import 'dart:math';
import 'package:flutter/material.dart';

enum Stone { none, black, white }

class MoveAI {
  int x;
  int y;
  Stone stone;
  int? score; // Added score for Minimax evaluation
  MoveAI(this.x, this.y, this.stone);
}

class GoAIBoard extends StatefulWidget {
  final int size;
  const GoAIBoard({Key? key, required this.size}) : super(key: key);

  @override
  State<GoAIBoard> createState() => _GoAIBoardState();
}

class _GoAIBoardState extends State<GoAIBoard> {
  late List<List<Stone>> board;
  Stone currentPlayer = Stone.black;
  Stone aiPlayer = Stone.white;
  List<MoveAI> moves = [];
  int blackScore = 0;
  int whiteScore = 0;
  bool gameOver = false;
  final Random random = Random(); // For adding randomness to AI

  @override
  void initState() {
    super.initState();
    _initializeBoard();
  }

  void _initializeBoard() {
    board = List.generate(widget.size, (_) => List.filled(widget.size, Stone.none));
  }

  void _makeAiMove() {
    if (gameOver) return; // Don't make a move if the game is over

    MoveAI? bestMove = _findBestMove(board, aiPlayer, depth: 3); // Depth-limited search
    if (bestMove != null) {
      _placeStone(bestMove.x, bestMove.y);
    } else {
      // If no valid move is found, end the game
      _endGame();
    }
  }

  MoveAI? _findBestMove(List<List<Stone>> boardState, Stone player, {int depth = 3, int alpha = -9999, int beta = 9999, bool maximizingPlayer = true}) {
    if (depth == 0 || _isGameOver(boardState)) {
      return MoveAI(-1, -1, player)..score = _evaluateBoard(boardState, player);
    }

    List<MoveAI> validMoves = _getValidMoves(boardState, player);
    if (validMoves.isEmpty) return null;

    // Occasionally choose a random move to make AI less predictable
    if (random.nextDouble() < 0.1) {
      return validMoves[random.nextInt(validMoves.length)];
    }

    MoveAI? bestMove;
    int bestScore = maximizingPlayer ? -9999 : 9999;

    for (var move in validMoves) {
      List<List<Stone>> newBoard = List.generate(widget.size, (i) => List.from(boardState[i]));
      newBoard[move.y][move.x] = player;

      MoveAI? result = _findBestMove(newBoard, player == Stone.black ? Stone.white : Stone.black, depth: depth - 1, alpha: alpha, beta: beta, maximizingPlayer: !maximizingPlayer);
      if (result == null) continue;

      int score = result.score ?? 0; // Handle null score
      if (maximizingPlayer) {
        if (score > bestScore) {
          bestScore = score;
          bestMove = move;
        }
        alpha = max(alpha, bestScore);
      } else {
        if (score < bestScore) {
          bestScore = score;
          bestMove = move;
        }
        beta = min(beta, bestScore);
      }

      if (beta <= alpha) {
        break; // Alpha-Beta pruning
      }
    }

    return bestMove ?? validMoves.first; // Return the first valid move if no best move is found
  }
  int _evaluateBoard(List<List<Stone>> boardState, Stone player) {
    int score = 0;

    // Evaluate based on territory, captures, and group strength
    for (int y = 0; y < widget.size; y++) {
      for (int x = 0; x < widget.size; x++) {
        if (boardState[y][x] == player) {
          score += 1; // Reward for own stones
        } else if (boardState[y][x] != Stone.none) {
          score -= 1; // Penalty for opponent's stones
        }
      }
    }

    // Reward capturing opponent stones
    Stone opponent = player == Stone.black ? Stone.white : Stone.black;
    for (int y = 0; y < widget.size; y++) {
      for (int x = 0; x < widget.size; x++) {
        if (boardState[y][x] == opponent) {
          var group = _findGroup(x, y, opponent, boardState);
          if (!_hasLiberty(group, boardState)) {
            score += group.length * 10; // Reward capturing
          }
        }
      }
    }

    return score;
  }

  bool _isGameOver(List<List<Stone>> boardState) {
    // Check if there are no valid moves left for either player
    return _getValidMoves(boardState, Stone.black).isEmpty && _getValidMoves(boardState, Stone.white).isEmpty;
  }

  List<MoveAI> _getValidMoves(List<List<Stone>> boardState, Stone player) {
    List<MoveAI> validMoves = [];
    for (int y = 0; y < widget.size; y++) {
      for (int x = 0; x < widget.size; x++) {
        if (_isValidMove(x, y, boardState, player)) {
          validMoves.add(MoveAI(x, y, player));
        }
      }
    }
    return validMoves;
  }

  List<List<int>> _findGroup(int x, int y, Stone stone, List<List<Stone>> boardState) {
    List<List<int>> group = [];
    List<List<int>> visited = List.generate(widget.size, (_) => List.filled(widget.size, 0));

    void dfs(int i, int j) {
      if (i < 0 || i >= widget.size || j < 0 || j >= widget.size || visited[j][i] == 1 || boardState[j][i] != stone) return;
      visited[j][i] = 1;
      group.add([i, j]);
      for (var dir in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
        dfs(i + dir[0], j + dir[1]);
      }
    }

    dfs(x, y);
    return group;
  }

  bool _hasLiberty(List<List<int>> group, List<List<Stone>> boardState) {
    for (var pos in group) {
      for (var dir in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
        int nx = pos[0] + dir[0];
        int ny = pos[1] + dir[1];
        if (nx >= 0 && nx < widget.size && ny >= 0 && ny < widget.size && boardState[ny][nx] == Stone.none) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isValidMove(int x, int y, List<List<Stone>> boardState, Stone player) {
    if (x < 0 || x >= widget.size || y < 0 || y >= widget.size || boardState[y][x] != Stone.none) return false;

    boardState[y][x] = player;
    var group = _findGroup(x, y, player, boardState);
    if (_hasLiberty(group, boardState)) {
      boardState[y][x] = Stone.none;
      return true;
    }

    Stone opponent = player == Stone.black ? Stone.white : Stone.black;
    bool valid = false;
    for (var dir in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
      int nx = x + dir[0];
      int ny = y + dir[1];
      if (nx >= 0 || nx < widget.size || ny >= 0 || ny < widget.size || boardState[ny][nx] == opponent) {
        var opponentGroup = _findGroup(nx, ny, opponent, boardState);
        if (!_hasLiberty(opponentGroup, boardState)) {
          valid = true;
          break;
        }
      }
    }

    boardState[y][x] = Stone.none;
    return valid;
  }

  void _placeStone(int x, int y) {
    if (!gameOver && _isValidMove(x, y, board, currentPlayer)) {
      setState(() {
        board[y][x] = currentPlayer;
        moves.add(MoveAI(x, y, currentPlayer));

        Stone opponent = currentPlayer == Stone.black ? Stone.white : Stone.black;
        for (var dir in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
          int nx = x + dir[0];
          int ny = y + dir[1];
          if (nx >= 0 && nx < widget.size && ny >= 0 && ny < widget.size && board[ny][nx] == opponent) {
            var opponentGroup = _findGroup(nx, ny, opponent, board);
            if (!_hasLiberty(opponentGroup, board)) {
              _captureStones(opponentGroup);
            }
          }
        }

        currentPlayer = currentPlayer == Stone.black ? Stone.white : Stone.black;
      });

      if (currentPlayer == aiPlayer && !gameOver) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _makeAiMove();
        });
      }
    }
  }

  void _captureStones(List<List<int>> group) {
    for (var pos in group) {
      board[pos[1]][pos[0]] = Stone.none;
    }
    if (currentPlayer == Stone.black) {
      blackScore += group.length;
    } else {
      whiteScore += group.length;
    }
  }

  void _endGame() {
    setState(() {
      gameOver = true;
      _calculateScore();
    });
  }

  void _calculateScore() {
    blackScore = 0;
    whiteScore = 0;

    List<List<bool>> visited = List.generate(widget.size, (_) => List.filled(widget.size, false));

    for (int y = 0; y < widget.size; y++) {
      for (int x = 0; x < widget.size; x++) {
        if (visited[y][x] || board[y][x] != Stone.none) continue;

        List<List<int>> territory = [];
        Stone? controllingStone;

        void dfs(int i, int j) {
          if (i < 0 || i >= widget.size || j < 0 || j >= widget.size || visited[j][i]) return;
          visited[j][i] = true;

          if (board[j][i] == Stone.none) {
            territory.add([i, j]);
          } else {
            if (controllingStone == null) {
              controllingStone = board[j][i];
            } else if (controllingStone != board[j][i]) {
              controllingStone = null;
            }
          }

          for (var dir in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
            dfs(i + dir[0], j + dir[1]);
          }
        }

        dfs(x, y);

        if (controllingStone == Stone.black) {
          blackScore += territory.length;
        } else if (controllingStone == Stone.white) {
          whiteScore += territory.length;
        }
      }
    }

    for (int y = 0; y < widget.size; y++) {
      for (int x = 0; x < widget.size; x++) {
        if (board[y][x] == Stone.black) blackScore++;
        if (board[y][x] == Stone.white) whiteScore++;
      }
    }
  }

  double _getIntersectionX(int x, double cellSize, double padding) {
    return x * cellSize + padding;
  }

  double _getIntersectionY(int y, double cellSize, double padding) {
    return y * cellSize + padding;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 253, 192, 100),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 253, 192, 100),
        title: const Center(child: Text('Go AI', style: TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic))),
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          double boardSize = constraints.maxWidth > constraints.maxHeight ? constraints.maxHeight : constraints.maxWidth;
          double padding = boardSize * 0.05;
          boardSize -= padding * 2;

          double cellSize = boardSize / (widget.size - 1);
          double stoneSize = cellSize * 0.8;

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text("Current Turn: ${currentPlayer == Stone.black ? 'Black' : 'White'}"),
              ),
              Center(
                child: SizedBox(
                  width: boardSize + padding * 2,
                  height: boardSize + padding * 2,
                  child: Stack(
                    children: [
                      Container(
                        width: boardSize + padding * 2,
                        height: boardSize + padding * 2,
                        color: const Color(0xFFD3B07C),
                      ),
                      for (int i = 0; i < widget.size; i++)
                        Positioned(
                          top: _getIntersectionY(i, cellSize, padding) - 0.5,
                          left: padding,
                          width: boardSize,
                          child: Container(
                            height: 1,
                            color: Colors.black,
                          ),
                        ),
                      for (int i = 0; i < widget.size; i++)
                        Positioned(
                          left: _getIntersectionX(i, cellSize, padding) - 0.5,
                          top: padding,
                          height: boardSize,
                          child: Container(
                            width: 1,
                            color: Colors.black,
                          ),
                        ),
                      if (widget.size == 9 || widget.size == 13 || widget.size == 19)
                        ..._buildHoshi(cellSize, padding),
                      for (int y = 0; y < widget.size; y++)
                        for (int x = 0; x < widget.size; x++)
                          if (board[y][x] != Stone.none)
                            Positioned(
                              top: _getIntersectionY(y, cellSize, padding) - stoneSize / 2,
                              left: _getIntersectionX(x, cellSize, padding) - stoneSize / 2,
                              child: _buildStone(board[y][x], stoneSize),
                            ),
                      GridView.builder(
                        physics: NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: widget.size,
                        ),
                        itemCount: widget.size * widget.size,
                        itemBuilder: (context, index) {
                          int x = index % widget.size;
                          int y = index ~/ widget.size;
                          return GestureDetector(
                            onTap: () => _placeStone(x, y),
                            child: Container(
                              color: Colors.transparent,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text("Black: $blackScore"),
                    Text("White: $whiteScore"),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildHoshi(double cellSize, double padding) {
    List<Widget> hoshi = [];
    List<List<int>> points;

    if (widget.size == 9) {
      points = [[2, 2], [6, 2], [2, 6], [6, 6], [4, 4]];
    } else if (widget.size == 13) {
      points = [[3, 3], [9, 3], [3, 9], [9, 9], [6, 6]];
    } else if (widget.size == 19) {
      points = [[3, 3], [9, 3], [15, 3], [3, 9], [9, 9], [15, 9], [3, 15], [9, 15], [15, 15]];
    } else {
      return hoshi;
    }

    for (var point in points) {
      hoshi.add(
        Positioned(
          left: _getIntersectionX(point[0], cellSize, padding) - 3,
          top: _getIntersectionY(point[1], cellSize, padding) - 3,
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black,
            ),
          ),
        ),
      );
    }
    return hoshi;
  }

  Widget _buildStone(Stone stone, double size) {
    if (stone == Stone.black) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black,
        ),
      );
    } else if (stone == Stone.white) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: Colors.black),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}