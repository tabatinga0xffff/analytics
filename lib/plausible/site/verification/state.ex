defmodule Plausible.Site.Verification.State do
  defstruct url: nil,
            data_domain: nil,
            report_to: nil,
            passed: %{},
            failed: %{},
            errors: %{},
            warnings: %{}

  defmacro __using__(_) do
    quote do
      alias Plausible.Site.Verification.Checks
      alias Plausible.Site.Verification.State
      import Plausible.Site.Verification.State, only: [fail: 4, warn: 3, pass: 4]
    end
  end

  def fail(%__MODULE__{} = state, check, message, result) do
    notify(state, check.friendly_name(), message)

    %__MODULE__{
      state
      | failed: Map.put(state.failed, check, result),
        errors: Map.update(state.errors, check, [message], &[message | &1])
    }
  end

  def warn(%__MODULE__{} = state, check, message) do
    notify(state, check.friendly_name(), message)

    %__MODULE__{state | warnings: Map.update(state.warnings, check, [message], &[message | &1])}
  end

  def pass(%__MODULE__{} = state, check, message, result) do
    notify(state, check.friendly_name(), message)

    %__MODULE__{state | passed: Map.put(state.passed, check, result)}
  end

  def notify(state, name, message) do
    if state.report_to do
      :timer.sleep(500)
      send(state.report_to, {:verification_progress, name, message})
    end
  end
end
