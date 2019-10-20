defmodule Proj3 do
  use GenServer

  def main do
    input = System.argv()
    [numNodes, numRequests] = input
    numNodes = numNodes |> String.to_integer()
    numRequests = numRequests |> String.to_integer()
    # IO.puts(numNodes)
    # IO.puts(numRequests)

    allNodes =
      Enum.map(1..numNodes, fn x ->
        {:ok, pid} = GenServer.start_link(__MODULE__, :ok, [])
        updatePIDState(pid, x)
        pid
      end)

    #IO.inspect(allNodes)

    indexed_actors =
      Stream.with_index(allNodes, 1)
      |> Enum.reduce(%{}, fn {pids, nodeID}, acc ->
        Map.put(acc, :crypto.hash(:sha, "#{nodeID}") |> Base.encode16(), pids)
      end)

    #IO.inspect(indexed_actors)

    neighbors = set_neighbours(numNodes,indexed_actors)
    #IO.inspect(neighbors)
  end

  def set_neighbours(numNodes,indexed_actors) do
    rowCount = :math.pow(numNodes, 1 / 3) |> ceil

    # Creating a map for indexing all Torus nodes
    tupleList =
      Enum.map(1..rowCount, fn x ->
        Enum.map(1..rowCount, fn y -> Enum.map(1..rowCount, fn z -> {x, y, z} end) end)
      end)
      |> List.flatten()

    # Associating the map indexed values with the Nodes
    torusMap =
      Stream.with_index(tupleList, 1)
      |> Enum.reduce(%{}, fn {tupleValue, nodes}, acc -> Map.put(acc, tupleValue, nodes) end)

    # Forming a key value pair of Nodes and the index
    torusMapNew =
      Stream.with_index(tupleList, 1)
      |> Enum.reduce(%{}, fn {nodes, tupleValue}, acc -> Map.put(acc, tupleValue, nodes) end)

    Enum.map(1..numNodes, fn x ->
      # Assigning the current node to the map
      {a, b, c} = Map.fetch!(torusMapNew, x)

      # Calculating the neighbors
      neighbors =
        cond do
          a == 1 ->
            cond do
              b == 1 && c == 1 ->
                [
                  Map.fetch!(torusMap, {a + 1, b, c}),
                  Map.fetch!(torusMap, {a, b + 1, c}),
                  Map.fetch!(torusMap, {a, b, c + 1}),
                  Map.fetch!(torusMap, {a, b, c + rowCount - 1}),
                  Map.fetch!(torusMap, {a, b + rowCount - 1, c}),
                  Map.fetch!(torusMap, {a + rowCount - 1, b, c})
                ]

              b == 1 && (c > 1 && c < rowCount) ->
                [
                  Map.fetch!(torusMap, {a, b, c - 1}),
                  Map.fetch!(torusMap, {a, b, c + 1}),
                  Map.fetch!(torusMap, {a, b + 1, c}),
                  Map.fetch!(torusMap, {a + 1, b, c}),
                  Map.fetch!(torusMap, {a, b + rowCount - 1, c}),
                  Map.fetch!(torusMap, {a + rowCount - 1, b, c})
                ]

              b == 1 && c == rowCount ->
                [
                  Map.fetch!(torusMap, {a, b, c - rowCount + 1}),
                  Map.fetch!(torusMap, {a, b, c - 1}),
                  Map.fetch!(torusMap, {a, b + 1, c}),
                  Map.fetch!(torusMap, {a + 1, b, c}),
                  Map.fetch!(torusMap, {a, b + rowCount - 1, c}),
                  Map.fetch!(torusMap, {a + rowCount - 1, b, c})
                ]

              b > 1 && b < rowCount && c == 1 ->
                [
                  Map.fetch!(torusMap, {a, b - 1, c}),
                  Map.fetch!(torusMap, {a, b + 1, c}),
                  Map.fetch!(torusMap, {a, b, c + 1}),
                  Map.fetch!(torusMap, {a + 1, b, c}),
                  Map.fetch!(torusMap, {a, b, c + rowCount - 1}),
                  Map.fetch!(torusMap, {a + rowCount - 1, b, c})
                ]

              b > 1 && b < rowCount && c == rowCount ->
                [
                  Map.fetch!(torusMap, {a, b - 1, c}),
                  Map.fetch!(torusMap, {a, b + 1, c}),
                  Map.fetch!(torusMap, {a, b, c - 1}),
                  Map.fetch!(torusMap, {a + 1, b, c}),
                  Map.fetch!(torusMap, {a, b, c - rowCount + 1}),
                  Map.fetch!(torusMap, {a + rowCount - 1, b, c})
                ]

              b == rowCount && c == 1 ->
                [
                  Map.fetch!(torusMap, {a, b - 1, c}),
                  Map.fetch!(torusMap, {a, b, c + 1}),
                  Map.fetch!(torusMap, {a + 1, b, c}),
                  Map.fetch!(torusMap, {a, b - rowCount + 1, c}),
                  Map.fetch!(torusMap, {a, b, c + rowCount - 1}),
                  Map.fetch!(torusMap, {a + rowCount - 1, b, c})
                ]

              b == rowCount && c > 1 && c < rowCount ->
                [
                  Map.fetch!(torusMap, {a, b, c + 1}),
                  Map.fetch!(torusMap, {a, b, c - 1}),
                  Map.fetch!(torusMap, {a, b - rowCount + 1, c}),
                  Map.fetch!(torusMap, {a + rowCount - 1, b, c}),
                  Map.fetch!(torusMap, {a, b - 1, c}),
                  Map.fetch!(torusMap, {a + 1, b, c})
                ]

              b == rowCount && c == rowCount ->
                [
                  Map.fetch!(torusMap, {a + 1, b, c}),
                  Map.fetch!(torusMap, {a, b - 1, c}),
                  Map.fetch!(torusMap, {a, b, c - 1}),
                  Map.fetch!(torusMap, {a + rowCount - 1, b, c}),
                  Map.fetch!(torusMap, {a, b - rowCount + 1, c}),
                  Map.fetch!(torusMap, {a, b, c - rowCount + 1})
                ]

              b > 1 && b < rowCount && c > 1 && c < rowCount ->
                [
                  Map.fetch!(torusMap, {a, b + 1, c}),
                  Map.fetch!(torusMap, {a, b - 1, c}),
                  Map.fetch!(torusMap, {a, b, c + 1}),
                  Map.fetch!(torusMap, {a, b, c - 1}),
                  Map.fetch!(torusMap, {a + 1, b, c}),
                  Map.fetch!(torusMap, {a + rowCount - 1, b, c})
                ]

              true ->
                []
            end

          a == rowCount ->
            cond do
              b == 1 && c == 1 ->
                [
                  Map.fetch!(torusMap, {a - 1, b, c}),
                  Map.fetch!(torusMap, {a, b, c + 1}),
                  Map.fetch!(torusMap, {a, b + 1, c}),
                  Map.fetch!(torusMap, {a - rowCount + 1, b, c}),
                  Map.fetch!(torusMap, {a, b + rowCount - 1, c}),
                  Map.fetch!(torusMap, {a, b, c + rowCount - 1})
                ]

              b == 1 && (c > 1 && c < rowCount) ->
                [
                  Map.fetch!(torusMap, {a, b, c + 1}),
                  Map.fetch!(torusMap, {a, b, c - 1}),
                  Map.fetch!(torusMap, {a - 1, b, c}),
                  Map.fetch!(torusMap, {a, b + 1, c}),
                  Map.fetch!(torusMap, {a - rowCount + 1, b, c}),
                  Map.fetch!(torusMap, {a, b + rowCount - 1, c})
                ]

              b == 1 && c == rowCount ->
                [
                  Map.fetch!(torusMap, {a - 1, b, c}),
                  Map.fetch!(torusMap, {a, b + 1, c}),
                  Map.fetch!(torusMap, {a, b, c - 1}),
                  Map.fetch!(torusMap, {a, b, c - rowCount + 1}),
                  Map.fetch!(torusMap, {a, b + rowCount - 1, c}),
                  Map.fetch!(torusMap, {a - rowCount + 1, b, c})
                ]

              b > 1 && b < rowCount && c == 1 ->
                [
                  Map.fetch!(torusMap, {a, b + 1, c}),
                  Map.fetch!(torusMap, {a, b - 1, c}),
                  Map.fetch!(torusMap, {a, b, c + 1}),
                  Map.fetch!(torusMap, {a - 1, b, c}),
                  Map.fetch!(torusMap, {a - rowCount + 1, b, c}),
                  Map.fetch!(torusMap, {a, b, c + rowCount - 1})
                ]

              b > 1 && b < rowCount && c == rowCount ->
                [
                  Map.fetch!(torusMap, {a, b + 1, c}),
                  Map.fetch!(torusMap, {a, b - 1, c}),
                  Map.fetch!(torusMap, {a, b, c - 1}),
                  Map.fetch!(torusMap, {a - 1, b, c}),
                  Map.fetch!(torusMap, {a - rowCount + 1, b, c}),
                  Map.fetch!(torusMap, {a, b, c - rowCount + 1})
                ]

              b == rowCount && c == 1 ->
                [
                  Map.fetch!(torusMap, {a - 1, b, c}),
                  Map.fetch!(torusMap, {a, b - 1, c}),
                  Map.fetch!(torusMap, {a, b, c + 1}),
                  Map.fetch!(torusMap, {a, b - rowCount + 1, c}),
                  Map.fetch!(torusMap, {a, b, c + rowCount - 1}),
                  Map.fetch!(torusMap, {a - rowCount + 1, b, c})
                ]

              b == rowCount && c > 1 && c < rowCount ->
                [
                  Map.fetch!(torusMap, {a, b, c - 1}),
                  Map.fetch!(torusMap, {a, b, c + 1}),
                  Map.fetch!(torusMap, {a, b - 1, c}),
                  Map.fetch!(torusMap, {a - 1, b, c}),
                  Map.fetch!(torusMap, {a - rowCount + 1, b, c}),
                  Map.fetch!(torusMap, {a, b - rowCount + 1, c})
                ]

              b == rowCount && c == rowCount ->
                [
                  Map.fetch!(torusMap, {a - 1, b, c}),
                  Map.fetch!(torusMap, {a, b - 1, c}),
                  Map.fetch!(torusMap, {a, b, c - 1}),
                  Map.fetch!(torusMap, {a, b, c - rowCount + 1}),
                  Map.fetch!(torusMap, {a, b - rowCount + 1, c}),
                  Map.fetch!(torusMap, {a - rowCount + 1, b, c})
                ]

              b > 1 && b < rowCount && c > 1 && c < rowCount ->
                [
                  Map.fetch!(torusMap, {a, b + 1, c}),
                  Map.fetch!(torusMap, {a, b - 1, c}),
                  Map.fetch!(torusMap, {a, b, c + 1}),
                  Map.fetch!(torusMap, {a, b, c - 1}),
                  Map.fetch!(torusMap, {a - 1, b, c}),
                  Map.fetch!(torusMap, {a - rowCount + 1, b, c})
                ]

              true ->
                []
            end

          b == 1 && a > 1 && a < rowCount ->
            cond do
              c == 1 ->
                [
                  Map.fetch!(torusMap, {a - 1, b, c}),
                  Map.fetch!(torusMap, {a + 1, b, c}),
                  Map.fetch!(torusMap, {a, b + 1, c}),
                  Map.fetch!(torusMap, {a, b, c + 1}),
                  Map.fetch!(torusMap, {a, b + rowCount - 1, c}),
                  Map.fetch!(torusMap, {a, b, c + rowCount - 1})
                ]

              c == rowCount ->
                [
                  Map.fetch!(torusMap, {a - 1, b, c}),
                  Map.fetch!(torusMap, {a + 1, b, c}),
                  Map.fetch!(torusMap, {a, b + 1, c}),
                  Map.fetch!(torusMap, {a, b, c - 1}),
                  Map.fetch!(torusMap, {a, b, c - rowCount + 1}),
                  Map.fetch!(torusMap, {a, b + rowCount - 1, c})
                ]

              c > 1 && c < rowCount ->
                [
                  Map.fetch!(torusMap, {a - 1, b, c}),
                  Map.fetch!(torusMap, {a + 1, b, c}),
                  Map.fetch!(torusMap, {a, b, c - 1}),
                  Map.fetch!(torusMap, {a, b, c + 1}),
                  Map.fetch!(torusMap, {a, b + 1, c}),
                  Map.fetch!(torusMap, {a, b + rowCount - 1, c})
                ]

              true ->
                []
            end

          b == rowCount && a > 1 && a < rowCount ->
            cond do
              c == 1 ->
                [
                  Map.fetch!(torusMap, {a + 1, b, c}),
                  Map.fetch!(torusMap, {a - 1, b, c}),
                  Map.fetch!(torusMap, {a, b - 1, c}),
                  Map.fetch!(torusMap, {a, b, c + 1}),
                  Map.fetch!(torusMap, {a, b, c + rowCount - 1}),
                  Map.fetch!(torusMap, {a, b - rowCount + 1, c})
                ]

              c == rowCount ->
                [
                  Map.fetch!(torusMap, {a + 1, b, c}),
                  Map.fetch!(torusMap, {a - 1, b, c}),
                  Map.fetch!(torusMap, {a, b - 1, c}),
                  Map.fetch!(torusMap, {a, b, c - 1}),
                  Map.fetch!(torusMap, {a, b, c - rowCount + 1}),
                  Map.fetch!(torusMap, {a, b - rowCount + 1, c})
                ]

              c > 1 && c < rowCount ->
                [
                  Map.fetch!(torusMap, {a + 1, b, c}),
                  Map.fetch!(torusMap, {a - 1, b, c}),
                  Map.fetch!(torusMap, {a, b, c + 1}),
                  Map.fetch!(torusMap, {a, b, c - 1}),
                  Map.fetch!(torusMap, {a, b - 1, c}),
                  Map.fetch!(torusMap, {a, b - rowCount + 1, c})
                ]

              true ->
                []
            end

          a > 1 && a < rowCount && b > 1 && b < rowCount && c == 1 ->
            [
              Map.fetch!(torusMap, {a + 1, b, c}),
              Map.fetch!(torusMap, {a - 1, b, c}),
              Map.fetch!(torusMap, {a, b + 1, c}),
              Map.fetch!(torusMap, {a, b - 1, c}),
              Map.fetch!(torusMap, {a, b, c + 1}),
              Map.fetch!(torusMap, {a, b, c + rowCount - 1})
            ]

          a > 1 && a < rowCount && b > 1 && b < rowCount && c == rowCount ->
            [
              Map.fetch!(torusMap, {a + 1, b, c}),
              Map.fetch!(torusMap, {a - 1, b, c}),
              Map.fetch!(torusMap, {a, b + 1, c}),
              Map.fetch!(torusMap, {a, b - 1, c}),
              Map.fetch!(torusMap, {a, b, c - 1}),
              Map.fetch!(torusMap, {a, b, c - rowCount + 1})
            ]

          a > 1 && a < rowCount && (b > 1 && b < rowCount) && (c > 1 && c < rowCount) ->
            [
              Map.fetch!(torusMap, {a - 1, b, c}),
              Map.fetch!(torusMap, {a + 1, b, c}),
              Map.fetch!(torusMap, {a, b - 1, c}),
              Map.fetch!(torusMap, {a, b + 1, c}),
              Map.fetch!(torusMap, {a, b, c + 1}),
              Map.fetch!(torusMap, {a, b, c - 1})
            ]

          true ->
            []
        end

      neighborHexVal =
        Enum.map(neighbors, fn value ->
          String.to_charlist(:crypto.hash(:sha, "#{value}") |> Base.encode16())
        end)

      nodeID = :crypto.hash(:sha, "#{x}") |> Base.encode16()

      hash_key_routing_table =
        fill_routing_table(String.to_charlist(nodeID), neighborHexVal)
      GenServer.call(Map.fetch!(indexed_actors,nodeID), {:UpdateRoutingTable,hash_key_routing_table})
    end)
  end

  def fill_routing_table(hash_key, list_of_neighbors) do
    Enum.reduce(list_of_neighbors, %{}, fn neighbor_key, acc ->
      level = 0

      key =
        Enum.reduce_while(neighbor_key, 0, fn char2, level ->
          if Enum.at(hash_key, level) == char2,
            do: {:cont, level + 1},
            else: {:halt, {level, List.to_string([char2])}}
        end)

      # if multiple entries are found in one slot, store the closest neighbor in routing table
      if Map.has_key?(acc, key) do
        already_in_map_hexVal = Map.fetch!(acc, key)
        {hash_key_integer, _} = Integer.parse(List.to_string(hash_key), 16)
        {already_in_map_integer, _} = Integer.parse(List.to_string(already_in_map_hexVal), 16)
        {neighbor_key_integer, _} = Integer.parse(List.to_string(neighbor_key), 16)

        dist1 = abs(hash_key_integer - already_in_map_integer)
        dist2 = abs(hash_key_integer - neighbor_key_integer)

        if dist1 < dist2 do
          Map.put(acc, key, already_in_map_hexVal)
        else
          Map.put(acc, key, neighbor_key)
        end
      else
        Map.put(acc, key, neighbor_key)
      end
    end)
  end

  def init(:ok) do
    {:ok, {0, %{}, 0}}
  end

  def updatePIDState(pid, numNodeID) do
    GenServer.call(pid, {:updatePID, numNodeID})
  end

  def handle_call({:UpdateRoutingTable,hash_key_routing_table},_from,state) do
    {nodeID, neighborTable, counter} = state
    state = {nodeID, hash_key_routing_table, counter}
    IO.inspect state
    {:reply, neighborTable, state}
  end

  def handle_call({:updatePID, numNodeID}, _from, state) do
    {nodeID, neighborList, counter} = state
    state = {numNodeID, neighborList, counter}
    {:reply, nodeID, state}
  end
end

Proj3.main()
