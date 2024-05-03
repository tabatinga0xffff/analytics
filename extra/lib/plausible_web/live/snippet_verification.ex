defmodule PlausibleWeb.Live.SnippetVerification do
  use PlausibleWeb, :live_view
  use Phoenix.HTML

  def mount(
        _params,
        %{"domain" => domain},
        socket
      ) do
    IO.inspect(:mount)

    if connected?(socket) do
      IO.inspect(:sending)
      Process.send_after(self(), :rotate_message, 1500)
    else
      IO.inspect(:not_connected)
    end

    socket = assign(socket, message: "Verifying your installation...", domain: domain)
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="flex justify-center w-full">
      <div class="block pulsating-circle"></div>
    </div>
    <div class="text-xs mt-6">
      <%= @message %>
    </div>
    """
  end

  def handle_info(:rotate_message, socket) do
    IO.inspect(:rotate)
    Process.send_after(self(), :rotate_message, Enum.random(400..1500))
    {:noreply, assign(socket, message: rotate_message(socket.assigns))}
  end

  def rotate_message(assigns) do
    Enum.random([
      "Connecting to #{assigns.domain}...",
      "Checking host availability...",
      "Looking for the snippet...",
      "Visiting the website..."
    ])
  end
end
