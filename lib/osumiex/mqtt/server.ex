defmodule Osumiex.Mqtt.Server do
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
    Logger.info("Request type : #{request_data.message_type}")

    do_response(socket, transport, request_data)

    {:noreply, state}
  end
  def handle_info({:tcp_closed, socket}, state=state(socket: socket, transport: transport)) do
    Logger.info('connection close')
    {:stop, :normal, State};
  end

  def terminate(_reason, _state) do
     :ok
  end

  ##
  ## Internal Functions
  ##

  # Connect response
  def do_response(socket, transport, %Osumiex.Mqtt.Message.Connect{} = message) do
    conn_ack = Osumiex.Mqtt.Message.conn_ack()
    response_data = conn_ack |> Osumiex.Mqtt.Encoder.encode
    transport.send(socket, response_data)
  end
  # PingReq response
  def do_response(socket, transport, %Osumiex.Mqtt.Message.PingReq{}) do
    ping_resp = Osumiex.Mqtt.Message.ping_resp()
    response_data = ping_resp |> Osumiex.Mqtt.Encoder.encode
    transport.send(socket, response_data)
  end
  def do_response(socket, transport, _message) do
    Logger.info("unknown message : #{inspect _message}")
  end

end
