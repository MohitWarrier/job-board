defmodule JobBoardWeb.Router do
  use JobBoardWeb, :router

  # ── Pipelines ──────────────────────────────────────────────────────────────

  # All API routes must accept JSON.
  pipeline :api do
    plug :accepts, ["json"]
  end

  # Protected pipeline — sits on top of :api.
  # AuthPlug reads the Authorization: Bearer <token> header and loads current_user.
  # Any route in an :authenticated pipeline will return 401 if the token is missing or invalid.
  pipeline :authenticated do
    plug :accepts, ["json"]
    plug JobBoardWeb.AuthPlug
  end

  # ── Public routes (no token required) ──────────────────────────────────────
  scope "/api", JobBoardWeb do
    pipe_through :api

    post "/register", AuthController, :register
    post "/login", AuthController, :login

    # Jobs — readable by anyone
    get "/jobs", JobController, :index
    get "/jobs/:id", JobController, :show
  end

  # ── Protected routes (JWT token required) ──────────────────────────────────
  scope "/api", JobBoardWeb do
    pipe_through :authenticated

    # Job management — employers only (enforced inside the controller)
    post "/jobs", JobController, :create
    put "/jobs/:id", JobController, :update
    delete "/jobs/:id", JobController, :delete

    # Applications — seekers only (enforced inside the controller)
    post "/jobs/:id/apply", ApplicationController, :apply

    # "My" routes — each scoped to the authenticated user's role
    get "/my/applications", ApplicationController, :my_applications
    get "/my/jobs", JobController, :my_jobs
    get "/my/jobs/:id/applications", ApplicationController, :job_applications
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:job_board, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: JobBoardWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
