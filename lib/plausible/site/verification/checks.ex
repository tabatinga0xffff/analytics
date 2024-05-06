defmodule Plausible.Site.Verification.Checks do
  alias Plausible.Site.Verification.Checks
  alias Plausible.Site.Verification.State

  require Logger

  @checks [
    Checks.FetchBody,
    Checks.Snippet,
    Checks.Installation
  ]

  def run(url, data_domain, report_to \\ self(), checks \\ @checks) do
    Task.start_link(fn ->
      Enum.reduce(
        checks,
        %State{url: url, data_domain: data_domain, report_to: report_to},
        fn check, state ->
          State.notify(state, check.friendly_name(), "in progress")
          Logger.info("Running #{check} against #{url} (data-domain=#{data_domain})")

          check.perform(state)
        end
      )
    end)
  end
end
