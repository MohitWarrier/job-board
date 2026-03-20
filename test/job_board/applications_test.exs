defmodule JobBoard.ApplicationsTest do
  use JobBoard.DataCase, async: true
  import JobBoard.Factory

  alias JobBoard.Applications

  describe "apply/3" do
    test "creates an application" do
      seeker = insert(:user, role: "seeker")
      job = insert(:job)

      assert {:ok, application} =
               Applications.apply(seeker, job.id, %{"cover_letter" => "Hire me"})

      assert application.user_id == seeker.id
      assert application.job_id == job.id
      assert application.cover_letter == "Hire me"
      assert application.status == "pending"
    end

    test "prevents duplicate applications" do
      seeker = insert(:user, role: "seeker")
      job = insert(:job)

      assert {:ok, _} = Applications.apply(seeker, job.id, %{})
      assert {:error, changeset} = Applications.apply(seeker, job.id, %{})
      assert errors_on(changeset).job_id != []
    end

    test "raises if job does not exist" do
      seeker = insert(:user, role: "seeker")

      assert_raise Ecto.NoResultsError, fn ->
        Applications.apply(seeker, 999_999, %{})
      end
    end
  end

  describe "list_my_applications/1" do
    test "returns only the user's applications with jobs preloaded" do
      seeker1 = insert(:user, role: "seeker")
      seeker2 = insert(:user, role: "seeker")
      job = insert(:job)

      {:ok, _} = Applications.apply(seeker1, job.id, %{})
      {:ok, _} = Applications.apply(seeker2, job.id, %{})

      apps = Applications.list_my_applications(seeker1)
      assert length(apps) == 1
      assert hd(apps).user_id == seeker1.id
      # job should be preloaded
      assert hd(apps).job.id == job.id
    end
  end

  describe "list_for_job/1" do
    test "returns all applications for a job with users preloaded" do
      seeker1 = insert(:user, role: "seeker")
      seeker2 = insert(:user, role: "seeker")
      job = insert(:job)

      {:ok, _} = Applications.apply(seeker1, job.id, %{})
      {:ok, _} = Applications.apply(seeker2, job.id, %{})

      apps = Applications.list_for_job(job)
      assert length(apps) == 2
      # users should be preloaded
      emails = Enum.map(apps, & &1.user.email)
      assert seeker1.email in emails
      assert seeker2.email in emails
    end
  end
end
