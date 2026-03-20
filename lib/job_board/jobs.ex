defmodule JobBoard.Jobs do
  @moduledoc """
  The Jobs context.

  Handles creating, reading, updating, and deleting job listings,
  plus search and pagination (Phase 4).

  Controllers call functions here. They never query the database directly.
  """

  import Ecto.Query
  alias JobBoard.Repo
  alias JobBoard.Jobs.Job

  # ---------------------------------------------------------------------------
  # Phase 2 — CRUD
  # ---------------------------------------------------------------------------

  @doc "Returns all published jobs."
  def list_jobs do
    Repo.all(from j in Job, where: j.status == "published", order_by: [desc: j.inserted_at])
  end

  @doc "Returns all jobs posted by the given user (employer's dashboard)."
  def list_my_jobs(user) do
    Repo.all(from j in Job, where: j.user_id == ^user.id, order_by: [desc: j.inserted_at])
  end

  @doc "Returns a single job by ID. Raises Ecto.NoResultsError if not found."
  def get_job!(id), do: Repo.get!(Job, id)

  @doc """
  Creates a new job listing owned by the given user.
  The user_id is set from the authenticated user — not from the request params.
  """
  def create_job(user, attrs) do
    %Job{user_id: user.id}
    |> Job.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates an existing job. Caller is responsible for checking ownership."
  def update_job(job, attrs) do
    job
    |> Job.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a job. Caller is responsible for checking ownership."
  def delete_job(job) do
    Repo.delete(job)
  end

  # ---------------------------------------------------------------------------
  # Phase 4 — Search and Pagination
  # ---------------------------------------------------------------------------

  @per_page 20

  @doc """
  Searches published jobs with optional filters.

  ## Params (all optional, string keys)
  - `"q"` — keyword search on title (case-insensitive)
  - `"loc"` — filter by location (case-insensitive)
  - `"min_salary"` — minimum salary (integer)
  - `"page"` — page number, default 1 (#{@per_page} results per page)
  """
  def search_jobs(params) do
    page = parse_page(params["page"])

    from(j in Job, where: j.status == "published", order_by: [desc: j.inserted_at])
    |> filter_by_title(params["q"])
    |> filter_by_location(params["loc"])
    |> filter_by_min_salary(params["min_salary"])
    |> limit(@per_page)
    |> offset(^((page - 1) * @per_page))
    |> Repo.all()
  end

  defp filter_by_title(query, nil), do: query
  defp filter_by_title(query, ""), do: query
  defp filter_by_title(query, q), do: where(query, [j], ilike(j.title, ^"%#{q}%"))

  defp filter_by_location(query, nil), do: query
  defp filter_by_location(query, ""), do: query
  defp filter_by_location(query, loc), do: where(query, [j], ilike(j.location, ^"%#{loc}%"))

  defp filter_by_min_salary(query, nil), do: query
  defp filter_by_min_salary(query, ""), do: query

  defp filter_by_min_salary(query, min) do
    case Integer.parse(to_string(min)) do
      {val, _} -> where(query, [j], j.salary >= ^val)
      :error -> query
    end
  end

  defp parse_page(nil), do: 1

  defp parse_page(p) do
    case Integer.parse(to_string(p)) do
      {val, _} when val > 0 -> val
      _ -> 1
    end
  end
end
