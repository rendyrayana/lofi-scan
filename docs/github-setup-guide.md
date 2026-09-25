# GitHub Repo Setup Guide

Companion to `psx-converter-spec.md`. This covers repo hygiene specifically —
what to commit, what to exclude, and how to prepare `lofi-scan` for an
eventual public release without leaking data or creating a messy history.

## 1. Repository visibility

- Create the repo as **private** initially.
- Only flip to public once: a working version exists per the build order in
  the main spec, and the owner has confirmed it fits their publication plans
  (see spec doc — this affects timing, not code structure).
- Note for later: if any scan data or output is ever accidentally committed
  before the repo goes public, deleting it in a later commit is **not**
  enough — git history retains it. It would need to be stripped from full
  history (e.g. via `git filter-repo`) before making the repo public. Best
  avoided entirely by getting `.gitignore` right from the very first commit.

## 2. `.gitignore` — required from the first commit, before `git add .`

```gitignore
# Raw scan data (ownership/rights unclear — never publish by default)
/scans/
/raw_scans/

# Generated pipeline outputs (regenerable, often large binaries)
/cache/
/video_out/
*.blend1
*.blend2

# Manifests (including per-object thumbnails) ARE intended to be committed —
# they're the evidence behind the recognizability scores and are core to the
# research value of this repo. See section 3a for the one-time review step
# before any thumbnail goes public.

# Python
__pycache__/
*.pyc
.venv/
venv/

# Godot
.godot/
*.import

# OS/editor cruft
.DS_Store
Thumbs.db
.vscode/
```

## 3a. Manifest thumbnails — included, with one manual check

Thumbnails are kept in the repo (not gitignored) since they're the visual
evidence behind each tier's recognizability score — without them the
manifest is just numbers with no way to verify them. Before the repo goes
public, do one pass over `/manifests/` and confirm every scanned object is
one the owner is comfortable showing publicly (e.g. nothing that belongs to
someone else, nothing personally identifying beyond the object itself). This
is a one-time manual review, not something to automate away — the guide's
job is to make sure it happens, not to guess the answer.

## 3. LICENSE

- Default to **MIT** — simple, permissive, standard for research/dev tooling.
- One thing to flag before finalizing (not a substitute for actual legal
  advice, just worth checking): the pipeline calls Blender as an external
  **subprocess**, which is generally treated differently from linking its
  libraries directly — invoking a GPL-licensed program via command line
  typically does not impose GPL terms on your own code. If `pymeshlab` (also
  GPL) is ever imported as a Python **library** rather than shelled out to,
  that's a different situation worth re-checking before locking in a license.
- Add the LICENSE file at the repo root before the first public-facing push.

## 4. README structure

```
# lofi-scan

One-line description: automated pipeline converting 3D scans into
recognizability-calibrated PSX-style low-poly/low-res assets.

## What it does
(short paragraph — no proprietary tools required, per-object adaptive
parameter search rather than fixed presets)

## Architecture
(brief summary + link to docs/psx-converter-spec.md for full detail)

## Requirements
- Python 3.10+
- Blender (version)
- Godot (version)
- ffmpeg

## Setup
(install steps)

## Usage
(how to run: upload -> process -> preview -> export)

## Folder structure
(short version of spec section 7)

## License
MIT — see LICENSE

## Design rationale / full spec
See docs/psx-converter-spec.md
```

Leave a placeholder near the top for a screenshot or short GIF once the UI
exists — repos with a visible screenshot are dramatically easier for others
(or future you) to parse at a glance.

## 5. Initial commit checklist

Commit these together as the first commit — scaffolding only, no generated
output:
- `.gitignore` (must exist before anything else is added)
- `LICENSE`
- `README.md`
- `docs/psx-converter-spec.md` (the design spec)
- `godot_app/shaders/psx_shader.gdshader`
- Empty folder structure from spec section 7, using `.gitkeep` files so
  empty dirs (`/cache`, `/video_out`) still show up in the repo even though
  their contents are gitignored. `/manifests/` is not gitignored — its
  contents (including thumbnails) will be added as the pipeline generates
  real results.

## 6. Commit hygiene going forward

- One commit per milestone from the spec's build order (section 9), with a
  message referencing the milestone (e.g. "Milestone 1: Blender decimate+bake
  script working on test scan") — keeps history readable and maps directly
  back to the spec.
- No need for branches/tags for a solo project unless it grows a
  collaborator — keep it simple until there's a reason not to.

## 7. Pre-public checklist (run once, right before flipping visibility)

- [ ] `git log --all --stat` (or similar) reviewed to confirm no raw scan
      data or `/cache` output ever entered history
- [ ] Every thumbnail in `/manifests/` manually reviewed and approved for
      public display (section 3a)
- [ ] LICENSE present and correct
- [ ] README complete, links resolve, requirements list is accurate
- [ ] Fresh clone into a temp folder, follow the README from scratch with no
      prior context — confirms nothing required is missing or assumed
