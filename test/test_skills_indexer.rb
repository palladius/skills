=begin
Tests for skills_indexer — stdlib minitest only.  Run with:  just test
Fixtures mimic (a) a flat Gemini extension and (b) a google/skills-like nested repo.
=end

require "minitest/autorun"
require "tmpdir"
require "skills_indexer"

FIXTURES = Pathname(__dir__).join("fixtures")

def fixture_source(name, **extra)
  SkillsIndexer::Source.new({
    "id" => name, "url" => "https://github.com/acme/#{name}", "tier" => "public",
    "path" => FIXTURES.join(name).to_s
  }.merge(extra)).resolve!
end

class TestSource < Minitest::Test
  def test_github_slug_and_urls
    s = fixture_source("flat-ext")
    assert_equal "acme/flat-ext", s.github_slug
    assert_equal "https://raw.githubusercontent.com/acme/flat-ext/main/skills/x/SKILL.md", s.raw_url("skills/x/SKILL.md")
    assert_equal "https://github.com/acme/flat-ext/blob/main/skills/x/SKILL.md", s.blob_url("skills/x/SKILL.md")
    assert s.gemini_extension?
    assert_equal "1.2.3", s.version
    assert_equal "Flat Extension", s.display_name
  end

  def test_gitiles_urls_for_non_github
    s = SkillsIndexer::Source.new("id" => "gitiles", "url" => "https://git.example.com/me/repo.git", "tier" => "google",
      "path" => FIXTURES.join("flat-ext").to_s, "web_base" => "https://git.example.com/me/repo").resolve!
    assert_equal "https://git.example.com/me/repo/+/refs/heads/main/skills/x/SKILL.md", s.blob_url("skills/x/SKILL.md")
    assert_match(/format=TEXT/, s.raw_url("skills/x/SKILL.md"))
    refute s.github?
  end

  def test_rejects_unknown_tier
    assert_raises(ArgumentError) { SkillsIndexer::Source.new("id" => "x", "url" => "u", "tier" => "secret") }
  end

  def test_submodule_paths
    assert_equal ["plugins/area/sub"], fixture_source("nested").submodule_paths
    assert_empty fixture_source("flat-ext").submodule_paths
  end

  def test_local_root_prefers_owner_dash_repo
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, "acme-flat-ext"))
      FileUtils.mkdir_p(File.join(root, "flat-ext"))
      s = SkillsIndexer::Source.new("id" => "f", "url" => "https://github.com/acme/flat-ext", "tier" => "public")
      s.resolve!(local_root: root)
      assert_equal "acme-flat-ext", s.dir.basename.to_s
    end
  end
end

class TestScanner < Minitest::Test
  def test_flat_layout_finds_only_folders_with_skill_md
    names = SkillsIndexer::Scanner.new(fixture_source("flat-ext")).skills.map(&:name)
    assert_equal %w[alpha beta], names
  end

  def test_nested_layout_skips_submodules_and_test_dirs
    ids = SkillsIndexer::Scanner.new(fixture_source("nested")).skills.map(&:id)
    assert_equal %w[nested/plug/gamma nested/gamma], ids
  end

  # --- AIR-GAP: skills excluded by name or content never reach the index ---------------
  def test_exclude_skills_by_name
    src = fixture_source("flat-ext", "exclude_skills" => ["alpha"])
    assert_equal %w[beta], SkillsIndexer::Scanner.new(src).skills.map(&:name)
    assert_equal %w[alpha], src.excluded
  end

  def test_exclude_skills_by_content_regex_is_case_insensitive
    src = fixture_source("flat-ext", "exclude_content_regex" => "ALPHA DOES")
    assert_equal %w[beta], SkillsIndexer::Scanner.new(src).skills.map(&:name)
    assert_equal %w[alpha], src.excluded
  end

  def test_warn_content_regex_logs_warning_without_excluding
    src = fixture_source("flat-ext", "warn_content_regex" => "BETA HAS NO")
    skills = SkillsIndexer::Scanner.new(src).skills
    assert_equal %w[alpha beta], skills.map(&:name)
    assert_empty src.excluded
    assert_equal 1, src.warned.size
    assert_match(/beta/, src.warned.first)
  end

  def test_excluded_names_never_serialised_only_count
    src = fixture_source("flat-ext", "exclude_skills" => ["alpha"])
    SkillsIndexer::Scanner.new(src).skills
    h = src.to_h(skills_count: 1)
    assert_equal 1, h[:excluded_count]
    refute_match(/alpha/, JSON.generate(h))
  end

  def test_optional_missing_source_is_skipped_not_cloned
    src = SkillsIndexer::Source.new("id" => "ghost", "url" => "https://github.com/acme/ghost", "tier" => "palladius",
      "path" => "/nonexistent/ghost", "optional" => true).resolve!
    refute src.available?
    assert_empty SkillsIndexer::Scanner.new(src).skills
  end

  def test_load_merges_multiple_files_later_wins
    Dir.mktmpdir do |d|
      File.write("#{d}/a.yaml", {"sources" => [{"id" => "x", "url" => "https://github.com/a/x", "tier" => "public"}, {"id" => "y", "url" => "https://github.com/a/y"}]}.to_yaml)
      File.write("#{d}/b.yaml", {"sources" => [{"id" => "x", "url" => "https://github.com/a/x", "tier" => "palladius", "exclude_skills" => ["s"]}]}.to_yaml)
      srcs = SkillsIndexer::Source.load("#{d}/a.yaml", "#{d}/b.yaml")
      assert_equal %w[x y], srcs.map(&:id)
      assert_equal :palladius, srcs[0].tier
      assert_equal ["s"], srcs[0].exclude_skills
    end
  end
end

class TestSkill < Minitest::Test
  def setup
    @alpha, @beta = SkillsIndexer::Scanner.new(fixture_source("flat-ext")).skills
    @plug_gamma, @gamma = SkillsIndexer::Scanner.new(fixture_source("nested")).skills
  end

  def test_compat_core_keys_come_first
    assert_equal SkillsIndexer::COMPAT_KEYS, @alpha.to_h.keys.first(3).map(&:to_s)
  end

  def test_frontmatter_fields
    assert_equal "alpha", @alpha.name
    assert_equal "(💛) Alpha does alpha things.", @alpha.description
    assert_equal "0.7", @alpha.version
    assert_equal "Gemini CLI", @alpha.compatibility
    assert_equal "Alpha, the First", @alpha.title
    assert_equal "💛", @alpha.emoji
    assert @alpha.has_scripts
    assert_equal %i[bash python], @alpha.languages
    assert_equal 10, @alpha.lines
  end

  def test_graceful_defaults
    assert_nil @beta.version
    assert_nil @beta.emoji
    assert_nil @beta.category
    assert_equal "beta", @beta.title, "title falls back to name when no H1"
    refute @beta.has_scripts
    assert_empty @beta.languages
    assert_match(/\A\d{4}-\d{2}-\d{2}\z/, @beta.updated_at, "falls back to mtime outside git")
  end

  def test_category_from_metadata_or_path
    assert_equal "Containers", @gamma.category, "metadata.category wins"
    assert_nil @plug_gamma.category, "plugins/<p>/skills/<name> has no category folder"
  end

  def test_ids_are_unique_even_with_same_name
    assert_equal "gamma", @gamma.name
    assert_equal "gamma", @plug_gamma.name
    refute_equal @gamma.id, @plug_gamma.id
    assert_equal "content/nested/plug/gamma.md", @plug_gamma.to_h[:content_url]
  end

  def test_entrypoint_matches_google_skills_convention
    assert_equal "https://raw.githubusercontent.com/acme/nested/main/skills/cloud/gamma/SKILL.md", @gamma.entrypoint
    assert_equal "npx skills add acme/nested --skill gamma", @gamma.install
  end

  def test_quality_is_explainable
    # alpha: version ✓, scripts ✓, recent (fixture mtime = now) ✓, 10 lines ✗, short description ✗ → 3
    assert_equal 3, @alpha.quality
    # beta: no version, no scripts, recent ✓, 5 lines ✗, short description ✗ → 1
    assert_equal 1, @beta.quality
    assert_includes 0..5, @gamma.quality
  end
end

class TestWriterAndCompat < Minitest::Test
  def test_end_to_end_build_is_compatible
    Dir.mktmpdir do |out|
      sources = [fixture_source("flat-ext"), fixture_source("nested")]
      skills = sources.flat_map { SkillsIndexer::Scanner.new(_1).skills }
      SkillsIndexer::Writer.new(out).write(sources:, skills:)
      index = JSON.parse(File.read(File.join(out, "index.json")))

      assert_empty SkillsIndexer::Compat.problems(index)
      assert_equal 4, index["skills"].size
      assert_equal [2, 2], index["sources"].map { _1["skills_count"] }
      assert_equal ["plugins/area/sub"], index["sources"][1]["skipped_submodules"]
      assert File.exist?(File.join(out, "content/flat-ext/alpha.md"))
      assert File.exist?(File.join(out, "content/nested/plug/gamma.md"))
    end
  end

  def test_upstream_google_skills_sample_is_compatible
    index = SkillsIndexer::Compat.load(FIXTURES.join("google-skills-index.sample.json").to_s)
    assert_empty SkillsIndexer::Compat.problems(index)
  end

  def test_compat_rejects_broken_indexes
    refute SkillsIndexer::Compat.compatible?([])
    refute SkillsIndexer::Compat.compatible?("generator" => "x", "skills" => [])
    refute SkillsIndexer::Compat.compatible?("generator" => "x", "skills" => [{"name" => "a", "description" => "b", "entrypoint" => "not-a-url"}])
    assert SkillsIndexer::Compat.compatible?("generator" => "x", "skills" => [{"name" => "a", "description" => "b", "entrypoint" => "https://x/SKILL.md"}])
  end
end

class TestMarketplace < Minitest::Test
  def test_only_sources_with_manifest_become_plugins
    sources = [fixture_source("flat-ext"), fixture_source("nested"),
      SkillsIndexer::Source.new("id" => "bare", "url" => "https://github.com/acme/bare", "tier" => "public", "path" => FIXTURES.join("flat-ext/skills").to_s).resolve!]
    names = SkillsIndexer::Marketplace.claude(sources)[:plugins].map { _1[:name] }
    assert_equal %w[flat-ext nested], names, "bare has no manifest → not a plugin"
  end

  def test_both_dialects_are_written
    Dir.mktmpdir do |root|
      paths = SkillsIndexer::Marketplace.write([fixture_source("flat-ext")], root:)
      assert_equal [".claude-plugin/marketplace.json", ".agents/plugins/marketplace.json"], paths.map { _1.relative_path_from(Pathname(root)).to_s }
      claude = JSON.parse(File.read(paths[0])); agents = JSON.parse(File.read(paths[1]))
      assert_equal({"source" => "github", "repo" => "acme/flat-ext", "ref" => "main"}, claude["plugins"][0]["source"])
      assert_equal({"source" => "url", "url" => "https://github.com/acme/flat-ext.git", "ref" => "main"}, agents["plugins"][0]["source"])
      assert_equal "AVAILABLE", agents["plugins"][0]["policy"]["installation"]
    end
  end
end
