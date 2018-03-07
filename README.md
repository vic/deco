# Deco - Minimalist function decorators and around-advice for Elixir.

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

```elixir
use Deco
```

The syntax is `deco DECORATORS in FORM` where decorators is a tuple of
one or more decorators, and form is tipically a function definition.

`decorators` are just plain functions you write that take the AST of
`FORM` and just return a modified AST of it. The `Deco` module has
some convenience functions for updating the AST.

Since `deco` runs at compile time, you cannot use functions being 
defined in the same module that is using `deco`. Normally it's better
to define your decorators on a separate module.

The following example decorates the function with a 
[tracer](https://github.com/vic/deco/blob/master/lib/deco/trace.ex) 
that will use `Logger` to print the arguments given before applying
the original function, and the its final result.

```elixir
   deco { Trace.trace() } in
   def foo(x) do
     x
   end
```

Decorators can take arguments, the AST will be prepended to the list
of arguments given by you.

Also, because decorators operate on the AST they have full access to it
allowing them to for example, introduce new guards or remove them.

```elixir
   deco { Deco.update_guard(fn _ -> nil end) } in
   def foo(x) when is_atom(x) do
     x
   end
   
   foo("hey")
   => "hey"
```

Decorators can be composed, the one at the end will take the original
AST and produce a new one for the one on top of it.

```elixir
   deco {
     Deco.pipe_result(String.capitalize),
     Deco.pipe_result(String.reverse),
     Deco.pipe_result(to_string)
   } in
   def foo(x) do
     x
   end
   
   foo(:john)
   => "Nhoj
```

You can decorate using a simple function, without having to mess with
the AST if you dont want to. The `Deco.around` decorator will act as
an _around advice_ and will give you a reference to the decorated 
function (made private) and all the arguments given on invocation.

```elixir
   # our private around advice
   defp bar_wrapper(decorated, name, say) do
     "#{say} #{decorated.(name)}"
   end

   deco {Deco.around( bar_wrapper("hello") )} in
   def bar(name) do
     name |> String.capitalize
   end


   bar("world")
   => "hello World"
```

For more examples, see the [tests](https://github.com/vic/deco/blob/master/test/deco_test.exs) or [use the source, Luke](https://github.com/vic/deco/blob/master/lib/deco.ex)

## AuthDeco

This example was adapted from [arjan/decorator](https://github.com/arjan/decorator) to show how
it would look like using deco. 

```elixir
   defp is_authorized(decorated, conn, params) do
      if conn.assigns.user do
        decorated.(conn, params)
      else
        conn
        |> send_resp(401, "unauthorized")
        |> halt()
      end
   end

   deco {Deco.around(is_authorized)} in
   def create(conn, params) do
     ...
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


