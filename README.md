# Quantifying heterospecific vocal mimicry with deep learning: evidence from a juvenile bellbird

Code and presentation of a study on vocal mimicry in a juvenile Three-wattled Bellbird (*Procnias tricarunculatus*) from Monteverde, Costa Rica.

**Website:** <https://marce10.github.io/bellbird_vocal_mimicry/>

**Authors:** Pablo Huertas-Vásquez, Marcos Q. Oliva, [Marcelo Araya-Salas](https://marce10.github.io/)

## Overview

Vocal mimicry is hard to tell apart from chance acoustic resemblance. We retrained [BirdNET](https://github.com/birdnet-team/BirdNET-Analyzer) to distinguish three sympatric species the focal bird could have imitated, closely related allopatric species that could not have served as vocal models, and other bellbirds. Genuine mimicry predicts more classifications as sympatric than as allopatric species, while variable vocalizations produced during development predict similar frequencies for both.

## Repository structure

| Path | Contents |
|:-----|:-----|
| `index.qmd`, `presentation.qmd`, `_quarto.yml`, `styles.css`, `_figure-download.html` | Website pages and configuration |
| `scripts/birdnet_acoustic_data_prep.qmd` | Annotations, selection tables and data export for BirdNET |
| `scripts/statistical_analysis.qmd` | Classifiers, Bayesian models and temporal changes |
| `scripts/statistical_analysis_from_detection_probabilities.qmd` | Alternative analysis based on detection probabilities (not on the website) |
| `scripts/embeddings.ipynb`, `scripts/get_additional_acoustic_data.Rmd`, `scripts/test.qmd`, `scripts/colormaps.R` | Embeddings, additional recordings, composite figure and helpers (not on the website) |
| `presentation/` | Talk in Spanish: `presentation.qmd`, its images and data, and `prepare_slide_assets.R` |
| `output/` | Figures |
| `_freeze/` | Stored results of the reports, used to build the website |
| `.github/workflows/publish.yml` | Website deployment to GitHub Pages |

Audio data (`data/`), fitted models and the manuscript are not in this repository.

## Updating the website

Pushing to `master` publishes the website. The workflow only uses the stored results in `_freeze/`, so it needs neither R nor the data. Render locally first if something changed:

- **Reports or website pages:** run `quarto render` in the project root, and commit `_freeze/` if a report changed. This needs the local `data/` folder.
- **Presentation:** run `quarto render presentation.qmd` inside `presentation/`, and commit `presentation/presentation.html`. This needs the development version of [dynaSpec](https://github.com/maRce10/dynaSpec). The deck is rendered on its own, as set by `presentation/_quarto.yml`.
- **Slide assets:** run `Rscript presentation/prepare_slide_assets.R` from the project root only if the inputs changed. This needs ffmpeg and the local `data/` folder.
