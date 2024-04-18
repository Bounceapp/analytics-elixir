defmodule Segment.Analytics do
  @moduledoc """
    The `Segment.Analytics` module is the easiest way to send Segment events and provides convenience methods for `track`, `identify,` `screen`, `alias`, `group`, and `page` calls

    The functions will then delegate the call to the configured service implementation which can be changed with:
    ```elixir
    config :segment, sender_impl: Segment.Analytics.Batcher,
    ```
    By default (if no configuration is given) it will use `Segment.Analytics.Batcher` to send events in a batch periodically
  """
  alias Segment.Analytics.{Track, Identify, Screen, Context, Alias, Group, Page}

  @type segment_id :: String.t() | integer()

  @doc """
    Make a call to Segment with an event. Should be of type `Track, Identify, Screen, Alias, Group or Page`
  """
  @spec send(atom(), Segment.segment_event()) :: :ok
  def send(source_name, %{__struct__: mod} = event)
      when mod in [Track, Identify, Screen, Alias, Group, Page] do
    call(event, source_name)
  end

  @doc """
    `track` lets you record the actions your users perform. Every action triggers what Segment call an “event”, which can also have associated properties as defined in the
    `Segment.Analytics.Track` struct

    See [https://segment.com/docs/spec/track/](https://segment.com/docs/spec/track/)
  """
  @spec track(atom(), Segment.Analytics.Track.t()) :: :ok
  def track(source_name, t = %Track{}) do
    call(t, source_name)
  end

  @doc """
    `track` lets you record the actions your users perform. Every action triggers what Segment call an “event”, which can also have associated properties. `track/4` takes a `user_id`, an
    `event_name`, optional additional `properties` and an optional `Segment.Analytics.Context` struct.

    See [https://segment.com/docs/spec/track/](https://segment.com/docs/spec/track/)
  """
  @spec track(atom(), segment_id(), String.t(), map(), Segment.Analytics.Context.t()) :: :ok
  def track(source_name, user_id, event_name, properties \\ %{}, context \\ Context.new()) do
    %Track{
      userId: user_id,
      event: event_name,
      properties: properties,
      context: context
    }
    |> call(source_name)
  end

  @doc """
    `identify` lets you tie a user to their actions and record traits about them as defined in the
    `Segment.Analytics.Identify` struct

    See [https://segment.com/docs/spec/identify/](https://segment.com/docs/spec/identify/)
  """
  @spec identify(atom(), Segment.Analytics.Identify.t()) :: :ok
  def identify(source_name, i = %Identify{}) do
    call(i, source_name)
  end

  @doc """
  `identify` lets you tie a user to their actions and record traits about them. `identify/3` takes a `user_id`, optional additional `traits` and an optional `Segment.Analytics.Context` struct.

  See [https://segment.com/docs/spec/identify/](https://segment.com/docs/spec/identify/)
  """
  @spec identify(atom(), segment_id(), map(), Segment.Analytics.Context.t()) :: :ok
  def identify(source_name, user_id, traits \\ %{}, context \\ Context.new()) do
    %Identify{userId: user_id, traits: traits, context: context}
    |> call(source_name)
  end

  @doc """
    `screen` let you record whenever a user sees a screen of your mobile app with properties defined in the
    `Segment.Analytics.Screen` struct

  See [https://segment.com/docs/spec/screen/](https://segment.com/docs/spec/screen/)
  """
  @spec screen(atom(), Segment.Analytics.Screen.t()) :: :ok
  def screen(source_name, s = %Screen{}) do
    call(s, source_name)
  end

  @doc """
  `screen` let you record whenever a user sees a screen of your mobile app. `screen/4` takes a `user_id`, an optional `screen_name`, optional `properties` and an optional `Segment.Analytics.Context` struct.

  See [https://segment.com/docs/spec/screen/](https://segment.com/docs/spec/screen/)
  """
  @spec screen(atom(), segment_id(), String.t(), map(), Segment.Analytics.Context.t()) :: :ok
  def screen(source_name, user_id, screen_name \\ "", properties \\ %{}, context \\ Context.new()) do
    %Screen{
      userId: user_id,
      name: screen_name,
      properties: properties,
      context: context
    }
    |> call(source_name)
  end

  @doc """
    `alias` is how you associate one identity with another with properties defined in the `Segment.Analytics.Alias` struct

  See [https://segment.com/docs/spec/alias/](https://segment.com/docs/spec/alias/)
  """
  @spec alias(atom(), Segment.Analytics.Alias.t()) :: :ok
  def alias(source_name, a = %Alias{}) do
    call(a, source_name)
  end

  @doc """
  `alias` is how you associate one identity with another. `alias/3` takes a `user_id` and a `previous_id` to map from. It also takes an optional `Segment.Analytics.Context` struct.

  See [https://segment.com/docs/spec/alias/](https://segment.com/docs/spec/alias/)
  """
  @spec alias(atom(), segment_id(), segment_id(), Segment.Analytics.Context.t()) :: :ok
  def alias(source_name, user_id, previous_id, context \\ Context.new()) do
    %Alias{userId: user_id, previousId: previous_id, context: context}
    |> call(source_name)
  end

  @doc """
  The `group` call is how you associate an individual user with a group with the properties in the defined in the `Segment.Analytics.Group` struct

  See [https://segment.com/docs/spec/group/](https://segment.com/docs/spec/group/)
  """
  @spec group(atom(), Segment.Analytics.Group.t()) :: :ok
  def group(source_name, g = %Group{}) do
    call(g, source_name)
  end

  @doc """
  The `group` call is how you associate an individual user with a group. `group/4` takes a `user_id` and a `group_id` to associate it with. It also takes optional `traits` of the group and
  an optional `Segment.Analytics.Context` struct.

  See [https://segment.com/docs/spec/group/](https://segment.com/docs/spec/group/)
  """
  @spec group(atom(), segment_id(), segment_id(), map(), Segment.Analytics.Context.t()) :: :ok
  def group(source_name, user_id, group_id, traits \\ %{}, context \\ Context.new()) do
    %Group{userId: user_id, groupId: group_id, traits: traits, context: context}
    |> call(source_name)
  end

  @doc """
  The `page` call lets you record whenever a user sees a page of your website with the properties defined in the `Segment.Analytics.Page` struct

  See [https://segment.com/docs/spec/page/](https://segment.com/docs/spec/page/)
  """
  @spec page(atom(), Segment.Analytics.Page.t()) :: :ok
  def page(source_name, p = %Page{}) do
    call(p, source_name)
  end

  @doc """
  The `page` call lets you record whenever a user sees a page of your website. `page/4` takes a `user_id` and an optional `page_name`, optional `properties` and an optional `Segment.Analytics.Context` struct.

  See [https://segment.com/docs/spec/page/](https://segment.com/docs/spec/page/)
  """
  @spec page(atom(), segment_id(), String.t(), map(), Segment.Analytics.Context.t()) :: :ok
  def page(source_name, user_id, page_name \\ "", properties \\ %{}, context \\ Context.new()) do
    %Page{userId: user_id, name: page_name, properties: properties, context: context}
    |> call(source_name)
  end

  @spec call(Segment.segment_event(), atom()) :: :ok
  def call(event, source_name) do
    Segment.Config.service().call(event, source_name)
  end
end
