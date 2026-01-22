# Zorb

Zorb is a WebAssembly Z-machine interpreter implemented in Elixir using the Orb DSL. It aims to provide a fast, safe, and portable way to run Infocom-style interactive fiction in any WebAssembly environment.

## Current Progress
Most core V3 and V4 opcodes are implemented, including routine management, object table navigation/manipulation, and Z-string abbreviation expansion. See `AGENTS.md` for a detailed status.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `zorb` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:zorb, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/zorb>.

