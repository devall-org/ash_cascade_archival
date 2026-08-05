defmodule AshCascadeArchival.Verifier.ArchivalDestinations do
  @moduledoc false
  # Cascading calls the destination's primary destroy action
  # (AshArchival.Resource.Changes.ArchiveRelated), so what actually happens
  # to each archive_related destination is decided by that action:
  #
  #   - no primary destroy       -> runtime crash (primary_action!/2 raises)
  #   - primary destroy soft?    -> the destination is archived
  #   - primary destroy not soft -> the destination is HARD-DELETED
  #
  # The verifier therefore classifies by the actual primary destroy action —
  # not by extension presence, which `exclude_destroy_actions` and custom
  # soft destroys can contradict. Hard deletion requires the explicit
  # `hard_delete` opt-in; a `hard_delete` declaration on a soft destination
  # is rejected as misleading.
  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)
    archive_related = AshArchival.Resource.Info.archive_archive_related!(dsl_state)
    hard_delete = AshCascadeArchival.Info.cascade_archive_hard_delete!(dsl_state)

    dsl_state
    |> Ash.Resource.Info.relationships()
    |> Enum.filter(&(&1.name in archive_related))
    |> Enum.flat_map(fn rel ->
      case verify_destination(module, rel, rel.name in hard_delete) do
        :ok -> []
        {:error, error} -> [error]
      end
    end)
    |> case do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  defp verify_destination(module, rel, hard_delete?) do
    primary_destroy = Ash.Resource.Info.primary_action(rel.destination, :destroy)

    case {primary_destroy, hard_delete?} do
      {nil, _} ->
        {:error,
         error(module, rel, """
         `:#{rel.name}` is in archive_related, but its destination \
         #{inspect(rel.destination)} has no primary destroy action.

         Cascading invokes the destination's primary destroy action, so archiving \
         #{inspect(module)} would crash at runtime. Add a primary destroy action to \
         #{inspect(rel.destination)}, or exclude the relationship:

           cascade_archive do
             except [:#{rel.name}]
           end
         """)}

      {%{soft?: true} = destroy, false} ->
        # soft? only routes the destroy through the update path — it does not
        # archive by itself. A soft destroy with no changes at all (neither
        # action-level nor resource-global destroy changes) and no manual
        # implementation is a no-op: cascading it would leave the children
        # untouched and active. This is a heuristic: the presence of a change
        # or a manual implementation is taken as evidence of archiving; the
        # verifier cannot prove the change actually archives.
        if destroy.manual == nil and destroy.changes == [] and
             Ash.Resource.Info.changes(rel.destination, :destroy) == [] do
          {:error,
           error(module, rel, """
           `:#{rel.name}` is in archive_related, but the soft primary destroy action \
           of its destination #{inspect(rel.destination)} has no changes — cascading \
           it would do nothing (the children would stay active).

           Make the destroy actually archive (e.g. via the AshArchival.Resource \
           extension or a `set_attribute` change), or exclude the relationship with \
           `except`.
           """)}
        else
          :ok
        end

      {%{soft?: true}, true} ->
        {:error,
         error(module, rel, """
         `:#{rel.name}` is marked `hard_delete`, but the primary destroy action of \
         #{inspect(rel.destination)} is soft — cascading archives it, so the \
         `hard_delete` declaration is misleading. Remove it from `hard_delete`.
         """)}

      {%{soft?: false}, true} ->
        :ok

      {%{soft?: false}, false} ->
        {:error,
         error(module, rel, """
         `:#{rel.name}` is in archive_related, but the primary destroy action of its \
         destination #{inspect(rel.destination)} is not soft.

         Cascading invokes that action, so archiving #{inspect(module)} would \
         HARD-DELETE #{inspect(rel.destination)} records instead of archiving them.

         Either make the destination's destroys soft (e.g. the AshArchival.Resource \
         or AshCascadeArchival.Resource extension), exclude the relationship, or opt \
         into hard deletion explicitly:

           cascade_archive do
             except [:#{rel.name}]
           end

           cascade_archive do
             hard_delete [:#{rel.name}]
           end
         """)}
    end
  end

  defp error(module, rel, message) do
    Spark.Error.DslError.exception(
      module: module,
      path: [:relationships, rel.name],
      message: message
    )
  end
end
