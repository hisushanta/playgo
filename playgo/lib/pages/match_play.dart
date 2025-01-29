import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:playgo/main.dart';
import 'package:playgo/pages/home.dart';

enum Stone { none, black, white }

class Move {
  int x;
  int y;
  Stone stone;
  Move(this.x, this.y, this.stone);
}

class GoBoardMatch extends StatefulWidget {
  final int size;
  final String gameId;
  final String playerId;
  final int totalGameTime;
  const GoBoardMatch({Key? key, required this.size, required this.gameId, required this.playerId , required this.totalGameTime}) : super(key: key);

  @override
  State<GoBoardMatch> createState() => _GoMultiplayerBoardState();
}

class _GoMultiplayerBoardState extends State<GoBoardMatch> {
  late List<List<Stone>> board;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> gameStream;
  bool isPlayerTurn = false;
  int blackScore = 0;
  int whiteScore = 0;
  int blackMissedTurns = 0;
  int whiteMissedTurns = 0;
  int blackTimeLeft = 30; // Timer for black player
  int whiteTimeLeft = 30; // Timer for white player
  int gameTimeLeft = 240; // 4-minute game timer (240 seconds)
  String userName = "";
  String partnerName = '';
  Timer? _turnTimer;
  Timer? _gameTimer;

  String? player1Id;
  String? player2Id;
  String? player1Stone;
  String? player2Stone;
  String currentTurn = 'black'; // Track the current turn
  bool showTurnNotification = false;
   
  @override
  void initState() {
    super.initState();
    gameTimeLeft = widget.totalGameTime*60;
    _initializeBoard();
    gameStream = FirebaseFirestore.instance.collection('games').doc(widget.gameId).snapshots();
    _listenToGameUpdates();
    _startTurnTimer();
    _startGameTimer();
    _markPlayerAsActive();
    _initializePlayers();
  }

  void _initializeBoard() {
    board = List.generate(widget.size, (_) => List.filled(widget.size, Stone.none));

  }

  void _initializePlayers() async {
    final gameDoc = FirebaseFirestore.instance.collection('games').doc(widget.gameId);
    final gameSnapshot = await gameDoc.get();

    if (gameSnapshot.exists) {
      final data = gameSnapshot.data();
      if (data != null) {
        setState(() {
          player1Id = data['player1Id'];
          player2Id = data['player2Id'];
          player1Stone = data['player1Stone'];
          player2Stone = data['player2Stone'];
          userName = data[player1Id];
          partnerName = data[player2Id];
          currentTurn = data['currentTurn'] ?? 'black'; // Initialize currentTurn
          blackTimeLeft = data['blackTimeLeft'] ?? 30; // Initialize black timer
          whiteTimeLeft = data['whiteTimeLeft'] ?? 30; // Initialize white timer
          isPlayerTurn = (currentTurn == 'black' && widget.playerId == player1Id && player1Stone == 'black') ||
              (currentTurn == 'white' && widget.playerId == player2Id && player2Stone == 'white');
        });
      }
    }
  }

  void _listenToGameUpdates() {
    gameStream.listen((snapshot) async {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null) {
          setState(() {
            // Deserialize the board from Firestore
            final Map<String, dynamic> firestoreBoard = data['board'] ?? {};
            for (int y = 0; y < widget.size; y++) {
              for (int x = 0; x < widget.size; x++) {
                String key = '$x\_$y';
                String stone = firestoreBoard[key] ?? 'none';
                board[y][x] = stone == 'black'
                    ? Stone.black
                    : stone == 'white'
                        ? Stone.white
                        : Stone.none;
              }
            }

            // Update scores and missed turns
            blackScore = data['blackScore'] ?? 0;
            whiteScore = data['whiteScore'] ?? 0;
            blackMissedTurns = data['blackMissedTurns'] ?? 0;
            whiteMissedTurns = data['whiteMissedTurns'] ?? 0;
            blackTimeLeft = data['blackTimeLeft'] ?? 30; // Update black timer
            whiteTimeLeft = data['whiteTimeLeft'] ?? 30; // Update white timer
            currentTurn = data['currentTurn'] ?? 'black'; // Update currentTurn

            // Determine if it's the current player's turn
            isPlayerTurn = (currentTurn == 'black' && widget.playerId == player1Id && player1Stone == 'black') ||
                (currentTurn == 'white' && widget.playerId == player2Id && player2Stone == 'white');
            // Check if game has ended
          if (data['status'] == 'ended' && data['endReason'] == 'timeout') {
            _gameTimer?.cancel();
            _turnTimer?.cancel();
            
            String winner = data['winner'];
            int finalBlackScore = data['finalBlackScore'] ?? blackScore;
            int finalWhiteScore = data['finalWhiteScore'] ?? whiteScore;

            // Show dialog to both players
            if (!mounted) return;
            // Determine if current player is the winner
              bool isCurrentPlayerWinner = (winner == 'black' && player1Stone == 'black' && widget.playerId == player1Id) ||
                                        (winner == 'white' && player2Stone == 'white' && widget.playerId == player2Id);

              // Show personalized dialog to current player
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  title: Text(isCurrentPlayerWinner ? 'You Won!' : 'Game Over'),
                  content: Text(
                    isCurrentPlayerWinner
                      ? 'Congratulations! You won with ${winner == 'black' ? blackScore : whiteScore} points!'
                      : 'Your opponent won with ${winner == 'black' ? blackScore : whiteScore} points.'
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        destroyTheScreen();
                      },
                      child: Text('OK'),
                    ),
                  ],
                ),
              );
          }

            // Check if the game should end due to missed turns
            if (blackMissedTurns >= 3 || whiteMissedTurns >= 3) {
              _endGame();
            }
            if (isPlayerTurn) {
              showTurnNotification = true;
              // Hide notification after 1 second
              Future.delayed(Duration(seconds: 1), () {
                if (mounted) {
                  setState(() {
                    showTurnNotification = false;
                  });
                }
              });
            }

          });
        }
      }
    });
  }

  void destroyTheScreen() {
    Navigator.pop(context);
  }

  Future<void> _markPlayerAsActive() async {
    final gameDoc = FirebaseFirestore.instance.collection('games').doc(widget.gameId);
    final gameSnapshot = await gameDoc.get();

    if (gameSnapshot.exists) {
      List<dynamic> activePlayers = gameSnapshot['activePlayers'] ?? [];

      if (!activePlayers.contains(widget.playerId)) {
        activePlayers.add(widget.playerId);
        await gameDoc.update({'activePlayers': activePlayers});
      }
    }
  }

  Future<void> _markPlayerAsInactive() async {
    final gameDoc = FirebaseFirestore.instance.collection('games').doc(widget.gameId);
    final gameSnapshot = await gameDoc.get();

    if (gameSnapshot.exists) {
      List<dynamic> activePlayers = gameSnapshot['activePlayers'] ?? [];

      activePlayers.remove(widget.playerId);
      await gameDoc.update({'activePlayers': activePlayers});

      if (activePlayers.isEmpty) {
        await FirebaseFirestore.instance.collection('games').doc(widget.gameId).delete();
      }
    }
  }

  void _startTurnTimer() {
    _turnTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (currentTurn == 'black') {
        setState(() {
          blackTimeLeft--;
        });
        if (blackTimeLeft <= 0) {
          _missTurn(); // Switch turn immediately when time runs out
        }
      } else if (currentTurn == 'white') {
        setState(() {
          whiteTimeLeft--;
        });
        if (whiteTimeLeft <= 0) {
          _missTurn(); // Switch turn immediately when time runs out
        }
      }
    });
  }

  void _startGameTimer() {

    _gameTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        gameTimeLeft--;
      });
      if (gameTimeLeft <= 0) {
        _endGameByTime(); // End the game when the 4-minute timer runs out
      }
    });
  }

  Future<void> _missTurn() async {
    final gameDoc = FirebaseFirestore.instance.collection('games').doc(widget.gameId);
    final gameSnapshot = await gameDoc.get();

    if (gameSnapshot.exists) {
      final data = gameSnapshot.data();
      if (data != null) {
        String nextTurn = currentTurn == 'black' ? 'white' : 'black';

        // Increment missed turns for the current player
        if (currentTurn == 'black') {
          blackMissedTurns++;
        } else {
          whiteMissedTurns++;
        }

        // Switch turns and reset the timer
        await gameDoc.update({
          'currentTurn': nextTurn,
          'blackTimeLeft': 30, // Reset black timer
          'whiteTimeLeft': 30, // Reset white timer
          'blackMissedTurns': blackMissedTurns,
          'whiteMissedTurns': whiteMissedTurns,
        });

        // Check if the game should end due to missed turns
        if (blackMissedTurns >= 3 || whiteMissedTurns >= 3) {
          _endGame();
        }
      }
    }
  }

   void _endGameByTime() async {
    _gameTimer?.cancel();
    _turnTimer?.cancel();

    String winner = blackScore > whiteScore ? 'black' : 'white';
    
    // Update game state to show it's ended
    await FirebaseFirestore.instance.collection('games').doc(widget.gameId).update({
      'status': 'ended',
      'winner': winner,
      'finalBlackScore': blackScore,
      'finalWhiteScore': whiteScore,
      'endReason': 'timeout'
    });

    // Determine if current player is the winner
    bool isCurrentPlayerWinner = (winner == 'black' && player1Stone == 'black' && widget.playerId == player1Id) ||
                               (winner == 'white' && player2Stone == 'white' && widget.playerId == player2Id);

    // Show personalized dialog to current player
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(isCurrentPlayerWinner ? 'You Won!' : 'Game Over'),
        content: Text(
          isCurrentPlayerWinner
            ? 'Congratulations! You won with ${winner == 'black' ? blackScore : whiteScore} points!'
            : 'Your opponent won with ${winner == 'black' ? blackScore : whiteScore} points.'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              destroyTheScreen();
            },
            child: Text('OK'),
          ),
        ],
      ),
    );

    // Wait a few seconds before marking players inactive and deleting the game
    await Future.delayed(Duration(seconds: 5));
    await FirebaseFirestore.instance.collection('games').doc(widget.gameId).update({
      'activePlayers': [], // Mark both players as inactive
    });
    await FirebaseFirestore.instance.collection('games').doc(widget.gameId).delete();
  }



  
  void _endGame() async {
    String winner = blackMissedTurns >= 3 ? 'white' : 'black';
    await FirebaseFirestore.instance.collection('games').doc(widget.gameId).update({
      'winner': winner,
      'activePlayers': [], // Mark both players as inactive
    });

    _turnTimer?.cancel();
    _gameTimer?.cancel();

    // Determine if current player is the winner
    bool isCurrentPlayerWinner = (winner == 'black' && player1Stone == 'black' && widget.playerId == player1Id) ||
                               (winner == 'white' && player2Stone == 'white' && widget.playerId == player2Id);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isCurrentPlayerWinner ? 'You Won!' : 'Game Over'),
        content: Text(
          isCurrentPlayerWinner
            ? 'Congratulations! You won due to opponent\'s missed turns!'
            : 'Your opponent won due to your missed turns.'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              destroyTheScreen();
            },
            child: Text('OK'),
          ),
        ],
      ),
    );

    // Delete the game after a short delay
    await Future.delayed(Duration(seconds: 1));
    await FirebaseFirestore.instance.collection('games').doc(widget.gameId).delete();
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

  Future<void> _captureStones(List<List<int>> group) async {
    final gameDoc = FirebaseFirestore.instance.collection('games').doc(widget.gameId);
    final gameSnapshot = await gameDoc.get();

    if (gameSnapshot.exists) {
      final data = gameSnapshot.data();
      if (data != null) {
        String currentTurn = data['currentTurn'] ?? 'black';

        // Update the score for the capturing player
        if (currentTurn == 'black') {
          blackScore += group.length;
        } else {
          whiteScore += group.length;
        }

        // Remove the captured stones from the board
        for (var pos in group) {
          board[pos[1]][pos[0]] = Stone.none;
        }

        // Update the board and scores in Firestore
        Map<String, String> firestoreBoard = {};
        for (int y = 0; y < widget.size; y++) {
          for (int x = 0; x < widget.size; x++) {
            String key = '$x\_$y';
            firestoreBoard[key] = board[y][x] == Stone.black
                ? 'black'
                : board[y][x] == Stone.white
                    ? 'white'
                    : 'none';
          }
        }

        await gameDoc.update({
          'board': firestoreBoard,
          'blackScore': blackScore,
          'whiteScore': whiteScore,
        });
      }
    }
  }

  Future<void> _placeStone(int x, int y) async {
    final gameDoc = FirebaseFirestore.instance.collection('games').doc(widget.gameId);
    final gameSnapshot = await gameDoc.get();

    if (gameSnapshot.exists) {
      final data = gameSnapshot.data();
      if (data != null) {
        String currentTurn = data['currentTurn'] ?? 'black';

        if ((currentTurn == 'black' && widget.playerId == player1Id) ||
            (currentTurn == 'white' && widget.playerId == player2Id)) {
          if (board[y][x] != Stone.none) return; // Cell is already occupied

          setState(() {
            board[y][x] = currentTurn == 'black' ? Stone.black : Stone.white;
            if (currentTurn == 'black') {
              blackTimeLeft = 30;
            } else {
              whiteTimeLeft = 30;
            }

          });
          

          // Check for captures
          Stone opponent = currentTurn == 'black' ? Stone.white : Stone.black;
          for (var dir in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
            int nx = x + dir[0];
            int ny = y + dir[1];
            if (nx >= 0 && nx < widget.size && ny >= 0 && ny < widget.size && board[ny][nx] == opponent) {
              var opponentGroup = _findGroup(nx, ny, opponent);
              if (!_hasLiberty(opponentGroup)) {
                await _captureStones(opponentGroup);
              }
            }
          }

          // Convert the board to a map for Firestore
          Map<String, String> firestoreBoard = {};
          for (int y = 0; y < widget.size; y++) {
            for (int x = 0; x < widget.size; x++) {
              String key = '$x\_$y';
              firestoreBoard[key] = board[y][x] == Stone.black
                  ? 'black'
                  : board[y][x] == Stone.white
                      ? 'white'
                      : 'none';
            }
          }

          // Switch turns
          String nextTurn = currentTurn == 'black' ? 'white' : 'black';
          await gameDoc.update({
            'board': firestoreBoard,
            'currentTurn': nextTurn, // Switch turns
            'blackTimeLeft': blackTimeLeft, // Update black timer
            'whiteTimeLeft': whiteTimeLeft, // Update white timer
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _turnTimer?.cancel();
    _gameTimer?.cancel();
    _markPlayerAsInactive();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 253, 192, 100),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 253, 192, 100),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Go Multiplayer',
              style: TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
            ),
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: gameTimeLeft / widget.totalGameTime*60,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  Text(
                    '${gameTimeLeft ~/ 60}:${(gameTimeLeft % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
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

          return Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Opponent Info
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 40,
                                height: 40,
                                child: CircularProgressIndicator(
                                  value: currentTurn == 'black' ? blackTimeLeft / 30 : 0, // Only active for black's turn
                                  backgroundColor: Colors.grey[300],
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                ),
                              ),
                              CircleAvatar(
                                radius: 20,
                                child: Icon(Icons.person),
                              ),
                            ],
                          ),
                          SizedBox(width: 10),
                          Text(
                            "$userName(${player1Stone == 'black' ? 'Black' : 'White'}) - $blackScore",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    // Go Board
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
                                top: i * cellSize + padding,
                                left: padding,
                                width: boardSize,
                                child: Container(
                                  height: 1,
                                  color: Colors.black,
                                ),
                              ),
                            for (int i = 0; i < widget.size; i++)
                              Positioned(
                                left: i * cellSize + padding,
                                top: padding,
                                height: boardSize,
                                child: Container(
                                  width: 1,
                                  color: Colors.black,
                                ),
                              ),
                            for (int y = 0; y < widget.size; y++)
                              for (int x = 0; x < widget.size; x++)
                                if (board[y][x] != Stone.none)
                                  Positioned(
                                    top: y * cellSize + padding - stoneSize / 2,
                                    left: x * cellSize + padding - stoneSize / 2,
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
                                  onTap: () {
                                    if (isPlayerTurn) {
                                      _placeStone(x, y);
                                    }
                                  },
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
                    // Current User Info
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 40,
                                height: 40,
                                child: CircularProgressIndicator(
                                  value: currentTurn == 'white' ? whiteTimeLeft / 30 : 0, // Only active for white's turn
                                  backgroundColor: Colors.grey[300],
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                ),
                              ),
                              CircleAvatar(
                                radius: 20,
                                child: Icon(Icons.person),
                              ),
                            ],
                          ),
                          SizedBox(width: 10),
                          Text(
                            "$partnerName(${player2Stone == 'black' ? 'Black' : 'White'}) - $whiteScore",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Notification for current user's turn
              // _notifyUserTurn(isPlayerTurn);
               
              if (isPlayerTurn && showTurnNotification)

                Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Your Turn!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
  

  Widget _buildStone(Stone stone, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: stone == Stone.black ? Colors.black : Colors.white,
        border: Border.all(color: Colors.black),
      ),
    );
  }
}