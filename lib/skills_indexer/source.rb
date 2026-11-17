=begin
Source — one entry of sources.yaml: a git repo that contains skills.

  - id: google-skills                         # stable, URL-safe, used in skill ids
    url: https://github.com/google/skills     # git clone URL (also used to build permalinks)
    tier: public                              # public | palladius | google  (drives CSS)
    ref: main                                 # optional, default main
    path: ~/git/google-skills                 # optional local checkout (skips clone)
    optional: true                            # optional: if path is missing, skip instead of cloning
    web_base: https://host/.../repo           # optional, for non-GitHub hosts (Gitiles)
    exclude_skills: [foo, bar]                # optional AIR-GAP: never index these skill names
    exclude_content_regex: "secret|internal"  # optional AIR-GAP: skip any SKILL.md matching this

Resolution order for the working directory:
  1. explicit `path:`      2. <local_root>/<owner>-<repo> or <local_root>/<repo>      3. blobless clone into <workdir>/<id>
=end

module SkillsIndexer
  class Source
    attr_reader :id, :url, :tier, :ref, :web_base, :exclude_skills, :exclude_content_regex, :optional
    attr_accessor :dir, :excluded

    def initialize(h)
      @id = h.fetch("id")
      @url = h.fetch("url")
      @tier = (h["tier"] || :public).to_sym
      @ref = h["ref"] || "main"
      @web_base = h["web_base"]
      @path = h["path"]
      @optional = !!h["optional"]
      @exclude_skills = Array(h["exclude_skills"]).map(&:to_s)
      @exclude_content_regex = h["exclude_content_regex"] && Regexp.new(h["exclude_content_regex"], Regexp::IGNORECASE)
      @excluded = []   # skill names dropped by the air-gap rules (logged, never serialised)
      raise ArgumentError, "#{id}: tier must be one of #{TIERS}" unless TIERS.include?(@tier)
    end

    # Loads one or more sources*.yaml; later files override earlier entries with the same id.
    # Relative `path:` values resolve against the yaml file's own directory.
    def self.load(*yaml_paths)
      by_id = {}
      yaml_paths.flatten.each do |p|
        base = File.dirname(File.expand_path(p))
        YAML.safe_load_file(p).fetch("sources").each do |h|
          h = h.merge("path" => File.expand_path(h["path"], base)) if h["path"] && !h["path"].start_with?("~", "/")
          by_id[h.fetch("id")] = new(h)
        end
      end
      by_id.values
    end

    # --- location -----------------------------------------------------------

    PROJECT_ROOT = Pathname(File.expand_path("../..", __dir__))

    def resolve!(local_root: nil, workdir: "tmp/sources", dryrun: false, log: ->(_) {})
      # An explicit `path:` is trusted as-is (even if it's this very repo: we do index ourselves).
      explicit = @path && Pathname(File.expand_path(@path, PROJECT_ROOT))
      @dir = explicit if explicit&.directory?
      if @dir.nil? && local_root
        root = File.expand_path(local_root)
        guesses = [owner && File.join(root, "#{owner}-#{repo_name}"), File.join(root, repo_name)].compact
        # Guesses must never resolve to the project itself (google/skills vs palladius/skills!).
        @dir = guesses.map { Pathname(_1) }.find { _1.directory? && _1.realpath != PROJECT_ROOT.realpath }
      end
      if @dir.nil? && @optional
        log.("⏭️  #{id}: optional source not found locally, skipping")
        return self
      end
      @dir ||= clone_into(Pathname(workdir).join(id), dryrun:, log:)
      self
    end

    def available? = !dir.nil? && dir.directory?

    # Air-gap rule: true when this skill must NOT be indexed for this build.
    def excluded?(name:, content:)
      exclude_skills.include?(name) || (exclude_content_regex && content.match?(exclude_content_regex)) || false
    end

    def owner = github_slug&.split("/")&.first

    def github? = url.include?("github.com")

    # "https://github.com/google/skills.git" -> "google/skills"
    def github_slug = url[%r{github\.com[:/]([^/]+/[^/]+?)(?:\.git)?/?\z}, 1]

    def repo_name = url.split("/").last.sub(/\.git\z/, "")

    # --- permalinks -----------------------------------------------------------

    def raw_url(rel_path)
      return "https://raw.githubusercontent.com/#{github_slug}/#{ref}/#{rel_path}" if github?
      web_base ? "#{web_base}/+/refs/heads/#{ref}/#{rel_path}?format=TEXT" : nil
    end

    def blob_url(rel_path)
      return "https://github.com/#{github_slug}/blob/#{ref}/#{rel_path}" if github?
      web_base ? "#{web_base}/+/refs/heads/#{ref}/#{rel_path}" : nil
    end

    def homepage = github? ? "https://github.com/#{github_slug}" : (web_base || url)

    # --- metadata from manifest files -----------------------------------------

    MANIFESTS = %w[gemini-extension.json plugin.json .claude-plugin/plugin.json].freeze

    def manifest
      @manifest ||= MANIFESTS.lazy.map { |m| dir.join(m) }.find(&:exist?)&.then { |f| JSON.parse(f.read) rescue nil } || {}
    end

    def version = manifest["version"]
    def display_name = manifest["displayName"] || manifest["name"] || github_slug || repo_name
    def gemini_extension? = dir.join("gemini-extension.json").exist?

    # Paths declared in .gitmodules — we skip those (v1 decision, see PLAN roast #10).
    def submodule_paths
      gm = dir.join(".gitmodules")
      return [] unless gm.exist?
      gm.read.scan(/^\s*path\s*=\s*(.+)$/).flatten.map(&:strip)
    end

    # Note: excluded skill NAMES are deliberately not serialised (only the count) —
    # the whole point of the air-gap is that the other side never learns they exist.
    def to_h(skills_count:)
      {
        id:, url: homepage, tier:, ref:, name: display_name, version:,
        gemini_extension: gemini_extension?, skills_count:, excluded_count: excluded.size,
        skipped_submodules: submodule_paths
      }
    end

    private

    # Blobless partial clone: full commit history (so `git log -- <dir>` gives real
    # updated_at dates) but only HEAD's file contents are downloaded. `--depth 1`
    # would be smaller but makes every skill look like it changed today.
    def clone_into(target, dryrun:, log:)
      if target.join(".git").directory?
        log.("🔄 #{id}: pulling #{target}")
        sh("git", "-C", target.to_s, "pull", "--ff-only", "--quiet") unless dryrun
      else
        log.("⬇️  #{id}: cloning #{url} (#{ref}) → #{target}")
        FileUtils.mkdir_p(target.dirname)
        sh("git", "clone", "--filter=blob:none", "--single-branch", "--branch", ref, "--quiet", url, target.to_s) unless dryrun
      end
      target
    end

    def sh(*cmd)
      out, err, st = Open3.capture3(*cmd)
      raise "command failed: #{cmd.join(" ")}\n#{err}" unless st.success?
      out
    end
  end
end
