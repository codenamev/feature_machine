module FeatureMachine
  # The model-facing half of drafting a work item: a RubyLLM::Agent whose
  # instructions live in engines/feature_machine/app/prompts/feature_machine/drafter/instructions.txt.erb
  # and whose output is constrained to WorkItemSpecSchema.
  #
  # The instructions describe the product through the _product_blurb partial
  # next to them, which renders FeatureMachine.config.product_blurb (falling
  # back to product_name). A host sets the blurb in its initializer; one that
  # wants a longer description can still ship its own
  # app/prompts/feature_machine/drafter/_product_blurb.txt.erb, since
  # RubyLLM::Prompt searches the application's prompt root first.
  #
  # Prompt caching is on, and the cache boundary sits right after the
  # instructions: they are identical across every draft, while the quoted
  # requests below them change each time.
  #
  # Model, provider, and fallbacks come from FeatureMachine.config at the time a
  # chat is built (not at class load), so a host can reconfigure the drafter in
  # an initializer or a test without reloading this class. With
  # config.drafter_model = nil, callers should not build a chat at all; see
  # WorkItemDrafter, which short-circuits to a digest in that case.
  class Drafter < RubyLLM::Agent
    # RubyLLM::Agent.instructions treats a call with no text, no block and no
    # prompt locals as the getter, so `instructions cache_until_here: true`
    # records nothing and the default declaration (no cache boundary) applies.
    # The block returns the same prompt-file reference the default would use,
    # which keeps the lookup (and a host's override) identical.
    instructions(cache_until_here: true) { { prompt: "instructions" } }
    caching
    schema WorkItemSpecSchema

    # Builds a chat on the configured drafter model, with the configured
    # fallbacks applied. Keyword arguments are forwarded to RubyLLM.chat and
    # take precedence over the config (handy for one-off overrides in tests).
    def self.chat(**kwargs)
      config = FeatureMachine.config
      chat = super(model: config.drafter_model, provider: config.drafter_provider, **kwargs)
      fallbacks = Array(config.drafter_fallbacks).compact
      chat = chat.with_fallbacks(*fallbacks) if fallbacks.any?
      chat
    end
  end
end
