defmodule AshCascadeArchival.Helpers do
  @moduledoc false

  alias Ash.Resource.Relationships.{HasOne, HasMany}

  @doc """
  Returns true if the child relationship is fully-contained (child is completely owned by parent).
  Only applies to has_one and has_many relationships.
  many_to_many is excluded because archive_related would target the destination, not the through resource.
  """
  def fully_contained_child?(rel) do
    case rel do
      %HasOne{no_attributes?: false, manual: nil, filters: []} -> true
      %HasMany{no_attributes?: false, manual: nil, filters: []} -> true
      _ -> false
    end
  end

  @doc """
  Returns true if the child relationship points to the given module.
  Only applies to has_one and has_many relationships.
  """
  def child_relationship_to_module?(rel, module) do
    case rel do
      %HasOne{destination: ^module} -> true
      %HasMany{destination: ^module} -> true
      _ -> false
    end
  end
end
