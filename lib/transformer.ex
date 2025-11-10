defmodule AshCascadeArchival.Transformer do
  use Spark.Dsl.Transformer

  require Logger
  alias Spark.Dsl.Transformer
  alias AshCascadeArchival.Helpers

  @setup_archival_module AshArchival.Resource.Transformers.SetupArchival
  Code.ensure_loaded!(@setup_archival_module)

  @impl Spark.Dsl.Transformer
  def before?(@setup_archival_module), do: true
  def before?(_), do: false

  @impl Spark.Dsl.Transformer
  def after?(_), do: false

  @impl Spark.Dsl.Transformer
  def transform(dsl_state) do
    archive_related = AshArchival.Resource.Info.archive_archive_related!(dsl_state)

    case archive_related do
      [] ->
        do_transform(dsl_state)

      _ ->
        resource = Transformer.get_persisted(dsl_state, :module)

        {:error,
         """
         #{inspect(resource)} cannot use both `cascade_archive` and explicit `archive_related`.

         `cascade_archive` automatically sets `archive_related` based on relationships.
         To exclude specific relationships, use the `except` option in `cascade_archive`:

           cascade_archive do
             except [:relationship_name]
           end

         Current archive_related: #{inspect(archive_related)}
         """}
    end
  end

  defp do_transform(dsl_state) do
    resource = Transformer.get_persisted(dsl_state, :module)
    except = AshCascadeArchival.Info.cascade_archive_except!(dsl_state)

    # Find all fully-contained child relationships
    fully_contained_children =
      dsl_state
      |> Ash.Resource.Info.relationships()
      |> Enum.filter(&Helpers.fully_contained_child?/1)

    validate_except!(except, fully_contained_children)

    archive_related =
      fully_contained_children
      |> Enum.reject(&(&1.name in except))
      |> Enum.map(& &1.name)

    unless Enum.empty?(archive_related) do
      Logger.info(
        "[AshCascadeArchival] #{inspect(resource)} archive_related: #{inspect(archive_related)}"
      )
    end

    {:ok,
     dsl_state
     |> Transformer.set_option(
       [:archive],
       :archive_related,
       archive_related
     )}
  end

  defp validate_except!(except, fully_contained_children) do
    valid_names = Enum.map(fully_contained_children, & &1.name)

    Enum.each(except, fn name ->
      unless name in valid_names do
        raise """
        #{inspect(name)} specified in `except` is not a fully-contained child relationship.

        Only fully-contained relationships can be archived:
        - has_one with no_attributes?: false, manual: nil, filters: []
        - has_many with no_attributes?: false, manual: nil, filters: []
        - many_to_many with filters: []

        Available relationships: #{inspect(valid_names)}
        """
      end
    end)
  end
end
