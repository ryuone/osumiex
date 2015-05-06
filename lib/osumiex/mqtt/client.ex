defmodule Osumiex.Mqtt.Client do
  use GenServer
  @behaviour :ranch_protocol

  @timeout 30

  require Logger
  import Record
  defrecord :client_state, socket: [], transport: [], session_pid: nil

  ##############################################################################
  # Gen Server(OTP) functions
  ##############################################################################

  def start_link(ref, socket, transport, opts) do
    :proc_lib.start_link(__MODULE__, :init, [ref, socket, transport, opts])
  end

  def init(ref, socket, transport, _opts) do
    :ok = :proc_lib.init_ack({:ok, self()})
    :ok = :ranch.accept_ack(ref)
    :ok = transport.setopts(socket, [{:active, :once}])
    status = client_state(socket: socket, transport: transport)
    :gen_server.enter_loop(__MODULE__, [], status, @timeout)
  end

  def handle_info({:tcp, socket, data}, client_state(socket: socket, transport: transport)=state) do
    :ok = transport.setopts(socket, [{:active, :once}])
    request_data = Osumiex.Mqtt.Decoder.decode(data)
    :ok = Logger.info("******************************************************")
    :ok = Logger.info("******** Decoded      : [#{inspect request_data}]")
    :ok = Logger.info("******** Request type : [#{request_data.message_type}]")
    state = do_response(socket, transport, request_data, state)
    {:noreply, state}
  end
  def handle_info({:tcp_closed, socket}, client_state(socket: socket, transport: _transport)=state) do
    :ok = Logger.info('connection close')
    {:stop, :normal, state};
  end
  def handle_info({:dispatch, {_pid, %Osumiex.Mqtt.Message.Publish{qos: :fire_and_forget} = message}}, client_state(socket: socket, transport: transport)=state) do
    :ok = Logger.info("Client dispatch")
    response_data = message |> Osumiex.Mqtt.Encoder.encode
    transport.send(socket, response_data)
    {:noreply, state}
  end
  def handle_info(data, state) do
    :ok = Logger.info("Received unknown data : [#{inspect data}]")
    {:noreply, state}
  end

  def terminate(_reason, _state) do
     :ok
  end

  ##############################################################################
  # Internal Functions
  ##############################################################################

  ### Connect response ###
  def do_response(socket, transport, %Osumiex.Mqtt.Message.Connect{} = message, state) do
    session_pid = case Osumiex.Mqtt.SupSession.start_session(socket, transport, message) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:already_started, pid}
    end |> session_resume(socket, transport)

    Osumiex.Mqtt.Session.start_keepalive(self(), session_pid)

    conn_ack = Osumiex.Mqtt.Message.conn_ack()
    response_data = conn_ack |> Osumiex.Mqtt.Encoder.encode
    transport.send(socket, response_data)
    client_state(state, session_pid: session_pid)
  end
  ### PingReq response ###
  def do_response(socket, transport, %Osumiex.Mqtt.Message.PingReq{}, state) do
    ping_resp = Osumiex.Mqtt.Message.ping_resp()
    recved_oct = :inet.getstat(socket, [:recv_oct])
    :ok = Logger.info("Packer recv oct : #{inspect(recved_oct)}")
    response_data = ping_resp |> Osumiex.Mqtt.Encoder.encode
    transport.send(socket, response_data)
    state
  end
  ### Subscribe ###
  def do_response(socket, transport,
                  %Osumiex.Mqtt.Message.Subscribe{topics: topics, message_id: message_id},
                  client_state(session_pid: session_pid) = state) do
    :ok = Logger.debug "[Subscribe]****************************************"
    :ok = Logger.debug "* Topic       : #{inspect(topics)}"
    :ok = Logger.debug "* Session PID : #{inspect(session_pid)}"
    :ok = Osumiex.Mqtt.Session.subscribe(session_pid, topics)
    sub_ack = Osumiex.Mqtt.Message.sub_ack(message_id, topics)
    response_data = sub_ack |> Osumiex.Mqtt.Encoder.encode
    transport.send(socket, response_data)
    state
  end
  ### Publish ###
  def do_response(_socket, _transport, %Osumiex.Mqtt.Message.Publish{} = message, client_state() = state) do
    :ok = Logger.debug("* PublishMessage : #{inspect message}")
    publish(message, state)
    state
  end
  ### Not support ###
  def do_response(_socket, _transport, _message, state) do
    :ok = Logger.info("Not supported message : #{inspect _message}")
    state
  end

  ### Publish message via session process ###
  defp publish(%Osumiex.Mqtt.Message.Publish{qos: :fire_and_forget} = message, state) do
    session_pid = client_state(state, :session_pid)
    Osumiex.Mqtt.Session.publish(session_pid, {:fire_and_forget, message})
  end

  def session_resume({:ok, session_pid}, _socket, _transport) do
    session_pid
  end
  def session_resume({:already_started, session_pid}, socket, transport) do
    Osumiex.Mqtt.Session.resume socket, transport, self(), session_pid
    session_pid
  end
end
