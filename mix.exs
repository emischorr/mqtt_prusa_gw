defmodule MqttPrusaGw.MixProject do
  use Mix.Project

  def project do
    [
      app: :mqtt_prusa_gw,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {MqttPrusaGw.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:tortoise311, "~> 0.12.0"},
      {:prusa_link, "~> 0.2.2"}
    ]
  end
end
