defmodule AshCascadeArchival.TransformerTest do
  use ExUnit.Case, async: true

  alias AshCascadeArchival.Test.Support.TestResources

  describe "archive_related configuration" do
    test "Author has posts and comments in archive_related, alphabetically ordered" do
      archive_related = AshArchival.Resource.Info.archive_archive_related!(TestResources.Author)

      assert archive_related == [:comments, :posts]
    end

    test "Post has comments and post_tags in archive_related, alphabetically ordered" do
      archive_related = AshArchival.Resource.Info.archive_archive_related!(TestResources.Post)

      assert archive_related == [:comments, :post_tags]
    end

    test "Comment has no child relationships in archive_related" do
      archive_related = AshArchival.Resource.Info.archive_archive_related!(TestResources.Comment)

      assert archive_related == []
    end

    test "PostTag has no child relationships in archive_related" do
      archive_related = AshArchival.Resource.Info.archive_archive_related!(TestResources.PostTag)

      assert archive_related == []
    end

    test "Tag has post_tags in archive_related" do
      archive_related = AshArchival.Resource.Info.archive_archive_related!(TestResources.Tag)

      assert archive_related == [:post_tags]
    end
  end

  describe "except option" do
    test "PostWithExcept excludes post_tags from archive_related" do
      archive_related =
        AshArchival.Resource.Info.archive_archive_related!(TestResources.PostWithExcept)

      assert archive_related == [:comments]
    end
  end

  describe "only option" do
    test "PostWithOnly includes only comments in archive_related" do
      archive_related =
        AshArchival.Resource.Info.archive_archive_related!(TestResources.PostWithOnly)

      assert archive_related == [:comments]
    end

    test "PostWithEmptyOnly includes no relationships in archive_related" do
      archive_related =
        AshArchival.Resource.Info.archive_archive_related!(TestResources.PostWithEmptyOnly)

      assert archive_related == []
    end
  end

  describe "order option" do
    test "PostWithOrder overrides the alphabetical order with declared pairs" do
      archive_related =
        AshArchival.Resource.Info.archive_archive_related!(TestResources.PostWithOrder)

      assert archive_related == [:post_tags, :comments]
    end

    test "order pairs naming relationships outside archive_related raise" do
      assert_raise RuntimeError, ~r/not part of archive_related/, fn ->
        defmodule PostWithUnknownOrder do
          @moduledoc false
          use Ash.Resource, domain: nil, extensions: [AshCascadeArchival.Resource]

          cascade_archive do
            order [{:comments, :nonexistent}]
          end

          attributes do
            uuid_primary_key :id
          end

          relationships do
            has_many :comments, AshCascadeArchival.Test.Support.TestResources.Comment do
              destination_attribute :post_id
            end
          end
        end
      end
    end

    test "order pairs forming a cycle raise" do
      assert_raise RuntimeError, ~r/cycle/, fn ->
        defmodule PostWithCyclicOrder do
          @moduledoc false
          use Ash.Resource, domain: nil, extensions: [AshCascadeArchival.Resource]

          cascade_archive do
            order [{:comments, :post_tags}, {:post_tags, :comments}]
          end

          attributes do
            uuid_primary_key :id
          end

          relationships do
            has_many :comments, AshCascadeArchival.Test.Support.TestResources.Comment do
              destination_attribute :post_id
            end

            has_many :post_tags, AshCascadeArchival.Test.Support.TestResources.PostTag do
              destination_attribute :post_id
            end
          end
        end
      end
    end
  end

  describe "borrowed_by exclusion" do
    test "a has_many carrying the :__borrowed_by__ marker is not fully contained" do
      plain = %Ash.Resource.Relationships.HasMany{
        no_attributes?: false,
        manual: nil,
        filters: []
      }

      assert AshCascadeArchival.Helpers.fully_contained_child?(plain)

      refute AshCascadeArchival.Helpers.fully_contained_child?(
               Map.put(plain, :__borrowed_by__, true)
             )
    end

    test "a belongs_to carrying the :__borrows__ marker is recognized" do
      plain = %Ash.Resource.Relationships.BelongsTo{}

      refute AshCascadeArchival.Helpers.borrows?(plain)
      assert AshCascadeArchival.Helpers.borrows?(Map.put(plain, :__borrows__, true))
    end
  end

  describe "filtered relationships" do
    test "PostWithFilteredRelationship only includes unfiltered comments" do
      archive_related =
        AshArchival.Resource.Info.archive_archive_related!(
          TestResources.PostWithFilteredRelationship
        )

      assert archive_related == [:comments]
    end
  end
end
