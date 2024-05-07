defmodule Plausible.Site.Verification.Checks.Installation do
  require EEx
  use Plausible.Site.Verification.State

  @verification_script_filename "verification/verify_plausible_installed.js.eex"
  @verification_script_path Path.join(:code.priv_dir(:plausible), @verification_script_filename)
  # TODO: external resource

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
         )
         |> IO.inspect(label: :resp_service) do
      {:ok, %{status: 200, body: %{"data" => %{"plausibleInstalled" => installed?}}}}
      when is_boolean(installed?) ->
        put_diagnostics(state, plausible_installed?: installed?)

      {:ok, %{status: status}} ->
        put_diagnostics(state, plausible_installed?: false, service_error: status)

      {:error, %{reason: reason}} ->
        put_diagnostics(state, plausible_isntalled?: false, service_error: reason)
    end
  end

  def verification_endpoint() do
    config = Application.get_env(:plausible, __MODULE__)
    token = Keyword.fetch!(config, :token)
    endpoint = Keyword.fetch!(config, :endpoint)
    Path.join(endpoint, "function?token=#{token}")
  end
end
