defmodule Osumiex.Mqtt.Session do
  use GenServer
  require Logger
  require Utils
  require Osumiex.Mqtt.Topic

  @expires 5

  defstruct socket: nil,
    transport: nil,
    client_id: nil,
    client_pid: nil,
    subscribes: Map.new(),
    expires: 0,
    await_rel: Map.new(),
    keep_alive: :infinity,
    expire_timer: nil,
    will_message: nil
  @type t :: %__MODULE__{}

  ##############################################################################
  # Gen Server(OTP) functions
  ##############################################################################

  def start_link(socket, transport, client_pid, %Osumiex.Mqtt.Message.Connect{client_id: client_id} = connect) do
    :ok = Logger.debug(Utils.current_module_function <> " called. client_id :[#{client_id}]")
    GenServer.start_link(__MODULE__, [socket, transport, client_pid, connect], name: {:global, client_id})
  end

  def init([socket, transport, client_pid, connect]) do
    :ok = Logger.debug "#{__MODULE__} : Session.init called [#{inspect client_pid}, #{inspect self()}]"
    Process.flag(:trap_exit, true)
    true = Process.link(client_pid)

    will_message = case connect.will_flag do
      1 -> Osumiex.Mqtt.Message.create_will_message(connect.will_topic, connect.will_qos, connect.will_retain, connect.will_message)
      _ -> nil
    end

    session = %Osumiex.Mqtt.Session{
      socket: socket,
      transport: transport,
      client_id: connect.client_id,
      client_pid: client_pid,
      keep_alive: connect.keep_alive,
      will_message: will_message,
      expires: @expires
    }

    {:ok, session}
  end

  def handle_cast({:pub_rel, packet_id}, state) do
    %Osumiex.Mqtt.Session{await_rel: await_rel} = state
    {message} = await_rel |> Map.get(packet_id) 
    Osumiex.Mqtt.PubSub.publish(message)
    {:noreply, state}
  end

  def handle_cast(msg, s) do
    :ok = Logger.error "#{__MODULE__} : Not supported session.handle_cast called #{inspect msg}"
    {:noreply, s}
  end

  def handle_call({:keepalive, :start, _client_pid}, from, s) do
    :ok = Logger.debug "#{__MODULE__} : Session.handle_call :keepalive start #{inspect from} / KeepAlive=#{inspect s.keep_alive}"
    {:ok, [recv_oct: size]} = :inet.getstat(s.socket, [:recv_oct])
    :ok = Logger.debug "#{__MODULE__} : recv_oct : #{size}"
    Osumiex.Mqtt.KeepAlive.new()
    {:reply, :ok, s}
  end
  def handle_call({:resume, _socket, _transport, _client_pid}, _from, %Osumiex.Mqtt.Session{expire_timer: nil} = state) do
    {:reply, :ok, state}
  end
  def handle_call({:resume, socket, transport, client_pid}, _from, %Osumiex.Mqtt.Session{expire_timer: expire_timer} = state) do
    _time = :erlang.cancel_timer(expire_timer)
    true = Process.link(client_pid)
    {:reply, :ok, %{state | socket: socket, transport: transport, client_pid: client_pid, expire_timer: nil}}
  end
  def handle_call({:subscribe, topics}, _from, state) do
    {:ok, new_state} = subscribe(state, topics)
    {:reply, :ok, new_state};
  end
  def handle_call({:publish, %Osumiex.Mqtt.Message.Publish{packet_id: packet_id, qos: qos} = message}, _from, state) when qos == :qos_2 do
    %Osumiex.Mqtt.Session{await_rel: await_rel} = state
    Logger.debug("#{__MODULE__} : await_rel : #{inspect(await_rel)}")
    # TODO: Remove this message when PUBREL received.
    await_rel = await_rel |> Map.put(packet_id, {message})
    {:reply, :ok, %{state | await_rel: await_rel}};
  end
  def handle_call(:clean_will_message, _from, state) do
    ### TODO: Change MqttMessage to Publish Message
    :ok = Logger.debug "#{__MODULE__} : Clean will message {#{inspect state.will_message}}."
    {:reply, :ok, %{state | will_message: nil}}
  end
  def handle_call(:send_will_message, _from, %Osumiex.Mqtt.Session{will_message: will_message} = state) do
    Logger.debug("#{__MODULE__} : *******************************************")
    Logger.debug("#{__MODULE__} : Send will message [#{inspect will_message}]")
    publish_msg = Osumiex.Mqtt.Message.convert_mqtt_msg_to_publish_msg(will_message)
    Logger.debug("#{__MODULE__} : Publish Message [#{inspect publish_msg}]")
    Osumiex.Mqtt.PubSub.publish(publish_msg)
    {:reply, :ok, state}
  end
  def handle_call(msg, _from, state) do
    :ok = Logger.info "#{__MODULE__} : Session.handle_call called #{inspect msg}"
    {:reply, :ok, state}
  end

  def handle_info({:EXIT, client_pid, _reason}=_data, state) do
    :ok = Logger.debug "#{__MODULE__} : Client exit #{inspect client_pid}"
    timer = Process.send_after(self(), :session_expired, state.expires * 1000)
    {:noreply, %{state | socket: nil, transport: nil, client_pid: nil, expire_timer: timer}};
  end
  def handle_info(:session_expired, %Osumiex.Mqtt.Session{client_id: client_id} = state) do
    :ok = Logger.info "#{__MODULE__} : Session expired #{inspect client_id}"
    {:stop, :normal, state};
  end
  def handle_info({:dispatch, {_from, %Osumiex.Mqtt.Message.Publish{qos: pub_qos}=message, sub_qos}}, s) do
    :ok = Logger.debug "#{__MODULE__} : Dispatched message :[#{inspect message}] / Subscribe_Qos : #{sub_qos} / Publish_Qos : #{pub_qos}"
    message = case is_downgrade(pub_qos, sub_qos) do
      true ->
        %{message | qos: sub_qos}
      false ->
        message
    end
    :ok = Logger.debug "#{__MODULE__} : Dispatched message :[#{inspect message}] / Subscribe_Qos : #{sub_qos} / Publish_Qos : #{pub_qos}"
    {:noreply, dispatch(message, s)}
  end
  def handle_info(msg, s) do
    :ok = Logger.debug "#{__MODULE__} : Session.handle_info called unknown[#{inspect msg}]"
    {:noreply, s}
  end


  ##############################################################################
  # APIs
  ##############################################################################

  defp is_downgrade(pub_qos, sub_qos) do
    qos_pub = Osumiex.Mqtt.Encoder.mqtt_qos_to_binary(pub_qos)
    qos_sub = Osumiex.Mqtt.Encoder.mqtt_qos_to_binary(sub_qos)
    Logger.debug("#{__MODULE__} : qos_pub:qos_sub -> #{qos_pub}:#{qos_sub}");
    qos_pub > qos_sub
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

  def clean_will_message(session_pid) do
    GenServer.call session_pid, :clean_will_message
  end

  @doc """
  Subscribe
  """
  def subscribe(%Osumiex.Mqtt.Session{subscribes: subscribes} = state, [{_topic, _qos}|_]=topics) do
    subscribes = List.foldl(topics, subscribes, fn({topic, qos}, acc) ->
      Map.put acc, topic, qos
    end)
    :ok = Osumiex.Mqtt.PubSub.subscribe(topics)
    {:ok, %{state | subscribes: subscribes}};
  end
  def subscribe(session_pid, topics) do
    :ok = Logger.info("#{__MODULE__} : Session subscribe called #{inspect topics}")
    :ok = GenServer.call(session_pid, {:subscribe, topics})
    :ok
  end

  def send_will_message(session_pid) do
    Logger.debug("#{__MODULE__} : send_will_message");
    GenServer.call session_pid, :send_will_message
  end

  @doc """
  Publish
  """
  def publish(_session_pid, %Osumiex.Mqtt.Message.Publish{qos: :qos_0} = message) do
    Osumiex.Mqtt.PubSub.publish(message)
    :ok
  end
  def publish(_session_pid, %Osumiex.Mqtt.Message.Publish{qos: :qos_1} = message) do
    Logger.debug("#{__MODULE__} : QoS1 : publish [#{inspect message}]");
    Osumiex.Mqtt.PubSub.publish(message)
    :ok
  end
  def publish(session_pid, %Osumiex.Mqtt.Message.Publish{qos: :qos_2} = message) do
    Logger.debug("#{__MODULE__} : QoS2 : publish [#{inspect message}]");
    GenServer.call session_pid, {:publish, message}
    :ok
  end
  def publish(_session_pid, _), do: :ok

  @doc """
  Dispatch message(send message) to client process.

  when client_id is not set, client does not exist.
  So store a message to send message when client online.
  """
  def dispatch(_message, %Osumiex.Mqtt.Session{client_id: nil} = state) do
    :ok = Logger.debug("#{__MODULE__} : Have to queue messages")
    state
  end
  def dispatch(
          %Osumiex.Mqtt.Message.Publish{qos: :qos_0} = message,
          %Osumiex.Mqtt.Session{client_pid: client_pid} = state
    ) do
    send client_pid, {:dispatch, {self(), message}}
    state
  end

  def dispatch(
          %Osumiex.Mqtt.Message.Publish{qos: :qos_1} = message,
          %Osumiex.Mqtt.Session{client_pid: client_pid} = state
    ) do
    send client_pid, {:dispatch, {self(), message}}
    state
  end
  def dispatch(
          %Osumiex.Mqtt.Message.Publish{qos: :qos_2} = message,
          %Osumiex.Mqtt.Session{client_pid: client_pid} = state
    ) do
    send client_pid, {:dispatch, {self(), message}}
    state
  end
end
