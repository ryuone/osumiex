defmodule Osumiex.Mqtt.SupSession do
  use Supervisor
  require Logger
  require Utils

  def start_link do
    :ok = Logger.info(Utils.current_module_function <> " called.")
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    :ok = Logger.info(Utils.current_module_function <> " called.")
    children = [
      worker(Osumiex.Mqtt.Session, [], restart: :temporary)
    ]
    supervise(children, strategy: :simple_one_for_one)
  end

  def start_session(socket, transport, %Osumiex.Mqtt.Message.Connect{} = connect) do
    :ok = Logger.info(Utils.current_module_function <> " called.")
    Supervisor.start_child(__MODULE__, [socket, transport, self(), connect])
  end
end
