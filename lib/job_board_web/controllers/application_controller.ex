defmodule JobBoardWeb.ApplicationController do
  use JobBoardWeb, :controller

  alias JobBoard.Applications
  alias JobBoard.Jobs

  @doc "POST /api/jobs/:id/apply — apply for a job. Seeker only."
  def apply(conn, %{"id" => job_id} = params) do
    with :ok <- require_seeker(conn) do
      attrs = Map.take(params, ["cover_letter"])

      case Applications.apply(conn.assigns.current_user, job_id, attrs) do
        {:ok, application} ->
          conn
          |> put_status(:created)
          |> json(%{application: application_json(application)})

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{errors: format_errors(changeset)})
      end
    end
  end

  @doc "GET /api/my/applications — list the authenticated seeker's applications."
  def my_applications(conn, _params) do
    with :ok <- require_seeker(conn) do
      applications = Applications.list_my_applications(conn.assigns.current_user)
      json(conn, %{applications: Enum.map(applications, &application_json/1)})
    end
  end

  @doc "GET /api/my/jobs/:id/applications — list applications for an employer's job."
  def job_applications(conn, %{"id" => job_id}) do
    job = Jobs.get_job!(job_id)

    with :ok <- require_job_owner(conn, job) do
      applications = Applications.list_for_job(job)
      json(conn, %{applications: Enum.map(applications, &application_json/1)})
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp require_seeker(conn) do
    if conn.assigns.current_user.role == "seeker" do
      :ok
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "only job seekers can perform this action"})
      |> halt()

      {:error, :forbidden}
    end
  end

  defp require_job_owner(conn, job) do
    user = conn.assigns.current_user

    if user.role == "employer" && job.user_id == user.id do
      :ok
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "you do not own this job"})
      |> halt()

      {:error, :forbidden}
    end
  end

  defp application_json(application) do
    base = %{
      id: application.id,
      job_id: application.job_id,
      user_id: application.user_id,
      cover_letter: application.cover_letter,
      status: application.status,
      inserted_at: application.inserted_at
    }

    # If the job or user association was preloaded, include a summary
    base
    |> maybe_put(:job, application, fn j -> %{id: j.id, title: j.title} end)
    |> maybe_put(:user, application, fn u -> %{id: u.id, name: u.name, email: u.email} end)
  end

  defp maybe_put(map, key, record, fun) do
    case Map.get(record, key) do
      %_{} = assoc -> Map.put(map, key, fun.(assoc))
      _ -> map
    end
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
