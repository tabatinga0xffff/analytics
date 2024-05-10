defmodule PlausibleWeb.SnippetVerificationComponent do
  use Phoenix.LiveComponent

  import PlausibleWeb.Components.Generic

  def update(assigns, socket) do
    socket =
      socket
      |> assign_new(:domain, fn -> assigns.domain end)
      |> assign_new(:embedded, fn -> assigns[:embedded] end)
      |> assign(
        message: assigns[:message] || "Verifying your installation",
        finished?: assigns[:finished?] || false,
        success?: assigns[:success?] || false,
        diagnostics: assigns[:diagnostics]
      )

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class={[
      "bg-white dark:bg-gray-800 text-center h-96 flex flex-col",
      if(!@embedded, do: "shadow-md rounded px-8 pt-6 pb-4 mb-4 mt-16")
    ]}>
      <h2 class="text-xl font-bold dark:text-gray-100">Verifying your installation</h2>
      <h2 class="text-xl font-bold dark:text-gray-100">on <%= @domain %></h2>
      <div :if={!@finished? || @success?} class="flex justify-center w-full h-12 mt-8">
        <div class={["block pulsating-circle", if(@embedded && @finished?, do: "hidden")]}></div>
        <Heroicons.check_circle
          :if={@embedded && @finished? && @success?}
          solid
          class="w-4 h-4 text-green-500"
        />
      </div>

      <div :if={@finished? && !@success?} class="flex justify-center pt-3 h-14 mb-4">
        <.shuttle width={50} height={50} />
      </div>
      <div
        id="progress"
        class={["text-xs mt-2", if(@finished? == false, do: "animate-pulse", else: "font-bold")]}
      >
        <%= @message %>
      </div>

      <div :if={@finished? && !@success? && @diagnostics}>
        <div class="text-xs mt-4">
          <.diagnostics_feedback diagnostics={@diagnostics} />
        </div>

        <div class="flex justify-center mt-6 text-xs">
          <.button_link href="#" phx-click="retry">
            Retry
          </.button_link>

          <.button_link :if={@finished? && @embedded} href="#" class="ml-4" phx-click="dismiss">
            Dismiss
          </.button_link>
        </div>
      </div>

      <div class="mt-auto pb-2 text-gray-600 dark:text-gray-400 text-xs w-full text-center leading-normal">
        <%= if !@embedded do %>
          Need to see the snippet again?
          <.styled_link href={"/#{URI.encode_www_form(@domain)}/snippet"}>
            Click here
          </.styled_link>
          <br /> Run verification later and go to Site Settings?
          <.styled_link href={"/#{URI.encode_www_form(@domain)}/settings/general"}>
            Click here
          </.styled_link>
          <br />
        <% end %>
        Skip to the dashboard?
        <.styled_link href={"/#{URI.encode_www_form(@domain)}?skip_to_dashboard=true"}>
          Click here
        </.styled_link>
      </div>
    </div>
    """
  end

  def diagnostics_feedback(assigns) do
    {:error, error} =
      Plausible.Site.Verification.Diagnostics.diagnostics_to_user_feedback(assigns.diagnostics)

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
end
