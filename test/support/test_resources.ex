defmodule AshCascadeArchival.Test.Support.TestResources do
  @moduledoc false

  alias AshCascadeArchival.Test.Support.TestResources

  defmodule Author do
    @moduledoc false
    use Ash.Resource, domain: nil, extensions: [AshCascadeArchival.Resource]

    attributes do
      uuid_primary_key :id
    end

    relationships do
      has_many :posts, TestResources.Post
      has_many :comments, TestResources.Comment
    end
  end

  defmodule Post do
    @moduledoc false
    use Ash.Resource, domain: nil, extensions: [AshCascadeArchival.Resource]

    attributes do
      uuid_primary_key :id
    end

    relationships do
      belongs_to :author, TestResources.Author

      has_many :comments, TestResources.Comment
      has_many :post_tags, TestResources.PostTag

      many_to_many :tags, TestResources.Tag, through: TestResources.PostTag
    end
  end

  defmodule Comment do
    @moduledoc false
    use Ash.Resource, domain: nil, extensions: [AshCascadeArchival.Resource]

    attributes do
      uuid_primary_key :id
    end

    relationships do
      belongs_to :author, TestResources.Author
      belongs_to :post, TestResources.Post
    end
  end

  defmodule PostTag do
    @moduledoc false
    use Ash.Resource, domain: nil, extensions: [AshCascadeArchival.Resource]

    attributes do
      uuid_primary_key :id
    end

    relationships do
      belongs_to :post, TestResources.Post
      belongs_to :tag, TestResources.Tag
    end
  end

  defmodule Tag do
    @moduledoc false
    use Ash.Resource, domain: nil, extensions: [AshCascadeArchival.Resource]

    attributes do
      uuid_primary_key :id
    end

    relationships do
      has_many :post_tags, TestResources.PostTag

      many_to_many :posts, TestResources.Post, through: TestResources.PostTag
    end
  end

  defmodule PostWithExcept do
    @moduledoc false
    use Ash.Resource, domain: nil, extensions: [AshCascadeArchival.Resource]

    cascade_archive do
      except [:post_tags]
    end

    attributes do
      uuid_primary_key :id
    end

    relationships do
      has_many :comments, TestResources.Comment do
        destination_attribute :post_id
      end

      has_many :post_tags, TestResources.PostTag do
        destination_attribute :post_id
      end
    end
  end

  defmodule PostWithFilteredRelationship do
    @moduledoc false
    use Ash.Resource, domain: nil, extensions: [AshCascadeArchival.Resource]

    attributes do
      uuid_primary_key :id
    end

    relationships do
      has_many :comments, TestResources.Comment do
        destination_attribute :post_id
      end

      has_many :published_comments, TestResources.Comment do
        destination_attribute :post_id
        filter expr(published == true)
      end
    end
  end
end
