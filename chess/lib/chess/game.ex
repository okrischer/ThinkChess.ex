defmodule Chess.Game do

  @type game_state :: :running | :invalid | :white_wins | :black_wins | :draw

  @type t :: %{
    board: map,
    turn: boolean,
    castling: binary,
    passant: binary,
    moves: [binary],
    captured: [char],
    checks: [binary],
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
      captured: [],
      checks: [],
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
        if to in legal_moves(game.board, from),
        do: {:ok, move},
        else: {:invalid, "illegal move #{move}"}
      else
        {:invalid, "it's not your turn"}
      end
    rescue
      MatchError -> {:invalid, "invalid coordinates: <#{from <> to}>"}
      ArgumentError -> {:invalid, "no piece at square <#{from}>"}
    end
  end

  @spec legal_moves(map, binary) :: [binary]
  def legal_moves(board, from) do
    try do
      piece = Map.fetch!(board, from)
      color = get_color(piece)
      args = {board, from, color}
      case piece do
        p when p in ~c"pP" -> pawn_move(args)
        p when p in ~c"rR" -> rook_move(args)
        p when p in ~c"nN" -> knight_move(args)
        p when p in ~c"bB" -> bishop_move(args)
        p when p in ~c"qQ" -> queen_move(args)
        p when p in ~c"kK" -> king_move(args)
        _ -> []
      end
    rescue
      KeyError -> []
      ArgumentError -> []
    end
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
    target = game.board[to]
    capture = target != ?.
    captured = if capture, do: [target | game.captured], else: game.captured
    lan = if capture, do: Enum.join([from, to], "x"), else: Enum.join([from, to], "-")
    moves = [lan | game.moves]
    turn = not game.turn
    checks = get_checks(board, turn)
    %{game | board: board,
      turn: turn,
      moves: moves,
      captured: captured,
      checks: checks,
      message: "",
      game_state: :running}
  end

  @spec undo_move(t) :: t
  def undo_move(game = %{moves: []}) do
      %{game | game_state: :invalid, message: "no more moves to undo"}
  end

  def undo_move(game) do
    [move | moves] = game.moves
    capture = String.contains?(move, "x")
    splitter = if capture, do: "x", else: "-"
    [from | [to | []]] = String.split(move, splitter)
    piece = game.board[to]
    turn = not game.turn
    case capture do
      false ->  board = %{game.board | from => piece, to => ?.}
                %{game | board: board, moves: moves, turn: turn}
      true  ->  [captured_piece | captured] = game.captured
                board = %{game.board | from => piece, to => captured_piece}
                %{game | board: board, moves: moves, turn: turn, captured: captured}
    end
  end

  ################################## private #######################################

  defp get_checks(board, turn) do
    king = Map.filter(board, fn {_k, v} -> v in ~c"Kk" and get_color(v) == turn end)
      |> Enum.map(fn {square, _v} -> square end)
    [king | []] = king
    Map.filter(board, fn {square, piece} -> piece != ?. and
                                            get_color(piece) == not turn and
                                            king in legal_moves(board, square) end)
    |> Enum.map(fn {square, _v} -> square end)
  end

  defp pawn_move(_args  = {board, square, _color = true}) do
    {file, rank} = String.to_charlist(square) |> List.to_tuple
    regular = if rank == ?2, do: [{0, 1}, {0, 2}], else: [{0, 1}]
    regular = Enum.map(regular, fn {f, r} -> {file + f, rank + r} end)
      |> Enum.map(fn {f, r} -> List.to_string([f, r]) end)
      |> Enum.filter(fn square -> board[square] == ?. end)
    capture = [{-1, 1}, {1, 1}]
    capture = Enum.map(capture, fn {f, r} -> {file + f, rank + r} end)
      |> Enum.map(fn {f, r} -> List.to_string([f, r]) end)
      |> Enum.filter(fn square -> board[square] in ~c"rnbqkp" end)
    regular ++ capture
  end

  defp pawn_move(_args = {board, square, _black}) do
    {file, rank} = String.to_charlist(square) |> List.to_tuple
    regular = if rank == ?7, do: [{0, -1}, {0, -2}], else: [{0, -1}]
    regular = Enum.map(regular, fn {f, r} -> {file + f, rank + r} end)
      |> Enum.map(fn {f, r} -> List.to_string([f, r]) end)
      |> Enum.filter(fn square -> board[square] == ?. end)
    capture = [{-1, -1}, {1, -1}]
    capture = Enum.map(capture, fn {f, r} -> {file + f, rank + r} end)
      |> Enum.map(fn {f, r} -> List.to_string([f, r]) end)
      |> Enum.filter(fn square -> board[square] in ~c"RNBQKP" end)
    regular ++ capture
  end

  defp king_move(args) do
    delta = [-1, 0, 1]
    moves = for f <- delta,
                r <- delta,
                {f, r} != {0, 0},
                do: {f, r}
    get_legal_squares(args, moves)
  end

  defp knight_move(args) do
    delta = [-2, -1, 1, 2]
    moves = for f <- delta,
                r <- delta,
                abs(f) != abs(r),
                do: {f, r}
    get_legal_squares(args, moves)
  end

  defp rook_move(args = {board, square, color}) do
    {file, rank} = String.to_charlist(square) |> List.to_tuple
    {low_file, high_file, low_rank, high_rank} = rook_blocks(args)
    board
    |> to_coordinates
    |> Enum.filter(fn {{f, r}, p} -> (p == ?. or get_color(p) != color) and
                                     (f == file or r == rank) end)
    |> Enum.filter(fn {{f, r}, _} -> f in low_file..high_file and
                                     r in low_rank..high_rank end)
    |> to_squares
  end

  defp bishop_move(args = {board, square, color}) do
    {file, rank} = String.to_charlist(square) |> List.to_tuple
    blocked = bishop_blocks(args)
    board
    |> to_coordinates
    |> Enum.filter(fn {{f, r}, p} -> (p == ?. or get_color(p) != color) and
                                     (abs(file - f) == abs(rank - r)) end)
    |> to_squares
    |> Enum.reject(fn square -> square in blocked end)
  end

  defp queen_move(args) do
    rook_move(args) ++ bishop_move(args)
  end

  defp rook_blocks(_args = {board, square, _color}) do
    {file, rank} = String.to_charlist(square) |> List.to_tuple
    blocking = board
      |> to_coordinates
      |> Enum.filter(fn {{f, r}, p} -> p != ?. and
                                      (f == file or r == rank) and
                                      {f, r} != {file, rank} end)

    low_file = blocking
      |> Enum.filter(fn {{f, r}, _} -> r == rank and f < file end)
    low_file = if Enum.empty?(low_file),
      do: ?a,
      else: Enum.map(low_file, fn {{f, _}, _} -> f end) |> Enum.max

    high_file = blocking
      |> Enum.filter(fn {{f, r}, _} -> r == rank and f > file end)
    high_file = if Enum.empty?(high_file),
      do: ?h,
      else: Enum.map(high_file, fn {{f, _}, _} -> f end) |> Enum.min

    low_rank = blocking
      |> Enum.filter(fn {{f, r}, _} -> f == file and r < rank end)
    low_rank = if Enum.empty?(low_rank),
      do: ?1,
      else: Enum.map(low_rank, fn {{_, r}, _} -> r end) |> Enum.max

    high_rank = blocking
      |> Enum.filter(fn {{f, r}, _} -> f == file and r > rank end)
    high_rank = if Enum.empty?(high_rank),
      do: ?8,
      else: Enum.map(high_rank, fn {{_, r}, _} -> r end) |> Enum.min

    {low_file, high_file, low_rank, high_rank}
  end

  defp bishop_blocks(_args = {board, square, _color}) do
    {file, rank} = String.to_charlist(square) |> List.to_tuple
    blocking_pieces = board
      |> to_coordinates
      |> Enum.filter(fn {{f, r}, p} -> p != ?. and
                                      (abs(file - f) == abs(rank - r)) and
                                      {f, r} != {file, rank} end)

    for p <- blocking_pieces do
      {{f, r}, _} = p
      cond do
        f < file and r < rank ->  files = -1..-6//-1
                                  ranks = files
                                  for fs <- files, rs <- ranks, abs(fs) == abs(rs),
                                  do: {f + fs, r + rs}
        f < file and r > rank ->  files = -1..-6//-1
                                  ranks = 1..6
                                  for fs <- files, rs <- ranks, abs(fs) == abs(rs),
                                  do: {f + fs, r + rs}
        f > file and r < rank ->  files = 1..6
                                  ranks = -1..-6//-1
                                  for fs <- files, rs <- ranks, abs(fs) == abs(rs),
                                  do: {f + fs, r + rs}
        f > file and r > rank ->  files = 1..6
                                  ranks = files
                                  for fs <- files, rs <- ranks, abs(fs) == abs(rs),
                                  do: {f + fs, r + rs}
      end
    end
    |> List.flatten
    |> Enum.map(fn {f, r} -> List.to_string([f, r]) end)
    |> Enum.filter(fn square -> square in @squares end)
  end

  defp get_legal_squares(_args = {board, square, color}, moves) do
    {file, rank} = String.to_charlist(square) |> List.to_tuple
    Enum.map(moves, fn {f, r} -> {file + f, rank + r} end)
    |> Enum.map(fn {f, r} -> List.to_string([f, r]) end)
    |> Enum.filter(fn square -> square in @squares end)
    |> Enum.filter(fn square -> board[square] == ?. or get_color(board[square]) != color end)
  end

  defp to_coordinates(board) do
    board
    |> Enum.map(fn {k, v} -> {String.to_charlist(k) |> List.to_tuple, v} end)
  end

  defp to_squares(coordinates) do
    coordinates
    |> Enum.map(fn {{f, r}, _} -> List.to_string([f, r]) end)
  end

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
