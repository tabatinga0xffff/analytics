defmodule Plausible.Site.Verification.Diagnostics do
  require Logger

  defstruct snippets_found_in_head: 0,
            snippets_found_in_body: 0,
            plausible_installed?: false,
            document_content_type: "",
            service_error: nil,
            could_not_fetch_body: nil

  def diagnostics_to_user_feedback(%__MODULE__{could_not_fetch_body: :nxdomain, service_error: e1})
      when is_nil(e1) do
    {:error, "We could not resolve your website via DNS"}
  end

  def diagnostics_to_user_feedback(%__MODULE__{could_not_fetch_body: e1, service_error: e2})
      when e1 != false and not is_nil(e2) do
    {:error, "We could not reach your website. Is it up?"}
  end

  def diagnostics_to_user_feedback(%__MODULE__{service_error: e}) when not is_nil(e) do
    Logger.error("Verification Agent error: #{inspect(e)}")
    {:error, "We are currently unable to verify your site. Please try again later."}
  end

  def diagnostics_to_user_feedback(%__MODULE__{
        snippets_found_in_head: 0,
        snippets_found_in_body: 0,
        plausible_installed?: false
      }) do
    {:error, "We could not find the Plausible snippet on your website"}
  end

  def diagnostics_to_user_feedback(%__MODULE__{plausible_installed?: false}) do
    {:error, "We could not verify your Plausible snippet working"}
  end
end
