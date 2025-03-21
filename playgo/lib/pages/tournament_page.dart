import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:playgo/main.dart';
import 'package:playgo/pages/about_pages.dart';
import 'package:playgo/pages/wallet_pages.dart';
import 'fund_page.dart';
import 'home.dart';
import 'match_play.dart';
class TournamentPage extends StatefulWidget {
  @override
  GameTournamentPage createState() => GameTournamentPage();
}

class GameTournamentPage extends State<TournamentPage> {
  Color allColor = Color.fromARGB(255, 247, 255, 16); // Default selected
  Color regularColor = Color.fromARGB(255, 241, 239, 239);
  bool isallCheck = true; // Default is "All"
  bool isregularCheck = false;

  List<Map<String, String>> tournaments = [];
  List<Map<String, String>> filteredTournaments = [];
  String? selectedSortOption; // Holds the currently selected sort option
  String fundBalance = '0.0';
  Timer? _refreshTimer;
  StreamSubscription<QuerySnapshot>? _confirmationListener;
  StreamSubscription<QuerySnapshot>? _countdownListener;
  bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Set up periodic refresh
    _refreshTimer = Timer.periodic(Duration(seconds: 5), (_) => _loadData());
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
            builder: (context) => CountdownBottomDialogForGame(
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
      fundBalance = info!.userProfile[userId]!['fund'];
      tournaments = (info!.itemInfo[userId]! as List<dynamic>).map((tournament) {
        return {
          "entryPrice": tournament[0].toString(),
          "prizePools": tournament[1].toString(),
          "category": tournament[2].toString(),
          "time": tournament[3].toString(),
        };
      }).toList();
      filteredTournaments = List.from(tournaments);
      
      // Reapply current filter
      if (isregularCheck) {
        filteredTournaments = tournaments
            .where((tournament) => tournament["category"] == "Regular")
            .toList();
      }
      
      // Reapply current sort
      if (selectedSortOption == "low_to_high") {
        filteredTournaments.sort((a, b) =>
            int.parse(a["entryPrice"]!).compareTo(int.parse(b["entryPrice"]!)));
      } else if (selectedSortOption == "high_to_low") {
        filteredTournaments.sort((a, b) =>
            int.parse(b["entryPrice"]!).compareTo(int.parse(a["entryPrice"]!)));
      }
    });
  }

  void updateFund(){
    _loadData();
  }

  void applyFilter(String filter) {
    setState(() {
      if (filter == "all") {
        filteredTournaments = List.from(tournaments);
        allColor = Color.fromARGB(255, 247, 255, 16);
        regularColor = Color.fromARGB(255, 241, 239, 239);
        isallCheck = true;
        isregularCheck = false;
      } else if (filter == "regular") {
        filteredTournaments = tournaments
            .where((tournament) => tournament["category"] == "Regular")
            .toList();
        allColor = Color.fromARGB(255, 241, 239, 239);
        regularColor = Color.fromARGB(255, 247, 255, 16);
        isallCheck = false;
        isregularCheck = true;
      }
    });
  }

  void resetSorting() {
    setState(() {
      selectedSortOption = null; // Reset sort option to default
      if (isallCheck) {
        filteredTournaments = List.from(tournaments);
      } else if (isregularCheck) {
        filteredTournaments = tournaments
            .where((tournament) => tournament["category"] == "Regular")
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 240, 246, 247),
      appBar: AppBar(
        backgroundColor: Colors.white,
        actions: [
          Padding ( 
              padding: EdgeInsets.all(8.0),
              child: Row(
              children: [
                 // Add Cash Button
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => WalletPage()),
              );
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
                MaterialPageRoute(builder: (context) => UserProfilePage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.orange,
              side: BorderSide(color: Colors.orangeAccent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Icon(Icons.settings,color: Colors.orange,),
          ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filters Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  DropdownButton<String>(
                    hint: Text(selectedSortOption == null
                        ? "Sort by Price"
                        : selectedSortOption == "low_to_high"
                            ? "Price: Low to High"
                            : selectedSortOption == "high_to_low"
                                ? "Price: High to Low"
                                : "Sort by Price"), // Display based on current option
                    value: selectedSortOption,
                    items: [
                      DropdownMenuItem(
                        value: "low_to_high",
                        child: Text("Price: Low to High"),
                      ),
                      DropdownMenuItem(
                        value: "high_to_low",
                        child: Text("Price: High to Low"),
                      ),
                      DropdownMenuItem(
                        value: "reset",
                        child: Text("Reset"),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedSortOption = value;
                          if (value == "low_to_high") {
                            filteredTournaments.sort((a, b) =>
                                int.parse(a["entryPrice"]!)
                                    .compareTo(int.parse(b["entryPrice"]!)));
                          } else if (value == "high_to_low") {
                            filteredTournaments.sort((a, b) =>
                                int.parse(b["entryPrice"]!)
                                    .compareTo(int.parse(a["entryPrice"]!)));
                          } else if (value == "reset") {
                            resetSorting();
                          }
                        });
                      }
                    },
                  ),
                  Row(
                    children: [
                      FilterChip(
                        label: Text('All'),
                        backgroundColor: allColor,
                        onSelected: (val) => applyFilter("all"),
                      ),
                      SizedBox(width: 8),
                      FilterChip(
                        label: Text('Regular'),
                        backgroundColor: regularColor,
                        onSelected: (val) => applyFilter("regular"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Recommended Tournaments',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListView.builder(
              physics: NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: filteredTournaments.length,
              itemBuilder: (context, index) {
                final tournament = filteredTournaments[index];
                return buildTournamentTile(
                  tournament["entryPrice"]!,
                  tournament["prizePools"]!,
                  tournament["category"]!,
                  tournament['time']!,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

 Widget buildTournamentTile(String entryPrice, String prizePools, String category, String time) {
  return Padding(
    padding: const EdgeInsets.all(8.0),
    child: Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Card(
              color: const Color.fromARGB(255, 199, 237, 236),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    category,
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.timer, size: 16, color: Colors.amber),
                  SizedBox(width: 8),
                  Text(
                    '$time min', // Display the duration here
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Prize Pool', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Row(
                      children: [
                        Text(
                          prizePools,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Icon(Icons.arrow_drop_down, color: Colors.black),
                      ],
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text('ENTRY',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic)),
                    ElevatedButton(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                          ),
                          builder: (context) {
                            return Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Handle for aesthetic purposes
                                    Container(
                                      width: 50,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    SizedBox(height: 20),
                                    // Currency Icon
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundColor: Colors.purple.withOpacity(0.1),
                                      child: Icon(
                                        Icons.currency_rupee,
                                        color: Colors.purple,
                                        size: 32,
                                      ),
                                    ),
                                    SizedBox(height: 15),
                                    // Title
                                    Text(
                                      "Confirm Payment",
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 10),
                                    // Game Info
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.timer, size: 20, color: Colors.amber),
                                        SizedBox(width: 5),
                                        Text(
                                          "$time min Go",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 20),
                                    // Entry Fee
                                    Container(
                                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Entry Fee",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black54,
                                            ),
                                          ),
                                          Text(
                                            "₹$entryPrice",
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 30),
                                    // Join Now Button
                                    ElevatedButton(
                                      onPressed: () {
                                        if (double.parse(fundBalance) >= double.parse(entryPrice)) {
                                          Navigator.pop(context);
                                          info!.updateGameStatus("Active", userId, entryPrice);
                                          showModalBottomSheet(
                                            context: context,
                                            isDismissible: false,
                                            enableDrag: false,
                                            isScrollControlled: true,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                                            ),
                                            builder: (context) {
                                              return PopScope(
                                                canPop: false,
                                                child: CountdownBottomDialog(
                                                  time: int.parse(time),
                                                  entryPrice: entryPrice,
                                                  prizePool: prizePools,
                                                  updateFund: updateFund,
                                                ),
                                              );
                                            },
                                          );
                                        } else {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Insufficient Balance, Please Add Money And Then Play Game💵',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontStyle: FontStyle.italic
                                                )
                                              ),
                                              duration: Duration(seconds: 3),
                                              backgroundColor: Colors.redAccent,
                                            ),
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 50),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                        backgroundColor: Colors.yellow,
                                        foregroundColor: Colors.black,
                                      ),
                                      child: Text(
                                        "Join Now",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 20),
                                  ],
                                ),
                              );
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        entryPrice,
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
          ],
        ),
      ),
    ),
  );
}
}

class CountdownBottomDialog extends StatefulWidget {
  final int time;
  final String entryPrice;
  final String prizePool;
  Function updateFund;
  CountdownBottomDialog({
    super.key, 
    required this.time,
    required this.entryPrice,
    required this.prizePool,
    required this.updateFund,
  });
  
  @override
  _CountdownBottomDialogState createState() => _CountdownBottomDialogState();
}

class _CountdownBottomDialogState extends State<CountdownBottomDialog> with SingleTickerProviderStateMixin {
  late int _currentTime;
  late Timer _timer;
  bool _isSearching = true;
  int _matchCountdown = 3;
  bool _partnerFound = false;
  Map<String, dynamic>? _partner;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _currentTime = 30;
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
    _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      if (!_isSearching) return;

      if (_currentTime > 0) {
        setState(() {
          _currentTime--;
        });

        // Check for game partner
        var partnerdata = await info!.findGamePartner(userId, widget.entryPrice);
        if (partnerdata.isNotEmpty) {
          final partnerId = partnerdata.keys.single;
          _timer.cancel();
          setState(() {
            _partnerFound = true;
            _partner = partnerdata;
          });
          _animationController.forward();
          info!.updateGameStatus("Matched", userId,widget.entryPrice);
          _startMatchCountdown(partnerId);
        }
      } else {
        _timer.cancel();
        _handleTimeout();
      }
    });
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


  void _handleTimeout() {
    setState(() {
      _isSearching = false;
    });
    info!.updateGameStatus("DeActive", userId,"0.0");
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No partner found. Please try again later.')),
    );
  }

  void _navigateToMatchBoard(Map<String, dynamic> partner) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GoBoardMatch(
          size: 13,
          gameId: partner['gameId'],
          playerId: userId,
          totalGameTime: widget.time,
          entryPrice: widget.entryPrice,
          prizePool: widget.prizePool,
        ),
      ),
    ).then((_) {
      widget.updateFund();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_partnerFound) {
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

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: () {
                  _timer.cancel();
                  info!.updateGameStatus("DeActive", userId,"0.0");
                  Navigator.pop(context);
                },
                child: Icon(Icons.cancel_outlined, color: Colors.white),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.search,
                  size: 40,
                  color: Colors.blue,
                ),
                SizedBox(height: 15),
                Text(
                  "Searching for a partner...",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(height: 15),
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.blue,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      "$_currentTime",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          Text(
            "Please wait while we find a game partner.",
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }
}
