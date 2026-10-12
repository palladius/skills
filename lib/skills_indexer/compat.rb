=begin
Compat — validates that an index.json speaks the google/skills dialect:

  { "generator": "...", "skills": [ { "name", "description", "entrypoint" }, ... ] }

Works on our own output (we are a superset) and on theirs (the smoke test).
Returns a list of human-readable problems; empty list == compatible.
=end

module SkillsIndexer
  module Compat
    module_function

    def problems(index)
      errs = []
      errs << "top-level must be an object" and return errs unless index.is_a?(Hash)
      errs << "missing 'generator' string" unless index["generator"].is_a?(String)
      errs << "missing 'skills' array" and return errs unless index["skills"].is_a?(Array)
      errs << "'skills' is empty" if index["skills"].empty?
      index["skills"].each_with_index do |s, i|
        COMPAT_KEYS.each do |k|
          errs << "skills[#{i}] (#{s["name"]}): '#{k}' must be a non-empty string" unless s[k].is_a?(String) && !s[k].strip.empty?
        end
        errs << "skills[#{i}] (#{s["name"]}): entrypoint is not an http(s) URL" unless s["entrypoint"].to_s.match?(%r{\Ahttps?://})
      end
      errs
    end

    def compatible?(index) = problems(index).empty?

    # Accepts a path or an http(s) URL.
    def load(path_or_url)
      if path_or_url.match?(%r{\Ahttps?://})
        require "net/http"
        JSON.parse(Net::HTTP.get(URI(path_or_url)))
      else
        JSON.parse(File.read(path_or_url))
      end
    end
  end
end
