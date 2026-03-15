defmodule Angivaonguoi.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :username, :string
    field :hashed_password, :string
    field :password, :string, virtual: true
    field :is_admin, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :username, :password, :is_admin])
    |> validate_required([:email, :username, :password])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email")
    |> validate_length(:username, min: 2, max: 40)
    |> validate_length(:password, min: 6, max: 72)
    |> unique_constraint(:email)
    |> unique_constraint(:username)
    |> hash_password()
  end

  def login_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_required([:email, :password])
  end

  defp hash_password(%Ecto.Changeset{valid?: true, changes: %{password: pw}} = cs) do
    put_change(cs, :hashed_password, Bcrypt.hash_pwd_salt(pw))
  end

  defp hash_password(cs), do: cs
end
