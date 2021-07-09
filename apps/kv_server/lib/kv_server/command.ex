defmodule KVServer.Command do
  @type command_result :: {:ok, String.t()}
  @type lookup_result :: command_result() | {:error, :not_found}

  @doc ~S"""
  Parses the given `line` into command

  ## Examples
  
      iex> KVServer.Command.parse("CREATE shopping\r\n")
      {:ok, {:create, "shopping"}}

      iex> KVServer.Command.parse("CREATE  shopping  \r\n")
      {:ok, {:create, "shopping"}}

      iex> KVServer.Command.parse("PUT shopping milk 1\r\n")
      {:ok, {:put, "shopping", "milk", "1"}}

      iex> KVServer.Command.parse("GET shopping milk\r\n")
      {:ok, {:get, "shopping", "milk"}}

      iex> KVServer.Command.parse("DELETE shopping eggs\r\n")
      {:ok, {:delete, "shopping", "eggs"}}

  Unknown commands or commands with the wrong number of
  arguments return an error:

      iex> KVServer.Command.parse("UNKNOWN shopping eggs\r\n")
      {:error, :unknown_command}

      iex> KVServer.Command.parse("GET shopping\r\n")
      {:error, :unknown_command}
  """
  @spec parse(String.t()) :: {atom(), tuple() | atom()}
  def parse(line) do
    case String.split(line) do
      ["CREATE", bucket] -> {:ok, {:create, bucket}}
      ["PUT", bucket, key, value] -> {:ok, {:put, bucket, key, value}}
      ["GET", bucket, key] -> {:ok, {:get, bucket, key}}
      ["DELETE", bucket, key] -> {:ok, {:delete, bucket, key}}
      _ -> {:error, :unknown_command}
    end
  end

  @doc """
  Runs the given command
  """
  def run(command)

  @spec run({:create, String.t()}) :: command_result()
  def run({:create, bucket}) do
    case KV.Router.route(bucket, KV.Registry, :create, [KV.Registry, bucket]) do
      pid when is_pid(pid) -> {:ok, "OK\r\n"}
      _ -> {:error, "FAILED TO CREATE BUCKET"}
    end
  end

  @spec run({:get, String.t(), String.t()}) :: lookup_result()
  def run({:get, bucket, key}) do
    lookup(bucket, fn pid ->
      value = KV.Bucket.get(pid, key)
      {:ok, "#{value}\r\nOK\r\n"}
    end)
  end

  @spec run({:put, String.t(), String.t(), String.t()}) :: lookup_result()
  def run({:put, bucket, key, value}) do
    lookup(bucket, fn pid ->
      KV.Bucket.put(pid, key, value)
      {:ok, "OK\r\n"}
    end)
  end

  @spec run({:delete, String.t(), String.t()}) :: lookup_result()
  def run({:delete, bucket, key}) do
    lookup(bucket, fn pid ->
      KV.Bucket.delete(pid, key)
      {:ok, "OK\r\n"}
    end)
  end

  @spec lookup(String.t(), (pid() -> command_result())) :: lookup_result()
  def lookup(bucket, callback) do
    case KV.Router.route(bucket, KV.Registry, :lookup, [KV.Registry, bucket]) do
      {:ok, pid} -> callback.(pid)
      :error -> {:error, :not_found}
    end
  end
end
