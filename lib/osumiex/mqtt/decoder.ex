defmodule Osumiex.Mqtt.Decoder do
  require Logger
  require Utils
  use Bitwise

  @type next_byte_fun :: (() -> {binary, next_byte_fun})

  @doc """
  Decode data.
  """
  def decode(<< header_msg :: binary-size(2), body_msg :: binary >>) do
    decode_header(header_msg, body_msg) |> decode_msg
  end

  defp decode_header(<<type :: size(4), dup :: size(1), qos :: size(2), retain :: size(1),
                     len :: size(8)>> = head_part, body_msg) do
    {len, body_msg} = binary_to_len(<<len>>, body_msg)
    :ok = Logger.debug("decode header : len      : " <> inspect(len))
    :ok = Logger.debug("decode header : body_msg : " <> inspect(head_part))

    Osumiex.Mqtt.Message.header(
      binary_to_mqtt_message_type(type),
      (dup == 1),
      binary_to_mqtt_qos(qos),
      (retain == 1),
      len,
      body_msg
    )
  end

  # 1. CONNECT
  defp decode_msg(%Osumiex.Mqtt.Message.FixedHeader{type: :connect, body: body, len: len} = header) do
    :ok = Logger.debug(Utils.current_module_function <> " : Message type : #{header.type}")
    decode_connect(header, len, body) |> Osumiex.Mqtt.Utils.Log.info
  end

  # 3. PUBLISH
  defp decode_msg(%Osumiex.Mqtt.Message.FixedHeader{type: :publish, body: body, len: len} = header) do
    decode_publish(header, len, body) |> Osumiex.Mqtt.Utils.Log.info
  end

  # 4. PUBACK
  defp decode_msg(%Osumiex.Mqtt.Message.FixedHeader{type: :pub_ack, body: body, len: len} = header) do
    decode_pub_ack(header, len, body)
  end

  # 5. PUBREC
  defp decode_msg(%Osumiex.Mqtt.Message.FixedHeader{type: :pub_rec, body: body, len: len} = header) do
    decode_pub_rec(header, len, body)
  end

  # 6. PUBREL
  defp decode_msg(%Osumiex.Mqtt.Message.FixedHeader{type: :pub_rel, body: body, len: len} = header) do
    decode_pub_rel(header, len, body)
  end

  # 7. PUBCOMP
  defp decode_msg(%Osumiex.Mqtt.Message.FixedHeader{type: :pub_comp, body: body, len: len} = header) do
    decode_pub_comp(header, len, body)
  end

  # 8. SUBSCRIBE
  defp decode_msg(%Osumiex.Mqtt.Message.FixedHeader{type: :subscribe, body: body, len: len} = header) do
    decode_subscribe(header, len, body) |> Osumiex.Mqtt.Utils.Log.info
  end

  # 12. PINGREQ
  defp decode_msg(%Osumiex.Mqtt.Message.FixedHeader{type: :ping_req} = header) do
    decode_ping_req(header)
  end

  # 14. DISCONNECT
  defp decode_msg(%Osumiex.Mqtt.Message.FixedHeader{type: :disconnect} = header) do
    :ok = Logger.debug(Utils.current_module_function <> " : Message type : #{header.type}")
    decode_disconnect(header) |> Osumiex.Mqtt.Utils.Log.info
  end

  # 14. Others
  defp decode_msg(%Osumiex.Mqtt.Message.FixedHeader{type: type} = _msg) do
    :ok = Logger.error("#{__MODULE__} : Unkown message type : #{type}")
  end

  ### 1. CONNECT create message ###
  @spec decode_connect(Osumiex.Mqtt.Message.FixedHeader, integer(), binary()) :: Osumiex.Mqtt.Message.t
  defp decode_connect(header, len, body) do
    :ok = Logger.debug(Utils.current_module_function <> " called.")
    <<payload :: binary-size(len), _rest :: binary>> = body
    {proto_name, payload} = utf8(payload)
    <<proto_version :: size(8), payload::binary>> = payload

    <<user_flag     :: size(1),
      pass_flag     :: size(1),
      will_retain   :: size(1),
      will_qos      :: size(2),
      will_flag     :: size(1),
      clean_session :: size(1),
      _reserved     :: size(1),
      keep_alive    :: big-size(16),
      payload       :: binary>> = payload

    {client_id,    payload} = utf8(payload)
    {will_topic,   payload} = utf8(payload, will_flag)
    {will_message, payload} = utf8(payload, will_flag)
    {username,     payload} = utf8(payload, user_flag)
    {password,    _payload} = utf8(payload, pass_flag)

    variable = Osumiex.Mqtt.Message.connect(
                 client_id,
                 username,
                 password,
                 proto_version,
                 proto_name,
                 keep_alive,
                 will_flag,
                 binary_to_mqtt_qos(will_qos),
                 will_retain,
                 will_topic,
                 will_message,
                 clean_session
               )
    Osumiex.Mqtt.Message.message(header, variable, body)
  end

  ### 3. PUBLISH create message ###
  defp decode_publish(%Osumiex.Mqtt.Message.FixedHeader{dup: dup, retain: retain, qos: qos} = header,
                      len, body) when qos == :qos_0 do

    <<payload :: binary-size(len), _rest :: binary>> = body
    <<topic_len :: big-size(16), topic :: binary-size(topic_len), payload::binary>> = payload

    Logger.debug("#{__MODULE__} : (QoS0)topic_len : #{inspect topic_len}");
    Logger.debug("#{__MODULE__} : (QoS0)topic     : #{inspect topic}");
    Logger.debug("#{__MODULE__} : (QoS0)payload   : #{inspect payload}");

    variable = Osumiex.Mqtt.Message.publish(qos, dup, retain, topic, payload)
    Osumiex.Mqtt.Message.message(header, variable, body)
  end
  defp decode_publish(%Osumiex.Mqtt.Message.FixedHeader{dup: dup, retain: retain, qos: qos} = header,
                      len, body) when qos == :qos_1 or qos == :qos_2 do

    <<payload :: binary-size(len), _rest :: binary>> = body
    <<topic_len :: big-size(16), topic :: binary-size(topic_len), payload::binary>> = payload
    <<packet_id :: big-size(16), payload :: binary>> = payload

    Logger.debug("#{__MODULE__} : (QoS1/2)topic_len : #{inspect topic_len}");
    Logger.debug("#{__MODULE__} : (Qos1/2)topic     : #{inspect topic}");
    Logger.debug("#{__MODULE__} : (Qos1/2)packet_id : #{inspect packet_id}");
    Logger.debug("#{__MODULE__} : (Qos1/2)payload   : #{inspect payload}");

    variable = Osumiex.Mqtt.Message.publish(qos, dup, retain, topic, packet_id, payload)
    Osumiex.Mqtt.Message.message(header, variable, body)
  end

  ### 8. SUBSCRIBE create message ###
  defp decode_subscribe(header, len, body) do
    <<payload :: binary-size(len), _rest :: binary>> = body
    <<packet_id :: big-size(16), payload :: binary>> = payload

    :qos_1 = header.qos

    topics = parse_topics(payload)

    variable = Osumiex.Mqtt.Message.subscribe(packet_id, topics)
    Osumiex.Mqtt.Message.message(header, variable, body)
  end

  ### 4. PUBACK create message ###
  defp decode_pub_ack(header, len, body) do
    <<payload :: binary-size(len), _rest :: binary>> = body
    <<packet_id :: big-size(16), _payload :: binary>> = payload

    variable = Osumiex.Mqtt.Message.pub_ack(packet_id)
    Osumiex.Mqtt.Message.message(header, variable, nil)
  end

  ### 5. PUBREC create message ###
  defp decode_pub_rec(header, len, body) do
    <<payload :: binary-size(len), _rest :: binary>> = body
    <<packet_id :: big-size(16), _payload :: binary>> = payload

    variable = Osumiex.Mqtt.Message.pub_rec(packet_id)
    Osumiex.Mqtt.Message.message(header, variable, nil)
  end

  ### 6. PUBREL create message ###
  defp decode_pub_rel(header, len, body) do
    <<payload :: binary-size(len), _rest :: binary>> = body
    <<packet_id :: big-size(16), _payload :: binary>> = payload

    variable = Osumiex.Mqtt.Message.pub_rel(packet_id)
    Osumiex.Mqtt.Message.message(header, variable, nil)
  end

  ### 7. PUBCOMP create message ###
  defp decode_pub_comp(header, len, body) do
    <<payload :: binary-size(len), _rest :: binary>> = body
    <<packet_id :: big-size(16), _payload :: binary>> = payload

    variable = Osumiex.Mqtt.Message.pub_comp(packet_id)
    Osumiex.Mqtt.Message.message(header, variable, nil)
  end

  ### 12. PINGREQ create message ###
  @spec decode_ping_req(Osumiex.Mqtt.Message.FixedHeader) :: Osumiex.Mqtt.Message.PingReq.t
  defp decode_ping_req(header) do
    variable = Osumiex.Mqtt.Message.ping_req()
    Osumiex.Mqtt.Message.message(header, variable, nil)
  end

  ### 14. DISCONNECT create message ###
  @spec decode_disconnect(Osumiex.Mqtt.Message.FixedHeader.t) :: Osumiex.Mqtt.Message.t
  defp decode_disconnect(header) do
    variable = Osumiex.Mqtt.Message.disconnect()
    Osumiex.Mqtt.Message.message(header, variable, nil)
  end

  @spec parse_topics(binary) :: [{binary, atom}]
  defp parse_topics(topics), do: parse_topics(topics, [])

  @spec parse_topics(binary, list) :: [{binary, atom}]
  defp parse_topics(<<>>, acc), do: acc |> Enum.reverse
  defp parse_topics(<<topic_len :: integer-unsigned-size(16), topic :: binary-size(topic_len),
              _ :: size(6), qos :: size(2), rest :: binary>> = _payload, acc) do
    parse_topics(rest, [{topic, binary_to_mqtt_qos(qos)} | acc])
  end

  @spec binary_to_len(binary, binary) :: {integer, binary}
  defp binary_to_len(bin, rest_bin), do: binary_to_len(bin, 4, rest_bin)

  @spec binary_to_len(binary, integer, binary) :: {integer, binary} | Exception.t
  defp binary_to_len(_bin, 0, _rest_bin) do
    raise Osumiex.Mqtt.RemainingLengthError
  end
  defp binary_to_len(<<overflow :: size(1), len :: size(7)>> = _bin, count, rest_bin) do
    case overflow do
      1 ->
        <<next :: size(8), rest_bin :: binary>> = rest_bin
        {ret_len, ret_rest_bin} = binary_to_len(<<next>>, count - 1, rest_bin)
        {len + (ret_len <<< 7), ret_rest_bin}
      0 ->
        {len, rest_bin}
    end
  end

  def pick_1head(0, list), do: {"", list}
  def pick_1head(1, list), do: {hd(list), tl(list)}

  def pick_2head(0, list), do: {"", "", list}
  def pick_2head(1, list), do: {hd(list), hd(tl(list)), tl(tl(list))}

  def utf8_list(binary), do: utf8_list(binary, [])
  def utf8_list(<<>>, acc), do: Enum.reverse acc
  def utf8_list(binary, acc) do
    {content, rest} = utf8(binary)
    utf8_list(rest, [content | acc])
  end

  def utf8(bin, 0), do: {nil, bin}
  def utf8(bin, _), do: utf8(bin)

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
