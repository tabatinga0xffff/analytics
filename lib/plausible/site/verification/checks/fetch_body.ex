defmodule Plausible.Site.Verification.Checks.FetchBody do
  use Plausible.Site.Verification.State

  def friendly_name, do: "Fetching website contents"

  def perform(%State{url: "https://" <> _ = url} = state) do
    req = Req.new(base_url: url, max_redirects: 1)

    case Req.get(req) do
      {:ok, %{body: body} = response} when is_binary(body) ->
        extract_document(state, response)

      {:error, _} = e ->
        fail(state, __MODULE__, "We could not reach the website.", e)
    end
  end

  def perform(%State{url: url} = state) do
    fail(state, __MODULE__, "The URL is invalid: #{inspect(url)}", url)
  end

  defp extract_document(state, response) do
    state = check_content_type(state, response)

    case Floki.parse_document(response.body) do
      {:ok, document} ->
        pass(state, __MODULE__, "Document parsed successfully", document)

      {:error, _} = e ->
        fail(
          state,
          __MODULE__,
          "We could not parse HTML of the website. Make sure all tags are properly closed.",
          e
        )
    end
  end

  defp check_content_type(state, response) do
    content_type = List.first(response.headers["content-type"])

    if is_binary(content_type) and content_type =~ "text/html" do
      state
    else
      warn(state, __MODULE__, "The content type of the website is not text/html.")
    end
  end
end
