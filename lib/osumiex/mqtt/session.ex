defmodule Osumiex.Mqtt.Session do
  use GenServer
  require Logger

  @expires 5

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

  #
  # OTP functions
  #
  def handle_cast(msg, s) do
    Logger.info "Session.handle_cast called #{inspect msg}"
    {:noreply, s}
  end

  def handle_call({:keepalive, :start, client_pid}, _from, s) do
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
  def handle_call(msg, _from, state) do
    Logger.info "Session.handle_call called #{inspect msg}"
    {:reply, :ok, state}
  end

  def handle_info({:EXIT, client_pid, reason}=data, state) do
    Logger.debug "Client exit #{inspect client_pid}"
    timer = Process.send_after(self(), :session_expired, state.expires * 1000)
    {:noreply, %{state | socket: nil, transport: nil, client_pid: nil, expire_timer: timer}};
  end
  def handle_info(:session_expired, %Osumiex.Mqtt.Message.Session{client_id: client_id} = state) do
    Logger.info "Session expired #{inspect client_id}"
    {:stop, :normal, state};
  end
  def handle_info(msg, s) do
    Logger.debug "Session.handle_info called unknown[#{inspect msg}]"
    {:noreply, s}
  end

  #
  # Session functions
  #
  def start_keepalive(client_pid, session_pid) do
    GenServer.call session_pid, {:keepalive, :start, client_pid}
  end
  def resume(socket, transport, client_pid, session_pid) do
    GenServer.call session_pid, {:resume, socket, transport, client_pid}
  end

end
