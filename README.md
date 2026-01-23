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

## Finding Games

Zorb is an interpreter only and does not include any game files. To find legal, open-source, or creative commons interactive fiction to play, we recommend the following resources:

*   **[IFDB (Interactive Fiction Database)](https://ifdb.org/):** Search for "Z-code" and filter by "Freeware" or "Public Domain."
    *   *Search Tip:* Look for games written with **PunyInform**, which are specifically optimized for the V3/V5 format.
*   **[PunyInform Games](https://github.com/johanberntsson/PunyInform):** Many modern games created for retro-computing challenges use this library and are free to distribute.
*   **[Interactive Fiction Archive](http://www.ifarchive.org/indexes/if-archive/games/zcode/):** A massive repository of community-created Z-code games.

Please respect the copyright and licensing terms provided by the authors of these games.

