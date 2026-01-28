# frozen_string_literal: true

require_relative "lib/girb/version"

Gem::Specification.new do |spec|
  spec.name = "girb"
  spec.version = Girb::VERSION
  spec.authors = ["Rira"]
  spec.email = ["rira@example.com"]

  spec.summary = "AI-powered IRB assistant"
  spec.description = "Ask questions in IRB and get AI-powered answers based on your runtime context. " \
                     "Access local variables, exception info, and Rails model data while debugging."
  spec.homepage = "https://github.com/rira/girb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "ruby-gemini-api", "~> 1.0"
  spec.add_dependency "irb", ">= 1.6.0"

  # Development dependencies
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "webmock", "~> 3.0"
end
