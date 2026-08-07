defmodule AshCascadeArchival.UseOrderTest do
  use ExUnit.Case, async: true

  import Spark.Test

  defmodule Group do
    @moduledoc false
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshArchival.Resource, AshCascadeArchival.Test.Support.FakeUses]

    attributes do
      uuid_primary_key :id
    end

    actions do
      defaults [:read, :destroy]
    end

    relationships do
      belongs_to :parent, AshCascadeArchival.UseOrderTest.Parent

      fake_used_by :members, AshCascadeArchival.UseOrderTest.Member do
        destination_attribute :group_id
      end
    end
  end

  defmodule Member do
    @moduledoc false
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshArchival.Resource, AshCascadeArchival.Test.Support.FakeUses]

    attributes do
      uuid_primary_key :id
    end

    actions do
      defaults [:read, :destroy]
    end

    relationships do
      belongs_to :parent, AshCascadeArchival.UseOrderTest.Parent
      fake_uses(:group, AshCascadeArchival.UseOrderTest.Group)
    end
  end

  test "a used destination archived before its user is rejected" do
    error =
      assert_dsl_error %Spark.Error.DslError{} do
        defmodule Parent do
          @moduledoc false
          use Ash.Resource,
            domain: nil,
            data_layer: Ash.DataLayer.Ets,
            extensions: [AshArchival.Resource, AshCascadeArchival.Resource]

          attributes do
            uuid_primary_key :id
          end

          actions do
            defaults [:read, :destroy]
          end

          relationships do
            # Alphabetically :groups precedes :members, but Member uses
            # Group, so archiving groups first would abort the cascade.
            has_many :groups, AshCascadeArchival.UseOrderTest.Group
            has_many :members, AshCascadeArchival.UseOrderTest.Member
          end
        end
      end

    assert error.message =~ "archive_last [:members, :groups]"
  end

  test "declaring the order explicitly resolves it" do
    refute_dsl_errors do
      defmodule OrderedParent do
        @moduledoc false
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Ets,
          extensions: [AshArchival.Resource, AshCascadeArchival.Resource]

        attributes do
          uuid_primary_key :id
        end

        actions do
          defaults [:read, :destroy]
        end

        relationships do
          has_many :groups, AshCascadeArchival.UseOrderTest.Group do
            destination_attribute :parent_id
          end

          has_many :members, AshCascadeArchival.UseOrderTest.Member do
            destination_attribute :parent_id
          end
        end

        cascade_archive do
          archive_last([:groups])
        end
      end
    end
  end
end
