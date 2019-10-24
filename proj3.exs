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

    {:ok, supervisorid} = Tapestrysupervisor.start_link(hashKeyList ++ [newNodeHashID])

    children = Supervisor.which_children(supervisorid)

    :ets.new(:hashPIDTable, [:named_table, :public])

    Enum.map(Enum.sort(children), fn {id, pid, _type, _module} ->
      :ets.insert(:hashPIDTable, {id, pid})
    end)

    Enum.map(hashKeyList ++ [newNodeHashID], fn hashKeyNodeID ->
      [{_, pid}] = :ets.lookup(:hashPIDTable, hashKeyNodeID)

      GenServer.cast(
        pid,
        {:UpdateCounter, hashKeyNodeID, numRequests, hashKeyList ++ [newNodeHashID]}
      )
    end)

    {_, maxHops} =
      List.last(
        Enum.sort(
          Enum.map(Enum.sort(children), fn {_id, pid, _type, _module} ->
            GenServer.call(pid, :getState)
          end)
        )
      )

    IO.puts("Maximum number of Hops = #{maxHops}")
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
    table =
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

    table ++ [calculateRoutingTable(newNodeHashID, hashKeyList)]
  end
end

defmodule Tapestrysupervisor do
  use Supervisor

  def start_link(hashKeyList) do
    Supervisor.start_link(__MODULE__, [hashKeyList])
  end

  def init([hashKeyList]) do
    children =
      Enum.map(hashKeyList, fn hashKeyNodeID ->
        worker(Tapestryalgo, [],
          id: hashKeyNodeID,
          restart: :permanent
        )
      end)

    Supervisor.init(children, strategy: :one_for_one)
  end
end

defmodule Tapestryalgo do
  use GenServer

  def start_link() do
    {:ok, pid} = GenServer.start_link(__MODULE__, :ok)
    {:ok, pid}
  end

  def init(:ok) do
    {:ok, {0, 0}}
  end

  def startTapestry(hashKeyNodeID, numRequests, hashKeyList) do
    neighborList = hashKeyList -- [hashKeyNodeID]
    destinationList = Enum.take_random(neighborList, numRequests)

    Enum.map(destinationList, fn destID ->
      counter = 0

      [{_, foundID}] =
        :ets.lookup(
          String.to_atom("#{hashKeyNodeID}"),
          Project3.commonPrefix(hashKeyNodeID, destID)
        )

      if foundID == destID do
        [{_, pid}] = :ets.lookup(:hashPIDTable, destID)
        GenServer.cast(pid, {:updatePIDCounter, counter + 1})
      else
        startHop(foundID, destID, counter)
      end
    end)
  end

  def startHop(foundID, destID, counter) do
    if foundID != destID do
      [{_, pid1}] = :ets.lookup(:hashPIDTable, foundID)
      GenServer.cast(pid1, {:nextHop, foundID, destID, counter + 1})
    else
      [{_, pid2}] = :ets.lookup(:hashPIDTable, destID)
      GenServer.cast(pid2, {:updatePIDCounter, counter + 1})
    end
  end

  def handle_cast({:nextHop, foundID, destID, counter}, state) do
    {_count, hops} = state

    [{_, newFoundID}] =
      :ets.lookup(
        String.to_atom("#{foundID}"),
        Project3.commonPrefix(foundID, destID)
      )

    maxHops = Enum.max([counter, hops])
    state = {counter, maxHops}
    # IO.inspect state
    startHop(newFoundID, destID, counter)
    {:noreply, state}
  end

  def handle_cast({:updatePIDCounter, counter}, state) do
    {_count, hops} = state
    maxHops = Enum.max([counter, hops])
    state = {counter, maxHops}
    # IO.inspect state
    {:noreply, state}
  end

  def handle_cast({:UpdateCounter, hashKeyNodeID, numRequests, hashKeyList}, state) do
    startTapestry(hashKeyNodeID, numRequests, hashKeyList)
    {:noreply, state}
  end

  def handle_call(:getState, _from, state) do
    {:reply, state, state}
  end
end

Project3.main()
