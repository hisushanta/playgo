import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:playgo/pages/match_play.dart';
import 'package:shimmer/shimmer.dart';
import 'package:playgo/main.dart'; // Import your ItemInfo class
import 'home.dart';
import 'package:google_fonts/google_fonts.dart';

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
      final duration = int.parse(snapshot['duration']);
      final entryPrice = snapshot['entryPrice']??'0.0';
      final boardSize = snapshot['boardSize'];
      final prizePool = double.parse(entryPrice) > 0.0?((double.parse(snapshot['entryPrice'])*2)-(((double.parse(snapshot['entryPrice']) * 2)/100)*2)).toString():"0.0";
      // Check if both users have confirmed
      if (senderConfirmed && receiverConfirmed) {

            // Navigate to the CountdownBottomDialog
            if (mounted) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) => CountdownBottomDialogForGame(
                  time: duration,
                  entryPrice: entryPrice,
                  prizePool: prizePool,
                  partnerId: userId == snapshot["senderId"]
                      ? snapshot['receiverId']
                      : snapshot['senderId'],
                  boardSize: boardSize,
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
      backgroundColor: Colors.white,
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
                    final entryPrice = request['entryPrice'].toString();
                    final gameDuration = request['duration'].toString();
                    final boardSize = request['boardSize'].toString();

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
                          entryPrice,
                          gameDuration,
                          boardSize,
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
  String entryPrice,
  String gameDuration,
  String boardSize,
) {
  return Card(
    margin: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
    elevation: 6,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Profile Avatar and Username
          Row(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: Colors.blue.shade700,
                child: Icon(Icons.person, size: 35, color: Colors.white),
              ),
              SizedBox(width: 10),
              /// Username
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4), // Small spacing between username and role
                    Text(
                      isSentRequest ? "You sent this request" : "You received this request",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 15), // Spacing between Username and Details

          /// Entry Price
          Row(
            children: [
              Icon(Icons.currency_rupee, color: Colors.green, size: 20),
              SizedBox(width: 5),
              Text(
                "Entry Price:",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
              SizedBox(width: 5),
              Text(
                "$entryPrice",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ],
          ),

          SizedBox(height: 10), // Spacing between Entry Price and Game Duration

          /// Game Duration
          Row(
            children: [
              Icon(Icons.timer, color: Colors.blue, size: 20),
              SizedBox(width: 5),
              Text(
                "Game Duration:",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
              SizedBox(width: 5),
              Text(
                "$gameDuration mins",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueAccent,
                ),
              ),
            ],
          ),

          SizedBox(height: 10), // Spacing between Game Duration and Board Size

          /// Board Size
          Row(
            children: [
              Icon(Icons.grid_on, color: Colors.orange, size: 20),
              SizedBox(width: 5),
              Text(
                "Board Size:",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
              SizedBox(width: 5),
              Text(
                "$boardSize",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                ),
              ),
            ],
          ),

          SizedBox(height: 20), // Spacing between Details and Buttons

          /// Action Buttons (Accept/Cancel) - Centered
          Row(
            mainAxisAlignment: MainAxisAlignment.center, // Center the buttons
            children: [
              if (!isSentRequest)
                ElevatedButton(
                  onPressed: () => _acceptMatchRequest(requestId, senderId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: Text(
                    "Accept",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              SizedBox(width: 10), // Spacing between buttons
              ElevatedButton(
                onPressed: () => _cancelMatchRequest(requestId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: Text(
                  "Cancel",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

}


