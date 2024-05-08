defmodule PlausibleWeb.Live.SnippetVerification do
  use PlausibleWeb, :live_view
  use Phoenix.HTML

  alias Plausible.Site.Verification.Checks
  alias Phoenix.LiveView.JS
  import PlausibleWeb.Components.Generic

  @slowdown_for_frequent_checking :timer.seconds(1)

  def mount(
        _params,
        %{"domain" => domain},
        socket
      ) do
    if connected?(socket) do
        Process.send_after(self(), :start, 500)
    end

    socket =
      assign(socket,
        domain: domain,
        message: "Verifying your installation...",
        domain: domain,
        finished?: false,
        success?: false
      )

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div
      id="check"
      data-on-success={JS.navigate("/#{URI.encode_www_form(@domain)}?skip_to_dashboard=true")}
    >
      <div class="flex justify-center w-full h-16">
        <div :if={!@finished?} class="block pulsating-circle"></div>
        <div :if={@finished? && !@success?} class="block">
          <.shuttle width={50} height={50} />
        </div>
      </div>
      <div class="w-full h-full">
        <div
          id="progress"
          class={["text-xs mt-6", if(@finished? == false, do: "animate-pulse", else: "font-bold")]}
        >
          <%= @message %>
        </div>
      </div>

      <div :if={@finished? && !@success?} class="">
        <div class="text-xs mt-4">
        <.diagnostics_feedback diagnostics={@diagnostics} />
        </div>

        <.button_link href="#" class="text-xs mt-4" phx-click="retry">
          Retry verification
        </.button_link>
      </div>

      <p class="text-gray-600 dark:text-gray-400 text-xs mt-8 mb-6 w-full text-center leading-normal">
        Need to see the snippet again?
        <.styled_link href={"/#{URI.encode_www_form(@domain)}/snippet"}>
          Click here
        </.styled_link>
        <br /> Skip to the dashboard?
        <.styled_link href={"/#{URI.encode_www_form(@domain)}?skip_to_dashboard=true"}>
          Click here
        </.styled_link>
      </p>
    </div>
    """
  end

  def diagnostics_feedback(assigns) do
    {:error, error} = Plausible.Site.Verification.Diagnostics.diagnostics_to_user_feedback(assigns.diagnostics)
    assigns = assign(assigns, :error, error)

    ~H"""
    <ul class="mt-2 leading-6">
    <li>
      <Heroicons.exclamation_triangle class="text-red-500 w-4 h-4 inline-block mr-1" />
      <span class="text-red-500">
    <%= @error %>
      </span>
      </li>
                          </ul>
    """
  end

  def handle_event("retry", _, socket) do
    Process.send_after(self(), :start, 500)
    {:noreply,
     assign(socket, message: "Verifying your installation...", finished?: false, success?: false)}
  end

  def handle_info(:start, socket) do
    case Plausible.RateLimit.check_rate("site_verification_#{socket.assigns.domain}", :timer.minutes(60), 3) do
      {:allow, _} -> :ok
      {:deny, _} -> :timer.sleep(:timer.seconds(@slowdown_for_frequent_checking))
    end
    Checks.run("https://#{socket.assigns.domain}", socket.assigns.domain)
    {:noreply, socket}
  end

  def handle_info({:verification_check_start, {check, _state}}, socket) do
    {:noreply, assign(socket, message: "#{check.friendly_name()}...")}
  end

  def handle_info({:verification_check_finish, {check, _state}}, socket) do
    {:noreply, assign(socket, message: "#{check.friendly_name()} completed.")}
  end

  def handle_info({:verification_end, state}, socket) do
    success? = !state.diagnostics.service_error && state.diagnostics.plausible_installed?

    message =
      if success? do
        "Plausible is installed on your website 🥳"
      else
        "We could not verify your Plausible installation at https://#{state.data_domain}"
      end

    socket =
      if success? do
        push_event(socket, "js-exec", %{
          to: "#check",
          attr: "data-on-success"
        })
      else
        socket
      end

    {:noreply,
     assign(socket,
       message: message,
       finished?: true,
       diagnostics: state.diagnostics |> IO.inspect(label: :diag),
       success?: success?
     )}
  end
end
