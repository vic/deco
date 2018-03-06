# Deco - Minimalist Function Decorators for Elixir.

<a href="https://travis-ci.org/vic/deco"><img src="https://travis-ci.org/vic/deco.svg"></a>
[hexdocs](https://hexdocs.pm/deco).

Yes, yet another package for decorating elixir functions :).

However, `deco`'s [core is minimalist](https://github.com/vic/deco/blob/master/lib/deco/core.ex) in comparission to others, 
uses much less magic, does not overrides anything like `Kernel.def` 
nor any operator.

`deco` has only one macro, decorators themselves are just plain functions
`Macro.t() -> Macro.t()`, and imposes no run-time overhead because
function decoration is performed at compile-time.

## Usage

The syntax is `deco DECORATORS in FORM` where decorators is a tuple of
one or more decorators, and form is tipically a function definition.

`decorators` are just plain functions you write that take the AST of
`FORM` and just return a modified AST of it. The `Deco` module has
some convenience functions for updating the AST.

Since `deco` runs at compile time, you cannot use functions being 
defined in the same module that is using `deco`. Normally it's better
to define your decorators on a separate module.

The following example [taken from a test](https://github.com/vic/deco/blob/master/test/deco_test.exs#L79) decorates a function with 
a `Logger` tracer that will print the arguments given before applying
to the original function, and the its final result.

```elixir
   deco { Trace.trace() } in
   def foo(x) do
     x
   end
```

Decorators can take arguments, the AST will be prepended to the list
of arguments given by you.
For example, [Deco.pipe_result](https://github.com/vic/deco/blob/master/test/deco_test.exs#L79) will as it name implies just pipe the 
function return value into the code given as argument to the decorator.

```elixir
   deco { Deco.pipe_result(to_string) } in
   def foo(x) when is_atom(x) do
     x
   end
```

Decorators can be composed, the one at the end will take the original
AST and produce a new one for the one on top of it.

```elixir
   deco {
     Deco.pipe_result(String.capitalize()),
     Deco.pipe_result(String.reverse()),
     Deco.pipe_result(to_string)
   } in
   def foo(x) do
     x
   end
   
   foo(:john)
   => "Nhoj
```

For more examples, see the [tests](https://github.com/vic/deco/blob/master/test/deco_test.exs) and the [use the source, Luke](https://github.com/vic/deco/blob/master/lib/deco.ex)

## AuthDeco

This example was adapted from [arjan/decorator](https://github.com/arjan/decorator) to show how
it look like. The main difference is, here we either access the argument variables as they
are present on the function head or create fresh variables for each argument, because it's even
possible that some arguments are just pattern matched and not bound by any variable on the
function definition.

```
   deco {AuthDeco.is_authorized} in
   def create(%Plug.Conn{}, %{}) do
     ...
   end
```


```elixir
defmodule AuthDeco do
  def is_authorized(defun) do
    # create a new variable for each arg
    {defun, args} = Deco.intro_args(defun)
    defun |> Deco.update_body(fn body ->
      quote do
        # get the args we are interested in
        [conn | _] = unquote(args)
        if conn.assigns.user do
          unquote(body)
        else
          conn
          |> send_resp(401, "unauthorized")
          |> halt()
        end
      end
    end)
  end
end
```


## Installation

```elixir
def deps do
  [
    {:deco, "~> 0.1"}
  ]
end
```


