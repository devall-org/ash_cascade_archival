defmodule AshCascadeArchival.TransformerTest do
  use ExUnit.Case, async: true

  alias AshCascadeArchival.Test.Support.TestResources

  describe "archive_related configuration" do
    test "Author has posts and comments in archive_related" do
      archive_related = AshArchival.Resource.Info.archive_archive_related!(TestResources.Author)

      assert Enum.sort(archive_related) == [:comments, :posts]
    end

    test "Post has comments and post_tags in archive_related" do
      archive_related = AshArchival.Resource.Info.archive_archive_related!(TestResources.Post)

      assert Enum.sort(archive_related) == [:comments, :post_tags]
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
