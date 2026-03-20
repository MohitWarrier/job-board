defmodule JobBoardWeb.ApplicationControllerTest do
  use JobBoardWeb.ConnCase, async: true
  import JobBoard.Factory

  defp auth_conn(conn, user) do
    token = JobBoard.Accounts.generate_token(user)
    put_req_header(conn, "authorization", "Bearer #{token}")
  end

  describe "POST /api/jobs/:id/apply" do
    test "201 as seeker", %{conn: conn} do
      seeker = insert(:user, role: "seeker")
      job = insert(:job)

      conn =
        conn
        |> auth_conn(seeker)
        |> post("/api/jobs/#{job.id}/apply", %{"cover_letter" => "Hire me"})

      body = json_response(conn, 201)

      assert body["application"]["job_id"] == job.id
      assert body["application"]["user_id"] == seeker.id
      assert body["application"]["cover_letter"] == "Hire me"
    end

    test "422 duplicate application", %{conn: conn} do
      seeker = insert(:user, role: "seeker")
      job = insert(:job)

      conn |> auth_conn(seeker) |> post("/api/jobs/#{job.id}/apply", %{})

      conn2 = build_conn() |> auth_conn(seeker) |> post("/api/jobs/#{job.id}/apply", %{})
      assert json_response(conn2, 422)["errors"] != nil
    end

    test "403 as employer", %{conn: conn} do
      employer = insert(:employer)
      job = insert(:job)

      conn = conn |> auth_conn(employer) |> post("/api/jobs/#{job.id}/apply", %{})
      assert json_response(conn, 403)["error"] =~ "seeker"
    end

    test "401 without token", %{conn: conn} do
      job = insert(:job)
      conn = post(conn, "/api/jobs/#{job.id}/apply", %{})
      assert json_response(conn, 401)
    end
  end

  describe "GET /api/my/applications" do
    test "returns seeker's applications", %{conn: conn} do
      seeker = insert(:user, role: "seeker")
      job = insert(:job)
      insert(:application, user: seeker, job: job)

      conn = conn |> auth_conn(seeker) |> get("/api/my/applications")
      body = json_response(conn, 200)

      assert length(body["applications"]) == 1
      assert hd(body["applications"])["job_id"] == job.id
    end

    test "403 as employer", %{conn: conn} do
      employer = insert(:employer)
      conn = conn |> auth_conn(employer) |> get("/api/my/applications")
      assert json_response(conn, 403)
    end
  end

  describe "GET /api/my/jobs/:id/applications" do
    test "returns applications for employer's job", %{conn: conn} do
      employer = insert(:employer)
      job = insert(:job, user: employer)
      seeker = insert(:user, role: "seeker")
      insert(:application, user: seeker, job: job)

      conn = conn |> auth_conn(employer) |> get("/api/my/jobs/#{job.id}/applications")
      body = json_response(conn, 200)

      assert length(body["applications"]) == 1
    end

    test "403 when not the job owner", %{conn: conn} do
      employer1 = insert(:employer)
      employer2 = insert(:employer)
      job = insert(:job, user: employer1)

      conn = conn |> auth_conn(employer2) |> get("/api/my/jobs/#{job.id}/applications")
      assert json_response(conn, 403)
    end

    test "403 as seeker", %{conn: conn} do
      seeker = insert(:user, role: "seeker")
      job = insert(:job)

      conn = conn |> auth_conn(seeker) |> get("/api/my/jobs/#{job.id}/applications")
      assert json_response(conn, 403)
    end
  end
end
