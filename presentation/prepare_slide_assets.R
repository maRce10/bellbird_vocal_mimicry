# Builds the data, spectrogram panels, photos and audio clips used by
# presentation.qmd. Run once from the project root (only re-run if inputs change):
#   Rscript presentation/prepare_slide_assets.R
# Needs ffmpeg on the PATH. The deck itself only reads the files written here.

library(Rraven)
library(brms)
library(ggplot2)
library(patchwork)
library(seewave)
library(tuneR)
library(viridis)

out_data <- "presentation/data"
out_img <- "presentation/images"
cls <- "data/processed/birdnet_classification_outputs/"
fig_dir <- "data/raw/figure_audios&pictures/"

# ---- classifier outputs -----------------------------------------------------

eval_sa <- read.csv("data/processed/birdnet_models/sympatric_and_allopatric/sympatric_and_allopatric_evaluation.csv")
eval_s <- read.csv("data/processed/birdnet_models/sympatric/sympatric_evaluation.csv")

# read a Raven folder; calls under the class's optimal threshold become "nocall"
read_class <- function(path, evaluation) {
  x <- imp_raven(path = path, all.data = TRUE, warbler.format = TRUE, pb = FALSE)
  pred <- x$`Common Name`
  thr <- evaluation$Optimal.Threshold[match(pred, evaluation$Class)]
  pred[is.na(thr) | x$Confidence < thr] <- "nocall"
  data.frame(file = basename(gsub("\\\\", "/", x$sound.files, useBytes = TRUE)), pred = pred)
}

est <- readRDS("data/processed/extended_selection_table_sympatric_and_allopatric_species.RDS")
add_source <- function(x) {
  x$source <- as.character(est$source)[match(x$file, paste0(est$sound.files, ".wav"))]
  x
}
test_files <- basename(list.files("data/processed/birdnet_data/test_data/", recursive = TRUE))

focal_sa <- read_class(paste0(cls, "mimic_bellbird/sympatrics_and_allopatrics_model/"), eval_sa)
other_sa <- read_class(paste0(cls, "other_bellbirds/sympatrics_and_allopatrics_model/"), eval_sa)
focal_s <- read_class(paste0(cls, "mimic_bellbird/sympatric_model/"), eval_s)
refs_sa <- add_source(read_class(paste0(cls, "sympatrics_and_allopactrics/sympatrics_and_allopatrics_model/"), eval_sa))
refs_s <- add_source(read_class(paste0(cls, "sympatrics/sympatrics_model/"), eval_s))

# Fig. 5 of the manuscript draft compares against every reference bellbird clip
other_s <- refs_s[refs_s$source == "Procnias tricarunculatus", ]

tab <- function(x, model, bird) {
  d <- as.data.frame(table(pred = x$pred), stringsAsFactors = FALSE)
  d$model <- model
  d$bird <- bird
  d$total <- sum(d$Freq)
  d
}
counts <- rbind(
  tab(focal_sa, "sympatric_allopatric", "focal"), tab(other_sa, "sympatric_allopatric", "other"),
  tab(focal_s, "sympatric", "focal"), tab(other_s, "sympatric", "other")
)
write.csv(counts, file.path(out_data, "classification_counts.csv"), row.names = FALSE)

# confusion matrices over calls above threshold, as in manuscript Figs. 2 and 4
confusion <- function(x) {
  x <- x[x$pred != "nocall" & !is.na(x$source) & x$source %in% x$pred, ]
  d <- as.data.frame(table(reference = x$source, predicted = x$pred), stringsAsFactors = FALSE)
  d$proportion <- d$Freq / ave(d$Freq, d$reference, FUN = sum)
  d
}
write.csv(confusion(refs_sa), file.path(out_data, "confusion_sympatric_allopatric.csv"), row.names = FALSE)
write.csv(confusion(refs_s), file.path(out_data, "confusion_sympatric.csv"), row.names = FALSE)

# held-out clips only, for comparison (not plotted)
write.csv(confusion(refs_sa[refs_sa$file %in% test_files, ]),
          file.path(out_data, "confusion_sympatric_allopatric_test_only.csv"), row.names = FALSE)
write.csv(confusion(refs_s[refs_s$file %in% test_files, ]),
          file.path(out_data, "confusion_sympatric_test_only.csv"), row.names = FALSE)

# ---- change through time ----------------------------------------------------

mod <- readRDS("data/processed/brms_model_prop_pred_mimicry.rds")
points <- data.frame(
  julian_day = mod$data$julian_day,
  species = as.character(mod$data$pred_common_name),
  n = mod$data$orig.sound.files,
  total = mod$data$total
)
points$prop <- points$n / points$total
points$date <- as.Date(points$julian_day - 1, origin = "2020-01-01")
write.csv(points, file.path(out_data, "temporal_points.csv"), row.names = FALSE)

grid <- expand.grid(
  julian_day = seq(min(points$julian_day), max(points$julian_day), length.out = 100),
  pred_common_name = unique(points$species),
  stringsAsFactors = FALSE
)
grid$total <- 100 # so that the expected count / 100 is a proportion
grid$prop <- colMeans(posterior_epred(mod, newdata = grid)) / 100
grid$date <- as.Date(grid$julian_day - 1, origin = "2020-01-01")
names(grid)[names(grid) == "pred_common_name"] <- "species"
write.csv(grid, file.path(out_data, "temporal_curves.csv"), row.names = FALSE)

# ---- spectrogram clips (same settings as the composite figure, scripts/test.qmd) ----

lowpass <- list("CABBM.wav" = 8000, "RSBBM.wav" = 8000, "BBS.wav" = 7000)
window_dur <- 3
flim <- c(0, 10)
highpass <- 1200

silhouette_files <- c(
  bellbird = "Edwin Prince.png", oropendola = "Ferran Sayol.png",
  aracari = "Edwin Price2.png", toucan = "Gabriela Palomo-Munoz.png"
)

# same 3 s window, band filter and padding as the composite figure; dynaSpec draws the
# spectrogram and plays the sound from this clip (see ds_panel() in presentation.qmd)
write_clip <- function(wav, start, out) {
  hdr <- readWave(wav, header = TRUE)
  w <- readWave(wav, from = start, to = min(start + window_dur, hdr$samples / hdr$sample.rate),
                units = "seconds")
  w <- ffilter(w, f = w@samp.rate, from = highpass, to = lowpass[[basename(wav)]], output = "Wave")
  pad <- round(window_dur * w@samp.rate) - length(w@left)
  if (pad > 0) {
    w <- bind(w, silence(duration = pad, samp.rate = w@samp.rate, bit = w@bit, pcm = w@pcm,
                         xunit = "samples"))
  }
  writeWave(normalize(w, unit = "16", level = 0.9), out)
}

# black silhouettes, for species without a drawing
write_silhouette <- function(silhouette) {
  alpha <- png::readPNG(paste0(fig_dir, silhouette_files[[silhouette]]))[, , 2]
  sil <- array(c(rep(0, 3 * length(alpha)), alpha), dim = c(dim(alpha), 4))
  png::writePNG(sil, file.path(out_img, paste0("sil_", silhouette, ".png")))
}

# center crop to the shape of the photo column, then shrink
write_photo_panel <- function(file, out, aspect = 0.72) {
  img <- jpeg::readJPEG(paste0(fig_dir, file))
  h <- dim(img)[1]; w <- dim(img)[2]
  if (w / h > aspect) {
    keep <- round(h * aspect); off <- floor((w - keep) / 2)
    img <- img[, (off + 1):(off + keep), , drop = FALSE]
  } else {
    keep <- round(w / aspect); off <- floor((h - keep) / 2)
    img <- img[(off + 1):(off + keep), , , drop = FALSE]
  }
  jpeg::writeJPEG(img, out, quality = 0.85)
  stopifnot(system2("ffmpeg", c("-y", "-loglevel", "error", "-i", shQuote(out), "-vf", "scale=500:-2",
                                "-q:v", "4", shQuote(paste0(out, ".tmp.jpg")))) == 0)
  file.rename(paste0(out, ".tmp.jpg"), out)
}

models_dir <- "data/processed/example_spectrogram_annotations/models/"
pairs <- list(
  oropendola = list(
    focal = list(wav = paste0(fig_dir, "OBBM.wav"), start = 1.6),
    model = list(wav = paste0(fig_dir, "Psarocolius-montezuma-106662_.wav"), start = 11.3),
    silhouette = "oropendola", model_title = "Oropéndola de Moctezuma",
    wl = 1024, collevels = seq(-45, 0, 1), photo = "DSCN8088.JPG"
  ),
  aracari = list(
    focal = list(wav = paste0(fig_dir, "CABBM.wav"), start = 0),
    model = list(wav = paste0(models_dir, "Pteroglossus-torquatus-154157_.wav"), start = 5.5),
    silhouette = "aracari", model_title = "Aracari de collar",
    wl = 512, collevels = seq(-50, 0, 5), photo = "celluloid-shot0003.jpg"
  ),
  toucan = list(
    focal = list(wav = paste0(fig_dir, "RSBBM.wav"), start = 0),
    model = list(wav = paste0(models_dir, "Ramphastos-sulfuratus-137713_.wav"), start = 0),
    silhouette = "toucan", model_title = "Tucán pico iris",
    wl = 512, collevels = seq(-50, 0, 5), photo = "DSCN7194.JPG"
  ),
  bock = list(
    focal = list(wav = paste0(fig_dir, "BBS.wav"), start = 0),
    model = list(wav = "data/raw/recordings/Procnias-tricarunculatus-30207.wav", start = 1.4),
    silhouette = "bellbird", model_title = "Pájaro campana adulto",
    wl = 512, collevels = seq(-50, 0, 5), photo = "DSCN7233.JPG"
  )
)

invisible(lapply(names(silhouette_files), write_silhouette))

for (nm in names(pairs)) {
  p <- pairs[[nm]]
  write_clip(p$focal$wav, p$focal$start, file.path(out_img, paste0("clip_", nm, "_focal.wav")))
  write_clip(p$model$wav, p$model$start, file.path(out_img, paste0("clip_", nm, "_model.wav")))
  write_photo_panel(p$photo, file.path(out_img, paste0("panel_", nm, ".jpg")))
}

# ---- species drawings -------------------------------------------------------
# source: images/<Genus species>.png; a drawing added there is used on the slides after running this
for (f in list.files(out_img, pattern = "^[A-Z][a-z]+ [a-z]+\\.png$", full.names = TRUE)) {
  sp <- sub("\\.png$", "", basename(f))
  d <- magick::image_trim(magick::image_read(f), fuzz = 5)
  d <- magick::image_resize(d, "500x500>")
  magick::image_write(d, file.path(out_img, paste0("dibujo_", gsub(" ", "_", tolower(sp)), ".png")))
}

# ---- photos -----------------------------------------------------------------

src <- c(toucan_bellbird = "data/processed/pictures/DSCN7154.JPG",
         singing = paste0(fig_dir, "DSCN7233.JPG"),
         perched = paste0(fig_dir, "DSCN8088.JPG"))
for (nm in names(src)) {
  stopifnot(system2("ffmpeg", c("-y", "-loglevel", "error", "-i", shQuote(src[[nm]]),
                                "-vf", "scale=1600:-2", "-q:v", "4",
                                shQuote(file.path(out_img, paste0("photo_", nm, ".jpg"))))) == 0)
}

# ---- training data of the classifiers -----------------------------------------
# recordings and 2 s clips per species used to train and test BirdNET (80/20 split by
# recording), and the F1 score of each class at its optimal threshold in each model
count_split <- function(split) {
  d <- file.path("data/processed/birdnet_data", split)
  do.call(rbind, lapply(list.dirs(d, recursive = FALSE), function(p) {
    f <- list.files(p, pattern = "\\.wav$")
    data.frame(species = basename(p), clips = length(f),
               recordings = length(unique(sub("\\.wav_[0-9]+\\.wav$", "", f))))
  }))
}
train <- count_split("train_data")
test <- count_split("test_data")
training <- merge(train, test, by = "species", suffixes = c("_train", "_test"))
f1 <- function(model) {
  e <- read.csv(file.path("data/processed/birdnet_models", model, paste0(model, "_evaluation.csv")),
                check.names = FALSE)
  setNames(e[["F1 Score (opt)"]], e$Class)
}
training$f1_sympatric_allopatric <- f1("sympatric_and_allopatric")[training$species]
training$f1_sympatric <- f1("sympatric")[training$species]
write.csv(training, file.path("presentation/data", "entrenamiento_modelos.csv"), row.names = FALSE)
