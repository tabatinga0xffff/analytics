defmodule Plausible.Site.Verification.Checks.Snippet do
  use Plausible.Site.Verification.State

  def friendly_name, do: "Looking for Plausible snippet"

  def perform(%State{assigns: %{document: document}} = state) do
    result = Floki.find(document, "script[data-domain=\"#{state.data_domain}\"]")
    put_diagnostics(state, snippets_found: Enum.count(result))
  end

  def perform(state), do: state
end
