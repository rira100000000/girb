# frozen_string_literal: true

require_relative "lib/gcore/version"

Gem::Specification.new do |spec|
  spec.name = "gcore"
  spec.version = Gcore::VERSION
  spec.authors = ["rira100000000"]
  spec.email = ["rira100000000@example.com"]

  spec.summary = "Core components for AI-powered Ruby debugging tools"
  spec.description = "Shared core library for girb (IRB AI assistant) and gdebug (debug gem AI assistant). " \
                     "Provides AI client, tools, and provider interfaces."
  spec.homepage = "https://github.com/rira100000000/gcore"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github])
    end
  end
  spec.require_paths = ["lib"]
end
