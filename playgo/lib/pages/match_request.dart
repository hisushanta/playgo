import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:playgo/pages/match_play.dart';
import 'package:shimmer/shimmer.dart';
import 'package:playgo/main.dart'; // Import your ItemInfo class
import 'home.dart';

class MatchRequestPage extends StatefulWidget {
  @override
  _MatchRequestPageState createState() => _MatchRequestPageState();
}

class _MatchRequestPageState extends State<MatchRequestPage> {
  bool _isDialogShowing = false; // Track if the dialog is currently showing
  StreamSubscription<DocumentSnapshot>? _confirmationListener; // Listener for confirmation
  
  
  @override
  void dispose() {
    // Cancel the listener when the widget is disposed
    _confirmationListener?.cancel();
    super.dispose();
  }

  Future<void> _cancelMatchRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection('matchRequests')
          .doc(requestId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Match request canceled!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel match request.')),
      );
    }
  }

  Future<void> _acceptMatchRequest(String requestId, String senderId) async {
    try {
      // Update Firestore to trigger the confirmation dialog for both users
      await FirebaseFirestore.instance
          .collection('matchRequests')
          .doc(requestId)
          .update({
        'receiverConfirmed': true,
        'showConfirmation': true, // Notify both users to show the dialog
      });
      // CountdownBottomDialog(time: 3,entryPrice: '0',partnerId: userId==requestId?senderId:requestId,prizePool: '0');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept match request.')),
      );
    }
  }

  void _listenForConfirmation(String requestId, bool isSender) {
  // Cancel any existing listener to avoid duplicates
  _confirmationListener?.cancel();

  // Start a new listener
  _confirmationListener = FirebaseFirestore.instance
      .collection('matchRequests')
      .doc(requestId)
      .snapshots()
      .listen((snapshot) async {
    if (snapshot.exists && !_isDialogShowing) {
      // Provide default values if fields are missing
      final showConfirmation = snapshot['showConfirmation'] ?? false;
      final senderConfirmed = snapshot['senderConfirmed'] ?? false;
      final receiverConfirmed = snapshot['receiverConfirmed'] ?? false;

      debugPrint(
          'showConfirmation: $showConfirmation, senderConfirmed: $senderConfirmed, receiverConfirmed: $receiverConfirmed');
      // Check if both users have confirmed
      if (senderConfirmed && receiverConfirmed) {
            debugPrint("Both users confirmed. Showing countdown dialog.");

            // Navigate to the CountdownBottomDialog
            if (mounted) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) => CountdownBottomDialog(
                  time: 3,
                  entryPrice: '0',
                  prizePool: '0',
                  partnerId: userId == snapshot["senderId"]
                      ? snapshot['receiverId']
                      : snapshot['senderId'],
                ),
              );
              _cancelMatchRequest(requestId);

            }
          }
      if (showConfirmation) {
        // Set the flag to indicate that the dialog is showing
        _isDialogShowing = true;

        // Reset the `showConfirmation` field to prevent re-triggering
        await FirebaseFirestore.instance
            .collection('matchRequests')
            .doc(requestId)
            .update({'showConfirmation': false});

        // Show confirmation dialog for both users
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Confirm Match', style: TextStyle(color: Colors.blue)),
              content: Text(isSender
                  ? 'The receiver has accepted your match request. Do you want to proceed?'
                  : 'You have accepted the match request. Waiting for the sender to confirm...'),
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

        // Reset the flag after the dialog is closed
        _isDialogShowing = false;

        if (confirmed == true) {
          
          // Update Firestore based on the user's role
          if (isSender) {
            await FirebaseFirestore.instance
                .collection('matchRequests')
                .doc(requestId)
                .update({'senderConfirmed': true});
          } else {
            await FirebaseFirestore.instance
                .collection('matchRequests')
                .doc(requestId)
                .update({'receiverConfirmed': true});
          }

          
        } else {
          // Cancel the match request if either user declines
          await _cancelMatchRequest(requestId);
        }
      }
    }
  });
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Match Requests', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue, Colors.purple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('matchRequests')
                  .where('status', isEqualTo: 'pending')
                  .where(Filter.or(
                    Filter('senderId', isEqualTo: userId),
                    Filter('receiverId', isEqualTo: userId),
                  ))
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildShimmerLoading();
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final requests = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    final requestId = request.id;
                    final senderId = request['senderId'];
                    final receiverId = request['receiverId'];
                    final status = request['status'];

                    // Determine if the current user is the sender or receiver
                    final isSentRequest = senderId == userId;
                    final otherUserId = isSentRequest ? receiverId : senderId;

                    // Listen for confirmation if the request is active
                    _listenForConfirmation(requestId, isSentRequest);

                    return FutureBuilder<Map<String, dynamic>?>(
                      future: info!.searchUserById(otherUserId),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.connectionState == ConnectionState.waiting) {
                          return _buildShimmerLoading();
                        }

                        if (!userSnapshot.hasData || userSnapshot.data == null) {
                          return ListTile(
                            title: Text('User not found'),
                          );
                        }

                        final otherUser = userSnapshot.data!;
                        final otherUsername = otherUser['username'];

                        return _buildMatchRequestCard(
                          otherUsername,
                          isSentRequest,
                          requestId,
                          senderId,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return SizedBox(
      height: 200, // Set a fixed height
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: ListView.builder(
          itemCount: 5,
          itemBuilder: (context, index) {
            return Card(
              margin: EdgeInsets.all(10),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: Colors.white),
                title: Container(
                  width: 100,
                  height: 16,
                  color: Colors.white,
                ),
                subtitle: Container(
                  width: 50,
                  height: 14,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 60, color: Colors.grey),
          SizedBox(height: 10),
          Text(
            'No match requests found.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchRequestCard(
    String username,
    bool isSentRequest,
    String requestId,
    String senderId,
  ) {
    return Card(
      margin: EdgeInsets.all(10),
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.blue,
              child: Icon(Icons.person, size: 30, color: Colors.white),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 5),
                  Text(
                    isSentRequest ? 'Sent Request' : 'Received Request',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
            isSentRequest
                ? ElevatedButton(
                    onPressed: () => _cancelMatchRequest(requestId),
                    child: Text('Cancel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  )
                : ElevatedButton(
                    onPressed: () => _acceptMatchRequest(requestId, senderId),
                    child: Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}


class CountdownBottomDialog extends StatefulWidget {
  final int time;
  final String entryPrice;
  final String prizePool;
  final String partnerId;
  CountdownBottomDialog({
    super.key, 
    required this.time,
    required this.entryPrice,
    required this.prizePool,
    required this.partnerId,
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
          size: 13,
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
