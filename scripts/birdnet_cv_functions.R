# Functions to summarize the BirdNET cross-validation (scripts/birdnet_cv.sh)
# Used by scripts/birdnet_model_fitting.qmd

cv_dir <- "./data/processed/birdnet_cv"
sympatric_spp <- c("Procnias tricarunculatus", "Psarocolius montezuma",
                   "Pteroglossus torquatus", "Ramphastos sulfuratus")
all_spp <- c(sympatric_spp, "Psarocolius guatimozinus", "Pteroglossus erythropygius", "Ramphastos brevis")
model_spp <- list(sympatric_and_allopatric = sort(all_spp), sympatric = sort(sympatric_spp))

# selection tables of a folder -> one row per clip x species (confidence)
read_tables <- function(path) {
    files <- list.files(path, pattern = "selection\\.table\\.txt$", full.names = TRUE)
    tabs <- lapply(files, function(f) {
        x <- read.delim(f, check.names = FALSE)
        clip <- sub("\\.BirdNET\\.selection\\.table\\.txt$", "", basename(f))
        if (nrow(x) == 0) return(NULL)
        data.frame(clip = clip, species = x$`Common Name`, confidence = x$Confidence)
    })
    out <- do.call(rbind, tabs)
    out[out$species != "nocall", ]
}

# clip x species matrix of confidences (0 when below the 0.05 reporting limit)
score_matrix <- function(tab, clips, spp) {
    m <- matrix(0, length(clips), length(spp), dimnames = list(clips, spp))
    tab <- tab[tab$clip %in% clips & tab$species %in% spp, ]
    tab <- aggregate(confidence ~ clip + species, tab, max)
    m[cbind(tab$clip, tab$species)] <- tab$confidence
    m
}

# out-of-fold scores of a configuration and model
oof_scores <- function(config, model, folds) {
    spp <- model_spp[[model]]
    f <- folds[folds$species %in% spp, ]
    do.call(rbind, lapply(sort(unique(f$fold)), function(k) {
        fk <- f[f$fold == k, ]
        tab <- read_tables(file.path(cv_dir, "classification", config, model, paste0("fold_", k), "heldout"))
        s <- score_matrix(tab, sub("\\.wav$", "", fk$clip, ignore.case = TRUE), spp)
        data.frame(clip = rownames(s), true = fk$species, fold = k, s, check.names = FALSE)
    }))
}

# average precision (area under the precision-recall curve) of one class
avg_precision <- function(score, positive) {
    if (!any(positive)) return(NA)
    o <- order(score, decreasing = TRUE)
    pos <- positive[o]
    prec <- cumsum(pos) / seq_along(pos)
    sum(prec[pos]) / sum(pos)
}

f1 <- function(pred, truth, sp) {
    tp <- sum(pred == sp & truth == sp); fp <- sum(pred == sp & truth != sp); fn <- sum(pred != sp & truth == sp)
    p <- if (tp + fp > 0) tp / (tp + fp) else 0; r <- if (tp + fn > 0) tp / (tp + fn) else 0
    c(precision = p, recall = r, f1 = if (p + r > 0) 2 * p * r / (p + r) else 0)
}

# threshold of each species that maximizes its one-vs-rest F1 (0.05 steps, as BirdNET)
optimal_thresholds <- function(sc, spp, grid = seq(0.05, 0.95, by = 0.05)) {
    sapply(spp, function(sp) {
        f <- sapply(grid, function(t) f1(ifelse(sc[[sp]] >= t, sp, "other"), sc$true, sp)[["f1"]])
        grid[which.max(f)]
    })
}

# one prediction per clip: top species if it reaches its threshold, otherwise unassigned
assign_species <- function(sc, spp, thr) {
    m <- as.matrix(sc[, spp, drop = FALSE])
    top <- spp[max.col(m, ties.method = "first")]
    ok <- m[cbind(seq_len(nrow(m)), match(top, spp))] >= thr[top]
    ifelse(ok, top, "Unassigned")
}

# per-species and macro metrics of out-of-fold scores
cv_metrics <- function(sc, spp, thr) {
    pred <- assign_species(sc, spp, thr)
    per_sp <- do.call(rbind, lapply(spp, function(sp)
        data.frame(species = sp, t(f1(pred, sc$true, sp)), AUPRC = avg_precision(sc[[sp]], sc$true == sp),
                   threshold = thr[[sp]], clips = sum(sc$true == sp))))
    list(per_species = per_sp, pred = pred,
         macro = c(AUPRC = mean(per_sp$AUPRC), F1 = mean(per_sp$f1), accuracy = mean(pred == sc$true)))
}

# macro AUPRC and F1 within each fold (thresholds from all out-of-fold scores)
fold_metrics <- function(sc, spp, thr) {
    do.call(rbind, lapply(split(sc, sc$fold), function(d) {
        m <- cv_metrics(d, spp, thr)$macro
        data.frame(fold = d$fold[1], AUPRC = m[["AUPRC"]], F1 = m[["F1"]], accuracy = m[["accuracy"]])
    }))
}

# focal bellbird clips: mean confidence over the fold models (ensemble)
ensemble_scores <- function(config, model, k = 5) {
    spp <- model_spp[[model]]
    mats <- lapply(seq_len(k), function(i) {
        p <- file.path(cv_dir, "classification", config, model, paste0("fold_", i), "focal")
        clips <- sub("\\.BirdNET\\.selection\\.table\\.txt$", "", list.files(p, pattern = "selection\\.table\\.txt$"))
        score_matrix(read_tables(p), sort(clips), spp)
    })
    m <- Reduce(`+`, mats) / k
    data.frame(clip = rownames(m), m, check.names = FALSE)
}
