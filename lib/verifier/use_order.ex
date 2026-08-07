defmodule AshCascadeArchival.Verifier.UseOrder do
  @moduledoc false
  # Cascading is sequential: `archive_related` is walked in order. When one
  # destination uses another (see `ash_ownership`), the using side must be
  # archived first — a used resource still holding live users refuses to be
  # archived, which aborts the whole cascade.
  #
  # The order cannot be derived automatically here. This transformer's phase
  # would have to read the child modules' relationships, and the cascade
  # verifier already reads parent modules from the child side; doing both
  # would close a compile-time dependency cycle. So the order is verified
  # instead, and a ready-to-paste `archive_last` is reported.
  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    archive_related = AshArchival.Resource.Info.archive_archive_related!(dsl_state)
    edges = use_edges(dsl_state, archive_related)

    if violated?(edges, archive_related) do
      module = Verifier.get_persisted(dsl_state, :module)

      {:error,
       Spark.Error.DslError.exception(
         module: module,
         path: [:cascade_archive, :archive_last],
         message: """
         #{inspect(module)} archives used resources before the resources that use them.

         Cascading is sequential, and a resource that still has live users \
         refuses to be archived — so the whole cascade of #{inspect(module)} would fail.

         Declare the order explicitly:

           cascade_archive do
             archive_last [#{Enum.map_join(suggestion(edges, archive_related), ", ", &":#{&1}")}]
           end

         Current archive_related: #{inspect(archive_related)}
         """
       )}
    else
      :ok
    end
  end

  # {user, used}: `user` must be archived before `used`.
  defp use_edges(dsl_state, archive_related) do
    for used_name <- archive_related,
        used_rel = relationship(dsl_state, used_name),
        used_rel != nil,
        users = users_of(used_rel.destination),
        not Enum.empty?(users),
        user_name <- archive_related,
        user_name != used_name,
        user_rel = relationship(dsl_state, user_name),
        user_rel != nil,
        MapSet.member?(users, user_rel.destination),
        uniq: true do
      {user_name, used_name}
    end
  end

  defp violated?(edges, archive_related) do
    position = archive_related |> Enum.with_index() |> Map.new()

    Enum.any?(edges, fn {user, used} -> position[user] > position[used] end)
  end

  # Every name touched by a use edge, topologically sorted with users first.
  # Pinning exactly those to the tail satisfies every edge, since both ends of
  # each edge are in the set.
  defp suggestion(edges, archive_related) do
    nodes = edges |> Enum.flat_map(&Tuple.to_list/1) |> Enum.uniq()

    predecessors =
      Enum.reduce(edges, Map.new(nodes, &{&1, MapSet.new()}), fn {user, used}, acc ->
        Map.update!(acc, used, &MapSet.put(&1, user))
      end)

    nodes
    |> Enum.sort_by(&Enum.find_index(archive_related, fn name -> name == &1 end))
    |> topo_sort(predecessors, [])
  end

  defp topo_sort([], _predecessors, acc), do: Enum.reverse(acc)

  defp topo_sort(remaining, predecessors, acc) do
    remaining_set = MapSet.new(remaining)

    case Enum.find(remaining, &MapSet.disjoint?(predecessors[&1], remaining_set)) do
      nil ->
        # A use cycle cannot be resolved by ordering. Report what is left so the
        # message still points at the resources involved.
        Enum.reverse(acc) ++ remaining

      name ->
        topo_sort(remaining -- [name], predecessors, [name | acc])
    end
  end

  defp relationship(dsl_state, name) do
    dsl_state
    |> Ash.Resource.Info.relationships()
    |> Enum.find(&(&1.name == name))
  end

  # Read through the `used_by` marker only, with no dependency on
  # ash_ownership itself: those are exactly the edges the destroy guard walks.
  defp users_of(module) do
    module
    |> Ash.Resource.Info.relationships()
    |> Enum.filter(&(Map.get(&1, :__used_by__, false) == true))
    |> MapSet.new(& &1.destination)
  end
end
