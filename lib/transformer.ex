defmodule AshCascadeArchival.Transformer do
  use Spark.Dsl.Transformer
  require Logger

  alias Spark.Dsl.Transformer
  alias Ash.Resource.Relationships.{BelongsTo, HasMany, HasOne, ManyToMany}

  @impl Spark.Dsl.Transformer
  def before?(AshArchival.Resource.Transformers.SetupArchival), do: true
  def before?(_), do: false

  @impl Spark.Dsl.Transformer
  def after?(_), do: false

  @impl Spark.Dsl.Transformer
  def transform(dsl_state) do
    if Transformer.get_option(dsl_state, [:archive], :archive_related) == [] do
      do_transform(dsl_state)
    else
      {:ok, dsl_state}
    end
  end

  defp do_transform(dsl_state) do
    resource = dsl_state |> Transformer.get_persisted(:module)
    except_list = Transformer.get_option(dsl_state, [:cascade_archive], :except, [])

    descendants =
      dsl_state
      |> Transformer.get_entities([:relationships])
      |> Enum.filter(fn
        %BelongsTo{} -> false
        %HasMany{no_attributes?: no_attr?, manual: manual} -> not no_attr? and manual == nil
        %HasOne{no_attributes?: no_attr?, manual: manual} -> not no_attr? and manual == nil
        %ManyToMany{} -> true
      end)

    direct_partitions =
      descendants
      |> Enum.filter(fn
        %HasMany{filter: filter, filters: filters} ->
          filter == nil and filters == []

        %HasOne{from_many?: from_many?, filter: _filter, filters: _filters} ->
          not from_many?

        %ManyToMany{} ->
          false
      end)
      |> tap(fn direct_partitions ->
        redundant_descendants = descendants -- direct_partitions

        warn_redundant_descendants_not_belong_to_any_direct_partition(
          redundant_descendants,
          direct_partitions,
          resource
        )

        validate_except!(except_list, direct_partitions, resource)
      end)

    {:ok,
     dsl_state
     |> Transformer.set_option(
       [:archive],
       :archive_related,
       direct_partitions |> Enum.reject(&(&1.name in except_list)) |> Enum.map(& &1.name)
     )}
  end

  @common_explain """
  A simple child is when no_attributes? and manual are nil, and it's either:
  1. A has_many relationship with filters == [].
  2. A has_one relationship with from_many? == false.
  """

  defp validate_except!(except_list, direct_partitions, resource) do
    direct_partition_names = direct_partitions |> Enum.map(& &1.name)

    except_list
    |> Enum.each(fn except ->
      unless except in direct_partition_names do
        raise """
        #{inspect(except)} specified in `except` is not a simple child of #{resource |> inspect()} and therefore cannot be a target for ash_archival's archive_related. Thus, it cannot be specified in `except`.
        #{@common_explain}
        """
      end
    end)
  end

  defp warn_redundant_descendants_not_belong_to_any_direct_partition(
         redundant_descendants,
         direct_partitions,
         resource
       ) do
    direct_partition_dests = direct_partitions |> Enum.map(& &1.destination)

    warn_message = fn dest ->
      """
      Please explicitly create a simple has_many relationship with destination #{dest |> inspect()} so that cascade_archive can process it.
      #{@common_explain}
      """
    end

    redundant_descendants
    |> Enum.each(fn
      %HasMany{name: name, destination: dest} ->
        unless dest in direct_partition_dests do
          Logger.warning("""

          #{resource |> inspect()}.#{name} is not a simple has_many and therefore cannot be a target for ash_archival's archive_related.
          #{warn_message.(dest)}
          """)
        end

      %HasOne{name: name, destination: dest} ->
        unless dest in direct_partition_dests do
          Logger.warning("""

          #{resource |> inspect()}.#{name} is not a simple has_one and therefore cannot be a target for ash_archival's archive_related.
          #{warn_message.(dest)}
          """)
        end

      %ManyToMany{name: name, through: through} ->
        unless through in direct_partition_dests do
          Logger.warning("""

          #{resource |> inspect()}.#{name} is a many_to_many relationship and therefore cannot be a target for ash_archival's archive_related.
          #{warn_message.(through)}
          """)
        end
    end)
  end
end
