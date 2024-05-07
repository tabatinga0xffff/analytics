defmodule Plausible.Site.Verification.State do
  defstruct url: nil,
            data_domain: nil,
            report_to: nil,
            assigns: %{},
            diagnostics: []

  defmacro __using__(_) do
    quote do
      alias Plausible.Site.Verification.Checks
      alias Plausible.Site.Verification.State
      import Plausible.Site.Verification.State
    end
  end

  def assign(%__MODULE__{} = state, [{key, value}]) do
    %{state | assigns: Map.put(state.assigns, key, value)}
  end

  def put_diagnostics(%__MODULE__{} = state, diagnostics) when is_list(diagnostics) do
    %{state | diagnostics: state.diagnostics ++ diagnostics}
  end

  def put_diagnostics(%__MODULE__{} = state, diagnostics) do
    put_diagnostics(state, List.wrap(diagnostics))
  end

  def notify_start(state, check, slowdown \\ 0) do
    if is_pid(state.report_to) do
      if is_integer(slowdown) and slowdown > 0, do: :timer.sleep(slowdown)
      send(state.report_to, {:verification_check_start, {check, state}})
    end

    state
  end

  def notify_finish(state, check, slowdown \\ 0) do
    if is_pid(state.report_to) do
      if is_integer(slowdown) and slowdown > 0, do: :timer.sleep(slowdown)
      send(state.report_to, {:verification_check_finish, {check, state}})
    end

    state
  end

  def notify_verification_end(state, slowdown \\ 0) do
    if is_pid(state.report_to) do
      if is_integer(slowdown) and slowdown > 0, do: :timer.sleep(slowdown)
      send(state.report_to, {:verification_end, state})
    end

    state
  end
end
