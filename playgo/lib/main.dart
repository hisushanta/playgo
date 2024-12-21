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
    board = List.generate(widget.size + 1, (_) => List.filled(widget.size + 1, Stone.none));
  }

  Stone _getStone(int x, int y) {
    if (x >= 0 && x <= widget.size && y >= 0 && y <= widget.size) {
      return board[y][x];
    }
    return Stone.none;
  }

  bool _captureStones(int x, int y, Stone opponent) {
    List<List<int>> visited = List.generate(widget.size + 1, (_) => List.filled(widget.size + 1, 0));
    List<List<int>> group = [];

    bool hasLiberty(int i, int j) {
      if (i < 0 || i > widget.size || j < 0 || j > widget.size) return false;
      return board[j][i] == Stone.none;
    }

    void findGroup(int i, int j) {
      if (i < 0 || i > widget.size || j < 0 || j > widget.size || visited[j][i] == 1 || board[j][i] != opponent) return;
      visited[j][i] = 1;
      group.add([i, j]);
      for (var dir in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
        findGroup(i + dir[0], j + dir[1]);
      }
    }

    findGroup(x, y);

    bool captured = true;
    for (var pos in group) {
      if (hasLiberty(pos[0] + 1, pos[1]) || hasLiberty(pos[0] - 1, pos[1]) || hasLiberty(pos[0], pos[1] + 1) || hasLiberty(pos[0], pos[1] - 1)) {
        captured = false;
        break;
      }
    }

    if (captured) {
      for (var pos in group) {
        board[pos[1]][pos[0]] = Stone.none;
      }
      return true;
    }
    return false;
  }

  bool _isSuicide(int x, int y, Stone stone) {
    Stone oldStone = board[y][x];
    board[y][x] = stone;
    bool suicide = true;
    for (var dir in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
      int nx = x + dir[0], ny = y + dir[1];
      if (nx >= 0 && nx <= widget.size && ny >= 0 && ny <= widget.size) {
        if (board[ny][nx] == Stone.none) {
          suicide = false;
          break;
        } else if (board[ny][nx] != stone && _captureStones(nx, ny, stone == Stone.black ? Stone.white : Stone.black)) {
          suicide = false;
          break;
        }
      }
    }
    board[y][x] = oldStone;
    return suicide;
  }

  bool _isKo(int x, int y, Stone stone) {
    if (lastMove != null && lastMove!.x == x && lastMove!.y == y) {
      Stone tempStone = board[y][x];
      board[y][x] = stone;
      bool wouldRecapture = _captureStones(lastMove!.x, lastMove!.y, stone == Stone.black ? Stone.white : Stone.black);
      board[y][x] = tempStone;
      return wouldRecapture;
    }
    return false;
  }

  bool _isValidMove(int x, int y) {
    if (x < 0 || x > widget.size || y < 0 || y > widget.size) return false;  // Out of bounds
    if (_getStone(x, y) != Stone.none) return false;
    if (_isKo(x, y, currentPlayer)) return false;
    if (_isSuicide(x, y, currentPlayer)) return false;
    return true;
  }

  void _placeStone(int x, int y) {
    if (!gameOver && _isValidMove(x, y)) {
      setState(() {
        board[y][x] = currentPlayer;
        moves.add(Move(x, y, currentPlayer));

        Stone opponent = (currentPlayer == Stone.black) ? Stone.white : Stone.black;
        bool captured = false;

        for (var dir in [
          [-1, 0], // Left
          [1, 0],  // Right
          [0, -1], // Up
          [0, 1]   // Down
        ]) {
          int nx = x + dir[0];
          int ny = y + dir[1];
          if (nx >= 0 && nx <= widget.size && ny >= 0 && ny <= widget.size) {
            captured = captured || _captureStones(nx, ny, opponent);
          }
        }

        lastMove = Move(x, y, currentPlayer);
        currentPlayer = (currentPlayer == Stone.black) ? Stone.white : Stone.black;
        _calculateScore();
      });
    }
  }

  void _calculateScore() {
    blackScore = 0;
    whiteScore = 0;

    for (int x = 0; x <= widget.size; x++) {
      for (int y = 0; y <= widget.size; y++) {
        if (board[y][x] == Stone.black) {
          blackScore++;
        } else if (board[y][x] == Stone.white) {
          whiteScore++;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Go Game'),
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
                crossAxisCount: widget.size + 1,
              ),
              itemCount: (widget.size + 1) * (widget.size + 1),
              itemBuilder: (context, index) {
                int x = index % (widget.size + 1);
                int y = index ~/ (widget.size + 1);
                return GestureDetector(
                  onTap: () => _placeStone(x, y),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                        ),
                      ),
                      if (x <= widget.size && y <= widget.size) 
                        Positioned(
                          left: 0,
                          top: 0,
                          right: 0,
                          bottom: 0,
                          child: Center(
                            child: _buildStone(board[y][x]),
                          ),
                        ),
                    ],
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
          ElevatedButton(
            onPressed: () {
              _calculateScore();
              setState(() {
                gameOver = true;
              });
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text("Game Over"),
                    content: Text("Black: $blackScore, White: $whiteScore"),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            _initializeBoard();
                            currentPlayer = Stone.black;
                            moves.clear();
                            lastMove = null;
                            blackScore = 0;
                            whiteScore = 0;
                            gameOver = false;
                          });
                        },
                        child: const Text("Play Again"),
                      )
                    ],
                  );
                },
              );
            },
            child: const Text("End Game"),
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