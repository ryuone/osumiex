defmodule Osumiex.Mqtt.Encoder do
  require Logger
  use Bitwise

  #
  # MQTT messages
  #
  def encode(%Osumiex.Mqtt.Message.ConnAck{message_type: message_type, status: status}) do
    <<mqtt_message_type_to_binary(message_type) :: size(4), 0 :: size(4), 0x02, 0x00, mqtt_conn_ack_status(status)>>
  end
  def encode(%Osumiex.Mqtt.Message.PingRes{message_type: message_type}) do
    <<mqtt_message_type_to_binary(message_type) :: size(4), 0 :: size(4), 0x00>>
  end
  def encode(%Osumiex.Mqtt.Message.SubAck{message_type: message_type, message_id: message_id, topics: topics}) do
    qos_binary = sub_ack_qos_to_binary(topics)
    len = 2 + byte_size(qos_binary)
    <<mqtt_message_type_to_binary(message_type) :: size(4), 0 :: size(4),
      len_to_binary(len) :: binary, message_id(message_id) :: binary,
      qos_binary :: binary>>
  end
  def encode(%Osumiex.Mqtt.Message.Publish{message_type: message_type, topic: topic, qos: :fire_and_forget, message: message}=publish) do
    Logger.info("Encode : message    [#{message}]")
    Logger.info("#{inspect topic}")
    topic = utf8(topic)
    msg_id = message_id(0)
    message = utf8(message)
    len = byte_size(topic) + byte_size(msg_id) + byte_size(message)
    Logger.info("length : [#{len}]")
    Logger.info("topic : [#{inspect topic}]")

    <<encode_header(message_type, false, publish.qos, false, len) :: binary, topic::binary, msg_id :: binary, message::binary>>
  end

  @spec encode_header(atom, boolean, atom, boolean, number) :: binary
  defp encode_header(type, dup, qos, retain, length) do
    <<mqtt_message_type_to_binary(type) :: size(4),
      boolean_to_binary(dup) :: bits,
      mqtt_qos_to_binary(qos) :: size(2),
      boolean_to_binary(retain) :: bits,
      len_to_binary(length) :: binary>>
  end

  @doc "Convert boolean to bit"
  def boolean_to_binary(true), do: <<1 :: size(1)>>
  def boolean_to_binary(false), do: <<0 :: size(1)>>

  def utf8(str), do: <<byte_size(str) :: big-size(16)>> <> str

  def message_id(id) when is_integer(id), do: <<id :: big-size(16)>>

  def sub_ack_qos_to_binary(topics), do: sub_ack_qos_to_binary(topics, <<>>)
  def sub_ack_qos_to_binary([], acc), do: acc
  def sub_ack_qos_to_binary([{_topic, qos} | t], acc) do
    sub_ack_qos_to_binary(t, acc <> <<mqtt_qos_to_binary(qos) :: size(8)>>)
  end


  defp len_to_binary(0), do: <<0x00>>
  defp len_to_binary(l) when l <= 268_435_455, do: len_to_binary(l, <<>>)
  defp len_to_binary(0, acc), do: acc
  defp len_to_binary(l, acc) do
    digit = l &&& 0x7f # mod 128
    new_l = l >>> 7 # div 128
    if new_l > 0 do
      len_to_binary(new_l, acc <> <<digit ||| 0x80>>)
    else
      len_to_binary(new_l, acc <> <<digit>>)
    end
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
