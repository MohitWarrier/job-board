defmodule JobBoardWeb.AuthControllerTest do
  use JobBoardWeb.ConnCase, async: true
  import JobBoard.Factory

  @register_attrs %{
    "email" => "alice@example.com",
    "password" => "password123",
    "role" => "seeker",
    "name" => "Alice"
  }

  describe "POST /api/register" do
    test "201 with valid data", %{conn: conn} do
      conn = post(conn, "/api/register", @register_attrs)
      body = json_response(conn, 201)

      assert body["email"] == "alice@example.com"
      assert body["name"] == "Alice"
      assert body["role"] == "seeker"
      assert body["id"] != nil
    end

    test "422 with missing fields", %{conn: conn} do
      conn = post(conn, "/api/register", %{})
      body = json_response(conn, 422)

      assert body["errors"]["email"] != nil
      assert body["errors"]["password"] != nil
    end

    test "422 with duplicate email", %{conn: conn} do
      insert(:user, email: "alice@example.com")

      conn = post(conn, "/api/register", @register_attrs)
      body = json_response(conn, 422)

      assert "has already been taken" in body["errors"]["email"]
    end

    test "422 with invalid role", %{conn: conn} do
      conn = post(conn, "/api/register", Map.put(@register_attrs, "role", "admin"))
      body = json_response(conn, 422)

      assert body["errors"]["role"] != nil
    end
  end

  describe "POST /api/login" do
    setup do
      JobBoard.Accounts.register_user(@register_attrs)
      :ok
    end

    test "200 with valid credentials", %{conn: conn} do
      conn =
        post(conn, "/api/login", %{"email" => "alice@example.com", "password" => "password123"})

      body = json_response(conn, 200)

      assert is_binary(body["token"])
    end

    test "401 with wrong password", %{conn: conn} do
      conn =
        post(conn, "/api/login", %{"email" => "alice@example.com", "password" => "wrongpass"})

      body = json_response(conn, 401)

      assert body["error"] == "invalid email or password"
    end

    test "401 with nonexistent email", %{conn: conn} do
      conn = post(conn, "/api/login", %{"email" => "nobody@x.com", "password" => "password123"})
      body = json_response(conn, 401)

      assert body["error"] == "invalid email or password"
    end

    test "422 with missing email and password", %{conn: conn} do
      conn = post(conn, "/api/login", %{})
      body = json_response(conn, 422)

      assert body["error"] == "email and password are required"
    end
  end
end
