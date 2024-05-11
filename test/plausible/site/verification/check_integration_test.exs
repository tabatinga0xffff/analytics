defmodule Plausible.Verification.CheckIntegrationTest do
  use Plausible.DataCase, async: true

  # TODO test against service  error

  alias Plausible.Verification.Checks

  test "foo" do
    body = """
    <html>
    <head>
    <script defer data-domain=\"example.com\" src=\"https://plausible.io/js/plausible.js\"></script>
    </head>
    <body>Hello</body>
    </html>
    """

    stub_fetch_body(200, body)
    stub_installation(200, %{"data" => %{"plausibleInstalled" => true}})

    result = Checks.run("https://example.com", "example.com", async?: false, report_to: nil)

    assert result.diagnostics.document_content_type == "text/html; charset=utf-8"
    assert result.diagnostics.snippets_found_in_head == 1
    assert result.diagnostics.snippets_found_in_body == 0
    assert result.diagnostics.plausible_installed? == true
  end

  defp stub_fetch_body(status, body) do
    Req.Test.stub(Plausible.Verification.Checks.FetchBody, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("text/html")
      |> Plug.Conn.send_resp(status, body)
    end)
  end

  defp stub_installation(status, json) do
    Req.Test.stub(Plausible.Verification.Checks.Installation, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(status, Jason.encode!(json))
    end)
  end
end
