require_relative "lib/feature_machine/version"

Gem::Specification.new do |spec|
  spec.name        = "feature_machine"
  spec.version     = FeatureMachine::VERSION
  spec.authors     = [ "codenamev" ]
  spec.summary     = "Feature requests in, triaged work items out, built by your agents."
  spec.description = "A mountable Rails engine for the feature-request -> triage -> " \
                     "work-item -> agent hand-off loop."
  spec.homepage    = "https://github.com/codenamev/feature_machine"
  spec.license     = "MIT"
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.required_ruby_version = ">= 3.3"

  spec.files = Dir["lib/**/*", "app/**/*", "config/**/*", "db/**/*", "exe/*",
                   "README.md", "LICENSE", "CHANGELOG.md"]
  spec.bindir = "exe"
  spec.executables = [ "feature_machine" ]

  spec.add_dependency "rails", ">= 8.1"
  # The drafter and judge use RubyLLM::Agent and RubyLLM::Judge (2.1+).
  spec.add_dependency "ruby_llm", ">= 2.1"
  spec.add_dependency "neighbor", ">= 1.0"
  # The API's views are jbuilder, and the agent's tools are served over MCP.
  spec.add_dependency "jbuilder", ">= 2.11"
  spec.add_dependency "mcp", ">= 1.6"
end
