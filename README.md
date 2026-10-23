# 🧭 palladius/skills

> Type `audio` → *puff!* → every skill that matches, with title, description, version, lines, date and a permalink.

A static, searchable catalogue of agent skills (`SKILL.md`) aggregated from many git repos — mine and others' — published at **https://palladius.github.io/skills**.

The generated [`index.json`](https://palladius.github.io/skills/index.json) is a **strict superset of [`google/skills`](https://github.com/google/skills)' `index.json`**: anything that reads theirs can read mine.

## How it works

```
sources.yaml ──► bin/skills-indexer ──► dist/index.json  +  dist/content/<id>.md ──► site/ (vanilla JS)
```

- A folder is a skill **iff** it contains a `SKILL.md`. No depth heuristics: works for `skills/<name>/`, `skills/<category>/<name>/` (google/skills style) and `plugins/**/skills/<name>/`.
- Every skill gets a stable id `<source>/<name>` (or `<source>/<plugin>/<name>` inside plugins), so same-named skills from different places coexist.
- Ruby **stdlib only** (no Bundler): runs anywhere Ruby ≥ 3.2 is.

## Usage

```bash
just test          # minitest suite
just index         # build dist/ reusing ~/git/<repo> checkouts (fast, local)
just index-ci      # build dist/ cloning everything shallow under tmp/ (what CI does)
just compat        # validate upstream google/skills index.json AND ours
just stats         # per-source counts
bin/skills-indexer -h
```

### Adding a source

Append to [`sources.yaml`](sources.yaml):

```yaml
  - id: my-skills                       # stable; used in permalinks
    url: https://github.com/me/my-skills
    tier: public                        # public | ricc | google (drives the CSS colour)
    # ref: main                         # optional
    # path: ~/git/my-skills             # optional local checkout
```

## `index.json` schema (v1)

The first three keys are exactly google/skills' format; everything else is additive.

| key | meaning |
|---|---|
| `name`, `description`, `entrypoint` | **compat core** — `entrypoint` is the raw `SKILL.md` URL |
| `id` | `<source>/<name>` or `<source>/<plugin>/<name>` |
| `title` | first `# H1` of the body (fallback: `name`) |
| `category` | `metadata.category` from frontmatter, else the folders between `skills/` and the skill |
| `emoji` | leading emoji of the description, if any |
| `version`, `compatibility` | from frontmatter (`version` or `metadata.version`) |
| `lines`, `size_bytes`, `updated_at` | `SKILL.md` lines/bytes, last git commit date touching the folder |
| `has_scripts`, `languages` | presence of `scripts/`, languages inferred from file extensions |
| `quality` | 0–5, one point each for: declared version · bundled scripts · updated in the last 90 days · 40–600 lines · 60–500 char description. Used to rank cards; deliberately dumb and explainable |
| `source`, `tier`, `path`, `upstream_url`, `content_url`, `install` | provenance + permalinks + a copy-pasteable install line |

## Install as a marketplace / skill package

The repo ships the same two manifests as `google/skills`, generated from `sources.yaml` (`just marketplace`):

| Harness | Command |
|---|---|
| Claude Code | `claude plugin marketplace add palladius/skills` |
| Codex | `codex plugin marketplace add palladius/skills` |
| skills.sh | `npx skills add palladius/skills` (installs [`find-skills`](skills/find-skills/SKILL.md), a skill that teaches an agent to query this catalogue) |
| Gemini CLI | `gemini extensions install <url>` for any `sources[].url` that is an extension |

## Private builds

Private sources (`tier: ricc` / `tier: google`) live in a `sources.private.yaml` that is **never committed** (see `.gitignore`); the resulting `dist-private/` is deployed separately behind IAP. The public site never sees them.

## License

Apache-2.0 — © Riccardo Carlesso
