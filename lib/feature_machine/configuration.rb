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
  # known to the engine: nowreading's ApiCredential already answers both.
  class Configuration
    attr_accessor :user_class, :current_user, :admin, :authenticate_api, :session_auth,
                  :product_name, :token_help_url, :protected_resource_url,
                  :embedding_model, :drafter_model, :drafter_provider, :drafter_fallbacks,
                  :judgment_model, :roadmap_path, :bug_reports_path, :new_bug_report_path,
                  :admin_nav_partial, :user_label, :admin_triage_path, :layout

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
      @roadmap_path           = nil
      @bug_reports_path       = nil
      @new_bug_report_path    = nil
      @admin_nav_partial      = nil
      @user_label             = ->(user) { "user ##{user.id}" }
      @admin_triage_path      = nil
      @product_blurb          = nil
      @layout                 = nil
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

    # Optional host links the engine's views offer: a lambda given the view
    # context (so it can call the host's route helpers) plus any record the
    # link is about, returning a path, or nil to leave the link out. The
    # engine never names a host route itself.
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

    # Any RubyLLM chat model name. nil turns judging off: triage shows the
    # similarity buckets unranked, with no bug/duplicate/clarity flags.
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
