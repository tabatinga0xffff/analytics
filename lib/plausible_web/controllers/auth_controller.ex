defmodule PlausibleWeb.AuthController do
  use PlausibleWeb, :controller
  use Plausible.Repo

  alias Plausible.Auth
  alias PlausibleWeb.TwoFactor

  require Logger

  plug(
    PlausibleWeb.RequireLoggedOutPlug
    when action not in [
           :password_reset_form,
           :password_reset
         ]
  )

  plug(
    :clear_2fa_user
    when action not in [
           :verify_2fa_form,
           :verify_2fa,
           :verify_2fa_recovery_code_form,
           :verify_2fa_recovery_code
         ]
  )

  plug(:assign_is_selfhost)

  defp assign_is_selfhost(conn, _opts) do
    assign(conn, :is_selfhost, Plausible.Release.selfhost?())
  end

  defp clear_2fa_user(conn, _opts) do
    TwoFactor.clear_2fa_user(conn)
  end

  def register(conn, %{"user" => %{"email" => email, "password" => password}}) do
    with {:ok, user} <- login_user(conn, email, password) do
      conn = set_user_session(conn, user)

      if user.email_verified do
        redirect(conn, to: Routes.site_path(conn, :new))
      else
        Auth.EmailVerification.issue_code(user)
        redirect(conn, to: Routes.user_path(conn, :activate_form))
      end
    end
  end

  def register_from_invitation(conn, %{"user" => %{"email" => email, "password" => password}}) do
    with {:ok, user} <- login_user(conn, email, password) do
      conn = set_user_session(conn, user)

      if user.email_verified do
        redirect(conn, to: Routes.site_path(conn, :index))
      else
        Auth.EmailVerification.issue_code(user)
        redirect(conn, to: Routes.user_path(conn, :activate_form))
      end
    end
  end

  def password_reset_request_form(conn, _) do
    render(conn, "password_reset_request_form.html",
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  def password_reset_request(conn, %{"email" => ""}) do
    render(conn, "password_reset_request_form.html",
      error: "Please enter an email address",
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  def password_reset_request(conn, %{"email" => email} = params) do
    if PlausibleWeb.Captcha.verify(params["h-captcha-response"]) do
      user = Repo.get_by(Auth.User, email: email)

      if user do
        token = Auth.Token.sign_password_reset(email)
        url = PlausibleWeb.Endpoint.url() <> "/password/reset?token=#{token}"
        email_template = PlausibleWeb.Email.password_reset_email(email, url)
        Plausible.Mailer.deliver_later(email_template)

        Logger.debug(
          "Password reset e-mail sent. In dev environment GET /sent-emails for details."
        )

        render(conn, "password_reset_request_success.html",
          email: email,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )
      else
        render(conn, "password_reset_request_success.html",
          email: email,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )
      end
    else
      render(conn, "password_reset_request_form.html",
        error: "Please complete the captcha to reset your password",
        layout: {PlausibleWeb.LayoutView, "focus.html"}
      )
    end
  end

  def password_reset_form(conn, params) do
    case Auth.Token.verify_password_reset(params["token"]) do
      {:ok, %{email: email}} ->
        render(conn, "password_reset_form.html",
          connect_live_socket: true,
          email: email,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )

      {:error, :expired} ->
        render_error(
          conn,
          401,
          "Your token has expired. Please request another password reset link."
        )

      {:error, _} ->
        render_error(
          conn,
          401,
          "Your token is invalid. Please request another password reset link."
        )
    end
  end

  def password_reset(conn, _params) do
    conn
    |> put_flash(:login_title, "Password updated successfully")
    |> put_flash(:login_instructions, "Please log in with your new credentials")
    |> put_session(:current_user_id, nil)
    |> delete_resp_cookie("logged_in")
    |> redirect_to_login()
  end

  def login_form(conn, _params) do
    render(conn, "login_form.html", layout: {PlausibleWeb.LayoutView, "focus.html"})
  end

  def login(conn, %{"email" => email, "password" => password}) do
    with {:ok, user} <- login_user(conn, email, password) do
      if Auth.TOTP.enabled?(user) and not TwoFactor.remember_2fa?(conn) do
        conn
        |> TwoFactor.set_2fa_user(user)
        |> redirect(to: Routes.auth_path(conn, :verify_2fa))
      else
        set_user_session_and_redirect(conn, user)
      end
    end
  end

  def logout(conn, params) do
    redirect_to = Map.get(params, "redirect", "/")

    conn
    |> configure_session(drop: true)
    |> delete_resp_cookie("logged_in")
    |> redirect(to: redirect_to)
  end

  def verify_2fa_form(conn, _) do
    case TwoFactor.get_2fa_user(conn) do
      {:ok, user} ->
        if Auth.TOTP.enabled?(user) do
          render(conn, "verify_2fa.html",
            remember_2fa_days: TwoFactor.remember_2fa_days(),
            layout: {PlausibleWeb.LayoutView, "focus.html"}
          )
        else
          redirect_to_login(conn)
        end

      {:error, :not_found} ->
        redirect_to_login(conn)
    end
  end

  def verify_2fa(conn, %{"code" => code} = params) do
    with {:ok, user} <- get_2fa_user_limited(conn) do
      case Auth.TOTP.validate_code(user, code) do
        {:ok, user} ->
          conn
          |> TwoFactor.maybe_set_remember_2fa(params["remember_2fa"])
          |> set_user_session_and_redirect(user)

        {:error, :invalid_code} ->
          maybe_log_failed_login_attempts(
            "wrong 2FA verification code provided for #{user.email}"
          )

          conn
          |> put_flash(:error, "The provided code is invalid. Please try again")
          |> render("verify_2fa.html",
            remember_2fa_days: TwoFactor.remember_2fa_days(),
            layout: {PlausibleWeb.LayoutView, "focus.html"}
          )

        {:error, :not_enabled} ->
          redirect_to_login(conn)
      end
    end
  end

  def verify_2fa_recovery_code_form(conn, _params) do
    case TwoFactor.get_2fa_user(conn) do
      {:ok, user} ->
        if Auth.TOTP.enabled?(user) do
          render(conn, "verify_2fa_recovery_code.html",
            layout: {PlausibleWeb.LayoutView, "focus.html"}
          )
        else
          redirect_to_login(conn)
        end

      {:error, :not_found} ->
        redirect_to_login(conn)
    end
  end

  def verify_2fa_recovery_code(conn, %{"recovery_code" => recovery_code}) do
    with {:ok, user} <- get_2fa_user_limited(conn) do
      case Auth.TOTP.use_recovery_code(user, recovery_code) do
        :ok ->
          set_user_session_and_redirect(conn, user)

        {:error, :invalid_code} ->
          maybe_log_failed_login_attempts("wrong 2FA recovery code provided for #{user.email}")

          conn
          |> put_flash(:error, "The provided recovery code is invalid. Please try another one")
          |> render("verify_2fa_recovery_code.html",
            layout: {PlausibleWeb.LayoutView, "focus.html"}
          )

        {:error, :not_enabled} ->
          set_user_session_and_redirect(conn, user)
      end
    end
  end

  defp login_user(conn, email, password) do
    with :ok <- check_ip_rate_limit(conn),
         {:ok, user} <- find_user(email),
         :ok <- check_user_rate_limit(user),
         :ok <- check_password(user, password) do
      {:ok, user}
    else
      :wrong_password ->
        maybe_log_failed_login_attempts("wrong password for #{email}")

        render(conn, "login_form.html",
          error: "Wrong email or password. Please try again.",
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )

      :user_not_found ->
        maybe_log_failed_login_attempts("user not found for #{email}")
        Auth.Password.dummy_calculation()

        render(conn, "login_form.html",
          error: "Wrong email or password. Please try again.",
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )

      {:rate_limit, _} ->
        maybe_log_failed_login_attempts("too many logging attempts for #{email}")

        render_error(
          conn,
          429,
          "Too many login attempts. Wait a minute before trying again."
        )
    end
  end

  defp get_2fa_user_limited(conn) do
    case TwoFactor.get_2fa_user(conn) do
      {:ok, user} ->
        with :ok <- check_ip_rate_limit(conn),
             :ok <- check_user_rate_limit(user) do
          {:ok, user}
        else
          {:rate_limit, _} ->
            maybe_log_failed_login_attempts("too many logging attempts for #{user.email}")

            render_error(
              conn,
              429,
              "Too many login attempts. Wait a minute before trying again."
            )
        end

      {:error, :not_found} ->
        redirect_to_login(conn)
    end
  end

  defp set_user_session(conn, user) do
    conn
    |> TwoFactor.clear_2fa_user()
    |> put_session(:current_user_id, user.id)
    |> put_resp_cookie("logged_in", "true",
      http_only: false,
      max_age: 60 * 60 * 24 * 365 * 5000
    )
  end

  defp maybe_log_failed_login_attempts(message) do
    if Application.get_env(:plausible, :log_failed_login_attempts) do
      Logger.warning("[login] #{message}")
    end
  end

  defp set_user_session_and_redirect(conn, user) do
    login_dest = get_session(conn, :login_dest) || Routes.site_path(conn, :index)

    conn
    |> set_user_session(user)
    |> put_session(:login_dest, nil)
    |> redirect(to: login_dest)
  end

  defp redirect_to_login(conn) do
    redirect(conn, to: Routes.auth_path(conn, :login_form))
  end

  defp check_password(user, password) do
    if Auth.Password.match?(password, user.password_hash || "") do
      :ok
    else
      :wrong_password
    end
  end

  defp find_user(email) do
    case Repo.get_by(Auth.User, email: email) do
      %{} = user -> {:ok, user}
      nil -> :user_not_found
    end
  end

  @login_interval 60_000
  @login_limit 5

  defp check_ip_rate_limit(conn) do
    ip_address = PlausibleWeb.RemoteIp.get(conn)

    case Hammer.check_rate("login:ip:#{ip_address}", @login_interval, @login_limit) do
      {:allow, _} -> :ok
      {:deny, _} -> {:rate_limit, :ip_address}
    end
  end

  defp check_user_rate_limit(user) do
    case Hammer.check_rate("login:user:#{user.id}", @login_interval, @login_limit) do
      {:allow, _} -> :ok
      {:deny, _} -> {:rate_limit, :user}
    end
  end
end
