defmodule JobBoardWeb.JobControllerTest do
  use JobBoardWeb.ConnCase, async: true
  import JobBoard.Factory

  @job_attrs %{
    "title" => "Elixir Developer",
    "description" => "Build Phoenix APIs",
    "location" => "Remote",
    "salary" => 90_000,
    "status" => "published"
  }

  defp auth_conn(conn, user) do
    token = JobBoard.Accounts.generate_token(user)
    put_req_header(conn, "authorization", "Bearer #{token}")
  end

  # ---------------------------------------------------------------------------
  # Public routes
  # ---------------------------------------------------------------------------

  describe "GET /api/jobs" do
    test "returns published jobs", %{conn: conn} do
      insert(:job, status: "published")
      insert(:job, status: "draft")

      conn = get(conn, "/api/jobs")
      body = json_response(conn, 200)

      assert length(body["jobs"]) == 1
    end

    test "search by title", %{conn: conn} do
      insert(:job, title: "Elixir Developer")
      insert(:job, title: "Python Developer")

      conn = get(conn, "/api/jobs?q=elixir")
      body = json_response(conn, 200)

      assert length(body["jobs"]) == 1
      assert hd(body["jobs"])["title"] == "Elixir Developer"
    end
  end

  describe "GET /api/jobs/:id" do
    test "returns the job", %{conn: conn} do
      job = insert(:job)
      conn = get(conn, "/api/jobs/#{job.id}")
      body = json_response(conn, 200)

      assert body["job"]["id"] == job.id
      assert body["job"]["title"] == job.title
    end
  end

  # ---------------------------------------------------------------------------
  # Protected routes
  # ---------------------------------------------------------------------------

  describe "POST /api/jobs" do
    test "201 as employer", %{conn: conn} do
      employer = insert(:employer)
      conn = conn |> auth_conn(employer) |> post("/api/jobs", @job_attrs)
      body = json_response(conn, 201)

      assert body["job"]["title"] == "Elixir Developer"
      assert body["job"]["user_id"] == employer.id
    end

    test "403 as seeker", %{conn: conn} do
      seeker = insert(:user, role: "seeker")
      conn = conn |> auth_conn(seeker) |> post("/api/jobs", @job_attrs)

      assert json_response(conn, 403)["error"] =~ "employer"
    end

    test "401 without token", %{conn: conn} do
      conn = post(conn, "/api/jobs", @job_attrs)
      assert json_response(conn, 401)
    end

    test "422 with invalid data", %{conn: conn} do
      employer = insert(:employer)
      conn = conn |> auth_conn(employer) |> post("/api/jobs", %{"title" => "Hi"})
      body = json_response(conn, 422)

      assert body["errors"] != nil
    end
  end

  describe "PUT /api/jobs/:id" do
    test "updates as owner", %{conn: conn} do
      employer = insert(:employer)
      job = insert(:job, user: employer)

      conn =
        conn
        |> auth_conn(employer)
        |> put("/api/jobs/#{job.id}", %{"title" => "Senior Elixir Dev"})

      body = json_response(conn, 200)

      assert body["job"]["title"] == "Senior Elixir Dev"
    end

    test "403 when not owner", %{conn: conn} do
      employer1 = insert(:employer)
      employer2 = insert(:employer)
      job = insert(:job, user: employer1)

      conn = conn |> auth_conn(employer2) |> put("/api/jobs/#{job.id}", %{"title" => "Hacked"})
      assert json_response(conn, 403)["error"] =~ "own"
    end
  end

  describe "DELETE /api/jobs/:id" do
    test "deletes as owner", %{conn: conn} do
      employer = insert(:employer)
      job = insert(:job, user: employer)

      conn = conn |> auth_conn(employer) |> delete("/api/jobs/#{job.id}")
      assert response(conn, 204)
    end

    test "403 when not owner", %{conn: conn} do
      employer1 = insert(:employer)
      employer2 = insert(:employer)
      job = insert(:job, user: employer1)

      conn = conn |> auth_conn(employer2) |> delete("/api/jobs/#{job.id}")
      assert json_response(conn, 403)
    end
  end

  describe "GET /api/my/jobs" do
    test "returns employer's own jobs", %{conn: conn} do
      employer = insert(:employer)
      insert(:job, user: employer)
      insert(:job)

      conn = conn |> auth_conn(employer) |> get("/api/my/jobs")
      body = json_response(conn, 200)

      assert length(body["jobs"]) == 1
    end

    test "403 as seeker", %{conn: conn} do
      seeker = insert(:user, role: "seeker")
      conn = conn |> auth_conn(seeker) |> get("/api/my/jobs")
      assert json_response(conn, 403)
    end
  end
end
