defmodule RowFilterIntegration do
  @moduledoc false
  alias Bigtable.{MutateRow, MutateRows, Mutations, ReadRows, RowFilter}

  use ExUnit.Case

  setup do
    assert ReadRows.read() == []

    row_keys = ["Test#1", "Test#2", "Test#3", "Other#1", "Other#2"]

    on_exit(fn ->
      IO.puts("Dropping Rows")

      mutations =
        Enum.map(row_keys, fn key ->
          entry = Mutations.build(key)

          entry
          |> Mutations.delete_from_row()
        end)

      mutations
      |> MutateRows.mutate()
    end)

    [
      row_keys: row_keys
    ]
  end

  describe "RowFilter.cells_per_column" do
    test "should properly limit the number of cells returned" do
      seed_multiple_values()

      [ok: raw] = ReadRows.read()

      IO.inspect(raw)

      assert length(raw.chunks) == 3

      [ok: filtered] =
        ReadRows.build()
        |> RowFilter.cells_per_column(1)
        |> ReadRows.read()

      filtered_value = List.first(filtered.chunks) |> Map.get(:value)

      assert length(filtered.chunks) == 1
      assert filtered_value == "3"
    end
  end

  describe "RowFilter.row_key_regex" do
    test "should properly filter rows based on row key", context do
      seed_values(context)

      rows = ReadRows.read()

      assert length(rows) == length(context.row_keys)

      request = ReadRows.build()

      test_filtered =
        request
        |> RowFilter.row_key_regex("^Test#\\w+")
        |> ReadRows.read()

      other_filtered =
        request
        |> RowFilter.row_key_regex("^Other#\\w+")
        |> ReadRows.read()

      assert length(test_filtered) == 3
      assert length(other_filtered) == 2
    end
  end

  describe "RowFilter.value_regex" do
    test "should properly filter a single row based on value", context do
      mutation =
        Mutations.build("Test#1")
        |> Mutations.set_cell("cf1", "column1", "foo")
        |> Mutations.set_cell("cf1", "column2", "bar")
        |> Mutations.set_cell("cf2", "column1", "foo")
        |> Mutations.set_cell("cf2", "column2", "bar")

      {:ok, _} =
        mutation
        |> MutateRow.build()
        |> MutateRow.mutate()

      [ok: result] =
        ReadRows.build()
        |> RowFilter.value_regex("foo")
        |> ReadRows.read()

      assert length(result.chunks) == 2
    end

    test "should properly filter multiple rows based on value", context do
      first_mutation =
        Mutations.build("Test#1")
        |> Mutations.set_cell("cf1", "column1", "foo")
        |> Mutations.set_cell("cf1", "column2", "bar")
        |> Mutations.set_cell("cf2", "column1", "foo")
        |> Mutations.set_cell("cf2", "column2", "bar")

      second_mutation =
        Mutations.build("Test#2")
        |> Mutations.set_cell("cf1", "column1", "foo")
        |> Mutations.set_cell("cf1", "column2", "bar")
        |> Mutations.set_cell("cf2", "column1", "foo")
        |> Mutations.set_cell("cf2", "column2", "bar")

      {:ok, _} =
        [first_mutation, second_mutation]
        |> MutateRows.build()
        |> MutateRows.mutate()

      result =
        ReadRows.build()
        |> RowFilter.value_regex("foo")
        |> ReadRows.read()

      assert length(result) == 2
      chunks = chunks_from_rows(result)
      assert length(chunks) == 4
    end
  end

  describe "RowFilter.family_name_regex" do
    test "should properly filter a single row based on family name", context do
      mutation =
        Mutations.build("Test#1")
        |> Mutations.set_cell("cf2", "cf2-column", "cf2-value")
        |> Mutations.set_cell("cf1", "cf1-column", "cf1-value")
        |> Mutations.set_cell("otherFamily", "other-column", "other-value")

      {:ok, _} =
        mutation
        |> MutateRow.build()
        |> MutateRow.mutate()

      [ok: cf_result] =
        ReadRows.build()
        |> RowFilter.family_name_regex("cf")
        |> ReadRows.read()

      [ok: other_result] =
        ReadRows.build()
        |> RowFilter.family_name_regex("other")
        |> ReadRows.read()

      assert length(cf_result.chunks) == 2
      assert length(other_result.chunks) == 1
    end

    test "should properly filter a multiple rows based on family name", context do
      first_mutation =
        Mutations.build("Test#1")
        |> Mutations.set_cell("cf2", "cf2-column", "cf2-value")
        |> Mutations.set_cell("cf1", "cf1-column", "cf1-value")
        |> Mutations.set_cell("otherFamily", "other-column", "other-value")

      second_mutation =
        Mutations.build("Test#2")
        |> Mutations.set_cell("cf2", "cf2-column", "cf2-value")
        |> Mutations.set_cell("cf1", "cf1-column", "cf1-value")
        |> Mutations.set_cell("otherFamily", "other-column", "other-value")

      {:ok, _} =
        [first_mutation, second_mutation]
        |> MutateRows.build()
        |> MutateRows.mutate()

      cf_result =
        ReadRows.build()
        |> RowFilter.family_name_regex("cf")
        |> ReadRows.read()

      assert length(cf_result) == 2
      cf_chunks = cf_result |> chunks_from_rows()
      assert length(cf_chunks) == 4

      other_result =
        ReadRows.build()
        |> RowFilter.family_name_regex("other")
        |> ReadRows.read()

      assert length(other_result) == 2
      other_chunks = other_result |> chunks_from_rows()
      assert length(other_chunks) == 2
    end
  end

  describe "RowFilter.column_qualifier_regex" do
    test "should properly filter a single row based on column qualifier", context do
      mutation =
        Mutations.build("Test#1")
        |> Mutations.set_cell("cf2", "foo-column", "bar-value")
        |> Mutations.set_cell("cf2", "bar-column", "bar-value")
        |> Mutations.set_cell("cf1", "foo-column", "foo-value")
        |> Mutations.set_cell("cf1", "bar-column", "baz-value")
        |> Mutations.set_cell("otherFamily", "bar-column", "other-value")

      {:ok, _} =
        mutation
        |> MutateRow.build()
        |> MutateRow.mutate()

      [ok: foo_result] =
        ReadRows.build()
        |> RowFilter.column_qualifier_regex("foo")
        |> ReadRows.read()

      [ok: bar_result] =
        ReadRows.build()
        |> RowFilter.column_qualifier_regex("bar")
        |> ReadRows.read()

      assert length(foo_result.chunks) == 2
      assert length(bar_result.chunks) == 3
    end

    test "should properly filter a multiple rows based on column qualifier", context do
      first_mutation =
        Mutations.build("Test#1")
        |> Mutations.set_cell("cf2", "foo-column", "bar-value")
        |> Mutations.set_cell("cf2", "bar-column", "bar-value")
        |> Mutations.set_cell("cf1", "foo-column", "foo-value")
        |> Mutations.set_cell("cf1", "bar-column", "baz-value")
        |> Mutations.set_cell("otherFamily", "bar-column", "other-value")

      second_mutation =
        Mutations.build("Test#2")
        |> Mutations.set_cell("cf2", "foo-column", "bar-value")
        |> Mutations.set_cell("cf2", "bar-column", "bar-value")
        |> Mutations.set_cell("cf1", "foo-column", "foo-value")
        |> Mutations.set_cell("cf1", "bar-column", "baz-value")
        |> Mutations.set_cell("otherFamily", "bar-column", "other-value")

      {:ok, _} =
        [first_mutation, second_mutation]
        |> MutateRows.build()
        |> MutateRows.mutate()

      foo_result =
        ReadRows.build()
        |> RowFilter.column_qualifier_regex("foo")
        |> ReadRows.read()

      assert length(foo_result) == 2
      foo_chunks = foo_result |> chunks_from_rows()
      assert length(foo_chunks) == 4

      bar_result =
        ReadRows.build()
        |> RowFilter.column_qualifier_regex("bar")
        |> ReadRows.read()

      assert length(bar_result) == 2
      bar_chunks = bar_result |> chunks_from_rows()
      assert length(bar_chunks) == 6
    end
  end

  describe "RowFilter.chain" do
    test "should properly apply a chain of filters", context do
      seed_values(context)

      seed_multiple_values()

      filters = [
        RowFilter.row_key_regex("^Test#1"),
        RowFilter.cells_per_column(1)
      ]

      [ok: result] =
        ReadRows.build()
        |> RowFilter.chain(filters)
        |> ReadRows.read()

      assert length(result.chunks) == 1
      assert List.first(result.chunks) |> Map.get(:row_key) == "Test#1"
    end
  end

  defp seed_multiple_values do
    IO.puts("Inserting Rows")

    mutations =
      Enum.map(1..3, fn i ->
        Mutations.build("Test#1")
        |> Mutations.set_cell("cf1", "column", to_string(i), 1000 * i)
      end)

    result =
      mutations
      |> MutateRows.build()
      |> MutateRows.mutate()

    IO.inspect(result)

    IO.puts("Rows Inserted")
  end

  defp seed_values(context) do
    Enum.each(context.row_keys, fn key ->
      {:ok, _} =
        Mutations.build(key)
        |> Mutations.set_cell("cf1", "column", "value")
        |> MutateRow.build()
        |> MutateRow.mutate()
    end)
  end

  defp chunks_from_rows(rows), do: Enum.flat_map(rows, fn {:ok, r} -> r.chunks end)
end
