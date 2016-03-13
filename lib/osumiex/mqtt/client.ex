defmodule Osumiex.Mqtt.Client do
  require Logger
  require Utils
  use GenServer
  @behaviour :ranch_protocol

  @timeout 30

  import Record
  defrecord :client_state, session_pid: nil, recv_length: 2, socket: nil, transport: nil

  ##############################################################################
  # Gen Server(OTP) functions
  ##############################################################################

  def start_link(ref, socket, transport, opts) do
    res = :proc_lib.start_link(__MODULE__, :init, [ref, socket, transport, opts])
    :ok = Logger.debug("start_link inside : " <> inspect(res))
    res
  end

  def init(ref, socket, transport, _opts) do
    :ok = Logger.info(Utils.current_module_function <> " called.")
    :ok = :proc_lib.init_ack({:ok, self()})
    :ok = :ranch.accept_ack(ref)
    :ok = transport.setopts(socket, [{:active, :once}])
    status = client_state(socket: socket, transport: transport)
    :gen_server.enter_loop(__MODULE__, [], status, @timeout)
  end

  def handle_info({:tcp, socket, data}, client_state(socket: socket, transport: transport)=state) do
    :ok = transport.setopts(socket, [{:active, :once}])
    decoded = Osumiex.Mqtt.Decoder.decode(data)
    :ok = Logger.info("#{__MODULE__} : Message received [#{inspect decoded.fixed_header.type}]")
    state = do_response(socket, transport, decoded, state)
    {:noreply, state}
  end
  def handle_info({:tcp_closed, socket}, client_state(socket: socket, transport: _transport)=state) do
    :ok = Logger.debug('#{__MODULE__} : TCP connection closed.')
    {:stop, :normal, state};
  end
  def handle_info({:dispatch, {_pid, %Osumiex.Mqtt.Message.Publish{qos: :qos_0} = message}}, client_state(socket: socket, transport: transport)=state) do
    :ok = Logger.debug("#{__MODULE__} : Client dispatch(QoS0)")
    response_data = message |> Osumiex.Mqtt.Encoder.encode
    transport.send(socket, response_data)
    {:noreply, state}
  end
  def handle_info({:dispatch, {_pid, %Osumiex.Mqtt.Message.Publish{qos: :qos_1} = message}}, client_state(socket: socket, transport: transport)=state) do
    :ok = Logger.debug("#{__MODULE__} Client dispatch(QoS1)")
    response_data = message |> Osumiex.Mqtt.Encoder.encode
    transport.send(socket, response_data)
    # TODO: await for PUBACK.
    {:noreply, state}
  end
  def handle_info({:dispatch, {_pid, %Osumiex.Mqtt.Message.Publish{qos: :qos_2} = message}}, client_state(socket: socket, transport: transport)=state) do
    :ok = Logger.debug("#{__MODULE__} Client dispatch(QoS2)")
    response_data = message |> Osumiex.Mqtt.Encoder.encode
    transport.send(socket, response_data)
    # TODO: await for PUBACK.
    {:noreply, state}
  end
  def handle_info(data, state) do
    :ok = Logger.error("#{__MODULE__} Received unknown data : [#{inspect data}]")
    {:noreply, state}
  end

  def terminate(reason, client_state(session_pid: session_pid) = state) do
    :ok = Logger.debug("#{__MODULE__} : terminate (#{inspect(reason)})")
    Osumiex.Mqtt.Session.send_will_message session_pid
    :ok
  end

  ##############################################################################
  # Internal Functions
  ##############################################################################

  ### 1. Connect ###
  defp do_response(socket, transport, %Osumiex.Mqtt.Message{variable: %Osumiex.Mqtt.Message.Connect{}} = message, state) do
    variable = message.variable

    session_pid = case Osumiex.Mqtt.SupSession.start_session(socket, transport, variable) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:already_started, pid}
    end |> session_resume(socket, transport)

    Osumiex.Mqtt.Session.start_keepalive(self(), session_pid)

    response_data = Osumiex.Mqtt.Message.conn_ack() |> Osumiex.Mqtt.Encoder.encode
    transport.send(socket, response_data)
    client_state(state, session_pid: session_pid)
  end

  ###
  ### 8. Subscribe ###
  ###
  defp do_response(socket, transport,
                  %Osumiex.Mqtt.Message{variable: %Osumiex.Mqtt.Message.Subscribe{}} = message,
                  client_state(session_pid: session_pid) = state) do

    topics    = message.variable.topics
    packet_id = message.variable.packet_id

    :ok = Logger.debug "#{__MODULE__} : [Subscribe]****************************************"
    :ok = Logger.debug "#{__MODULE__} : * Topic         : #{inspect(topics)}"
    :ok = Logger.debug "#{__MODULE__} : * Session PID   : #{inspect(session_pid)}"
    :ok = Osumiex.Mqtt.Session.subscribe(session_pid, topics)
    sub_ack = Osumiex.Mqtt.Message.sub_ack(packet_id, topics)
    :ok = Logger.debug "#{__MODULE__} : * sub_ack       : #{inspect(sub_ack)}"
    response_data = sub_ack |> Osumiex.Mqtt.Encoder.encode
    :ok = Logger.debug "#{__MODULE__} : * response_data : #{inspect(response_data)}"
    transport.send(socket, response_data)
    state
  end

  ###
  ### 3. Publish ###
  ###
  defp do_response(socket, transport,
                  %Osumiex.Mqtt.Message{variable: %Osumiex.Mqtt.Message.Publish{}} = message,
                  client_state() = state) do
    :ok = Logger.debug("#{__MODULE__} : * PublishMessage : #{inspect message.variable.message}")
    publish(socket, transport, message.variable, state)
    state
  end

  ###
  ### 4. PUBACK ###
  ###
  defp do_response(_socket, _transport,
                  %Osumiex.Mqtt.Message{variable: %Osumiex.Mqtt.Message.PubAck{packet_id: packet_id}},
                  state) do
    :ok = Logger.debug("#{__MODULE__} : PUBACK : packet_id[#{packet_id}]")
    state
  end

  ###
  ### 5. PUBREC ###
  ###
  defp do_response(socket, transport,
                  %Osumiex.Mqtt.Message{variable: %Osumiex.Mqtt.Message.PubRec{packet_id: packet_id}} = _message,
                  state) do
    session_pid   = client_state(state, :session_pid)
    pub_rel       = Osumiex.Mqtt.Message.pub_rel(packet_id)
    response_data = pub_rel |> Osumiex.Mqtt.Encoder.encode

    :ok = Logger.debug "#{__MODULE__} : * response_data : #{inspect(response_data)}"
    GenServer.cast session_pid, {:pub_rec, packet_id}

    transport.send(socket, response_data)
    state
  end

  ###
  ### 6. PUBREL ###
  ###
  defp do_response(socket, transport,
                  %Osumiex.Mqtt.Message{variable: %Osumiex.Mqtt.Message.PubRel{packet_id: packet_id}} = _message,
                  state) do
    session_pid   = client_state(state, :session_pid)
    pub_comp      = Osumiex.Mqtt.Message.pub_comp(packet_id)
    response_data = pub_comp |> Osumiex.Mqtt.Encoder.encode

    :ok = Logger.debug "#{__MODULE__} : * response_data : #{inspect(response_data)}"
    GenServer.cast session_pid, {:pub_rel, packet_id}

    transport.send(socket, response_data)
    state
  end

  ###
  ### 7. PUBCOMP ###
  ###
  defp do_response(_socket, _transport,
                  %Osumiex.Mqtt.Message{variable: %Osumiex.Mqtt.Message.PubComp{packet_id: packet_id}} = _message,
                  state) do
    session_pid = client_state(state, :session_pid)
    GenServer.cast session_pid, {:pub_comp, packet_id}
    state
  end

  ###
  ### 12. PingReq ###
  ###
  defp do_response(socket, transport, %Osumiex.Mqtt.Message{variable: %Osumiex.Mqtt.Message.PingReq{}}, state) do
    ping_resp = Osumiex.Mqtt.Message.ping_resp()
    recved_oct = :inet.getstat(socket, [:recv_oct])
    :ok = Logger.debug("#{__MODULE__} : Packet recv oct : #{inspect(recved_oct)}")
    response_data = ping_resp |> Osumiex.Mqtt.Encoder.encode
    transport.send(socket, response_data)
    state
  end

  ###
  ### 14. Disconnect ###
  ###
  defp do_response(_socket, _transport,
                  %Osumiex.Mqtt.Message{variable: %Osumiex.Mqtt.Message.Disconnect{}},
                  client_state(session_pid: session_pid) = state) do
    :ok = Logger.debug("#{__MODULE__} : Client disconnect.")
    Osumiex.Mqtt.Session.clean_will_message(session_pid)
    state
  end

  ### Not support ###
  defp do_response(_socket, _transport, message, state) do
    :ok = Logger.error("#{__MODULE__} : Not supported message [#{inspect message}]")
    state
  end

  ###########################################
  ### Publish message via session process ###
  ###########################################
  defp publish(_socket, _transport, %Osumiex.Mqtt.Message.Publish{qos: :qos_0} = message, state) do
    Logger.debug("#{__MODULE__} : Publish QOS0");
    session_pid = client_state(state, :session_pid)
    Osumiex.Mqtt.Session.publish(session_pid, message)
  end
  defp publish(socket, transport, %Osumiex.Mqtt.Message.Publish{qos: :qos_1} = message, state) do
    Logger.debug("#{__MODULE__} : Publish QOS1");
    session_pid = client_state(state, :session_pid)
    Osumiex.Mqtt.Session.publish(session_pid, message)

    pub_ack = Osumiex.Mqtt.Message.pub_ack(message.packet_id)
    response_data = pub_ack |> Osumiex.Mqtt.Encoder.encode
    Logger.debug("#{__MODULE__} : response_data : #{inspect response_data}")

    transport.send(socket, response_data)
  end
  defp publish(socket, transport, %Osumiex.Mqtt.Message.Publish{qos: :qos_2} = message, state) do
    Logger.debug("#{__MODULE__} : Publish QOS2");
    session_pid = client_state(state, :session_pid)
    Osumiex.Mqtt.Session.publish(session_pid, message)

    pub_rec = Osumiex.Mqtt.Message.pub_rec(message.packet_id)
    response_data = pub_rec |> Osumiex.Mqtt.Encoder.encode
    Logger.debug("#{__MODULE__} : response_data : #{inspect response_data}")

    transport.send(socket, response_data)
  end

  def session_resume({:ok, session_pid}, _socket, _transport) do
    session_pid
  end
  def session_resume({:already_started, session_pid}, socket, transport) do
    Osumiex.Mqtt.Session.resume socket, transport, self(), session_pid
    session_pid
  end
end
