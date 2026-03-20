defmodule JobBoard.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      JobBoardWeb.Telemetry,
      JobBoard.Repo,
      {DNSCluster, query: Application.get_env(:job_board, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: JobBoard.PubSub},
      {Oban, Application.fetch_env!(:job_board, Oban)},
      JobBoardWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: JobBoard.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    JobBoardWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
