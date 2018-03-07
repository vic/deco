defmodule Deco.Core do
  @moduledoc false

  defmacro deco({:in, _, [{a, b}, head]}, rest) do
    deco([a, b], head, rest, __CALLER__)
  end

  defmacro deco({:in, _, [{:{}, _, decos}, head]}, rest) do
    deco(decos, head, rest, __CALLER__)
  end

  defp deco(decos, head, rest, env) do
    expr = add_args(:append, head, [rest]) |> Macro.escape()

    decos
    |> Enum.reverse()
    |> Enum.reduce(expr, &add_args(:prepend, &1, [&2]))
    |> Code.eval_quoted([], env)
    |> elem(0)
  end


  @doc false
  @spec add_args(mode :: (:append | :prepend), Macro.t(), [Macro.t()]) :: Macro.t()
  def add_args(mode, call, more_args)

  def add_args(add, {name, meta, args}, more_args) when is_atom(name) do
    args = (is_atom(args) && []) || args
    args = (add == :prepend && [more_args, args]) || [args, more_args]
    {name, meta, Enum.concat(args)}
  end

  def add_args(add, {into = {:., _, _}, meta, args}, more_args) do
    args = (add == :prepend && [more_args, args]) || [args, more_args]
    {into, meta, Enum.concat(args)}
  end

  def add_args(_, call, _more_args) do
    raise "Expected `#{Macro.to_string(call)}` to be a function call"
  end
end
