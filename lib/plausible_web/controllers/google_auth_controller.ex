defmodule PlausibleWeb.GoogleAuthController do
  use PlausibleWeb, :controller
  use Plausible.Repo

  def google_auth_callback(conn, %{"error" => error, "state" => state} = params) do
    [site_id, _redirect_to] = Jason.decode!(state)
    site = Repo.get(Plausible.Site, site_id)

    case error do
      "access_denied" ->
        conn
        |> put_flash(
          :error,
          "We were unable to authenticate your Google Analytics account. Please check that you have granted us permission to 'See and download your Google Analytics data' and try again."
        )
        |> redirect(to: Routes.site_path(conn, :settings_general, site.domain))

      message when message in ["server_error", "temporarily_unavailable"] ->
        conn
        |> put_flash(
          :error,
          "We are unable to authenticate your Google Analytics account because Google's authentication service is temporarily unavailable. Please try again in a few moments."
        )
        |> redirect(to: Routes.site_path(conn, :settings_general, site.domain))

      _any ->
        Sentry.capture_message("Google OAuth callback failed. Reason: #{inspect(params)}")

        conn
        |> put_flash(
          :error,
          "We were unable to authenticate your Google Analytics account. If the problem persists, please contact support for assistance."
        )
        |> redirect(to: Routes.site_path(conn, :settings_general, site.domain))
    end
  end

  def google_auth_callback(conn, %{"code" => code, "state" => state}) do
    res = Plausible.Google.HTTP.fetch_access_token(code)
    [site_id, redirect_to] = Jason.decode!(state)
    site = Repo.get(Plausible.Site, site_id)
    expires_at = NaiveDateTime.add(NaiveDateTime.utc_now(), res["expires_in"])

    case redirect_to do
      "import" ->
        redirect(conn,
          to:
            Routes.site_path(conn, :import_from_google_view_id_form, site.domain,
              access_token: res["access_token"],
              refresh_token: res["refresh_token"],
              expires_at: NaiveDateTime.to_iso8601(expires_at)
            )
        )

      _ ->
        id_token = res["id_token"]
        [_, body, _] = String.split(id_token, ".")
        id = body |> Base.decode64!(padding: false) |> Jason.decode!()

        Plausible.Site.GoogleAuth.changeset(%Plausible.Site.GoogleAuth{}, %{
          email: id["email"],
          refresh_token: res["refresh_token"],
          access_token: res["access_token"],
          expires: expires_at,
          user_id: conn.assigns[:current_user].id,
          site_id: site_id
        })
        |> Repo.insert!()

        site = Repo.get(Plausible.Site, site_id)

        redirect(conn, to: "/#{URI.encode_www_form(site.domain)}/settings/integrations")
    end
  end
end
