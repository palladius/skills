=begin
Marketplace — emits the two plugin-marketplace manifests that google/skills ships,
so `palladius/skills` can be added as a marketplace by Claude Code / Codex / agy:

  .claude-plugin/marketplace.json   { name, owner, metadata, plugins:[{name, source:{source:"github", repo, ref}, description}] }
  .agents/plugins/marketplace.json  { name, plugins:[{name, source:{source:"url", url, ref}, description, policy, category}] }

One plugin entry per source that is an installable extension/plugin (has a manifest).
Pure aggregators like google/skills (no root manifest) are skipped.
=end

module SkillsIndexer
  module Marketplace
    module_function

    NAME = "palladius-skills"
    OWNER = {name: "Riccardo Carlesso", url: "https://github.com/palladius"}.freeze
    DESCRIPTION = "Riccardo's catalogue of agent skills and Gemini CLI extensions, plus upstream Google skill repos. Browse at https://palladius.github.io/skills"

    # Only sources that are themselves installable (have a plugin/extension manifest).
    # Pure aggregators like google/skills have no root manifest and are skipped.
    def entries(sources)
      sources.select { _1.github? && _1.manifest.any? }.map do |s|
        {
          name: s.id,
          repo: s.github_slug,
          url: "https://github.com/#{s.github_slug}.git",
          ref: s.ref,
          description: s.manifest["description"] || "Skills from #{s.github_slug}",
          category: s.tier == :public ? "Skills" : "Private"
        }
      end
    end

    def claude(sources)
      {
        name: NAME, owner: OWNER,
        metadata: {version: VERSION, description: DESCRIPTION},
        plugins: entries(sources).map { |e|
          {name: e[:name], source: {source: "github", repo: e[:repo], ref: e[:ref]}, description: e[:description]}
        }
      }
    end

    def agents(sources)
      {
        name: NAME,
        plugins: entries(sources).map { |e|
          {name: e[:name], source: {source: "url", url: e[:url], ref: e[:ref]}, description: e[:description],
           policy: {installation: "AVAILABLE", authentication: "ON_INSTALL"}, category: e[:category]}
        }
      }
    end

    # Writes both files under root (the repo root, not dist/ — marketplaces are read from the repo).
    def write(sources, root:)
      {".claude-plugin/marketplace.json" => claude(sources), ".agents/plugins/marketplace.json" => agents(sources)}.map do |rel, doc|
        path = Pathname(root).join(rel)
        FileUtils.mkdir_p(path.dirname)
        path.write(JSON.pretty_generate(doc) + "\n")
        path
      end
    end
  end
end
