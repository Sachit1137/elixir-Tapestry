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
    indexed_actors = Stream.with_index(allNodes,1) |> Enum.reduce(%{}, fn {pids, nodeID}, acc -> Map.put(acc, :crypto.hash(:sha, "#{nodeID}") |> Base.encode16 , pids) end)
    IO.inspect indexed_actors

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
