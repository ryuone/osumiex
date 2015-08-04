defmodule Osumiex.Mixfile do
  use Mix.Project

  def project do
    [
      app: :osumiex,
      version: "0.0.1",
      elixir: "~> 1.1-dev",
      deps: deps,
      dialyzer: [
        plt_add_apps: [:mnesia],
        flags: [
            "-Wunmatched_returns","-Werror_handling","-Wrace_conditions",
            "-Wno_opaque"
            #"-Wunderspecs", "-Woverspecs"
        ]
      ]
    ]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger, :ranch, :mnesia],
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
      {:ranch, github: "ninenines/ranch", tag: "master"},
      {:earmark, "~> 0.1", only: :dev},
      {:ex_doc, "~> 0.7", only: :dev}
    ]
  end
end
