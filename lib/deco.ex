defmodule Deco do
  @moduledoc File.read!(Path.expand("../README.md", __DIR__))

  @doc false
  defmacro __using__(_) do
    quote do
      import Deco.Core, only: [deco: 2]
    end
  end

  @type updater :: (Macro.t() -> Macro.t())

  @doc """
  Pipes the result of the decorated function into `pipe`.

  # Example

      deco {Deco.pipe_result(to_string)} in
      def foo(x), do: x

      foo(:hello)
      => "hello"

  """
  @spec pipe_result(defun :: Macro.t(), pipe :: Macro.t()) :: Macro.t()
  defmacro pipe_result(defun, pipe) do
    quote bind_quoted: [pipe: Macro.escape(pipe), defun: defun] do
      defun |> Deco.update_do(fn body -> {:|>, [], [body, pipe]} end)
    end
  end

  @doc """
  Lets you update the decorated function body

  Note that `updater` function takes the quoted
  body and should also return another quoted
  expression.

      deco {Deco.update_do(fn _ -> :yes end)}
      def foo, do: :ok

      foo()
      => :yes

  Using this decorator you can rescue exceptions
  and turn them into erlang tagged tuples:

      defmodule MyDecos do
        def ok_or_error(defun) do
          defun |> Deco.update_do(fn body ->
            quote do
              try do
                {:ok, unquote(body)}
              rescue
                error -> {:error, error}
              end
            end
          end)
        end
      end


      deco {MyDecos.ok_or_error} in
      def foo() do
        raise "Oops"
      end

      foo()
      => {:error, %RuntimeError{message: "Oops"}}
  """
  @spec update_do(defun :: Macro.t(), updater :: updater) :: Macro.t()
  def update_do(defun, updater)

  def update_do(expr = {:def, _, _}, fun) do
    update_def_key(expr, do: fun)
  end

  @doc "Alias for update_do"
  @spec update_body(defun :: Macro.t(), updater :: updater) :: Macro.t()
  def update_body(defun, updater) do
    update_do(defun, updater)
  end


  @doc """
  Lets you update the function definition head
  """
  @spec update_head(defun :: Macro.t(), updater :: updater) :: Macro.t()
  def update_head(defun, updater)
  def update_head({:def, m, [{:when, _, [head, guard]}, opts]}, fun) do
    update_head(head, m, guard, opts, fun)
  end
  def update_head({:def, m, [head, opts]}, fun) do
    update_head(head, m, _guard = nil, opts, fun)
  end

  defp update_head(head, m, guard, opts, fun) do
    head = fun.(head)
    case guard do
      nil -> {:def, m, [head, opts]}
      guard -> {:def, m, [{:when, m, [head, guard]}, opts]}
    end
  end

  @doc """
  Get the head of the function definition. `name(args)`
  """
  @spec get_head(defun :: Macro.t()) :: Macro.t()
  def get_head(defun)
  def get_head({:def, _, [{:when, _, [head, _]}, _]}), do: head
  def get_head({:def, _, [head, _]}), do: head

  @spec get_name(defun :: Macro.t()) :: atom
  def get_name(defun) do
    {name, _, _args} = get_head(defun)
    name
  end

  @spec get_args(defun :: Macro.t()) :: list(Macro.t())
  def get_args(defun) do
    {_, _, args} = get_head(defun)
    args
  end

  @spec update_args(defun :: Macro.t(), updater) :: Macro.t()
  def update_args(defun, updater) do
    update_head(defun, fn {name, m, args} ->
      {name, m, updater.(args)}
    end)
  end

  @doc """
  Creates a list of fresh variables, one per each formal argument in head.
  """
  def fresh_args(defun, context \\ __MODULE__) do
    defun |> get_args |> Enum.count |> Macro.generate_arguments(context)
  end

  @doc """
  Make the function definition private, prefixing its name with `prefix`
  """
  def privatize(defun, prefix) do
    defun = update_head(defun, fn {name, c, a} -> {:"#{prefix}#{name}", c, a} end)
    case defun do
      {:def, c, d} -> {:defp, c, d}
      {:defmacro, c, d} -> {:defmacrop, c, d}
      x -> x
    end
  end

  @doc """
  Generates and binds a new variable to each formal parameter

  Returns a tuple of the updated defun and a list of the bound argument variables.
  """
  @spec intro_args(defun :: Macro.t(), context :: atom) :: {Macro.t(), list(Macro.t())}
  def intro_args(defun, context \\ __MODULE__) do
    vars = fresh_args(defun, context)
    args = get_args(defun)
    args = Enum.zip([vars, args]) |> Enum.map(fn {v, a} ->
      quote do: unquote(v) = unquote(a)
    end)
    defun = update_args(defun, fn _ -> args end)
    {defun, vars}
  end


  @doc """
  Lets you update or remove the function definition guard.

  The `updater` function will receive the AST of the current guard
  or nil if none was defined.

  If nil is returned by `updater`, the guard is removed from
  the decorated function.
  """
  @spec update_guard(defun :: Macro.t(), updater :: updater) :: Macro.t()
  def update_guard(defun, updater)

  def update_guard({:def, m, [{:when, _, [head, guard]}, opts]}, fun) do
    update_guard(guard, m, head, opts, fun)
  end

  def update_guard({:def, m, [head, opts]}, fun) do
    update_guard(nil, m, head, opts, fun)
  end

  defp update_guard(guard, m, head, opts, fun) do
    case fun.(guard) do
      nil -> {:def, m, [head, opts]}
      guard -> {:def, m, [{:when, m, [head, guard]}, opts]}
    end
  end

  defp update_def_key({:def, meta, [head, opts]}, [{key, fun}]) do
    opts = update_in(opts[key], fun)
    {:def, meta, [head, opts]}
  end

end
