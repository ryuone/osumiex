defmodule Osumiex.Mqtt.Topic do
  require Logger
  import Record

  @topic_subscriber [topic: nil, qos: nil, subscriber_pid: nil]
  @topic_trie_edge [node_id: nil, word: nil]
  @topic_trie_node [node_id: nil, edge_count: 0, topic: nil]
  @topic_trie [edge: nil, node_id: 0]
  @topic [name: nil, node: nil]

  @topic_subscriber_fields Keyword.keys(@topic_subscriber)
  @topic_trie_edge_fields Keyword.keys(@topic_trie_edge)
  @topic_trie_node_fields Keyword.keys(@topic_trie_node)
  @topic_trie_fields Keyword.keys(@topic_trie)
  @topic_fields Keyword.keys(@topic)

  defrecord :topic_subscriber, @topic_subscriber
  defrecord :topic_trie_edge, @topic_trie_edge
  defrecord :topic_trie_node, @topic_trie_node
  defrecord :topic_trie, @topic_trie
  defrecord :topic, @topic

  @topic_max_length 32_767 * 2

  def topic_subscriber_fields, do: @topic_subscriber_fields
  def topic_trie_node_fields, do: @topic_trie_node_fields
  def topic_trie_fields, do: @topic_trie_fields
  def topic_fields, do: @topic_fields


  #
  # Topic type : direct or wildcard.
  #
  def type(name) when is_binary(name) do
    type(%Osumiex.Mqtt.Message.Topic{name: name})
  end
  def type(%Osumiex.Mqtt.Message.Topic{name: name} = topic) when is_binary(name) do
    type2(name)
  end

  defp type2(""), do: :direct
  defp type2(<<?+::size(8), rest::binary>>), do: :wildcard
  defp type2(<<?#::size(8), rest::binary>>), do: :wildcard
  defp type2(<<_::size(8), rest::binary>>) do
    type2(rest)
  end

  # ------------------------------------------------------------------------
  # Topic validate
  # ------------------------------------------------------------------------
  def validate({_, <<>>}), do: false
  def validate({_, topic}) when is_binary(topic) and (byte_size(topic) > @topic_max_length), do: false
  def validate({:direct, topic}) do
    validate2(words(topic)) and type(topic) != :wildcard
  end
  def validate({:filter, topic}) do
    validate2(words(topic))
  end

  defp validate2([]), do: true
  defp validate2([<<?#::size(8)>>]), do: true
  defp validate2([<<?#::size(8)>> | rest]) when byte_size(rest) > 0, do: false
  defp validate2(["" | rest]), do: validate2(rest)
  defp validate2([<<?+::size(8)>> | rest]), do: validate2(rest)
  defp validate2([w|rest]) do
    case validate3(w) do
      true -> validate2(rest);
      false -> false
    end
  end

  defp validate3(<<>>) do
    true
  end
  defp validate3(<<char::size(8), _rest::binary>>) when char == ?# or char == ?+ do
    false
  end
  defp validate3(<<_::size(8), rest::binary>>) do
    validate3(rest)
  end

  # ------------------------------------------------------------------------
  # Match Topic.
  # ------------------------------------------------------------------------
  def match(name, filter) when is_binary(name) and is_binary(filter) do
    match(words(name), words(filter))
  end
  def match([], []), do: true
  def match([h|t1], [h|t2]), do: match(t1, t2)
  def match([<<?$::size(8), _::binary>>|_], [<<?+::size(8)>>|_]), do: false
  def match([_|t1], [<<?+::size(8)>>|t2]), do: match(t1, t2)
  def match([<<?$::size(8), _::binary>>|_], [<<?#::size(8)>>]), do: false
  def match(_, [<<?#::size(8)>>]), do: true
  def match([_h1|_], [_h2|_]), do: false
  def match([_h1|_], []), do: false
  def match([], [_h|_t2]), do: false

  # ------------------------------------------------------------------------
  # Topic to tries_triples
  # ------------------------------------------------------------------------
  def tries_triples(topic) when is_binary(topic) do
    tries_triples(words(topic), :root, [])
  end
  def tries_triples([], _parent, acc), do: Enum.reverse(acc)
  def tries_triples([w|words], parent, acc) do
    node = join(parent, w)
    tries_triples(words, node, [{parent, w, node}|acc])
  end

  def join(:root, w) when is_binary(w), do: w
  def join(parent, w) when is_binary(parent) and is_binary(w), do: "#{parent}/#{w}"

  # ------------------------------------------------------------------------
  # Split Topic to Words
  # ------------------------------------------------------------------------
  def words(topic) when is_binary(topic), do: topic |> String.split "/"

end
