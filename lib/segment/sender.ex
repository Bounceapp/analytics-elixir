defmodule Segment.Analytics.Sender do
  @moduledoc """
    The `Segment.Analytics.Sender` service implementation is an alternative to the default Batcher to send every event as it is called.
    The HTTP call is made with an async `Task` to not block the GenServer. This will not guarantee ordering.

    The `Segment.Analytics.Batcher` should be preferred in production but this module will emulate the implementation of the original library if
    you need that or need events to be as real-time as possible.
  """
  use GenServer
  alias Segment.Analytics.{Track, Identify, Screen, Alias, Group, Page}

  @doc """
    Start the `Segment.Analytics.Sender` GenServer with an Segment HTTP Source API Write Key
  """
  @spec start_link(String.t()) :: GenServer.on_start()
  def start_link(args) do
    clients =
      case args do
        api_key when is_bitstring(api_key) ->
          [default: Segment.Http.client(api_key)]

        args when is_list(args) ->
          Enum.map(args, fn {name, api_key} -> {name, Segment.Http.client(api_key)} end)
      end

    GenServer.start_link(__MODULE__, clients, name: __MODULE__)
  end

  @doc """
    Start the `Segment.Analytics.Sender` GenServer with an Segment HTTP Source API Write Key and a Tesla Adapter. This is mainly used
    for testing purposes to override the Adapter with a Mock.
  """
  @spec start_link(String.t(), Segment.Http.adapter()) :: GenServer.on_start()
  def start_link(args, adapter) do
    clients =
      case args do
        api_key when is_bitstring(api_key) ->
          [default: Segment.Http.client(api_key, adapter)]

        args when is_list(args) ->
          Enum.map(args, fn {name, api_key} -> {name, Segment.Http.client(api_key)} end)
      end

    GenServer.start_link(__MODULE__, clients, name: __MODULE__)
  end

  # client
  @doc """
    Make a call to Segment with an event. Should be of type `Track, Identify, Screen, Alias, Group or Page`.
    This event will be sent immediately and asynchronously
  """
  @spec call(Segment.segment_event()) :: :ok
  def call(%{__struct__: mod} = event, client_name \\ :default)
      when mod in [Track, Identify, Screen, Alias, Group, Page] do
    callp(event, client_name)
  end

  # GenServer Callbacks

  @impl true
  def init(client) do
    {:ok, client}
  end

  @impl true
  def handle_cast({:send, event, client_name}, clients) do
    Task.start_link(fn -> Segment.Http.send(clients[client_name], event) end)
    {:noreply, clients}
  end

  # Helpers
  defp callp(event, client_name) do
    GenServer.cast(__MODULE__, {:send, event, client_name})
  end
end
