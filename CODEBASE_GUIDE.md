# How This Codebase Works

This document explains every part of the Job Board API codebase, from the highest level down to individual files. No Phoenix or Elixir knowledge is assumed.

---

## 1. What This App Does (The Big Picture)

This is a JSON API server. It sits on your machine, listens on port 4000, and waits for HTTP requests. When a request comes in (from Postman, a browser, a mobile app, anything), it processes the request and sends back a JSON response.

Example: Postman sends `POST /api/register` with `{"email": "alice@example.com", ...}`. The server receives it, saves the user to a PostgreSQL database, and responds with `{"id": 1, "email": "alice@example.com", ...}`.

That's it. No web pages. No HTML. Just JSON in, JSON out.

---

## 2. The Request Journey (How a Request Flows Through the App)

Every single request follows the same path through the code. No exceptions.

```
Postman sends request
       |
       v
   ENDPOINT (lib/job_board_web/endpoint.ex)
   Receives raw HTTP bytes. Parses headers. Parses JSON body.
   You never touch this file. Phoenix handles it.
       |
       v
   ROUTER (lib/job_board_web/router.ex)
   Looks at the URL and HTTP method (POST, GET, etc).
   Finds which controller function to call.
   Also runs pipeline checks (like "does this request have a valid token?").
       |
       v
   CONTROLLER (lib/job_board_web/controllers/*.ex)
   Receives two things:
     - conn: the full request (URL, headers, method, etc.)
     - params: the JSON body parsed into a map
   The controller does NOT contain business logic.
   It calls a context function and turns the result into a JSON response.
       |
       v
   CONTEXT (lib/job_board/*.ex)
   Contains the actual business logic.
   "Register a user" = validate the data, hash the password, save to database.
   "Login" = find user by email, check password, generate a token.
   The context does NOT know about HTTP. It doesn't know about conn,
   status codes, or JSON. It just takes data in and returns results.
       |
       v
   REPO (lib/job_board/repo.ex)
   The single gateway to PostgreSQL. Every database operation goes through Repo.
   Repo.insert() = INSERT INTO ...
   Repo.all() = SELECT * FROM ...
   Repo.get() = SELECT * FROM ... WHERE id = ...
   Repo.delete() = DELETE FROM ...
       |
       v
   POSTGRESQL DATABASE
   The actual database on your machine. Tables: users, jobs, applications.
   Created by running `mix ecto.setup`.
```

### Why so many layers?

Each layer has one job and knows nothing about the layers above it.

- **Router** knows about URLs. It does NOT know how to register a user.
- **Controller** knows about HTTP (status codes, JSON responses). It does NOT know how to hash a password or write SQL.
- **Context** knows about business rules (password must be 8+ chars, email must be unique). It does NOT know about HTTP requests or status codes.
- **Repo** knows how to talk to PostgreSQL. It does NOT know what a "user registration" is.

This separation means:
- If you want to change the URL from `/api/register` to `/api/signup`, you change ONE file: the router. Nothing else.
- If you want to change the password minimum length from 8 to 10, you change ONE file: the context. Nothing else.
- If you want to change the JSON response format, you change ONE file: the controller. Nothing else.

---

## 3. What Is a Context?

A context is a plain Elixir module (just a file with functions). It groups related business logic together.

This app has three contexts:

| Context | File | What it handles |
|---------|------|-----------------|
| Accounts | `lib/job_board/accounts.ex` | Everything about users: registering, logging in, finding a user by ID |
| Jobs | `lib/job_board/jobs.ex` | Everything about job listings: creating, listing, updating, deleting, searching |
| Applications | `lib/job_board/applications.ex` | Everything about job applications: applying, listing applications |

The name "context" is Phoenix terminology. In other frameworks it might be called a "service" or "use case" or "business layer". It's just a module that holds functions.

The rule: **controllers call contexts. Contexts call Repo. Nobody skips a layer.**

A controller never writes `Repo.insert(...)` directly. It always calls a context function like `Accounts.register_user(params)`, and the context calls Repo internally.

Why? Because if you later want to register a user from a different place (a background job, a CLI script, a test), you call the same `Accounts.register_user(params)`. The business logic (validate, hash password, insert) runs the same way regardless of where the call comes from.

---

## 4. What Is a Schema?

A schema is a file that describes what a database table looks like in Elixir.

Your database has a `users` table with columns: id, email, password_hash, role, name, inserted_at, updated_at.

The schema file (`lib/job_board/accounts/user.ex`) maps those columns to Elixir fields. When Repo reads a row from the `users` table, it creates a `%User{}` struct with those fields filled in. When you want to insert a row, you create a `%User{}` struct and Repo converts it to an INSERT statement.

Each table has one schema file:

| Table | Schema file |
|-------|-------------|
| users | `lib/job_board/accounts/user.ex` |
| jobs | `lib/job_board/jobs/job.ex` |
| applications | `lib/job_board/applications/application.ex` |

The schema file also contains **changesets**. A changeset is a set of validation rules that run before data is saved. For example, the User changeset checks: email must contain `@`, password must be 8+ characters, role must be "employer" or "seeker". If any check fails, the data is NOT saved to the database. The changeset collects all the error messages so the controller can send them back to Postman.

---

## 5. What Is a Migration?

A migration is a file that creates or changes a database table.

You write the migration in Elixir. When you run `mix ecto.migrate`, Ecto reads the file and runs the equivalent SQL against your PostgreSQL database.

For example, the line `add :email, :string, null: false` in a migration becomes `email VARCHAR(255) NOT NULL` in SQL.

Each migration has a timestamp in its filename (like `20260310162236`). Ecto runs migrations in timestamp order and tracks which ones have already run, so it never runs the same migration twice.

Migration files live in `priv/repo/migrations/`.

| Migration file | What it creates |
|---------------|-----------------|
| `20260310162236_create_users.exs` | The `users` table with columns: email, password_hash, role, name. Plus a unique index on email. |
| `20260310162240_create_jobs.exs` | The `jobs` table with columns: user_id (FK to users), title, description, location, salary, status. |
| `20260310162243_create_applications.exs` | The `applications` table with columns: job_id (FK to jobs), user_id (FK to users), cover_letter, status. Plus a unique index on (job_id, user_id) to prevent duplicate applications. |

When you ran `mix ecto.setup`, it created the database `job_board_dev` and ran all three migrations, which created all three tables. You verified this in psql with `SELECT * FROM users;`.

---

## 6. What Is a Plug?

A plug is a function that runs on a request before it reaches the controller. It can inspect the request, modify it, or reject it.

Think of it as a security checkpoint. The request has to pass through the plug before it reaches the controller. If the plug doesn't like the request, it sends back an error response and the controller never runs.

This app has one custom plug:

**AuthPlug** (`lib/job_board_web/plugs/auth_plug.ex`)

What it does, step by step:
1. Reads the `Authorization` header from the request
2. Extracts the JWT token from the header (the part after "Bearer ")
3. Verifies the token's signature and checks it's not expired
4. Reads the user ID from inside the token
5. Loads that user from the database using `Repo.get(User, id)`
6. Attaches the user to `conn.assigns.current_user`

If any step fails (no header, invalid token, expired token, user not found), AuthPlug sends back a 401 response and stops. The controller never runs.

If all steps pass, the controller runs and can read `conn.assigns.current_user` to know who is making the request.

---

## 7. What Is a Pipeline?

A pipeline is a named group of plugs defined in the router.

This app has two pipelines:

| Pipeline | Plugs inside it | What it checks |
|----------|----------------|----------------|
| `:api` | `plug :accepts, ["json"]` | Request must accept JSON responses |
| `:authenticated` | `plug :accepts, ["json"]` + `plug JobBoardWeb.AuthPlug` | Request must accept JSON AND must have a valid JWT token |

In the router, each group of routes specifies which pipeline to use with `pipe_through`:

- Public routes (register, login, browse jobs) use `pipe_through :api` — no token needed.
- Protected routes (create jobs, apply for jobs) use `pipe_through :authenticated` — token required.

---

## 8. What Is Repo?

Repo is a 5-line module (`lib/job_board/repo.ex`) that connects to PostgreSQL. It reads the database credentials from `config/dev.exs` (username, password, hostname, database name).

Every database operation in the entire app goes through this one module:

| Elixir code | SQL it runs |
|-------------|-------------|
| `Repo.insert(changeset)` | `INSERT INTO users (email, ...) VALUES ('alice@...', ...)` |
| `Repo.all(User)` | `SELECT * FROM users` |
| `Repo.get(User, 1)` | `SELECT * FROM users WHERE id = 1` |
| `Repo.get_by(User, email: "alice@...")` | `SELECT * FROM users WHERE email = 'alice@...'` |
| `Repo.update(changeset)` | `UPDATE users SET name = '...' WHERE id = 1` |
| `Repo.delete(user)` | `DELETE FROM users WHERE id = 1` |

The database credentials are in `config/dev.exs`:
- hostname: localhost
- database: job_board_dev
- username: postgres
- password: elixir

---

## 9. What Is conn?

`conn` is a struct (a map with fixed keys) that represents the entire HTTP request AND the response being built. Every controller function receives it as the first argument.

**Reading from conn (request data):**

| Field | What it contains | Example value |
|-------|-----------------|---------------|
| `conn.method` | HTTP method | `"POST"` |
| `conn.request_path` | URL path | `"/api/register"` |
| `conn.req_headers` | List of header tuples | `[{"content-type", "application/json"}, ...]` |
| `conn.params` | Parsed JSON body (same as the `params` argument) | `%{"email" => "alice@...", "password" => "secret"}` |
| `conn.assigns` | A scratchpad map for storing custom data | `%{}` or `%{current_user: %User{...}}` after AuthPlug runs |

**Writing to conn (building the response):**

| Function | What it does |
|----------|-------------|
| `put_status(conn, :created)` | Sets the response HTTP status code to 201 |
| `put_status(conn, :unauthorized)` | Sets the response HTTP status code to 401 |
| `json(conn, %{id: 1, email: "..."})` | Converts the map to JSON and sends it back to the client |
| `halt(conn)` | Stops the request. No more plugs or controllers will run. |
| `assign(conn, :current_user, user)` | Stores `user` in `conn.assigns.current_user`. Used by AuthPlug. |

---

## 10. What Is params?

`params` is the second argument every controller function receives. It's the JSON body from the request, parsed into an Elixir map.

If Postman sends:
```json
{"email": "alice@example.com", "password": "secret123", "name": "Alice", "role": "seeker"}
```

Then `params` is:
```
%{"email" => "alice@example.com", "password" => "secret123", "name" => "Alice", "role" => "seeker"}
```

`params` is just `conn.params` pulled out for convenience. They're the same thing.

For routes with URL parameters like `/api/jobs/:id`, the `:id` value also appears in params. If the URL is `/api/jobs/42`, then `params["id"]` is `"42"`.

---

## 11. File Map (Every File and What It Does)

### Files you work with:

| File | Layer | Purpose |
|------|-------|---------|
| `lib/job_board_web/router.ex` | Router | Maps every URL to a controller function. Defines pipelines. |
| `lib/job_board_web/plugs/auth_plug.ex` | Plug | Checks JWT token on protected routes. Loads current_user. |
| `lib/job_board_web/controllers/auth_controller.ex` | Controller | Handles POST /api/register and POST /api/login. |
| `lib/job_board_web/controllers/job_controller.ex` | Controller | Handles all /api/jobs routes (list, show, create, update, delete). |
| `lib/job_board_web/controllers/application_controller.ex` | Controller | Handles applying for jobs and listing applications. |
| `lib/job_board/accounts.ex` | Context | Business logic for users: register, login, find user, generate/verify JWT. |
| `lib/job_board/jobs.ex` | Context | Business logic for jobs: CRUD operations, search. |
| `lib/job_board/applications.ex` | Context | Business logic for applications: apply, list. |
| `lib/job_board/accounts/user.ex` | Schema | Describes the users table. Contains validation rules (changeset). |
| `lib/job_board/jobs/job.ex` | Schema | Describes the jobs table. Contains validation rules. |
| `lib/job_board/applications/application.ex` | Schema | Describes the applications table. Contains validation rules. |
| `lib/job_board/workers/email_worker.ex` | Worker | Background job that sends confirmation emails (via Oban). |
| `lib/job_board/repo.ex` | Repo | 5-line file. The gateway to PostgreSQL. |
| `priv/repo/migrations/*.exs` | Migration | One file per table. Creates tables in the database. |

### Files Phoenix generated (you rarely touch these):

| File | Purpose |
|------|---------|
| `lib/job_board_web/endpoint.ex` | Receives raw HTTP requests, parses them, hands them to the router. |
| `lib/job_board_web.ex` | Defines what `use JobBoardWeb, :controller` and `use JobBoardWeb, :router` paste into your files. |
| `lib/job_board/application.ex` | Starts the app. Launches the database connection pool, the web server, etc. |
| `lib/job_board/mailer.ex` | Email sending configuration. Not used yet. |
| `lib/job_board_web/telemetry.ex` | Metrics collection. Ignore. |
| `lib/job_board_web/gettext.ex` | Translation support. Ignore. |
| `lib/job_board_web/controllers/error_json.ex` | Default error responses. |
| `config/config.exs` | Base configuration (shared across all environments). |
| `config/dev.exs` | Development-specific config: database credentials, debug settings. |
| `config/test.exs` | Test-specific config. |
| `config/prod.exs` | Production-specific config. |
| `config/runtime.exs` | Config read from environment variables at runtime. |
| `mix.exs` | Project manifest. Lists dependencies, defines mix commands. |
| `mix.lock` | Pinned dependency versions (like package-lock.json in Node). |
| `test/support/conn_case.ex` | Test helper for controller tests. |
| `test/support/data_case.ex` | Test helper for context tests. |

---

## 12. Concrete Example: What Happens When You Register

You send from Postman:
```
POST http://localhost:4000/api/register
Content-Type: application/json

{"email": "alice@example.com", "password": "secret123", "name": "Alice", "role": "seeker"}
```

**Step 1 — Endpoint** (`endpoint.ex`)
Parses the raw HTTP bytes. Extracts headers. Parses the JSON body string into an Elixir map. You never see this happen.

**Step 2 — Router** (`router.ex`)
Sees: method is POST, path is `/api/register`. Matches line `post "/register", AuthController, :register`. Runs the `:api` pipeline first (checks the request accepts JSON). Pipeline passes. Calls `JobBoardWeb.AuthController.register(conn, params)`.

**Step 3 — Controller** (`auth_controller.ex`, function `register`)
Receives `conn` and `params`. Calls `Accounts.register_user(params)`.

**Step 4 — Context** (`accounts.ex`, function `register_user`)
Creates an empty `%User{}` struct. Passes it and `params` to `User.registration_changeset()`.

**Step 5 — Schema changeset** (`user.ex`, function `registration_changeset`)
Runs all validations:
- email present? Yes.
- email contains @? Yes.
- password present? Yes.
- password 8+ chars? Yes (9 chars).
- role is "employer" or "seeker"? Yes ("seeker").
- All pass. Hashes the password. Changeset is valid.

**Step 6 — Context calls Repo** (`accounts.ex`)
Calls `Repo.insert(changeset)`. Changeset is valid, so Repo generates SQL:
```sql
INSERT INTO users (email, password_hash, role, name, inserted_at, updated_at)
VALUES ('alice@example.com', '$pbkdf2-sha512$160000$...', 'seeker', 'Alice', '2026-03-13 06:07:44', '2026-03-13 06:07:44')
RETURNING id
```
PostgreSQL executes it. Returns id = 1. Repo returns `{:ok, %User{id: 1, email: "alice@example.com", ...}}`.

**Step 7 — Back to Controller** (`auth_controller.ex`)
`case` matches `{:ok, user}`. Sets status to 201 (`:created`). Builds JSON map from user fields. Sends response.

**Step 8 — Postman receives:**
```json
{"id": 1, "email": "alice@example.com", "name": "Alice", "role": "seeker"}
```

---

## 13. Concrete Example: What Happens When Registration Fails

You send the same email again:
```
POST http://localhost:4000/api/register
{"email": "alice@example.com", "password": "secret123", "name": "Alice2", "role": "seeker"}
```

Steps 1-5 are the same. All validations pass.

**Step 6 — Repo.insert()** runs the INSERT SQL. PostgreSQL rejects it because the unique index on email prevents duplicates. Repo catches the database error and returns `{:error, changeset}` where the changeset contains the error `email: ["has already been taken"]`.

**Step 7 — Back to Controller.** `case` matches `{:error, changeset}`. Sets status to 422 (`:unprocessable_entity`). Calls `format_errors(changeset)` which converts the changeset errors into `%{email: ["has already been taken"]}`. Sends response.

**Step 8 — Postman receives:**
```json
{"errors": {"email": ["has already been taken"]}}
```

This is the "QUERY ERROR" you saw in the logs. It's not a crash. It's PostgreSQL correctly rejecting a duplicate, and the app correctly handling it.

---

## 14. Confusing Terms Clarified

Backend engineering has a lot of overloaded words. The same word means different things in different contexts. Here's every confusing term in this project and what it actually means here.

### "Repo" is NOT a git repository

In everyday coding, "repo" means a git repository (your GitHub project). In Phoenix/Ecto, `Repo` means something completely different.

`Repo` (short for Repository) is a module that sends SQL queries to your PostgreSQL database. It's the only thing in your app that talks to the database. When your code needs to read or write data, it calls `Repo`. That's it.

Think of it like this:
- **Git repo** = a folder tracked by git, stored on GitHub. Has commits, branches, pull requests.
- **Ecto Repo** = a module in your Elixir app that sends SQL to PostgreSQL. Has functions like `insert`, `get`, `delete`.

They share the word "repository" but have zero connection to each other. Ecto borrowed the term from an old software pattern called the "Repository Pattern" which means "a single place that handles all data storage."

### "Migration" is NOT moving data somewhere

In everyday language, "migration" means moving something from one place to another (like migrating servers, migrating from one tool to another). In Ecto, a migration is a file that changes your database structure.

A migration does NOT move data. It creates tables, adds columns, removes columns, adds indexes — it changes the shape of the database. The word comes from the idea that your database "migrates" from one version (no tables) to the next version (has a users table) to the next (has users + jobs tables).

The key things about migrations:
- Each migration is a single file in `priv/repo/migrations/`
- Each file has a timestamp in its name (`20260310162236_create_users.exs`)
- They run in order (oldest first)
- Each migration runs exactly once. Ecto tracks which ones have already run.
- Running `mix ecto.migrate` applies all migrations that haven't run yet
- Running `mix ecto.rollback` undoes the most recent migration

### "Database" vs "Table" vs "Row" vs "Column"

These are nested containers:

```
PostgreSQL (the program running on your machine)
  └── job_board_dev (one database — created by mix ecto.create)
        ├── users (one table — created by the users migration)
        │     ├── row 1: {id: 1, email: "test@example.com", role: "seeker", ...}
        │     └── row 2: {id: 2, email: "debug@example.com", role: "employer", ...}
        ├── jobs (one table — created by the jobs migration)
        │     └── (empty — no jobs created yet)
        └── applications (one table — created by the applications migration)
              └── (empty — no applications yet)
```

- **PostgreSQL** is a program (like Chrome or VS Code). It runs in the background on your machine.
- **Database** (`job_board_dev`) is like a folder inside PostgreSQL. Your app has one database. `mix ecto.create` created it.
- **Table** (`users`, `jobs`, `applications`) is like a spreadsheet inside that database. Migrations created them.
- **Row** is one entry in a table. When you registered in Postman, it created one row in the users table.
- **Column** is a field. `email`, `password_hash`, `role`, `name` are columns in the users table.

### "Schema" vs "Migration" — both describe a table, why two files?

A migration tells PostgreSQL what to CREATE. It runs once, changes the database, and is done. The migration file is never read again after it runs.

A schema tells Elixir what the table LOOKS LIKE. It's used every time your app reads or writes data. When Repo reads a row from the `users` table, it uses the schema to know which columns exist and what types they are, so it can build a proper `%User{}` struct.

Think of it like building a house:
- **Migration** = the construction blueprint. Used once to build the house. Filed away after.
- **Schema** = the floor plan you keep on hand. Used every day to know where the rooms are.

Both describe the same table, but for different purposes and at different times.

### "Changeset" is NOT a git changeset

In git, a changeset is a set of file changes in a commit. In Ecto, a changeset is completely different.

An Ecto changeset is a set of validation rules that data must pass before it gets saved to the database. When someone tries to register with a password that's too short, the changeset catches it and returns an error. If all validations pass, the changeset is "valid" and Repo saves the data. If any validation fails, the changeset is "invalid" and Repo refuses to save.

Think of it as a bouncer at a door. The data has to pass every check before it gets in.

### "Plug" vs "Plugin"

A plug is NOT a plugin you install. It's a function that runs on an HTTP request before it reaches the controller.

The name comes from the idea of "plugging" functions together in a pipeline, like connecting pipes in plumbing. Each plug does one thing: check the token, check the content type, log the request, etc. You chain them together and the request flows through each one.

In FastAPI, the equivalent is middleware or a dependency (`Depends`). In Express.js, it's middleware (`app.use`).

### "Context" is NOT a React context

If you know React, `Context` there means a way to share state across components. In Phoenix, a context is completely different.

A Phoenix context is just a plain Elixir module that groups related functions together. `Accounts` is a context that has functions for register, login, and find user. `Jobs` is a context that has functions for create, list, update, and delete jobs.

The word "context" means "the boundary around a topic." Everything about users is inside the Accounts context. Everything about jobs is inside the Jobs context. If you need to change how login works, you know exactly which file to open: `accounts.ex`.

Other frameworks call the same thing a "service", "use case", or "business logic layer". Phoenix chose the word "context."

### "Endpoint" in Phoenix vs "endpoint" in REST APIs

In REST API documentation, an "endpoint" means a URL you can call (like `POST /api/register` is "the register endpoint").

In Phoenix, `Endpoint` is also a specific module (`lib/job_board_web/endpoint.ex`) that receives raw HTTP connections from the internet, parses them, and passes them to the router. You never edit this file.

When someone says "hit the register endpoint," they mean the URL. When Phoenix docs say "the Endpoint module," they mean the file.

### "Scope" is NOT a variable scope

In programming, "scope" usually means where a variable is visible (local scope, global scope). In Phoenix's router, `scope` means a URL prefix group.

`scope "/api" do` means: every route inside this block gets `/api` added to the front of its URL. So `post "/register"` becomes `POST /api/register`. It's just a way to avoid typing `/api` on every single line.

You can have multiple scopes. You could have `scope "/api/v1"` and `scope "/api/v2"` for different API versions. Each scope just adds a different prefix.

---

## 15. How `use` Works (skip this if you're not curious yet)

Many files start with a line like `use JobBoardWeb, :controller` or `use Ecto.Schema`. This is confusing because it looks like magic.

`use` does one thing: it finds a special function in the target module and runs it. The code that function returns gets copy-pasted into your file at compile time.

Concretely:

`use JobBoardWeb, :router` goes to `lib/job_board_web.ex`, runs the `router` function, which returns three lines of code. Those three lines get pasted into your router file. Those three lines give your router the ability to use `pipeline`, `scope`, `get`, `post`, `plug`, etc. Without `use JobBoardWeb, :router`, none of those keywords would exist.

`use JobBoardWeb, :controller` does the same thing but returns different lines — ones that give your controller the ability to use `json`, `put_status`, etc.

`use Ecto.Schema` gives your module the `schema` and `field` keywords.

`use Ecto.Migration` gives your module the `create`, `add`, `table` keywords.

You don't need to understand the internals. Just know: `use Something` = "give me the tools that Something provides."

---

## 15. How Module Names Map to Files

In Elixir, file paths and module names are independent. A module's name is decided by the `defmodule` line inside the file, NOT by where the file is on disk.

| Module name (inside the file) | File path (on disk) |
|-------------------------------|---------------------|
| `JobBoardWeb.Router` | `lib/job_board_web/router.ex` |
| `JobBoardWeb.AuthController` | `lib/job_board_web/controllers/auth_controller.ex` |
| `JobBoardWeb.AuthPlug` | `lib/job_board_web/plugs/auth_plug.ex` |
| `JobBoard.Accounts` | `lib/job_board/accounts.ex` |
| `JobBoard.Accounts.User` | `lib/job_board/accounts/user.ex` |
| `JobBoard.Repo` | `lib/job_board/repo.ex` |

When the router says `plug JobBoardWeb.AuthPlug`, Elixir searches for a module named `JobBoardWeb.AuthPlug`. It does NOT look for a file at `job_board_web/auth_plug.ex`. It finds the module by name, wherever the file happens to be.

The file paths follow a convention (controllers go in `controllers/`, plugs go in `plugs/`), but this is for human organization only. Elixir would work the same if every file was in one flat folder.

---

## 16. Config Files

Configuration is split across multiple files in the `config/` folder:

| File | When it's loaded | What it configures |
|------|-----------------|-------------------|
| `config/config.exs` | Always | Settings shared across all environments. JWT secret, Oban queues, JSON library. |
| `config/dev.exs` | Only in development (`mix phx.server`) | Database credentials (postgres/elixir/localhost/job_board_dev). Debug settings. Dev dashboard. |
| `config/test.exs` | Only during tests (`mix test`) | Test database name (job_board_test). Faster password hashing for speed. |
| `config/prod.exs` | Only in production | Minimal settings. Most production config comes from runtime.exs. |
| `config/runtime.exs` | At application startup | Reads environment variables (DATABASE_URL, SECRET_KEY_BASE). Used in production. |

`config.exs` loads first, then the environment-specific file overrides it. So `config.exs` sets `jwt_secret: "dev_secret_change_in_production"`, and `runtime.exs` could override it in production by reading from an environment variable.

---

## 17. Mix Commands

`mix` is Elixir's command-line tool (like `npm` in Node or `pip`/`python` in Python).

| Command | What it does |
|---------|-------------|
| `mix deps.get` | Downloads dependencies listed in mix.exs (like `npm install`) |
| `mix ecto.create` | Connects to PostgreSQL and runs `CREATE DATABASE job_board_dev` |
| `mix ecto.migrate` | Reads migration files and runs the SQL to create/change tables |
| `mix ecto.setup` | Runs `ecto.create` + `ecto.migrate` + seeds (all in one) |
| `mix ecto.reset` | Drops the database and runs `ecto.setup` again (fresh start) |
| `mix phx.server` | Starts the web server on port 4000 |
| `mix phx.routes` | Prints every URL → controller mapping (the full route table) |
| `mix test` | Runs all tests |
| `mix compile` | Compiles all Elixir files |

---

## 18. Glossary

| Term | What it means |
|------|--------------|
| **Endpoint** | The entry point of the web server. Receives raw HTTP, parses it, hands it to the router. You don't touch this file. |
| **Router** | A lookup table: URL + HTTP method → controller function. Also defines pipelines. |
| **Pipeline** | A named group of checks (plugs) that run before the controller. Example: `:authenticated` checks for a valid JWT token. |
| **Plug** | A function that runs on a request. Can inspect it, modify it, or reject it. Like middleware in Express.js or FastAPI. |
| **Controller** | Receives the HTTP request (conn + params), calls a context function, sends back a JSON response. Thin layer — no business logic. |
| **Context** | A module of functions that contain business logic. Accounts context handles users. Jobs context handles jobs. Called by controllers. Calls Repo. |
| **Schema** | A file that describes a database table's columns in Elixir. Also contains changesets (validation rules). |
| **Changeset** | A set of validation rules. Runs before data is saved. If any rule fails, the data is NOT saved and errors are returned. |
| **Migration** | A file that creates or changes a database table. Run once via `mix ecto.migrate`. |
| **Repo** | The single module that talks to PostgreSQL. Every database read/write goes through it. |
| **conn** | A struct representing the HTTP request and the response being built. Every controller function receives it. |
| **params** | The parsed JSON body from the request, as an Elixir map. Second argument to every controller function. |
| **Struct** | An Elixir map with fixed keys. `%User{id: 1, email: "..."}` is a struct. Like a Python dataclass or a TypeScript interface. |
| **Atom** | A constant like `:ok`, `:error`, `:created`. Written with a colon prefix. Used as labels, not as data. Similar to symbols in Ruby or enums in other languages. |
| **Pattern matching** | Elixir's way of destructuring. `{:ok, user} = Accounts.register_user(params)` pulls the second element into `user` if the first element is `:ok`. If it's not `:ok`, it crashes (or in a `case` block, tries the next branch). |
| **Pipe operator (`\|>`)** | Takes the result of the left side and passes it as the first argument to the right side. `conn \|> put_status(:created) \|> json(%{...})` is the same as `json(put_status(conn, :created), %{...})`. Just easier to read. |
| **`defp`** | Defines a private function. Can only be called from within the same module. `def` is public (callable from anywhere), `defp` is private. |
| **`alias`** | A shortcut. `alias JobBoard.Accounts` lets you write `Accounts` instead of `JobBoard.Accounts`. Does not import functions — just shortens the module name. |
| **`import`** | Brings all functions from another module into the current one. `import Ecto.Changeset` lets you write `cast(...)` instead of `Ecto.Changeset.cast(...)`. |
| **`use`** | Runs a special function in the target module and pastes the returned code into your file. Gives your module new capabilities (like `schema`, `pipeline`, `json`, etc). |