defmodule Osumiex.Mqtt.Encoder do
  require Logger

  def encode(%Osumiex.Mqtt.Message.ConnAck{message_type: message_type, status: status}) do
    <<mqtt_message_type_to_binary(message_type) :: size(4), 0 :: size(4), 0x02, 0x00, mqtt_conn_ack_status(status)>>
  end
  def encode(%Osumiex.Mqtt.Message.PingRes{message_type: message_type}) do
    <<mqtt_message_type_to_binary(message_type) :: size(4), 0 :: size(4), 0x00>>
  end

  # Define Qos function.
  for {num, atom} <- Osumiex.Mqtt.Define.qos do
    def mqtt_qos_to_binary(unquote(atom)), do: unquote(num)
  end
  # Define Mqtt Message type
  for {num, atom} <- Osumiex.Mqtt.Define.message_type do
    def mqtt_message_type_to_binary(unquote(atom)), do: unquote(num)
  end
  # Define Mqtt ack status
  for {num, atom} <- Osumiex.Mqtt.Define.ack_status do
    def mqtt_conn_ack_status(unquote(atom)), do: unquote(num)
  end

end
