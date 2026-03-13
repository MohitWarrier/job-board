defmodule JobBoardWeb.JobController do
  use JobBoardWeb, :controller

  alias JobBoard.Jobs

  # ---------------------------------------------------------------------------
  # Public actions (no auth required)
  # ---------------------------------------------------------------------------

  @doc "GET /api/jobs — list published jobs. Supports search params in Phase 4."
  def index(conn, _params) do
    # TODO Phase 4: pass params to Jobs.search_jobs/1 for filtering and pagination
    jobs = Jobs.list_jobs()
    json(conn, %{jobs: Enum.map(jobs, &job_json/1)})
  end

  @doc "GET /api/jobs/:id — get a single job."
  def show(conn, %{"id" => id}) do
    job = Jobs.get_job!(id)
    json(conn, %{job: job_json(job)})
  end

  # ---------------------------------------------------------------------------
  # Protected actions (token required, role checked)
  # ---------------------------------------------------------------------------

  @doc "POST /api/jobs — create a job. Employer only."
  def create(conn, params) do
    with :ok <- require_employer(conn) do
      case Jobs.create_job(conn.assigns.current_user, params) do
        {:ok, job} ->
          conn
          |> put_status(:created)
          |> json(%{job: job_json(job)})

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{errors: format_errors(changeset)})
      end
    end
  end

  @doc "PUT /api/jobs/:id — update a job. Owner only."
  def update(conn, %{"id" => id} = params) do
    job = Jobs.get_job!(id)

    with :ok <- require_owner(conn, job) do
      case Jobs.update_job(job, params) do
        {:ok, updated} ->
          json(conn, %{job: job_json(updated)})

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{errors: format_errors(changeset)})
      end
    end
  end

  @doc "DELETE /api/jobs/:id — delete a job. Owner only."
  def delete(conn, %{"id" => id}) do
    job = Jobs.get_job!(id)

    with :ok <- require_owner(conn, job) do
      Jobs.delete_job(job)
      send_resp(conn, :no_content, "")
    end
  end

  @doc "GET /api/my/jobs — list the authenticated employer's own jobs."
  def my_jobs(conn, _params) do
    with :ok <- require_employer(conn) do
      jobs = Jobs.list_my_jobs(conn.assigns.current_user)
      json(conn, %{jobs: Enum.map(jobs, &job_json/1)})
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp require_employer(conn) do
    if conn.assigns.current_user.role == "employer" do
      :ok
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "only employers can perform this action"})
      |> halt()

      {:error, :forbidden}
    end
  end

  defp require_owner(conn, job) do
    if job.user_id == conn.assigns.current_user.id do
      :ok
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "you do not own this job"})
      |> halt()

      {:error, :forbidden}
    end
  end

  defp job_json(job) do
    %{
      id: job.id,
      title: job.title,
      description: job.description,
      location: job.location,
      salary: job.salary,
      status: job.status,
      user_id: job.user_id,
      inserted_at: job.inserted_at,
      updated_at: job.updated_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
