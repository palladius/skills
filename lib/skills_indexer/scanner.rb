=begin
Scanner — walks a Source's checkout and returns its Skills.

Rule (PLAN roast #11): a folder is a skill iff it contains SKILL.md. No depth
heuristics. We only skip VCS/junk folders, test fixtures, git submodules — and whatever the
source's air-gap rules (exclude_skills / exclude_content_regex) say must not leave.
=end

module SkillsIndexer
  class Scanner
    SKIP = %r{(^|/)(\.git|node_modules|tmp|trash|test|tests|spec|fixtures|dist|out)(/|$)}
    # Explicit depths instead of "**": "**" never descends into symlinked directories, and
    # skill folders are often symlinks (e.g. a git repo pointing at a monorepo checkout).
    # Depth 6 covers plugins/<area>/<plugin>/skills/<name>/SKILL.md with room to spare.
    PATTERNS = (0..6).map { |d| (["*"] * d + ["SKILL.md"]).join("/") }.freeze

    def initialize(source) = @source = source

    def skills
      return [] unless @source.available?
      skip_prefixes = @source.submodule_paths
      Dir.glob(PATTERNS, base: @source.dir).sort.filter_map do |rel|
        next if rel.match?(SKIP)
        next if skip_prefixes.any? { rel.start_with?("#{_1}/") }
        skill = Skill.new(source: @source, skill_md: @source.dir.join(rel))
        # AIR-GAP: a skill excluded by name or by content regex is dropped *before* it
        # can reach index.json or content/. Its name is remembered only for the build log.
        if @source.excluded?(name: skill.name, content: skill.raw)
          @source.excluded << skill.name
          next
        end
        matches = @source.warn_matches(content: skill.raw)
        @source.warned << "#{skill.name} (#{matches.first(3).join(', ')})" unless matches.empty?
        skill
      end
    end
  end
end
