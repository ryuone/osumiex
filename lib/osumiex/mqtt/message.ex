defmodule Osumiex.Mqtt.Message do

  defstruct fixed_header: nil,
    variable: nil,
    payload: nil
  @type t :: %__MODULE__{}

  def message(fixed_header, variable, payload) do
    %__MODULE__{
      fixed_header: fixed_header,
      variable: variable,
      payload: payload
    }
  end

  ###========================================================
  ### MQTT : FixedHeader
  ###========================================================
  defmodule FixedHeader do
    @moduledoc """
    Defines the fixed header of a MQTT message.
    """
    defstruct type: :reserved, # bits 7-4
      dup: false,              # bits 1
      qos: :qos_0,             # bits 2
      retain: false,           # bits 1
      len: 0,
      body: <<>>
    @type t :: %__MODULE__{}
  end
  def header(type \\ :reserved, dup \\ false, qos \\ :qos_0,
             retain \\ false, len \\ 0, body \\ <<>>) when
             is_atom(type) and is_boolean(dup) and is_atom(qos) and
             is_boolean(retain) and is_integer(len) and len >= 0 do
    %FixedHeader{type: type, dup: dup,
            qos: qos, retain: retain, len: len, body: body}
  end

  ###========================================================
  ### CONNECT(type 1: Client to Server)
  ###========================================================
  defmodule Connect do
    defstruct message_type: :connect,
      proto_version: 3,
      proto_name: "",
      client_id: "",
      username: "",
      password: "",
      keep_alive:  :infinity, # or the keep-alive in milliseconds (=1000*mqtt-keep-alive)
      # keep_alive_server: :infinity, # or 1.5 * keep-alive in milliseconds (=1500*mqtt-keep-alive)
      will_flag: 0,
      will_qos: :qos_0,
      will_retain: 0,
      will_topic: "",
      will_message: "",
      clean_session: 0
    @type client_id :: String.t
    @type t :: %__MODULE__{}
  end
  def connect(client_id, username, password, proto_version,
              proto_name, keep_alive, will_flag,
              will_qos, will_retain, will_topic, will_message,
              clean_session) do
    %Connect{
      client_id: client_id,
      username: username,
      password: password,
      proto_version: proto_version,
      proto_name: proto_name,
      keep_alive: keep_alive,
      will_flag: will_flag,
      will_qos: will_qos,
      will_retain: will_retain,
      will_topic: will_topic,
      will_message: will_message,
      clean_session: clean_session
    }
  end

  ###========================================================
  ### CONNACK(type 2: Server to Client)
  ###========================================================
  defmodule ConnAck do
    defstruct message_type: :conn_ack,
      status: :ok
  end
  def conn_ack(status \\ :ok), do: %ConnAck{status: status}

  ###========================================================
  ### PUBLISH(type 3: Client to Server or Server to Client)
  ###========================================================
  defmodule Publish do
    defstruct message_type: :publish,
      qos: :qos_0,
      dup: false,
      retain: false,
      topic: "",
      packet_id: -1,
      message: ""
    @type t :: %__MODULE__{}
  end
  @spec publish(atom, boolean, boolean, binary, number, binary) :: Publish.t
  def publish(qos, dup, retain, topic, packet_id, message) do
    %Publish{
      qos: qos,
      dup: dup,
      retain: retain,
      topic: topic,
      packet_id: packet_id,
      message: message
    }
  end
  @spec publish(atom, boolean, boolean, binary, binary) :: Publish.t
  def publish(qos, dup, retain, topic, message) do
    %Publish{
      qos: qos,
      dup: dup,
      retain: retain,
      topic: topic,
      message: message
    }
  end

  ###========================================================
  ### PUBACK(type 4: Client to Server or Server to Client)
  ###========================================================
  defmodule PubAck do
    defstruct message_type: :pub_ack,
      packet_id: 0
    @type t :: %__MODULE__{}
  end
  def pub_ack(packet_id) do
    %PubAck{packet_id: packet_id}
  end

  ###========================================================
  ### PUBREC(type 5: Client to Server or Server to Client))
  ###========================================================
  defmodule PubRec do
    defstruct message_type: :pub_rec,
      packet_id: 0
    @type t :: %__MODULE__{}
  end
  def pub_rec(packet_id) do
    %PubRec{packet_id: packet_id}
  end

  ###========================================================
  ### PUBREL(type 6: Client to Server or Server to Client)
  ###========================================================
  defmodule PubRel do
    defstruct message_type: :pub_rel,
      packet_id: 0
    @type t :: %__MODULE__{}
  end
  def pub_rel(packet_id) do
    %PubRel{packet_id: packet_id}
  end

  ###========================================================
  ### PUBCOMP(type 7: Client to Server or Server to Client)
  ###========================================================
  defmodule PubComp do
    defstruct message_type: :pub_comp,
      packet_id: 0
    @type t :: %__MODULE__{}
  end
  def pub_comp(packet_id) do
    %PubComp{packet_id: packet_id}
  end

  ###========================================================
  ### SUBSCRIBE(type 8: Subscribe)
  ###========================================================
  defmodule Subscribe do
    defstruct message_type: :subscribe,
      packet_id: 0,
      topics: []
    @type t :: %__MODULE__{}
  end
  def subscribe(packet_id, topics) when is_list(topics) do
    %Subscribe{
      packet_id: packet_id,
      topics: topics
    }
  end

  ###========================================================
  ### SUBACK(type 9: Server to Client)
  ###========================================================
  defmodule SubAck do
    defstruct message_type: :sub_ack,
      packet_id: 0,
      topics: [{"topic", :qos_0}]
    @type t :: %__MODULE__{}
  end
  @spec sub_ack(number, list) :: SubAck.t
  def sub_ack(packet_id, topics) when is_integer(packet_id) and is_list(topics) do
    %SubAck{
      packet_id: packet_id,
      topics: topics
    }
  end

  ###========================================================
  ### UNSUBSCRIBE(type 10: Client to Server)
  ###========================================================
  ###========================================================
  ### UNSUBACK(type 11: Server to Client)
  ###========================================================

  ###========================================================
  ### PINGREQ(type 12: Client to Server)
  ###========================================================
  defmodule PingReq do
    defstruct message_type: :ping_req
    @type t :: %__MODULE__{}
  end
  def ping_req(), do: %PingReq{}

  ###========================================================
  ### PINGRESP(type 13: Server to Client)
  ###========================================================
  defmodule PingResp do
    defstruct message_type: :ping_resp
    @type t :: %__MODULE__{}
  end
  def ping_resp(), do: %PingResp{}

  ###========================================================
  ### DISCONNECT(type 14: Client to Server)
  ###========================================================
  defmodule Disconnect do
    defstruct message_type: :disconnect
    @type t :: %__MODULE__{}
  end
  def disconnect(), do: %Disconnect{}

  ###========================================================
  ### Topic
  ###========================================================
  defmodule Topic do
    defstruct name: nil, node: nil
  end
  def topic(name, node) do
    %Topic{name: name, node: node}
  end

  ###========================================================
  ### MQTT Message
  ###========================================================
  defmodule MqttMessage do
    defstruct topic: nil,
      qos: nil,
      retain: nil,
      message: "",
      packet_id: nil,
      dup: nil,
      timestamp: nil
  end
  def create_will_message(topic, qos, retain, message) do
    %MqttMessage{
      topic: topic,
      qos: qos,
      retain: retain,
      message: message
    }
  end

  def convert_mqtt_msg_to_publish_msg(%MqttMessage{} = msg) do
    publish(msg.qos, msg.dup, msg.retain, msg.topic, 1, msg.message)
  end
  def convert_mqtt_msg_to_publish_msg(nil = msg), do: msg

end
