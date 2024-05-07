defmodule Plausible.Site.Verification.Checks.FetchBody do
  use Plausible.Site.Verification.State

  def friendly_name, do: "Fetching website contents"

  def perform(%State{url: "https://" <> _ = url} = state) do
    req = Req.new(base_url: url, max_redirects: 1)

    case Req.get(req) do
      {:ok, %{body: body} = response} when is_binary(body) ->
        extract_document(state, response)

      {:error, %{reason: e}} ->
        put_diagnostics(state, could_not_fetch_body: e)
    end
  end

  defp extract_document(state, response) do
    state = check_content_type(state, response)

    case Floki.parse_document(response.body) do
      {:ok, document} ->
        assign(state, document: document)

      {:error, reason} ->
        put_diagnostics(state, could_not_parse_document: reason)
    end
  end

  defp check_content_type(state, response) do
    content_type = List.first(response.headers["content-type"])
    put_diagnostics(state, document_content_type: content_type)
  end
end
