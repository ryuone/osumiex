defmodule Osumiex.Mqtt.SupSession do
  use Supervisor
  require Logger

  def start_link do
    Logger.info "SupSession.start_link called."
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    Logger.info "SupSession.init called."
    children = [
      worker(Osumiex.Mqtt.Session, [], restart: :transient)
    ]
    supervise(children, strategy: :simple_one_for_one)
  end

  def start_session(socket, transport, %Osumiex.Mqtt.Message.Connect{} = connect) do
    Supervisor.start_child(__MODULE__, [socket, transport, self(), connect])
  end
end
