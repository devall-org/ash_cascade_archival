defmodule AshCascadeArchival.MixProject do
  use Mix.Project

  def project do
    [
      app: :ash_cascade_archival,
      version: "0.4.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      consolidate_protocols: Mix.env() not in [:dev, :test],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description:
        "Automatically sets `archive_related` from `ash_archival` for all fully-contained child relationships.",
      package: package(),
      source_url: "https://github.com/devall-org/ash_cascade_archival",
      homepage_url: "https://github.com/devall-org/ash_cascade_archival",
      docs: [
        main: "readme",
        extras: ["README.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ash, ">= 0.0.0"},
      {:ash_archival, ">= 0.0.0"},
      {:spark, ">= 0.0.0"},
      {:inflex, ">= 0.0.0"},
      {:sourceror, ">= 0.0.0", only: [:dev, :test], optional: true},
      {:ex_doc, "~> 0.29", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      name: "ash_cascade_archival",
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/devall-org/ash_cascade_archival"
      }
    ]
  end
end
