import Config

config :mqtt_prusa_gw, :printer,
  ip: System.get_env("PRUSA_IP"),
  password: System.get_env("PRUSA_PW"),
  # refresh interval in seconds
  update_interval: System.get_env("PRUSA_INTERVAL") || 10

config :mqtt_prusa_gw, :mqtt,
  host: System.get_env("MQTT_HOST") || "127.0.0.1",
  port: System.get_env("MQTT_PORT") || 1883,
  username: System.get_env("MQTT_USER") || nil,
  password: System.get_env("MQTT_PW") || nil,
  event_topic_namespace: System.get_env("MQTT_EVENT_TOPIC_NS") || "home/get/prusa_gw"
