defmodule JobBoard.Workers.EmailWorker do
  @moduledoc """
  Oban worker that sends a confirmation email after a job application.

  This worker is enqueued by `JobBoard.Applications.apply/3` after a successful
  application is saved to the database. Oban runs it asynchronously — the HTTP
  response is already returned to the user before this executes.

  If the worker crashes, Oban automatically retries it (up to max_attempts times)
  with exponential backoff. The job state moves:
    available → executing → completed
                         → retryable (on failure, until max_attempts)
                         → discarded (after max_attempts exhausted)

  TODO Phase 5: hook this up in Applications.apply/3 and add Oban to the
  supervision tree in lib/job_board/application.ex.
  """

  use Oban.Worker, queue: :emails, max_attempts: 3

  alias JobBoard.Accounts
  alias JobBoard.Jobs

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "job_id" => job_id, "type" => type}}) do
    user = Accounts.get_user(user_id)
    job = Jobs.get_job!(job_id)

    # For learning purposes we just log the email instead of sending a real one.
    # In production you would call a Swoosh mailer here.
    require Logger

    Logger.info("""
    [EmailWorker] #{type}
      To: #{user.email} (#{user.name})
      Job: #{job.title}
      Message: Thank you for applying! We'll be in touch.
    """)

    :ok
  end
end
