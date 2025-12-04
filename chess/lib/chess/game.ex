defmodule Chess.Game do

  @type game_state :: :running | :invalid | :white_wins | :black_wins | :draw

  @type t :: %{
    board: map,
    turn: boolean,
    castling: binary,
    passant: binary,
    moves: [binary],
    message: binary,
    game_state: game_state
  }

  @squares [
    "a8", "b8", "c8", "d8", "e8", "f8", "g8", "h8",
    "a7", "b7", "c7", "d7", "e7", "f7", "g7", "h7",
    "a6", "b6", "c6", "d6", "e6", "f6", "g6", "h6",
    "a5", "b5", "c5", "d5", "e5", "f5", "g5", "h5",
    "a4", "b4", "c4", "d4", "e4", "f4", "g4", "h4",
    "a3", "b3", "c3", "d3", "e3", "f3", "g3", "h3",
    "a2", "b2", "c2", "d2", "e2", "f2", "g2", "h2",
    "a1", "b1", "c1", "d1", "e1", "f1", "g1", "h1",
  ]

  #################################### API ########################################

  @spec new_game(binary) :: t
  def new_game(fen \\ "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -") do
    {board, turn, castling, passant} = parse_fen(fen)
    %{
      board: board,
      turn: turn,
      castling: castling,
      passant: passant,
      moves: [],
      message: "",
      game_state: :running
    }
  end

  @spec make_move(t, binary) :: t
  def make_move(game = %{game_state: state}, _move)
  when state in [:white_wins, :black_wins, :draw], do: game

  def make_move(game, move) do
    move = check_move(game, move)
    accept_move(game, move)
  end

  @spec check_move(t, binary) :: {atom, binary}
  def check_move(game, move) do
    {from, to} = String.split_at(move, 2)
    try do
      {:ok, piece} = Map.fetch(game.board, from)
      {:ok, _} = Map.fetch(game.board, to)
      if get_color(piece) == game.turn do
        valid_move?(game, move)
      else
        {:invalid, "it's not your turn"}
      end
    rescue
      MatchError -> {:invalid, "invalid coordinates: <#{from}#{to}>"}
      ArgumentError -> {:invalid, "no piece at square <#{from}>"}
    end
  end

  @spec valid_move?(t, binary) :: {atom, binary}
  def valid_move?(_game, move) do
    {:ok, move}
  end

  @spec accept_move(t, {atom, binary}) :: t
  def accept_move(game, _move = {:invalid, reason}) do
    %{game | game_state: :invalid, message: reason}
  end

  def accept_move(game, move) do
    {:ok, uci} = move
    {from, to} = String.split_at(uci, 2)
    piece = game.board[from]
    board = %{game.board | from => ?., to => piece}
    moves = [uci | game.moves]
    turn = not game.turn
    %{game | board: board, turn: turn, moves: moves, message: ""}
  end

  ################################## private #######################################

  defp get_color(_piece = ?.), do: raise ArgumentError
  defp get_color(piece), do: piece in ~c"RNBQKP"

  defp parse_fen(fen) do
    fen_fields = String.split(fen)
    length(fen_fields) < 4 and raise ArgumentError, message: "invalid FEN"
    board = create_board(Enum.at(fen_fields, 0))
    turn = Enum.at(fen_fields, 1) == "w"
    castling = Enum.at(fen_fields, 2)
    passant = Enum.at(fen_fields, 3)
    {board, turn, castling, passant}
  end

  defp create_board(placement) do
    board = Enum.map(String.to_charlist(placement), &map_piece/1) |> List.flatten
    length(board) != 64 and raise ArgumentError, message: "invalid piece placement"
    Map.new(Enum.zip(@squares, board))
  end

  defp map_piece(piece) when piece in ~c"rnbqkpRNBQKP", do: piece
  defp map_piece(piece) do
    case piece do
      ?1 -> ?.
      ?2 -> ~c".."
      ?3 -> ~c"..."
      ?4 -> ~c"...."
      ?5 -> ~c"....."
      ?6 -> ~c"......"
      ?7 -> ~c"......."
      ?8 -> ~c"........"
      _  -> ~c""
    end
  end

end
