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
    // const UserProfilePage() 
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
            barrierDismissible: false,
            builder: (context) {
              return AlertDialog(
                title: Text('Match Confirmed', 
                    style: TextStyle(fontWeight: FontWeight.bold)),
                content: Text('Your opponent has accepted the match! Ready to play?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('Play', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
            isDismissible: false,
            enableDrag: false,
            isScrollControlled: true,
            builder: (context) => PopScope(
            canPop: false,
            child: CountdownBottomDialogForGame(
              time: duration,
              entryPrice: request['entryPrice'] ?? '0.0',
              prizePool:prizePool,
              partnerId: request['receiverId'],
              boardSize: request['boardSize'] ?? '9x9',
            ),
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
   int duration = 15;
  int boardSize = 9;
  final List<int> presetDurations = [5, 10, 15, 20, 30, 45, 60];
  final TextEditingController customDurationController = TextEditingController();

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24.0),
            ),
            child: SingleChildScrollView(  // Added scroll for keyboard
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  const Icon(Icons.timer_outlined, size: 48, color: Colors.blueAccent),
                  const SizedBox(height: 16),
                  Text(
                    'Game Settings',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Duration Picker
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          'Select Duration',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: presetDurations.length,
                          itemBuilder: (context, index) {
                            final minutes = presetDurations[index];
                            final isSelected = duration == minutes && customDurationController.text.isEmpty;
                            
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  duration = minutes;
                                  customDurationController.clear();
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(right: 12),
                                width: 80,
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.blue[50] : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? Colors.blue : Colors.grey[300]!,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$minutes',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[800],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      minutes < 60 ? 'min' : 'hour${minutes > 60 ? "s" : ""}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Custom Duration Input
                  TextField(
                    controller: customDurationController,
                    decoration: InputDecoration(
                      labelText: 'Or enter custom minutes',
                      prefixIcon: const Icon(Icons.edit),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[400]!),
                      ),
                      suffixText: 'min',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        if (value.isNotEmpty) {
                          duration = int.tryParse(value) ?? duration;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // Board Size Display
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.grid_on, color: Colors.green[700]),
                        const SizedBox(width: 12),
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Board Size: ',
                                style: TextStyle(fontSize: 16),
                              ),
                              TextSpan(
                                text: '9 × 9',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: BorderSide(color: Colors.red[400]!),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('CANCEL'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GoAIBoard(
                                  size: boardSize,
                                  duration: duration,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'START GAME',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

  void _showTwoPlayerGameDialog(BuildContext context) {
  int duration = 15;
  int boardSize = 9;
  final List<int> presetDurations = [5, 10, 15, 20, 30, 45, 60];
  final TextEditingController customDurationController = TextEditingController();

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24.0),
            ),
            child: SingleChildScrollView(  // Added scroll for keyboard
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  const Icon(Icons.timer_outlined, size: 48, color: Colors.blueAccent),
                  const SizedBox(height: 16),
                  Text(
                    'Game Settings',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Duration Picker
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          'Select Duration',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: presetDurations.length,
                          itemBuilder: (context, index) {
                            final minutes = presetDurations[index];
                            final isSelected = duration == minutes && customDurationController.text.isEmpty;
                            
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  duration = minutes;
                                  customDurationController.clear();
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(right: 12),
                                width: 80,
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.blue[50] : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? Colors.blue : Colors.grey[300]!,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$minutes',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[800],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      minutes < 60 ? 'min' : 'hour${minutes > 60 ? "s" : ""}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Custom Duration Input
                  TextField(
                    controller: customDurationController,
                    decoration: InputDecoration(
                      labelText: 'Or enter custom minutes',
                      prefixIcon: const Icon(Icons.edit),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[400]!),
                      ),
                      suffixText: 'min',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        if (value.isNotEmpty) {
                          duration = int.tryParse(value) ?? duration;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // Board Size Display
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.grid_on, color: Colors.green[700]),
                        const SizedBox(width: 12),
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Board Size: ',
                                style: TextStyle(fontSize: 16),
                              ),
                              TextSpan(
                                text: '9 × 9',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: BorderSide(color: Colors.red[400]!),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('CANCEL'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GoBoard(
                                  size: boardSize,
                                  duration: duration,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'START GAME',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
  backgroundColor: Colors.white,
  elevation: 0,
  title: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      // App title aligned to the left
      Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/homeIcon.png',
              width: 24,
              height: 24,
            ),
            const SizedBox(width: 4),
            const Text(
              "Play Go",
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
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
              backgroundColor:  Colors.white,
              foregroundColor: Colors.green,
              elevation: 20,
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
                MaterialPageRoute(builder: (context) => UserProfilePage()),
              ).then((_) => _loadData());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.orange,
              side: BorderSide(color: Colors.orangeAccent),
              elevation: 20,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Icon(Icons.settings,color: Colors.orange,),
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
                        color: Colors.black, // Use a dark background for contrast
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Background Image
                          ClipRRect(
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                            child: Image.asset(
                              'assets/goBoard.jpg', // Replace with your image path
                              width: double.infinity,
                              height: 250, // Adjust height as needed
                              fit: BoxFit.cover, // Ensure the image covers the area
                              opacity: AlwaysStoppedAnimation(0.7), // Add opacity for better text visibility
                            ),
                          ),
                          // Content Overlay
                          Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Title and Subtitle
                                Text(
                                  "Go Game",
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "The Ancient Strategy Game",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white70,
                                  ),
                                ),
                                SizedBox(height: 20),
                                // Start Match Button
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => TournamentPage()),
                                    ).then((_) => _loadData());
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30), // Rounded corners
                                    ),
                                    elevation: 20, // Add shadow
                                  ),
                                  child: Text(
                                    "Tourney Zone",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                   // Tournament Banner
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 16,horizontal: 16),
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
                    },
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

class CountdownBottomDialogForGame extends StatefulWidget {
  final int time;
  final String entryPrice;
  final String prizePool;
  final String partnerId;
  final String boardSize;
  CountdownBottomDialogForGame({
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

class _CountdownBottomDialogState extends State<CountdownBottomDialogForGame> with SingleTickerProviderStateMixin {
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