defmodule Plausible.Verification.Checks.FetchBody do
  use Plausible.Verification.Check

  @impl true
  def friendly_name, do: "Fetching website contents"

  @impl true
  def perform(%State{url: "https://" <> _ = url} = state) do
    fetch_body_opts = Application.get_env(:plausible, __MODULE__)[:req_opts] || []

    opts =
      Keyword.merge(
        [
          base_url: url,
          max_redirects: 1,
          connect_options: [transport_opts: [cacerts: :public_key.cacerts_get()]]
        ],
        fetch_body_opts
      )

    req = Req.new(opts)

    case Req.get(req) |> IO.inspect(label: :req) do
      {:ok, %{status: status, body: body} = response}
      when is_binary(body) and status in 200..299 ->
        extract_document(state, response)

      {:ok, _response} ->
        put_diagnostics(state, could_not_fetch_body: true)

      {:error, _exception} ->
        put_diagnostics(state, could_not_fetch_body: true)
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
    content_type = List.first(List.wrap(response.headers["content-type"]))
    put_diagnostics(state, document_content_type: content_type || "")
  end
end
