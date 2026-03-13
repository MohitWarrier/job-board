# Project: Job Board API
## A REST API backend for a job listings platform

---

## What you are building

A backend API — no UI, no HTML. Just a server that receives HTTP requests and returns JSON.

A frontend app (or Postman, or curl) can:
- Register as a user (job seeker or employer)
- Log in and get an auth token
- Post a job listing (employer)
- Browse and search job listings (job seeker)
- Apply for a job (job seeker)
- View applications received (employer)
- Get email confirmation when applying (background job)

This is the kind of backend that sits behind every job site, e-commerce platform, or SaaS product. It is the most common type of Elixir backend role.

---

## What is a REST API?

REST is a convention for how a server and client communicate over HTTP.

Instead of loading a web page, the client sends a request like:

```
POST /api/jobs
Content-Type: application/json

{ "title": "Elixir Developer", "company": "Acme", "salary": 90000 }
```

The server processes it and responds with JSON:

```json
{ "id": 42, "title": "Elixir Developer", "status": "published" }
```

No HTML. No browser rendering. Just data going back and forth. The frontend (whether React, mobile app, or Postman) decides how to display it.

Every HTTP request uses a verb that signals intent:
- `GET` — read something
- `POST` — create something
- `PUT` / `PATCH` — update something
- `DELETE` — delete something

---

## Why this is the right first project

Before building real-time systems, you need to know the foundation. Every Elixir job involves:

- Phoenix handling HTTP requests
- Ecto querying a Postgres database
- Changesets validating incoming data
- Auth tokens protecting certain routes
- Background jobs for async work

This project teaches all five. The trivia game and collaborative editor build on top of this foundation. If you skip this and jump straight to real-time, you will be constantly confused by the basics.

---

## Architecture

```
Client (Postman / React / Mobile app)
         │
         │ HTTP request (GET /api/jobs, POST /api/jobs, etc.)
         ▼
┌─────────────────────────────────────────────┐
│              Phoenix Router                 │
│  Maps URL + verb to a controller function  │
│                                             │
│  POST   /api/register    → AuthController   │
│  POST   /api/login       → AuthController   │
│  GET    /api/jobs        → JobController    │
│  POST   /api/jobs        → JobController    │
│  GET    /api/jobs/:id    → JobController    │
│  DELETE /api/jobs/:id    → JobController    │
│  POST   /api/jobs/:id/apply → ApplicationController │
│  GET    /api/my/applications → ApplicationController│
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│           Controllers                       │
│  Receive the request, call context modules, │
│  return JSON response with status code      │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│           Context Modules                   │
│  Accounts   — user registration, login      │
│  Jobs       — create, list, search, delete  │
│  Applications — apply, list, status         │
│                                             │
│  These are plain Elixir modules.            │
│  No web knowledge. Just business logic      │
│  + Ecto queries.                            │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│              Ecto + PostgreSQL              │
│  Tables: users, jobs, applications          │
└─────────────────────────────────────────────┘
                   │
         (on job application)
                   │
                   ▼
┌─────────────────────────────────────────────┐
│                 Oban                        │
│  Background job queue backed by Postgres    │
│  When someone applies → enqueue             │
│  EmailWorker → send confirmation email      │
│  Runs async, retries on failure             │
└─────────────────────────────────────────────┘
```

---

## Concepts this project teaches

### 1. Phoenix Router and Controllers

The router is a table that maps every incoming URL to a function. For example:

```
GET /api/jobs       → JobController.index/2   (list all jobs)
POST /api/jobs      → JobController.create/2  (create a job)
GET /api/jobs/:id   → JobController.show/2    (get one job)
DELETE /api/jobs/:id → JobController.delete/2 (delete a job)
```

A controller function receives the request, calls the appropriate context function, and returns a JSON response with an HTTP status code (200 OK, 201 Created, 404 Not Found, 422 Unprocessable Entity, etc.).

This teaches you: how HTTP request/response works, Phoenix routing, structuring controllers cleanly.

---

### 2. Ecto Schemas and Changesets

An Ecto schema defines the shape of a database table in Elixir:

```elixir
schema "jobs" do
  field :title, :string
  field :description, :string
  field :salary, :integer
  field :location, :string
  field :status, :string, default: "draft"
  belongs_to :user, User
  has_many :applications, Application
  timestamps()
end
```

A changeset is how you validate data before saving it. It's a pipeline of checks:

```elixir
def changeset(job, attrs) do
  job
  |> cast(attrs, [:title, :description, :salary, :location])
  |> validate_required([:title, :description])
  |> validate_length(:title, min: 5, max: 100)
  |> validate_number(:salary, greater_than: 0)
end
```

If any validation fails, the changeset is marked invalid and nothing is saved. You return a 422 error with the validation messages.

This teaches you: Ecto schemas, associations (belongs_to / has_many), changesets, migrations.

---

### 3. Authentication with JWT tokens

When a user logs in, the server:
1. Checks email + password against the database
2. If correct, generates a JWT token (a signed string containing the user's ID)
3. Returns the token to the client

```json
{ "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." }
```

The client stores this token and sends it with every future request:

```
GET /api/jobs
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

The server reads the token, verifies it's valid and not expired, extracts the user ID, and now knows who is making the request.

A plug (Phoenix middleware) sits in front of protected routes and rejects requests with missing or invalid tokens with a 401 Unauthorized response.

This teaches you: how authentication works in practice, Phoenix plugs (middleware), JWT tokens, password hashing.

---

### 4. Context modules — separating web from business logic

Phoenix encourages you to separate concerns:

- **Controllers** know about HTTP — requests, responses, status codes
- **Contexts** know about business logic — what makes a valid job, how to search, what applying means

A context is just a plain Elixir module:

```elixir
defmodule JobBoard.Jobs do
  def list_jobs(filters), do: ...
  def get_job!(id), do: ...
  def create_job(user, attrs), do: ...
  def delete_job(job), do: ...
  def search_jobs(query), do: ...
end
```

The controller calls `Jobs.create_job(current_user, params)` and doesn't care how it works internally. If you later want to add a CLI or a background job that creates jobs, they both call the same context function — no web layer involved.

This teaches you: the most important Phoenix architectural pattern, separation of concerns, why this makes testing easy.

---

### 5. Oban — background jobs

When a job seeker applies for a job, you don't want to send the confirmation email during the HTTP request. If the email server is slow or down, the user waits. Instead:

1. Application is saved to the database
2. HTTP response is returned immediately (fast)
3. An Oban job is enqueued in the background
4. Oban's worker process picks it up and sends the email

Oban persists jobs to Postgres. If the server crashes mid-send, Oban retries when it restarts. You configure max attempts, retry delays, and what to do on permanent failure.

This teaches you: why background jobs exist, Oban basics, async patterns, retry logic.

---

### 6. Testing with ExUnit

Because context modules are pure Elixir with no web knowledge, they are trivial to test:

```elixir
test "create_job with valid attrs saves to database" do
  user = insert(:user)
  attrs = %{title: "Elixir Dev", description: "...", salary: 90000}
  assert {:ok, job} = Jobs.create_job(user, attrs)
  assert job.title == "Elixir Dev"
end

test "create_job with missing title returns error" do
  user = insert(:user)
  assert {:error, changeset} = Jobs.create_job(user, %{})
  assert "can't be blank" in errors_on(changeset).title
end
```

You also write controller tests that make real HTTP requests to your API and assert on the JSON response and status codes.

This teaches you: ExUnit basics, testing context functions, testing HTTP endpoints, why the context pattern makes testing easy.

---

## Data Model

### users
```
id
email             — unique, indexed
password_hash     — bcrypt hashed, never store plain text
role              — "employer" | "seeker"
name
inserted_at
updated_at
```

### jobs
```
id
user_id           — FK to users (the employer who posted it)
title
description
location
salary
status            — "draft" | "published" | "closed"
inserted_at
updated_at
```

### applications
```
id
job_id            — FK to jobs
user_id           — FK to users (the seeker who applied)
cover_letter
status            — "pending" | "reviewed" | "rejected" | "accepted"
inserted_at
updated_at
```

### oban_jobs (created automatically by Oban)
```
id
queue             — "emails"
worker            — "JobBoard.Workers.EmailWorker"
args              — JSON: { "user_id": 42, "job_id": 7, "type": "application_confirmation" }
state             — "available" | "executing" | "completed" | "retryable" | "discarded"
attempt
max_attempts
inserted_at
```

---

## API Routes

```
POST   /api/register                   — create account
POST   /api/login                      — get token

GET    /api/jobs                       — list published jobs (public)
GET    /api/jobs?q=elixir&loc=london   — search jobs (public)
GET    /api/jobs/:id                   — get one job (public)

POST   /api/jobs                       — create job (employer only)
PUT    /api/jobs/:id                   — update job (owner only)
DELETE /api/jobs/:id                   — delete job (owner only)

POST   /api/jobs/:id/apply             — apply for job (seeker only)
GET    /api/my/applications            — my applications (seeker only)
GET    /api/my/jobs                    — my posted jobs (employer only)
GET    /api/my/jobs/:id/applications   — applications for my job (employer only)
```

---

## Build Order

### Phase 1 — Users and auth
1. `mix phx.new job_board --no-html --no-assets` (API-only Phoenix project)
2. Create `users` table and schema
3. Build `Accounts.register_user/1` — hash password, save to DB
4. Build `Accounts.login/2` — check password, return JWT token
5. Build auth plug — reads token from header, loads current user
6. Test with Postman: register → login → get token back

### Phase 2 — Jobs CRUD
7. Create `jobs` table and schema
8. Build `Jobs.create_job/2`, `Jobs.list_jobs/1`, `Jobs.get_job!/1`, `Jobs.delete_job/1`
9. Build `JobController` — routes to context functions, returns JSON
10. Add authorization — only employers can create jobs, only owner can delete
11. Test: create a job, list jobs, delete a job, verify a seeker can't create

### Phase 3 — Applications
12. Create `applications` table and schema
13. Build `Applications.apply/2` — prevent duplicate applications
14. Build `ApplicationController`
15. Test: apply for a job, view applications, verify you can't apply twice

### Phase 4 — Search and filtering
16. Add `Jobs.search_jobs/1` — search by title keyword, filter by location, salary range
17. Add pagination — return 20 jobs per page, accept `?page=2`
18. Test: search for "elixir", filter by salary > 80000

### Phase 5 — Background jobs
19. Add Oban to the project
20. Create `EmailWorker` — logs "sending email to X" (no real email needed for learning)
21. Enqueue `EmailWorker` when application is created
22. Test: apply for job → see Oban job appear in `oban_jobs` table → see it execute

### Phase 6 — Tests
23. Write ExUnit tests for all context functions
24. Write controller tests for all API endpoints
25. Test auth: verify protected routes reject requests without a token

---

## Libraries

| Library | What it does |
|---------|-------------|
| `phoenix` | Web framework, router, controllers |
| `ecto` + `postgrex` | Database queries and migrations |
| `bcrypt_elixir` | Hashing passwords before storing |
| `guardian` or `joken` | Generating and verifying JWT tokens |
| `oban` | Background job queue |
| `jason` | JSON encoding/decoding |
| `ex_machina` | Factory helpers for test data |

---

## What you will learn

| Concept | Where |
|---------|-------|
| REST API design (verbs, status codes, URLs) | All routes |
| Phoenix router and controllers | JobController, AuthController |
| Ecto schemas, changesets, associations | users, jobs, applications |
| Database migrations | All 3 tables |
| Authentication (JWT, plugs, password hashing) | Auth flow |
| Context pattern (separating web from business logic) | Accounts, Jobs, Applications modules |
| Authorization (who can do what) | Employer vs seeker checks |
| Background jobs and async processing | Oban + EmailWorker |
| Pagination and search | Jobs.search_jobs |
| Testing APIs with ExUnit | Phase 6 |