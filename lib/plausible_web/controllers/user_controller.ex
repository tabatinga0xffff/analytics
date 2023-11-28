defmodule PlausibleWeb.UserController do
  use PlausibleWeb, :controller
  use Plausible.Repo

  alias Plausible.Auth
  alias PlausibleWeb.TwoFactor

  plug(PlausibleWeb.RequireAccountPlug)

  plug(:assign_is_selfhost)

  defp assign_is_selfhost(conn, _opts) do
    assign(conn, :is_selfhost, Plausible.Release.selfhost?())
  end

  def user_settings(conn, _params) do
    user = conn.assigns.current_user
    settings_changeset = Auth.User.settings_changeset(user)
    email_changeset = Auth.User.settings_changeset(user)

    render_settings(conn,
      settings_changeset: settings_changeset,
      email_changeset: email_changeset
    )
  end

  def activate_form(conn, _params) do
    user = conn.assigns.current_user

    render(conn, "activate.html",
      has_email_code?: Plausible.Users.has_email_code?(user),
      has_any_invitations?: Plausible.Site.Memberships.pending?(user.email),
      has_any_memberships?: Plausible.Site.Memberships.any?(user),
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  def activate(conn, %{"code" => code}) do
    user = conn.assigns.current_user

    has_any_invitations? = Plausible.Site.Memberships.pending?(user.email)
    has_any_memberships? = Plausible.Site.Memberships.any?(user)

    case Auth.EmailVerification.verify_code(user, code) do
      :ok ->
        cond do
          has_any_memberships? ->
            handle_email_updated(conn)

          has_any_invitations? ->
            redirect(conn, to: Routes.site_path(conn, :index))

          true ->
            redirect(conn, to: Routes.site_path(conn, :new))
        end

      {:error, :incorrect} ->
        render(conn, "activate.html",
          error: "Incorrect activation code",
          has_email_code?: true,
          has_any_invitations?: has_any_invitations?,
          has_any_memberships?: has_any_memberships?,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )

      {:error, :expired} ->
        render(conn, "activate.html",
          error: "Code is expired, please request another one",
          has_email_code?: false,
          has_any_invitations?: has_any_invitations?,
          has_any_memberships?: has_any_memberships?,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )
    end
  end

  def request_activation_code(conn, _params) do
    user = conn.assigns.current_user
    Auth.EmailVerification.issue_code(user)

    conn
    |> put_flash(:success, "Activation code was sent to #{user.email}")
    |> redirect(to: Routes.user_path(conn, :activate_form))
  end

  def initiate_2fa_setup(conn, _params) do
    case Auth.TOTP.initiate(conn.assigns.current_user) do
      {:ok, user, %{totp_uri: totp_uri, secret: secret}} ->
        render(conn, "initiate_2fa_setup.html", user: user, totp_uri: totp_uri, secret: secret)

      {:error, :already_setup} ->
        conn
        |> put_flash(:error, "Two-factor authentication is already setup for this account.")
        |> redirect(to: Routes.user_path(conn, :user_settings) <> "#setup-2fa")
    end
  end

  def verify_2fa_setup_form(conn, _params) do
    if Auth.TOTP.initiated?(conn.assigns.current_user) do
      render(conn, "verify_2fa_setup.html")
    else
      redirect(conn, to: Routes.user_path(conn, :user_settings) <> "#setup-2fa")
    end
  end

  def verify_2fa_setup(conn, %{"code" => code}) do
    case Auth.TOTP.enable(conn.assigns.current_user, code) do
      {:ok, _, %{recovery_codes: codes}} ->
        conn
        |> put_flash(:success, "Two-factor authentication is fully enabled now")
        |> render("generate_2fa_recovery_codes.html", recovery_codes: codes, from_setup: true)

      {:error, :invalid_code} ->
        conn
        |> put_flash(:error, "The provided code is invalid. Please try again")
        |> render("verify_2fa_setup.html")

      {:error, :not_initiated} ->
        conn
        |> put_flash(:error, "Please enable two-factor authentication for this account first.")
        |> redirect(to: Routes.user_path(conn, :user_settings) <> "#setup-2fa")
    end
  end

  def disable_2fa(conn, %{"password" => password}) do
    case Auth.TOTP.disable(conn.assigns.current_user, password) do
      {:ok, _} ->
        conn
        |> TwoFactor.clear_remember_2fa()
        |> put_flash(:success, "Two-factor authentication is disabled")
        |> redirect(to: Routes.user_path(conn, :user_settings) <> "#setup-2fa")

      {:error, :invalid_password} ->
        conn
        |> put_flash(:error, "Incorrect password provided")
        |> redirect(to: Routes.user_path(conn, :user_settings) <> "#setup-2fa")
    end
  end

  def generate_2fa_recovery_codes(conn, %{"password" => password}) do
    case Auth.TOTP.generate_recovery_codes(conn.assigns.current_user, password) do
      {:ok, codes} ->
        conn
        |> put_flash(:success, "New recovery codes generated")
        |> render("generate_2fa_recovery_codes.html", recovery_codes: codes, from_setup: false)

      {:error, :invalid_password} ->
        conn
        |> put_flash(:error, "Incorrect password provided")
        |> redirect(to: Routes.user_path(conn, :user_settings) <> "#setup-2fa")

      {:error, :not_enabled} ->
        conn
        |> put_flash(:error, "Please enable two-factor authentication for this account first.")
        |> redirect(to: Routes.user_path(conn, :user_settings) <> "#setup-2fa")
    end
  end

  def save_settings(conn, %{"user" => user_params}) do
    user = conn.assigns.current_user
    changes = Auth.User.settings_changeset(user, user_params)

    case Repo.update(changes) do
      {:ok, _user} ->
        conn
        |> put_flash(:success, "Account settings saved successfully")
        |> redirect(to: Routes.user_path(conn, :user_settings))

      {:error, changeset} ->
        email_changeset = Auth.User.settings_changeset(user)

        render_settings(conn,
          settings_changeset: changeset,
          email_changeset: email_changeset
        )
    end
  end

  def update_email(conn, %{"user" => user_params}) do
    user = conn.assigns.current_user
    changes = Auth.User.email_changeset(user, user_params)

    case Repo.update(changes) do
      {:ok, user} ->
        if user.email_verified do
          handle_email_updated(conn)
        else
          Auth.EmailVerification.issue_code(user)
          redirect(conn, to: Routes.user_path(conn, :activate_form))
        end

      {:error, changeset} ->
        settings_changeset = Auth.User.settings_changeset(user)

        render_settings(conn,
          settings_changeset: settings_changeset,
          email_changeset: changeset
        )
    end
  end

  def cancel_update_email(conn, _params) do
    changeset = Auth.User.cancel_email_changeset(conn.assigns.current_user)

    case Repo.update(changeset) do
      {:ok, user} ->
        conn
        |> put_flash(:success, "Email changed back to #{user.email}")
        |> redirect(to: Routes.user_path(conn, :user_settings) <> "#change-email-address")

      {:error, _} ->
        conn
        |> put_flash(
          :error,
          "Could not cancel email update because previous email has already been taken"
        )
        |> redirect(to: Routes.user_path(conn, :activate_form))
    end
  end

  defp handle_email_updated(conn) do
    conn
    |> put_flash(:success, "Email updated successfully")
    |> redirect(to: Routes.user_path(conn, :user_settings) <> "#change-email-address")
  end

  defp render_settings(conn, opts) do
    settings_changeset = Keyword.fetch!(opts, :settings_changeset)
    email_changeset = Keyword.fetch!(opts, :email_changeset)

    user = Plausible.Users.with_subscription(conn.assigns.current_user)
    {pageview_usage, custom_event_usage} = Plausible.Billing.usage_breakdown(user)

    render(conn, "user_settings.html",
      user: user |> Repo.preload(:api_keys),
      settings_changeset: settings_changeset,
      email_changeset: email_changeset,
      subscription: user.subscription,
      invoices: Plausible.Billing.paddle_api().get_invoices(user.subscription),
      theme: user.theme || "system",
      team_member_limit: Plausible.Billing.Quota.team_member_limit(user),
      team_member_usage: Plausible.Billing.Quota.team_member_usage(user),
      site_limit: Plausible.Billing.Quota.site_limit(user),
      site_usage: Plausible.Billing.Quota.site_usage(user),
      total_pageview_limit: Plausible.Billing.Quota.monthly_pageview_limit(user.subscription),
      total_pageview_usage: pageview_usage + custom_event_usage,
      totp_enabled?: Auth.TOTP.enabled?(user),
      custom_event_usage: custom_event_usage,
      pageview_usage: pageview_usage
    )
  end

  def new_api_key(conn, _params) do
    changeset = Auth.ApiKey.changeset(%Auth.ApiKey{})

    render(conn, "new_api_key.html",
      changeset: changeset,
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  def create_api_key(conn, %{"api_key" => %{"name" => name, "key" => key}}) do
    case Auth.create_api_key(conn.assigns.current_user, name, key) do
      {:ok, _api_key} ->
        conn
        |> put_flash(:success, "API key created successfully")
        |> redirect(to: "/settings#api-keys")

      {:error, changeset} ->
        render(conn, "new_api_key.html",
          changeset: changeset,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )
    end
  end

  def delete_api_key(conn, %{"id" => id}) do
    case Auth.delete_api_key(conn.assigns.current_user, id) do
      :ok ->
        conn
        |> put_flash(:success, "API key revoked successfully")
        |> redirect(to: "/settings#api-keys")

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Could not find API Key to delete")
        |> redirect(to: "/settings#api-keys")
    end
  end

  def delete_me(conn, _params) do
    Plausible.Auth.delete_user(conn.assigns.current_user)

    redirect(conn, to: Routes.auth_path(conn, :logout))
  end
end
