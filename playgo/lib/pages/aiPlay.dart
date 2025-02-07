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

    // First, check if there are any capturing moves
    List<MoveAI> capturingMoves = _getCapturingMoves(board, aiPlayer);
    if (capturingMoves.isNotEmpty) {
      // Choose a random capturing move to make the AI less predictable
      MoveAI captureMove = capturingMoves[random.nextInt(capturingMoves.length)];
      _placeStone(captureMove.x, captureMove.y);
      return;
    }

    // If no capturing moves, find all valid moves
    List<MoveAI> validMoves = _getValidMoves(board, aiPlayer);
    if (validMoves.isNotEmpty) {
      // Choose a random valid move
      MoveAI randomMove = validMoves[random.nextInt(validMoves.length)];
      _placeStone(randomMove.x, randomMove.y);
    } else {
      // If no valid move is found, end the game
      _endGame();
    }
  }

  List<MoveAI> _getCapturingMoves(List<List<Stone>> boardState, Stone player) {
    List<MoveAI> capturingMoves = [];
    for (int y = 0; y < widget.size; y++) {
      for (int x = 0; x < widget.size; x++) {
        if (_isValidMove(x, y, boardState, player)) {
          // Temporarily place the stone
          boardState[y][x] = player;

          // Check if this move captures any opponent stones
          Stone opponent = player == Stone.black ? Stone.white : Stone.black;
          bool captures = false;
          for (var dir in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
            int nx = x + dir[0];
            int ny = y + dir[1];
            if (nx >= 0 && nx < widget.size && ny >= 0 && ny < widget.size && boardState[ny][nx] == opponent) {
              var opponentGroup = _findGroup(nx, ny, opponent, boardState);
              if (!_hasLiberty(opponentGroup, boardState)) {
                captures = true;
                break;
              }
            }
          }

          // Revert the move
          boardState[y][x] = Stone.none;

          if (captures) {
            capturingMoves.add(MoveAI(x, y, player));
          }
        }
      }
    }
    return capturingMoves;
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

    // Temporarily place the stone
    boardState[y][x] = player;

    // Check if the move has liberties
    var group = _findGroup(x, y, player, boardState);
    if (_hasLiberty(group, boardState)) {
      boardState[y][x] = Stone.none; // Revert the move
      return true;
    }

    // Check if the move captures any opponent stones
    Stone opponent = player == Stone.black ? Stone.white : Stone.black;
    bool captures = false;
    for (var dir in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
      int nx = x + dir[0];
      int ny = y + dir[1];
      if (nx >= 0 && nx < widget.size && ny >= 0 && ny < widget.size && boardState[ny][nx] == opponent) {
        var opponentGroup = _findGroup(nx, ny, opponent, boardState);
        if (!_hasLiberty(opponentGroup, boardState)) {
          captures = true;
          break;
        }
      }
    }

    boardState[y][x] = Stone.none; // Revert the move
    return captures; // Allow the move if it captures opponent stones
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
  void destroyTheScreen(){
    Navigator.pop(context);
  }
  void _showExitDialog() {
    String winner = blackScore > whiteScore ? "Black" : blackScore == whiteScore ? "Draw":"White";
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.emoji_events,
                  color: Colors.amber,
                  size: 50,
                ),
                const SizedBox(height: 20),
                Text(
                  winner=="Draw"? "$winner Match":"$winner Wins!",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Black: $blackScore | White: $whiteScore",
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the dialog
                    destroyTheScreen();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "Close",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 253, 192, 100),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 253, 192, 100),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.blue, Colors.purple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Go AI',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              color: Colors.white,
            ),
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false, // Remove the back arrow
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: _showExitDialog,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          double boardSize = constraints.maxWidth > constraints.maxHeight
              ? constraints.maxHeight
              : constraints.maxWidth;
          double padding = boardSize * 0.05;
          boardSize -= padding * 2;

          double cellSize = boardSize / (widget.size - 1);
          double stoneSize = cellSize * 0.8;

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // White Player Card (Above the Board)
              Card(
                margin: const EdgeInsets.all(10),
                elevation: 5,
                color: Colors.grey[200], // Light gray background for better visibility
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Circular Indicator Around White Stone Icon
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: currentPlayer == Stone.white ? Colors.green : Colors.grey,
                            width: 2,
                          ),
                        ),
                        child: const Icon(Icons.circle, color: Colors.white, size: 30),
                      ),
                      Text(
                        "White: $whiteScore",
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20), // Gap between card and board

              // Board
              Center(
                child: SizedBox(
                  width: boardSize + padding * 2,
                  height: boardSize + padding * 2,
                  child: Stack(
                    children: [
                      Container(
                        width: boardSize + padding * 2,
                        height: boardSize + padding * 2,
                        color: const Color(0xFFD3B07C), // Light brown color
                      ),
                      for (int i = 0; i < widget.size; i++)
                        Positioned(
                          top: _getIntersectionY(i, cellSize, padding) - 0.5,
                          left: padding,
                          width: boardSize,
                          child: Container(
                            height: 1,
                            color: Colors.black, // Black grid lines
                          ),
                        ),
                      for (int i = 0; i < widget.size; i++)
                        Positioned(
                          left: _getIntersectionX(i, cellSize, padding) - 0.5,
                          top: padding,
                          height: boardSize,
                          child: Container(
                            width: 1,
                            color: Colors.black, // Black grid lines
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
                      Positioned.fill(
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
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
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20), // Gap between board and card

              // Black Player Card (Below the Board)
              Card(
                margin: const EdgeInsets.all(10),
                elevation: 5,
                color: Colors.grey[200], // Light gray background for better visibility
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Circular Indicator Around Black Stone Icon
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: currentPlayer == Stone.black ? Colors.green : Colors.grey,
                            width: 2,
                          ),
                        ),
                        child: const Icon(Icons.circle, color: Colors.black, size: 30),
                      ),
                      Text(
                        "Black: $blackScore",
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
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
