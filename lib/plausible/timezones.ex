defmodule Plausible.Timezones do
  @spec options(DateTime.t()) :: [{:key, String.t()}, {:value, String.t()}, {:offset, integer()}]
  def options(now \\ DateTime.utc_now()) do
    Tzdata.zone_list()
    |> Enum.reduce([], fn timezone_code, acc -> build_option(timezone_code, acc, now) end)
    |> Enum.sort_by(& &1[:offset], :desc)
  end

  @spec to_utc_datetime(NaiveDateTime.t(), String.t()) :: DateTime.t()
  def to_utc_datetime(naive_date_time, timezone) do
    case DateTime.from_naive(naive_date_time, timezone) do
      {:ok, date_time} ->
        DateTime.shift_zone!(date_time, "Etc/UTC")

      {:gap, _before_dt, after_dt} ->
        DateTime.shift_zone!(after_dt, "Etc/UTC")

      {:ambiguous, _first_dt, second_dt} ->
        DateTime.shift_zone!(second_dt, "Etc/UTC")

      {:error, :time_zone_not_found} ->
        DateTime.from_naive!(naive_date_time, "Etc/UTC")
    end
  end

  @spec to_date_in_timezone(NaiveDateTime.t() | DateTime.t() | Date.t(), String.t()) :: Date.t()
  def to_date_in_timezone(dt, timezone) do
    dt |> to_datetime_in_timezone(timezone) |> DateTime.to_date()
  end

  @doc """
  Represents a point in time in a different timezone.
  Naive datetimes are assumed to be GMT.

  Examples:

      iex> to_datetime_in_timezone(~U[2024-03-16 01:50:45.180928Z], "Asia/Kuala_Lumpur")
      #DateTime<2024-03-16 09:50:45.180928+08:00 +08 Asia/Kuala_Lumpur>

      iex> to_datetime_in_timezone(~N[2024-03-16 01:50:45.180928], "Asia/Kuala_Lumpur")
      #DateTime<2024-03-16 09:50:45.180928+08:00 +08 Asia/Kuala_Lumpur>

      iex> to_datetime_in_timezone(~N[2024-03-16 01:50:45.180928], "Etc/GMT-8")
      #DateTime<2024-03-16 09:50:45.180928+08:00 +08 Etc/GMT-8>

  """
  @spec to_datetime_in_timezone(NaiveDateTime.t() | DateTime.t() | Date.t(), String.t()) ::
          DateTime.t()
  def to_datetime_in_timezone(%NaiveDateTime{} = naive, timezone) do
    naive
    |> DateTime.from_naive!("Etc/UTC")
    |> to_datetime_in_timezone(timezone)
  end

  def to_datetime_in_timezone(%Date{} = date, timezone) do
    date
    |> DateTime.new!(~T[00:00:00], "Etc/UTC")
    |> to_datetime_in_timezone(timezone)
  end

  def to_datetime_in_timezone(%DateTime{} = dt, timezone) do
    DateTime.shift_zone!(dt, timezone)
  end

  defp build_option(timezone_code, acc, now) do
    case Timex.Timezone.get(timezone_code, now) do
      %Timex.TimezoneInfo{} = timezone_info ->
        offset_in_minutes = timezone_info |> Timex.Timezone.total_offset() |> div(-60)

        hhmm_formatted_offset =
          timezone_info
          |> Timex.TimezoneInfo.format_offset()
          |> String.slice(0..-4//1)

        option = [
          key: "(GMT#{hhmm_formatted_offset}) #{timezone_code}",
          value: timezone_code,
          offset: offset_in_minutes
        ]

        [option | acc]

      error ->
        Sentry.capture_message("Failed to fetch timezone",
          extra: %{code: timezone_code, error: inspect(error)}
        )

        acc
    end
  end
end
