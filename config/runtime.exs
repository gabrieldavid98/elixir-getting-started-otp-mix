import Config

config :kv, :routing_table, [{?a..?z, node()}]

if config_env() == :prod do
  config :kv, :routing_table, [
    {?a..?m, :"foo@DESKTOP-K5N5NP1"},
    {?n..?z, :"bar@DESKTOP-K5N5NP1"},
  ]
end
