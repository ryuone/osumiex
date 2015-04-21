#
# Currentry not using.
#
defmodule Osumiex.Mqtt.Mnesia do
  def init do
    :mnesia.create_schema([node()])
  end
end
