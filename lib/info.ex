defmodule AshCascadeArchival.Info do
  use Spark.InfoGenerator, extension: AshCascadeArchival.Resource, sections: [:cascade_archive]
end
