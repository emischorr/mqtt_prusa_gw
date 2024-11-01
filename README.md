# MqttPrusaGw

A MQTT gateway that connects to your local Prusa printer API to query for the printer information and job status.
Updates information every 30 seconds.

## ENV vars

Required:
`PRUSA_USER`
`PRUSA_PW`

Optional:
`MQTT_HOST` default "127.0.0.1"
`MQTT_PORT` default 1883
`MQTT_USER`
`MQTT_PW`

## Installation / Running

