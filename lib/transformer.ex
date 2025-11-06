defmodule AshCascadeArchival.Transformer do
  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer
  alias Ash.Resource.Relationships.{BelongsTo, HasMany, HasOne, ManyToMany}

  @impl Spark.Dsl.Transformer
  def before?(AshArchival.Resource.Transformers.SetupArchival), do: true
  def before?(_), do: false

  @impl Spark.Dsl.Transformer
  def after?(_), do: false

  @impl Spark.Dsl.Transformer
  def transform(dsl_state) do
    if AshArchival.Resource.Info.archive_archive_related!(dsl_state) == [] do
      do_transform(dsl_state)
    else
      {:ok, dsl_state}
    end
  end

  defp do_transform(dsl_state) do
    resource = Transformer.get_persisted(dsl_state, :module)
    excluded_names = AshCascadeArchival.Info.cascade_archive_except!(dsl_state)

    child_relationships =
      dsl_state
      |> Ash.Resource.Info.relationships()
      |> Enum.filter(fn
        %BelongsTo{} -> false
        %HasMany{no_attributes?: no_attr?, manual: manual} -> not no_attr? and manual == nil
        %HasOne{no_attributes?: no_attr?, manual: manual} -> not no_attr? and manual == nil
        %ManyToMany{} -> true
      end)

    simple_children =
      child_relationships
      |> Enum.filter(fn
        %HasMany{filter: filter, filters: filters} ->
          filter == nil and filters == []

        %HasOne{from_many?: from_many?, filter: _filter, filters: _filters} ->
          not from_many?

        %ManyToMany{} ->
          false
      end)
      |> tap(fn simple_children ->
        redundant_children = child_relationships -- simple_children

        suggest_missing_simple_children(
          redundant_children,
          simple_children,
          resource
        )

        validate_except!(excluded_names, simple_children)
      end)

    archive_related =
      simple_children
      |> Enum.reject(&(&1.name in excluded_names))
      |> Enum.map(& &1.name)

    {:ok,
     dsl_state
     |> Transformer.set_option(
       [:archive],
       :archive_related,
       archive_related
     )}
  end

  @simple_child_explanation """
  A simple child is when no_attributes? and manual are nil, and it's either:
  1. A has_many relationship with filters == [].
  2. A has_one relationship with from_many? == false.
  """

  defp validate_except!(excluded_names, simple_children) do
    simple_children_names = simple_children |> Enum.map(& &1.name)

    excluded_names
    |> Enum.each(fn excluded ->
      unless excluded in simple_children_names do
        raise """
        #{inspect(excluded)} specified in `except` is not a simple child. Only simple children can be archived.
        #{@simple_child_explanation}
        """
      end
    end)
  end

  defp suggest_missing_simple_children(
         redundant_children,
         simple_children,
         resource
       ) do
    archivable_dests = simple_children |> Enum.map(& &1.destination)

    missing_children_hint = fn destination ->
      """
      Create a simple has_many relationship to #{inspect(destination)} so cascade_archive can process it.
      #{@simple_child_explanation}
      """
    end

    redundant_children
    |> Enum.each(fn
      %HasMany{name: name, destination: destination} ->
        unless destination in archivable_dests do
          IO.warn("""
          #{inspect(resource)}.#{name} is not a simple has_many. It cannot be archived.
          #{missing_children_hint.(destination)}
          """)
        end

      %HasOne{name: name, destination: destination} ->
        unless destination in archivable_dests do
          IO.warn("""
          #{inspect(resource)}.#{name} is not a simple has_one. It cannot be archived.
          #{missing_children_hint.(destination)}
          """)
        end

      %ManyToMany{name: name, through: through} ->
        unless through in archivable_dests do
          IO.warn("""
          #{inspect(resource)}.#{name} is a many_to_many relationship. It cannot be archived.
          #{missing_children_hint.(through)}
          """)
        end
    end)
  end
end
