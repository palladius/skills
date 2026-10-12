=begin
Scanner — walks a Source's checkout and returns its Skills.

Rule (PLAN roast #11): a folder is a skill iff it contains SKILL.md. No depth
heuristics. We only skip VCS/junk folders, test fixtures and git submodules.
=end

module SkillsIndexer
  class Scanner
    SKIP = %r{(^|/)(\.git|node_modules|tmp|trash|test|tests|spec|fixtures|dist|out)(/|$)}

    def initialize(source) = @source = source

    def skills
      skip_prefixes = @source.submodule_paths
      Dir.glob("**/SKILL.md", base: @source.dir).sort.filter_map do |rel|
        next if rel.match?(SKIP)
        next if skip_prefixes.any? { rel.start_with?("#{_1}/") }
        Skill.new(source: @source, skill_md: @source.dir.join(rel))
      end
    end
  end
end
