---
name: find-skills
description: Finds and fetches agent skills (SKILL.md) from the palladius/skills catalogue — 200+ skills aggregated from palladius and Google repos, searchable via a google/skills-compatible index.json. Use when you need a skill for a task (e.g. "is there a skill for Veo / GKE / Cloud Run?"), want to list skills by source or category, or want to read a SKILL.md by name without knowing which repo hosts it.
compatibility: Any agent with shell access (curl + jq). Works offline against a local dist/index.json too.
metadata:
  version: 0.1.0
  category: Meta
---
# find-skills — query the palladius/skills catalogue

The catalogue lives at **https://palladius.github.io/skills/** and exposes one JSON file:

```
https://palladius.github.io/skills/index.json
```

It is a strict superset of `google/skills`' `index.json`: every entry has `name`, `description`, `entrypoint` (raw `SKILL.md` URL) plus extras (`title`, `category`, `version`, `lines`, `updated_at`, `quality` 0–5, `source`, `tier`, `languages`, `install`).

## 1. Search

```bash
IDX=https://palladius.github.io/skills/index.json
# words must ALL appear in name/title/description (case-insensitive)
curl -sL $IDX | jq -r --arg q "veo" '
  .skills[] | select((.name + " " + .title + " " + .description) | ascii_downcase | contains($q | ascii_downcase))
  | "\(.quality)★ \(.name) [\(.source)] — \(.description[0:100])"' | sort -r
```

Narrow by source or category:

```bash
curl -sL $IDX | jq -r '.skills[] | select(.source=="google-skills" and .category=="Containers") | .name'
curl -sL $IDX | jq -r '.sources[] | "\(.skills_count)\t\(.id)\t\(.url)"'
```

## 2. Read a skill

```bash
NAME=nano-banana-ricc
curl -sL $IDX | jq -r --arg n "$NAME" '.skills[] | select(.name==$n) | .entrypoint' | xargs curl -sL
```

If two sources ship the same `name`, prefer the higher `quality`, then the newer `updated_at`, and tell the user there are duplicates (`id` is always unique: `<source>/<name>`).

## 3. Install for the user

Each entry carries a copy-pasteable `install` line, e.g.

```
npx skills add palladius/gemini-cli-palladius-public-goodies --skill nano-banana-ricc
```

Gemini CLI users can instead install the whole extension listed in `sources[].url` with `gemini extensions install <url>`.

## Notes

- Human-friendly permalink for any skill: `https://palladius.github.io/skills/#/s/<id>` (URL-encode the `/` in `id` as `%2F`).
- `quality` is deliberately simple: one point each for declared version, bundled scripts, updated in the last 90 days, 40–600 lines, 60–500 char description.
- The index is rebuilt nightly; `generated_at` tells you how fresh it is.
