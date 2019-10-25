defmodule Proj3 do
  def main do
    # Input of the nodes, Topology and Algorithm
    input = System.argv()
    [num_nodes, num_requests, num_fail_nodes] = input
    num_nodes = String.to_integer(num_nodes)
    num_requests = String.to_integer(num_requests)
    num_fail_nodes = String.to_integer(num_fail_nodes)

    list_of_hexValues =
      Enum.map(1..(num_nodes + 1), fn nodeID ->
        String.to_charlist(:crypto.hash(:sha, "#{nodeID}") |> Base.encode16())
      end)

    # table for linking hash with their pids
    :ets.new(:indexed_actors, [:named_table, :public])
    :ets.new(:indexed_pids, [:named_table, :public])

    # using supervisor to initialise all the workers
    children =
      Enum.map(list_of_hexValues, fn hash ->
        Supervisor.child_spec({Tapestryworker, []}, id: hash, restart: :permanent)
      end)

    new_num_node = num_nodes + 2
    new_hash = String.to_charlist(:crypto.hash(:sha, "#{new_num_node}") |> Base.encode16())

    children =
      children ++ [Supervisor.child_spec({Tapestryworker, []}, id: new_hash, restart: :permanent)]

    Supervisor.start_link(children, strategy: :one_for_one, name: Tapestrysupervisor)
    result = Supervisor.which_children(Tapestrysupervisor)

    Enum.map(result, fn {hash, pid, _, _} ->
      :ets.insert(:indexed_actors, {hash, pid})
    end)

    Enum.map(result, fn {hash, pid, _, _} ->
      :ets.insert(:indexed_pids, {pid, hash})
    end)

    list_of_pids =
      Enum.map(result, fn {_, pid, _, _} ->
        pid
      end)

    list_of_pids = list_of_pids -- [List.last(list_of_pids)]

    list_without_newNode = list_of_hexValues -- [List.last(list_of_hexValues)]

    create_fault_tol_table(new_hash, list_of_hexValues)

    # creating routing tables for all nodes except the last node
    Enum.map(list_without_newNode, fn hash_key ->
      fill_routing_table(
        hash_key,
        list_of_hexValues -- [hash_key]
      )
    end)

    # inserting last node as a newNode into the network
    new_num_node = List.last(list_of_hexValues)
    node_insertion(new_num_node, list_without_newNode)

    killed_pids =
      Enum.map(Enum.take_random(list_of_pids, num_fail_nodes), fn pid ->
        Process.exit(pid, :kill)
        pid
      end)

    killed_hash =
      Enum.map(killed_pids, fn x ->
        [{_, hash}] = :ets.lookup(:indexed_pids, x)
        hash
      end)

    new_dest_list = list_of_hexValues -- killed_hash

    # Start Hopping
    Enum.map(new_dest_list, fn source_ID ->
      destinationList = Enum.take_random(new_dest_list -- [source_ID], num_requests)

      [{_, pid}] = :ets.lookup(:indexed_actors, source_ID)

      implementing_tapestry(
        source_ID,
        pid,
        destinationList,
        new_hash
      )
    end)

    hopping_list =
      Enum.reduce(new_dest_list, [], fn hash_key, list ->
        [{_, pid}] = :ets.lookup(:indexed_actors, hash_key)
        list ++ [GenServer.call(pid, :getState)]
      end)

    max_hops = Enum.max(hopping_list)
    IO.puts("Maximum Hops = #{max_hops}")
  end

  def create_fault_tol_table(new_hash, list_of_hexValues) do
    :ets.new(:fault_tol_table, [:bag, :named_table, :public])

    Enum.map(list_of_hexValues, fn hash_key ->
      key = common_prefix(new_hash, hash_key)
      :ets.insert(:fault_tol_table, {key, hash_key})
    end)
  end

  def node_insertion(new_num_node, list_without_newNode) do
    # Adapting the routing tables of all the current nodes
    Enum.map(list_without_newNode, fn neighbor_hash ->
      key = common_prefix(neighbor_hash, new_num_node)
      handling_insertion(neighbor_hash, new_num_node, key)
    end)

    # Creating the routing table of the new node
    fill_routing_table(new_num_node, list_without_newNode)
  end

  def implementing_tapestry(
        node_ID,
        pid,
        destinationList,
        new_hash
      ) do
    Enum.map(destinationList, fn dest_ID ->
      GenServer.cast(
        pid,
        {:update_next_hop, node_ID, dest_ID, new_hash, 1}
      )

      # :timer.sleep(1000)
    end)
  end

  def fill_routing_table(hash_key, list_of_neighbors) do
    Enum.reduce(
      list_of_neighbors,
      :ets.new(String.to_atom("Table_#{hash_key}"), [:named_table, :public]),
      fn neighbor_key, _acc ->
        key = common_prefix(hash_key, neighbor_key)
        handling_insertion(hash_key, neighbor_key, key)
      end
    )
  end

  def handling_insertion(hash_key, neighbor_key, key) do
    if :ets.lookup(String.to_atom("Table_#{hash_key}"), key) != [] do
      [{_, already_in_map_hexVal}] = :ets.lookup(String.to_atom("Table_#{hash_key}"), key)
      {hash_key_integer, _} = Integer.parse(List.to_string(hash_key), 16)
      {already_in_map_integer, _} = Integer.parse(List.to_string(already_in_map_hexVal), 16)
      {neighbor_key_integer, _} = Integer.parse(List.to_string(neighbor_key), 16)

      dist1 = abs(hash_key_integer - already_in_map_integer)
      dist2 = abs(hash_key_integer - neighbor_key_integer)

      if dist1 < dist2 do
        :ets.insert(String.to_atom("Table_#{hash_key}"), {key, already_in_map_hexVal})
      else
        :ets.insert(String.to_atom("Table_#{hash_key}"), {key, neighbor_key})
      end
    else
      :ets.insert(String.to_atom("Table_#{hash_key}"), {key, neighbor_key})
    end
  end

  def common_prefix(hash_key, neighbor_key) do
    Enum.reduce_while(neighbor_key, 0, fn char, level ->
      if Enum.at(hash_key, level) == char,
        do: {:cont, level + 1},
        else: {:halt, {level, List.to_string([char])}}
    end)
  end
end

defmodule Tapestryworker do
  use GenServer

  def start_link(_args) do
    {:ok, pid} = GenServer.start_link(__MODULE__, 1)
    {:ok, pid}
  end

  def init(hops) do
    {:ok, hops}
  end

  def nextHop(new_node_ID, dest_ID, new_hash, total_hops) do
    [{_, pid}] = :ets.lookup(:indexed_actors, new_node_ID)

    if Process.alive?(pid) != True do
      [{_, new_pid}] = :ets.lookup(:indexed_actors, new_hash)

      GenServer.cast(
        new_pid,
        {:update_fault_hop, new_node_ID, dest_ID, new_hash, total_hops + 1}
      )
    end

    GenServer.cast(
      pid,
      {:update_next_hop, new_node_ID, dest_ID, new_hash, total_hops}
    )
  end

  def handle_cast(
        {:update_fault_hop, new_node_ID, dest_ID, _new_hash, total_hops},
        state
      ) do
    key = Proj3.common_prefix(new_node_ID, dest_ID)

    values = :ets.lookup(:fault_tol_table, key)

    list =
      Enum.map(values, fn x ->
        {_, hash} = x
        hash
      end)

    if Enum.find(list, fn _x -> dest_ID end) == dest_ID do
      state = Enum.max([state, total_hops])
      {:noreply, state}
    end

    state = Enum.max([state, total_hops])
    {:noreply, state}
  end

  def handle_cast(
        {:update_next_hop, node_ID, dest_ID, new_hash, total_hops},
        state
      ) do
    key = Proj3.common_prefix(node_ID, dest_ID)
    [{_, new_node_ID}] = :ets.lookup(String.to_atom("Table_#{node_ID}"), key)

    state = Enum.max([state, total_hops])

    if(new_node_ID == dest_ID) do
      {:noreply, state}
    else
      nextHop(
        new_node_ID,
        dest_ID,
        new_hash,
        total_hops + 1
      )

      {:noreply, state}
    end
  end

  def handle_call(:getState, _from, state) do
    {:reply, state, state}
  end
end

Proj3.main()
