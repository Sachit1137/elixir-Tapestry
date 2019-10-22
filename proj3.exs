defmodule Project3 do
  def main do
    input = System.argv()
    [numNodes, numRequests] = input
    numNodes = numNodes |> String.to_integer()
    numRequests = numRequests |> String.to_integer()

    hashKeyList =
      Enum.map(1..numNodes, fn nodeID ->
        String.to_charlist(:crypto.hash(:sha, "#{nodeID}") |> Base.encode16())
      end)

    routingTable =
      Enum.reduce(hashKeyList, %{}, fn hashKeyID, acc ->
        Map.put(acc, hashKeyID, calculateRoutingTable(hashKeyID, hashKeyList -- [hashKeyID]))
      end)

    {:ok, supervisorid} = Tapestrysupervisor.start_link(hashKeyList, numRequests, routingTable)

    children = Supervisor.which_children(supervisorid)

    maxHops = List.last Enum.sort(Enum.map(Enum.sort(children), fn {_id, pid, _type, _module} ->
      GenServer.call(pid, :getState)
    end))

    IO.puts "Maximum number of Hops = #{maxHops}"
  end

  def calculateRoutingTable(hashKeyID, neighborList) do
    Enum.reduce(neighborList, %{}, fn neighborKeyID, acc ->
      key = commonPrefix(hashKeyID, neighborKeyID)

      if Map.has_key?(acc, key) do
        existingMapHashID = Map.fetch!(acc, key)
        {hashKeyIntegerVal, _} = Integer.parse(List.to_string(hashKeyID), 16)
        {existingMapIntegerVal, _} = Integer.parse(List.to_string(existingMapHashID), 16)
        {neighborKeyIntegerVal, _} = Integer.parse(List.to_string(neighborKeyID), 16)

        distance1 = abs(hashKeyIntegerVal - existingMapIntegerVal)
        distance2 = abs(hashKeyIntegerVal - neighborKeyIntegerVal)

        if distance1 < distance2 do
          Map.put(acc, key, existingMapHashID)
        else
          Map.put(acc, key, neighborKeyID)
        end
      else
        Map.put(acc, key, neighborKeyID)
      end
    end)
  end

  def commonPrefix(hashKeyID, neighborKeyID) do
    Enum.reduce_while(neighborKeyID, 0, fn char, level ->
      if Enum.at(hashKeyID, level) == char,
        do: {:cont, level + 1},
        else: {:halt, {level, List.to_string([char])}}
    end)
  end
end

defmodule Tapestrysupervisor do
  use Supervisor

  def start_link(hashKeyList, numRequests,routingTable) do
    Supervisor.start_link(__MODULE__, [hashKeyList, numRequests,routingTable])
  end

  def init([hashKeyList, numRequests,routingTable]) do
    children =
      Enum.map(hashKeyList, fn hashKeyNodeID ->
        worker(Tapestryalgo, [hashKeyNodeID, numRequests, routingTable, hashKeyList], id: hashKeyNodeID, restart: :permanent)
      end)

    Supervisor.init(children, strategy: :one_for_one)
  end
end

defmodule Tapestryalgo do
  use GenServer

  def start_link(hashKeyNodeID, numRequests, routingTable,hashKeyList) do
    {:ok, pid} = GenServer.start_link(__MODULE__, 0)
    GenServer.cast(pid, {:UpdateCounter, hashKeyNodeID, numRequests, routingTable, hashKeyList})
    {:ok, pid}
  end

  def init(counter) do
    {:ok, counter}
  end

  def startTapestry(hashKeyNodeID, numRequests, routingTable, hashKeyList) do
    neighborList = hashKeyList -- [hashKeyNodeID]
    destinationList =  Enum.take_random(neighborList,numRequests)
    hopsList = Enum.map(destinationList, fn destID ->
      counter = 0
      startHop(hashKeyNodeID, routingTable, destID, counter)
    end)
    List.last(Enum.sort(hopsList))
  end

  def startHop(hashKeyNodeID, routingTable, destID, counter) do
    counter = counter + 1
    foundID = Map.fetch!(Map.fetch!(routingTable,hashKeyNodeID),(Project3.commonPrefix(hashKeyNodeID,destID)))
    if (foundID != destID) do
      startHop(foundID, routingTable, destID, counter)
    else
      counter
    end
  end

  def handle_cast({:UpdateCounter, hashKeyNodeID, numRequests, routingTable, hashKeyList}, _state) do
    state = startTapestry(hashKeyNodeID, numRequests, routingTable, hashKeyList)
    #IO.inspect state
    {:noreply, state}
  end

  def handle_call(:getState,_from, state) do
    {:reply, state, state}
  end
end

Project3.main()
