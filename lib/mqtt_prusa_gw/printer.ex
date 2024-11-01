defmodule MqttPrusaGw.Printer do
  use GenServer
  require Logger

  alias MqttPrusaGw.Mqtt

  @fields ~w[progress time_remaining time_printing]a ++
            ~w[state temp_bed target_bed temp_nozzle target_nozzle]a

  # Client

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def refresh do
    GenServer.call(__MODULE__, :refresh)
  end

  # Server

  def init(_args) do
    Process.flag(:trap_exit, true)
    {:ok, nil, {:continue, :init}}
  end

  def handle_continue(:init, _state) do
    {:ok, mqtt_client_id} = Mqtt.connect()
    Mqtt.publish_meta(mqtt_client_id)

    %{ip: ip, password: pw, update_interval: update_interval} =
      printer_conf()

    printer =
      case PrusaLink.printer(ip, pw) do
        {:error, reason} ->
          Logger.error("Could not setup connection to printer: #{inspect(reason)}")
          nil

        {:not_reachable, printer} ->
          Logger.info("Could not reach printer. Trying later...")
          printer

        {:ok, printer} ->
          Logger.info("Connection to printer successful.")
          Mqtt.publish(mqtt_client_id, printer_name(printer), "status", "online")
          Mqtt.publish(mqtt_client_id, printer_name(printer), "last_seen", now())
          printer
      end

    Process.send_after(self(), :update, update_interval)

    {:noreply,
     %{
       mqtt_client_id: mqtt_client_id,
       printer: printer,
       update_interval: update_interval,
       online: printer.name != nil
     }}
  end

  def handle_info(:update, state) do
    Process.send_after(self(), :update, state.update_interval)
    {:noreply, update_mqtt(state)}
  end

  def handle_info({{_module, _mqtt_client_id}, _ref, :ok}, state) do
    # responses from mqtt messages send with qos other than 0
    {:noreply, state}
  end

  def handle_info({:EXIT, _pid, _signal}, state) do
    {:noreply, state}
  end

  def terminate(reason, state) do
    Logger.info("Shuting down printer process: #{inspect(reason)}")
    send_printer_offline(state)
    :normal
  end

  defp update_mqtt(%{printer: nil} = state), do: state

  defp update_mqtt(%{printer: %{name: nil}} = state) do
    case PrusaLink.refresh(state.printer) do
      {:ok, printer} ->
        Logger.info("Printer #{printer.name} now online.")
        Mqtt.publish(state.mqtt_client_id, printer_name(printer), "status", "online")
        Mqtt.publish(state.mqtt_client_id, printer_name(printer), "last_seen", now())
        %{state | printer: printer, online: true}

      {:not_reachable, _printer} ->
        state
    end
  end

  defp update_mqtt(%{printer: printer} = state) do
    case PrusaLink.status(printer) do
      {:ok, resp} ->
        resp
        |> extract_printer_info()
        |> Enum.each(fn {key, value} ->
          Mqtt.publish(state.mqtt_client_id, printer_name(printer), key, value)
        end)

        Mqtt.publish(state.mqtt_client_id, printer_name(printer), "last_seen", now())
        %{state | online: true}

      {:error, reason} when reason in [:timeout, :not_reachable] ->
        send_printer_offline(state)
        %{state | online: false}

      {:error, reason} ->
        Logger.warning("Error calling printer: #{inspect(reason)}")
        %{state | online: false}
    end
  end

  defp extract_printer_info(%{printer: printer} = resp) do
    # job is just an optional field, only present when a job is running
    job_fields =
      case resp[:job] do
        nil -> %{}
        map when is_map(map) -> Map.take(map, @fields)
      end

    Map.take(printer, @fields)
    |> Map.merge(job_fields)
  end

  defp extract_printer_info(resp),
    do: Logger.warning("Unexpected response from printer: #{inspect(resp)}")

  defp printer_conf do
    [ip: ip, password: pw, update_interval: update_interval] =
      Application.get_env(:mqtt_prusa_gw, :printer)

    interval =
      case update_interval do
        string when is_binary(string) -> Integer.parse(string)
        int when is_integer(int) -> int
        _else -> 10
      end

    %{ip: ip, password: pw, update_interval: max(interval, 1) * 1000}
  end

  defp send_printer_offline(%{online: false}), do: nil

  defp send_printer_offline(%{printer: %{name: nil}, online: true}) do
    Logger.info("Printer connection lost")
  end

  defp send_printer_offline(%{mqtt_client_id: mqtt_client_id, printer: printer, online: true}) do
    Logger.info("Printer connection lost")
    Mqtt.publish(mqtt_client_id, printer_name(printer), "status", "offline")

    Enum.map(@fields, fn key ->
      Mqtt.publish(mqtt_client_id, printer_name(printer), key, nil)
    end)
  end

  defp printer_name(printer), do: printer.name

  defp now, do: DateTime.utc_now(:second) |> DateTime.to_iso8601()
end
