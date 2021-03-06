defmodule Absinthe.Schema.Rule.InputOuputTypesCorrectlyPlaced do
  use Absinthe.Schema.Rule

  alias Absinthe.Schema
  alias Absinthe.Type

  @moduledoc false

  @description """
  Only input types may be used as inputs. Input types may not be used as output types

  Input types consist of Scalars, Enums, and Input Objects.
  """

  def explanation(%{data: %{argument: argument, type: type, struct: struct}}) do
    """
    #{inspect(type)} is not a valid input type for argument #{inspect(argument)} because
    it is an #{Macro.to_string(struct)} type. Arguments may only be input types.

    #{@description}
    """
  end

  def explanation(%{data: %{field: field, type: type, struct: struct, parent: parent}}) do
    """
    #{inspect(type)} is not a valid type for field #{inspect(field)} because
    it is an #{Macro.to_string(struct)} type, and the parent of this field is an #{
      Macro.to_string(parent)
    } type.

    #{@description}
    """
  end

  def check(schema) do
    Schema.types(schema)
    |> Enum.flat_map(&check_type(schema, &1))
  end

  defp check_type(schema, %Type.Object{} = type) do
    field_errors =
      for {_, field} <- type.fields,
          field_type = get_type(field, schema),
          !output_type?(field_type) do
        detail = %{
          field: field.identifier,
          type: field_type.identifier,
          struct: field_type.__struct__,
          parent: Type.Object
        }

        report(type.__reference__.location, detail)
      end

    argument_errors =
      for {_, field} <- type.fields,
          {_, arg} <- field.args,
          type = get_type(arg, schema),
          !input_type?(type) do
        detail = %{
          argument: arg.identifier,
          type: type.identifier,
          struct: type.__struct__
        }

        report(type.__reference__.location, detail)
      end

    field_errors ++ argument_errors
  end

  defp check_type(schema, %Type.InputObject{} = type) do
    for {_, field} <- type.fields,
        field_type = get_type(field, schema),
        !input_type?(field_type) do
      detail = %{
        field: field.identifier,
        type: field_type.identifier,
        struct: field_type.__struct__,
        parent: Type.InputObject
      }

      report(type.__reference__.location, detail)
    end
  end

  defp check_type(_, _) do
    []
  end

  defp get_type(%{type: type}, schema) do
    Type.expand(type, schema)
    |> Type.unwrap()
  end

  defp get_type(type, schema) do
    Type.expand(type, schema)
    |> Type.unwrap()
  end

  defp input_type?(%Type.Scalar{}), do: true
  defp input_type?(%Type.Enum{}), do: true
  defp input_type?(%Type.InputObject{}), do: true
  defp input_type?(_), do: false

  defp output_type?(%Type.InputObject{}), do: false
  defp output_type?(_), do: true
end
