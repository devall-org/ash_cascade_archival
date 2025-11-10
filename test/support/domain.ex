defmodule AshCascadeArchival.Test.Support.Domain do
  @moduledoc false

  use Ash.Domain

  resources do
    resource AshCascadeArchival.Test.Support.TestResources.Author
    resource AshCascadeArchival.Test.Support.TestResources.Post
    resource AshCascadeArchival.Test.Support.TestResources.Comment
    resource AshCascadeArchival.Test.Support.TestResources.PostTag
    resource AshCascadeArchival.Test.Support.TestResources.Tag
    resource AshCascadeArchival.Test.Support.TestResources.PostWithExcept
    resource AshCascadeArchival.Test.Support.TestResources.PostWithFilteredRelationship
  end
end
