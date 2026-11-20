# Builds the spectrogram panels, photos and audio clips used by presentation.qmd (the
# classification data of the result slides are built by prepare_slide_data.R).
# Run once from the project root (only re-run if inputs change):
#   Rscript presentation/prepare_slide_assets.R
# Needs ffmpeg on the PATH. The deck itself only reads the files written here.

library(ggplot2)
library(patchwork)
library(seewave)
library(tuneR)
library(viridis)

out_data <- "presentation/data"
out_img <- "presentation/images"
fig_dir <- "data/raw/figure_audios&pictures/"

# ---- spectrogram clips (same settings as the composite figure, scripts/test.qmd) ----

lowpass <- list("CABBM.wav" = 8000, "RSBBM.wav" = 8000, "BBS.wav" = 7000)
window_dur <- 3
flim <- c(0, 10)
highpass <- 1200

silhouette_files <- c(
  bellbird = "Edwin Prince.png",
  oropendola = "Ferran Sayol.png",
  aracari = "Edwin Price2.png",
  toucan = "Gabriela Palomo-Munoz.png"
)

# same 3 s window, band filter and padding as the composite figure; dynaSpec draws the
# spectrogram and plays the sound from this clip (see ds_panel() in presentation.qmd)
write_clip <- function(wav, start, out) {
  hdr <- readWave(wav, header = TRUE)
  w <- readWave(
    wav,
    from = start,
    to = min(start + window_dur, hdr$samples / hdr$sample.rate),
    units = "seconds"
  )
  w <- ffilter(
    w,
    f = w@samp.rate,
    from = highpass,
    to = lowpass[[basename(wav)]],
    output = "Wave"
  )
  pad <- round(window_dur * w@samp.rate) - length(w@left)
  if (pad > 0) {
    w <- bind(
      w,
      silence(
        duration = pad,
        samp.rate = w@samp.rate,
        bit = w@bit,
        pcm = w@pcm,
        xunit = "samples"
      )
    )
  }
  writeWave(normalize(w, unit = "16", level = 0.9), out)
}

# black silhouettes, for species without a drawing
write_silhouette <- function(silhouette) {
  alpha <- png::readPNG(paste0(fig_dir, silhouette_files[[silhouette]]))[,, 2]
  sil <- array(c(rep(0, 3 * length(alpha)), alpha), dim = c(dim(alpha), 4))
  png::writePNG(sil, file.path(out_img, paste0("sil_", silhouette, ".png")))
}

# center crop to the shape of the photo column, then shrink
write_photo_panel <- function(file, out, aspect = 0.72) {
  img <- jpeg::readJPEG(paste0(fig_dir, file))
  h <- dim(img)[1]
  w <- dim(img)[2]
  if (w / h > aspect) {
    keep <- round(h * aspect)
    off <- floor((w - keep) / 2)
    img <- img[, (off + 1):(off + keep), , drop = FALSE]
  } else {
    keep <- round(w / aspect)
    off <- floor((h - keep) / 2)
    img <- img[(off + 1):(off + keep), , , drop = FALSE]
  }
  jpeg::writeJPEG(img, out, quality = 0.85)
  stopifnot(
    system2(
      "ffmpeg",
      c(
        "-y",
        "-loglevel",
        "error",
        "-i",
        shQuote(out),
        "-vf",
        "scale=500:-2",
        "-q:v",
        "4",
        shQuote(paste0(out, ".tmp.jpg"))
      )
    ) ==
      0
  )
  file.rename(paste0(out, ".tmp.jpg"), out)
}

models_dir <- "data/processed/example_spectrogram_annotations/models/"
pairs <- list(
  oropendola = list(
    focal = list(wav = paste0(fig_dir, "OBBM.wav"), start = 1.6),
    model = list(
      wav = paste0(fig_dir, "Psarocolius-montezuma-106662_.wav"),
      start = 11.3
    ),
    silhouette = "oropendola",
    model_title = "Oropéndola de Moctezuma",
    wl = 1024,
    collevels = seq(-45, 0, 1),
    photo = "DSCN8088.JPG"
  ),
  # focal clip classified as Psarocolius montezuma by BirdNET (from INVEST_0093.wav)
  oropendola_birdnet = list(
    focal = list(
      wav = "presentation/images/INVEST_0093_oropendola_imitation_example.wav",
      start = 0
    ),
    model = list(
      wav = paste0(fig_dir, "Psarocolius-montezuma-106662_.wav"),
      start = 11.3
    ),
    silhouette = "oropendola",
    model_title = "Oropéndola de Moctezuma",
    wl = 1024,
    collevels = seq(-45, 0, 1),
    photo = "DSCN8088.JPG"
  ),
  aracari = list(
    focal = list(wav = paste0(fig_dir, "CABBM.wav"), start = 0),
    model = list(
      wav = paste0(models_dir, "Pteroglossus-torquatus-154157_.wav"),
      start = 5.5
    ),
    silhouette = "aracari",
    model_title = "Aracari de collar",
    wl = 512,
    collevels = seq(-50, 0, 5),
    photo = "celluloid-shot0003.jpg"
  ),
  toucan = list(
    focal = list(wav = paste0(fig_dir, "RSBBM.wav"), start = 0),
    model = list(
      wav = paste0(models_dir, "Ramphastos-sulfuratus-137713_.wav"),
      start = 0
    ),
    silhouette = "toucan",
    model_title = "Tucán pico iris",
    wl = 512,
    collevels = seq(-50, 0, 5),
    photo = "DSCN7194.JPG"
  ),
  bock = list(
    focal = list(wav = paste0(fig_dir, "BBS.wav"), start = 0),
    model = list(
      wav = "data/raw/recordings/Procnias-tricarunculatus-30207.wav",
      start = 1.4
    ),
    silhouette = "bellbird",
    model_title = "Pájaro campana adulto",
    wl = 512,
    collevels = seq(-50, 0, 5),
    photo = "DSCN7233.JPG"
  )
)

invisible(lapply(names(silhouette_files), write_silhouette))

for (nm in names(pairs)) {
  p <- pairs[[nm]]
  write_clip(
    p$focal$wav,
    p$focal$start,
    file.path(out_img, paste0("clip_", nm, "_focal.wav"))
  )
  write_clip(
    p$model$wav,
    p$model$start,
    file.path(out_img, paste0("clip_", nm, "_model.wav"))
  )
  write_photo_panel(p$photo, file.path(out_img, paste0("panel_", nm, ".jpg")))
}

# ---- species drawings -------------------------------------------------------
# source: images/<Genus species>.png; a drawing added there is used on the slides after running this
for (f in list.files(
  out_img,
  pattern = "^[A-Z][a-z]+ [a-z]+\\.png$",
  full.names = TRUE
)) {
  sp <- sub("\\.png$", "", basename(f))
  d <- magick::image_trim(magick::image_read(f), fuzz = 5)
  d <- magick::image_resize(d, "500x500>")
  magick::image_write(
    d,
    file.path(out_img, paste0("dibujo_", gsub(" ", "_", tolower(sp)), ".png"))
  )
}

# ---- photos -----------------------------------------------------------------

src <- c(
  toucan_bellbird = "data/processed/pictures/DSCN7154.JPG",
  singing = paste0(fig_dir, "DSCN7233.JPG"),
  perched = paste0(fig_dir, "DSCN8088.JPG")
)
for (nm in names(src)) {
  stopifnot(
    system2(
      "ffmpeg",
      c(
        "-y",
        "-loglevel",
        "error",
        "-i",
        shQuote(src[[nm]]),
        "-vf",
        "scale=1600:-2",
        "-q:v",
        "4",
        shQuote(file.path(out_img, paste0("photo_", nm, ".jpg")))
      )
    ) ==
      0
  )
}
