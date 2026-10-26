# What the feature_machine engine needs from this app. Every setting is shown
# with its default; the first three are the ones a real host must change.
# Lambdas stay lazy: initializers may not autoload app constants.
FeatureMachine.configure do |config|
  # The user model the engine's requests and work items belong to.
  config.user_class   = "User"

  # The signed-in user for a request, or nil. The default treats everyone as
  # signed out, so nothing is readable until this is set.
  config.current_user = ->(_request) { nil }

  # May this user triage requests and manage work items?
  config.admin        = ->(user) { user.respond_to?(:admin?) && user.admin? }

  # Bearer token -> credential (any object answering `user` and
  # `allows?(scope)` for "read", "write" and "maintainer"), or nil. Without
  # it the API takes no tokens and maintainer endpoints refuse everything.
  # config.authenticate_api = ->(token) { ApiToken.authenticate(token) }

  # Signed-in users may use the API through their session cookie (writes are
  # CSRF-checked). Turn off for a token-only API.
  config.session_auth = true

  # How the engine names this app in its pages and in the drafter's prompt.
  config.product_name = "<%= Rails.application.class.module_parent_name.underscore.humanize %>"
  # config.product_blurb = "My App (a todo list with an API for agents)"

  # Where users get an API token, and the OAuth protected-resource metadata
  # URL sent on 401s. nil leaves them out.
  # config.token_help_url         = "https://example.com/token"
  # config.protected_resource_url = "https://example.com/.well-known/oauth-protected-resource"

  # Any RubyLLM embedding model groups similar requests; nil turns embeddings
  # off and triage falls back to a flat newest-first list.
  # config.embedding_model = "text-embedding-3-small"

  # Any RubyLLM chat model drafts work-item specs; nil drafts a plain digest.
  # config.drafter_model     = "gpt-4.1-mini"
  # config.drafter_provider  = :openai
  # config.drafter_fallbacks = []

  # Any RubyLLM chat model ranks untriaged requests (bug? duplicate? clear?);
  # nil keeps triage unranked.
  # config.judgment_model = nil

  # The layout engine pages render through. nil uses this app's own; set
  # "feature_machine" for the engine's minimal standalone shell.
  # config.layout = nil

  # Links into this app the engine's views offer. Each lambda gets the view
  # context; leave one nil and the link is omitted.
  # config.roadmap_path        = ->(view, work_item = nil) { view.roadmap_path }
  # config.bug_reports_path    = ->(view) { view.bug_reports_path }
  # config.new_bug_report_path = ->(view) { view.new_bug_report_path }
  # config.admin_triage_path   = ->(view) { view.admin_triage_path }

  # This app's admin nav partial, rendered atop engine admin pages, and how a
  # requester is named in them.
  # config.admin_nav_partial = "admin/nav"
  # config.user_label        = ->(user) { "user ##{user.id}" }
end
