# What the feature_machine engine needs from this app. Every setting is shown
# with its default; the first three are the ones a real host must change.
# Lambdas stay lazy: initializers may not autoload app constants.
FeatureMachine.configure do |config|
  # The user model the engine's requests and work items belong to.
  config.user_class   = "User"

<% if rails_authentication? -%>
  # The signed-in user for a request, or nil. This app has Rails'
  # authentication generator (app/models/session.rb), so the session cookie
  # it sets answers the question.
  config.current_user = ->(request) { Session.find_by(id: request.cookie_jar.signed[:session_id])&.user }
<% else -%>
  # The signed-in user for a request, or nil. The default treats everyone as
  # signed out, so nothing is readable until this is set.
  config.current_user = ->(_request) { nil }
<% end -%>

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

  # A RubyLLM chat model ranks untriaged requests (bug? duplicate? clear?);
  # nil keeps triage unranked. It needs a provider with structured judgments:
  # OpenAI, Ollama, or TypeSafe ("jev-latest"). With only an OpenRouter key,
  # use "jev-latest" and set RubyLLM's typesafe_api_base to
  # "https://openrouter.ai/api" and typesafe_api_key to that key. For a local
  # Jev-compatible server, point typesafe_api_base at it and name the provider
  # so the server's own model id resolves.
  # config.judgment_model    = nil
  # config.judgment_provider = nil   # e.g. :typesafe

  # The layout engine pages render through. nil uses this app's own; set
  # "feature_machine" for the engine's minimal standalone shell.
  # config.layout = nil

  # Engine pages show their own notices ("Thanks. Its status will update
  # here."), since a new app's layout doesn't render flash. Turn this off if
  # yours does, or they'll show twice.
  # config.flash_in_pages = true

  # What engine controllers inherit from, as class names. Pages and admin
  # pages get this app's ApplicationController (its layout and auth filters);
  # the API gets ActionController::API unless you have a base of your own.
  # config.parent_controller       = "ApplicationController"
  # config.admin_parent_controller = "ApplicationController"
  # config.api_parent_controller   = "ActionController::API"

  # Where a signed-out visitor to an engine page goes, given the controller.
  # The default finds new_session_path (Rails' authentication generator);
  # nil answers 401.
  # config.sign_in_path = ->(controller) { controller.new_session_path }

  # The engine links its own roadmap, bug reports and triage pages. Point a
  # lambda at your own page instead, or set nil to drop the link.
  # config.roadmap_path        = ->(view, work_item = nil) { view.roadmap_path }
  # config.bug_reports_path    = ->(view) { view.bug_reports_path }
  # config.new_bug_report_path = ->(view) { view.new_bug_report_path }
  # config.admin_triage_path   = ->(view) { view.admin_triage_path }

  # This app's admin nav partial, rendered atop engine admin pages, and how a
  # requester is named in them and in what agents read.
  # config.admin_nav_partial = "admin/nav"
  # config.user_label        = ->(user) { "user ##{user.id}" }

  # Called with the request after each committed status change, e.g. to tell
  # the requester. Keep it fast (enqueue a job); nil does nothing.
  # config.on_status_change = ->(request) { StatusNoteJob.perform_later(request.id) }
end
