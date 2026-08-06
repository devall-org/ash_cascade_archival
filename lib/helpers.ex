defmodule AshCascadeArchival.Helpers do
  @moduledoc false

  alias Ash.Resource.Relationships.{HasOne, HasMany}

  @doc """
  Returns true if the child relationship is fully-contained (child is completely owned by parent).
  Only applies to has_one and has_many relationships.
  many_to_many is excluded because archive_related would target the destination, not the through resource.
  Relationships marked as `used_by` (see `ash_borrow`) are excluded: they point at
  users of this resource, not contained children, and archiving them would drag
  the users down with the used resource.
  """
  def fully_contained_child?(rel) do
    case rel do
      %HasOne{no_attributes?: false, manual: nil, filters: []} -> not used_by?(rel)
      %HasMany{no_attributes?: false, manual: nil, filters: []} -> not used_by?(rel)
      _ -> false
    end
  end

  defp used_by?(rel), do: Map.get(rel, :__used_by__, false) == true

  @doc """
  Returns true if the relationship is a `uses` edge (see `ash_borrow`):
  a non-owning belongs_to that must not be treated as a containment chain.
  """
  def uses?(rel), do: Map.get(rel, :__uses__, false) == true

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
