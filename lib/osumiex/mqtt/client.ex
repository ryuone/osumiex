defmodule Osumiex.Mqtt.Client do
  use GenServer

  require Logger

  @behaviour :ranch_protocol

  @timeout 30

  import Record
  defrecord :client_state, socket: [], transport: [], session_pid: nil

  def start_link(ref, socket, transport, opts) do
    :proc_lib.start_link(__MODULE__, :init, [ref, socket, transport, opts])
  end

  def init(ref, socket, transport, _opts) do
    :ok = :proc_lib.init_ack({:ok, self()})
    :ok = :ranch.accept_ack(ref)
    :ok = transport.setopts(socket, [{:active, :once}])

    s = client_state(socket: socket, transport: transport)

    :gen_server.enter_loop(__MODULE__, [], s, @timeout)
  end


  def handle_info({:tcp, socket, data}, client_state(socket: socket, transport: transport)=state) do
    :ok = transport.setopts(socket, [{:active, :once}])

    request_data = Osumiex.Mqtt.Decoder.decode(data)
    Logger.info("******************************************************")
    Logger.info("******** Request type : [#{request_data.message_type}]")

    state = do_response(socket, transport, request_data, state)

    {:noreply, state}
  end
  def handle_info({:tcp_closed, socket}, client_state(socket: socket, transport: _transport)=state) do
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
  def do_response(socket, transport, %Osumiex.Mqtt.Message.Connect{} = message, state) do
    session_pid = case Osumiex.Mqtt.SupSession.start_session(socket, transport, message) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:already_started, pid}
    end |> session_resume(socket, transport)
    Logger.info("SupSession start PID[#{inspect session_pid}]")
    Osumiex.Mqtt.Session.start_keepalive self(), session_pid

    conn_ack = Osumiex.Mqtt.Message.conn_ack()
    response_data = conn_ack |> Osumiex.Mqtt.Encoder.encode
    transport.send(socket, response_data)
    client_state(state, session_pid: session_pid)
  end
  #
  # PingReq response
  #
  def do_response(socket, transport, %Osumiex.Mqtt.Message.PingReq{}, state) do
    ping_resp = Osumiex.Mqtt.Message.ping_resp()
    recved_oct = :inet.getstat(socket, [:recv_oct])
    Logger.info("Packer recv oct : #{inspect(recved_oct)}")
    response_data = ping_resp |> Osumiex.Mqtt.Encoder.encode
    transport.send(socket, response_data)
    state
  end
  #
  # Subscribe
  #
  def do_response(socket, transport, %Osumiex.Mqtt.Message.Subscribe{topics: topics} = message, client_state(session_pid: session_pid) = state) do
    Logger.debug "[Subscribe]****************************************"
    Logger.debug "* Topic       : #{inspect(topics)}"
    Logger.debug "* Session PID : #{inspect(session_pid)}"

    :ok = Osumiex.Mqtt.Session.subscribe(session_pid, topics)

    sub_ack = Osumiex.Mqtt.Message.sub_ack(message.message_id, topics)
    # Logger.debug("Self    : #{inspect(self)}")
    # Logger.debug("SubAck  : #{inspect(sub_ack)}")
    # Logger.debug("Message : #{inspect(message)}")
    response_data = sub_ack |> Osumiex.Mqtt.Encoder.encode
    # Logger.debug("Message : #{inspect(response_data)}")
    transport.send(socket, response_data)
    state
  end

  #
  # Unknown
  #
  def do_response(_socket, _transport, _message, state) do
    Logger.info("unknown message : #{inspect _message}")
    state
  end

  #
  # Internal functions
  #
  def session_resume({:ok, session_pid}, _socket, _transport) do
    session_pid
  end
  def session_resume({:already_started, session_pid}, socket, transport) do
    Osumiex.Mqtt.Session.resume socket, transport, self(), session_pid
    session_pid
  end

end
