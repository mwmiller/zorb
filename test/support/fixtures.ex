defmodule Zorb.TestFixtures do
  @moduledoc false
  @doc """
  Generates a standard Z-machine header for the given version.
  """
  def header(version, opts \\ []) do
    pc = Keyword.get(opts, :pc, 0x0100)
    globals = Keyword.get(opts, :globals, 0x0200)
    objects = Keyword.get(opts, :objects, 0x0300)
    static = Keyword.get(opts, :static, 0x0400)
    dictionary = Keyword.get(opts, :dictionary, 0x0500)
    abbrevs = Keyword.get(opts, :abbreviations, 0x0600)

    # 64-byte header
    header = <<
      # 0x00
      version,
      # 0x01 Flags 1
      0,
      # 0x02 Release
      0,
      0,
      # 0x04 High memory base (unused in tests mostly)
      0,
      0,
      # 0x06 Initial PC
      pc::16,
      # 0x08 Dictionary
      dictionary::16,
      # 0x0A Object Table
      objects::16,
      # 0x0C Globals
      globals::16,
      # 0x0E Static Memory
      static::16,
      # 0x10 Flags 2
      0,
      0,
      # 0x12-0x15 Reserved
      0,
      0,
      0,
      0,
      # 0x16 Serial (part 1)
      0,
      0,
      # 0x18 Abbreviations
      abbrevs::16
    >>

    header <> :binary.copy(<<0>>, 64 - byte_size(header))
  end

  @doc """
  Generates a routine call.
  """
  def call_code(version, routine_packed, result_var \\ 16) do
    if version <= 3 do
      # call (VAR:0) routine, result_var
      <<0xE0, 0x3F, routine_packed::16, result_var>>
    else
      # call_vs (VAR:0) routine, result_var
      <<0xE0, 0x3F, routine_packed::16, result_var>>
    end
  end

  @doc """
  Generates a routine header with the given number of locals.
  """
  def routine_header(version, num_locals, local_values \\ []) do
    if version <= 3 do
      values =
        Enum.take((local_values ++ Stream.repeatedly(fn -> 0 end)) |> Enum.to_list(), num_locals)

      values_bin = for v <- values, into: <<>>, do: <<v::16>>
      <<num_locals, values_bin::binary>>
    else
      <<num_locals>>
    end
  end

  @doc """
  Generates a minimal object table for the given version.
  """
  def object_table(version) do
    defaults = :binary.copy(<<0>>, if(version <= 3, do: 62, else: 126))
    # Object 1: no attributes, no parent/sib/child, props at 0x0800
    obj1 =
      if version <= 3 do
        <<0::32, 0, 0, 0, 0x0800::16>>
      else
        <<0::48, 0::16, 0::16, 0::16, 0x0800::16>>
      end

    defaults <> obj1
  end
end
