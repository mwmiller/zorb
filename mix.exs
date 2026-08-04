defmodule Zorb.MixProject do
  use Mix.Project

  def project do
    [
      app: :zorb,
      version: "0.9.2",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      aliases: aliases(),
      description: description(),
      package: package(),
      name: "Zorb",
      source_url: "https://github.com/mwmiller/zorb",
      docs: [
        main: "Zorb",
        extras: [
          "README.md",
          "usage-rules.md",
          "CAPSULE_HOST.md",
          "CHANGELOG.md",
          "ORB_CONCEPTS.md",
          "ZMACHINE.md"
        ]
      ],
      compilers: Mix.compilers(),
      elixirc_options: [
        all_warnings: true
      ]
    ]
  end

  defp description do
    "Z-machine implementation compiling stories into standalone WebAssembly capsules"
  end

  defp package do
    [
      maintainers: ["Matthew Miller"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/mwmiller/zorb"},
      files:
        ~w(lib mix.exs README.md LICENSE usage-rules.md CAPSULE_HOST.md CHANGELOG.md ORB_CONCEPTS.md ZMACHINE.md)
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  defp aliases do
    [
      precommit: ["format --check-formatted", "credo --strict", "test"]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:orb, "~> 0.2.2"},
      {:watusi, "~> 0.6.2"},
      {:wasmex, "~> 0.14.0", only: [:dev, :test]},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:usage_rules, "~> 1.2", only: [:dev, :test], runtime: false},
      {:sourceror, "~> 1.12"},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end
end
