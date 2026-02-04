defmodule Zorb.Interpreter.Types do
  @moduledoc false

  defmodule ZChar do
    @moduledoc false
    @behaviour Orb.CustomType
    def wasm_type, do: :i32
  end

  defmodule ZWord do
    @moduledoc false
    @behaviour Orb.CustomType
    def wasm_type, do: :i32
  end

  defmodule Address do
    @moduledoc false
    @behaviour Orb.CustomType
    def wasm_type, do: :i32
  end

  defmodule PackedAddress do
    @moduledoc false
    @behaviour Orb.CustomType
    def wasm_type, do: :i32
  end

  defmodule Object do
    @moduledoc false
    @behaviour Orb.CustomType
    def wasm_type, do: :i32
  end

  defmodule Property do
    @moduledoc false
    @behaviour Orb.CustomType
    def wasm_type, do: :i32
  end

  defmodule Variable do
    @moduledoc false
    @behaviour Orb.CustomType
    def wasm_type, do: :i32
  end
end
