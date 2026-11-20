"""Assign BirdNET training clips to cross-validation folds grouped by recording.

All clips of the train and test sets are pooled and split into k folds with
StratifiedGroupKFold: all clips of a recording fall in the same fold and the
folds are balanced by species. For each fold it builds (with symlinks):

    <out>/fold_<k>/train_sympatric_and_allopatric/<species>/   training clips, all species
    <out>/fold_<k>/train_sympatric/<species>/                  training clips, sympatric species
    <out>/fold_<k>/heldout_2s/                                 held-out clips, 2 s versions

and writes the assignment to <out>/folds.csv.

Usage: python birdnet_cv_folds.py <birdnet_data dir> <out dir> [--k 5] [--seed 123]
"""

import argparse
import csv
import os
import re
import shutil

import numpy as np
from sklearn.model_selection import StratifiedGroupKFold

SYMPATRIC = ["Procnias tricarunculatus", "Psarocolius montezuma", "Pteroglossus torquatus", "Ramphastos sulfuratus"]

p = argparse.ArgumentParser()
p.add_argument("data")
p.add_argument("out")
p.add_argument("--k", type=int, default=5)
p.add_argument("--seed", type=int, default=123)
a = p.parse_args()

data, out = os.path.abspath(a.data), os.path.abspath(a.out)

clips = []  # (clip file name, species, recording, source path)
for split in ["train_data", "test_data"]:
    for sp in sorted(os.listdir(os.path.join(data, split))):
        d = os.path.join(data, split, sp)
        if not os.path.isdir(d) or os.path.islink(d):
            continue
        for f in sorted(os.listdir(d)):
            if f.lower().endswith(".wav"):
                rec = re.sub(r"\.wav_\d+\.wav$", "", f, flags=re.I)
                clips.append((f, sp, rec, os.path.join(d, f)))

species = np.array([c[1] for c in clips])
groups = np.array([c[1] + "|" + c[2] for c in clips])
folds = np.zeros(len(clips), dtype=int)
sgkf = StratifiedGroupKFold(n_splits=a.k, shuffle=True, random_state=a.seed)
for k, (_, test_idx) in enumerate(sgkf.split(np.zeros(len(clips)), species, groups), start=1):
    folds[test_idx] = k

clips_2s = os.path.join(data, "sympatrics_and_allopatrics_2s")
missing = [c[0] for c in clips if not os.path.exists(os.path.join(clips_2s, c[0]))]
if missing:
    raise SystemExit(f"{len(missing)} clips have no 2 s version, e.g. {missing[:3]}")

if os.path.exists(out):
    for f in os.listdir(out):
        if f.startswith("fold_"):
            shutil.rmtree(os.path.join(out, f))
os.makedirs(out, exist_ok=True)

for k in range(1, a.k + 1):
    fd = os.path.join(out, f"fold_{k}")
    os.makedirs(os.path.join(fd, "heldout_2s"))
    for (f, sp, rec, src), fold in zip(clips, folds):
        if fold == k:
            os.symlink(os.path.join(clips_2s, f), os.path.join(fd, "heldout_2s", f))
        else:
            for model in ["sympatric_and_allopatric", "sympatric"]:
                if model == "sympatric" and sp not in SYMPATRIC:
                    continue
                td = os.path.join(fd, f"train_{model}", sp)
                os.makedirs(td, exist_ok=True)
                os.symlink(src, os.path.join(td, f))

with open(os.path.join(out, "folds.csv"), "w", newline="") as fh:
    w = csv.writer(fh)
    w.writerow(["clip", "species", "recording", "fold"])
    for (f, sp, rec, _), fold in zip(clips, folds):
        w.writerow([f, sp, rec, fold])

print(f"{len(clips)} clips, {len(set(groups))} recordings, {a.k} folds")
for k in range(1, a.k + 1):
    sel = folds == k
    print(f"fold {k}: {sel.sum()} clips, {len(set(groups[sel]))} recordings,",
          ", ".join(f"{sp.split()[1][:4]} {np.sum(species[sel] == sp)}" for sp in sorted(set(species))))
