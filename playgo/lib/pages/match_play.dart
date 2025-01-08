import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  const GoBoardMatch({Key? key, required this.size, required this.gameId, required this.playerId}) : super(key: key);

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
  int playerTimeLeft = 30;
  Timer? _timer;

  String? player1Id;
  String? player2Id;
  String? player1Stone;
  String? player2Stone;

  @override
  void initState() {
    super.initState();
    _initializeBoard();
    gameStream = FirebaseFirestore.instance.collection('games').doc(widget.gameId).snapshots();
    _listenToGameUpdates();
    _startTimer();
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

          // Initialize currentTurn if it doesn't exist
          if (!data.containsKey('currentTurn')) {
            gameDoc.update({'currentTurn': 'black'});
          }

          // Determine if it's the current player's turn
          String currentTurn = data['currentTurn'] ?? 'black';
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
            playerTimeLeft = data['playerTimeLeft'] ?? 30;

            // Determine if it's the current player's turn
            String currentTurn = data['currentTurn'] ?? 'black';
            isPlayerTurn = (currentTurn == 'black' && widget.playerId == player1Id && player1Stone == 'black') ||
                (currentTurn == 'white' && widget.playerId == player2Id && player2Stone == 'white');

            // Check if the game should end due to missed turns
            if (blackMissedTurns >= 3 || whiteMissedTurns >= 3) {
              _endGame();
            }
          });
        }
      }
    });
  }

  void destroyTheScreen(){
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

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (isPlayerTurn) {
        setState(() {
          playerTimeLeft--;
        });
        if (playerTimeLeft <= 0) {
          _missTurn(); // Switch turn immediately when time runs out
        }
      }
    });
  }

  Future<void> _missTurn() async {
    final gameDoc = FirebaseFirestore.instance.collection('games').doc(widget.gameId);
    final gameSnapshot = await gameDoc.get();

    if (gameSnapshot.exists) {
      final data = gameSnapshot.data();
      if (data != null) {
        String currentTurn = data['currentTurn'] ?? 'black';
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
          'playerTimeLeft': 30, // Reset timer for the next player
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

  void _endGame() async {
    String winner = blackMissedTurns >= 3 ? 'white' : 'black';
    await FirebaseFirestore.instance.collection('games').doc(widget.gameId).update({
      'winner': winner,
      'activePlayers': [], // Mark both players as inactive
    });

    _timer?.cancel();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Game Over'),
        content: Text('$winner wins!'),
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
            playerTimeLeft = 30;
          });

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
            'playerTimeLeft': 30, // Reset timer for the next player
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _markPlayerAsInactive();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 253, 192, 100),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 253, 192, 100),
        title: const Center(
          child: Text(
            'Go Multiplayer',
            style: TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
          ),
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

          return SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "Current Turn: ${isPlayerTurn ? 'Your Turn' : 'Opponent\'s Turn'}"
                  ),
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
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "Time Left: $playerTimeLeft seconds",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
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