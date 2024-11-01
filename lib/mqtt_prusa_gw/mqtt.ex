defmodule MqttPrusaGw.Mqtt do
  alias MqttPrusaGw.Mqtt.Handler

  def client(), do: "prusa_gw_#{Enum.random(1..9)}"

  def connect(), do: connect(client())

  def connect(client_id) do
    config = Application.get_env(:mqtt_prusa_gw, :mqtt)

    case Tortoise311.Supervisor.start_child(
           client_id: client_id,
           handler: {Handler, []},
           server: {Tortoise311.Transport.Tcp, host: config[:host], port: config[:port]},
           user_name: config[:username],
           password: config[:password],
           will: %Tortoise311.Package.Publish{
             topic: "#{config[:event_topic_namespace]}/status",
             payload: "offline",
             qos: 1,
             retain: true
           }
         ) do
      {:ok, _pid} -> {:ok, client_id}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec publish_meta(String.t()) :: :ok | {:error, :unknown_connection} | {:ok, reference}
  def publish_meta(client_id) do
    topic_ns = Application.get_env(:mqtt_prusa_gw, :mqtt)[:event_topic_namespace]

    Tortoise311.publish(client_id, "#{topic_ns}/status", "online", qos: 0, retain: true)
  end

  @spec publish(String.t(), String.t(), term(), any()) ::
          :ok | {:error, :unknown_connection} | {:ok, reference}
  def publish(client_id, printer_name, key, val) do
    topic =
      Application.get_env(:mqtt_prusa_gw, :mqtt)[:event_topic_namespace]
      |> sanitize_topic("/#{printer_name}/#{key}")

    value = val |> to_string()
    Tortoise311.publish(client_id, topic, value, qos: 0, retain: true)
  end

  defp sanitize_topic(ns, topic) do
    (ns <> topic) |> String.downcase() |> String.replace(" ", "_")
  end
end
