#!/usr/bin/env bash
# Exports the result figures of the English deck at 300 dpi for the manuscript
# (output/manuscript/figure_2.png ... figure_7.png). Run from the project root after
# Rscript presentation/prepare_slide_data.R:  bash presentation/export_paper_figures.sh
set -euo pipefail
cd presentation
sed -e 's/^    embed-resources: true/    embed-resources: false/' -e 's/^    dpi: 150/    dpi: 300/' \
    -e 's/^    fig-dpi: 150/    fig-dpi: 300/' presentation_en.qmd > zz_paperfigs.qmd
quarto render zz_paperfigs.qmd > /dev/null
f=zz_paperfigs_files/figure-revealjs
mkdir -p ../output/manuscript
# chunk number -> manuscript figure (chunks are numbered in order of appearance in the deck)
cp "$f/unnamed-chunk-14-1.png" ../output/manuscript/figure_2.png  # confusion, sympatric + allopatric
cp "$f/unnamed-chunk-11-1.png" ../output/manuscript/figure_3.png  # sympatric vs allopatric, focal and others
cp "$f/unnamed-chunk-15-1.png" ../output/manuscript/figure_4.png  # confusion, sympatric only
cp "$f/unnamed-chunk-12-1.png" ../output/manuscript/figure_5.png  # sympatric model species
cp "$f/unnamed-chunk-13-1.png" ../output/manuscript/figure_6.png  # change over time
cp "$f/imitation-quality-1.png" ../output/manuscript/figure_7.png  # quality of imitations and own song through time
rm -rf zz_paperfigs.qmd zz_paperfigs.html zz_paperfigs_files
echo "Figures written to output/manuscript"
