defmodule Plausible.Site.Verification.Check do
  @type state() :: Plausible.Site.Verification.State.t()
  @callback friendly_name() :: String.t()
  @callback perform(state()) :: state()

  defmacro __using__(_) do
    quote do
      alias Plausible.Site.Verification.Checks
      alias Plausible.Site.Verification.State
      import Plausible.Site.Verification.State

      @behaviour Plausible.Site.Verification.Check
    end
  end

end
