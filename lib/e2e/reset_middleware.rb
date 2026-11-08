module E2E
  # Test-only: POST /__e2e__/reset empties the database and re-seeds it, so each
  # Playwright test starts from an empty queue. Loaded only by
  # config/environments/e2e.rb, so it doesn't exist in development, test or production.
  class ResetMiddleware
    PATH = "/__e2e__/reset".freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) unless env["REQUEST_METHOD"] == "POST" && env["PATH_INFO"] == PATH

      # truncate! (not purge!) keeps the indexes, including the unique ones
      # that guarantee no duplicate active parties.
      Mongoid.truncate!
      Rails.application.load_seed
      [ 204, {}, [] ]
    end
  end
end
