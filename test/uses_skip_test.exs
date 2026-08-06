defmodule AshCascadeArchival.UsesSkipTest do
  use ExUnit.Case, async: true

  import Spark.Test

  defmodule UseTarget do
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

  test "a belongs_to carrying the :__uses__ marker needs no reverse relationship" do
    refute_dsl_errors do
      defmodule MarkedUser do
        @moduledoc false
        use Ash.Resource,
          domain: nil,
          extensions: [
            AshCascadeArchival.Resource,
            AshCascadeArchival.Test.Support.FakeUses
          ]

        attributes do
          uuid_primary_key :id
        end

        relationships do
          fake_uses(:use_target, AshCascadeArchival.UsesSkipTest.UseTarget)
        end
      end
    end

    rel =
      Ash.Resource.Info.relationship(
        AshCascadeArchival.UsesSkipTest.MarkedUser,
        :use_target
      )

    assert AshCascadeArchival.Helpers.uses?(rel)
  end

  test "the same shape without the marker still demands a reverse relationship" do
    # The reverse verifier reports plain string errors, not DslError structs.
    error =
      assert_dsl_error error when is_binary(error) do
        defmodule PlainUser do
          @moduledoc false
          use Ash.Resource, domain: nil, extensions: [AshCascadeArchival.Resource]

          attributes do
            uuid_primary_key :id
          end

          relationships do
            belongs_to :use_target, AshCascadeArchival.UsesSkipTest.UseTarget
          end
        end
      end

    assert error =~ "has_many or has_one to pair with belongs_to"
  end
end
