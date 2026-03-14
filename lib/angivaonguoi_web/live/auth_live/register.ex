defmodule AngivaonguoiWeb.AuthLive.Register do
  use AngivaonguoiWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: :user), trigger_submit: false)}
  end

  @impl true
  def handle_event("register", params, socket) do
    {:noreply, assign(socket, form: to_form(params, as: :user), trigger_submit: true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-sm mx-auto px-4 py-16">
      <div class="card bg-base-100 border border-base-200 shadow">
        <div class="card-body space-y-4">
          <h1 class="text-2xl font-bold text-center">Create Account</h1>

          <.form
            for={@form}
            action={~p"/register"}
            phx-submit="register"
            phx-trigger-action={@trigger_submit}
            class="space-y-4"
          >
            <div>
              <label class="label"><span class="label-text">Email</span></label>
              <input
                type="email"
                name="user[email]"
                class="input input-bordered w-full"
                placeholder="you@example.com"
                required
              />
            </div>

            <div>
              <label class="label"><span class="label-text">Username</span></label>
              <input
                type="text"
                name="user[username]"
                class="input input-bordered w-full"
                placeholder="yourname"
                required
              />
            </div>

            <div>
              <label class="label"><span class="label-text">Password</span></label>
              <input
                type="password"
                name="user[password]"
                class="input input-bordered w-full"
                placeholder="min 6 characters"
                required
              />
            </div>

            <button type="submit" class="btn btn-primary w-full">Register</button>
          </.form>

          <p class="text-center text-sm text-gray-500">
            Already have an account?
            <.link navigate={~p"/login"} class="link link-primary">Log in</.link>
          </p>
        </div>
      </div>
    </div>
    """
  end
end
