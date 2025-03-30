import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:playgo/pages/info.dart';

enum Stone { none, black, white }

class Move {
  int x;
  int y;
  Stone stone;
  Move(this.x, this.y, this.stone);
}

class GoBoard extends StatefulWidget {
  final int size;
  final int duration;
  const GoBoard({Key? key, required this.size, required this.duration}) : super(key: key);

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
  int _timeLeft = 180; // 3 minutes in seconds
  late Timer _timer;
  PlaceStoneSound placeStoneSound = PlaceStoneSound();
  
  @override
  void initState() {
    super.initState();
    _timeLeft = widget.duration * 60;
    _initializeBoard();
    _startTimer();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);  // to only hide the status bar

    // Delay the orientation logic until after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final double shortestSide = MediaQuery.of(context).size.shortestSide;
      if (shortestSide < 600) {
        // Phone: Lock to portrait mode
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      } else {
        // Tablet: Allow both portrait and landscape modes
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _timer.cancel(); // Cancel the timer to avoid memory leaks
    placeStoneSound.disposeStoneSound();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
      } else {
        _timer.cancel();
        _endGame();
      }
    });
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


  void _placeStone(int x, int y) async {
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
      // Play the sound when a stone is placed
      await placeStoneSound.playStoneSound();

    }
  }

  void _endGame() {
    setState(() {
      gameOver = true;
      _showExitDialog();
    });
  }

  void distroyTheScreen() {
    Navigator.pop(context); // Return to the home screen
  }

  double _getIntersectionX(int x, double cellSize, double padding) {
    return x * cellSize + padding;
  }

  double _getIntersectionY(int y, double cellSize, double padding) {
    return y * cellSize + padding;
  }

  void _showExitDialog() {
    String winner = blackScore > whiteScore ? "Black" : blackScore == whiteScore ? "Draw" : "White";

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
                  winner == "Draw" ? "$winner Match" : "$winner Wins!",
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
                    distroyTheScreen();
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

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Battle Ground',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _formatTime(_timeLeft),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: _showExitDialog,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          double boardSize = isLandscape
              ? constraints.maxHeight * 0.6 // Use 60% of height in landscape
              : constraints.maxWidth > constraints.maxHeight
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
                color: Colors.grey[200],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
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
                        "Score: $whiteScore",
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10), // Reduced spacing

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
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10), // Reduced spacing

              // Black Player Card (Below the Board)
              Card(
                margin: const EdgeInsets.all(10),
                elevation: 5,
                color: Colors.grey[200],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
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
                        "Score: $blackScore",
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
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(2, 2),
            ),
          ],
          gradient: RadialGradient(
            colors: [Colors.grey[800]!, Colors.black],
            center: Alignment.topLeft,
            radius: 1.5,
          ),
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
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(2, 2),
            ),
          ],
          gradient: RadialGradient(
            colors: [Colors.white, Colors.grey[300]!],
            center: Alignment.topLeft,
            radius: 1.5,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}