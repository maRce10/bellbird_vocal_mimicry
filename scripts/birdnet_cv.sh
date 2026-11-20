#!/usr/bin/env bash
# 5-fold cross-validation of the custom BirdNET classifiers, grouped by recording.
#
# For each hyperparameter configuration (A, B, C and the random ones, R01...), model (sympatric_and_allopatric,
# sympatric) and fold: train on the other folds (seed 123, bandpass 400-12000 Hz,
# early stopping on a random 20% of the training clips), then classify the held-out
# fold (2 s clips) and the focal bellbird clips.
#
# Run from the project root:  bash scripts/birdnet_cv.sh [folds|train|classify|all]
# Outputs in data/processed/birdnet_cv/:
#   folds.csv                                       fold of each clip
#   models/<config>/<model>/fold_<k>/               trained models and logs
#   classification/<config>/<model>/fold_<k>/heldout/  out-of-fold selection tables
#   classification/<config>/<model>/fold_<k>/focal/    focal bellbird selection tables
set -euo pipefail

PY=${BIRDNET_PY:-$HOME/mambaforge/envs/birdnet_env/bin/python}
BIRDNET_DIR=${BIRDNET_DIR:-$HOME/BirdNET-Analyzer}
SEED=${SEED:-123}
K=${K:-5}
EPOCHS=${EPOCHS:-50}
FMIN=400; FMAX=12000
STEP=${1:-all}

PROJECT=$(pwd)
DATA=$PROJECT/data/processed/birdnet_data
CV=$PROJECT/data/processed/birdnet_cv
MODELS=(sympatric_and_allopatric sympatric)

# hyperparameter configurations compared
config_args() {
    case $1 in
        # A: settings of the GUI sympatric + allopatric model
        A) echo "--hidden_units 2048 --dropout 0.5 --batch_size 64 --learning_rate 0.001 --upsampling_mode repeat --upsampling_ratio 0 --mixup --focal-loss --focal-loss-alpha 0.75 --focal-loss-gamma 0.5" ;;
        # B: settings of the GUI sympatric-only model
        B) echo "--hidden_units 256 --dropout 0.5 --batch_size 16 --learning_rate 0.002 --upsampling_mode repeat --upsampling_ratio 0.33 --mixup" ;;
        # C: BirdNET defaults (linear classifier, no dropout, mixup, upsampling or focal loss)
        C) echo "--hidden_units 0 --dropout 0 --batch_size 32 --learning_rate 0.0001 --upsampling_mode repeat --upsampling_ratio 0" ;;
        # R01, R02, ...: random configurations drawn by scripts/birdnet_random_search.py
        R*) "$PY" -I -c "import csv,sys; print(next(r['args'] for r in csv.DictReader(open(sys.argv[1])) if r['config'] == sys.argv[2]))" \
                "$CV/random_search_configs.csv" "$1" ;;
    esac
}
CONFIGS=${CONFIGS:-"A B C"}
# all random configurations: CONFIGS="$(cut -d, -f1 data/processed/birdnet_cv/random_search_configs.csv | tail -n +2)"

if [[ $STEP == all || $STEP == folds ]]; then
    "$PY" -I "$PROJECT/scripts/birdnet_cv_folds.py" "$DATA" "$CV" --k "$K" --seed "$SEED"
fi

if [[ $STEP == all || $STEP == train ]]; then
    for model in "${MODELS[@]}"; do
        for k in $(seq 1 "$K"); do
            # embeddings of each fold's training clips are computed once and cached
            cache="$CV/cache/${model}_fold_${k}.npz"; mkdir -p "$CV/cache"
            for config in $CONFIGS; do
                out="$CV/models/$config/$model/fold_$k"; mkdir -p "$out"
                if [[ -f $cache ]]; then cache_args=(--cache_mode load --cache_file "$cache")
                else cache_args=(--cache_mode save --cache_file "$cache"); fi
                echo "=== train config $config, $model, fold $k ($(date +%T))"
                # shellcheck disable=SC2046
                (cd "$BIRDNET_DIR" && "$PY" "$PROJECT/scripts/train_birdnet.py" --seed "$SEED" \
                    "$CV/fold_$k/train_$model" -o "$out/$model" \
                    --val_split 0.2 --epochs "$EPOCHS" --crop_mode center --overlap 0 --audio_speed 1.0 \
                    --fmin $FMIN --fmax $FMAX --model_format tflite --model_save_mode replace \
                    --threads 16 "${cache_args[@]}" $(config_args "$config")) > "$out/${model}_training.log" 2>&1
                grep -E "early stopping|Best AUPRC" "$out/${model}_training.log" || true
            done
        done
    done
fi

classify() {  # $1 = model file, $2 = clips, $3 = output folder
    rm -rf "$3"; mkdir -p "$3"
    (cd "$BIRDNET_DIR" && "$PY" -m birdnet_analyzer.analyze "$2" -o "$3" --classifier "$1" \
        --fmin $FMIN --fmax $FMAX --overlap 0 --audio_speed 1.0 --merge_consecutive 1 \
        --min_conf 0.05 --rtype table --threads 16) > "$3.log" 2>&1
}

if [[ $STEP == all || $STEP == classify ]]; then
    for config in $CONFIGS; do
        for model in "${MODELS[@]}"; do
            for k in $(seq 1 "$K"); do
                echo "=== classify config $config, $model, fold $k ($(date +%T))"
                m="$CV/models/$config/$model/fold_$k/$model.tflite"
                c="$CV/classification/$config/$model/fold_$k"
                classify "$m" "$CV/fold_$k/heldout_2s" "$c/heldout"
                classify "$m" "$DATA/mimic_bellbird" "$c/focal"
            done
        done
    done
fi
