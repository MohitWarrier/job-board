defmodule JobBoard.AccountsTest do
  use JobBoard.DataCase, async: true
  import JobBoard.Factory

  alias JobBoard.Accounts

  @valid_attrs %{
    "email" => "alice@example.com",
    "password" => "password123",
    "role" => "seeker",
    "name" => "Alice"
  }

  describe "register_user/1" do
    test "creates a user with valid attrs" do
      assert {:ok, user} = Accounts.register_user(@valid_attrs)
      assert user.email == "alice@example.com"
      assert user.role == "seeker"
      assert user.name == "Alice"
      assert user.password_hash != nil
      assert user.password == nil
    end

    test "fails with missing email" do
      attrs = Map.delete(@valid_attrs, "email")
      assert {:error, changeset} = Accounts.register_user(attrs)
      assert "can't be blank" in errors_on(changeset).email
    end

    test "fails with short password" do
      attrs = Map.put(@valid_attrs, "password", "short")
      assert {:error, changeset} = Accounts.register_user(attrs)
      assert "must be at least 8 characters" in errors_on(changeset).password
    end

    test "fails with invalid role" do
      attrs = Map.put(@valid_attrs, "role", "admin")
      assert {:error, changeset} = Accounts.register_user(attrs)
      assert errors_on(changeset).role != []
    end

    test "fails with invalid email format" do
      attrs = Map.put(@valid_attrs, "email", "not-an-email")
      assert {:error, changeset} = Accounts.register_user(attrs)
      assert "must include @" in errors_on(changeset).email
    end

    test "fails with duplicate email" do
      assert {:ok, _} = Accounts.register_user(@valid_attrs)
      assert {:error, changeset} = Accounts.register_user(@valid_attrs)
      assert "has already been taken" in errors_on(changeset).email
    end
  end

  describe "login/2" do
    setup do
      {:ok, user} = Accounts.register_user(@valid_attrs)
      %{user: user}
    end

    test "returns token with correct credentials" do
      assert {:ok, token} = Accounts.login("alice@example.com", "password123")
      assert is_binary(token)
    end

    test "fails with wrong password" do
      assert {:error, :invalid_credentials} = Accounts.login("alice@example.com", "wrongpass")
    end

    test "fails with nonexistent email" do
      assert {:error, :invalid_credentials} = Accounts.login("nobody@example.com", "password123")
    end
  end

  describe "get_user/1" do
    test "returns user by id" do
      user = insert(:user)
      assert found = Accounts.get_user(user.id)
      assert found.id == user.id
    end

    test "returns nil for nonexistent id" do
      assert Accounts.get_user(999_999) == nil
    end
  end

  describe "generate_token/1 and verify_token/1" do
    test "round-trips user id" do
      user = insert(:user)
      token = Accounts.generate_token(user)
      assert {:ok, user_id} = Accounts.verify_token(token)
      assert user_id == user.id
    end

    test "rejects tampered token" do
      assert {:error, _} = Accounts.verify_token("garbage.token.here")
    end
  end
end
