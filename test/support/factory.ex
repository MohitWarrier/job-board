defmodule JobBoard.Factory do
  use ExMachina.Ecto, repo: JobBoard.Repo

  def user_factory do
    %JobBoard.Accounts.User{
      email: sequence(:email, &"user#{&1}@example.com"),
      password_hash: Pbkdf2.hash_pwd_salt("password123"),
      role: "seeker",
      name: sequence(:name, &"User #{&1}")
    }
  end

  def employer_factory do
    struct!(user_factory(), role: "employer")
  end

  def job_factory do
    %JobBoard.Jobs.Job{
      title: sequence(:title, &"Elixir Developer #{&1}"),
      description: "Build Phoenix APIs",
      location: "Remote",
      salary: 90_000,
      status: "published",
      user: build(:employer)
    }
  end

  def application_factory do
    %JobBoard.Applications.Application{
      cover_letter: "I would love to work here",
      status: "pending",
      job: build(:job),
      user: build(:user)
    }
  end
end
