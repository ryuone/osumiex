defmodule Osumiex.Mqtt.Message do

  ###========================================================
  ### MQTT : Header
  ###========================================================
  defmodule Header do
    @moduledoc """
    Defines the fixed header of a MQTT message.
    """
    defstruct type: :reserved,
      dup: false,
      qos: :fire_and_forget,
      retain: false,
      len: 0,
      body: <<>>
    @type t :: %__MODULE__{}
  end
  def header(type \\ :reserved, dup \\ false, qos \\ :fire_and_forget,
             retain \\ false, len \\ 0, body \\ <<>>) when
             is_atom(type) and is_boolean(dup) and is_atom(qos) and
             is_boolean(retain) and is_integer(len) and len >= 0 do
    %Header{type: type, dup: dup,
            qos: qos, retain: retain, len: len, body: body}
  end

  ###========================================================
  ### MQTT : Connect
  ###========================================================
  defmodule Connect do
    defstruct message_type: :connect,
      client_id: "",
      user_name: "",
      password: "",
      version: 3,
      keep_alive:  :infinity, # or the keep-alive in milliseconds (=1000*mqtt-keep-alive)
      # keep_alive_server: :infinity, # or 1.5 * keep-alive in milliseconds (=1500*mqtt-keep-alive)
      last_will: false,
      will_qos: :fire_and_forget,
      will_retain: false,
      will_topic: "",
      will_message: "",
      clean_session: true
    @type client_id :: String.t
    @type t :: %__MODULE__{}
  end
  def connect(client_id, user_name, password, version, keep_alive, last_will,
                 will_qos, will_retain, will_topic, will_message,
                clean_session) do
    %Connect{
      client_id: client_id,
      user_name: user_name,
      password: password,
      version: version,
      keep_alive: keep_alive,
      last_will: last_will,
      will_qos: will_qos,
      will_retain: will_retain,
      will_topic: will_topic,
      will_message: will_message,
      clean_session: clean_session
    }
  end

  ###========================================================
  ### MQTT : Connect Ack
  ###========================================================
  defmodule ConnAck do
    defstruct message_type: :conn_ack,
      status: :ok
  end
  def conn_ack(status \\ :ok), do: %ConnAck{status: status}

  ###========================================================
  ### MQTT : Publish
  ###========================================================
  defmodule Publish do
    defstruct message_type: :publish,
      qos: :fire_and_forget,
      dup: false,
      retain: false,
      topic: "",
      message_id: -1,
      message: ""
    @type t :: %__MODULE__{}
  end
  @spec publish(atom, boolean, boolean, binary, number, binary) :: Publish.t
  def publish(qos, dup, retain, topic, message_id, message) do
    %Publish{
      qos: qos,
      dup: dup,
      retain: retain,
      topic: topic,
      message_id: message_id,
      message: message
    }
  end

  ###========================================================
  ### MQTT : Subscribe
  ###========================================================
  defmodule Subscribe do
    defstruct message_type: :subscribe,
      qos: :fire_and_forget,
      dup: false,
      message_id: 0,
      topics: []
    @type t :: %__MODULE__{}
  end
  def subscribe(qos, dup, message_id, topics) when is_atom(qos) and is_boolean(dup) and is_list(topics) do
    %Subscribe{
      qos: qos,
      dup: dup,
      message_id: message_id,
      topics: topics
    }
  end

  ###========================================================
  ### MQTT : Subscribe Ack
  ###========================================================
  defmodule SubAck do
    defstruct message_type: :sub_ack,
      message_id: 0,
      topics: [{"topic", :fire_and_forget}]
    @type t :: %__MODULE__{}
  end
  @spec sub_ack(number, list) :: SubAck.t
  def sub_ack(message_id, topics) when is_integer(message_id) and is_list(topics) do
    %SubAck{
      message_id: message_id,
      topics: topics
    }
  end

  ###========================================================
  ### MQTT : Ping request
  ###========================================================
  defmodule PingReq do
    defstruct message_type: :ping_req
    @type t :: %__MODULE__{}
  end
  def ping_req(), do: %PingReq{}

  ###========================================================
  ### MQTT : Ping response
  ###========================================================
  defmodule PingRes do
    defstruct message_type: :ping_resp
    @type t :: %__MODULE__{}
  end
  def ping_resp(), do: %PingRes{}

  ###========================================================
  ### MQTT : 3.14 Disconnect
  ###========================================================
  defmodule Disconnect do
    defstruct message_type: :disconnect
    @type t :: %__MODULE__{}
  end
  def disconnect(), do: %Disconnect{}

  ###========================================================
  ### State : Session
  ###========================================================
  defmodule Session do
    defstruct socket: nil,
      transport: nil,
      client_id: nil,
      client_pid: nil,
      subscribes: Map.new(),
      expires: 0,
      keep_alive: :infinity,
      expire_timer: nil
  end
  def session(socket, transport, client_id, client_pid, keep_alive, expires) do
    %Session{
      socket: socket,
      transport: transport,
      client_id: client_id,
      client_pid: client_pid,
      expires: expires,
      keep_alive: keep_alive
    }
  end

  ###========================================================
  ### Topic
  ###========================================================
  defmodule Topic do
    defstruct name: nil, node: nil
  end
  def topic(name, node) do
    %Topic{name: name, node: node}
  end

end
