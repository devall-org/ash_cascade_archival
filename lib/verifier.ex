defmodule AshCascadeArchival.Verifier do
  use Spark.Dsl.Verifier

  require Logger
  alias Spark.Dsl.Verifier
  alias Ash.Resource.Relationships.{BelongsTo, ManyToMany, HasOne, HasMany}

  @impl true
  def verify(dsl_state) do
    current = dsl_state |> Verifier.get_persisted(:module)
    multitenant_attr = Ash.Resource.Info.multitenancy_attribute(dsl_state)

    belongs_toes =
      dsl_state
      |> Ash.Resource.Info.relationships()
      |> Enum.filter(fn
        %BelongsTo{source_attribute: source_attribute} ->
          source_attribute != multitenant_attr

        %{} ->
          false
      end)

    belongs_toes
    |> Enum.each(fn %BelongsTo{destination: destination} ->
      perant_dsl = destination.spark_dsl_config()

      perant_dsl
      |> Ash.Resource.Info.relationships()
      |> Enum.any?(fn rel ->
        case rel do
          %HasOne{destination: ^current} -> true
          %HasMany{destination: ^current} -> true
          %ManyToMany{through: ^current} -> true
          _ -> false
        end
      end)
      |> unless do
        parent_resource = destination |> printable()
        parent = parent_resource |> Macro.underscore()

        child_resource = current |> printable()
        child = child_resource |> Macro.underscore()
        children = "#{child}s"

        Logger.warning("""

        AshArchival requires has_many, has_one, or many_to_many to pair with belongs_to.
        Add one of the following to #{parent}.ex:

        has_many :#{children}, R.#{child_resource}
        has_one :#{child}, R.#{child_resource}
        many_to_many :<things>, <R.Thing>, through: R.#{child_resource}
        """)
      end
    end)

    :ok
  end

  defp printable(module) do
    module |> Module.split() |> List.last()
  end
end
