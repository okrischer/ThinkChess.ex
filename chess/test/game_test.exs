defmodule GameTest do
  use ExUnit.Case
  alias Chess.Game

  test "new_game returns a new game" do
    %{board: b, turn: t, castling: c, passant: p, game_state: gs} = Game.new_game()
    assert b["d8"] == ?q
    assert b["e8"] == ?k
    assert b["d1"] == ?Q
    assert b["e1"] == ?K
    assert t == true
    assert c == "KQkq"
    assert p == "-"
    assert gs == :running
  end

  test "new_game from fen (after 1.e4c5) returns valid game" do
    fen = "rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq c6"
    %{board: b, turn: t, castling: c, passant: p, game_state: gs} = Game.new_game(fen)
    assert b["e4"] == ?P
    assert b["c5"] == ?p
    assert b["e2"] == ?.
    assert b["c7"] == ?.
    assert t == true
    assert c == "KQkq"
    assert p == "c6"
    assert gs == :running
  end

  test "new_game from invalid fen raises an exception" do
    fen = "rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPPPPP/RNBQKBNR w KQkq c6"
    catch_error(Game.new_game(fen))
  end

  test "make_move for finished game doesn't change anything" do
    game = Game.new_game()
    fin_game = %{game | game_state: :draw}
    new_game = Game.make_move(fin_game, "testmove")
    assert new_game == fin_game
  end

  test "check_move recognizes valid move e2e4" do
    game = Game.new_game()
    assert {:ok, "e2e4"} = Game.check_move(game, "e2e4")
  end

  test "check_move detects invalid squares" do
    game = Game.new_game()
    assert {:invalid, "invalid coordinates: <k3f7>"} = Game.check_move(game, "k3f7")
    assert {:invalid, "invalid coordinates: <f7f9>"} = Game.check_move(game, "f7f9")
  end

  test "check_move detects missing piece" do
    game = Game.new_game()
    assert {:invalid, "no piece at square <e3>"} = Game.check_move(game, "e3e4")
    assert {:invalid, "no piece at square <c6>"} = Game.check_move(game, "c6c5")
  end

  test "check_move detects wrong color" do
    game = Game.new_game()
    assert {:ok, "e2e4"} = Game.check_move(game, "e2e4")
    assert {:invalid, "it's not your turn"} = Game.check_move(game, "c7c5")
  end

  test "accept_move for invalid move only changes game_state and message" do
    game = Game.new_game()
    new_game = Game.accept_move(game, {:invalid, "reason"})
    assert game.board == new_game.board
    assert game.turn == new_game.turn
    assert new_game.game_state == :invalid
    assert new_game.message == "reason"
  end

  test "accept_move for valid move creates a valid new game" do
    game = Game.new_game()
    new_game = Game.accept_move(game, {:ok, "e2e4"})
    assert new_game.board["e2"] == ?.
    assert new_game.board["e4"] == ?P
    assert game.turn
    assert not new_game.turn
    assert new_game.game_state == :running
    assert new_game.message == ""
  end

  test "make_move for valid move creates a valid new game" do
    game = Game.new_game()
    new_game = Game.make_move(game, "e2e4")
    assert new_game.board["e2"] == ?.
    assert new_game.board["e4"] == ?P
    assert game.turn
    assert not new_game.turn
    assert new_game.game_state == :running
    assert new_game.message == ""
  end
end
