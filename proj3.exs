defmodule Proj3 do
  use GenServer

  def main do
    # Input of the nodes, Topology and Algorithm
    input = System.argv()
    [numNodes, numRequests] = input
    numNodes = String.to_integer(numNodes)
    numRequests = String.to_integer(numRequests)

    # Associating all nodes with their PID's
    allNodes =
      Enum.map(1..numNodes, fn x ->
        pid = start_node()
        updatePIDState(pid, x)
        pid
      end)


    # Indexing all the PID's with the hexadecimal node ID's
    # indexed_actors = Stream.with_index(allNodes,1) |> Enum.reduce(%{}, fn {pids, nodeID}, acc -> Map.put(acc, String.slice(:crypto.hash(:sha, "#{nodeID}") |> Base.encode16 , 1..4) , pids) end)
    indexed_actors = Stream.with_index(allNodes,1) |> Enum.reduce(%{}, fn {pids, nodeID}, acc -> Map.put(acc, :crypto.hash(:sha, "#{nodeID}") |> Base.encode16 , pids) end)
    # IO.inspect indexed_actors

    routing_tables = Map.new()

    list_of_hexValues = for {hash_key , _pid} <- indexed_actors do
      String.to_charlist(hash_key)
    end
    IO.inspect list_of_hexValues
    # IO.inspect ['3f93','1c42', '309c','93cb','c3ca','d340','e9ce','fod7','2fe4','3f93','362d','705b','8887','3c6f']

    # IO.inspect fill_routing_table('3f93',['1c42', '3c6f','309c','93cb','c3ca','d340','e9ce','fod7','2fe4','3f93','362d','705b','8887'])

    IO.inspect Enum.reduce(indexed_actors, %{}, fn {hash_key, _pid}, all_routing_tables ->
      # list_of_hexValues -- [String.to_charlist(hash_key)]
      # IO.puts "hash_key = #{hash_key}"
      hash_key_routing_table = fill_routing_table(String.to_charlist(hash_key), list_of_hexValues -- [String.to_charlist(hash_key)])
      Map.put(all_routing_tables,hash_key,hash_key_routing_table)
    end)

    # for {hash_key , _pid} <- indexed_actors do
    #   # list_of_hexValues -- [String.to_charlist(hash_key)]
    #   IO.puts "hash_key = #{hash_key}"
    #   IO.inspect fill_routing_table(String.to_charlist(hash_key), list_of_hexValues -- [String.to_charlist(hash_key)])
    # end
  end

  def fill_routing_table(hash_key,list_of_neighbors) do

    Enum.reduce(list_of_neighbors, %{}, fn neighbor_key,acc->
      level = 0
      key = Enum.reduce_while(neighbor_key, 0 ,fn char2,level ->
        if Enum.at(hash_key,level) == char2, do: {:cont, level+1}, else: {:halt, {level,List.to_string([char2])}}
      end)

      #if multiple entries are found in one slot, store the closest neighbor in routing table
      if Map.has_key?(acc,key) do
        already_in_map_hexVal = Map.fetch!(acc,key)
        {hash_key_integer,_} = Integer.parse(List.to_string(hash_key),16)
        {already_in_map_integer,_} = Integer.parse(List.to_string(already_in_map_hexVal),16)
        {neighbor_key_integer,_} = Integer.parse(List.to_string(neighbor_key),16)

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

      # Map.put(acc, key, neighbor_key)
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
