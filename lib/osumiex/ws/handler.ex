defmodule Osumiex.Ws.Handler do
  require Logger

  def init({:tcp, :http}, _req, _opts) do
    :erlang.start_timer(1000, self(), "Hello!")
    :gproc.reg {:p, :l, :group}
    {:upgrade, :protocol, :cowboy_websocket}
  end

  def websocket_init(_transport_name, req, _opts) do
    Logger.info "websocket_init called..."
    { :ok, req, :no_state }
  end

  def websocket_handle({:text, msg}, req, state) do
    {:reply, {:text, "That's what she said!" <> msg}, req, state}
  end
  def websocket_handle(_data, req, state) do
    {:ok, req, state}
  end

  def websocket_info({:timeout, _ref, msg}, req, state) do
    :erlang.start_timer(1000, self(), "How' you doin'?")
    {:reply, {:text, msg}, req, state}
  end
  def websocket_info(_info, req, state) do
    {:ok, req, state}
  end

  def websocket_terminate(_reason, _req, _state), do: :ok
end
