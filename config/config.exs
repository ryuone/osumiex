# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for third-
# party users, it should be done in your mix.exs file.

# Sample configuration:
#
#     config :logger,
#       level: :info
#
#     config :logger, :console,
#       format: "$date $time [$level] $metadata$message\n",
#       metadata: [:user_id]

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env}.exs"

config :osumiex,
  port: 3000,
  http_port: 8080

config :logger,
  level: :info,
  backends: [{LoggerFileBackend, :log_info},
             {LoggerFileBackend, :log_error},
             {LoggerFileBackend, :log_debug},
             :console],
  handle_otp_reports: true,
  handle_sasl_reports: true,
  format: "$date $time [$level] $metadata$message\n"

config :logger, :console,
  level: :debug,
  colors: [info: :magenta],
  format: "[console] $date $time $metadata[$level] $levelpad$message\n",
  metadata: [:module, :function],
  truncate: :infinity,
  compile_time_purge_level: :debug

config :logger, :log_info,
  path: "./log/info.log",
  metadata: [:module, :pid],
  format: "$dateT$time $node $metadata[$level] $levelpad$message\n",
  level: :info

config :logger, :log_debug,
  path: "./log/debug.log",
  metadata: [:pid, :application, :module, :file, :function, :line],
  format: "$dateT$time $node $metadata[$level] $levelpad$message\n",
  level: :debug

config :logger, :log_error,
  path: "./log/error.log",
  metadata: [:pid, :application, :module, :file, :line],
  format: "$dateT$time $node $metadata[$level] $levelpad$message\n",
  level: :error
