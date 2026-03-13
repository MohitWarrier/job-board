# Job Board API

A REST API backend for a job listings platform, built with Elixir and Phoenix. No UI — just a JSON API that a frontend, mobile app, or Postman can talk to.

This is a learning project that covers the core patterns found in every real Elixir/Phoenix backend role:
- Phoenix routing and controllers
- Ecto schemas, changesets, and migrations
- JWT authentication with plugs
- Context modules (separating web from business logic)
- Oban background jobs

---

## Architecture

```
Client (Postman / React / Mobile app)
         │
         │ HTTP request
         ▼
┌─────────────────────────────────────────────┐
│              Phoenix Router                 │
│  Maps URL + HTTP verb to a controller       │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│           AuthPlug (middleware)             │
│  Reads JWT from Authorization header        │
│  Loads current_user onto conn               │
│  Rejects invalid/missing tokens with 401    │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│              Controllers                    │
│  Receive request, call context, return JSON │
│  AuthController / JobController /           │
│  ApplicationController                      │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│           Context Modules                   │
│  Accounts   — register_user, login          │
│  Jobs       — create, list, search, delete  │
│  Applications — apply, list, status         │
│                                             │
│  Plain Elixir. No web knowledge.            │
│  Just business logic + Ecto queries.        │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│           Ecto + PostgreSQL                 │
│  Tables: users, jobs, applications          │
└──────────────────┬──────────────────────────┘
                   │ (on job application)
                   ▼
┌─────────────────────────────────────────────┐
│                 Oban                        │
│  Background job queue backed by Postgres    │
│  EmailWorker → confirmation email async     │
└─────────────────────────────────────────────┘
```

---

## Tech Stack

| Library | Version | Why |
|---------|---------|-----|
| `phoenix` | ~> 1.8.3 | Web framework — router, controllers, plugs |
| `bandit` | ~> 1.5 | HTTP server (replaces Cowboy, pure Elixir) |
| `ecto_sql` | ~> 3.13 | Database query DSL and migration runner |
| `phoenix_ecto` | ~> 4.5 | Connects Phoenix changesets to Ecto |
| `postgrex` | >= 0.0.0 | PostgreSQL driver for Ecto |
| `pbkdf2_elixir` | ~> 2.0 | PBKDF2 password hashing — pure Elixir, no C compiler needed. Same `comeonin` API as bcrypt. |
| `joken` | ~> 2.6 | Generate and verify JWT tokens for auth |
| `jose` | ~> 1.11 | JOSE crypto primitives (Joken depends on this) |
| `oban` | ~> 2.19 | Background job queue backed by Postgres, with retries |
| `jason` | ~> 1.2 | JSON encoding/decoding |
| `swoosh` | ~> 1.16 | Email sending (used in future for real emails) |
| `gettext` | ~> 1.0 | Internationalization |
| `dns_cluster` | ~> 0.2.0 | DNS-based node clustering for distributed deploys |
| `telemetry_metrics` | ~> 1.0 | Observability metrics |
| `telemetry_poller` | ~> 1.0 | Periodic telemetry measurements |
| `phoenix_live_dashboard` | ~> 0.8.3 | Dev dashboard at `/dev/dashboard` |
| `ex_machina` | ~> 2.7 | Test factory helpers — build test data cleanly (test only) |
| `req` | ~> 0.5 | HTTP client (for outgoing requests if needed) |

---

## Data Model

### users
| Column | Type | Notes |
|--------|------|-------|
| `id` | bigint | primary key |
| `email` | string | unique, indexed |
| `password_hash` | string | bcrypt hash — never the plain password |
| `role` | string | `"employer"` or `"seeker"` |
| `name` | string | display name |
| `inserted_at` | naive_datetime | auto |
| `updated_at` | naive_datetime | auto |

### jobs
| Column | Type | Notes |
|--------|------|-------|
| `id` | bigint | primary key |
| `user_id` | bigint | FK → users (the employer who posted it) |
| `title` | string | |
| `description` | text | |
| `location` | string | |
| `salary` | integer | in whole currency units |
| `status` | string | `"draft"` / `"published"` / `"closed"` |
| `inserted_at` | naive_datetime | auto |
| `updated_at` | naive_datetime | auto |

### applications
| Column | Type | Notes |
|--------|------|-------|
| `id` | bigint | primary key |
| `job_id` | bigint | FK → jobs |
| `user_id` | bigint | FK → users (the seeker who applied) |
| `cover_letter` | text | optional |
| `status` | string | `"pending"` / `"reviewed"` / `"rejected"` / `"accepted"` |
| `inserted_at` | naive_datetime | auto |
| `updated_at` | naive_datetime | auto |

> Unique index on `(job_id, user_id)` prevents duplicate applications.

### oban_jobs
Created automatically by Oban's migration. Stores background jobs in Postgres for durability and retry logic.

---

## API Reference

### Public routes (no auth required)

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/register` | Create an account |
| `POST` | `/api/login` | Get a JWT token |
| `GET` | `/api/jobs` | List published jobs |
| `GET` | `/api/jobs?q=elixir&loc=london&min_salary=80000` | Search/filter jobs |
| `GET` | `/api/jobs/:id` | Get a single job |

### Protected routes (require `Authorization: Bearer <token>`)

| Method | Path | Who | Description |
|--------|------|-----|-------------|
| `POST` | `/api/jobs` | employer | Create a job listing |
| `PUT` | `/api/jobs/:id` | employer (owner) | Update a job listing |
| `DELETE` | `/api/jobs/:id` | employer (owner) | Delete a job listing |
| `POST` | `/api/jobs/:id/apply` | seeker | Apply for a job |
| `GET` | `/api/my/applications` | seeker | List my applications |
| `GET` | `/api/my/jobs` | employer | List my posted jobs |
| `GET` | `/api/my/jobs/:id/applications` | employer | Applications for one job |

### Example: Register
```
POST /api/register
Content-Type: application/json

{
  "email": "alice@example.com",
  "password": "secret123",
  "name": "Alice",
  "role": "seeker"
}
```
Response `201 Created`:
```json
{
  "id": 1,
  "email": "alice@example.com",
  "name": "Alice",
  "role": "seeker"
}
```

### Example: Login
```
POST /api/login
Content-Type: application/json

{
  "email": "alice@example.com",
  "password": "secret123"
}
```
Response `200 OK`:
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### Example: Create Job
```
POST /api/jobs
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{
  "title": "Elixir Developer",
  "description": "We are looking for...",
  "location": "London",
  "salary": 90000,
  "status": "published"
}
```
Response `201 Created`:
```json
{
  "id": 42,
  "title": "Elixir Developer",
  "location": "London",
  "salary": 90000,
  "status": "published"
}
```

### HTTP Status Codes Used
| Code | Meaning |
|------|---------|
| `200` | OK — successful read/update |
| `201` | Created — resource created |
| `401` | Unauthorized — missing or invalid token |
| `403` | Forbidden — authenticated but not allowed (wrong role/not owner) |
| `404` | Not Found — resource does not exist |
| `422` | Unprocessable Entity — validation failed (returns errors map) |

---

## Setup

### Prerequisites
- Elixir >= 1.15 and Erlang/OTP >= 26
- PostgreSQL running locally on port 5432 (default credentials: `postgres` / `postgres`)

### Steps
```bash
# Install dependencies
mix deps.get

# Create and migrate the database
mix ecto.setup

# Start the server
mix phx.server
```

The API will be available at `http://localhost:4000`.

---

## Environment Variables

| Variable | Required in | Default | Description |
|----------|-------------|---------|-------------|
| `DATABASE_URL` | production | — | Postgres connection URL |
| `SECRET_KEY_BASE` | production | — | Phoenix secret key (64+ char string) |
| `JWT_SECRET` | all | set in config | Secret key used to sign JWT tokens |
| `PHX_HOST` | production | — | Your domain name |
| `PORT` | production | 4000 | HTTP port |

In development, these are set in `config/dev.exs`. For production, set them as environment variables — they are read from `config/runtime.exs`.

---

## Running Tests

```bash
mix test
```

This creates/migrates the test database automatically, then runs all tests.

### Test structure
| File | What it covers |
|------|----------------|
| `test/job_board/accounts_test.exs` | Accounts context — register, login, duplicate email, wrong password |
| `test/job_board/jobs_test.exs` | Jobs context — CRUD, search, authorization |
| `test/job_board/applications_test.exs` | Applications context — apply, duplicate prevention |
| `test/job_board_web/controllers/auth_controller_test.exs` | HTTP: register and login endpoints |
| `test/job_board_web/controllers/job_controller_test.exs` | HTTP: job CRUD, role checks, 401/403 responses |
| `test/job_board_web/controllers/application_controller_test.exs` | HTTP: apply, list applications |

### Test helpers
- `DataCase` — wraps each test in a transaction, rolled back after. Use for context tests.
- `ConnCase` — sets up a Phoenix conn for HTTP tests. Use for controller tests.
- `Factory` (ex_machina) — `insert(:user)`, `insert(:job)`, `insert(:application)` — clean test data.

---

## Development Workflow

### Adding a new migration
```bash
mix ecto.gen.migration create_my_table
# edit priv/repo/migrations/*_create_my_table.exs
mix ecto.migrate
```

### Adding a new route end-to-end
1. Add the route to `lib/job_board_web/router.ex`
2. Add the action to the controller in `lib/job_board_web/controllers/`
3. Add the business logic to the context in `lib/job_board/`
4. Write a test in `test/job_board_web/controllers/` and `test/job_board/`

### Mix aliases
| Command | What it does |
|---------|-------------|
| `mix setup` | Install deps, create DB, migrate, seed |
| `mix ecto.reset` | Drop DB and run setup again |
| `mix test` | Auto-migrate test DB and run all tests |
| `mix precommit` | Compile (warnings as errors), check unused deps, format, test |

---

## Background Jobs (Oban)

When a seeker applies for a job:
1. The application is saved to the database
2. HTTP `201` is returned immediately (fast)
3. An `EmailWorker` job is enqueued in the `oban_jobs` table
4. Oban picks it up asynchronously and "sends" the confirmation email

### Inspecting the queue

In `psql` or any DB client:
```sql
SELECT id, queue, worker, state, args, attempt, max_attempts
FROM oban_jobs
ORDER BY inserted_at DESC;
```

States: `available` → `executing` → `completed` (or `retryable` → `discarded` on failure)

### Queue configuration
- Queue name: `emails`
- Concurrency: 5 (5 jobs can run simultaneously)
- Max attempts: 3 (Oban retries failed jobs with exponential backoff)

---
