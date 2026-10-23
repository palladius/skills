# Changelog

## 0.4.0 — 2026-10-23

- 🛒 P3: `bin/skills-indexer marketplace` emits `.claude-plugin/marketplace.json` + `.agents/plugins/marketplace.json` (google/skills format); CI fails if they drift from `sources.yaml`.
- 🪞 The repo now indexes itself: `skills/find-skills` teaches any agent to search/fetch skills from the catalogue via `index.json`.
- 🐛 Explicit `path:` in `sources.yaml` is trusted even when it points at this repo (the self-indexing guard now only applies to `--local-root` guesses).
- CI: non-blocking `npx skills add palladius/skills --list` smoke test, shown in the job summary.

## 0.3.1 — 2026-10-23

- 🐛 `Skill#description` now falls back to `title` if an upstream `SKILL.md` frontmatter is missing or has an empty `description`, preventing CI compat failures when upstream repos add malformed YAML frontmatter.
- 🎲 Indexed `gws-readonly-usage` and `presentation-that-riccardo-likes` from `palladius-public-goodies` for DevFest Prague 2026 ("Steal My Skill").

## 0.3.0 — 2026-10-14

- 🐛 Typing in the search box while a skill detail is open now leaves the detail and shows results (you were stuck on the skill).
- 🧱 Results are a responsive card grid (1–4 columns, `auto-fill minmax(300px)`), 3-line clamped descriptions.
- ⭐ New `quality` field (0–5) in `index.json`; cards sorted by match → quality → date → name, stars shown on cards and detail.

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
