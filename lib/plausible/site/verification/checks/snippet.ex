defmodule Plausible.Site.Verification.Checks.Snippet do
  use Plausible.Site.Verification.State

  def friendly_name, do: "Looking for Plausible snippet"

  def perform(%State{passed: %{Checks.FetchBody => body}} = state) do
    result =
      Floki.find(body, "script[data-domain=\"#{state.data_domain}\"]")

    pass(state, __MODULE__, "Plausible snippet found", result)
  end

  def perform(state) do
    fail(state, __MODULE__, "We could not find the snippet.", :no_body)
  end
end
