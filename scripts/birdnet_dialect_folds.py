"""Assign the reference Three-wattled Bellbird clips to dialect cross-validation folds.

Clips of other bellbirds (data/processed/birdnet_cv_dialect/dialect_labels.csv, built from the
annotations: Monteverde, Nicaragua, Panama, Talamanca; babbling left out) are split into k folds
with StratifiedGroupKFold: all clips of a recording fall in the same fold and the folds are
balanced by dialect. For each fold it builds (with symlinks):

    <out>/fold_<k>/train_dialect/<dialect>/   training clips
    <out>/fold_<k>/heldout_2s/                held-out clips, 2 s versions

and writes the assignment to <out>/folds.csv.

Usage: python birdnet_dialect_folds.py <birdnet_data dir> <out dir> [--k 5] [--seed 123]
"""

import argparse
import csv
import os
import shutil

import numpy as np
from sklearn.model_selection import StratifiedGroupKFold

p = argparse.ArgumentParser()
p.add_argument("data")
p.add_argument("out")
p.add_argument("--k", type=int, default=5)
p.add_argument("--seed", type=int, default=123)
a = p.parse_args()

data, out = os.path.abspath(a.data), os.path.abspath(a.out)
labels = list(csv.DictReader(open(os.path.join(out, "dialect_labels.csv"))))


def source(clip):
    for split in ["train_data", "test_data"]:
        f = os.path.join(data, split, "Procnias tricarunculatus", clip)
        if os.path.exists(f):
            return f
    raise SystemExit(f"clip not found: {clip}")


clips = [(r["clip"], r["dialect"], r["recording"], source(r["clip"])) for r in labels]
dialect = np.array([c[1] for c in clips])
groups = np.array([c[2] for c in clips])
folds = np.zeros(len(clips), dtype=int)
sgkf = StratifiedGroupKFold(n_splits=a.k, shuffle=True, random_state=a.seed)
for k, (_, test_idx) in enumerate(sgkf.split(np.zeros(len(clips)), dialect, groups), start=1):
    folds[test_idx] = k

clips_2s = os.path.join(data, "sympatrics_and_allopatrics_2s")
for f in os.listdir(out):
    if f.startswith("fold_"):
        shutil.rmtree(os.path.join(out, f))

for k in range(1, a.k + 1):
    fd = os.path.join(out, f"fold_{k}")
    os.makedirs(os.path.join(fd, "heldout_2s"))
    for (f, d, rec, src), fold in zip(clips, folds):
        if fold == k:
            os.symlink(os.path.join(clips_2s, f), os.path.join(fd, "heldout_2s", f))
        else:
            td = os.path.join(fd, "train_dialect", d)
            os.makedirs(td, exist_ok=True)
            os.symlink(src, os.path.join(td, f))

with open(os.path.join(out, "folds.csv"), "w", newline="") as fh:
    w = csv.writer(fh)
    w.writerow(["clip", "species", "recording", "fold"])
    for (f, d, rec, _), fold in zip(clips, folds):
        w.writerow([f, d, rec, fold])

print(f"{len(clips)} clips, {len(set(groups))} recordings, {a.k} folds")
for k in range(1, a.k + 1):
    sel = folds == k
    print(f"fold {k}: {sel.sum()} clips, {len(set(groups[sel]))} recordings,",
          ", ".join(f"{d} {np.sum(dialect[sel] == d)} ({len(set(groups[sel & (dialect == d)]))} rec.)" for d in sorted(set(dialect))))
