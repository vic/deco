require Logger

defmodule DecoTest.MyDecos do
  @doc """
  Replaces with a completely new hello function
  """
  def goodbye(_hello) do
    quote do
      def hello(_) do
        :adios
      end
    end
  end

  @doc """
  Reverses the argument order on the function
  """
  def reverse_args(defun) do
    defun |> Deco.update_head(fn {name, m, args} ->
      {name, m, Enum.reverse(args)}
    end)
  end

  @doc """
  What an is_authorized plug decoration would look
  """
  def is_authorized(defun) do
    # create a new variable for each arg
    {defun, args} = Deco.intro_args(defun)
    defun |> Deco.update_body(fn body ->
      quote do
        # get the argument we want
        [conn | _] = unquote(args)
        if is_list(conn) do
          unquote(body)
        else
          :halted
        end
      end
    end)
  end

end

defmodule DecoTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  use Deco

  alias __MODULE__.MyDecos

  deco {MyDecos.goodbye()} in
  def(hello(x)) do
    x
  end

  test "replaced whole function definition" do
    assert hello(:world) == :adios
  end

  deco {
    Deco.pipe_result(String.capitalize()),
    Deco.pipe_result(String.reverse()),
    Deco.pipe_result(to_string)
  } in
  def(hey(x)) do
    x
  end

  test "upcased via decorators composition" do
    assert hey(:john) == "Nhoj"
  end

  deco {Deco.update_guard(fn _ -> nil end)} in
  def(never(x) when x == :do_this) do
    x
  end

  test "removed guard bad boy" do
    assert never(22) == 22
  end

  deco {MyDecos.reverse_args} in
  def pair(a, b) do
    {a, b}
  end

  test "update head" do
    assert {1, 2} == pair(2, 1)
  end


  deco {Deco.Trace.trace, Deco.pipe_result(String.upcase)} in
  def traced(x) when is_binary(x) do
    x
  end

  test "trace" do
    out = capture_log fn ->
      assert "HELLO" == traced("hello")
    end
    assert String.contains?(out, "called")
    assert String.contains?(out, "result")
  end

  test "trace args even if no function matches" do
    out = capture_log fn ->
      assert_raise FunctionClauseError, fn ->
        traced(:no_match)
      end
    end
    assert String.contains?(out, "called")
    refute String.contains?(out, "result")
  end


  deco {MyDecos.is_authorized} in
  def access(_) do
    :granted
  end

  test "is_authorized" do
    assert :halted == access(nil)
    assert :granted == access([user: :me])
  end
end
