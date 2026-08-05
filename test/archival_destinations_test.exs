defmodule AshCascadeArchival.ArchivalDestinationsTest do
  use ExUnit.Case, async: true

  import Spark.Test

  defmodule NonArchivalChild do
    @moduledoc false
    use Ash.Resource, domain: nil

    attributes do
      uuid_primary_key :id
      attribute :parent_id, :uuid, public?: true
    end
  end

  test "a cascade into a hard-destroy destination without opt-in is rejected" do
    error =
      assert_dsl_error %Spark.Error.DslError{} do
        defmodule ParentOfHardDestroyChild do
          @moduledoc false
          use Ash.Resource, domain: nil, extensions: [AshCascadeArchival.Resource]

          attributes do
            uuid_primary_key :id
          end

          relationships do
            has_many :children, AshCascadeArchival.ArchivalDestinationsTest.DeletableChild do
              destination_attribute :parent_id
            end
          end
        end
      end

    assert error.message =~ "HARD-DELETE"
  end

  test "a cascade into a destination without a primary destroy action is rejected" do
    error =
      assert_dsl_error %Spark.Error.DslError{} do
        defmodule ParentOfNoDestroyChild do
          @moduledoc false
          use Ash.Resource, domain: nil, extensions: [AshCascadeArchival.Resource]

          attributes do
            uuid_primary_key :id
          end

          relationships do
            has_many :children, AshCascadeArchival.ArchivalDestinationsTest.NonArchivalChild do
              destination_attribute :parent_id
            end
          end
        end
      end

    assert error.message =~ "no primary destroy action"
  end

  defmodule DeletableChild do
    @moduledoc false
    use Ash.Resource, domain: nil

    attributes do
      uuid_primary_key :id
      attribute :parent_id, :uuid, public?: true
    end

    actions do
      defaults [:read, :destroy]
    end
  end

  test "hard_delete opts a non-archival destination into the cascade" do
    refute_dsl_errors do
      defmodule ParentWithHardDelete do
        @moduledoc false
        use Ash.Resource, domain: nil, extensions: [AshCascadeArchival.Resource]

        cascade_archive do
          hard_delete [:children]
        end

        attributes do
          uuid_primary_key :id
        end

        relationships do
          has_many :children, AshCascadeArchival.ArchivalDestinationsTest.DeletableChild do
            destination_attribute :parent_id
          end
        end
      end
    end

    archive_related =
      AshArchival.Resource.Info.archive_archive_related!(
        AshCascadeArchival.ArchivalDestinationsTest.ParentWithHardDelete
      )

    assert archive_related == [:children]
  end

  test "hard_delete on an archival destination is rejected as misleading" do
    error =
      assert_dsl_error %Spark.Error.DslError{} do
        defmodule ParentWithMisleadingHardDelete do
          @moduledoc false
          use Ash.Resource, domain: nil, extensions: [AshCascadeArchival.Resource]

          cascade_archive do
            hard_delete [:children]
          end

          attributes do
            uuid_primary_key :id
          end

          relationships do
            has_many :children, AshCascadeArchival.Test.Support.TestResources.Comment do
              destination_attribute :post_id
            end
          end
        end
      end

    assert error.message =~ "misleading"
  end

  test "hard_delete destination without a primary destroy action is rejected" do
    error =
      assert_dsl_error %Spark.Error.DslError{} do
        defmodule ParentWithUndeletableHardDelete do
          @moduledoc false
          use Ash.Resource, domain: nil, extensions: [AshCascadeArchival.Resource]

          cascade_archive do
            hard_delete [:children]
          end

          attributes do
            uuid_primary_key :id
          end

          relationships do
            has_many :children, AshCascadeArchival.ArchivalDestinationsTest.NonArchivalChild do
              destination_attribute :parent_id
            end
          end
        end
      end

    assert error.message =~ "no primary destroy action"
  end

  test "hard_delete naming a relationship outside archive_related raises" do
    assert_raise RuntimeError, ~r/not part of archive_related/, fn ->
      defmodule ParentWithUnknownHardDelete do
        @moduledoc false
        use Ash.Resource, domain: nil, extensions: [AshCascadeArchival.Resource]

        cascade_archive do
          hard_delete [:nonexistent]
        end

        attributes do
          uuid_primary_key :id
        end

        relationships do
          has_many :children, AshCascadeArchival.ArchivalDestinationsTest.DeletableChild do
            destination_attribute :parent_id
          end
        end
      end
    end
  end

  defmodule ManualArchiveImpl do
    @moduledoc false
    use Ash.Resource.ManualDestroy

    @impl true
    def destroy(changeset, _opts, _context), do: {:ok, changeset.data}
  end

  defmodule ManualArchiveChild do
    @moduledoc false
    # Soft destroy with no changes but a manual implementation: the manual
    # implementation is presumed to archive, so cascading into it is allowed.
    use Ash.Resource, domain: nil

    attributes do
      uuid_primary_key :id
      attribute :parent_id, :uuid, public?: true
    end

    actions do
      defaults [:read]

      destroy :destroy do
        primary? true
        soft? true
        require_atomic? false
        manual AshCascadeArchival.ArchivalDestinationsTest.ManualArchiveImpl
      end
    end
  end

  test "a soft destroy with a manual implementation is accepted" do
    refute_dsl_errors do
      defmodule ParentOfManualArchiveChild do
        @moduledoc false
        use Ash.Resource, domain: nil, extensions: [AshCascadeArchival.Resource]

        attributes do
          uuid_primary_key :id
        end

        relationships do
          has_many :children, AshCascadeArchival.ArchivalDestinationsTest.ManualArchiveChild do
            destination_attribute :parent_id
          end
        end
      end
    end
  end

  test "a no-op soft destroy (no changes, no manual) is rejected" do
    defmodule NoOpSoftChild do
      @moduledoc false
      use Ash.Resource, domain: nil

      attributes do
        uuid_primary_key :id
        attribute :parent_id, :uuid, public?: true
      end

      actions do
        defaults [:read]

        destroy :destroy do
          primary? true
          soft? true
          require_atomic? false
        end
      end
    end

    error =
      assert_dsl_error %Spark.Error.DslError{} do
        defmodule ParentOfNoOpSoftChild do
          @moduledoc false
          use Ash.Resource, domain: nil, extensions: [AshCascadeArchival.Resource]

          attributes do
            uuid_primary_key :id
          end

          relationships do
            has_many :children, AshCascadeArchival.ArchivalDestinationsTest.NoOpSoftChild do
              destination_attribute :parent_id
            end
          end
        end
      end

    assert error.message =~ "would do nothing"
  end

  test "excluding the non-archival destination with except compiles cleanly" do
    refute_dsl_errors do
      defmodule ParentWithExceptedNonArchival do
        @moduledoc false
        use Ash.Resource, domain: nil, extensions: [AshCascadeArchival.Resource]

        cascade_archive do
          except [:children]
        end

        attributes do
          uuid_primary_key :id
        end

        relationships do
          has_many :children, AshCascadeArchival.ArchivalDestinationsTest.NonArchivalChild do
            destination_attribute :parent_id
          end
        end
      end
    end
  end
end
