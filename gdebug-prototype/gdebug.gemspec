# frozen_string_literal: true

require_relative "lib/gdebug/version"

Gem::Specification.new do |spec|
  spec.name = "gdebug"
  spec.version = Gdebug::VERSION
  spec.authors = ["Your Name"]
  spec.email = ["your@email.com"]

  spec.summary = "AI-powered debugging assistant for Ruby's debug gem"
  spec.description = "An AI assistant embedded in your debug session. " \
                     "It understands your runtime context and helps with debugging. " \
                     "Works with VSCode, RubyMine, and other debug gem clients."
  spec.homepage = "https://github.com/yourusername/gdebug"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "debug", ">= 1.0"

  spec.add_development_dependency "rspec", "~> 3.0"
end
