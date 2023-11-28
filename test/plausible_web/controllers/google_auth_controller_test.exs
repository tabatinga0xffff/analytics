defmodule PlausibleWeb.GoogleAuthControllerTest do
  use PlausibleWeb.ConnCase, async: true

  describe "GET /auth/google/callback" do
    test "shows error and redirects back to settings when authentication fails", %{conn: conn} do
      site = insert(:site)
      callback_params = %{"error" => "access_denied", "state" => "[#{site.id},\"import\"]"}
      conn = get(conn, Routes.google_auth_path(conn, :google_auth_callback), callback_params)

      assert redirected_to(conn, 302) == Routes.site_path(conn, :settings_general, site.domain)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "unable to authenticate your Google Analytics"
    end
  end
end
