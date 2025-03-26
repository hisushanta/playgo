import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:playgo/pages/match_play.dart';
import 'package:shimmer/shimmer.dart';
import 'package:playgo/main.dart'; // Import your ItemInfo class
import 'home.dart';

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _foundUser;
  bool _isSearching = false;
  Timer? _debounce;
  String _selectedBoardSize = '9x9'; // Default board size
  StreamSubscription<QuerySnapshot>? _confirmationListener;
  StreamSubscription<QuerySnapshot>? _countdownListener;
  bool _isDialogShowing = false;
  final FocusNode _searchFocusNode = FocusNode();  // Add this line


  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _listenForConfirmation(); // Listen for confirmation
    _listenForCountdown(); // Listen for countdown


  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    _confirmationListener?.cancel();
    _countdownListener?.cancel();
    _searchFocusNode.dispose();
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



  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchUser();
    });
  }

  Future<void> _searchUser() async {
    final searchId = _searchController.text.trim();
    if (searchId.isEmpty) {
      setState(() {
        _isSearching = false;
        _foundUser = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _foundUser = null;
    });

    final userProfile = await info!.searchUserById(searchId);
    setState(() {
      _isSearching = false;
      _foundUser = userProfile;
    });

    if (_foundUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User not found')),
      );
    }
  }

  Future<void> _sendMatchRequest(String entryPrice, String duration) async {
    if (_foundUser == null) return;
    if(double.parse(entryPrice) > double.parse(info!.userProfile[userId]!['fund'])){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Your fund is low.')),
      );
    } else{


      final success = await info!.sendMatchRequest(
        userId,
        _foundUser!['id'],
        duration,
        entryPrice,
        _selectedBoardSize, // Pass the selected board size
      );
      if (success) {
        // Clear the search box and remove focus
        _searchController.clear();
        _searchFocusNode.unfocus();
        
        setState(() {
          _foundUser = null;  // Clear the found user
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Match request sent!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send match request.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              title: Row(
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
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom, // Adjust for keyboard
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Search Bar
              AnimatedContainer(
                duration: Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: Colors.grey[200],
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,  // Add this
                  decoration: InputDecoration(
                    hintText: 'Enter User ID',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.search, color: Colors.blue),
                      onPressed: _searchUser,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              // Loading or Results
              if (_isSearching)
                _buildShimmerLoading()
              else if (_foundUser != null)
                Expanded(child: _buildUserProfileCard()) // Use Expanded to avoid overflow
              else
                _buildEmptyState(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 20),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 10),
            Container(
              width: 200,
              height: 20,
              color: Colors.white,
            ),
            SizedBox(height: 10),
            Container(
              width: 150,
              height: 20,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserProfileCard() {
    // Set default values if not provided
    final totalGameTime = _foundUser!['totalGameTime'] ?? '12';
    final entryPrice = _foundUser!['entryPrice']?.toStringAsFixed(2) ?? '0.00';

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue, Colors.purple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: Colors.blue),
              ),
              SizedBox(height: 10),
              Text(
                'User ID: ${_foundUser!['id']}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              SizedBox(height: 5),
              Text(
                'Username: ${_foundUser!['username']}',
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              SizedBox(height: 20),
              // Editable Total Game Time
              _buildEditableFieldForMinutes(
                label: 'Total Game Time',
                value: totalGameTime,
                onChanged: (value) {
                  setState(() {
                    _foundUser!['totalGameTime'] = value;
                  });
                },
                icon: Icons.timer,
              ),
              SizedBox(height: 20),
              // Editable Entry Price
              _buildEditableField(
                label: 'Entry Price',
                value: entryPrice,
                onChanged: (value) {
                  setState(() {
                    _foundUser!['entryPrice'] = double.tryParse(value) ?? 0.0;
                  });
                },
                icon: Icons.attach_money,
              ),
              SizedBox(height: 20),
              // Board Size Selection
              _buildBoardSizeSelector(),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  _sendMatchRequest(entryPrice.toString(), totalGameTime.toString());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                child: Text('Request to Play Match'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to create an editable field with an icon
  Widget _buildEditableField({
    required String label,
    required String value,
    required Function(String) onChanged,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.white70),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
        SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextFormField(
            initialValue: value,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // Helper method to create an editable field with an icon
  Widget _buildEditableFieldForMinutes({
    required String label,
    required String value,
    required Function(String) onChanged,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.white70),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
        SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextFormField(
            initialValue: value,
            keyboardType: TextInputType.number,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // Helper method to create a board size selector
  Widget _buildBoardSizeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Board Size',
          style: TextStyle(fontSize: 14, color: Colors.white70),
        ),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildBoardSizeOption('9x9'),
            _buildBoardSizeOption('13x13'),
          ],
        ),
      ],
    );
  }

  Widget _buildBoardSizeOption(String size) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedBoardSize = size;
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: _selectedBoardSize == size ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _selectedBoardSize == size ? Colors.blue : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          size,
          style: TextStyle(
            fontSize: 16,
            color: _selectedBoardSize == size ? Colors.blue : Colors.white70,
            fontWeight: _selectedBoardSize == size ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 60, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              'No user found. Try searching again!',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

