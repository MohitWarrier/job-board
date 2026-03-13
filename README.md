# Job Board API

REST API for a job listings platform. Built with Elixir/Phoenix + PostgreSQL.

## Setup

```bash
mix deps.get
mix ecto.setup
mix phx.server
```

Server runs at `http://localhost:4000`.

## API Routes

### Public (no auth)

```
POST   /api/register              Create account
POST   /api/login                 Get JWT token
GET    /api/jobs                  List published jobs
GET    /api/jobs/:id              Get a job
```

Search params on `/api/jobs`: `?q=`, `?loc=`, `?min_salary=`, `?page=`

### Protected (requires `Authorization: Bearer <token>`)

```
POST   /api/jobs                  Create job (employer)
PUT    /api/jobs/:id              Update job (owner)
DELETE /api/jobs/:id              Delete job (owner)
POST   /api/jobs/:id/apply        Apply to job (seeker)
GET    /api/my/applications       My applications (seeker)
GET    /api/my/jobs               My posted jobs (employer)
GET    /api/my/jobs/:id/applications   Applications on my job (employer)
```

## Tech Stack

- **Phoenix 1.8** - web framework
- **Ecto + Postgrex** - database layer
- **Joken** - JWT tokens
- **pbkdf2_elixir** - password hashing
- **Oban** - background jobs

## Data Model

Three tables: `users`, `jobs`, `applications`.

- Users have a `role` field: `"employer"` or `"seeker"`
- Jobs belong to a user (the employer)
- Applications belong to a job and a user (the seeker)
- Unique index on `(job_id, user_id)` prevents duplicate applications

## Running Tests

```bash
mix test
```