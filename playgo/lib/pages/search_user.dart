import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:playgo/pages/match_play.dart';
import 'package:shimmer/shimmer.dart';
import 'package:playgo/main.dart';
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
  String _selectedBoardSize = '9x9';
  StreamSubscription<QuerySnapshot>? _confirmationListener;
  StreamSubscription<QuerySnapshot>? _countdownListener;
  bool _isDialogShowing = false;
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _entryPriceController = TextEditingController();
  FocusNode _durationFocusNode = FocusNode();
  FocusNode _entryPriceFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _listenForConfirmation();
    _listenForCountdown();
    _durationFocusNode.addListener(_onDurationFocusChange);
    _entryPriceFocusNode.addListener(_onEntryPriceFocusChange);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    _confirmationListener?.cancel();
    _countdownListener?.cancel();
    _searchFocusNode.dispose();
    _durationController.dispose();
    _entryPriceController.dispose();
    _durationFocusNode.dispose();
    _entryPriceFocusNode.dispose();
    super.dispose();
  }

  void _onDurationFocusChange() {
    if (!_durationFocusNode.hasFocus) {
      _updateDuration();
    }
  }

  void _onEntryPriceFocusChange() {
    if (!_entryPriceFocusNode.hasFocus) {
      _updateEntryPrice();
    }
  }

  void _updateDuration() {
    if (_foundUser != null) {
      setState(() {
        _foundUser!['totalGameTime'] = _durationController.text;
      });
    }
  }

  void _updateEntryPrice() {
    if (_foundUser != null) {
      setState(() {
        _foundUser!['entryPrice'] = _entryPriceController.text;
      });
    }
  }

  void _listenForConfirmation() {
    _confirmationListener = FirebaseFirestore.instance
        .collection('matchRequests')
        .where('senderId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        final request = snapshot.docs.first;
        final requestId = request.id;
        final showConfirmation = request['showConfirmation'] ?? false;

        if (showConfirmation && !_isDialogShowing) {
          _isDialogShowing = true;

          final confirmed = await showDialog<bool>(
            context: context,
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

          await FirebaseFirestore.instance
              .collection('matchRequests')
              .doc(requestId)
              .update({'showConfirmation': false});

          _isDialogShowing = false;
          _searchController.clear();
          _searchFocusNode.unfocus();

          if (confirmed == true) {
            await FirebaseFirestore.instance
                .collection('matchRequests')
                .doc(requestId)
                .update({'senderConfirmed': true});
          } else {
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
        .where('senderId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        final request = snapshot.docs.first;
        final requestId = request.id;
        final senderConfirmed = request['senderConfirmed'] ?? false;
        final receiverConfirmed = request['receiverConfirmed'] ?? false;
        final entryPrice = request['entryPrice']?.toString() ?? '0.0';
        final duration = int.tryParse(request['duration']?.toString() ?? '0') ?? 0;
        final prizePool = double.parse(entryPrice) > 0.0
          ? ((double.parse(entryPrice)*2)-(((double.parse(entryPrice) * 2)/100)*2)).toStringAsFixed(2)
          : "0.0";

        if (senderConfirmed && receiverConfirmed && !_isDialogShowing) {
          _isDialogShowing = true;

          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => CountdownBottomDialogForGame(
              time: duration,
              entryPrice: entryPrice,
              prizePool: prizePool,
              partnerId: request['receiverId'],
              boardSize: request['boardSize'] ?? '9x9',
            ),
          );

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
      if (_foundUser != null) {
        _durationController.text = _foundUser!['totalGameTime']?.toString() ?? '12';
        _entryPriceController.text = _foundUser!['entryPrice'] is double 
            ? (_foundUser!['entryPrice'] as double).toStringAsFixed(2)
            : (double.tryParse(_foundUser!['entryPrice']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2);
      }
    });

    if (_foundUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User not found'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  Future<void> _sendMatchRequest(String entryPrice, String duration) async {
    FocusScope.of(context).unfocus();
    if (_foundUser == null) return;
    
    final currentFund = double.tryParse(info!.userProfile[userId]!['fund']?.toString() ?? '0.0') ?? 0.0;
    final requestAmount = double.tryParse(entryPrice) ?? 0.0;
    
    if(requestAmount > currentFund){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient funds'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } else {
      final success = await info!.sendMatchRequest(
        userId,
        _foundUser!['id'],
        duration,
        entryPrice,
        _selectedBoardSize,
      );
      if (success) {
        _searchController.clear();
        _searchFocusNode.unfocus();
        
        setState(() {
          _foundUser = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Match request sent!'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send match request'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
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
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Search player by ID...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    prefixIcon: Icon(Icons.search, color: Colors.blue[700]),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey[500]),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _foundUser = null;
                              });
                            },
                          )
                        : null,
                  ),
                ),
              ),
              SizedBox(height: 24),
              
              // Loading or Results
              if (_isSearching)
                _buildShimmerLoading()
              else if (_foundUser != null)
                _buildUserProfileCard()
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
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[200]!,
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
            SizedBox(height: 16),
            Container(
              width: 200,
              height: 20,
              color: Colors.white,
            ),
            SizedBox(height: 10),
            Container(
              width: 150,
              height: 16,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserProfileCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Profile Header
          Column(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue[100],
                ),
                child: Icon(Icons.person, size: 50, color: Colors.blue[700]),
              ),
              SizedBox(height: 16),
              Text(
                _foundUser!['username'] ?? 'Unknown',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 4),
              Text(
                'ID: ${_foundUser!['id']}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 24),
          
          // Match Settings
          Column(
            children: [
              _buildEditableField(
                label: "Game Duration",
                controller: _durationController,
                focusNode: _durationFocusNode,
                suffixText: "minutes",
                keyboardType: TextInputType.number,
              ),
              
              Divider(height: 24, color: Colors.grey[200]),
              
              _buildEditableField(
                label: "Entry Fee",
                controller: _entryPriceController,
                focusNode: _entryPriceFocusNode,
                prefixText: "₹",
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              
              Divider(height: 24, color: Colors.grey[200]),
              
              _buildBoardSizeSelector(),
            ],
          ),
          
          SizedBox(height: 24),
          
          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _sendMatchRequest(_entryPriceController.text, _durationController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'SEND MATCH REQUEST',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    String? prefixText,
    String? suffixText,
    required TextInputType keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            prefixText: prefixText,
            suffixText: suffixText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildBoardSizeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BOARD SIZE',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildBoardSizeOption('9x9'),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildBoardSizeOption('13x13'),
            ),
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
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: _selectedBoardSize == size ? Colors.blue[700]! : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _selectedBoardSize == size ? Colors.blue[700]! : Colors.grey[300]!,
          ),
        ),
        child: Center(
          child: Text(
            size,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _selectedBoardSize == size ? Colors.white : Colors.grey[800],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.search, size: 60, color: Colors.grey[300]),
          SizedBox(height: 16),
          Text(
            'Find Players',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Search for players by their ID to start a match',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}