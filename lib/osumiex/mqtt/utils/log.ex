defmodule Osumiex.Mqtt.Utils.Log do
  @shortdoc "Logger"

  @moduledoc """
  Logger
  """

  require Logger

  def info(%Osumiex.Mqtt.Message{variable: variable}=message) do
    info(variable)
    message
  end

  @spec info(Osumiex.Mqtt.Message.Connect.t) :: Osumiex.Mqtt.Message.Connect.t
  def info(%Osumiex.Mqtt.Message.Connect{
             client_id: client_id,
             proto_version: proto_version,
             keep_alive: keep_alive,
             will_flag: will_flag,
             will_qos: will_qos,
             will_retain: will_retain,
             will_topic: will_topic,
             will_message: will_message,
             clean_session: clean_session
           }=connect_message) do
    :ok = Logger.debug("Connect - client_id     : #{client_id}")
    :ok = Logger.debug("Connect - proto_version : #{proto_version}")
    :ok = Logger.debug("Connect - keep_alive    : #{keep_alive}")
    :ok = Logger.debug("Connect - will_flag     : #{will_flag}")
    :ok = Logger.debug("Connect - will_qos      : #{will_qos}")
    :ok = Logger.debug("Connect - will_retain   : #{will_retain}")
    :ok = Logger.debug("Connect - will_topic    : #{will_topic}")
    :ok = Logger.debug("Connect - will_message  : #{will_message}")
    :ok = Logger.debug("Connect - clean_session : #{clean_session}")
    connect_message
  end

  @spec info(Osumiex.Mqtt.Message.Publish.t) :: Osumiex.Mqtt.Message.Publish.t
  def info(%Osumiex.Mqtt.Message.Publish{
            qos: qos,
            dup: dup,
            retain: retain,
            topic: topic,
            packet_id: packet_id,
            message: message
          }=publish_message) do
    :ok = Logger.debug("Publish - qos        : #{qos}")
    :ok = Logger.debug("Publish - dup        : #{dup}")
    :ok = Logger.debug("Publish - retain     : #{retain}")
    :ok = Logger.debug("Publish - topic      : #{topic}");
    :ok = Logger.debug("Publish - packet_id  : #{packet_id}");
    :ok = Logger.debug("Publish - message    : #{message}")
    publish_message
  end

  @spec info(Osumiex.Mqtt.Message.Subscribe.t) :: Osumiex.Mqtt.Message.Subscribe.t
  def info(%Osumiex.Mqtt.Message.Subscribe{
            packet_id: packet_id,
            topics: topics
          }=subscribe_message) do
    :ok = Logger.debug("Subscribe - packet_id : #{packet_id}");
    :ok = Logger.debug("Subscribe - topics    : #{inspect(topics)}");
    subscribe_message
  end

  @spec info(Osumiex.Mqtt.Message.Disconnect.t) :: Osumiex.Mqtt.Message.Disconnect.t
  def info(%Osumiex.Mqtt.Message.Disconnect{}=disconnect_message) do
    :ok = Logger.debug("Disconnect.")
    disconnect_message
  end
end
