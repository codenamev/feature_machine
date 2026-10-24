require_relative "lib/feature_machine/version"

Gem::Specification.new do |spec|
  spec.name        = "feature_machine"
  spec.version     = FeatureMachine::VERSION
  spec.authors     = [ "codenamev" ]
  spec.summary     = "Feature requests in, triaged work items out, built by your agents."
  spec.description = "A mountable Rails engine for the feature-request -> triage -> " \
                     "work-item -> agent hand-off loop, extracted from nowreading.dev."
  spec.homepage    = "https://github.com/codenamev/nowreading.dev/issues/102"
  spec.required_ruby_version = ">= 3.3"

  # Licence, repository and release are phase 6 (nowreading#102). Until then
  # this gem is only ever loaded by path from nowreading.dev.
  spec.metadata["allowed_push_host"] = "https://example.invalid"

  spec.files = Dir["lib/**/*", "app/**/*", "config/**/*", "db/**/*"]

  spec.add_dependency "rails", ">= 8.1"
end
