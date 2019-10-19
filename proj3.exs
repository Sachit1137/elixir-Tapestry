defmodule Proj3 do
  use GenServer

  def main do
    # Input of the nodes, Topology and Algorithm
    input = System.argv()
    [numNodes, numRequests] = input
    numNodes = String.to_integer(numNodes)
    numRequests = String.to_integer(numRequests)

    rowCount = :math.pow(numNodes, 1 / 3) |> ceil
    numNodes = rowCount * rowCount * rowCount

    # Associating all nodes with their PID's
    allNodes =
      Enum.map(1..numNodes, fn x ->
        pid = start_node()
        updatePIDState(pid, x)
        pid
      end)

    # Indexing all the PID's with the hexadecimal node ID's
    indexed_actors =
      Stream.with_index(allNodes, 1)
      |> Enum.reduce(%{}, fn {pids, nodeID}, acc ->
        Map.put(acc, :crypto.hash(:sha, "#{nodeID}") |> Base.encode16(), pids)
      end)

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

    IO.inspect routing_tables_of_all_hexIDs(numNodes, torusMap, torusMapNew, rowCount)
  end

  # implementing torus network architecture to find neighbors
  def routing_tables_of_all_hexIDs(numNodes, torusMap, torusMapNew, rowCount) do
    Enum.reduce(1..numNodes, %{}, fn x, all_routing_tables ->
      # Assigning the current node to the map
      {a, b, c} = Map.fetch!(torusMapNew, x)

      # Calculating the neighbors
      neighbors =
        cond do
          a == 1 ->
            cond do
              b == 1 && c == 1 ->
                _neighborList = [
                  Map.fetch!(torusMap, {a + 1, b, c}),
                  Map.fetch!(torusMap, {a, b + 1, c}),
                  Map.fetch!(torusMap, {a, b, c + 1}),
                  Map.fetch!(torusMap, {a, b, c + rowCount - 1}),
                  Map.fetch!(torusMap, {a, b + rowCount - 1, c}),
                  Map.fetch!(torusMap, {a + rowCount - 1, b, c})
                ]

              b == 1 && (c > 1 && c < rowCount) ->
                _neighborList = [
                  Map.fetch!(torusMap, {a, b, c - 1}),
                  Map.fetch!(torusMap, {a, b, c + 1}),
                  Map.fetch!(torusMap, {a, b + 1, c}),
                  Map.fetch!(torusMap, {a + 1, b, c}),
                  Map.fetch!(torusMap, {a, b + rowCount - 1, c}),
                  Map.fetch!(torusMap, {a + rowCount - 1, b, c})
                ]

              b == 1 && c == rowCount ->
                _neighborList = [
                  Map.fetch!(torusMap, {a, b, c - rowCount + 1}),
                  Map.fetch!(torusMap, {a, b, c - 1}),
                  Map.fetch!(torusMap, {a, b + 1, c}),
                  Map.fetch!(torusMap, {a + 1, b, c}),
                  Map.fetch!(torusMap, {a, b + rowCount - 1, c}),
                  Map.fetch!(torusMap, {a + rowCount - 1, b, c})
                ]

              b > 1 && b < rowCount && c == 1 ->
                _neighborList = [
                  Map.fetch!(torusMap, {a, b - 1, c}),
                  Map.fetch!(torusMap, {a, b + 1, c}),
                  Map.fetch!(torusMap, {a, b, c + 1}),
                  Map.fetch!(torusMap, {a + 1, b, c}),
                  Map.fetch!(torusMap, {a, b, c + rowCount - 1}),
                  Map.fetch!(torusMap, {a + rowCount - 1, b, c})
                ]

              b > 1 && b < rowCount && c == rowCount ->
                _neighborList = [
                  Map.fetch!(torusMap, {a, b - 1, c}),
                  Map.fetch!(torusMap, {a, b + 1, c}),
                  Map.fetch!(torusMap, {a, b, c - 1}),
                  Map.fetch!(torusMap, {a + 1, b, c}),
                  Map.fetch!(torusMap, {a, b, c - rowCount + 1}),
                  Map.fetch!(torusMap, {a + rowCount - 1, b, c})
                ]

              b == rowCount && c == 1 ->
                _neighborList = [
                  Map.fetch!(torusMap, {a, b - 1, c}),
                  Map.fetch!(torusMap, {a, b, c + 1}),
                  Map.fetch!(torusMap, {a + 1, b, c}),
                  Map.fetch!(torusMap, {a, b - rowCount + 1, c}),
                  Map.fetch!(torusMap, {a, b, c + rowCount - 1}),
                  Map.fetch!(torusMap, {a + rowCount - 1, b, c})
                ]

              b == rowCount && c > 1 && c < rowCount ->
                _neighborList = [
                  Map.fetch!(torusMap, {a, b, c + 1}),
                  Map.fetch!(torusMap, {a, b, c - 1}),
                  Map.fetch!(torusMap, {a, b - rowCount + 1, c}),
                  Map.fetch!(torusMap, {a + rowCount - 1, b, c}),
                  Map.fetch!(torusMap, {a, b - 1, c}),
                  Map.fetch!(torusMap, {a + 1, b, c})
                ]

              b == rowCount && c == rowCount ->
                _neighborList = [
                  Map.fetch!(torusMap, {a + 1, b, c}),
                  Map.fetch!(torusMap, {a, b - 1, c}),
                  Map.fetch!(torusMap, {a, b, c - 1}),
                  Map.fetch!(torusMap, {a + rowCount - 1, b, c}),
                  Map.fetch!(torusMap, {a, b - rowCount + 1, c}),
                  Map.fetch!(torusMap, {a, b, c - rowCount + 1})
                ]

              b > 1 && b < rowCount && c > 1 && c < rowCount ->
                _neighborList = [
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
                _neighborList = [
                  Map.fetch!(torusMap, {a - 1, b, c}),
                  Map.fetch!(torusMap, {a, b, c + 1}),
                  Map.fetch!(torusMap, {a, b + 1, c}),
                  Map.fetch!(torusMap, {a - rowCount + 1, b, c}),
                  Map.fetch!(torusMap, {a, b + rowCount - 1, c}),
                  Map.fetch!(torusMap, {a, b, c + rowCount - 1})
                ]

              b == 1 && (c > 1 && c < rowCount) ->
                _neighborList = [
                  Map.fetch!(torusMap, {a, b, c + 1}),
                  Map.fetch!(torusMap, {a, b, c - 1}),
                  Map.fetch!(torusMap, {a - 1, b, c}),
                  Map.fetch!(torusMap, {a, b + 1, c}),
                  Map.fetch!(torusMap, {a - rowCount + 1, b, c}),
                  Map.fetch!(torusMap, {a, b + rowCount - 1, c})
                ]

              b == 1 && c == rowCount ->
                _neighborList = [
                  Map.fetch!(torusMap, {a - 1, b, c}),
                  Map.fetch!(torusMap, {a, b + 1, c}),
                  Map.fetch!(torusMap, {a, b, c - 1}),
                  Map.fetch!(torusMap, {a, b, c - rowCount + 1}),
                  Map.fetch!(torusMap, {a, b + rowCount - 1, c}),
                  Map.fetch!(torusMap, {a - rowCount + 1, b, c})
                ]

              b > 1 && b < rowCount && c == 1 ->
                _neighborList = [
                  Map.fetch!(torusMap, {a, b + 1, c}),
                  Map.fetch!(torusMap, {a, b - 1, c}),
                  Map.fetch!(torusMap, {a, b, c + 1}),
                  Map.fetch!(torusMap, {a - 1, b, c}),
                  Map.fetch!(torusMap, {a - rowCount + 1, b, c}),
                  Map.fetch!(torusMap, {a, b, c + rowCount - 1})
                ]

              b > 1 && b < rowCount && c == rowCount ->
                _neighborList = [
                  Map.fetch!(torusMap, {a, b + 1, c}),
                  Map.fetch!(torusMap, {a, b - 1, c}),
                  Map.fetch!(torusMap, {a, b, c - 1}),
                  Map.fetch!(torusMap, {a - 1, b, c}),
                  Map.fetch!(torusMap, {a - rowCount + 1, b, c}),
                  Map.fetch!(torusMap, {a, b, c - rowCount + 1})
                ]

              b == rowCount && c == 1 ->
                _neighborList = [
                  Map.fetch!(torusMap, {a - 1, b, c}),
                  Map.fetch!(torusMap, {a, b - 1, c}),
                  Map.fetch!(torusMap, {a, b, c + 1}),
                  Map.fetch!(torusMap, {a, b - rowCount + 1, c}),
                  Map.fetch!(torusMap, {a, b, c + rowCount - 1}),
                  Map.fetch!(torusMap, {a - rowCount + 1, b, c})
                ]

              b == rowCount && c > 1 && c < rowCount ->
                _neighborList = [
                  Map.fetch!(torusMap, {a, b, c - 1}),
                  Map.fetch!(torusMap, {a, b, c + 1}),
                  Map.fetch!(torusMap, {a, b - 1, c}),
                  Map.fetch!(torusMap, {a - 1, b, c}),
                  Map.fetch!(torusMap, {a - rowCount + 1, b, c}),
                  Map.fetch!(torusMap, {a, b - rowCount + 1, c})
                ]

              b == rowCount && c == rowCount ->
                _neighborList = [
                  Map.fetch!(torusMap, {a - 1, b, c}),
                  Map.fetch!(torusMap, {a, b - 1, c}),
                  Map.fetch!(torusMap, {a, b, c - 1}),
                  Map.fetch!(torusMap, {a, b, c - rowCount + 1}),
                  Map.fetch!(torusMap, {a, b - rowCount + 1, c}),
                  Map.fetch!(torusMap, {a - rowCount + 1, b, c})
                ]

              b > 1 && b < rowCount && c > 1 && c < rowCount ->
                _neighborList = [
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
                _neighborList = [
                  Map.fetch!(torusMap, {a - 1, b, c}),
                  Map.fetch!(torusMap, {a + 1, b, c}),
                  Map.fetch!(torusMap, {a, b + 1, c}),
                  Map.fetch!(torusMap, {a, b, c + 1}),
                  Map.fetch!(torusMap, {a, b + rowCount - 1, c}),
                  Map.fetch!(torusMap, {a, b, c + rowCount - 1})
                ]

              c == rowCount ->
                _neighborList = [
                  Map.fetch!(torusMap, {a - 1, b, c}),
                  Map.fetch!(torusMap, {a + 1, b, c}),
                  Map.fetch!(torusMap, {a, b + 1, c}),
                  Map.fetch!(torusMap, {a, b, c - 1}),
                  Map.fetch!(torusMap, {a, b, c - rowCount + 1}),
                  Map.fetch!(torusMap, {a, b + rowCount - 1, c})
                ]

              c > 1 && c < rowCount ->
                _neighborList = [
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
                _neighborList = [
                  Map.fetch!(torusMap, {a + 1, b, c}),
                  Map.fetch!(torusMap, {a - 1, b, c}),
                  Map.fetch!(torusMap, {a, b - 1, c}),
                  Map.fetch!(torusMap, {a, b, c + 1}),
                  Map.fetch!(torusMap, {a, b, c + rowCount - 1}),
                  Map.fetch!(torusMap, {a, b - rowCount + 1, c})
                ]

              c == rowCount ->
                _neighborList = [
                  Map.fetch!(torusMap, {a + 1, b, c}),
                  Map.fetch!(torusMap, {a - 1, b, c}),
                  Map.fetch!(torusMap, {a, b - 1, c}),
                  Map.fetch!(torusMap, {a, b, c - 1}),
                  Map.fetch!(torusMap, {a, b, c - rowCount + 1}),
                  Map.fetch!(torusMap, {a, b - rowCount + 1, c})
                ]

              c > 1 && c < rowCount ->
                _neighborList = [
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
            _neighborList = [
              Map.fetch!(torusMap, {a + 1, b, c}),
              Map.fetch!(torusMap, {a - 1, b, c}),
              Map.fetch!(torusMap, {a, b + 1, c}),
              Map.fetch!(torusMap, {a, b - 1, c}),
              Map.fetch!(torusMap, {a, b, c + 1}),
              Map.fetch!(torusMap, {a, b, c + rowCount - 1})
            ]

          a > 1 && a < rowCount && b > 1 && b < rowCount && c == rowCount ->
            _neighborList = [
              Map.fetch!(torusMap, {a + 1, b, c}),
              Map.fetch!(torusMap, {a - 1, b, c}),
              Map.fetch!(torusMap, {a, b + 1, c}),
              Map.fetch!(torusMap, {a, b - 1, c}),
              Map.fetch!(torusMap, {a, b, c - 1}),
              Map.fetch!(torusMap, {a, b, c - rowCount + 1})
            ]

          a > 1 && a < rowCount && (b > 1 && b < rowCount) && (c > 1 && c < rowCount) ->
            _neighborList = [
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

      neighbor_hexValues =
        Enum.map(neighbors, fn nodeID ->
          String.to_charlist(:crypto.hash(:sha, "#{nodeID}") |> Base.encode16())
        end)

      hash_key = :crypto.hash(:sha, "#{x}") |> Base.encode16()

      hash_key_routing_table =
        fill_routing_table(String.to_charlist(hash_key), neighbor_hexValues)

      Map.put(all_routing_tables, hash_key, hash_key_routing_table)
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
    {:ok, {0, 0, [], 1}}
  end

  def start_node() do
    {:ok, pid} = GenServer.start_link(__MODULE__, :ok, [])
    pid
  end

  def updatePIDState(pid, nodeID) do
    GenServer.call(pid, {:UpdatePIDState, nodeID})
  end

  # Handle call for associating specific Node with PID
  def handle_call({:UpdatePIDState, nodeID}, _from, state) do
    {a, b, c, d} = state
    state = {nodeID, b, c, d}
    {:reply, a, state}
  end
end

Proj3.main()
