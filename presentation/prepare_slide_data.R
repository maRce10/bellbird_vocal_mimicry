# Builds the classification data used by the result slides of presentation.qmd and
# presentation_en.qmd, from the cross-validated BirdNET classifiers (scripts/birdnet_cv.sh,
# scripts/birdnet_model_fitting.qmd) and the brms fits of scripts/statistical_analysis_cv.qmd.
# Run from the project root after those:  Rscript presentation/prepare_slide_data.R

library(brms)

source("scripts/birdnet_cv_functions.R")
out_data <- "presentation/data"
models <- c(sympatric_allopatric = "sympatric_and_allopatric", sympatric = "sympatric")

# out-of-fold predictions of the reference clips (each clip classified by the model of the fold
# that did not include its recording) and ensemble predictions of the focal bellbird clips.
# Unassigned clips (below the out-of-fold threshold of their top species) are "nocall"
oof <- lapply(models, function(m) read.csv(file.path(cv_dir, paste0("oof_predictions_", m, ".csv")), check.names = FALSE))
focal <- lapply(models, function(m) read.csv(file.path(cv_dir, paste0("focal_predictions_", m, ".csv")), check.names = FALSE))
as_nocall <- function(x) ifelse(x == "Unassigned", "nocall", x)

# ---- classification counts: focal bellbird and other bellbirds -------------------
tab <- function(pred, model, bird) {
  d <- as.data.frame(table(pred = as_nocall(pred)), stringsAsFactors = FALSE)
  d$model <- model
  d$bird <- bird
  d$total <- sum(d$Freq)
  d
}
counts <- do.call(rbind, lapply(names(models), function(m) rbind(
  tab(focal[[m]]$predicted, m, "focal"),
  tab(oof[[m]]$predicted[oof[[m]]$true == "Procnias tricarunculatus"], m, "other")
)))
write.csv(counts, file.path(out_data, "classification_counts.csv"), row.names = FALSE)

# ---- confusion matrices: out-of-fold predictions of the assigned clips -------------------
confusion <- function(x) {
  x <- x[x$predicted != "Unassigned", ]
  d <- as.data.frame(table(reference = x$true, predicted = x$predicted), stringsAsFactors = FALSE)
  d$proportion <- d$Freq / ave(d$Freq, d$reference, FUN = sum)
  d
}
write.csv(confusion(oof$sympatric_allopatric), file.path(out_data, "confusion_sympatric_allopatric.csv"), row.names = FALSE)
write.csv(confusion(oof$sympatric), file.path(out_data, "confusion_sympatric.csv"), row.names = FALSE)

# ---- clips, recordings and out-of-fold F1 of each species --------------------------------
folds <- read.csv(file.path(cv_dir, "folds.csv"))
training <- aggregate(clip ~ species, folds, length)
names(training)[2] <- "clips"
training$recordings <- tapply(folds$recording, folds$species, function(x) length(unique(x)))[training$species]
for (m in names(models)) {
  spp <- model_spp[[models[[m]]]]
  r <- cv_metrics(oof[[m]], spp, optimal_thresholds(oof[[m]], spp))
  training[[paste0("f1_", m)]] <- setNames(r$per_species$f1, spp)[training$species]
  # macro-averaged F1 of the model (same value in every row)
  training[[paste0("macro_f1_", m)]] <- r$macro[["F1"]]
}
write.csv(training, file.path(out_data, "entrenamiento_modelos.csv"), row.names = FALSE)

# ---- change through time ----------------------------------------------------------------
mod <- readRDS("data/processed/cv_fits/mimicry_through_time.rds")
points <- data.frame(
  julian_day = mod$data$julian_day,
  species = as.character(mod$data$pred_common_name),
  n = mod$data$n,
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
# category effects only, averaging over the observation-level (overdispersion) effect
grid$prop <- colMeans(posterior_epred(mod, newdata = grid,
                                      re_formula = ~ (1 + scale(julian_day) | pred_common_name))) / 100
grid$date <- as.Date(grid$julian_day - 1, origin = "2020-01-01")
names(grid)[names(grid) == "pred_common_name"] <- "species"
write.csv(grid, file.path(out_data, "temporal_curves.csv"), row.names = FALSE)

# ---- numbers quoted on the slides --------------------------------------------------------
fit1 <- readRDS("data/processed/cv_fits/sympatric_allopatric_focal.rds")
p <- plogis(as_draws_df(fit1)$b_Intercept)
sa <- counts[counts$model == "sympatric_allopatric", ]
het <- function(bird, spp) sum(sa$Freq[sa$bird == bird & sa$pred %in% spp])
allo <- c("Psarocolius guatimozinus", "Pteroglossus erythropygius", "Ramphastos brevis")
symp <- c("Psarocolius montezuma", "Pteroglossus torquatus", "Ramphastos sulfuratus")
numbers <- data.frame(
  focal_sympatric = het("focal", symp), focal_allopatric = het("focal", allo),
  other_sympatric = het("other", symp), other_allopatric = het("other", allo),
  other_total = unique(sa$total[sa$bird == "other"]),
  p_sympatric = median(p), p_sympatric_low = quantile(p, 0.025), p_sympatric_high = quantile(p, 0.975),
  reference_clips = nrow(folds)
)
write.csv(numbers, file.path(out_data, "result_numbers.csv"), row.names = FALSE)
print(numbers)
