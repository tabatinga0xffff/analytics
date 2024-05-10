defmodule PlausibleWeb.Live.SnippetVerification do
  use PlausibleWeb, :live_view
  use Phoenix.HTML

  alias Plausible.Site.Verification.Checks
  alias PlausibleWeb.Live.Components.Modal

  # check if npm package installs window.plausible() function
  # ask Marko about skip to dashboard 

  @slowdown_for_frequent_checking :timer.seconds(1)

  def mount(
        _params,
        %{"domain" => domain} = session,
        socket
      ) do
    IO.inspect(self(), label: :child)

    if connected?(socket) and !session["modal"] do
      Process.send_after(self(), :start, 500)
    end

    socket =
      assign(socket,
        domain: domain,
        message: "Verifying your installation...",
        domain: domain,
        finished?: false,
        success?: false,
        modal?: !!session["modal"]
      )

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div :if={@modal?}>
      <.live_component module={Modal} id="verification-modal">
        <.live_component
          module={PlausibleWeb.SnippetVerificationComponent}
          domain={@domain}
          id="verification-within-modal"
          embedded={@modal?}
        />
      </.live_component>

      <PlausibleWeb.Components.Generic.button
        id="add-ip-rule"
        x-data
        x-on:click={Modal.JS.open("verification-modal")}
        phx-click="launch-verification"
        class="mt-4"
      >
        Verify
      </PlausibleWeb.Components.Generic.button>
    </div>

    <.live_component
      :if={!@modal?}
      module={PlausibleWeb.SnippetVerificationComponent}
      domain={@domain}
      id="verification-standalone"
    />
    """
  end

  def handle_event("launch-verification", _, socket) do
    Process.send_after(self(), :start, 500)
    {:noreply, socket}
  end

  def handle_event("retry", _, socket) do
    Process.send_after(self(), :start, 500)

    send_update(PlausibleWeb.SnippetVerificationComponent,
      id:
        if(socket.assigns.modal?,
          do: "verification-within-modal",
          else: "verification-standalone"
        ),
      message: "Verifying your installation...",
      finished?: false,
      success?: false,
      diagnostics: nil
    )

    {:noreply, socket}
  end

  def handle_event("dismiss", _, %{assigns: %{modal?: true}} = socket) do
    {:noreply, Modal.close(socket, "verification-modal")}
  end

  def handle_info(:start, socket) do
    case Plausible.RateLimit.check_rate(
           "site_verification_#{socket.assigns.domain}",
           :timer.minutes(60),
           3
         ) do
      {:allow, _} -> :ok
      {:deny, _} -> :timer.sleep(@slowdown_for_frequent_checking)
    end

    Checks.run("https://#{socket.assigns.domain}", socket.assigns.domain)
    {:noreply, socket}
  end

  def handle_info({:verification_check_start, {check, _state}}, socket) do
    send_update(PlausibleWeb.SnippetVerificationComponent,
      id:
        if(socket.assigns.modal?,
          do: "verification-within-modal",
          else: "verification-standalone"
        ),
      message: "#{check.friendly_name()}..."
    )

    {:noreply, socket}
  end

  def handle_info({:verification_check_finish, {check, _state}}, socket) do
    send_update(PlausibleWeb.SnippetVerificationComponent,
      id:
        if(socket.assigns.modal?,
          do: "verification-within-modal",
          else: "verification-standalone"
        ),
      message: "#{check.friendly_name()} completed"
    )

    {:noreply, socket}
  end

  def handle_info({:verification_end, state}, socket) do
    success? = !state.diagnostics.service_error && state.diagnostics.plausible_installed?

    message =
      cond do
        success? and socket.assigns.modal? ->
          "Plausible is installed on your website 🥳"

        success? ->
          "Plausible is installed on your website 🥳 - awaiting your first pageview"

        true ->
          "Verification failed for https://#{state.data_domain}"
      end

    send_update(PlausibleWeb.SnippetVerificationComponent,
      id:
        if(socket.assigns.modal?,
          do: "verification-within-modal",
          else: "verification-standalone"
        ),
      message: message,
      finished?: true,
      success?: success?,
      diagnostics: state.diagnostics
    )

    {:noreply, socket}
  end
end
