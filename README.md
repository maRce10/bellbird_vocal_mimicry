# Quantifying heterospecific vocal mimicry with deep learning: evidence from a juvenile bellbird

Code and presentation of a study on vocal mimicry in a juvenile Three-wattled Bellbird (*Procnias tricarunculatus*) from Monteverde, Costa Rica.

**Website:** <https://marce10.github.io/bellbird_vocal_mimicry/>

**Authors:** [Marcelo Araya-Salas](https://marce10.github.io/), Pablo Huertas-Vásquez, Marcos Q. Oliva

## Overview

Vocal mimicry is hard to tell apart from chance acoustic resemblance. We retrained [BirdNET](https://github.com/birdnet-team/BirdNET-Analyzer) to distinguish three sympatric species the focal bird could have imitated, closely related allopatric species that could not have served as vocal models, and other bellbirds. Genuine mimicry predicts more classifications as sympatric than as allopatric species, while variable vocalizations produced during development predict similar frequencies for both.

## Repository structure

| Path | Contents |
|:-----|:-----|
| `index.qmd`, `media.qmd`, `presentation.qmd`, `presentation_en.qmd`, `_quarto.yml`, `styles.css`, `_figure-download.html` | Website pages (home, videos and images, links to the two decks) and configuration |
| `scripts/birdnet_acoustic_data_prep.qmd` | Annotations, selection tables and data export for BirdNET |
| `scripts/birdnet_model_fitting.qmd` | BirdNET classifiers with 5-fold cross-validation grouped by recording, hyperparameter search and classification of the clips |
| `scripts/statistical_analysis_cv.qmd` | Bayesian models of the classifications, the quality of the imitations and of the own song (long-window signal-to-noise ratio and recording equipment as covariates), the dialects of the focal bellbird and the robustness checks |
| `scripts/birdnet_cv.sh`, `scripts/birdnet_cv_folds.py`, `scripts/birdnet_dialect_folds.py`, `scripts/birdnet_random_search.py`, `scripts/birdnet_cv_functions.R` | Cross-validation folds, training runs and helper functions used by the reports |
| `scripts/statistical_analysis.qmd`, `scripts/statistical_analysis_from_detection_probabilities.qmd` | Earlier analyses without cross-validation (not on the website) |
| `scripts/embeddings.ipynb`, `scripts/get_additional_acoustic_data.Rmd`, `scripts/test.qmd`, `scripts/colormaps.R` | Embeddings, additional recordings, composite figure and helpers (not on the website) |
| `presentation/` | Talk in Spanish (`presentation.qmd`) and English (`presentation_en.qmd`), their images and data, `prepare_slide_data.R` (results shown on the slides), `prepare_slide_assets.R` (sounds and videos) and the scripts of the paper figures (`paper_figure_dialects.R`, `export_paper_figures.sh`) |
| `data/processed/` | Small derived tables: cross-validation folds, out-of-fold and focal predictions, and the dialect of each focal clip |
| `output/` | Figures |
| `_freeze/` | Stored results of the reports, used to build the website |
| `.github/workflows/publish.yml` | Website deployment to GitHub Pages |

Audio data, fitted models and the manuscript are not in this repository.

## Updating the website

Pushing to `master` publishes the website. The workflow only uses the stored results in `_freeze/`, so it needs neither R nor the data. Render locally first if something changed:

- **Reports or website pages:** run `quarto render` in the project root, and commit `_freeze/` if a report changed. This needs the local `data/` folder.
- **Presentation:** run `Rscript presentation/prepare_slide_data.R` from the project root if the models changed, then `quarto render presentation.qmd` and `quarto render presentation_en.qmd` inside `presentation/`, and commit both `.html` files. This needs the development version of [dynaSpec](https://github.com/maRce10/dynaSpec). The decks are rendered on their own, as set by `presentation/_quarto.yml`.
- **Slide assets:** run `Rscript presentation/prepare_slide_assets.R` from the project root only if the inputs changed. This needs ffmpeg and the local `data/` folder.
