defmodule AshCascadeArchival.BorrowsSkipTest do
  use ExUnit.Case, async: true

  import Spark.Test

  defmodule BorrowTarget do
    @moduledoc false
    # Archival resource with no reverse relationship at all.
    use Ash.Resource, domain: nil, extensions: [AshCascadeArchival.Resource]

    attributes do
      uuid_primary_key :id
    end

    actions do
      defaults [:read, :destroy]
    end
  end

  test "a belongs_to carrying the :__borrows__ marker needs no reverse relationship" do
    refute_dsl_errors do
      defmodule MarkedBorrower do
        @moduledoc false
        use Ash.Resource,
          domain: nil,
          extensions: [
            AshCascadeArchival.Resource,
            AshCascadeArchival.Test.Support.FakeBorrow
          ]

        attributes do
          uuid_primary_key :id
        end

        relationships do
          fake_borrows(:borrow_target, AshCascadeArchival.BorrowsSkipTest.BorrowTarget)
        end
      end
    end

    rel =
      Ash.Resource.Info.relationship(
        AshCascadeArchival.BorrowsSkipTest.MarkedBorrower,
        :borrow_target
      )

    assert AshCascadeArchival.Helpers.borrows?(rel)
  end

  test "the same shape without the marker still demands a reverse relationship" do
    # The reverse verifier reports plain string errors, not DslError structs.
    error =
      assert_dsl_error error when is_binary(error) do
        defmodule PlainBorrower do
          @moduledoc false
          use Ash.Resource, domain: nil, extensions: [AshCascadeArchival.Resource]

          attributes do
            uuid_primary_key :id
          end

          relationships do
            belongs_to :borrow_target, AshCascadeArchival.BorrowsSkipTest.BorrowTarget
          end
        end
      end

    assert error =~ "has_many or has_one to pair with belongs_to"
  end
end
