"""Draw random hyperparameter configurations for the BirdNET cross-validation.

The search space is the one used by BirdNET-Analyzer's built-in tuner (--autotune,
birdnet_analyzer/train/utils.py, v2.4): hidden units, dropout, batch size with its own set of
learning rates, upsampling ratio and mode, mixup, label smoothing and focal loss (gamma and
alpha). Each configuration is written as the BirdNET training arguments it stands for.

Usage: python birdnet_random_search.py <out csv> [--n 30] [--seed 123]
"""

import argparse
import csv
import random

p = argparse.ArgumentParser()
p.add_argument("out")
p.add_argument("--n", type=int, default=30)
p.add_argument("--seed", type=int, default=123)
a = p.parse_args()

rng = random.Random(a.seed)
learning_rates = {
    8: [0.0005, 0.0002, 0.0001],
    16: [0.005, 0.002, 0.001, 0.0005, 0.0002],
    32: [0.01, 0.005, 0.001, 0.0005, 0.0001],
    64: [0.01, 0.005, 0.002, 0.001],
    128: [0.1, 0.01, 0.005],
}

rows = []
for i in range(1, a.n + 1):
    c = {
        "config": f"R{i:02d}",
        "hidden_units": rng.choice([0, 128, 256, 512, 1024, 2048]),
        "dropout": rng.choice([0.0, 0.25, 0.33, 0.5, 0.75, 0.9]),
        "batch_size": rng.choice([8, 16, 32, 64, 128]),
    }
    c["learning_rate"] = rng.choice(learning_rates[c["batch_size"]])
    c["upsampling_ratio"] = rng.choice([0.0, 0.25, 0.33, 0.5, 0.75, 1.0])
    c["upsampling_mode"] = rng.choice(["repeat", "mean", "linear"]) if c["upsampling_ratio"] > 0 else "repeat"
    c["mixup"] = rng.random() < 0.5
    c["label_smoothing"] = rng.random() < 0.5
    c["focal_loss"] = rng.random() < 0.5
    c["focal_loss_gamma"] = rng.choice([0.5, 1.0, 2.0, 3.0, 4.0]) if c["focal_loss"] else ""
    c["focal_loss_alpha"] = rng.choice([0.1, 0.25, 0.5, 0.75, 0.9]) if c["focal_loss"] else ""

    args = [f"--hidden_units {c['hidden_units']}", f"--dropout {c['dropout']}",
            f"--batch_size {c['batch_size']}", f"--learning_rate {c['learning_rate']}",
            f"--upsampling_mode {c['upsampling_mode']}", f"--upsampling_ratio {c['upsampling_ratio']}"]
    if c["mixup"]:
        args.append("--mixup")
    if c["label_smoothing"]:
        args.append("--label_smoothing")
    if c["focal_loss"]:
        args += ["--focal-loss", f"--focal-loss-gamma {c['focal_loss_gamma']}", f"--focal-loss-alpha {c['focal_loss_alpha']}"]
    c["args"] = " ".join(args)
    rows.append(c)

with open(a.out, "w", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
    w.writeheader()
    w.writerows(rows)
print(f"{len(rows)} configurations written to {a.out}")
