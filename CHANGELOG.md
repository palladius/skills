# Changelog

## 0.2.0 — 2026-10-12

- 🌐 P1: static site (`site/`): instant search with weighted scoring, agc-style cards, detail view rendering SKILL.md (marked + DOMPurify), source/tier filter chips, keyboard nav (`/`, ↑↓, Enter, Esc), tier colours via `data-tier`, dark mode.
- 🚀 P2: GitHub Pages workflow (push + nightly + manual) with test, build, upstream compat check and job summary.
- 🐛 Blobless partial clones instead of `--depth 1`: `updated_at` was HEAD's date for every skill in CI.
- `--site DIR` flag; `just serve`.

## 0.1.0 — 2026-10-12

- 🎉 P0: Ruby stdlib indexer (`bin/skills-indexer build|compat`), universal `SKILL.md` scanner (flat, nested, plugins; skips submodules).
- `index.json` is a strict superset of `google/skills` format (`name`, `description`, `entrypoint` + extras).
- `sources.yaml` with palladius custom-commands, palladius public-goodies, google/skills, google-gemini/gemini-skills (187 skills).
- Minitest suite with flat + nested fixtures and an upstream compat sample.
