defmodule Plausible.Verification.Check do
  @type state() :: Plausible.Verification.State.t()
  @callback friendly_name() :: String.t()
  @callback perform(state()) :: state()

  defmacro __using__(_) do
    quote do
      alias Plausible.Verification.Checks
      alias Plausible.Verification.State
      import Plausible.Verification.State

      @behaviour Plausible.Verification.Check
    end
  end

end
