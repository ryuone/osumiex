defmodule Osumiex.Mixfile do
  use Mix.Project

  def project do
    [
      app: :osumiex,
      version: "0.0.1",
      elixir: "~> 1.2-dev",
      deps: deps,
      dialyzer: [
        plt_add_apps: [:mnesia],
        flags: [
            "-Wunmatched_returns","-Werror_handling","-Wrace_conditions",
            "-Wno_opaque",
            "-Wunderspecs", "-Woverspecs"
        ]
      ]
    ]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger, :crypto, :ranch, :cowboy, :mnesia, :gproc],
     mod: {Osumiex, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [
      {:cowboy, "~> 1.0.4"},
      {:gproc, "~> 0.5.0"},
      {:earmark, "~> 0.2.1", only: :dev},
      {:ex_doc, "~> 0.11.4", only: :dev}
    ]
  end
end
