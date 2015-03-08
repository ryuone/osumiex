defmodule Osumiex.Mqtt.Utils.Log do
  require Logger

  def info(%Osumiex.Mqtt.Message.Connect{} = message) do
    Logger.debug("Connect - client_id     : #{message.client_id}")
    Logger.debug("Connect - version       : #{message.version}")
    Logger.debug("Connect - keep_alive    : #{message.keep_alive}")
    Logger.debug("Connect - last_will     : #{message.last_will}")
    Logger.debug("Connect - will_qos      : #{message.will_qos}")
    Logger.debug("Connect - will_retain   : #{message.will_retain}")
    Logger.debug("Connect - will_topic    : #{message.will_topic}")
    Logger.debug("Connect - will_message  : #{message.will_message}")
    Logger.debug("Connect - clean_session : #{message.clean_session}")
    message
  end

  def info(%Osumiex.Mqtt.Message.Publish{} = message) do
    Logger.debug("Publish - qos        : #{message.qos}")
    Logger.debug("Publish - dup        : #{message.dup}")
    Logger.debug("Publish - retain     : #{message.retain}")
    Logger.debug("Publish - topic      : #{message.topic}");
    Logger.debug("Publish - message_id : #{message.message_id}");
    Logger.debug("Publish - message    : #{message.message}")
    message
  end

end
