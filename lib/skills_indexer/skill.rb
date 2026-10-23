=begin
Skill — everything we know about one SKILL.md, ready to be serialised.

The first three keys of #to_h (name, description, entrypoint) are *exactly*
google/skills' index.json format. Everything after is additive.

  id:          "<source>/<name>"  or  "<source>/<plugin>/<name>" when nested under plugins/
  category:    frontmatter metadata.category, else the folders between skills/ and the skill
  updated_at:  last git commit touching the folder (falls back to mtime)
=end

module SkillsIndexer
  class Skill
    FRONTMATTER = /\A---\s*\n(.*?)\n---\s*(?:\n|\z)/m
    LEADING_EMOJI = /\A\s*[(\[]?\s*(\p{Extended_Pictographic}\u{FE0F}?)\s*[)\]]?/
    LANGUAGES = {
      ".py" => :python, ".rb" => :ruby, ".sh" => :bash, ".bash" => :bash, ".js" => :javascript,
      ".mjs" => :javascript, ".ts" => :typescript, ".go" => :go, ".toml" => :toml,
      ".sql" => :sql, ".ipynb" => :jupyter, ".tf" => :terraform
    }.freeze
    IGNORED_PLUGIN_SEGMENTS = %w[plugins skills].freeze

    attr_reader :source, :dir, :rel_path, :meta, :body

    def initialize(source:, skill_md:)
      @source = source
      @dir = skill_md.dirname
      @rel_path = skill_md.relative_path_from(source.dir).to_s
      content = skill_md.read
      @meta = parse_frontmatter(content)
      @body = content.sub(FRONTMATTER, "")
      @lines = content.lines.count
      @size = content.bytesize
    end

    # --- compat core (google/skills) -----------------------------------------
    def name = (meta["name"] || dir.basename.to_s).to_s.strip
    def description = meta["description"].to_s.strip.then { _1.empty? ? title : _1 }
    def entrypoint = source.raw_url(rel_path)

    # --- extras -----------------------------------------------------------------
    def id = ([source.id] + plugin_segments + [dir.basename.to_s]).join("/")
    def title = body[/^#\s+(.+?)\s*$/, 1] || name
    def emoji = description[LEADING_EMOJI, 1]
    def version = (meta["version"] || meta.dig("metadata", "version"))&.to_s
    def compatibility = meta["compatibility"]
    def lines = @lines
    def size_bytes = @size
    def has_scripts = dir.join("scripts").directory?

    def category
      meta.dig("metadata", "category") || begin
        segs = path_segments
        i = segs.rindex("skills")
        between = i ? segs[(i + 1)...-1] : []
        between.empty? ? nil : between.join("/")
      end
    end

    def languages
      Dir.glob("**/*", base: dir).map { File.extname(_1) }.filter_map { LANGUAGES[_1] }.uniq.sort
    end

    def updated_at
      @updated_at ||= git_date || File.mtime(dir.join("SKILL.md")).strftime("%Y-%m-%d")
    end

    def install
      source.github? ? "npx skills add #{source.github_slug} --skill #{name}" : "agc skills install #{name} --global"
    end

    # A deliberately simple, explainable 0–5 "quality" score used to rank cards.
    # One point each for: declared version · bundled scripts · touched in the last
    # 90 days · a real body (40–600 lines) · a useful description (60–500 chars).
    def quality
      [
        !version.nil?,
        has_scripts,
        (Date.today - Date.parse(updated_at)).to_i <= 90,
        (40..600).cover?(lines),
        (60..500).cover?(description.length)
      ].count(true)
    end

    def to_h
      {
        name:, description:, entrypoint:,
        id:, title:, category:, emoji:, version:, lines:, size_bytes:, updated_at:,
        compatibility:, has_scripts:, languages:, quality:,
        source: source.id, tier: source.tier, path: rel_path,
        upstream_url: source.blob_url(rel_path),
        content_url: "content/#{id}.md",
        install:
      }
    end

    private

    def parse_frontmatter(content)
      yaml = content[FRONTMATTER, 1] or return {}
      YAML.safe_load(yaml, permitted_classes: [Date, Time]) || {}
    rescue Psych::SyntaxError
      {}
    end

    def path_segments = Pathname(rel_path).dirname.each_filename.to_a

    # For plugins/<area>/<plugin>/skills/<name> keep <plugin> so ids stay unique across plugins.
    def plugin_segments
      segs = path_segments
      return [] unless segs.first == "plugins"
      i = segs.index("skills") || segs.size
      segs[1...i].last(1)
    end

    def git_date
      out, st = Open3.capture2("git", "-C", source.dir.to_s, "log", "-1", "--format=%cs", "--", rel_path.sub(%r{/SKILL\.md\z}, ""), err: File::NULL)
      st.success? && !out.strip.empty? ? out.strip : nil
    end
  end
end
