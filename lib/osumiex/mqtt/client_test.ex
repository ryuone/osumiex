defmodule Osumiex.Mqtt.ClientTest do
  require Logger
  require Utils

  use GenServer
  @behaviour :ranch_protocol

  @timeout 100

  import Record
  defrecord :client_state, recv_length: 2, socket: nil, transport: nil

  def start_link(ref, socket, transport, opts) do
    :proc_lib.start_link(__MODULE__, :init, [ref, socket, transport, opts])
  end

  def init(ref, socket, transport, _opts=[]) do
    :ok = Logger.debug(Utils.current_module_function <> " called.")
    :ok = :proc_lib.init_ack({:ok, self()})
    :ok = :ranch.accept_ack(ref)

    :ok = transport.setopts(socket, [{:active, :once}])

    state = client_state(socket: socket, transport: transport)

    :gen_server.enter_loop(__MODULE__, [], state, @timeout)
  end

  def handle_info({:tcp, socket, data}, client_state(socket: socket, transport: transport)=state) do
    Logger.debug("TCP...")
    :ok = transport.setopts(socket, [{:active, :once}, {:packet, 1}])
    Logger.debug(inspect(socket))
    Logger.debug(inspect(data))
    {:noreply, state}
  end

  def handle_info(:timeout, client_state(socket: socket, transport: transport)=state) do
    Logger.debug("Timeout...")
    data = transport.recv(socket, 2, :infinity)
    Logger.debug(inspect(data))
    {:noreply, state, @timeout}
  end

  def handle_info({:tcp_closed, socket}, client_state(socket: socket, transport: _transport)=state) do
    :ok = Logger.debug(Utils.current_module_function <> " called. : TCP connection closed.")
    {:stop, :normal, state};
  end
end

