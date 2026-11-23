# Changelog

## 0.5.2 — 2026-11-23

- 🔒 Upgrade Tier B container base image from `nginx:1.27-alpine` to `nginx:alpine` (Alpine 3.24+, `brotli-libs` 1.2.1+, `libssl3`/`libcrypto3` 3.5.9+) with `apk upgrade --no-cache` to remediate brotli and OpenSSL CVEs.

## 0.5.1 — 2026-11-18

- ⚠️ Air-gap `warn_content_regex` support per source (`SkillsIndexer::Source#warn_matches`, `Scanner`, `bin/skills-indexer`): logs soft warnings during builds without excluding matching skills.

## 0.5.0 — 2026-11-17

- 🔱 P4: three-tier privacy model (public ⚪ / palladius 💛 / google 🔵) as a V, not a chain. Tier `ricc` renamed to `palladius`.
- 🚧 Air-gap rules per source: `exclude_skills` + `exclude_content_regex` drop skills before indexing; only `excluded_count` is serialised.
- 🧩 `-s` is repeatable; later files override same ids; relative `path:` resolves against the yaml; `optional: true` skips missing local sources instead of cloning.
- 🐳 Tier B: `Dockerfile` + nginx Basic Auth (fails closed without `BASIC_AUTH_PASS`), `just build-b` / `just deploy-b` (Cloud Run scale-to-zero). `.dockerignore` admits only `dist-private/` + `deploy/`.
- 🗄️ Tier C: `just build-c` + `just publish-dir` (FUSE-safe cp + 0755/0644).
- 🔗 Scanner uses explicit-depth globs so symlinked skill folders are followed (`**` never was).
- 🛡️ Site hardening for `Origin: null` sandboxes: `index.js` inline data (fetch fallback), `history.replaceState` in try/catch, marked + DOMPurify vendored (`just vendor`) with CDN fallback.

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
