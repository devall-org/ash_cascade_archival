defmodule AshCascadeArchival.Helpers do
  @moduledoc false

  alias Ash.Resource.Relationships.{HasOne, HasMany, ManyToMany}

  @doc """
  Returns true if the child relationship is fully-contained (child is completely owned by parent).
  Only applies to has_one, has_many, and many_to_many relationships.
  """
  def fully_contained_child?(rel) do
    case rel do
      %HasOne{no_attributes?: false, manual: nil, filters: []} -> true
      %HasMany{no_attributes?: false, manual: nil, filters: []} -> true
      %ManyToMany{filters: []} -> true
      _ -> false
    end
  end

  @doc """
  Returns true if the child relationship points to the given module.
  Only applies to has_one, has_many, and many_to_many relationships.
  """
  def child_relationship_to_module?(rel, module) do
    case rel do
      %HasOne{destination: ^module} -> true
      %HasMany{destination: ^module} -> true
      %ManyToMany{through: ^module} -> true
      _ -> false
    end
  end
end
