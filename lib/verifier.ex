defmodule AshCascadeArchival.Verifier do
  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier
  alias Ash.Resource.Relationships.BelongsTo
  alias AshCascadeArchival.Helpers

  @impl true
  def verify(dsl_state) do
    child_module = dsl_state |> Verifier.get_persisted(:module)

    belongs_to_rels =
      dsl_state
      |> Ash.Resource.Info.relationships()
      |> Enum.filter(fn
        %BelongsTo{} -> true
        %{} -> false
      end)

    errors =
      belongs_to_rels
      |> Enum.reduce([], fn %BelongsTo{destination: parent_module}, errors ->
        validate_archival_relationship(parent_module, child_module) ++ errors
      end)

    case errors do
      [] ->
        :ok

      _ ->
        {:error, Enum.join(errors, "\n\n")}
    end
  end

  defp validate_archival_relationship(parent_module, child_module) do
    extensions = Spark.Dsl.Extension.get_persisted(parent_module, :extensions)

    # If the parent is not an AshArchival target, skip validation
    if AshArchival.Resource not in extensions do
      []
    else
      # If the parent is an AshArchival target, verify it has a fully-contained relationship to child
      if has_fully_contained_child?(parent_module, child_module) do
        []
      else
        [build_error_message(parent_module, child_module)]
      end
    end
  end

  defp has_fully_contained_child?(parent_module, child_module) do
    parent_module
    |> Ash.Resource.Info.relationships()
    |> Enum.any?(fn rel ->
      Helpers.child_relationship_to_module?(rel, child_module) and
        Helpers.fully_contained_child?(rel)
    end)
  end

  defp build_error_message(parent_module, child_module) do
    child_singular = to_singular(child_module)
    child_plural = Inflex.pluralize(child_singular)

    """
    AshCascadeArchival requires has_many or has_one to pair with belongs_to.
    Parent #{inspect(parent_module)} must have one of the following:

    has_many :#{child_plural}, #{inspect(child_module)}
    has_one :#{child_singular}, #{inspect(child_module)}
    """
  end

  defp to_singular(module) do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end
end
