# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :job_board,
  ecto_repos: [JobBoard.Repo],
  generators: [timestamp_type: :utc_datetime],
  # JWT secret used to sign and verify tokens.
  # Override in config/runtime.exs for production (read from env var).
  jwt_secret: "dev_secret_change_in_production"

# Oban background job queue configuration.
# The :emails queue processes email confirmation jobs with up to 5 concurrent workers.
config :job_board, Oban,
  repo: JobBoard.Repo,
  queues: [emails: 5]

# Configure the endpoint
config :job_board, JobBoardWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: JobBoardWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: JobBoard.PubSub,
  live_view: [signing_salt: "IyMOYyt/"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :job_board, JobBoard.Mailer, adapter: Swoosh.Adapters.Local

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
