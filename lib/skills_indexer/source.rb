=begin
Source — one entry of sources.yaml: a git repo that contains skills.

  - id: google-skills                         # stable, URL-safe, used in skill ids
    url: https://github.com/google/skills     # git clone URL (also used to build permalinks)
    tier: public                              # public | ricc | google  (drives CSS)
    ref: main                                 # optional, default main
    path: ~/git/google-skills                 # optional local checkout (skips clone)
    web_base: https://host/.../repo           # optional, for non-GitHub hosts (Gitiles)

Resolution order for the working directory:
  1. explicit `path:`      2. <local_root>/<repo basename> if it exists      3. shallow clone into <workdir>/<id>
=end

module SkillsIndexer
  class Source
    attr_reader :id, :url, :tier, :ref, :web_base
    attr_accessor :dir

    def initialize(h)
      @id = h.fetch("id")
      @url = h.fetch("url")
      @tier = (h["tier"] || :public).to_sym
      @ref = h["ref"] || "main"
      @web_base = h["web_base"]
      @path = h["path"]
      raise ArgumentError, "#{id}: tier must be one of #{TIERS}" unless TIERS.include?(@tier)
    end

    def self.load(yaml_path)
      YAML.safe_load_file(yaml_path).fetch("sources").map { |h| new(h) }
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
      @dir ||= clone_into(Pathname(workdir).join(id), dryrun:, log:)
      self
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

    def to_h(skills_count:)
      {
        id:, url: homepage, tier:, ref:, name: display_name, version:,
        gemini_extension: gemini_extension?, skills_count:,
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
