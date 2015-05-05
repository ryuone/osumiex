defmodule Osumiex.Mqtt.Session do
  use GenServer
  require Logger
  require Osumiex.Mqtt.Topic

  @expires 5

  ##############################################################################
  # Gen Server(OTP) functions
  ##############################################################################

  def start_link(socket, transport, client_pid, %Osumiex.Mqtt.Message.Connect{} = connect) do
    Logger.info "Session.start_link called [#{inspect self()}]"
    GenServer.start_link(__MODULE__, [socket, transport, client_pid, connect], name: {:global, connect.client_id})
  end

  def init([socket, transport, client_pid, connect]) do
    Logger.info "Session.init called [#{inspect client_pid}, #{inspect self()}]"
    Process.flag(:trap_exit, true)
    true = Process.link(client_pid)
    {:ok, Osumiex.Mqtt.Message.session(socket, transport, connect.client_id, client_pid, connect.keep_alive, @expires)}
  end

  def handle_cast(msg, s) do
    Logger.info "Session.handle_cast called #{inspect msg}"
    {:noreply, s}
  end

  def handle_call({:keepalive, :start, _client_pid}, _from, s) do
    Logger.info "Session.handle_call :keepalive :start #{inspect _from}"
    Logger.info "Session.handle_call :keepalive :start KeepAlive=#{inspect s.keep_alive}"
    Logger.info inspect(s.transport)
    x = :inet.getstat(s.socket, [:recv_oct])
    Logger.info inspect(x)
    Osumiex.Mqtt.KeepAlive.new()
    {:reply, :ok, s}
  end
  def handle_call({:resume, socket, transport, client_pid}, _from, state) do
    :erlang.cancel_timer(state.expire_timer)
    true = Process.link(client_pid)
    {:reply, :ok, %{state | socket: socket, transport: transport, client_pid: client_pid, expire_timer: nil}}
  end
  def handle_call({:subscribe, topics}, _from, state) do
    {:ok, new_state} = subscribe(state, topics)
    {:reply, :ok, new_state};
  end
  def handle_call(msg, _from, state) do
    Logger.info "Session.handle_call called #{inspect msg}"
    {:reply, :ok, state}
  end

  def handle_info({:EXIT, client_pid, _reason}=_data, state) do
    Logger.debug "Client exit #{inspect client_pid}"
    timer = Process.send_after(self(), :session_expired, state.expires * 1000)
    {:noreply, %{state | socket: nil, transport: nil, client_pid: nil, expire_timer: timer}};
  end
  def handle_info(:session_expired, %Osumiex.Mqtt.Message.Session{client_id: client_id} = state) do
    Logger.info "Session expired #{inspect client_id}"
    {:stop, :normal, state};
  end
  def handle_info({:dispatch, {_from, %Osumiex.Mqtt.Message.Publish{}=message}}, s) do
    Logger.debug "Dispatched message :[#{inspect message}]"
    {:noreply, dispatch(message, s)}
  end
  def handle_info(msg, s) do
    Logger.debug "Session.handle_info called unknown[#{inspect msg}]"
    {:noreply, s}
  end


  ##############################################################################
  # APIs
  ##############################################################################

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
    Logger.info("Session subscribe called #{inspect topics}")
    :ok = GenServer.call(session_pid, {:subscribe, topics})
    :ok
  end

  @doc """
  Publish
  """
  def publish(_session_pid, {:fire_and_forget, %Osumiex.Mqtt.Message.Publish{} = message}) do
    Osumiex.Mqtt.PubSub.publish(message)
    :ok
  end

  @doc """
  Dispatch message(send message) to client process.

  when client_id is not set, client does not exist.
  So store a message to send message when client online.
  """
  def dispatch(_message, %Osumiex.Mqtt.Message.Session{client_id: nil} = state) do
    Logger.debug("Have to queue messages")
    state
  end
  def dispatch(
          %Osumiex.Mqtt.Message.Publish{qos: :fire_and_forget} = message,
          %Osumiex.Mqtt.Message.Session{client_pid: client_pid} = state
    ) do
    send client_pid, {:dispatch, {self(), message}}
    state
  end
end
