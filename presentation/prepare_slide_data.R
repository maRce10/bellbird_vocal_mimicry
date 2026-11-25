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

# ---- quality of the imitations and of the own song through time --------------------------
# acoustic similarity (mean cosine similarity of the generic BirdNET embedding to the 5 most similar
# reference clips of the species) and consistency (mean cosine similarity to each of the other clips
# of the same type recorded the same day) of each assigned focal clip, and their population-level
# trends at average long-window SNR, averaged over recording equipment in proportion to its number of
# clips. Final models of statistical_analysis_cv.qmd (long-window SNR and equipment as covariates)
qfits <- list(similarity = readRDS("data/processed/cv_fits/imitation_knn_snrlong_equipment_through_time.rds"),
              consistency = readRDS("data/processed/cv_fits/consistency_pairwise_snrlong_equipment_through_time.rds"))
resp <- c(similarity = "knn", consistency = "consistency")
spp_levels <- levels(qfits$similarity$data$species)
qpoints <- qcurves <- qslopes <- list()
for (m in names(qfits)) {
  d <- qfits[[m]]$data
  d$date <- as.Date(d$julian_day - 1, origin = "2020-01-01")
  qpoints[[m]] <- data.frame(date = d$date, species = as.character(d$species), measure = m, value = d[[resp[[m]]]])
  g <- expand.grid(julian_day = seq(min(d$julian_day), max(d$julian_day), length.out = 60), species = spp_levels,
                   equipment = sort(unique(d$equipment)), stringsAsFactors = FALSE)
  g$snr_long <- mean(d$snr_long)
  w <- as.numeric(table(d$equipment)[g$equipment]) / nrow(d)
  ep <- posterior_epred(qfits[[m]], newdata = g, re_formula = NA) * sd(d[[resp[[m]]]]) + mean(d[[resp[[m]]]])
  key <- paste(g$julian_day, g$species)
  ep <- t(rowsum(t(ep) * w, key, reorder = FALSE))
  g <- g[!duplicated(key), ]
  qcurves[[m]] <- data.frame(date = as.Date(g$julian_day - 1, origin = "2020-01-01"), species = g$species, measure = m,
                             value = colMeans(ep), low = apply(ep, 2, quantile, 0.025), high = apply(ep, 2, quantile, 0.975))
  post <- as_draws_df(qfits[[m]])
  base <- post$b_scalejulian_day
  sl <- cbind(base, base + post[["b_speciesCollaredAracari:scalejulian_day"]],
              base + post[["b_speciesThreeMwattledBellbird:scalejulian_day"]])
  qslopes[[m]] <- data.frame(measure = m, species = spp_levels, slope = colMeans(sl),
                             low = apply(sl, 2, quantile, 0.025), high = apply(sl, 2, quantile, 0.975))
}
write.csv(do.call(rbind, qpoints), file.path(out_data, "quality_points.csv"), row.names = FALSE)
write.csv(do.call(rbind, qcurves), file.path(out_data, "quality_curves.csv"), row.names = FALSE)
write.csv(do.call(rbind, qslopes), file.path(out_data, "quality_slopes.csv"), row.names = FALSE)

# ---- dialects of the own song through time -----------------------------------------------
# A: daily proportion of Talamanca rather than Nicaragua own-song clips and the Bernoulli trend
# (focal_dialect_through_time); B: neighbour similarity of each clip to the reference clips of its
# assigned dialect and its trends at average long-window SNR, averaged over equipment (own_song_similarity_within_dialect_snrlong_equipment_through_time)
fd <- read.csv("data/processed/focal_dialects.csv")
fd$date <- as.Date(fd$date)
nt <- fd[fd$dialect %in% c("Nicaragua", "Talamanca"), ]
dpts <- aggregate(dialect ~ date, nt, function(x) c(p = mean(x == "Talamanca"), n = length(x)))
dpts <- data.frame(date = dpts$date, prop = dpts$dialect[, "p"], n = dpts$dialect[, "n"])
write.csv(dpts, file.path(out_data, "dialect_points.csv"), row.names = FALSE)
d_days <- seq(min(fd$date), max(fd$date), length.out = 80)
d_jd <- as.numeric(format(d_days, "%j"))
ep <- posterior_epred(readRDS("data/processed/cv_fits/focal_dialect_through_time.rds"),
                      newdata = data.frame(julian_day = d_jd), re_formula = NA)
write.csv(data.frame(date = d_days, prop = colMeans(ep), low = apply(ep, 2, quantile, 0.025),
                     high = apply(ep, 2, quantile, 0.975)),
          file.path(out_data, "dialect_curve.csv"), row.names = FALSE)

m11 <- readRDS("data/processed/cv_fits/own_song_similarity_within_dialect_snrlong_equipment_through_time.rds")
d11 <- m11$data
write.csv(data.frame(date = as.Date(d11$julian_day - 1, origin = "2020-01-01"), dialect = as.character(d11$dialect),
                     value = d11$knn_d), file.path(out_data, "dialect_similarity_points.csv"), row.names = FALSE)
g <- expand.grid(julian_day = d_jd, dialect = c("Nicaragua", "Talamanca"), equipment = sort(unique(d11$equipment)),
                 stringsAsFactors = FALSE)
g$snr_long <- mean(d11$snr_long)
w <- as.numeric(table(d11$equipment)[g$equipment]) / nrow(d11)
ep <- posterior_epred(m11, newdata = g, re_formula = NA) * sd(d11$knn_d) + mean(d11$knn_d)
key <- paste(g$julian_day, g$dialect)
ep <- t(rowsum(t(ep) * w, key, reorder = FALSE))
g <- g[!duplicated(key), ]
write.csv(data.frame(date = as.Date(g$julian_day - 1, origin = "2020-01-01"), dialect = g$dialect, value = colMeans(ep),
                     low = apply(ep, 2, quantile, 0.025), high = apply(ep, 2, quantile, 0.975)),
          file.path(out_data, "dialect_similarity_curves.csv"), row.names = FALSE)
post <- as_draws_df(m11)
sl <- cbind(Nicaragua = post$b_scalejulian_day, Talamanca = post$b_scalejulian_day + post[["b_dialectTalamanca:scalejulian_day"]])
x10 <- as_draws_df(readRDS("data/processed/cv_fits/focal_dialect_through_time.rds"))$b_scalejulian_day
write.csv(data.frame(measure = c("talamanca_share", "similarity", "similarity"), dialect = c("Both", colnames(sl)),
                     slope = c(mean(x10), colMeans(sl)), low = c(quantile(x10, 0.025), apply(sl, 2, quantile, 0.025)),
                     high = c(quantile(x10, 0.975), apply(sl, 2, quantile, 0.975))),
          file.path(out_data, "dialect_slopes.csv"), row.names = FALSE)

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
