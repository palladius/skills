=begin
Writer — serialises the index and copies every SKILL.md next to it.

  <out>/index.json
  <out>/content/<skill id>.md        # id contains slashes → nested folders
=end

module SkillsIndexer
  class Writer
    def initialize(out_dir) = @out = Pathname(out_dir)

    def write(sources:, skills:)
      counts = skills.group_by { _1.source.id }.transform_values(&:size)
      index = {
        generator: "skills-indexer #{VERSION} — https://github.com/palladius/skills",
        generated_at: Time.now.utc.iso8601,
        sources: sources.map { _1.to_h(skills_count: counts.fetch(_1.id, 0)) },
        skills: skills.map(&:to_h)
      }
      FileUtils.mkdir_p(@out)
      @out.join("index.json").write(JSON.pretty_generate(index) + "\n")
      skills.each do |s|
        dest = @out.join("content", "#{s.id}.md")
        FileUtils.mkdir_p(dest.dirname)
        FileUtils.cp(s.dir.join("SKILL.md"), dest)
      end
      index
    end

    # Copies the static frontend (index.html, app.js, style.css…) into <out>/.
    def copy_site(site_dir)
      Dir.glob("*", base: site_dir).each { FileUtils.cp_r(File.join(site_dir, _1), @out) }
    end
  end
end
