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
         To select specific relationships, use the `only` option in `cascade_archive`.
         To exclude specific relationships, use the `except` option in `cascade_archive`:

           cascade_archive do
             only [:relationship_name]
           end

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
    only = fetch_only(dsl_state)
    archive_last = AshCascadeArchival.Info.cascade_archive_archive_last!(dsl_state)

    # Find all fully-contained child relationships
    fully_contained_children =
      dsl_state
      |> Ash.Resource.Info.relationships()
      |> Enum.filter(&Helpers.fully_contained_child?/1)

    validate_options!(only, except, fully_contained_children)

    hard_delete = AshCascadeArchival.Info.cascade_archive_hard_delete!(dsl_state)

    archive_related =
      fully_contained_children
      |> filter_archive_related(only, except)
      |> Enum.map(& &1.name)
      |> Enum.sort()
      |> apply_archive_last(archive_last)

    validate_hard_delete_names!(hard_delete, archive_related)

    if log_enabled?() and not Enum.empty?(archive_related) do
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

  # Moves the named relationships to the back, keeping the order they were
  # declared in. Everything else stays alphabetical in front of them.
  defp apply_archive_last(names, []), do: names

  defp apply_archive_last(names, last) do
    validate_end_names!(last, names)

    Enum.reject(names, &(&1 in last)) ++ last
  end

  defp validate_end_names!(named, names) do
    case named -- names do
      [] ->
        :ok

      unknown ->
        raise """
        #{inspect(Enum.uniq(unknown))} specified in `archive_last` are not \
        part of archive_related.

        Only relationships that end up in archive_related can be ordered.
        """
    end
  end

  defp validate_hard_delete_names!(hard_delete, archive_related) do
    hard_delete
    |> Enum.reject(&(&1 in archive_related))
    |> case do
      [] ->
        :ok

      unknown ->
        raise """
        #{inspect(unknown)} specified in `hard_delete` are not part of archive_related.

        Only relationships that end up in archive_related can be marked for hard delete.
        Current archive_related: #{inspect(archive_related)}
        """
    end
  end

  defp fetch_only(dsl_state) do
    case Transformer.fetch_option(dsl_state, [:cascade_archive], :only) do
      {:ok, nil} -> :all
      {:ok, only} -> {:only, only}
      :error -> :all
    end
  end

  defp filter_archive_related(relationships, :all, except) do
    Enum.reject(relationships, &(&1.name in except))
  end

  defp filter_archive_related(relationships, {:only, only}, _except) do
    Enum.filter(relationships, &(&1.name in only))
  end

  defp validate_options!(only, except, fully_contained_children) do
    if only != :all and except != [] do
      raise """
      Cannot use both `only` and `except` in `cascade_archive`.

      Use `only` to include a specific set of relationships, or `except` to exclude relationships from the automatic set.
      """
    end

    validate_only!(only, fully_contained_children)
    validate_relationship_names!(:except, except, fully_contained_children)
  end

  defp validate_only!(:all, _fully_contained_children), do: :ok

  defp validate_only!({:only, only}, fully_contained_children) do
    validate_relationship_names!(:only, only, fully_contained_children)
  end

  defp validate_relationship_names!(option, names, fully_contained_children) do
    valid_names = Enum.map(fully_contained_children, & &1.name)

    Enum.each(names, fn name ->
      unless name in valid_names do
        raise """
        #{inspect(name)} specified in `#{option}` is not a fully-contained child relationship.

        Only fully-contained relationships can be archived:
        - has_one with no_attributes?: false, manual: nil, filters: []
        - has_many with no_attributes?: false, manual: nil, filters: []

        Available relationships: #{inspect(valid_names)}
        """
      end
    end)
  end

  defp log_enabled? do
    Application.get_env(:ash_cascade_archival, :log, true)
  end
end
