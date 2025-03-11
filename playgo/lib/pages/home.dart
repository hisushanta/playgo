import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:playgo/main.dart';
import 'package:playgo/pages/match_play.dart';
import 'playgame.dart';
import 'about_pages.dart';
import 'fund_page.dart';
import 'tournament_page.dart';
import 'aiPlay.dart';
import 'wallet_pages.dart';
import 'search_user.dart';
import 'match_request.dart';

final userId = FirebaseAuth.instance.currentUser!.uid;

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MyHomePage(),
      debugShowCheckedModeBanner: false, // Remove the debug banner
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}
class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0; // Track the selected index for the navigation bar
  final List<Widget> _pages = [
    GoGameHomePage(),
    SearchPage(),
    MatchRequestPage(),
    const UserProfilePage() 
  ];
  
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
        body: _pages[_selectedIndex], // Display content based on selected index
        bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
      
        },
        backgroundColor: Colors.white,
        indicatorColor: Colors.amber,
        selectedIndex: _selectedIndex,
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.home),
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.person_search_sharp),
            icon: Icon(Icons.person_search_outlined),
            label: 'Matchmaking',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.shopping_basket_sharp),
            icon: Icon(Icons.shopping_basket_outlined),
            label: 'Request',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.account_box),
            icon: Icon(Icons.account_box_outlined),
            label: 'About',
          ),
          
        ],
        
      ), 
       
    );
  }
}

class GoGameHomePage extends StatefulWidget {
  @override
  _GoGameHomePageState createState() => _GoGameHomePageState();
}

class _GoGameHomePageState extends State<GoGameHomePage>{

  Timer? _refreshTimer;
  String fundBalance = '0.0';
  StreamSubscription<QuerySnapshot>? _confirmationListener;
  StreamSubscription<QuerySnapshot>? _countdownListener;
  bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(Duration(seconds: 3), (_) => _loadData());
    _listenForConfirmation(); // Listen for confirmation
    _listenForCountdown(); // Listen for countdown

  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _confirmationListener?.cancel();
    _countdownListener?.cancel();
    super.dispose();
  }
  
  void _listenForConfirmation() {
    _confirmationListener = FirebaseFirestore.instance
        .collection('matchRequests')
        .where('senderId', isEqualTo: userId) // Listen for requests where the current user is the sender
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        final request = snapshot.docs.first;
        final requestId = request.id;

        // Check if the confirmation dialog should be shown
        final showConfirmation = request['showConfirmation'] ?? false;

        if (showConfirmation && !_isDialogShowing) {
          _isDialogShowing = true;

          // Show the confirmation dialog
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text('Confirm Match', style: TextStyle(color: Colors.blue)),
                content: Text('The receiver has accepted your match request. Do you want to proceed?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Cancel', style: TextStyle(color: Colors.red)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('Confirm', style: TextStyle(color: Colors.blue)),
                  ),
                ],
              );
            },
          );

          // Reset the `showConfirmation` field to prevent re-triggering
          await FirebaseFirestore.instance
              .collection('matchRequests')
              .doc(requestId)
              .update({'showConfirmation': false});

          _isDialogShowing = false;

          if (confirmed == true) {
            // Update Firestore to indicate the sender has confirmed
            await FirebaseFirestore.instance
                .collection('matchRequests')
                .doc(requestId)
                .update({'senderConfirmed': true});
          } else {
            // Cancel the match request if the sender declines
            await FirebaseFirestore.instance
                .collection('matchRequests')
                .doc(requestId)
                .delete();
          }
        }
      }
    });
  }

void _listenForCountdown() {
    _countdownListener = FirebaseFirestore.instance
        .collection('matchRequests')
        .where('senderId', isEqualTo: userId) // Listen for requests where the current user is the sender
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        final request = snapshot.docs.first;
        final requestId = request.id;

        // Check if both users have confirmed
        final senderConfirmed = request['senderConfirmed'] ?? false;
        final receiverConfirmed = request['receiverConfirmed'] ?? false;
        final entryPrice = request['entryPrice']??'0.0';
        final duration = int.parse(request['duration']);

        final prizePool = double.parse(entryPrice) > 0.0?((double.parse(request['entryPrice'])*2)-(((double.parse(request['entryPrice']) * 2)/100)*2)).toString():"0.0";

        if (senderConfirmed && receiverConfirmed && !_isDialogShowing) {
          _isDialogShowing = true;

          // Show the countdown dialog
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => CountdownBottomDialog(
              time: duration,
              entryPrice: request['entryPrice'] ?? '0.0',
              prizePool:prizePool,
              partnerId: request['receiverId'],
              boardSize: request['boardSize'] ?? '9x9',
            ),
          );

          // Reset the confirmation fields to prevent re-triggering
          await FirebaseFirestore.instance
              .collection('matchRequests')
              .doc(requestId)
              .update({
            'senderConfirmed': false,
            'receiverConfirmed': false,
          });

          _isDialogShowing = false;
        }
      }
    });
  }
  void _loadData() {
  if (!mounted) return;
  setState(() {
    fundBalance = info!.userProfile[info!.uuid]?['fund'] ?? '0.0'; // Provide a default value
  });
}
  void _showAIGameDialog(BuildContext context) {
      int duration = 8; // Default duration
  int boardSize = 9; // Default board size

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            title: Center(
              child: Text(
                'Set Game Parameters',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Duration Dropdown
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer, color: Colors.blue),
                      SizedBox(width: 10),
                      Expanded(
                        child: DropdownButton<int>(
                          value: duration,
                          onChanged: (int? newValue) {
                            setState(() {
                              duration = newValue!;
                            });
                          },
                          items: List.generate(93, (index) => index + 8) // Generates 8 to 100
                              .map<DropdownMenuItem<int>>((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text(
                                '$value minutes',
                                style: TextStyle(fontSize: 16),
                              ),
                            );
                          }).toList(),
                          underline: SizedBox(), // Remove the default underline
                          isExpanded: true,
                          icon: Icon(Icons.arrow_drop_down, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20), // Spacing between dropdowns
                // Board Size Dropdown
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.grid_on, color: Colors.green),
                      SizedBox(width: 10),
                      Expanded(
                        child: DropdownButton<int>(
                          value: boardSize,
                          onChanged: (int? newValue) {
                            setState(() {
                              boardSize = newValue!;
                            });
                          },
                          items: [9, 13, 19]
                              .map<DropdownMenuItem<int>>((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text(
                                '$value x $value',
                                style: TextStyle(fontSize: 16),
                              ),
                            );
                          }).toList(),
                          underline: SizedBox(), // Remove the default underline
                          isExpanded: true,
                          icon: Icon(Icons.arrow_drop_down, color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Cancel Button
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close the dialog
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[400],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.cancel, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Cancel',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  // Start Button
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close the dialog
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GoAIBoard(size: boardSize, duration: duration),
                        ),
                      ).then((_) => _loadData());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[400],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.play_arrow, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Start',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );
    },
  );
}

void _showTwoPlayerGameDialog(BuildContext context) {
  int duration = 8; // Default duration
  int boardSize = 9; // Default board size

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            title: Center(
              child: Text(
                'Set Game Parameters',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Duration Dropdown
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer, color: Colors.blue),
                      SizedBox(width: 10),
                      Expanded(
                        child: DropdownButton<int>(
                          value: duration,
                          onChanged: (int? newValue) {
                            setState(() {
                              duration = newValue!;
                            });
                          },
                          items: List.generate(93, (index) => index + 8) // Generates 8 to 100
                              .map<DropdownMenuItem<int>>((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text(
                                '$value minutes',
                                style: TextStyle(fontSize: 16),
                              ),
                            );
                          }).toList(),
                          underline: SizedBox(), // Remove the default underline
                          isExpanded: true,
                          icon: Icon(Icons.arrow_drop_down, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20), // Spacing between dropdowns
                // Board Size Dropdown
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.grid_on, color: Colors.green),
                      SizedBox(width: 10),
                      Expanded(
                        child: DropdownButton<int>(
                          value: boardSize,
                          onChanged: (int? newValue) {
                            setState(() {
                              boardSize = newValue!;
                            });
                          },
                          items: [9, 13, 19]
                              .map<DropdownMenuItem<int>>((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text(
                                '$value x $value',
                                style: TextStyle(fontSize: 16),
                              ),
                            );
                          }).toList(),
                          underline: SizedBox(), // Remove the default underline
                          isExpanded: true,
                          icon: Icon(Icons.arrow_drop_down, color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Cancel Button
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close the dialog
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[400],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.cancel, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Cancel',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  // Start Button
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close the dialog
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GoBoard(size: boardSize, duration: duration),
                        ),
                      ).then((_) => _loadData());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[400],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.play_arrow, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Start',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
        valueListenable: info!.isLoading,
        builder: (context, bool isLoading, child) {
          // Check if still loading and no data
          if (isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
  backgroundColor: const Color.fromARGB(255, 47, 46, 46),
  elevation: 0,
  title: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      // App title aligned to the left
      Text(
        "PlayGo",
        style: TextStyle(
          color: Colors.white,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.bold,
        ),
      ),
      // Buttons aligned to the right
      Row(
        children: [
          // Add Cash Button
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => WalletPage()),
              ).then((_) => _loadData());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.green,
              side: BorderSide(color: Colors.lightGreenAccent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text('₹${double.parse(fundBalance).toStringAsFixed(2)}'),
          ),
          SizedBox(width: 8), // Reduced space between buttons
          // Wallet Button
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddCashPage()),
              ).then((_) => _loadData());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.orange,
              side: BorderSide(color: Colors.orangeAccent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Icon(Icons.add,color: Colors.orange,),
          ),
        ],
      ),
    ],
  ),
),


      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Top Section
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/goBoard.jpg', // Placeholder for the Go board image
                          width: double.maxFinite, 
                        ),
                        Text(
                          "Go Game",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "The Ancient Strategy Game",
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) =>  TournamentPage()),).then((_) => _loadData());
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                            child: Text(
                              "Start Match",
                              style: TextStyle(color: Colors.black, fontSize: 18),
                            ),
                          ),
                          
                        ),
                      ],
                    ),
                  ),
                   // Tournament Banner
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 2,horizontal: 16),
                    child: GestureDetector( 
                      child: Card(
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [const Color.fromARGB(255, 48, 48, 47), const Color.fromARGB(255, 129, 52, 252)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Two Player Game",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  "Entry: Free",
                                  style: TextStyle(color: Colors.white70),
                                ),
                                Spacer(),
                                Text(
                                  "Try It Your Family",
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    onTap: (){
                      _showTwoPlayerGameDialog(context);
                    },
                    ),
                  ),
                   // Tournament Banner
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 2,horizontal: 16),
                    child: GestureDetector( 
                      child: Card(
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [const Color.fromARGB(255, 247, 63, 12), const Color.fromARGB(255, 36, 35, 37)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "You Vs AI",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  "Entry: Free",
                                  style: TextStyle(color: Colors.white70),
                                ),
                                Spacer(),
                                Text(
                                  "Test Your Skill.",
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    onTap: (){
                      _showAIGameDialog(context);
                      // Navigator.push(context, MaterialPageRoute(builder: (context) => const GoAIBoard(size: 9,duration: 4,))).then((_) => _loadData());;
                    },
                    ),
                  ),

                  // Rules Update Banner
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.rule, color: Colors.white, size: 28),
                            SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                "Learn Go Rules\nEverything you need to know about the game",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

         
        ],
      ),
    );
  }
    );
  }
}

class CountdownBottomDialog extends StatefulWidget {
  final int time;
  final String entryPrice;
  final String prizePool;
  final String partnerId;
  final String boardSize;
  CountdownBottomDialog({
    super.key, 
    required this.time,
    required this.entryPrice,
    required this.prizePool,
    required this.partnerId,
    required this.boardSize,
  });
  
  @override
  _CountdownBottomDialogState createState() => _CountdownBottomDialogState();
}

class _CountdownBottomDialogState extends State<CountdownBottomDialog> with SingleTickerProviderStateMixin {
  late Timer _timer;
  int _matchCountdown = 3;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );
    _startTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _startTimer() {
  
          _animationController.forward();
          info!.updateGameStatus("Matched", userId,widget.entryPrice);
          _startMatchCountdown(widget.partnerId);
      } 

  void _startMatchCountdown(String partnerId) {
    String gameId = "";
  _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
    if (_matchCountdown > 0) {
      setState(() {
        _matchCountdown--;
      });
    } else {
      _timer.cancel();
      try {
        // First create the match
        Map<String, dynamic> partner = await info!.createMatch(
          userId,
          partnerId,
          info!.userProfile[userId]!["username"],
        );
        
        // Update match status to indicate this player is ready
        await info!.updateMatchStatus(partner['gameId'], userId, true);

        // Start listening for both players to be ready
        bool bothPlayersReady = false;
        int attempts = 0;
        const maxAttempts = 10; // 10 second timeout
        gameId = partner['gameId'];
        while (!bothPlayersReady && attempts < maxAttempts) {
          var matchData = await info!.getMatchStatus(partner['gameId']);
          String player1Id = partner['gameId'].split("+")[0];
          String player2Id = partner['gameId'].split("+")[1];
          if (matchData['${player1Id}Ready'] == true && matchData['${player2Id}Ready'] == true) {
            bothPlayersReady = true;
            if (mounted) {
              await info!.updateUserFund(userId, double.parse(widget.entryPrice),"dec");
              Navigator.pop(context);
              _navigateToMatchBoard(partner);
            }
            break;
          }
          attempts++;
          await Future.delayed(Duration(seconds: 1));
        }
        
        // If timeout occurs
        if (!bothPlayersReady && mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Match start timeout. Please try again.')),
          );
          // Reset match status
          await info!.updateMatchStatus(partner['gameId'], userId, false);
          await info!.updateGameStatus("DeActive", userId, "0.0");
          await info!.deleteMatch(partner['gameId']);
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error starting match. Please try again.')),
          );
          await info!.updateGameStatus("DeActive", userId, '0.0');
          await info!.deleteMatch(gameId);
        }
      }
    }
  });
}


 

  void _navigateToMatchBoard(Map<String, dynamic> partner) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GoBoardMatch(
          size: widget.boardSize=="9x9"?9:13,
          gameId: partner['gameId'],
          playerId: userId,
          totalGameTime: widget.time,
          entryPrice: widget.entryPrice,
          prizePool: widget.prizePool,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    
      return Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    spreadRadius: 5,
                    blurRadius: 15,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.people_alt_rounded,
                      size: 50,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Partner Found!",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Game starts in",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 10),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.blue,
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        "$_matchCountdown",
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    
}