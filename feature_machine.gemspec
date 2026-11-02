require_relative "lib/feature_machine/version"

Gem::Specification.new do |spec|
  spec.name        = "feature_machine"
  spec.version     = FeatureMachine::VERSION
  spec.authors     = [ "codenamev" ]
  spec.summary     = "Feature requests in, triaged work items out, built by your agents."
  spec.description = "A mountable Rails engine for the feature-request -> triage -> " \
                     "work-item -> agent hand-off loop."
  spec.homepage    = "https://github.com/codenamev/feature_machine"
  spec.metadata["source_code_uri"] = spec.homepage
  spec.required_ruby_version = ">= 3.3"

  # No licence or release yet. Until the first release the gem is only
  # loaded by path or git source, so pushes are blocked.
  spec.metadata["allowed_push_host"] = "https://example.invalid"

  spec.files = Dir["lib/**/*", "app/**/*", "config/**/*", "db/**/*", "exe/*"]
  spec.bindir = "exe"
  spec.executables = [ "feature_machine" ]

  spec.add_dependency "rails", ">= 8.1"
  spec.add_dependency "ruby_llm"
  spec.add_dependency "neighbor"
  # The API's views are jbuilder, and the agent's tools are served over MCP.
  spec.add_dependency "jbuilder"
  spec.add_dependency "mcp", ">= 1.6"
end
