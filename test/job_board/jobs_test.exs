defmodule JobBoard.JobsTest do
  use JobBoard.DataCase, async: true
  import JobBoard.Factory

  alias JobBoard.Jobs

  @valid_attrs %{
    "title" => "Elixir Developer",
    "description" => "Build Phoenix APIs",
    "location" => "Remote",
    "salary" => "90000",
    "status" => "published"
  }

  describe "create_job/2" do
    test "creates a job with valid attrs" do
      employer = insert(:employer)
      assert {:ok, job} = Jobs.create_job(employer, @valid_attrs)
      assert job.title == "Elixir Developer"
      assert job.user_id == employer.id
    end

    test "fails with missing title" do
      employer = insert(:employer)
      attrs = Map.delete(@valid_attrs, "title")
      assert {:error, changeset} = Jobs.create_job(employer, attrs)
      assert errors_on(changeset).title != []
    end

    test "fails with short title" do
      employer = insert(:employer)
      attrs = Map.put(@valid_attrs, "title", "Hi")
      assert {:error, changeset} = Jobs.create_job(employer, attrs)
      assert errors_on(changeset).title != []
    end

    test "fails with negative salary" do
      employer = insert(:employer)
      attrs = Map.put(@valid_attrs, "salary", "-100")
      assert {:error, changeset} = Jobs.create_job(employer, attrs)
      assert errors_on(changeset).salary != []
    end
  end

  describe "list_jobs/0" do
    test "returns only published jobs" do
      employer = insert(:employer)
      {:ok, _draft} = Jobs.create_job(employer, Map.put(@valid_attrs, "status", "draft"))
      {:ok, pub} = Jobs.create_job(employer, @valid_attrs |> Map.put("title", "Published Job"))

      jobs = Jobs.list_jobs()
      assert length(jobs) == 1
      assert hd(jobs).id == pub.id
    end
  end

  describe "list_my_jobs/1" do
    test "returns only the employer's jobs" do
      employer1 = insert(:employer)
      employer2 = insert(:employer)
      {:ok, job1} = Jobs.create_job(employer1, @valid_attrs)

      {:ok, _job2} =
        Jobs.create_job(employer2, @valid_attrs |> Map.put("title", "Other Job Here"))

      jobs = Jobs.list_my_jobs(employer1)
      assert length(jobs) == 1
      assert hd(jobs).id == job1.id
    end
  end

  describe "get_job!/1" do
    test "returns the job" do
      employer = insert(:employer)
      {:ok, job} = Jobs.create_job(employer, @valid_attrs)
      assert Jobs.get_job!(job.id).id == job.id
    end

    test "raises on not found" do
      assert_raise Ecto.NoResultsError, fn ->
        Jobs.get_job!(999_999)
      end
    end
  end

  describe "update_job/2" do
    test "updates with valid attrs" do
      employer = insert(:employer)
      {:ok, job} = Jobs.create_job(employer, @valid_attrs)
      assert {:ok, updated} = Jobs.update_job(job, %{"title" => "Senior Elixir Dev"})
      assert updated.title == "Senior Elixir Dev"
    end
  end

  describe "delete_job/1" do
    test "deletes the job" do
      employer = insert(:employer)
      {:ok, job} = Jobs.create_job(employer, @valid_attrs)
      assert {:ok, _} = Jobs.delete_job(job)

      assert_raise Ecto.NoResultsError, fn ->
        Jobs.get_job!(job.id)
      end
    end
  end

  describe "search_jobs/1" do
    setup do
      employer = insert(:employer)

      {:ok, _} =
        Jobs.create_job(employer, %{
          @valid_attrs
          | "title" => "Elixir Developer",
            "location" => "London",
            "salary" => "90000"
        })

      {:ok, _} =
        Jobs.create_job(employer, %{
          @valid_attrs
          | "title" => "Python Developer",
            "location" => "Berlin",
            "salary" => "70000"
        })

      {:ok, _} =
        Jobs.create_job(employer, %{
          @valid_attrs
          | "title" => "Go Backend Engineer",
            "location" => "London",
            "salary" => "100000"
        })

      :ok
    end

    test "filters by title keyword" do
      jobs = Jobs.search_jobs(%{"q" => "elixir"})
      assert length(jobs) == 1
      assert hd(jobs).title == "Elixir Developer"
    end

    test "filters by location" do
      jobs = Jobs.search_jobs(%{"loc" => "london"})
      assert length(jobs) == 2
    end

    test "filters by min salary" do
      jobs = Jobs.search_jobs(%{"min_salary" => "95000"})
      assert length(jobs) == 1
      assert hd(jobs).title == "Go Backend Engineer"
    end

    test "combines filters" do
      jobs = Jobs.search_jobs(%{"loc" => "london", "min_salary" => "95000"})
      assert length(jobs) == 1
    end

    test "returns all published jobs with no filters" do
      jobs = Jobs.search_jobs(%{})
      assert length(jobs) == 3
    end
  end
end
