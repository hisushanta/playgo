import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:playgo/main.dart';
import 'package:playgo/pages/home.dart';
import 'package:playgo/pages/info.dart';

enum Stone { none, black, white }

class Move {
  int x;
  int y;
  Stone stone;
  Move(this.x, this.y, this.stone);
}

class GoAIMatchPage extends StatefulWidget {
  final int size;
  final int totalGameTime;
  final String entryPrice;
  final String prizePool;

  const GoAIMatchPage({
    Key? key,
    required this.size,
    required this.totalGameTime,
    required this.entryPrice,
    required this.prizePool,
  }) : super(key: key);

  @override
  State<GoAIMatchPage> createState() => _GoAIMatchPageState();
}

class _GoAIMatchPageState extends State<GoAIMatchPage> with WidgetsBindingObserver {
  late List<List<Stone>> board;
  bool isPlayerTurn = true;
  int blackScore = 0;
  int whiteScore = 0;
  int blackMissedTurns = 0;
  int whiteMissedTurns = 0;
  int blackTimeLeft = 15;
  int whiteTimeLeft = 15;
  int gameTimeLeft = 240;
  String userName = "";
  String partnerName = 'Go Master';
  Timer? _turnTimer;
  Timer? _gameTimer;

  String player1Id = "";
  String player2Id = "ai_opponent";
  String player1Stone = 'black';
  String player2Stone = 'white';
  String currentTurn = 'black';
  bool showTurnNotification = false;
  bool isDialogShowing = false;
  bool isLandscape = false;

  // Emoji functionality
  String? currentEmoji;
  String? emojiProfileCardId;
  Map<String, String> playerEmojis = {};

  bool _blackPassed = false;
  bool _whitePassed = false;
  bool _playerRequestedEnd = false;
  bool _aiRequestedEnd = false;
  final Random _random = Random();
  PlaceStoneSound placeStoneSound = PlaceStoneSound();

  // AI names list
  final List<String> _aiNames = [
    'Go Master',
    'Stone Warrior', 
    'Board Strategist',
    'Ancient Player',
    'Mind Champion',
    'Territory Expert',
    'Line Walker',
    'Corner Guardian'
  ];

  bool get isTablet {
    final data = MediaQueryData.fromView(WidgetsBinding.instance.platformDispatcher.views.first);
    return data.size.shortestSide >= 600;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    gameTimeLeft = widget.totalGameTime * 60;
    _initializeBoard();
    _setupGame();
    _startTurnTimer();
    _startGameTimer();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    // Set random AI name
    partnerName = _aiNames[_random.nextInt(_aiNames.length)];
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final double shortestSide = MediaQuery.of(context).size.shortestSide;
      if (shortestSide < 600) {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    });
  }

  void _setupGame() {
    setState(() {
      player1Id = userId;
      userName = info!.userProfile[userId]!['username'];
      currentTurn = 'black';
      isPlayerTurn = true;
    });
    _deductEntryFee();
  }

  void _deductEntryFee() async {
    await info!.updateUserFund(userId, double.parse(widget.entryPrice), "dec");
  }

  void _initializeBoard() {
    board = List.generate(widget.size, (_) => List.filled(widget.size, Stone.none));
    _blackPassed = false;
    _whitePassed = false;
    _playerRequestedEnd = false;
    _aiRequestedEnd = false;
  }

  // AI Logic with human-like timing and decision making
  void _makeAIMove() {
    if (!mounted || isPlayerTurn || currentTurn != 'white') return;

    // If player requested end game, AI has a chance to agree
    if (_playerRequestedEnd && _random.nextDouble() < 0.7) { // 70% chance AI agrees to end
      // Think for a bit before agreeing
      Future.delayed(Duration(milliseconds: _random.nextInt(2000) + 1000), () {
        if (mounted) {
          _aiAgreeToEndGame();
        }
      });
      return;
    }

    // Find all valid moves for AI
    List<Move> validMoves = [];
    List<Move> goodMoves = [];
    
    for (int y = 0; y < widget.size; y++) {
      for (int x = 0; x < widget.size; x++) {
        if (board[y][x] == Stone.none) {
          // Check if move is valid (not suicide)
          if (!_isSuicideMove(x, y, Stone.white)) {
            Move move = Move(x, y, Stone.white);
            validMoves.add(move);
            
            // Check if this is a "good" move (not too close to edge, has potential)
            if (x > 1 && x < widget.size - 2 && y > 1 && y < widget.size - 2) {
              goodMoves.add(move);
            }
          }
        }
      }
    }
    
    // Sometimes AI decides to pass (10% chance if both players passed before, 5% otherwise)
    bool shouldPass = false;
    if (_blackPassed && _random.nextDouble() < 0.1) {
      shouldPass = true;
    } else if (_random.nextDouble() < 0.05 && validMoves.length > 10) {
      shouldPass = true;
    }
    
    // Think for a random time (800ms to 3000ms) to feel human
    int thinkingTime = _random.nextInt(2200) + 800;
    
    Future.delayed(Duration(milliseconds: thinkingTime), () {
      if (!mounted) return;
      
      if (shouldPass) {
        _aiPassTurn();
      } else if (validMoves.isNotEmpty) {
        // Prefer good moves if available, otherwise use any valid move
        List<Move> movesToChoose = goodMoves.isNotEmpty ? goodMoves : validMoves;
        Move aiMove = movesToChoose[_random.nextInt(movesToChoose.length)];
        _placeStoneForAI(aiMove.x, aiMove.y);
      } else {
        // If no valid moves, AI must pass
        _aiPassTurn();
      }
    });
  }

  void _placeStoneForAI(int x, int y) {
    if (board[y][x] != Stone.none) return;

    setState(() {
      board[y][x] = Stone.white;
      whiteTimeLeft = 30;
      // Reset end game requests when placing stones
      _playerRequestedEnd = false;
      _aiRequestedEnd = false;
    });

    // Check for captures
    for (var dir in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
      int nx = x + dir[0];
      int ny = y + dir[1];
      if (nx >= 0 && nx < widget.size && ny >= 0 && ny < widget.size && 
          board[ny][nx] == Stone.black) {
        var opponentGroup = _findGroup(nx, ny, Stone.black);
        if (!_hasLiberty(opponentGroup)) {
          _captureStones(opponentGroup);
        }
      }
    }

    // Switch to player's turn
    setState(() {
      currentTurn = 'black';
      isPlayerTurn = true;
      _whitePassed = false;
    });

    // Show turn notification
    _showTurnNotification();
  }

  void _aiPassTurn() {
    setState(() {
      _whitePassed = true;
      isPlayerTurn = true;
      currentTurn = 'black';
      _aiRequestedEnd = true;
    });
    
    _showTurnNotification();
    _showAIPassNotification();
  }

  void _aiAgreeToEndGame() {
    _endGameByPass();
  }

  void _showAIPassNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.orange[400]!,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.people, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$partnerName wants to end the game. Place a stone to continue or click End Game.',
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
        duration: Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(20),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
    );
  }

  void _showTurnNotification() {
    setState(() {
      showTurnNotification = true;
    });
    Future.delayed(Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          showTurnNotification = false;
        });
      }
    });
  }

  // Player move logic
  void _placeStone(int x, int y) async {
    if (!isPlayerTurn || board[y][x] != Stone.none) return;

    Stone currentStone = currentTurn == 'black' ? Stone.black : Stone.white;

    // Check for suicide move
    if (_isSuicideMove(x, y, currentStone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid move: Stone would have no liberties'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    await placeStoneSound.playStoneSound();

    setState(() {
      board[y][x] = currentStone;
      if (currentTurn == 'black') {
        blackTimeLeft = 30;
      } else {
        whiteTimeLeft = 30;
      }
      // Reset pass states and end game requests when placing stones
      _blackPassed = false;
      _whitePassed = false;
      _playerRequestedEnd = false;
      _aiRequestedEnd = false;
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
          _captureStones(opponentGroup);
        }
      }
    }

    // Switch turns
    if (currentTurn == 'black') {
      setState(() {
        currentTurn = 'white';
        isPlayerTurn = false;
      });
      
      // AI makes move after delay
      Future.delayed(Duration(milliseconds: 500), () {
        _makeAIMove();
      });
    }
  }

  // Helper methods
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
    if (currentTurn == 'black') {
      blackScore += group.length;
    } else {
      whiteScore += group.length;
    }
  }

  bool _isSuicideMove(int x, int y, Stone currentStone) {
    List<List<Stone>> tempBoard = [];
    for (int i = 0; i < widget.size; i++) {
      tempBoard.add(List<Stone>.from(board[i]));
    }
    
    tempBoard[y][x] = currentStone;
    List<List<int>> group = _findGroupOnBoard(tempBoard, x, y, currentStone);
    bool hasLiberties = _hasLibertyOnBoard(tempBoard, group);
    
    Stone opponentStone = currentStone == Stone.black ? Stone.white : Stone.black;
    bool capturesOpponent = false;
    
    for (var dir in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
      int nx = x + dir[0];
      int ny = y + dir[1];
      if (_isValidPosition(nx, ny) && tempBoard[ny][nx] == opponentStone) {
        List<List<int>> opponentGroup = _findGroupOnBoard(tempBoard, nx, ny, opponentStone);
        if (!_hasLibertyOnBoard(tempBoard, opponentGroup)) {
          capturesOpponent = true;
          break;
        }
      }
    }
    
    return !hasLiberties && !capturesOpponent;
  }

  bool _isValidPosition(int x, int y) {
    return x >= 0 && x < widget.size && y >= 0 && y < widget.size;
  }

  List<List<int>> _findGroupOnBoard(List<List<Stone>> boardState, int x, int y, Stone stone) {
    List<List<int>> group = [];
    List<List<bool>> visited = List.generate(widget.size, (_) => List.filled(widget.size, false));

    void dfs(int i, int j) {
      if (!_isValidPosition(i, j) || visited[j][i] || boardState[j][i] != stone) return;
      visited[j][i] = true;
      group.add([i, j]);
      for (var dir in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
        dfs(i + dir[0], j + dir[1]);
      }
    }

    dfs(x, y);
    return group;
  }

  bool _hasLibertyOnBoard(List<List<Stone>> boardState, List<List<int>> group) {
    for (var pos in group) {
      for (var dir in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
        int nx = pos[0] + dir[0];
        int ny = pos[1] + dir[1];
        if (_isValidPosition(nx, ny) && boardState[ny][nx] == Stone.none) {
          return true;
        }
      }
    }
    return false;
  }

  // Timer methods
  void _startTurnTimer() {
    _turnTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (currentTurn == 'black') {
        setState(() {
          blackTimeLeft--;
        });
        if (blackTimeLeft <= 0) {
          _missTurn();
        }
      } else if (currentTurn == 'white') {
        setState(() {
          whiteTimeLeft--;
        });
        if (whiteTimeLeft <= 0) {
          _missTurn();
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
        _endGameByTime();
      }
    });
  }

  void _missTurn() {
    String nextTurn = currentTurn == 'black' ? 'white' : 'black';

    // Increment missed turns
    if (currentTurn == 'black') {
      blackMissedTurns++;
    } else {
      whiteMissedTurns++;
    }

    setState(() {
      _blackPassed = false;
      _whitePassed = false;
      _playerRequestedEnd = false;
      _aiRequestedEnd = false;
      currentTurn = nextTurn;
      isPlayerTurn = currentTurn == 'black';
    });

    // Check if game should end
    if (blackMissedTurns >= 3 || whiteMissedTurns >= 3) {
      _endGameByTime();
    }

    // If it's AI's turn, make a move
    if (currentTurn == 'white' && !isPlayerTurn) {
      Future.delayed(Duration(milliseconds: 500), () {
        _makeAIMove();
      });
    }
  }

  // Game end logic
  void _endGameByTime() async {
    _gameTimer?.cancel();
    _turnTimer?.cancel();

    String winner;
    String winnerId = "";

    if (blackMissedTurns >= 3) {
      winner = 'white';
      winnerId = player2Id;
    } else if (whiteMissedTurns >= 3) {
      winner = 'black';
      winnerId = player1Id;
    } else {
      if (blackScore == whiteScore) {
        winner = "Both";
        await info!.updateUserFund(userId, double.parse(widget.entryPrice));
      } else {
        winner = blackScore > whiteScore ? 'black' : 'white';
        winnerId = winner == 'black' ? player1Id : player2Id;
        if (winnerId == userId) {
          await info!.updateUserFund(userId, double.parse(widget.prizePool));
          await info!.updateUserWinning(userId, double.parse(widget.prizePool) / 2);
        }
      }
    }

    info!.updateGameStatus("DeActive", userId, "0.0");
    _showWinnerDialog(winner);
  }

  void _endGameByPass() {
    _gameTimer?.cancel();
    _turnTimer?.cancel();

    String winner;
    if (blackScore == whiteScore) {
      winner = "Both";
      info!.updateUserFund(userId, double.parse(widget.entryPrice));
    } else {
      winner = blackScore > whiteScore ? 'black' : 'white';
      String winnerId = winner == 'black' ? player1Id : player2Id;
      if (winnerId == userId) {
        info!.updateUserFund(userId, double.parse(widget.prizePool));
        info!.updateUserWinning(userId, double.parse(widget.prizePool));
      }
    }

    info!.updateGameStatus("DeActive", userId, "0.0");
    _showWinnerDialog(winner);
  }

  void _showWinnerDialog(String winner) {
    _turnTimer!.cancel();
    _gameTimer!.cancel();
    if (isDialogShowing) return;
    isDialogShowing = true;

    // FIXED: Correct winner logic - check if current user is the winner
    bool isCurrentPlayerWinner = (winner == 'black' && player1Stone == 'black') ||
                                (winner == 'white' && player2Stone == 'white');

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
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
                  : winner == "Both"
                    ? [Colors.orange.shade200, Colors.orange.shade400]
                    : [Colors.grey.shade200, Colors.grey.shade400],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isCurrentPlayerWinner ? Icons.emoji_events : 
                  winner == "Both" ? Icons.star : Icons.sentiment_dissatisfied,
                  size: 60,
                  color: isCurrentPlayerWinner ? Colors.amber : 
                        winner == "Both" ? Colors.orange : Colors.grey.shade700,
                ),
                SizedBox(height: 16),
                Text(
                  isCurrentPlayerWinner ? 'Victory!' : 
                  winner == "Both" ? 'Draw Match!' : 'You Lose',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  isCurrentPlayerWinner ? 'Congratulations on your win!' :
                  winner == "Both" ? 'The game ended in a draw!' :
                  'Better luck next time!',
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
                    foregroundColor: isCurrentPlayerWinner ? Colors.blue : 
                                  winner == "Both" ? Colors.orange : Colors.grey.shade700,
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

  // Pass button functionality
  Widget _buildPassButton() {
    bool showEndGame = (_playerRequestedEnd && _aiRequestedEnd) || 
                      (_blackPassed && _whitePassed);
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: showEndGame ? Colors.red[400] : Colors.orange[400],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        icon: Icon(
          showEndGame ? Icons.warning : Icons.skip_next,
          size: 24),
        label: Text(
          showEndGame ? 'End Game' : 'Pass',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        onPressed: showEndGame ? _endGameByPass : _passTurn,
      ),
    );
  }

  // Fixed container that always maintains same height but with minimal height
  Widget _buildPassButtonContainer() {
    bool showPassButton = isPlayerTurn;
    
    return Container(
      height: 60, // Reduced height to minimize gap
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: 200),
        child: showPassButton 
            ? _buildPassButton()
            : SizedBox.shrink(), // Empty but same height container
      ),
    );
  }

  Future<void> _passTurn() async {
    if (!isPlayerTurn) return;

    setState(() {
      if (currentTurn == 'black') {
        _blackPassed = true;
        _playerRequestedEnd = true;
      } else {
        _whitePassed = true;
      }
    });

    String nextTurn = currentTurn == 'black' ? 'white' : 'black';
    
    // Reset timers
    int newBlackTime = currentTurn == 'black' ? 30 : blackTimeLeft;
    int newWhiteTime = currentTurn == 'white' ? 30 : whiteTimeLeft;

    setState(() {
      currentTurn = nextTurn;
      isPlayerTurn = currentTurn == 'black';
      blackTimeLeft = newBlackTime;
      whiteTimeLeft = newWhiteTime;
    });

    // Show notification
    _showPassNotification(
      message: 'You passed your turn. Waiting for $partnerName response...',
      icon: Icons.check_circle_outline,
      color: Colors.green[400]!,
    );

    // If it's AI's turn after player passes, AI should decide whether to pass back or play
    if (currentTurn == 'white' && !isPlayerTurn) {
      Future.delayed(Duration(milliseconds: 500), () {
        _makeAIMove();
      });
    }
  }

  void _showPassNotification({required String message, required IconData icon, required Color color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Expanded(child: Text(message, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500))),
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

  // Emoji functionality with proper picker
  void _showEmojiPicker(String senderId) {
    List<String> emojis = [
      "😊", "😂", "🥰", "😎", "🔥", "⭐", "🎯", "🏆",
      "👍", "👏", "🙌", "💪", "🎉", "✨", "💯", "❤️"
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: 300,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Choose an Emoji',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: emojis.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        _sendEmoji(emojis[index], senderId);
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.grey[100],
                        ),
                        child: Center(
                          child: Text(
                            emojis[index],
                            style: TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _sendEmoji(String emoji, String senderId) {
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

  // Player info with emoji support
  Widget _buildPlayerInfo({
    required String name,
    required int score,
    required bool isBlack,
    required int timeLeft,
    required bool isCurrentTurn,
    required String playerId,
    required bool isCurrentUser,
  }) {
    bool isAI = playerId == "ai_opponent";
    
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4), // Reduced vertical margin
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
                  onPressed: () => _showEmojiPicker(playerId),
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

  // Cancel game handler
  Future<void> _handleGameCancel() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_rounded, size: 50, color: Colors.red.shade700),
              SizedBox(height: 16),
              Text('End Game?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red.shade900)),
              SizedBox(height: 12),
              Text('Are you sure you wish to exit? This will result in a loss of your money.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.red.shade900.withOpacity(0.8)),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.grey.shade700),
                    child: Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
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
      // AI wins when player cancels - no refund
      info!.updateGameStatus("DeActive", userId, "0.0");
      destroyTheScreen();
    }
  }

  void destroyTheScreen() {
    Navigator.pop(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _turnTimer?.cancel();
    _gameTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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

  // Build method
  @override
  Widget build(BuildContext context) {
    final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 253, 192, 100),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 253, 192, 100),
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.red),
          onPressed: _handleGameCancel,
        ),
        centerTitle: true,
        title: Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events, color: Colors.amber, size: 24),
              SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Prize Pool', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
                  Text('⭐${widget.prizePool}', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          if (isTablet && isPlayerTurn)
            Container(margin: EdgeInsets.only(right: 12), child: _buildPassButton()),
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // FIXED: Use similar board sizing as multiplayer version
          double boardSize = isLandscape
              ? constraints.maxHeight * 0.7 // Use more height in landscape
              : constraints.maxWidth > constraints.maxHeight
                  ? constraints.maxHeight * 0.85 // Use more height in portrait
                  : constraints.maxWidth * 0.95; // Use almost full width

          double padding = boardSize * 0.05;
          boardSize -= padding * 2;
          double cellSize = boardSize / (widget.size - 1);
          double stoneSize = cellSize * 0.8;

          return Column(
            children: [
              SizedBox(height: 4), // Reduced top spacing
              // Player 1 (User)
              Column(
                children: [
                  _buildPlayerInfo(
                    name: userName,
                    score: blackScore,
                    isBlack: player1Stone == 'black',
                    timeLeft: player1Stone == 'black' ? blackTimeLeft : whiteTimeLeft,
                    isCurrentTurn: currentTurn == (player1Stone == 'black' ? 'black' : 'white'),
                    playerId: player1Id,
                    isCurrentUser: true,
                  ),
                  // FIXED: Minimal gap pass button container
                  if(!isTablet) _buildPassButtonContainer(),
                ],
              ),
              SizedBox(height: 2), // Minimal gap
              Expanded(
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Board
                      Container(
                        margin: EdgeInsets.symmetric(vertical: 2), // Reduced margin
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
                                child: Container(width: boardSize, height: 1, color: Colors.black.withOpacity(0.7)),
                              ),
                            ),
                            ...List.generate(widget.size, (i) => 
                              Positioned(
                                left: i * cellSize + padding,
                                top: padding,
                                child: Container(width: 1, height: boardSize, color: Colors.black.withOpacity(0.7)),
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
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: widget.size),
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
                      // Turn Notification Overlay
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
              ),
              SizedBox(height: 2), // Minimal gap
              // Player 2 (AI)
              _buildPlayerInfo(
                name: partnerName,
                score: whiteScore,
                isBlack: player2Stone == 'black',
                timeLeft: player2Stone == 'black' ? blackTimeLeft : whiteTimeLeft,
                isCurrentTurn: currentTurn == (player2Stone == 'black' ? 'black' : 'white'),
                playerId: player2Id,
                isCurrentUser: false,
              ),
              SizedBox(height: 4), // Reduced bottom spacing
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