defmodule Deco.Trace do

  @doc """
  Traces function execution via Logger.info

  Prints the arguments given and the result of the decorated function.

  This implementation prints the arguments before applying them to
  the decorated function, thus you'll see what was called even if
  no function guards matches.

  This example converts its decorated function into private.
  """
  def trace(defun) do
    name = Deco.get_name(defun)
    args = Deco.get_args(defun) |> Enum.count |> Macro.generate_arguments(__MODULE__)

    {_, m, defm} = defun |> Deco.update_head(fn {_, m, args} -> {:"__#{name}", m, args} end)
    private = {:defp, m, defm}

    logger = quote do
      def unquote(name)(unquote_splicing(args)) do
        Logger.info fn ->
          """
          [called] #{__MODULE__}.#{unquote(name)}(#{inspect(unquote(args))})
          """
        end
        result = unquote(:"__#{name}")(unquote_splicing(args))
        Logger.info fn ->
          """
          [result] #{__MODULE__}.#{unquote(name)}: #{inspect(result)}
          """
        end
        result
      end
    end

    quote do
      unquote(private)
      unquote(logger)
    end
  end

end
