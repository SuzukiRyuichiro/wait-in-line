# The isolated Playwright stack (`docker compose --profile e2e`): development
# settings plus a test-only reset hook. Production never loads this file.
require_relative "development"
require_relative "../../lib/e2e/reset_middleware"

Rails.application.configure do
  # Rails only adds the default dev hosts (localhost etc.) in development, so
  # list them here: Playwright calls web-e2e, the healthcheck calls localhost.
  config.hosts = %w[web-e2e localhost]

  # POST /__e2e__/reset: empty the DB and re-seed (see lib/e2e/reset_middleware.rb).
  # `use` puts it after the executor/reloader, so model code is loaded normally.
  config.middleware.use E2E::ResetMiddleware
end
