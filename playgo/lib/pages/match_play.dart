import 'dart:async';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:playgo/main.dart';
import 'package:playgo/pages/home.dart';
import 'package:flutter/services.dart';
import 'package:playgo/pages/info.dart';

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
  final String entryPrice;
  final String prizePool;
  const GoBoardMatch({Key? key, required this.size, required this.gameId, required this.playerId , required this.totalGameTime,required this.entryPrice,required this.prizePool}) : super(key: key);

  @override
  State<GoBoardMatch> createState() => _GoMultiplayerBoardState();
}

class _GoMultiplayerBoardState extends State<GoBoardMatch> with WidgetsBindingObserver {
  late List<List<Stone>> board;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> gameStream;
  bool isPlayerTurn = false;
  int blackScore = 0;
  int whiteScore = 0;
  int blackMissedTurns = 0;
  int whiteMissedTurns = 0;
  int blackTimeLeft = 15; // Timer for black player
  int whiteTimeLeft = 15; // Timer for white player
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
  bool isDialogShowing = false;
  bool isLandscape = false;
  String? currentEmoji; // Track the current emoji to display
  String? emojiProfileCardId; // Track which profile card the emoji belongs to
  Map<String, String> playerEmojis = {}; // Track emojis for both players
  PlaceStoneSound placeStoneSound = PlaceStoneSound();
  bool get isTablet {
    final data = MediaQueryData.fromView(WidgetsBinding.instance.platformDispatcher.views.first);
    return data.size.shortestSide >= 600;
  }
  bool _blackPassed = false;
  bool _whitePassed = false;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    gameTimeLeft = widget.totalGameTime * 60;
    _initializeBoard();
    gameStream = FirebaseFirestore.instance.collection('games').doc(widget.gameId).snapshots();
    _listenToGameUpdates();
    _startTurnTimer();
    _startGameTimer();
    _markPlayerAsActive();
    _initializePlayers();
    _listenToEmojiUpdates();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);  // to only hide the status bar
    // Set orientation based on device type (phone or tablet)
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

 void _listenToEmojiUpdates() {
  FirebaseFirestore.instance
    .collection('games')
    .doc(widget.gameId)
    .collection('emojiUpdates')
    .orderBy('timestamp', descending: true)
    .limit(1)
    .snapshots()
    .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final emoji = doc['emoji'];
        final senderId = doc['senderId'];
        final timestamp = doc['timestamp'];

        // Show emoji only if it's recent (within 3 seconds)
        if (DateTime.now().millisecondsSinceEpoch - timestamp <= 3000) {
          setState(() {
            playerEmojis[senderId] = emoji;
          });

          // Remove after 3 seconds
          Future.delayed(Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                playerEmojis.remove(senderId);
              });
            }
          });
        }
      }
    });

}

  void _showEmojiPicker(String senderId) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return EmojiPicker(
          onEmojiSelected: ( category,emoji) {
            _sendEmoji(emoji.emoji, senderId);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Future<void> _sendEmoji(String emoji, String senderId) async {
  
  await FirebaseFirestore.instance
    .collection('games')
    .doc(widget.gameId)
    .collection('emojiUpdates')
    .add({
      'emoji': emoji,
      'senderId': senderId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

}

Widget _buildPlayerInfo({
  required String name,
  required int score,
  required bool isBlack,
  required int timeLeft,
  required bool isCurrentTurn,
  required String playerId,
  required bool isCurrentUser,
}) {
  return Container(
    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.9),
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          spreadRadius: 1,
          blurRadius: 3,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCurrentTurn ? Colors.blue : Colors.grey,
                      width: 2,
                    ),
                  ),
                  child: CircularProgressIndicator(
                    value: timeLeft / 30,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCurrentTurn ? Colors.blue : Colors.grey,
                    ),
                  ),
                ),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isBlack ? Colors.black : Colors.white,
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                ),
              ],
            ),
            SizedBox(width: 12),
            Text(
              name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Score: $score',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ),
            if (isCurrentUser) // Show emoji button only for the current user
              IconButton(
                icon: Icon(Icons.emoji_emotions, color: Colors.blue),
                onPressed: () => _showEmojiPicker(playerId), // Pass the current user's ID
              ),
          ],
        ),
        // Display the emoji if it belongs to this profile card
        if (playerEmojis.containsKey(playerId))
          Text(
            playerEmojis[playerId]!,
            style: TextStyle(fontSize: 24),
          ),
      ],
    ),
  );
}

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _turnTimer?.cancel();
    _gameTimer?.cancel();
    _markPlayerAsInactive();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);  // to only hide the status bar

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    placeStoneSound.disposeStoneSound();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final orientation = MediaQuery.of(context).orientation;
    setState(() {
      isLandscape = orientation == Orientation.landscape;
    });
  }

  void _initializeBoard() {
    board = List.generate(widget.size, (_) => List.filled(widget.size, Stone.none));
    _blackPassed = false;  // Add this line
    _whitePassed = false;  // Add this line

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
        // Check for forfeit first
        if (data['status'] == 'ended' && data['endReason'] == 'forfeit') {
          String forfeitedBy = data['forfeitedBy'];
          if (forfeitedBy != widget.playerId && !isDialogShowing) {
            // Show win dialog to the opponent
            _showWinnerDialog(widget.playerId == player1Id ? player1Stone! : player2Stone!);
            return;
          }
          return; // Skip other updates if game ended by forfeit
        }

        // Inside _listenToGameUpdates(), after the forfeit check:
        if (data['status'] == 'ended' && data['endReason'] == 'normal' && !isDialogShowing) {
            String winner = data['winner'] ?? 'Both';
            _showWinnerDialog(winner);
            
            // Clean up after both players have seen the result
            if (data['endedBy'] == widget.playerId) {
              await Future.delayed(Duration(seconds: 5));
              await FirebaseFirestore.instance.collection('games').doc(widget.gameId).update({
                'activePlayers': [],
              });
              await FirebaseFirestore.instance.collection('games').doc(widget.gameId).delete();
            }
            return;
          }

        // Update pass states from Firestore - ADD AFTER FORFEIT CHECK
        _blackPassed = data['blackPassed'] ?? false;
        _whitePassed = data['whitePassed'] ?? false;

        // Check if opponent passed - ADD AFTER FORFEIT CHECK
        // Inside _listenToGameUpdates
          String lastPasserId = data['lastPasserId'] ?? '';
          if (lastPasserId.isNotEmpty && lastPasserId != widget.playerId) {
            // Clear the passer ID
            await FirebaseFirestore.instance.collection('games').doc(widget.gameId).update({
              'lastPasserId': '',
            });

            // Show beautiful notification for opponent
            _showPassNotification(
              message: 'Opponent passed their turn',
              icon: Icons.notifications_active,
              color: Colors.blue[400]!,
            );
          }
        
        // Check if the board has changed
        bool boardChanged = false;
        final Map<String, dynamic> firestoreBoard = data['board'] ?? {};
        for (int y = 0; y < widget.size; y++) {
          for (int x = 0; x < widget.size; x++) {
            String key = '$x\_$y';
            String stone = firestoreBoard[key] ?? 'none';
            Stone newStone = stone == 'black' ? Stone.black : 
                           stone == 'white' ? Stone.white : Stone.none;
            
            if (board[y][x] != newStone) {
              boardChanged = true;
              break;
            }
          }
          if (boardChanged) break;
        }

        // Play sound if board changed (stone was placed)
        if (boardChanged) {
          await placeStoneSound.playStoneSound();
        }


        // Regular game updates continue here...
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

          // Update scores
          blackScore = data['blackScore'] ?? 0;
          whiteScore = data['whiteScore'] ?? 0;

          // Update missed turns
          blackMissedTurns = data['blackMissedTurns'] ?? 0;
          whiteMissedTurns = data['whiteMissedTurns'] ?? 0;

          // Update timers
          blackTimeLeft = data['blackTimeLeft'] ?? 30;
          whiteTimeLeft = data['whiteTimeLeft'] ?? 30;

          // Update current turn
          String newTurn = data['currentTurn'] ?? 'black';

          // Check if the turn has changed
          if (newTurn != currentTurn) {
            currentTurn = newTurn;

            // Determine if it's the current player's turn
            isPlayerTurn = (currentTurn == 'black' && widget.playerId == player1Id && player1Stone == 'black') ||
                (currentTurn == 'white' && widget.playerId == player2Id && player2Stone == 'white');

            // Show turn notification if it's player's turn (only for moves, not emoji)
            if (isPlayerTurn && !showTurnNotification) {
              showTurnNotification = true;
              Future.delayed(Duration(seconds: 1), () {
                if (mounted) {
                  setState(() {
                    showTurnNotification = false;
                  });
                }
              });
            }
          }

          // Update player information
          player1Id = data['player1Id'];
          player2Id = data['player2Id'];
          player1Stone = data['player1Stone'];
          player2Stone = data['player2Stone'];

          // Update player names
          userName = data[player1Id] ?? '';
          partnerName = data[player2Id] ?? '';
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
        _blackPassed = false;
        _whitePassed = false;


        // Switch turns without resetting timer
        await gameDoc.update({
          'currentTurn': nextTurn,
          'blackMissedTurns': blackMissedTurns,
          'whiteMissedTurns': whiteMissedTurns,
          'blackPassed': false,    // ADD THIS LINE
          'whitePassed': false,    // ADD THIS LINE
        });

        // Check if the game should end due to missed turns
        if (blackMissedTurns >= 3 || whiteMissedTurns >= 3) {
          _endGameByTime();
        }
      }
    }
  }


  void _endGameByTime() async {
    _gameTimer?.cancel();
    _turnTimer?.cancel();

    // Determine winner based on missed turns, not points
    String winner;
    String winnerId;

    if (blackMissedTurns >= 3) {
      winner = 'white';
      winnerId = winner == 'black' 
            ? (player1Stone == 'black' ? player1Id! : player2Id!)
            : (player1Stone == 'white' ? player1Id! : player2Id!);
      if (winnerId == userId){
            await info!.updateUserFund(userId, double.parse(widget.prizePool));
            await info!.updateUserWinning(userId, double.parse(widget.prizePool));
      }
    } 
      else if (whiteMissedTurns >= 3) {
      winner = 'black';
      winnerId = winner == 'black' 
            ? (player1Stone == 'black' ? player1Id! : player2Id!)
            : (player1Stone == 'white' ? player1Id! : player2Id!);
      if (winnerId == userId){
            await info!.updateUserFund(userId, double.parse(widget.prizePool));
            await info!.updateUserWinning(userId, double.parse(widget.prizePool));

        }
    } else {
      // If no missed turns, then use points
      if (blackScore == whiteScore){
        winner = "Both";
        await info!.updateUserFund(userId, double.parse(widget.entryPrice));
      }
      else{
        winner = blackScore > whiteScore ? 'black' : 'white';
        winnerId = winner == 'black' 
            ? (player1Stone == 'black' ? player1Id! : player2Id!)
            : (player1Stone == 'white' ? player1Id! : player2Id!);
        if (winnerId == userId){
            await info!.updateUserFund(userId, double.parse(widget.prizePool));
            await info!.updateUserWinning(userId, double.parse(widget.prizePool));

        }
      }
    }
    info!.updateGameStatus("DeActive",player1Id!,"0.0");
    info!.updateGameStatus("DeActive", player2Id!,"0.0");
    // Update game state
    await FirebaseFirestore.instance.collection('games').doc(widget.gameId).update({
      'status': 'ended',
      'winner': winner,
      'endReason': 'timeout'
    });

    _showWinnerDialog(winner);

    // Clean up game
    await Future.delayed(Duration(seconds: 5));
    await FirebaseFirestore.instance.collection('games').doc(widget.gameId).update({
      'activePlayers': [],
    });
    await FirebaseFirestore.instance.collection('games').doc(widget.gameId).delete();
    

  }

   void _showWinnerDialog(String winner) {
    _turnTimer!.cancel();
    _gameTimer!.cancel();
    // If dialog is already showing, don't show another one
    if (isDialogShowing) return;
    isDialogShowing = true;

    // Determine if current player is the winner
    if (winner != "Both"){
      bool isCurrentPlayerWinner = (winner == 'black' && player1Stone == 'black' && widget.playerId == player1Id) ||
                                  (winner == 'white' && player2Stone == 'white' && widget.playerId == player2Id);
                                
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
        onWillPop: () async {
          // Prevent back button from closing the dialog
          return false;
        },
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isCurrentPlayerWinner 
                  ? [Colors.blue.shade200, Colors.blue.shade400]
                  : [Colors.grey.shade200, Colors.grey.shade400],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isCurrentPlayerWinner ? Icons.emoji_events : Icons.star,
                  size: 60,
                  color: isCurrentPlayerWinner ? Colors.amber : Colors.grey.shade700,
                ),
                SizedBox(height: 16),
                Text(
                  isCurrentPlayerWinner ? 'Victory!' : 'You Lose',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  isCurrentPlayerWinner
                    ? 'Congratulations on your win!'
                    : 'Better luck next time!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: isCurrentPlayerWinner ? Colors.blue : Colors.grey.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    destroyTheScreen();
                  },
                  child: Text('Continue'),
                ),
              ],
            ),
          ),
        ),
        ),
      );
    }
    else{
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
        onWillPop: () async {
          // Prevent back button from closing the dialog
          return false;
        },
         child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: 
                  [Colors.blue.shade200, Colors.blue.shade400]
                 
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.emoji_events,
                  size: 60,
                  color:  Colors.amber ,
                ),
                SizedBox(height: 16),
                Text(
                  "Draw Match!",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  "Sorry Draw The Match,Next time try to win the match!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor:  Colors.blue ,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    destroyTheScreen();
                  },
                  child: Text('Continue'),
                ),
              ],
            ),
          ),
        ),
        ),
      );
    }
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
        
        // Check if cell is already occupied
        if (board[y][x] != Stone.none) return;

        // Get current stone color
        Stone currentStone = currentTurn == 'black' ? Stone.black : Stone.white;

        // Check for suicide move
        if (isSuicideMove(board, x, y, currentStone)) {
          // Show error message to user
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invalid move: Stone would have no liberties'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        // Play sound for current player's move
        await placeStoneSound.playStoneSound();


        setState(() {
          board[y][x] = currentStone;
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
          if (nx >= 0 && nx < widget.size && ny >= 0 && ny < widget.size && 
              board[ny][nx] == opponent) {
            var opponentGroup = _findGroup(nx, ny, opponent);
            if (!_hasLiberty(opponentGroup)) {
              await _captureStones(opponentGroup);
            }
          }
        }

        // Convert board to Firestore format
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

        // Reset pass states when placing a stone - ADD BEFORE gameDoc.update()
        _blackPassed = false;
        _whitePassed = false;

        // Switch turns
        String nextTurn = currentTurn == 'black' ? 'white' : 'black';
        // Then modify the existing update call to include:
        await gameDoc.update({
          'board': firestoreBoard,
          'currentTurn': nextTurn,
          'blackTimeLeft': blackTimeLeft,
          'whiteTimeLeft': whiteTimeLeft,
          'blackPassed': false,    // ADD THIS LINE
          'whitePassed': false,    // ADD THIS LINE
        });
      }
    }
  }
}

 Future<void> _handleGameCancel() async {
    // Show confirmation dialog
    bool confirm = await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.red.shade100, Colors.red.shade200],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                spreadRadius: 5,
                blurRadius: 7,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_rounded,
                size: 50,
                color: Colors.red.shade700,
              ),
              SizedBox(height: 16),
              Text(
                'End Game?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade900,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Are you sure you wish to exit? This will result in a loss of your money.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.red.shade900.withOpacity(0.8),
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.grey.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text('End Game'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ) ?? false;


    if (confirm) {
      _turnTimer?.cancel();
      _gameTimer?.cancel();
      // Determine winner and distribute prize
      String winnerId = widget.playerId == player1Id ? player2Id! : player1Id!;
      await info!.updateUserFund(winnerId, double.parse(widget.prizePool));
      await info!.updateUserWinning(winnerId, double.parse(widget.prizePool));

      info!.updateGameStatus("DeActive",player1Id!,"0.0");
      info!.updateGameStatus("DeActive", player2Id!,"0.0");
      // Update game state in Firestore to trigger opponent's listener
      await FirebaseFirestore.instance.collection('games').doc(widget.gameId).update({
        'status': 'ended',
        'endReason': 'forfeit',
        'forfeitedBy': widget.playerId
      });

      // For the player who clicked cancel - show lose dialog
      if (mounted) {
        _showWinnerDialog(widget.playerId == player1Id ? player2Stone! : player1Stone!);
      }

      // Clean up game after delay
      await Future.delayed(Duration(seconds: 5));
      await FirebaseFirestore.instance.collection('games').doc(widget.gameId).update({
        'activePlayers': [],
      });
      await FirebaseFirestore.instance.collection('games').doc(widget.gameId).delete();
      
    }
  }
// Checks if placing a stone would result in suicide (no liberties)
  static bool isSuicideMove(List<List<Stone>> board, int x, int y, Stone currentStone) {
    // Temporarily place the stone to check its effect
    board[y][x] = currentStone;
    
    // Get the group that includes the new stone
    List<List<int>> group = findGroup(board, x, y, currentStone);
    
    // Check if this group has any liberties
    bool hasLiberties = hasLiberty(board, group);
    
    // Check if this move captures any opponent groups (which would make it valid)
    Stone opponentStone = currentStone == Stone.black ? Stone.white : Stone.black;
    bool capturesOpponent = false;
    
    for (var dir in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
      int nx = x + dir[0];
      int ny = y + dir[1];
      if (isValidPosition(board, nx, ny) && board[ny][nx] == opponentStone) {
        List<List<int>> opponentGroup = findGroup(board, nx, ny, opponentStone);
        if (!hasLiberty(board, opponentGroup)) {
          capturesOpponent = true;
          break;
        }
      }
    }
    
    // Remove the temporary stone
    board[y][x] = Stone.none;
    
    // The move is valid if either it has liberties or captures opponent stones
    return !hasLiberties && !capturesOpponent;
  }

  // Helper function to check if a position is within the board
  static bool isValidPosition(List<List<Stone>> board, int x, int y) {
    return x >= 0 && x < board.length && y >= 0 && y < board.length;
  }

  // Find all stones in the same group
  static List<List<int>> findGroup(List<List<Stone>> board, int x, int y, Stone stone) {
    List<List<int>> group = [];
    List<List<bool>> visited = List.generate(
      board.length,
      (_) => List.filled(board.length, false)
    );

    void dfs(int i, int j) {
      if (!isValidPosition(board, i, j) || 
          visited[j][i] || 
          board[j][i] != stone) return;
      
      visited[j][i] = true;
      group.add([i, j]);
      
      for (var dir in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
        dfs(i + dir[0], j + dir[1]);
      }
    }

    dfs(x, y);
    return group;
  }

  // Check if a group has any liberties (empty adjacent points)
  static bool hasLiberty(List<List<Stone>> board, List<List<int>> group) {
    for (var pos in group) {
      for (var dir in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
        int nx = pos[0] + dir[0];
        int ny = pos[1] + dir[1];
        if (isValidPosition(board, nx, ny) && board[ny][nx] == Stone.none) {
          return true;
        }
      }
    }
    return false;
  }
Widget _buildPassButton() {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
    child: ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: _blackPassed || _whitePassed 
            ? Colors.red[400] 
            : Colors.orange[400],
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      icon: Icon(
        _blackPassed || _whitePassed 
            ? Icons.warning 
            : Icons.skip_next,
        size: 24),
      label: Text(
        _blackPassed || _whitePassed 
            ? 'End Game' 
            : 'Pass',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      onPressed: _passTurn,
    ),
  );
}
Future<void> _endGameByPass() async {
  _gameTimer?.cancel();
  _turnTimer?.cancel();

  // Determine winner based on existing scores
  String winner;
  if (blackScore == whiteScore) {
    winner = "Both";
    await info!.updateUserFund(userId, double.parse(widget.entryPrice));
  } else {
    winner = blackScore > whiteScore ? 'black' : 'white';
    String winnerId = winner == 'black' 
        ? (player1Stone == 'black' ? player1Id! : player2Id!)
        : (player1Stone == 'white' ? player1Id! : player2Id!);
    
    if (winnerId == userId) {
      await info!.updateUserFund(userId, double.parse(widget.prizePool));
      await info!.updateUserWinning(userId, double.parse(widget.prizePool));
    }
  }

  // Update game state - this will trigger the dialog for both players
  await FirebaseFirestore.instance.collection('games').doc(widget.gameId).update({
    'status': 'ended',
    'winner': winner,
    'endReason': 'normal',
    'endedBy': widget.playerId,  // Track who ended the game
  });

  // Don't show dialog here - let _listenToGameUpdates handle it
  // Don't delete game yet - let both players see the result first

  info!.updateGameStatus("DeActive", player1Id!, "0.0");
  info!.updateGameStatus("DeActive", player2Id!, "0.0");
}

Future<bool> _showEndGameConfirmation() async {
  return await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6A11CB),
              Color(0xFF2575FC),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_events,
              size: 48,
              color: Colors.amber,
            ),
            SizedBox(height: 20),
            Text(
              "End the Game?",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 12),
            Text(
              "Passing now will end the game.\nAre you sure you want to continue?",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    "Cancel",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    elevation: 5,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    "End Game",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  ) ?? false;
}
Future<void> _passTurn() async {
  // Show confirmation if this would end the game
  if ((currentTurn == 'black' && _whitePassed) ||
      (currentTurn == 'white' && _blackPassed)) {
    bool confirm = await _showEndGameConfirmation();
    
    if (!confirm) return;
  }

  final gameDoc = FirebaseFirestore.instance.collection('games').doc(widget.gameId);
  
  // Update local pass state
  setState(() {
    if (currentTurn == 'black') {
      _blackPassed = true;
    } else {
      _whitePassed = true;
    }
  });

  // Check for two consecutive passes to end the game
  if (_blackPassed && _whitePassed) {
    await _endGameByPass();
    return;
  }

  // For single pass
  String nextTurn = currentTurn == 'black' ? 'white' : 'black';
  
  // Reset timers
  int newBlackTime = currentTurn == 'black' ? 30 : blackTimeLeft;
  int newWhiteTime = currentTurn == 'white' ? 30 : whiteTimeLeft;

  // Show notification
  _showPassNotification(
    message: 'You passed your turn',
    icon: Icons.check_circle_outline,
    color: Colors.green[400]!,
  );

  // Update Firestore
  await gameDoc.update({
    'currentTurn': nextTurn,
    'blackTimeLeft': newBlackTime,
    'whiteTimeLeft': newWhiteTime,
    'lastPasserId': widget.playerId,
    'blackPassed': _blackPassed,
    'whitePassed': _whitePassed,
  });
}

void _showPassNotification({required String message, required IconData icon, required Color color}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
      duration: Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.all(20),
      elevation: 0,
      backgroundColor: Colors.transparent,
    ),
  );
}
 @override
Widget build(BuildContext context) {
  final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

  return Scaffold(
    backgroundColor: const Color.fromARGB(255, 253, 192, 100),
    appBar: AppBar(
      backgroundColor: const Color.fromARGB(255, 253, 192, 100),
      leading: IconButton(
        icon: Icon(Icons.close, color: Colors.red), // X icon
        onPressed: _handleGameCancel,
      ),
      centerTitle: true,
      title: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF6A11CB), // Rich purple
              Color(0xFF2575FC), // Bright blue
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, -1),
            ),
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (Rect bounds) {
                return LinearGradient(
                  colors: [Colors.amber[300]!, Colors.amber[500]!],
                ).createShader(bounds);
              },
              child: Icon(
                Icons.emoji_events,
                color: Colors.white,
                size: 24,
              ),
            ),
            SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Prize Pool',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '₹${widget.prizePool}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.3),
                        offset: Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        if (isTablet && isPlayerTurn) // Show pass button in app bar for tablets
          Container(
          margin: EdgeInsets.only(right: 12),
          child: _buildPassButton()
        ),

        Container(
          margin: EdgeInsets.only(right: 16),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              Icon(Icons.timer, size: 18, color: Colors.white),
              SizedBox(width: 6),
              Text(
                '${gameTimeLeft ~/ 60}:${(gameTimeLeft % 60).toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
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
        // Determine pass button visibility
        bool showPlayer1Pass = widget.playerId == player1Id && isPlayerTurn;
        bool showPlayer2Pass = widget.playerId == player2Id && isPlayerTurn;

        return Column(
          children: [
            SizedBox(height: 8),
            if (player1Id != null) // Add null check
              Column(
                children: [

              _buildPlayerInfo(
                name: userName,
                score: blackScore,
                isBlack: player1Stone == 'black',
                timeLeft: player1Stone == 'black' ? blackTimeLeft : whiteTimeLeft,
                isCurrentTurn: currentTurn == (player1Stone == 'black' ? 'black' : 'white'),
                playerId: player1Id!, // Pass player ID
                isCurrentUser: widget.playerId == player1Id, // Check if this is the current user's card
              ),
              // Fixed height container for pass button
              if(!isTablet)
                  Container(
                    height: 72, // Same height as your pass button
                    child: showPlayer1Pass ? _buildPassButton() : null,
                  ),

                    ],),
            SizedBox(height: 4),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Board
                  Center(
                    child: Container(
                      margin: EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Container(
                            width: boardSize + padding * 2,
                            height: boardSize + padding * 2,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD3B07C),
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          // Grid lines
                          ...List.generate(widget.size, (i) => 
                            Positioned(
                              top: i * cellSize + padding,
                              left: padding,
                              child: Container(
                                width: boardSize,
                                height: 1,
                                color: Colors.black.withOpacity(0.7),
                              ),
                            ),
                          ),
                          ...List.generate(widget.size, (i) => 
                            Positioned(
                              left: i * cellSize + padding,
                              top: padding,
                              child: Container(
                                width: 1,
                                height: boardSize,
                                color: Colors.black.withOpacity(0.7),
                              ),
                            ),
                          ),
                          // Stones
                          ...List.generate(
                            widget.size * widget.size,
                            (index) {
                              int x = index % widget.size;
                              int y = index ~/ widget.size;
                              if (board[y][x] != Stone.none) {
                                return Positioned(
                                  top: y * cellSize + padding - stoneSize / 2,
                                  left: x * cellSize + padding - stoneSize / 2,
                                  child: _buildStone(board[y][x], stoneSize),
                                );
                              }
                              return SizedBox.shrink();
                            },
                          ),
                          // Touch Grid
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
                                  onTap: () {
                                    if (isPlayerTurn) {
                                      _placeStone(x, y);
                                    }
                                  },
                                  child: Container(color: Colors.transparent),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Turn Notification Overlay (centered on board)
                  if (isPlayerTurn && showTurnNotification)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'Your Turn!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 4),
            if (player2Id != null) // Add null check
              Column(
              children: [
                 // Fixed height container for pass button
                 if (!isTablet)
                    Container(
                      height: 72, // Same height as your pass button
                      child: showPlayer2Pass ? _buildPassButton() : null,
                    ),
                _buildPlayerInfo(
                  name: partnerName,
                  score: whiteScore,
                  isBlack: player2Stone == 'black',
                  timeLeft: player2Stone == 'black' ? blackTimeLeft : whiteTimeLeft,
                  isCurrentTurn: currentTurn == (player2Stone == 'black' ? 'black' : 'white'),
                  playerId: player2Id!, // Pass player ID
                  isCurrentUser: widget.playerId == player2Id, // Check if this is the current user's card
                ),
                
                  ]),
            SizedBox(height: 8),
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
        border: Border.all(color: Colors.black.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
    );
  }
}