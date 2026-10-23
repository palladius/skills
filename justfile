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
