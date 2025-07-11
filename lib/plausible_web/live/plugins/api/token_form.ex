defmodule PlausibleWeb.Live.Plugins.API.TokenForm do
  @moduledoc """
  Live view for the goal creation form
  """
  use PlausibleWeb, live_view: :no_sentry_context
  import PlausibleWeb.Live.Components.Form

  alias Plausible.Plugins.API.{Token, Tokens}

  def mount(
        _params,
        %{
          "token_description" => token_description,
          "domain" => domain,
          "rendered_by" => pid
        },
        socket
      ) do
    socket =
      socket
      |> assign_new(:site, fn %{current_user: current_user} ->
        Plausible.Sites.get_for_user!(current_user, domain, [
          :owner,
          :admin,
          :editor,
          :super_admin
        ])
      end)

    token = Token.generate()
    form = to_form(Token.insert_changeset(socket.assigns.site, token))

    {:ok,
     assign(socket,
       token_description: token_description,
       token: token,
       form: form,
       domain: domain,
       rendered_by: pid,
       token_generated: false
     )}
  end

  def render(assigns) do
    ~H"""
    <div
      class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity z-50"
      phx-window-keydown="close-tokens-modal"
      phx-key="Escape"
    >
    </div>
    <div class="fixed inset-0 flex items-center justify-center mt-16 z-50 overflow-y-auto overflow-x-hidden">
      <div class="w-1/2 h-full">
        <div
          class="max-w-md w-full mx-auto bg-white dark:bg-gray-800 shadow-md rounded px-8 pt-6 pb-8 mb-4 mt-8"
          phx-click-away="close-token-modal"
        >
          <%= if @token_generated do %>
            <div class="mt-4">
              <.input_with_clipboard
                id="token-clipboard"
                name="token_clipboard"
                label="Plugin Token"
                value={@token.raw}
              />
            </div>
            <p class="mt-4 text-sm text-gray-500 dark:text-gray-400">
              Please copy the token and store it in a secure place as it won't be shown again.
              <span :if={@token_description == "WordPress"}>
                You'll need to paste the token in the settings area of the Plausible WordPress plugin.
              </span>
            </p>
            <.button
              phx-click="close-token-modal"
              class="w-full border !border-gray-300 dark:!border-gray-500 !text-gray-700 dark:!text-gray-300 !bg-transparent hover:!bg-gray-100 dark:hover:!bg-gray-850"
            >
              Close modal
            </.button>
          <% else %>
            <.form :let={f} for={@form} phx-submit="generate-token">
              <.title>
                Create Plugin Token for {@domain}
              </.title>

              <div class="mt-4">
                <.input
                  autofocus
                  field={f[:description]}
                  label="Description"
                  placeholder="e.g. Your Plugin Name"
                  value={@token_description}
                  autocomplete="off"
                  disabled={@token_generated}
                />
              </div>

              <p class="mt-4 text-sm text-gray-500 dark:text-gray-400">
                Once created, we will display the token so it can be copied.
              </p>
              <.button type="submit" class="w-full">
                Create Plugin Token
              </.button>
            </.form>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("generate-token", %{"token" => %{"description" => description}}, socket) do
    case Tokens.create(socket.assigns.site, description, socket.assigns.token) do
      {:ok, token, _} ->
        send(socket.assigns.rendered_by, {:token_created, token})
        {:noreply, assign(socket, token_generated: true)}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("close-token-modal", _value, socket) do
    send(socket.assigns.rendered_by, :close_token_modal)
    {:noreply, socket}
  end
end
