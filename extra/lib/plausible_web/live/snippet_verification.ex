defmodule PlausibleWeb.Live.SnippetVerification do
  use PlausibleWeb, :live_view
  use Phoenix.HTML

  alias Plausible.Site.Verification.Checks

  def mount(
        _params,
        %{"domain" => domain},
        socket
      ) do
    if connected?(socket) do
      Process.send_after(self(), :start, 500)
    end

    socket = assign(socket, message: "Verifying your installation...", domain: domain)
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="flex justify-center w-full">
      <div class="block pulsating-circle"></div>
    </div>
    <div class="w-full h-full">
      <div id="progress" class="text-xs mt-6 animate-pulse">
        <%= @message %>
      </div>
    </div>
    """
  end

  def handle_info(:start, socket) do
    Checks.run("https://#{socket.assigns.domain}", socket.assigns.domain)
    {:noreply, socket}
  end

  def handle_info({:verification_progress, check, status}, socket) do
    {:noreply, assign(socket, message: "#{check}: #{status}")}
  end
end
