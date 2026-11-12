# One short example sound per bellbird dialect (Nicaraguan, Monteverde, Talamancan) for the
# dialect map next to the phylogeny close-up: among the adult bellbird selections in the
# extended selection table (column Vocalization), the one with the highest signal-to-noise
# ratio, in a 0.8 s window centred on it. Saved as images/dialecto_*.wav; presentation.qmd
# draws their spectrograms and the map.
# Run from presentation/ or from the project root (needs the local data/ folder):
#   Rscript presentation/dialect_spectrograms.R

if (!file.exists("dialect_spectrograms.R") && file.exists("presentation/dialect_spectrograms.R"))
  setwd("presentation")

suppressMessages({library(warbleR); library(tuneR); library(seewave)})

est <- readRDS("../data/processed/extended_selection_table_sympatric_and_allopatric_species.RDS")
dialects <- c(nicaraguense = "Nicaraguan", monteverde = "Monteverde", talamanca = "Talamancan")
win <- 0.8   # seconds shown

# SNR of a selection: brightest 1 % of spectrogram cells against the median cell, 0.5-10 kHz
sel_snr <- function(w) {
  if (w@stereo) w <- mono(w, "left")
  if (max(abs(w@left)) == 0) return(NA_real_)
  s <- spectro(w, wl = 512, ovlp = 75, plot = FALSE, dB = NULL, norm = FALSE)
  a <- s$amp[s$freq >= 0.5 & s$freq <= 10, , drop = FALSE]
  as.numeric(20 * log10(quantile(a, 0.99) / median(a)))
}

# 0.8 s window centred on the sound (padded with silence when it is shorter)
centre <- function(w, win) {
  n <- round(win * w@samp.rate)
  x <- w@left
  if (length(x) >= n) {
    s <- floor((length(x) - n) / 2)
    x <- x[(s + 1):(s + n)]
  } else {
    a <- floor((n - length(x)) / 2)
    x <- c(rep(0, a), x, rep(0, n - length(x) - a))
  }
  Wave(left = x, samp.rate = w@samp.rate, bit = w@bit)
}

best <- do.call(rbind, lapply(names(dialects), function(d) {
  idx <- which(est$Vocalization == dialects[[d]])
  snr <- vapply(idx, function(i) sel_snr(read_sound_file(est, index = i)), numeric(1))
  i <- idx[which.max(snr)]
  w <- read_sound_file(est, index = i)
  if (w@stereo) w <- mono(w, "left")
  writeWave(centre(w, win), file.path("images", paste0("dialecto_", d, ".wav")))
  data.frame(dialect = dialects[[d]], sound.files = est$sound.files[i],
             snr = round(max(snr, na.rm = TRUE), 1), n = length(idx))
}))
write.csv(best, "data/espectrogramas_dialectos.csv", row.names = FALSE)
print(best)
