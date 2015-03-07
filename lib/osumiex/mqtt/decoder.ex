defmodule Osumiex.Mqtt.Decoder do
  require Logger
  use Bitwise

  def decode(<< header_msg :: binary-size(2), body_msg :: binary >>) do
    msg = decode_header(header_msg, body_msg)

    decode_msg(msg)
  end

  def decode_header(<<type :: size(4), dup :: size(1), qos :: size(2),
                    retain :: size(1), len :: size(8)>>, body_msg) do
    [len, body_msg] = binary_to_len(<<len>>, body_msg)

    Osumiex.Mqtt.Message.header(
      binary_to_mqtt_message_type(type),
      (dup == 1),
      binary_to_mqtt_qos(qos),
      (retain == 1),
      len,
      body_msg
    )
  end

  # Connect
  defp decode_msg(%Osumiex.Mqtt.Message.Header{type: :connect, body: body} = _header) do
    decode_connect(body)
  end
  defp decode_msg(%Osumiex.Mqtt.Message.Header{type: :ping_req, body: body} = _header) do
    decode_ping_req()
  end
  defp decode_msg(%Osumiex.Mqtt.Message.Header{type: type} = _msg) do
    Logger.info("2)type : #{type}")
  end

  # Create connect message.
  def decode_connect(<<client_id_len :: integer-unsigned-size(16),
                     client_id :: binary-size(client_id_len), version :: size(8),
                     flags :: size(8), keep_alive :: size(16), rest::binary>>) do

    # parse flag
    <<user_flag :: size(1), pass_flag :: size(1), w_retain :: size(1), w_qos :: size(2),
      w_flag :: size(1), clean :: size(1), _ ::size(1)>> = <<flags>>

    {client_id, payload} = pick_1head(1, utf8_list(rest))
    {will_topic, will_message, payload} = pick_2head(w_flag, payload)
    {user_name, payload} = pick_1head(user_flag, payload)
    {password, payload} = pick_1head(pass_flag, payload)

    Osumiex.Mqtt.Message.connect(client_id, user_name, password,
                                 keep_alive,
                                 (w_flag == 1),
                                 binary_to_mqtt_qos(w_qos),
                                 (w_retain == 1),
                                 will_topic,
                                 will_message,
                                 (clean == 1))
  end

  def decode_ping_req() do
    Osumiex.Mqtt.Message.ping_req()
  end


  defp binary_to_len(bin, count \\ 4, rest_bin)
  defp binary_to_len(_bin, _count = 0, _rest_bin), do: raise 'Invalid length'
  defp binary_to_len(<<overflow :: size(1), len :: size(7)>> = _bin, count, rest_bin) do
    case overflow do
      1 ->
        <<next :: size(8), rest_bin :: binary>> = rest_bin
        [ret_len, ret_rest_bin] = binary_to_len(<<next>>, count - 1, rest_bin)
        [len + (ret_len <<< 7), ret_rest_bin]
      0 ->
        [len, rest_bin]
    end
  end

  def pick_1head(0, list), do: {"", list}
  def pick_1head(1, list), do: {hd(list), tl(list)}

  def pick_2head(0, list), do: {"", "", list}
  def pick_2head(1, list), do: {hd(list), hd(tl(list)), tl(tl(list))}


  def utf8_list(<<>>, acc), do: Enum.reverse acc
  def utf8_list(binary, acc \\ []) do
    {content, rest} = utf8(binary)
    utf8_list(rest, [content | acc])
  end

  def utf8(<<length :: integer-unsigned-size(16), content :: bytes-size(length), rest :: binary>>) do
    {content, rest}
  end

  # Define Qos function.
  for {num, atom} <- Osumiex.Mqtt.Define.qos do
    def binary_to_mqtt_qos(unquote(num)), do: unquote(atom)
  end
  # Define Mqtt Message type
  for {num, atom} <- Osumiex.Mqtt.Define.message_type do
    def binary_to_mqtt_message_type(unquote(num)), do: unquote(atom)
  end
  # Define Mqtt ack status
  for {num, atom} <- Osumiex.Mqtt.Define.ack_status do
    def mqtt_conn_ack_status(unquote(num)), do: unquote(atom)
  end
end
