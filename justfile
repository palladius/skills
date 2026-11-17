default:
    @just --list

# Lists your targets
list: default

# Run minitest suite (stdlib only, no bundler needed)
test:
    ruby -Ilib:test -e 'Dir["test/test_*.rb"].each { require File.expand_path(_1) }'

# Build the PUBLIC index into dist/ — reuses ~/git/<repo> checkouts when present, clones otherwise
index:
    bin/skills-indexer build --local-root ~/git -o dist -v

# Same as `index` but clone everything fresh under tmp/sources (what CI does)
index-ci:
    bin/skills-indexer build -o dist

# Dry run: resolve + scan, write nothing
dryrun:
    bin/skills-indexer build --local-root ~/git -n -v

# Check that upstream google/skills index.json still speaks our dialect
compat:
    bin/skills-indexer compat https://raw.githubusercontent.com/google/skills/main/index.json
    bin/skills-indexer compat dist/index.json

# Quick stats on the last build
stats:
    @jq -r '.sources[] | "\(.skills_count)\t\(.tier)\t\(.id)\t\(.version // "-")"' dist/index.json | column -t
    @jq -r '"TOTAL\t\(.skills | length) skills"' dist/index.json

# Serve dist/ locally on http://localhost:8787 (Ctrl-C to stop)
serve port="8787":
    @echo "🌍 http://localhost:{{port}}/#/?q=audio"
    ruby -run -e httpd dist -p {{port}}

# Regenerate .claude-plugin/ and .agents/plugins/ marketplace.json from sources.yaml (commit the result)
marketplace:
    bin/skills-indexer marketplace --local-root ~/git

# Download marked + DOMPurify into site/vendor/ (no CDN at runtime; commit the result once)
vendor:
    mkdir -p site/vendor
    curl -sSfL https://cdn.jsdelivr.net/npm/marked@12/marked.min.js -o site/vendor/marked.min.js
    curl -sSfL https://cdn.jsdelivr.net/npm/dompurify@3/dist/purify.min.js -o site/vendor/purify.min.js
    ls -lh site/vendor

# ---- Private tiers ---------------------------------------------------------------------------
# Tier B (💛 palladius) and tier C (🔵 google) are built from EXTRA sources files that live
# OUTSIDE this public repo. Pass them explicitly; later files override same ids and may add
# air-gap rules (exclude_skills / exclude_content_regex). Output dirs are gitignored.

# Build tier B: public + palladius-private sources  →  dist-private/
build-b extra="../gemini-cli-palladius-private-goodies/etc/skills-sources.b.yaml":
    bin/skills-indexer build -s sources.yaml -s {{extra}} --local-root ~/git -o dist-private -v

# Build tier C: public + corp sources  →  dist-corp/   (extra file lives in the corp skills repo)
build-c extra:
    bin/skills-indexer build -s sources.yaml -s {{extra}} --local-root ~/git -o dist-corp -v

# Publish a built dir to a plain static web root with 0755/0644 perms (cp, never cp -a: FUSE-safe)
publish-dir src dest:
    mkdir -p {{dest}} && find {{dest}} -mindepth 1 -delete
    (cd {{src}} && find . -type d -exec mkdir -p {{dest}}/{} \; && find . -type f -exec cp {} {{dest}}/{} \;)
    find {{dest}} -type d -exec chmod 755 {} + && find {{dest}} -type f -exec chmod 644 {} +
    @echo "📦 published {{src}} → {{dest}}"

# Deploy tier B to Cloud Run (nginx + Basic Auth, scale-to-zero). Needs BASIC_AUTH_PASS in env.
deploy-b project="ric-cccwiki" region="europe-west1" account="palladiusbonton@gmail.com": build-b
    test -n "$BASIC_AUTH_PASS" || { echo "set BASIC_AUTH_PASS first"; exit 1; }
    gcloud run deploy skills-private --source . --project {{project}} --region {{region}} --account {{account}} \
      --allow-unauthenticated --min-instances 0 --max-instances 1 --memory 128Mi \
      --set-env-vars BASIC_AUTH_USER=ricc,BASIC_AUTH_PASS="$BASIC_AUTH_PASS"
