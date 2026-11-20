#!/usr/bin/env bash
# Train the two custom BirdNET classifiers from the command line (instead of the GUI)
# and classify the clips with them.
#
# Hyperparameters are those the GUI stored in
#   data/processed/birdnet_models/<model>/<model>_Params.csv
# Training is seeded (SEED, default 123) through scripts/train_birdnet.py.
#
# Run from the project root:
#   bash scripts/train_birdnet_models.sh [train|classify|all]
# Outputs:
#   data/processed/birdnet_models_cli/<model>/                      trained models
#   data/processed/birdnet_classification_outputs_cli/<clips>/<model>/  selection tables
set -euo pipefail

PY=${BIRDNET_PY:-$HOME/mambaforge/envs/birdnet_env/bin/python}
BIRDNET_DIR=${BIRDNET_DIR:-$HOME/BirdNET-Analyzer}
SEED=${SEED:-123}
EPOCHS=${EPOCHS:-50}   # not stored in the GUI params file; 50 is the BirdNET default
STEP=${1:-all}

PROJECT=$(pwd)
DATA=$PROJECT/data/processed/birdnet_data
MODELS=$PROJECT/data/processed/birdnet_models_cli
CLASS=$PROJECT/data/processed/birdnet_classification_outputs_cli

# sympatric species only: symlinked subset of the train/test folders
SYMP=("Procnias tricarunculatus" "Psarocolius montezuma" "Pteroglossus torquatus" "Ramphastos sulfuratus")
for split in train_data test_data; do
    rm -rf "$DATA/sympatric_$split"; mkdir -p "$DATA/sympatric_$split"
    for sp in "${SYMP[@]}"; do ln -s "$DATA/$split/$sp" "$DATA/sympatric_$split/$sp"; done
done

train() {  # $1 = model name, $2 = train folder, $3 = test folder, rest = model hyperparameters
    local name=$1 train_dir=$2 test_dir=$3; shift 3
    mkdir -p "$MODELS/$name"
    echo "=== training $name, seed $SEED ($(date))"
    # run from the BirdNET-Analyzer checkout so the package and its checkpoints are found
    (cd "$BIRDNET_DIR" && "$PY" "$PROJECT/scripts/train_birdnet.py" --seed "$SEED" "$train_dir" \
        --test_data "$test_dir" -o "$MODELS/$name/$name" \
        --epochs "$EPOCHS" --crop_mode center --overlap 0 --audio_speed 1.0 \
        --model_format tflite --model_save_mode replace --threads 16 "$@") \
        2>&1 | tee "$MODELS/$name/${name}_training.log"
}

classify() {  # $1 = model name, $2 = clip folder, $3 = output folder
    local name=$1 clips=$2 out=$3
    rm -rf "$out"; mkdir -p "$out"
    echo "=== classifying $clips with $name ($(date))"
    # same settings as the GUI runs (BirdNET_analysis_params.csv): 400-12000 Hz bandpass,
    # no overlap, consecutive detections merged, minimum confidence 0.05
    (cd "$BIRDNET_DIR" && "$PY" -m birdnet_analyzer.analyze "$clips" -o "$out" \
        --classifier "$MODELS/$name/$name.tflite" \
        --fmin 400 --fmax 12000 --overlap 0 --audio_speed 1.0 --merge_consecutive 1 \
        --min_conf 0.05 --rtype table --threads 16) > "$out/../${name}_classification.log" 2>&1
}

if [[ $STEP == all || $STEP == train ]]; then
    train sympatric_and_allopatric "$DATA/train_data" "$DATA/test_data" \
        --hidden_units 2048 --dropout 0.5 --batch_size 64 --learning_rate 0.001 \
        --upsampling_mode repeat --upsampling_ratio 0 \
        --mixup --focal-loss --focal-loss-alpha 0.75 --focal-loss-gamma 0.5
    train sympatric "$DATA/sympatric_train_data" "$DATA/sympatric_test_data" \
        --hidden_units 256 --dropout 0.5 --batch_size 16 --learning_rate 0.002 \
        --upsampling_mode repeat --upsampling_ratio 0.33 \
        --mixup
fi

if [[ $STEP == all || $STEP == classify ]]; then
    # 2 s versions of all train and test clips (as the GUI runs; the test clips are kept
    # downstream, and for the sympatric model only sympatric species) and focal bellbird clips
    classify sympatric_and_allopatric "$DATA/sympatrics_and_allopatrics_2s" "$CLASS/sympatrics_and_allopatrics_2s/sympatric_and_allopatric"
    classify sympatric                "$DATA/sympatrics_and_allopatrics_2s" "$CLASS/sympatrics_and_allopatrics_2s/sympatric"
    classify sympatric_and_allopatric "$DATA/mimic_bellbird"       "$CLASS/mimic_bellbird/sympatric_and_allopatric"
    classify sympatric                "$DATA/mimic_bellbird"       "$CLASS/mimic_bellbird/sympatric"
fi
