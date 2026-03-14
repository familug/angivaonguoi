defmodule Angivaonguoi.AccountsTest do
  use Angivaonguoi.DataCase

  alias Angivaonguoi.Accounts
  alias Angivaonguoi.Accounts.User

  describe "register_user/1" do
    test "creates a user with valid attrs" do
      assert {:ok, %User{} = user} =
               Accounts.register_user(%{
                 email: "alice@example.com",
                 username: "alice",
                 password: "secret123"
               })

      assert user.email == "alice@example.com"
      assert user.username == "alice"
      assert user.hashed_password != "secret123"
    end

    test "returns error for missing fields" do
      assert {:error, changeset} = Accounts.register_user(%{})
      assert %{email: _, username: _, password: _} = errors_on(changeset)
    end

    test "returns error for invalid email" do
      assert {:error, changeset} =
               Accounts.register_user(%{email: "notanemail", username: "bob", password: "pass123"})

      assert "must be a valid email" in errors_on(changeset).email
    end

    test "returns error for short password" do
      assert {:error, changeset} =
               Accounts.register_user(%{email: "bob@example.com", username: "bob", password: "ab"})

      assert errors_on(changeset).password != []
    end

    test "enforces unique email" do
      Accounts.register_user(%{email: "dup@example.com", username: "user1", password: "pass123"})

      assert {:error, changeset} =
               Accounts.register_user(%{
                 email: "dup@example.com",
                 username: "user2",
                 password: "pass123"
               })

      assert "has already been taken" in errors_on(changeset).email
    end

    test "enforces unique username" do
      Accounts.register_user(%{email: "a@example.com", username: "taken", password: "pass123"})

      assert {:error, changeset} =
               Accounts.register_user(%{
                 email: "b@example.com",
                 username: "taken",
                 password: "pass123"
               })

      assert "has already been taken" in errors_on(changeset).username
    end
  end

  describe "authenticate/2" do
    setup do
      {:ok, user} =
        Accounts.register_user(%{
          email: "auth@example.com",
          username: "authuser",
          password: "correct_pass"
        })

      {:ok, user: user}
    end

    test "returns user for correct credentials", %{user: user} do
      assert {:ok, authenticated} = Accounts.authenticate("auth@example.com", "correct_pass")
      assert authenticated.id == user.id
    end

    test "returns error for wrong password" do
      assert {:error, :invalid_credentials} =
               Accounts.authenticate("auth@example.com", "wrong_pass")
    end

    test "returns error for unknown email" do
      assert {:error, :invalid_credentials} =
               Accounts.authenticate("nobody@example.com", "whatever")
    end
  end
end
