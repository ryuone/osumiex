defmodule Osumiex do
  use Application

  @ranchAcceptors 5

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    port = Application.get_env(:osumiex, :port)

    :ranch.start_listener(:mqtt_client, @ranchAcceptors, :ranch_tcp,
                          [{:active, :once}, {:packet, :raw}, {:reuseaddr, true}, {:port, port}],
                          Osumiex.Mqtt.Client, [])

    children = [
      worker(Osumiex.Mqtt.PubSub, [], restart: :transient),
      supervisor(Osumiex.Mqtt.SupSession, [], restart: :transient)
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Osumiex.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
