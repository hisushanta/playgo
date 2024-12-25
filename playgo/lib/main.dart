
import 'package:flutter/material.dart';

enum Stone { none, black, white }

class Move {
  int x;
  int y;
  Stone stone;
  Move(this.x, this.y, this.stone);
}

class GoBoard extends StatefulWidget {
  final int size;
  const GoBoard({Key? key, required this.size}) : super(key: key);

  @override
  State<GoBoard> createState() => _GoBoardState();
}

class _GoBoardState extends State<GoBoard> {
  late List<List<Stone>> board;
  Stone currentPlayer = Stone.black;
  List<Move> moves = [];
  Move? lastMove;
  int blackScore = 0;
  int whiteScore = 0;
  bool gameOver = false;

  @override
  void initState() {
    super.initState();
    _initializeBoard();
  }

  @override
  void _initializeBoard() {
    board = List.generate(widget.size, (_) => List.filled(widget.size, Stone.none));
  }

  Stone _getStone(int x, int y) {
    if (x >= 0 && x < widget.size && y >= 0 && y < widget.size) {
      return board[y][x];
    }
    return Stone.none;
  }

  List<List<int>> _findGroup(int x, int y, Stone stone) {
    List<List<int>> group = [];
    List<List<int>> visited = List.generate(widget.size, (_) => List.filled(widget.size, 0));

    void dfs(int i, int j) {
      if (i < 0 || i >= widget.size || j < 0 || j >= widget.size || visited[j][i] == 1 || board[j][i] != stone) return;
      visited[j][i] = 1;
      group.add([i, j]);
      for (var dir in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
        dfs(i + dir[0], j + dir[1]);
      }
    }

    dfs(x, y);
    return group;
  }

  bool _hasLiberty(List<List<int>> group) {
    for (var pos in group) {
      for (var dir in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
        int nx = pos[0] + dir[0];
        int ny = pos[1] + dir[1];
        if (nx >= 0 && nx < widget.size && ny >= 0 && ny < widget.size && board[ny][nx] == Stone.none) {
          return true;
        }
      }
    }
    return false;
  }

  void _captureStones(List<List<int>> group) {
  for (var pos in group) {
    board[pos[1]][pos[0]] = Stone.none;
  }
  // Update the score for the capturing player
  if (currentPlayer == Stone.black) {
    blackScore += group.length;
  } else {
    whiteScore += group.length;
  }
}


  bool _isValidMove(int x, int y) {
    if (x < 0 || x >= widget.size || y < 0 || y >= widget.size || board[y][x] != Stone.none) return false;

    board[y][x] = currentPlayer;
    var group = _findGroup(x, y, currentPlayer);
    if (_hasLiberty(group)) {
      board[y][x] = Stone.none;
      return true;
    }

    Stone opponent = currentPlayer == Stone.black ? Stone.white : Stone.black;
    bool valid = false;
    for (var dir in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
      int nx = x + dir[0];
      int ny = y + dir[1];
      if (nx >= 0 && nx < widget.size && ny >= 0 && ny < widget.size && board[ny][nx] == opponent) {
        var opponentGroup = _findGroup(nx, ny, opponent);
        if (!_hasLiberty(opponentGroup)) {
          valid = true;
          break;
        }
      }
    }

    board[y][x] = Stone.none;
    return valid;
  }

  void _placeStone(int x, int y) {
    if (!gameOver && _isValidMove(x, y)) {
      setState(() {
        board[y][x] = currentPlayer;
        moves.add(Move(x, y, currentPlayer));

        Stone opponent = currentPlayer == Stone.black ? Stone.white : Stone.black;
        for (var dir in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
          int nx = x + dir[0];
          int ny = y + dir[1];
          if (nx >= 0 && nx < widget.size && ny >= 0 && ny < widget.size && board[ny][nx] == opponent) {
            var opponentGroup = _findGroup(nx, ny, opponent);
            if (!_hasLiberty(opponentGroup)) {
              _captureStones(opponentGroup);
            }
          }
        }

        currentPlayer = currentPlayer == Stone.black ? Stone.white : Stone.black;
      });
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
      appBar: AppBar(
        title: const Text('Go Game'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag),
            onPressed: _endGame,
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
                      Container( // Background color for the board
                        width: boardSize + padding * 2,
                        height: boardSize + padding * 2,
                        color: const Color(0xFFD3B07C), // Light brown color
                      ),
                      // Draw Grid Lines
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
                      // Draw Hoshi (Star Points)
                      if (widget.size == 9 || widget.size == 13 || widget.size == 19)
                        ..._buildHoshi(cellSize, padding), //Call the function for draw points

                      // Place Stones
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
      return hoshi; // No hoshi for other board sizes
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

void main() {
  runApp(const MaterialApp(
    home: GoBoard(size: 19),
  ));
}