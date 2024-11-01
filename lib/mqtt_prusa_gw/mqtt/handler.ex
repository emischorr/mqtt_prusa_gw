defmodule MqttPrusaGw.Mqtt.Handler do
  use Tortoise311.Handler

  require Logger

  defstruct []
  alias __MODULE__, as: State

  def init(_opts) do
    Logger.info("Initializing handler")
    {:ok, %State{}}
  end

  def connection(:up, state) do
    Logger.info("Connection has been established")
    {:ok, state}
  end

  def connection(:down, state) do
    Logger.warning("Connection has been dropped")
    {:ok, state}
  end

  def connection(:terminating, state) do
    Logger.warning("Connection is terminating")
    {:ok, state}
  end

  #  topic filter room/+/temp
  def handle_message(topic, payload, state) do
    case {List.last(topic), payload} do
      {key, payload} ->
        Logger.warning("Setting #{key} is not supported for payload: #{payload}")
    end

    {:ok, state}
  end

  def subscription(:up, topic, state) do
    Logger.info("Subscribed to #{inspect(topic)}")
    {:ok, state}
  end

  def subscription({:warn, [requested: req, accepted: qos]}, topic, state) do
    Logger.warning(
      "Subscribed to #{inspect(topic)}; requested #{req} but got accepted with QoS #{qos}"
    )

    {:ok, state}
  end

  def subscription({:error, reason}, topic, state) do
    Logger.error("Error subscribing to #{inspect(topic)}; #{inspect(reason)}")
    {:ok, state}
  end

  def subscription(:down, topic, state) do
    Logger.info("Unsubscribed from #{inspect(topic)}")
    {:ok, state}
  end

  def terminate(reason, _state) do
    Logger.warning("Client has been terminated with reason: #{inspect(reason)}")
    :ok
  end
end
