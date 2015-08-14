defmodule Osumiex.Mqtt.Session do
  use GenServer
  require Logger
  require Osumiex.Mqtt.Topic

  @expires 5

  ##############################################################################
  # Gen Server(OTP) functions
  ##############################################################################

  def start_link(socket, transport, client_pid, %Osumiex.Mqtt.Message.Connect{client_id: client_id} = connect) do
    :ok = Logger.info "Session.start_link called [#{inspect self()}]"
    GenServer.start_link(__MODULE__, [socket, transport, client_pid, connect], name: {:global, client_id})
  end

  def init([socket, transport, client_pid, connect]) do
    :ok = Logger.info "Session.init called [#{inspect client_pid}, #{inspect self()}]"
    Process.flag(:trap_exit, true)
    true = Process.link(client_pid)
    session = Osumiex.Mqtt.Message.session(
                socket,
                transport,
                connect.client_id,
                client_pid,
                connect.keep_alive,
                @expires
              )
    {:ok, session}
  end

  def handle_cast({:pub_rel, packet_id}, state) do
    %Osumiex.Mqtt.Message.Session{await_rel: await_rel} = state
    {message} = await_rel |> Map.get(packet_id) 
    Osumiex.Mqtt.PubSub.publish(message)
    {:noreply, state}
  end

  def handle_cast(msg, s) do
    :ok = Logger.info "Not supported session.handle_cast called #{inspect msg}"
    {:noreply, s}
  end

  def handle_call({:keepalive, :start, _client_pid}, from, s) do
    :ok = Logger.info "Session.handle_call :keepalive :start #{inspect from}"
    :ok = Logger.info "Session.handle_call :keepalive :start KeepAlive=#{inspect s.keep_alive}"
    :ok = Logger.info inspect(s.transport)
    x = :inet.getstat(s.socket, [:recv_oct])
    :ok = Logger.info inspect(x)
    Osumiex.Mqtt.KeepAlive.new()
    {:reply, :ok, s}
  end
  def handle_call({:resume, _socket, _transport, _client_pid}, _from, %Osumiex.Mqtt.Message.Session{expire_timer: nil} = state) do
    {:reply, :ok, state}
  end
  def handle_call({:resume, socket, transport, client_pid}, _from, %Osumiex.Mqtt.Message.Session{expire_timer: expire_timer} = state) do
    _time = :erlang.cancel_timer(expire_timer)
    true = Process.link(client_pid)
    {:reply, :ok, %{state | socket: socket, transport: transport, client_pid: client_pid, expire_timer: nil}}
  end
  def handle_call({:subscribe, topics}, _from, state) do
    {:ok, new_state} = subscribe(state, topics)
    {:reply, :ok, new_state};
  end
  def handle_call({:publish, %Osumiex.Mqtt.Message.Publish{packet_id: packet_id, qos: qos} = message}, _from, state) when qos == :qos_2 do
    %Osumiex.Mqtt.Message.Session{await_rel: await_rel} = state
    # TODO: Remove this message when PUBREL received.
    await_rel = await_rel |> Map.put(packet_id, {message})
    {:reply, :ok, %{state | await_rel: await_rel}};
  end
  def handle_call(msg, _from, state) do
    :ok = Logger.info "Session.handle_call called #{inspect msg}"
    {:reply, :ok, state}
  end

  def handle_info({:EXIT, client_pid, _reason}=_data, state) do
    :ok = Logger.debug "Client exit #{inspect client_pid}"
    timer = Process.send_after(self(), :session_expired, state.expires * 1000)
    {:noreply, %{state | socket: nil, transport: nil, client_pid: nil, expire_timer: timer}};
  end
  def handle_info(:session_expired, %Osumiex.Mqtt.Message.Session{client_id: client_id} = state) do
    :ok = Logger.info "Session expired #{inspect client_id}"
    {:stop, :normal, state};
  end
  def handle_info({:dispatch, {_from, %Osumiex.Mqtt.Message.Publish{qos: pub_qos}=message, sub_qos}}, s) do
    :ok = Logger.debug "Dispatched message :[#{inspect message}] / Subscribe_Qos : #{sub_qos} / Publish_Qos : #{pub_qos}"
    message = case is_downgrade(pub_qos, sub_qos) do
      true ->
        %{message | qos: sub_qos}
      false ->
        message
    end
    :ok = Logger.debug "Dispatched message :[#{inspect message}] / Subscribe_Qos : #{sub_qos} / Publish_Qos : #{pub_qos}"
    {:noreply, dispatch(message, s)}
  end
  def handle_info(msg, s) do
    :ok = Logger.debug "Session.handle_info called unknown[#{inspect msg}]"
    {:noreply, s}
  end


  ##############################################################################
  # APIs
  ##############################################################################

  defp is_downgrade(pub_qos, sub_qos) do
    qos1 = Osumiex.Mqtt.Encoder.mqtt_qos_to_binary(pub_qos)
    qos2 = Osumiex.Mqtt.Encoder.mqtt_qos_to_binary(sub_qos)
    Logger.debug("qos1:qos2 -> #{qos1}:#{qos2}");
    qos1 > qos2
  end

  @doc """
  Session functions
  """
  @spec start_keepalive(pid, pid) :: term
  def start_keepalive(client_pid, session_pid) do
    GenServer.call session_pid, {:keepalive, :start, client_pid}
  end

  def resume(socket, transport, client_pid, session_pid) do
    GenServer.call session_pid, {:resume, socket, transport, client_pid}
  end

  @doc """
  Subscribe
  """
  def subscribe(%Osumiex.Mqtt.Message.Session{subscribes: subscribes} = state, [{_topic, _qos}|_]=topics) do
    subscribes = List.foldl(topics, subscribes, fn({topic, qos}, acc) ->
      Map.put acc, topic, qos
    end)
    :ok = Osumiex.Mqtt.PubSub.subscribe(topics)
    {:ok, %{state | subscribes: subscribes}};
  end
  def subscribe(session_pid, topics) do
    :ok = Logger.info("Session subscribe called #{inspect topics}")
    :ok = GenServer.call(session_pid, {:subscribe, topics})
    :ok
  end

  @doc """
  Publish
  """
  def publish(_session_pid, {:qos_0, %Osumiex.Mqtt.Message.Publish{} = message}) do
    Osumiex.Mqtt.PubSub.publish(message)
    :ok
  end
  def publish(_session_pid, {:qos_1, %Osumiex.Mqtt.Message.Publish{} = message}) do
    Logger.debug("QoS1 : publish [#{inspect message}]");
    Osumiex.Mqtt.PubSub.publish(message)
    :ok
  end
  def publish(session_pid, {:qos_2, %Osumiex.Mqtt.Message.Publish{} = message}) do
    Logger.debug("QoS2 : publish [#{inspect message}]");
    GenServer.call session_pid, {:publish, message}
    #    Osumiex.Mqtt.PubSub.publish(message)
    :ok
  end

  @doc """
  Dispatch message(send message) to client process.

  when client_id is not set, client does not exist.
  So store a message to send message when client online.
  """
  def dispatch(_message, %Osumiex.Mqtt.Message.Session{client_id: nil} = state) do
    :ok = Logger.debug("Have to queue messages")
    state
  end
  def dispatch(
          %Osumiex.Mqtt.Message.Publish{qos: :qos_0} = message,
          %Osumiex.Mqtt.Message.Session{client_pid: client_pid} = state
    ) do
    send client_pid, {:dispatch, {self(), message}}
    state
  end

  def dispatch(
          %Osumiex.Mqtt.Message.Publish{qos: :qos_1} = message,
          %Osumiex.Mqtt.Message.Session{client_pid: client_pid} = state
    ) do
    send client_pid, {:dispatch, {self(), message}}
    state
  end
  def dispatch(
          %Osumiex.Mqtt.Message.Publish{qos: :qos_2} = message,
          %Osumiex.Mqtt.Message.Session{client_pid: client_pid} = state
    ) do
    send client_pid, {:dispatch, {self(), message}}
    state
  end
end
