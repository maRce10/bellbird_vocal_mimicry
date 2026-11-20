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
    # a model that never reaches the reporting limit (a diverged fit) scores 0 everywhere
    if (is.null(tab)) return(m)
    tab <- tab[tab$clip %in% clips & tab$species %in% spp, ]
    if (nrow(tab) == 0) return(m)
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

# complexity of a configuration, to break near-ties (one-standard-error rule): hidden units
# first, then the number of added techniques (focal loss, mixup, label smoothing, upsampling),
# then dropout. Read from the parameters file written by BirdNET for the fold 1 model
config_complexity <- function(config, model) {
    p <- read.csv(file.path(cv_dir, "models", config, model, "fold_1", paste0(model, "_Params.csv")), check.names = FALSE)
    extras <- (p[["use focal loss"]] == "True") + (p[["use mixup"]] == "True") +
        (p[["use label smoothing"]] == "True") + (as.numeric(p[["Upsamling ratio"]]) > 0)
    data.frame(config = config, hidden = p[["Hidden units"]], extras = extras, dropout = p[["Dropout"]])
}

# one-standard-error rule: among the configurations whose macro AUPRC is within one standard
# error (SD across folds / sqrt(number of folds)) of the best one, the simplest
# auprc: named vector of macro AUPRC; se: standard error of the best one's; complexity: data
# frame from config_complexity()
select_one_se <- function(auprc, se_best, complexity) {
    best <- names(auprc)[which.max(auprc)]
    cand <- names(auprc)[auprc >= auprc[[best]] - se_best]
    cx <- complexity[match(cand, complexity$config), ]
    cand[order(cx$hidden, cx$extras, cx$dropout, -auprc[cand])][1]
}

# macro AUPRC of each fold
fold_auprc <- function(sc, spp) sapply(split(sc, sc$fold), function(d)
    mean(sapply(spp, function(sp) avg_precision(d[[sp]], d$true == sp))))

# performance of the selection procedure itself (the selected configuration's out-of-fold score
# is optimistic when it is chosen among many). For each fold k, the configuration is chosen with
# the one-standard-error rule on the out-of-fold predictions of the other folds, and its
# thresholds are tuned on those folds; it is then scored on fold k, which played no part in the
# choice. scores: list of out-of-fold score data frames, one per configuration
selection_excluded_metrics <- function(scores, spp, complexity) {
    ks <- sort(unique(scores[[1]]$fold))
    do.call(rbind, lapply(ks, function(k) {
        rest <- lapply(scores, function(sc) sc[sc$fold != k, ])
        auprc_rest <- sapply(rest, function(d) mean(sapply(spp, function(sp) avg_precision(d[[sp]], d$true == sp))))
        best <- names(auprc_rest)[which.max(auprc_rest)]
        fa <- fold_auprc(rest[[best]], spp)
        cf <- select_one_se(auprc_rest, sd(fa) / sqrt(length(fa)), complexity)
        held <- scores[[cf]][scores[[cf]]$fold == k, ]
        m <- cv_metrics(held, spp, optimal_thresholds(rest[[cf]], spp))$macro
        data.frame(fold = k, chosen = cf, AUPRC = m[["AUPRC"]], F1 = m[["F1"]], accuracy = m[["accuracy"]])
    }))
}
