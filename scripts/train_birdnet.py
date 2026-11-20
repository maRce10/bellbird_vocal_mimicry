"""Train a custom BirdNET classifier with a fixed random seed.

Wraps `python -m birdnet_analyzer.train` (same arguments) and, before training,
seeds Python, NumPy and TensorFlow (weights, shuffling, dropout, mixup) and
turns on deterministic TensorFlow ops. It also writes the per-epoch training
history to `<output>_history.csv`.

Usage (from the BirdNET-Analyzer checkout, with its environment):
    python train_birdnet.py --seed 123 <birdnet_analyzer.train arguments>
"""

import argparse
import csv
import os
import random
import sys

seed_parser = argparse.ArgumentParser(add_help=False)
seed_parser.add_argument("--seed", type=int, default=123)
seed_args, birdnet_argv = seed_parser.parse_known_args()

os.environ["PYTHONHASHSEED"] = str(seed_args.seed)
os.environ["TF_DETERMINISTIC_OPS"] = "1"

import numpy as np  # noqa: E402
import tensorflow as tf  # noqa: E402

random.seed(seed_args.seed)
np.random.seed(seed_args.seed)
tf.keras.utils.set_random_seed(seed_args.seed)
tf.config.experimental.enable_op_determinism()

import birdnet_analyzer.config as cfg  # noqa: E402
from birdnet_analyzer import cli, model, train  # noqa: E402

# BirdNET's own NumPy generators (upsampling, mixup, validation split) use cfg.RANDOM_SEED
cfg.RANDOM_SEED = seed_args.seed

args = cli.train_parser().parse_args(birdnet_argv)

# keep the Keras history of the final training run
_train_linear_classifier = model.train_linear_classifier


def _train_and_save_history(*a, **k):
    classifier, history = _train_linear_classifier(*a, **k)
    path = args.output.removesuffix(".tflite") + "_history.csv"
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    keys = list(history.history.keys())
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["epoch", *keys])
        for i in range(len(history.epoch)):
            w.writerow([i + 1, *[history.history[key][i] for key in keys]])
    return classifier, history


model.train_linear_classifier = _train_and_save_history

print(f"Random seed: {seed_args.seed}", flush=True)
train(**vars(args))
sys.exit(0)
