defmodule Osumiex.Mqtt.PubSub do
  use GenServer
  require Logger
  require Osumiex.Mqtt.Topic

  # ------------------------------------------------------------------
  # gen_server Function Definitions
  # ------------------------------------------------------------------
  def start_link() do
    Logger.info "PubSub.start_link called [#{inspect self()}]"
    GenServer.start_link(__MODULE__, [], name: {:local, :pub_sub})
  end

  def init([]) do
    Logger.info "PubSub.init called [#{inspect self()}]"
    Process.flag(:trap_exit, true)
    :mnesia.create_schema([node()])

    :mnesia.create_table(:topic_trie_node, [
        {:ram_copies, [node()]},
        {:attributes, Osumiex.Mqtt.Topic.topic_trie_node_fields}
      ])
    :mnesia.add_table_copy(:topic_trie_node, node(), :ram_copies)

    :mnesia.create_table(:topic_trie, [
      {:ram_copies, [node()]},
      {:attributes, Osumiex.Mqtt.Topic.topic_trie_fields}])
    :mnesia.add_table_copy(:topic_trie, node(), :ram_copies)

    :mnesia.create_table(:topic, [
      {:ram_copies, [node()]},
      {:attributes, Osumiex.Mqtt.Topic.topic_fields}])
    :mnesia.add_table_copy(:topic, node(), :ram_copies)
    :mnesia.subscribe({:table, :topic, :simple})

    :mnesia.create_table(:topic_subscriber, [
      {:type, :bag},
      {:ram_copies, [node()]},
      {:attributes, Osumiex.Mqtt.Topic.topic_subscriber_fields},
      {:index, [:subscriber_pid]},
      {:local_content, true}
    ])
    :mnesia.subscribe({:table, :topic_subscriber, :simple})

    {:ok, []}
  end

  def handle_info({:mnesia_table_event, {:write, Osumiex.Mqtt.Topic.topic_subscriber(subscriber_pid: subscriber_pid), _activity_id}}, state) do
    Logger.info("Mnesia Event : subsciber_pid -> #{inspect subscriber_pid}")
    true = Process.link(subscriber_pid)
    {:noreply, state}
  end
  def handle_info({:mnesia_table_event, _event}, state) do
    #Logger.info("Mnesia Event : #{inspect _event}")
    {:noreply, state}
  end
  def handle_info({:EXIT, subscriber_pid, reason}=data, state) do
    Logger.info("Subscriber is down : #{inspect subscriber_pid}")
    topic_subscribers = :mnesia.dirty_index_read(:topic_subscriber, subscriber_pid, 4)
    func = fn() ->
      for topic_subscriber <- topic_subscribers, do: :mnesia.delete_object(topic_subscriber)
    end
    case :mnesia.transaction(func) do
      {:atomic, _} -> :ok
      error -> {:error, error}
    end
    {:noreply, state}
  end
  def handle_info(data, state) do
    Logger.info("Unknown handle_info data : #{inspect data}")
    {:noreply, state}
  end


  def terminate(_Reason, _State) do
    :mnesia.unsubscribe({:table, :topic, :simple})
    :mnesia.unsubscribe({:table, :topic_subscriber, :simple})
    :ok
  end

  # ------------------------------------------------------------------
  # APIs
  # ------------------------------------------------------------------
  def match(topic) when is_binary(topic) do
    trie_nodes = :mnesia.async_dirty(&trie_match/1, [Osumiex.Mqtt.Topic.words(topic)])
    names = for trie_node=Osumiex.Mqtt.Topic.topic_trie_node(topic: name) <- trie_nodes, name != nil, do: name
    List.flatten(for name <- names, do: :mnesia.dirty_read(:topic, name))
  end

  def subscribe({topic, qos}) when is_binary(topic) do
    case subscribe([{topic, qos}]) do
      true -> :ok
    end
  end
  def subscribe([{_topic, _qos} | _] = topics) do
    subscribe(topics, self())
  end
  def subscribe([], subscriber_pid) do
    :ok
  end
  def subscribe([{topic, qos}|topics], subscriber_pid) do
    Logger.debug "****************************************"
    Logger.debug "* PubSub:subscribe [#{topic}] : [#{qos}]"
    Logger.debug "* Subscriber PID : #{inspect(subscriber_pid)}"
    Logger.debug "* Rest Topics    : #{inspect(topics)}"
    Logger.debug "* TopicName      : #{inspect(topic)}"

    subscriber = Osumiex.Mqtt.Topic.topic_subscriber(topic: topic, qos: qos, subscriber_pid: subscriber_pid)
    func = fn() ->
      trie_add(topic)
      :mnesia.write(subscriber)
    end
    case :mnesia.transaction(func) do
      {:atomic, :ok} -> subscribe(topics, subscriber_pid)
      error -> {:error, error}
    end
  end

  def publish(%Osumiex.Mqtt.Message.Publish{} = message) do
    func = fn(Osumiex.Mqtt.Topic.topic(name: topic, node: node), acc) ->
      case node == node() do
        true -> dispatch(topic, message) + acc
        false -> :ok # TODO: Implement RPC.
      end
    end
    List.foldl(match(message.topic), 0, func)
  end

  defp dispatch(topic, %Osumiex.Mqtt.Message.Publish{message: msg} = message) do
    subscribers = :mnesia.dirty_read(:topic_subscriber, topic)
    Logger.info("Subscribers : [#{inspect subscribers}]")
    subscribers |> Enum.each(fn(Osumiex.Mqtt.Topic.topic_subscriber(subscriber_pid: subscriber_pid)) ->
      Logger.info("Subscriber Pid : #{inspect subscriber_pid}")
      send subscriber_pid, {:dispatch, {self(), message}}
    end)
    length(subscribers)
  end

  # ------------------------------------------------------------------
  # Trie APIs
  # ------------------------------------------------------------------

  defp trie_add(topic) do
    Osumiex.Mqtt.Topic.topic(name: topic, node: node()) |> :mnesia.write

    case :mnesia.read(:topic_trie_node, topic) do
      [trie_node=Osumiex.Mqtt.Topic.topic_trie_node(topic: nil)] ->
        Logger.info("* 1)")
        :mnesia.write(Osumiex.Mqtt.Topic.topic_trie_node(trie_node, topic: topic))
      [Osumiex.Mqtt.Topic.topic_trie_node(topic: topic)] ->
        Logger.info("* 2)")
        :ok
      [] ->
        Logger.info("* 3)")
        tries_triples = Osumiex.Mqtt.Topic.tries_triples(topic)
        for tries_triple <- tries_triples, do: trie_add_path(tries_triple)

        topic_trie_node = Osumiex.Mqtt.Topic.topic_trie_node(node_id: topic, topic: topic)
        :mnesia.write(topic_trie_node)
    end
  end

  defp trie_add_path(triple={parent, word, node}) do
    Logger.info("* Add path #{inspect(triple)}")
    edge = Osumiex.Mqtt.Topic.topic_trie_edge(node_id: parent, word: word)

    case :mnesia.read(:topic_trie_node, parent) do
      [trie_node = Osumiex.Mqtt.Topic.topic_trie_node(edge_count: count)] ->
        Logger.info("** 3-1) count : [#{inspect count}]")
        case :mnesia.read(:topic_trie, edge) do
          [] ->
            Logger.info("** 3-1-1)")
            trie_node = Osumiex.Mqtt.Topic.topic_trie_node(trie_node, edge_count: count+1)
            topic_trie = Osumiex.Mqtt.Topic.topic_trie(edge: edge, node_id: node)
            :mnesia.write(trie_node)
            :mnesia.write(topic_trie);
          [_] ->
            Logger.info("** 3-1-2)")
            :ok
        end
      [] ->
        Logger.info("** 3-2) #{inspect node}")
        topic_trie_node = Osumiex.Mqtt.Topic.topic_trie_node(node_id: parent, edge_count: 1)
        topic_trie = Osumiex.Mqtt.Topic.topic_trie(edge: edge, node_id: node)
        :mnesia.write(topic_trie_node)
        :mnesia.write(topic_trie)
    end
  end

  def trie_match(words) do
    trie_match(:root, words, [])
  end
  def trie_match(node_id, [], res_acc) do
    :mnesia.read(:topic_trie_node, node_id) ++ trie_match_wildcard(node_id, res_acc)
  end
  def trie_match(node_id, [w|words], res_acc) do
    Logger.info("trie_match : node_id [#{node_id}] / w : [#{w}]")
    func = fn(arg, acc) ->
      Logger.info("arg : #{inspect arg} / acc : #{inspect acc}")
      case :mnesia.read(:topic_trie, Osumiex.Mqtt.Topic.topic_trie_edge(node_id: node_id, word: arg)) do
        [Osumiex.Mqtt.Topic.topic_trie(node_id: child_id)] ->
          Logger.info("loop #{inspect child_id}")
          trie_match(child_id, words, acc)
        [] ->
          acc
      end
    end
    List.foldl([w, "+"], trie_match_wildcard(node_id, res_acc), func)
  end
  def trie_match_wildcard(node_id, res_acc) do
    case :mnesia.read(:topic_trie, Osumiex.Mqtt.Topic.topic_trie_edge(node_id: node_id, word: "#")) do
      [Osumiex.Mqtt.Topic.topic_trie(node_id: child_id)] ->
        :mnesia.read(:topic_trie_node, child_id) ++ res_acc;
      [] ->
        res_acc
    end
  end

end
