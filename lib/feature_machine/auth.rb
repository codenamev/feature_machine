module FeatureMachine
  module Auth
    # Does this credential allow `scope`, by the engine's rules? The credential
    # answers for itself, and for `maintainer` the host's admin predicate must
    # agree. This is the one place the rule lives; controllers and tools call
    # it rather than `credential.allows?` directly.
    def self.allows?(credential, scope)
      return false unless credential&.allows?(scope.to_s)
      return true unless scope.to_s == MAINTAINER

      FeatureMachine.config.admin?(credential.user)
    end

    # The "Authorization: Bearer <token>" value of a Rack env, or nil.
    def self.bearer_token(env)
      header = env["HTTP_AUTHORIZATION"].to_s
      scheme, token = header.split(" ", 2)
      token&.strip.presence if scheme&.casecmp?("bearer")
    end

    # The credential a signed-in browser session carries. `user` is resolved
    # on first use, so installing the middleware costs nothing on requests
    # that never ask. A session user may read and write their own requests;
    # maintainer access needs the host's admin predicate.
    class SessionCredential
      def initialize(request, config: FeatureMachine.config)
        @request = request
        @config  = config
      end

      def user
        return @user if defined?(@user)

        @user = @config.user_for(@request)
      end

      def allows?(scope)
        return false unless user

        case scope.to_s
        when READ, WRITE then true
        when MAINTAINER  then @config.admin?(user)
        else false
        end
      end

      def session?
        true
      end
    end

    # Resolves a bearer token through `config.authenticate_api` and sets the
    # env key when it finds a credential. A missing or bad token sets nothing,
    # so the next middleware may still find one. Install before Session.
    class Bearer
      def initialize(app, resolver: nil)
        @app      = app
        @resolver = resolver
      end

      def call(env)
        if env[ENV_KEY].nil? && (resolver = @resolver || FeatureMachine.config.authenticate_api)
          token = Auth.bearer_token(env)
          credential = resolver.call(token) if token
          env[ENV_KEY] = credential if credential
        end

        @app.call(env)
      end
    end

    # Sets a SessionCredential when nothing earlier in the stack set a
    # credential and `config.session_auth` is on. Install last, after the
    # host's session middleware.
    class Session
      def initialize(app)
        @app = app
      end

      def call(env)
        if env[ENV_KEY].nil? && FeatureMachine.config.session_auth
          env[ENV_KEY] = SessionCredential.new(ActionDispatch::Request.new(env))
        end

        @app.call(env)
      end
    end
  end
end
