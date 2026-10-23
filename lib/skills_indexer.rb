=begin
skills_indexer — crawls a list of git repos, finds every SKILL.md, and emits
a single index.json (a strict superset of google/skills' index.json format)
plus a copy of each SKILL.md under content/.

  sources.yaml  ──►  Scanner ──► [Skill] ──► Writer ──► dist/index.json
                                                        dist/content/<id>.md
=end

require "json"
require "yaml"
require "pathname"
require "fileutils"
require "open3"
require "time"
require "date"

require_relative "skills_indexer/version"
require_relative "skills_indexer/source"
require_relative "skills_indexer/skill"
require_relative "skills_indexer/scanner"
require_relative "skills_indexer/writer"
require_relative "skills_indexer/compat"
require_relative "skills_indexer/marketplace"

module SkillsIndexer
  TIERS = %i[public ricc google].freeze

  # The three keys every entry MUST have to be readable by google/skills consumers.
  COMPAT_KEYS = %w[name description entrypoint].freeze
end
