defmodule Osumiex.Mqtt.Message do

  defmodule Header do
    @moduledoc """
    Defines the fixed header of a MQTT message.
    """
    defstruct type: :reserved, # :: Mqttex.message_type,
      dup: false, # :: boolean,
      qos: :fire_and_forget, # :: Mqttex.qos_type,
      retain: false, # :: boolean,
      len: 0, # :: pos_integer
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

  defmodule Connect do
    defstruct message_type: :connect, # :: atom
      client_id: "", # :: binary,
      user_name: "", # :: binary,
      password: "", # :: binary,
      version: 3, #
      keep_alive:  :infinity, # or the keep-alive in milliseconds (=1000*mqtt-keep-alive)
      # keep_alive_server: :infinity, # or 1.5 * keep-alive in milliseconds (=1500*mqtt-keep-alive)
      last_will: false, # :: boolean,
      will_qos: :fire_and_forget, # :: Mqttex.qos_type,
      will_retain: false, # :: boolean,
      will_topic: "", # :: binary,
      will_message: "", # :: binary,
      clean_session: true # :: boolean,
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

  defmodule ConnAck do
    defstruct message_type: :conn_ack,
      status: :ok
  end
  def conn_ack(status \\ :ok), do: %ConnAck{status: status}

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


  defmodule PingReq do
    defstruct message_type: :ping_req
  end
  def ping_req(), do: %PingReq{}

  defmodule PingRes do
    defstruct message_type: :ping_resp
  end
  def ping_resp(), do: %PingRes{}

end
