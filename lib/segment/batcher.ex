defmodule Segment.Analytics.Batcher do
  @moduledoc """
    The `Segment.Analytics.Batcher` module is the default service implementation for the library which uses the
    [Segment Batch HTTP API](https://segment.com/docs/sources/server/http/#batch) to put events in a FIFO queue and
    send on a regular basis.

    The `Segment.Analytics.Batcher` can be configured with
    ```elixir
    config :segment,
      max_batch_size: 100,
      batch_every_ms: 5000
    ```
    * `config :segment, :max_batch_size` The maximum batch size of messages that will be sent to Segment at one time. Default value is 100.
    * `config :segment, :batch_every_ms` The time (in ms) between every batch request. Default value is 2000 (2 seconds)

    The Segment Batch API does have limits on the batch size "There is a maximum of 500KB per batch request and 32KB per call.". While
    the library doesn't check the size of the batch, if this becomes a problem you can change `max_batch_size` to a lower number and probably want
    to change `batch_every_ms` to run more frequently. The Segment API asks you to limit calls to under 50 a second, so even if you have no other
    Segment calls going on, don't go under 20ms!

  """
  use GenServer
  alias Segment.Analytics.{Track, Identify, Screen, Alias, Group, Page}

  @doc """
    Start the `Segment.Analytics.Batcher` GenServer with an Segment HTTP Source API Write Key
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

    queues = Enum.map(clients, fn {name, _} -> {name, :queue.new()} end)
    GenServer.start_link(__MODULE__, {clients, queues}, name: __MODULE__)
  end

  @doc """
    Start the `Segment.Analytics.Batcher` GenServer with an Segment HTTP Source API Write Key and a Tesla Adapter. This is mainly used
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

    queues = Enum.map(clients, fn {name, _} -> {name, :queue.new()} end)
    GenServer.start_link(__MODULE__, {clients, queues}, name: __MODULE__)
  end

  # client
  @doc """
    Make a call to Segment with an event. Should be of type `Track, Identify, Screen, Alias, Group or Page`.
    This event will be queued and sent later in a batch.
  """
  @spec call(Segment.segment_event()) :: :ok
  def call(%{__struct__: mod} = event, client_name \\ :default)
      when mod in [Track, Identify, Screen, Alias, Group, Page] do
    enqueue(event, client_name)
  end

  @doc """
    Force the batcher to flush the queue and send all the events as a big batch (warning could exceed batch size)
  """
  @spec flush() :: :ok
  def flush() do
    GenServer.call(__MODULE__, :flush)
  end

  # GenServer Callbacks

  @impl true
  def init({client, queue}) do
    schedule_batch_send()
    {:ok, {client, queue}}
  end

  @impl true
  def handle_cast({:enqueue, event, client_name}, {clients, queues}) do
    {:noreply, {clients, Keyword.put(queues, client_name, :queue.in(event, queues[client_name]))}}
  end

  @impl true
  def handle_call(:flush, _from, {clients, queues}) do
    # flush all queues
    Enum.each(clients, fn {name, client} ->
      {items, _queue} = extract_batch(queues[name], :queue.len(queues[name]))
      if length(items) > 0, do: Segment.Http.batch(client, items)
    end)

    {:reply, :ok, {clients, Enum.map(queues, fn {name, _} -> {name, :queue.new()} end)}}
  end

  @impl true
  def handle_info(:process_batch, {clients, queues}) do
    # process all queues and update queues variable
    queues =
      Enum.map(clients, fn {name, client} ->
        {items, queue} = extract_batch(queues[name], :queue.len(queues[name]))
        if length(items) > 0, do: Segment.Http.batch(client, items)
        {name, queue}
      end)

    schedule_batch_send()
    {:noreply, {clients, queues}}
  end

  def handle_info({:ssl_closed, _msg}, state), do: {:no_reply, state}

  # Helpers
  defp schedule_batch_send do
    Process.send_after(self(), :process_batch, Segment.Config.batch_every_ms())
  end

  defp enqueue(event, client_name) do
    GenServer.cast(__MODULE__, {:enqueue, event, client_name})
  end

  defp extract_batch(queue, 0),
    do: {[], queue}

  defp extract_batch(queue, length) do
    max_batch_size = Segment.Config.max_batch_size()

    if length >= max_batch_size do
      :queue.split(max_batch_size, queue)
      |> split_result()
    else
      :queue.split(length, queue) |> split_result()
    end
  end

  defp split_result({q1, q2}), do: {:queue.to_list(q1), q2}
end
