defmodule Zorb.MixProject do
  use Mix.Project

  def project do
    [
      app: :zorb,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      aliases: aliases()
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
      {:wasmex, "~> 0.14.0"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:sourceror, "~> 1.7"}
    ]
  end
end
