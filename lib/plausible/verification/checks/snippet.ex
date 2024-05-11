defmodule Plausible.Verification.Checks.Snippet do
  use Plausible.Verification.Check

  @impl true
  def friendly_name, do: "Looking for Plausible snippet"

  @impl true
  def perform(%State{assigns: %{document: document}} = state) do
    result_head = Floki.find(document, "head script[data-domain=\"#{state.data_domain}\"]")
    result_body = Floki.find(document, "body script[data-domain=\"#{state.data_domain}\"]")

    put_diagnostics(state,
      snippets_found_in_head: Enum.count(result_head),
      snippets_found_in_body: Enum.count(result_body)
    )
  end

  def perform(state), do: state
end
