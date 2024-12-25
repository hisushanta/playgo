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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text("Current Turn: ${currentPlayer == Stone.black ? 'Black' : 'White'}"),
          ),
          Expanded(
            child: GridView.builder(
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
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                    ),
                    child: Center(
                      child: _buildStone(board[y][x]),
                    ),
                  ),
                );
              },
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
      ),
    );
  }

  Widget _buildStone(Stone stone) {
    if (stone == Stone.black) {
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black,
        ),
      );
    } else if (stone == Stone.white) {
      return Container(
        width: 20,
        height: 20,
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
    home: GoBoard(size: 9),
  ));
}
