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
    draw = %{game | game_state: :draw}
    new_game = Game.make_move(draw, "testmove")
    assert new_game == draw

    checkmate = %{game | game_state: :checkmate}
    new_game = Game.make_move(checkmate, "testmove")
    assert new_game == checkmate
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
    assert new_game.message == "e2-e4"
  end

  test "make_move for valid move creates a valid new game" do
    game = Game.new_game()
    game = Game.make_move(game, "e2e4")
    assert game.board["e2"] == ?.
    assert game.board["e4"] == ?P
    assert not game.turn
    assert game.moves == ["e2-e4"]
    assert game.game_state == :running
    assert game.message == "e2-e4"

    game = Game.make_move(game, "d7d5")
    assert game.board["d7"] == ?.
    assert game.board["d5"] == ?p
    assert game.moves == ["d7-d5", "e2-e4"]

    game = Game.make_move(game, "e4d5")
    assert game.board["e4"] == ?.
    assert game.board["d5"] == ?P
    assert game.moves == ["e4xd5", "d7-d5", "e2-e4"]
  end

  test "make_move for invalid move creates invalid game_state" do
    game = Game.new_game()
    new_game = Game.make_move(game, "e2f4")
    assert new_game.game_state == :invalid
    assert new_game.message == "illegal move e2f4"
    assert new_game.board == game.board
    assert new_game.turn == game.turn
  end

  test "legal_moves returns correct moves for pawn" do
    game = Game.new_game("8/8/8/8/8/3p1p2/4P3/8 - - -")
    moves = Game.legal_moves(game.board, "e2")
    assert Enum.sort(moves) == Enum.sort(["e3", "e4", "d3", "f3"])

    game = Game.new_game("8/4p3/3P1P2/8/8/8/8/8 - - -")
    moves = Game.legal_moves(game.board, "e7")
    assert Enum.sort(moves) == Enum.sort(["e6", "e5", "d6", "f6"])
  end

  test "legal_moves returns correct moves for knight" do
    game = Game.new_game("8/8/8/3N4/8/8/8/8 - - -")
    moves = Game.legal_moves(game.board, "d5")
    assert Enum.sort(moves) == Enum.sort(["b4", "b6", "c3", "c7", "e3", "e7", "f4", "f6"])
  end

  test "legal_moves returns correct moves for king" do
    game = Game.new_game("8/8/8/3k4/8/8/8/8 - - -")
    moves = Game.legal_moves(game.board, "d5")
    assert Enum.sort(moves) == Enum.sort(["c4", "c5", "c6", "d4", "d6", "e4", "e5", "e6"])
  end

  test "legal_moves returns correct moves for rook" do
    game = Game.new_game("8/8/8/3R4/8/8/8/8 - - -")
    moves = Game.legal_moves(game.board, "d5")
    assert Enum.sort(moves) ==  Enum.sort([
      "a5", "b5", "c5", "d1", "d2", "d3", "d4",
      "d6", "d7", "d8", "e5", "f5", "g5", "h5"])
  end

  test "legal_moves for rook with blocks" do
    game = Game.new_game("8/8/3p4/3R1P2/8/8/8/8 - - -")
    moves = Game.legal_moves(game.board, "d5")
    assert Enum.sort(moves) ==  Enum.sort([
      "a5", "b5", "c5", "d1", "d2", "d3", "d4", "d6", "e5"])
  end

  test "legal_moves returns correct moves for bishop" do
    game = Game.new_game("8/8/8/8/3b4/8/8/8 - - -")
    moves = Game.legal_moves(game.board, "d4")
    assert Enum.sort(moves) ==  Enum.sort([
      "a1", "a7", "b2", "b6", "c3", "c5", "e3",
      "e5", "f2", "f6", "g1", "g7", "h8"])
  end

  test "legal_moves for bishop with blocks" do
    game = Game.new_game("8/6p1/8/8/3B4/4P3/8/8 - - -")
    moves = Game.legal_moves(game.board, "d4")
    assert Enum.sort(moves) ==  Enum.sort([
      "a1", "a7", "b2", "b6", "c3", "c5", "e5", "f6", "g7"])
  end

  test "legal_moves returns correct moves for queen" do
    game = Game.new_game("8/8/8/8/3Q4/8/8/8 - - -")
    moves = Game.legal_moves(game.board, "d4")
    assert Enum.sort(moves) ==  Enum.sort([
      "a4", "b4", "c4", "d1", "d2", "d3", "d5", "d6", "d7",
      "d8", "e4", "f4", "g4", "h4", "a1", "a7", "b2", "b6",
      "c3", "c5", "e3", "e5", "f2", "f6", "g1", "g7", "h8"])
  end

  test "legal_moves for queen with blocks" do
    game = Game.new_game("8/8/8/2pp4/3Q4/4P3/8/8 - - -")
    moves = Game.legal_moves(game.board, "d4")
    assert Enum.sort(moves) ==  Enum.sort([
      "a4", "b4", "c4", "d1", "d2", "d3", "d5",
      "e4", "f4", "g4", "h4", "a1", "b2",
      "c3", "c5", "e5", "f6", "g7", "h8"])
  end

  test "move gives check for black" do
    game = Game.new_game("4k3/8/8/1N6/B7/8/8/8 w - -")
    game = Game.make_move(game, "b5d6")
    assert game.checks == ["a4", "d6"]
  end

  test "move gives check for white" do
    game = Game.new_game("8/8/8/b7/1n6/8/8/4K3 b - -")
    game = Game.make_move(game, "b4d3")
    assert game.checks == ["a5", "d3"]
  end

  test "make_move detects checkmate" do
    game = Game.new_game("rnbqk2r/pppp1ppp/5n2/2b1p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w - -")
    assert game.turn
    assert game.game_state == :running
    assert game.moves == []
    assert game.captured == []
    assert game.checks == []

    game = Game.make_move(game, "h5f7")
    assert not game.turn
    assert game.game_state == :checkmate
    assert game.moves == ["h5xf7"]
    assert game.captured == ~c"p"
    assert game.checks == ["f7"]
    assert game.message == "Checkmate! White wins."
  end

  test "make_move detects stalemate" do
    game = Game.new_game("5k2/5P2/8/5K2/8/8/8/8 w - -")
    game = Game.make_move(game, "f5f6")
    assert game.game_state == :draw
    assert game.message == "Stalemate! It's a draw."
    assert game.moves == ["f5-f6"]

    game = Game.new_game("kb5R/8/8/K7/8/8/8/8 w - -")
    game = Game.make_move(game, "a5b6")
    assert game.game_state == :draw

    game = Game.new_game("8/8/8/1Q4K1/8/8/p7/k7 w - -")
    game = Game.make_move(game, "b5b3")
    assert game.game_state == :draw

    game = Game.new_game("k7/P7/K7/8/8/4B3/8/8 w - -")
    game = Game.make_move(game, "e3f4")
    assert game.game_state == :draw

    game = Game.new_game("k7/P7/K7/8/8/3B4/8/8 w - -")
    game = Game.make_move(game, "d3e4")
    assert game.game_state == :checkmate
  end

  test "make_move detects moves that put own king in check" do
    game = Game.new_game("8/8/b7/8/8/3Pp3/4K3/8 w - -")
    game = Game.make_move(game, "e2f2")
    assert game.game_state == :invalid
    assert game.message == "observe check"

    game = Game.make_move(game, "d3d4")
    assert game.game_state == :invalid
    assert game.message == "observe check"

    game = Game.make_move(game, "e2e3")
    assert game.game_state == :running
    assert game.message == "e2xe3"
  end

  test "pawn promotion" do
    game = Game.new_game("3r2k1/2P5/2K5/8/8/8/8/8 w - -")
    game = Game.make_move(game, "c7d8")
    assert game.game_state == :running
    assert game.message == "c7xd8Q"
    assert game.moves == ["c7xd8Q"]
    assert game.board["d8"] == ?Q
    assert game.checks == ["d8"]
  end

  test "undo_move" do
    game = Game.new_game()
    game = Game.make_move(game, "e2e4")
    game = Game.make_move(game, "d7d5")
    game = Game.make_move(game, "e4d5")
    assert game.moves == ["e4xd5", "d7-d5", "e2-e4"]
    assert game.captured == ~c"p"

    game = Game.undo_move(game)
    assert game.board["d5"] == ?p
    assert game.board["e4"] == ?P
    assert game.moves == ["d7-d5", "e2-e4"]
    assert game.captured == []
    assert game.message == "move e4xd5 undone"

    game = Game.undo_move(game)
    assert game.board["d5"] == ?.
    assert game.board["d7"] == ?p
    assert game.moves == ["e2-e4"]
    assert game.captured == []
    assert game.message == "move d7-d5 undone"

    game = Game.undo_move(game)
    assert game.board["e4"] == ?.
    assert game.board["e2"] == ?P
    assert game.moves == []
    assert game.message == "move e2-e4 undone"

    game = Game.undo_move(game)
    assert game.game_state == :invalid
    assert game.message == "no more moves to undo"
  end
end
