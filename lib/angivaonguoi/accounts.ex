defmodule Angivaonguoi.Accounts do
  import Ecto.Query, warn: false

  alias Angivaonguoi.Repo
  alias Angivaonguoi.Accounts.User

  def get_user(id), do: Repo.get(User, id)

  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: String.downcase(email))
  end

  def register_user(attrs) do
    first_user? = Repo.aggregate(User, :count, :id) == 0

    %User{}
    |> User.registration_changeset(attrs)
    |> Ecto.Changeset.put_change(:is_admin, first_user?)
    |> Repo.insert()
  end

  def valid_refer_code?(code) when is_binary(code) do
    expected = Application.get_env(:angivaonguoi, :refer_code, "changeme")
    String.trim(code) == String.trim(expected)
  end

  def valid_refer_code?(_), do: false

  @doc """
  Verifies email + password. Returns `{:ok, user}` or `{:error, :invalid_credentials}`.
  """
  def authenticate(email, password) when is_binary(email) and is_binary(password) do
    user = get_user_by_email(email)

    cond do
      user && Bcrypt.verify_pass(password, user.hashed_password) ->
        {:ok, user}

      user ->
        {:error, :invalid_credentials}

      true ->
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}
    end
  end
end
