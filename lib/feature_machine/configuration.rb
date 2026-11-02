module FeatureMachine
  # Everything the engine needs from its host, as plain values and callables.
  # Set it once in config/initializers/feature_machine.rb:
  #
  #   FeatureMachine.configure do |config|
  #     config.current_user     = ->(request) { ... }      # the host's user, or nil
  #     config.admin            = ->(user) { user.admin? } # may this user triage?
  #     config.authenticate_api = ->(token) { ... }        # bearer token -> credential, or nil
  #     config.product_name     = "My App"
  #     config.token_help_url   = "https://my.app/token"
  #   end
  #
  # A credential is any object answering `user` and `allows?(scope)` for the
  # scopes in FeatureMachine::SCOPES. The host's token model never has to be
  # known to the engine.
  class Configuration
    attr_accessor :user_class, :current_user, :admin, :authenticate_api, :session_auth,
                  :product_name, :token_help_url, :protected_resource_url,
                  :embedding_model, :drafter_model, :drafter_provider, :drafter_fallbacks,
                  :judgment_model, :judgment_provider, :roadmap_path, :bug_reports_path, :new_bug_report_path,
                  :admin_nav_partial, :user_label, :admin_triage_path, :layout,
                  :on_status_change, :parent_controller, :admin_parent_controller,
                  :api_parent_controller, :sign_in_path, :flash_in_pages

    # The engine's own pages, linked by default. A host that draws its own
    # roadmap or bug board points these at it instead, or sets nil to drop the
    # link. respond_to? keeps a link out when its route isn't drawn.
    DEFAULT_ROADMAP_PATH = lambda do |view, work_item = nil|
      view.roadmap_path(anchor: (view.dom_id(work_item) if work_item)) if view.respond_to?(:roadmap_path)
    end
    DEFAULT_BUG_REPORTS_PATH     = ->(view) { view.bug_reports_path if view.respond_to?(:bug_reports_path) }
    DEFAULT_NEW_BUG_REPORT_PATH  = ->(view) { view.new_bug_report_path if view.respond_to?(:new_bug_report_path) }
    DEFAULT_ADMIN_TRIAGE_PATH    = ->(view) { view.admin_triage_path if view.respond_to?(:admin_triage_path) }
    # Where a signed-out visitor to an engine page is sent, given the
    # controller. Rails' authentication generator draws new_session_path.
    DEFAULT_SIGN_IN_PATH         = ->(controller) { controller.new_session_path if controller.respond_to?(:new_session_path) }

    def initialize
      @user_class             = "User"
      @current_user           = ->(_request) { nil }
      @admin                  = ->(user) { user.respond_to?(:admin?) && user.admin? }
      @authenticate_api       = nil
      @session_auth           = true
      @product_name           = "this app"
      @token_help_url         = nil
      @protected_resource_url = nil
      @embedding_model        = nil
      @drafter_model          = nil
      @drafter_provider       = nil
      @drafter_fallbacks      = []
      @judgment_model         = nil
      @judgment_provider      = nil
      @roadmap_path           = DEFAULT_ROADMAP_PATH
      @bug_reports_path       = DEFAULT_BUG_REPORTS_PATH
      @new_bug_report_path    = DEFAULT_NEW_BUG_REPORT_PATH
      @admin_nav_partial      = nil
      @user_label             = ->(user) { "user ##{user.id}" }
      @admin_triage_path      = DEFAULT_ADMIN_TRIAGE_PATH
      @product_blurb          = nil
      @layout                 = nil
      @on_status_change       = nil
      @parent_controller      = "ApplicationController"
      @admin_parent_controller = nil
      @api_parent_controller  = "ActionController::API"
      @sign_in_path           = DEFAULT_SIGN_IN_PATH
      @flash_in_pages         = true
    end

    # The classes engine controllers inherit from, named as strings so the
    # initializer never autoloads app code. Pages inherit the host's
    # ApplicationController (its layout, its auth filters); admin pages inherit
    # admin_parent_controller, falling back to the same; the API inherits
    # ActionController::API unless the host has its own base for error shape,
    # rate-limit headers and the like. The engine adds its own admin check and
    # token auth on top of whichever it gets.
    def admin_parent_controller
      @admin_parent_controller || parent_controller
    end

    # The layout engine pages render through. nil (the default) means the
    # host's own: engine controllers inherit the host's ApplicationController
    # and so its layout, nav and stylesheets. A host with no layout of its own
    # (or one it doesn't want the engine in) names one, e.g. "feature_machine"
    # for the engine's minimal standalone shell. `.md` responses never use it.

    # One line the drafter uses to describe the product to the model, e.g.
    # "My App (a todo list with an API for agents)". Falls back to product_name
    # so a host that sets nothing still gets a truthful, if terse, prompt.
    attr_writer :product_blurb

    def product_blurb
      @product_blurb.to_s.empty? ? product_name : @product_blurb
    end

    # Links the engine's views offer: a lambda given the view context plus any
    # record the link is about, returning a path, or nil to leave the link out.
    # They default to the engine's own pages (DEFAULT_*_PATH); a host with its
    # own roadmap or bug board points them there.
    #
    #   admin_triage_path:   ->(view) { ... }                  the host's triage inbox
    #   roadmap_path:        ->(view, work_item = nil) { ... } the roadmap, anchored on an item if given
    #   bug_reports_path:    ->(view) { ... }                  the host's bug board
    #   new_bug_report_path: ->(view) { ... }                  where to file a bug
    def host_path(name, view, *args)
      callable = public_send(name)
      callable&.call(view, *args)
    end

    # The host's own admin navigation, rendered at the top of every engine
    # admin page when set (a partial path such as "admin/nav"); nil renders
    # nothing. The engine never names a host route or page itself.
    def admin_nav_partial?
      !admin_nav_partial.nil?
    end

    # How a requester is named wherever the engine shows one (admin pages,
    # specs handed to agents). The host knows its user model; the engine
    # only knows it has an id.
    def label_for(user)
      user_label.call(user)
    end

    # Any RubyLLM embedding model name. nil turns embeddings off: requests and
    # work items are never embedded, and triage shows a flat newest-first list
    # instead of similarity buckets. pgvector only decides where vectors live.
    def embeddings?
      !embedding_model.nil?
    end

    # Any RubyLLM chat model name, with an optional explicit provider and an
    # ordered list of fallback models for when it is unavailable. nil turns the
    # model off: forming a work item still works, the draft is a plain digest
    # of the requests instead of a written specification.
    def drafter?
      !drafter_model.nil?
    end

    # A RubyLLM model whose provider does structured judgments (OpenAI,
    # Ollama, or TypeSafe's Jev, which OpenRouter also serves). nil turns judging off: triage shows the
    # similarity buckets unranked, with no bug/duplicate/clarity flags.
    # judgment_provider names the provider outright, for a model id the
    # registry doesn't know, such as one on a local Jev-compatible server
    # (:typesafe with RubyLLM's typesafe_api_base pointed at it).
    def judge?
      !judgment_model.nil?
    end

    # The engine never trusts a credential's own answer for the one scope with
    # teeth: before any maintainer action it asks the host again whether the
    # user may triage. A host that misconfigures its tokens still can't hand
    # the queue to a customer.
    def admin?(user)
      !!(user && admin.call(user))
    end

    def user_for(request)
      current_user.call(request)
    end
  end
end
