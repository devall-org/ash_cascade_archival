defmodule AshCascadeArchival.Verifier.UseOrder do
  @moduledoc false
  # Cascading is sequential: `archive_related` is walked in order. When one
  # destination uses another (see `ash_borrow`), the using side must be
  # archived first — a used resource still holding live users refuses to be
  # archived, which aborts the whole cascade.
  #
  # The order cannot be derived automatically here. This transformer's phase
  # would have to read the child modules' relationships, and the cascade
  # verifier already reads parent modules from the child side; doing both
  # would close a compile-time dependency cycle. So the order is verified
  # instead, and the exact `order` pairs to declare are reported.
  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    archive_related = AshArchival.Resource.Info.archive_archive_related!(dsl_state)

    case missing_pairs(dsl_state, archive_related) do
      [] ->
        :ok

      pairs ->
        module = Verifier.get_persisted(dsl_state, :module)

        {:error,
         Spark.Error.DslError.exception(
           module: module,
           path: [:cascade_archive, :order],
           message: """
           #{inspect(module)} archives used resources before the resources that use them.

           Cascading is sequential, and a resource that still has live users \
           refuses to be archived — so the whole cascade of #{inspect(module)} would fail.

           Declare the order explicitly:

             cascade_archive do
               order [#{Enum.map_join(pairs, ", ", fn {a, b} -> "{:#{a}, :#{b}}" end)}]
             end

           Current archive_related: #{inspect(archive_related)}
           """
         )}
    end
  end

  defp missing_pairs(dsl_state, archive_related) do
    indexed = Enum.with_index(archive_related)

    for {used_name, used_index} <- indexed,
        used_rel = relationship(dsl_state, used_name),
        used_rel != nil,
        users = users_of(used_rel.destination),
        not Enum.empty?(users),
        {user_name, user_index} <- indexed,
        user_index > used_index,
        user_rel = relationship(dsl_state, user_name),
        user_rel != nil,
        MapSet.member?(users, user_rel.destination),
        uniq: true do
      {user_name, used_name}
    end
  end

  defp relationship(dsl_state, name) do
    dsl_state
    |> Ash.Resource.Info.relationships()
    |> Enum.find(&(&1.name == name))
  end

  # Read through the `used_by` marker only, with no dependency on
  # ash_borrow itself: those are exactly the edges the destroy guard walks.
  defp users_of(module) do
    module
    |> Ash.Resource.Info.relationships()
    |> Enum.filter(&(Map.get(&1, :__used_by__, false) == true))
    |> MapSet.new(& &1.destination)
  end
end
