defmodule Proj3 do
  use GenServer

  def main do
    input = System.argv()
    [numNodes, numRequests] = input
    numNodes = numNodes |> String.to_integer()
    numRequests = numRequests |> String.to_integer()

    allNodes =
      Enum.map(1..numNodes, fn x ->
        {:ok, pid} = GenServer.start_link(__MODULE__, :ok, [])
        #updatePIDState(pid, x)
        updatePIDState(pid,String.to_charlist(:crypto.hash(:sha, "#{x}") |> Base.encode16()))
        pid
      end)

    indexed_actors =
      Stream.with_index(allNodes, 1)
      |> Enum.reduce(%{}, fn {pids, nodeID}, acc ->
        Map.put(acc, String.to_charlist(:crypto.hash(:sha, "#{nodeID}") |> Base.encode16()), pids)
      end)

    #IO.inspect(indexed_actors)

    list_of_hexValues =
      for {hash_key, _pid} <- indexed_actors do
        hash_key
      end
      #IO.inspect(list_of_hexValues)

    Enum.map(1..numNodes, fn x ->
      nodeID = :crypto.hash(:sha, "#{x}") |> Base.encode16()

      hash_key_routing_table =
        fill_routing_table(
          String.to_charlist(nodeID),
          list_of_hexValues -- [String.to_charlist(nodeID)]
        )
        GenServer.call(Map.fetch!(indexed_actors, String.to_charlist(nodeID)), {:UpdateRoutingTable,hash_key_routing_table})
    end)

    #IO.inspect
    tapestryAlgo(list_of_hexValues,indexed_actors,numRequests)
  end

  def commonPrefix(hash_key,neighbor_key) do
    Enum.reduce_while(neighbor_key, 0, fn char2, level ->
      if Enum.at(hash_key, level) == char2,
        do: {:cont, level + 1},
        else: {:halt, {level, List.to_string([char2])}}
    end)
  end
  def fill_routing_table(hash_key, list_of_neighbors) do
    Enum.reduce(list_of_neighbors, %{}, fn neighbor_key, acc ->
      key = commonPrefix(hash_key,neighbor_key)


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

   def tapestryAlgo(list_of_hexValues,indexed_actors,numRequests) do
     Enum.map(indexed_actors, fn {hashKey,pid} ->
      neighborList = list_of_hexValues
      neighborList = neighborList -- [hashKey]
      IO.inspect neighborList
      IO.inspect hashKey
      destinationList = Enum.take_random(neighborList,numRequests)
      IO.inspect destinationList
      IO.inspect "Iteration"
      Enum.map(destinationList, fn destID ->
        IO.inspect destID
        IO.puts "Hello World"
        GenServer.call(pid,{:UpdateNextHop,destID,indexed_actors})
      end)
    end)
   end

  def init(:ok) do
    {:ok, {0, %{}, 0}}
  end

  def updatePIDState(pid, numNodeID) do
    GenServer.call(pid, {:updatePID, numNodeID})
  end

  def nextHop(newNodeID,destID,indexed_actors) do
    GenServer.call(Map.fetch!(indexed_actors,newNodeID),{:UpdateNextHop,destID,indexed_actors})
  end

  def handle_call({:UpdateNextHop,destID,indexed_actors},_from,state) do
    {nodeID, neighborTable, counter} = state
    IO.inspect nodeID
    IO.inspect destID
    IO.puts "Iteration"
    state = {nodeID, neighborTable, counter + 1}
    #IO.inspect state
    key = commonPrefix(nodeID,destID)
    IO.inspect key
    if(Map.fetch!(neighborTable,key) != destID) do
      nextHop(Map.fetch!(neighborTable,key),destID,indexed_actors)
    else
      IO.puts "Result"
      IO.inspect nodeID
      IO.inspect destID
      IO.puts "Result Out"
      {:reply, state, state}
    end
  end

  def handle_call({:UpdateRoutingTable, hash_key_routing_table}, _from, state) do
    {nodeID, neighborTable, counter} = state
    state = {nodeID, hash_key_routing_table, counter}
    #IO.inspect(state)
    {:reply, neighborTable, state}
  end

  def handle_call({:updatePID, numNodeID}, _from, state) do
    {nodeID, neighborList, counter} = state
    state = {numNodeID, neighborList, counter}
    {:reply, nodeID, state}
  end
end

Proj3.main()
