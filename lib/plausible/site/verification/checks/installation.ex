defmodule Plausible.Site.Verification.Checks.Installation do
  require EEx
  use Plausible.Site.Verification.State

  @verification_script_filename "verification/verify_plausible_installed.js.eex"
  @verification_script_path :code.priv_dir(:plausible)
                            |> Path.join(@verification_script_filename)

  EEx.function_from_file(
    :def,
    :verify_plausible_installed_js_code,
    @verification_script_path,
    [
      :url
    ]
  )

  def friendly_name, do: "Verifying Plausible snippet installation"

  def perform(%State{url: url} = state) do
    case Req.post(verification_endpoint(),
           headers: %{content_type: "application/javascript"},
           body: verify_plausible_installed_js_code(url),
           retry: :transient,
           max_retries: 3
         ) do
      {:ok, %{status: 200, body: %{"data" => %{"plausibleInstalled" => true}}}} ->
        pass(state, __MODULE__, "Your Plausible snippet looks good!", true)

      {:ok, %{status: 200, body: %{"data" => %{"plausibleInstalled" => false}}}} ->
        fail(
          state,
          __MODULE__,
          "We could not detect your Plausible snippet installed correctly.",
          false
        )

      {:ok, %{status: status} = response} ->
        fail(
          state,
          __MODULE__,
          "We could not visit your website to verify the snippet installation. Our agent encountered #{status} code.",
          response
        )

      {:error, _} = e ->
        fail(
          state,
          __MODULE__,
          "There has been an error trying to retrieve the snippet from your website.",
          e
        )
    end
  end

  def verification_endpoint() do
    config = Application.get_env(:plausible, __MODULE__)
    token = Keyword.fetch!(config, :token)
    endpoint = Keyword.fetch!(config, :endpoint)
    Path.join(endpoint, "function?token=#{token}")
  end
end
