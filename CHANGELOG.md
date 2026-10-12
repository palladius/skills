# Changelog

## 0.1.0 — 2026-10-12

- 🎉 P0: Ruby stdlib indexer (`bin/skills-indexer build|compat`), universal `SKILL.md` scanner (flat, nested, plugins; skips submodules).
- `index.json` is a strict superset of `google/skills` format (`name`, `description`, `entrypoint` + extras).
- `sources.yaml` with palladius custom-commands, palladius public-goodies, google/skills, google-gemini/gemini-skills (187 skills).
- Minitest suite with flat + nested fixtures and an upstream compat sample.
