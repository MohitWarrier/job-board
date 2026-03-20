# Job Board API

REST API backend for a job listings platform. Employers post jobs, seekers browse and apply. Built with Elixir, Phoenix, and PostgreSQL.

## Setup

Requires Elixir 1.17+, PostgreSQL 15+.

```bash
mix deps.get
mix ecto.setup
mix phx.server
```

Runs at `http://localhost:4000`.

## API

All requests and responses use JSON. Protected routes require `Authorization: Bearer <token>` header.

### Public

| Method | Path | Description |
|--------|------|-------------|
| POST | /api/register | Create account |
| POST | /api/login | Get JWT token |
| GET | /api/jobs | List published jobs |
| GET | /api/jobs/:id | Get a single job |

Search params on `GET /api/jobs`: `?q=elixir`, `?loc=london`, `?min_salary=80000`, `?page=2`

### Protected (token required)

| Method | Path | Who | Description |
|--------|------|-----|-------------|
| POST | /api/jobs | employer | Create a job |
| PUT | /api/jobs/:id | owner | Update a job |
| DELETE | /api/jobs/:id | owner | Delete a job |
| POST | /api/jobs/:id/apply | seeker | Apply for a job |
| GET | /api/my/applications | seeker | List my applications |
| GET | /api/my/jobs | employer | List my posted jobs |
| GET | /api/my/jobs/:id/applications | employer | List applications on my job |

## Data Model

Three tables: `users`, `jobs`, `applications`.

- Users have a `role`: `"employer"` or `"seeker"`
- Jobs belong to a user (the employer who posted it)
- Applications belong to a job and a user (the seeker who applied)
- Unique constraint on (job_id, user_id) prevents duplicate applications
- When a seeker applies, a background job (Oban) logs a confirmation email

## Auth

- Passwords are hashed with pbkdf2 before storage
- Login returns a signed JWT token (HS256, 24h expiry)
- Protected routes use a plug that verifies the token and loads the user

## Tech

- **Phoenix 1.8** -- web framework
- **Ecto + Postgrex** -- database layer
- **Joken** -- JWT tokens
- **pbkdf2_elixir** -- password hashing (pure Elixir, no C compiler needed)
- **Oban** -- background job queue (backed by Postgres)
- **ex_machina** -- test factories

## Project Structure

```
lib/
  job_board/
    accounts.ex              # User business logic (register, login, JWT)
    accounts/user.ex         # User schema + validations
    jobs.ex                  # Job business logic (CRUD, search, pagination)
    jobs/job.ex              # Job schema + validations
    applications.ex          # Application business logic (apply, list)
    applications/application.ex  # Application schema + validations
    workers/email_worker.ex  # Oban worker for confirmation emails
    repo.ex                  # Database gateway
  job_board_web/
    router.ex                # URL -> controller mapping, pipelines
    plugs/auth_plug.ex       # JWT verification plug
    controllers/
      auth_controller.ex     # Register + login endpoints
      job_controller.ex      # Job CRUD endpoints
      application_controller.ex  # Apply + list endpoints
priv/repo/migrations/        # Database table definitions
config/                       # Environment-specific config
```

## Tests

```bash
mix test
```

## Docs

Detailed codebase documentation (architecture walkthrough, concept explanations, feature tracker) is in the `docs/` folder.
