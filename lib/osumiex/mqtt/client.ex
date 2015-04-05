defmodule Osumiex.Mqtt.Client do
  use GenServer

  require Logger

  import Record
  @behaviour :ranch_protocol

  @timeout 30

  defrecord :state, socket: [], transport: []

  def start_link(ref, socket, transport, opts) do
    :proc_lib.start_link(__MODULE__, :init, [ref, socket, transport, opts])
  end

  def init(ref, socket, transport, opts) do
    :ok = :proc_lib.init_ack({:ok, self()})
    :ok = :ranch.accept_ack(ref)
    :ok = transport.setopts(socket, [{:active, :once}])

    s = state(socket: socket, transport: transport)

    result = :gen_server.enter_loop(__MODULE__, [], s, @timeout)
  end


  def handle_info({:tcp, socket, data}, state=state(socket: socket, transport: transport)) do
    :ok = transport.setopts(socket, [{:active, :once}])

    request_data = Osumiex.Mqtt.Decoder.decode(data)
    Logger.info("******************************************************")
    Logger.info("******** Request type : [#{request_data.message_type}]")

    do_response(socket, transport, request_data)

    {:noreply, state}
  end
  def handle_info({:tcp_closed, socket}, state=state(socket: socket, transport: transport)) do
    Logger.info('connection close')
    {:stop, :normal, state};
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  def terminate(_reason, _state) do
     :ok
  end

  ##
  ## Internal Functions
  ##

  #
  # Connect response
  #
  def do_response(socket, transport, %Osumiex.Mqtt.Message.Connect{} = message) do
    session_pid = case Osumiex.Mqtt.SupSession.start_session(socket, transport, message) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:already_started, pid}
    end |> session_resume(socket, transport)
    Logger.info("SupSession start PID[#{inspect session_pid}]")
    Osumiex.Mqtt.Session.start_keepalive self(), session_pid

    conn_ack = Osumiex.Mqtt.Message.conn_ack()
    response_data = conn_ack |> Osumiex.Mqtt.Encoder.encode
    transport.send(socket, response_data)
  end
  #
  # PingReq response
  #
  def do_response(socket, transport, %Osumiex.Mqtt.Message.PingReq{}) do
    ping_resp = Osumiex.Mqtt.Message.ping_resp()
    x = :inet.getstat(socket, [:recv_oct])
    Logger.info inspect(x)
    response_data = ping_resp |> Osumiex.Mqtt.Encoder.encode
    transport.send(socket, response_data)
  end
  #
  # Subscribe
  #
  def do_response(socket, transport, %Osumiex.Mqtt.Message.Subscribe{} = message) do
    sub_ack = Osumiex.Mqtt.Message.sub_ack(message.message_id, message.topics)
    Logger.debug(inspect(self))
    Logger.debug(inspect(sub_ack))
    response_data = sub_ack |> Osumiex.Mqtt.Encoder.encode
    transport.send(socket, response_data)
  end
  def do_response(socket, transport, _message) do
    Logger.info("unknown message : #{inspect _message}")
  end

  #
  # Internal functions
  #
  def session_resume({:ok, session_pid}, socket, transport) do
    session_pid
  end
  def session_resume({:already_started, session_pid}, socket, transport) do
    Osumiex.Mqtt.Session.resume socket, transport, self(), session_pid
    session_pid
  end

end
