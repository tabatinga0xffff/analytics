defmodule Plausible.Verification.HeadlessBrowser do
  require EEx

  @verification_script_filename "verification/verify_plausible_installed.js.eex"
  @verification_script_path :code.priv_dir(:plausible)
                            |> Path.join(@verification_script_filename)

  #  - Browserless
  #   - timeouts
  #   - DNS resolution failure
  #   - long running pages

  EEx.function_from_file(
    :def,
    :verify_plausible_installed_js_code,
    @verification_script_path,
    [
      :url
    ]
  )

  defmodule VerificationResult do
    defstruct url_valid?: true,
              plausible_installed?: false,
              page_evaluated?: false,
              reachable_from_app?: false
  end

  def verification_endpoint() do
    config = Application.get_env(:plausible, __MODULE__)
    token = Keyword.fetch!(config, :token)
    endpoint = Keyword.fetch!(config, :endpoint)
    Path.join(endpoint, "function?token=#{token}")
  end

  def verify_plausible_installed("https://" <> _ = url) do
    reachable_from_app? = reachable_from_app?(url)

    result =
      Plausible.HTTPClient.post(
        verification_endpoint(),
        [{"content-type", "application/javascript"}],
        verify_plausible_installed_js_code(url)
      )

    case result do
      {:ok,
       %Finch.Response{
         status: 200,
         body: %{"data" => %{"plausibleInstalled" => plausible_installed?}}
       }} ->
        %VerificationResult{
          plausible_installed?: plausible_installed?,
          page_evaluated?: true,
          reachable_from_app?: reachable_from_app?
        }

      _ ->
        %VerificationResult{reachable_from_app?: reachable_from_app?}
    end
  end

  def verify_plausible_installed(_non_https) do
    %VerificationResult{
      url_valid?: false
    }
  end

  defp reachable_from_app?(url) do
    case Plausible.HTTPClient.get(url) do
      %Finch.Response{status: 200} -> true
      _ -> false
    end
  end
end
