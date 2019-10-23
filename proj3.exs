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

    Enum.map(hashKeyList, fn hashKeyID ->
      calculateRoutingTable(hashKeyID, hashKeyList -- [hashKeyID])
    end)

    newNumNode = numNodes + 1
    newNodeHashID = String.to_charlist(:crypto.hash(:sha, "#{newNumNode}") |> Base.encode16())
    newNodeInsertion(newNodeHashID, hashKeyList)

    {:ok, supervisorid} =
      Tapestrysupervisor.start_link(hashKeyList ++ [newNodeHashID], numRequests)

    children = Supervisor.which_children(supervisorid)

    max_hop_list =
      Enum.map(Enum.sort(children), fn {_id, pid, _type, _module} ->
        GenServer.call(pid, :getState)
      end)

    IO.puts("Maximum number of Hops = #{Enum.max(max_hop_list)}")
  end

  def calculateRoutingTable(hashKeyID, neighborList) do
    Enum.reduce(
      neighborList,
      :ets.new(String.to_atom("#{hashKeyID}"), [:named_table, :public]),
      fn neighborKeyID, _acc ->
        key = commonPrefix(hashKeyID, neighborKeyID)

        if :ets.lookup(String.to_atom("#{hashKeyID}"), key) != [] do
          [{_, existingMapHashID}] = :ets.lookup(String.to_atom("#{hashKeyID}"), key)
          {hashKeyIntegerVal, _} = Integer.parse(List.to_string(hashKeyID), 16)
          {existingMapIntegerVal, _} = Integer.parse(List.to_string(existingMapHashID), 16)
          {neighborKeyIntegerVal, _} = Integer.parse(List.to_string(neighborKeyID), 16)

          distance1 = abs(hashKeyIntegerVal - existingMapIntegerVal)
          distance2 = abs(hashKeyIntegerVal - neighborKeyIntegerVal)

          if distance1 < distance2 do
            :ets.insert(String.to_atom("#{hashKeyID}"), {key, existingMapHashID})
          else
            :ets.insert(String.to_atom("#{hashKeyID}"), {key, neighborKeyID})
          end
        else
          :ets.insert(String.to_atom("#{hashKeyID}"), {key, neighborKeyID})
        end
      end
    )
  end

  def commonPrefix(hashKeyID, neighborKeyID) do
    Enum.reduce_while(neighborKeyID, 0, fn char, level ->
      if Enum.at(hashKeyID, level) == char,
        do: {:cont, level + 1},
        else: {:halt, {level, List.to_string([char])}}
    end)
  end

  def newNodeInsertion(newNodeHashID, hashKeyList) do
    Enum.map(hashKeyList, fn neighborKeyID ->
      key = commonPrefix(neighborKeyID, newNodeHashID)

      if :ets.lookup(String.to_atom("#{neighborKeyID}"), key) != [] do
        [{_, existingMapHashID}] = :ets.lookup(String.to_atom("#{neighborKeyID}"), key)
        {hashKeyIntegerVal, _} = Integer.parse(List.to_string(neighborKeyID), 16)
        {existingMapIntegerVal, _} = Integer.parse(List.to_string(existingMapHashID), 16)
        {neighborKeyIntegerVal, _} = Integer.parse(List.to_string(newNodeHashID), 16)

        distance1 = abs(hashKeyIntegerVal - existingMapIntegerVal)
        distance2 = abs(hashKeyIntegerVal - neighborKeyIntegerVal)

        if distance1 < distance2 do
          :ets.insert(String.to_atom("#{neighborKeyID}"), {key, existingMapHashID})
        else
          :ets.insert(String.to_atom("#{neighborKeyID}"), {key, newNodeHashID})
        end
      else
        :ets.insert(String.to_atom("#{neighborKeyID}"), {key, newNodeHashID})
      end
    end)

    calculateRoutingTable(newNodeHashID, hashKeyList)
  end
end

defmodule Tapestrysupervisor do
  use Supervisor

  def start_link(hashKeyList, numRequests) do
    Supervisor.start_link(__MODULE__, [hashKeyList, numRequests])
  end

  def init([hashKeyList, numRequests]) do
    newList = Enum.chunk_every(Enum.to_list(hashKeyList), 10)

    children =
      Enum.map(newList, fn hashKeysNodeID ->
        worker(Tapestryalgo, [hashKeysNodeID, numRequests, hashKeyList],
          id: Enum.at(hashKeysNodeID, 0),
          restart: :permanent
        )
      end)

    Supervisor.init(children, strategy: :one_for_one)
  end
end

defmodule Tapestryalgo do
  use GenServer

  def start_link(hashKeyNodeID, numRequests, hashKeyList) do
    {:ok, pid} = GenServer.start_link(__MODULE__, 0)
    GenServer.cast(pid, {:UpdateCounter, hashKeyNodeID, numRequests, hashKeyList})
    {:ok, pid}
  end

  def init(counter) do
    {:ok, counter}
  end

  def startTapestry(hashKeysNodeID, numRequests, hashKeyList) do
    newHopList =
      Enum.map(hashKeysNodeID, fn hashKeyNodeID ->
        neighborList = hashKeyList -- [hashKeyNodeID]
        destinationList = Enum.take_random(neighborList, numRequests)

        # x = Enum.at(destinationList,0)
        # IO.puts "#{hashKeyNodeID}-> #{x}"

        hopsList =
          Enum.map(destinationList, fn destID ->
            startHop(hashKeyNodeID, destID, 0)
          end)

        Enum.max(hopsList)
      end)

    # IO.inspect newHopList
    Enum.max(newHopList)
  end

  def startHop(hashKeyNodeID, destID, counter) do
    [{_, foundID}] =
      :ets.lookup(
        String.to_atom("#{hashKeyNodeID}"),
        Project3.commonPrefix(hashKeyNodeID, destID)
      )

    if foundID != destID do
      startHop(foundID, destID, counter + 1)
    else
      counter + 1
    end
  end

  def handle_cast({:UpdateCounter, hashKeyNodeID, numRequests, hashKeyList}, _state) do
    state = startTapestry(hashKeyNodeID, numRequests, hashKeyList)
    {:noreply, state}
  end

  def handle_call(:getState, _from, state) do
    {:reply, state, state}
  end
end

Project3.main()
