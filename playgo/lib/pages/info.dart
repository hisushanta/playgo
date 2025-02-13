import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import 'package:playgo/pages/home.dart';


class ItemInfo{
  String? uuid;
  FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String,List<List>> itemInfo = {};
  Map<String,List> categories = {};
  Map<String,String> imageUrls = {};
  Map<String,List<List>> orderActiveStatus = {};
  Map<String,List<List>> loveItem = {};
  ValueNotifier<bool> isLoading = ValueNotifier<bool>(true); // To track loading state
  Map<String, Map<String, dynamic>> userProfile = {}; // New map for user profile

  ItemInfo(this.uuid) {
    itemInfo[uuid!] = [];
    orderActiveStatus[uuid!] = [];
    loveItem[uuid!] = [];
    imageUrls = {};
    userProfile[uuid!] = {}; // Initialize user profile
    _initializeData();
    // Initialize the data if have
  }

  Future<void> _initializeData() async {
      await _loadDataFromFirestore();
      _setupListeners();
      isLoading.value = false; // Mark loading as complete
    }

  Future<void> _loadDataFromFirestore() async {
    if (uuid != null) {
      var data = await _firestore.collection('match').doc('collection').get();
      var baseItem = data.data()!['match'];
      List<List> itemStore = [];
      for (var key in baseItem.keys){
        itemStore.add(baseItem[key]);
      }
      itemInfo[uuid!] = itemStore;
    //   // Categories Store
    //   var cdata = await _firestore.collection("Item").doc("lottlo").get();
    //   var baseCategory = cdata.data()!['categories'];
    //   for (var key in baseCategory.keys){
    //     categories[key]= baseCategory[key];
    //   }
    //   // Extract the singleOption list
    //   List<dynamic> singleOptionList = categories['singleOption']!;

    //   // Remove singleOption from the map
    //   categories.remove('singleOption');

    //   // Add singleOption to the end of the map
    //   categories['singleOption'] = singleOptionList;
    // }
    //  // Love order store 
    //  var loveData = await _firestore.collection('users').doc(uuid).collection('love').get();
    //  var baseLoveData = loveData.docs.map((doc){
    //   var ddata = doc.data();
    //   return ddata;
    //  }).toList();
    //  if (baseLoveData.isNotEmpty){
    //   List<List> ddlove = [];
    //   for (var i in (List.generate( baseLoveData.length, (i) => i))){
    //     for (var key in baseLoveData[i].keys){
    //       ddlove.add(baseLoveData[i][key]);
    //     }
    //   }
    //   loveItem[uuid!] = ddlove;
    //  }

    // // Active order get
    // var orderActive = await _firestore.collection('users').doc(uuid).collection('order').get();
    // var subOrder = orderActive.docs.map((doc) {
    //   var data = doc.data();
    //   return data;
    // }).toList();
    // if(subOrder.isNotEmpty){
    //       List<List> damOrder = [];
    //       for (var i in (List.generate(subOrder.length, (i) => i))){
    //         for (var key in subOrder[i].keys){
    //         damOrder.add(subOrder[i][key]);
    //         }
            
    //       }
    //       orderActiveStatus[uuid!] = damOrder;
        }
    
    // Load user profile
    var userProfileData = await _firestore.collection('users').doc(uuid).get();
    debugPrint("UserProfile: $userProfileData");
    if (userProfileData.exists) {
      try{
        userProfile[uuid!] = {
          'username': userProfileData['username'],
          'profileImage': userProfileData['profileImage'],
          'email': userProfileData['email'],
          'number': userProfileData['number'],
          'fund': userProfileData['fund'],
          'deposit': userProfileData['deposit'],
          'winning': userProfileData['winning'],
          'status': userProfileData['status'],
          'currentEntryPrice':userProfileData['currentEntryPrice'],
        };
      } catch(e){
        updateUserProfile("Unknown", "assets/mainIcon.png", '','','','');
      }
    }else{
      updateUserProfile("Unknown", "assets/mainIcon.png", '','','','');
    }
  
  // Get all images
  imageUrls = await getAllImageUrls();
  }
  List<List> getItem(){
    return List.from(itemInfo[uuid]!);
  }
  Future<Map<String,String>> getAllImageUrls() async {
    Map<String,String> localImageUrls = {};
    
    try {
      // Reference to the folder in Firebase Storage
      final ref = FirebaseStorage.instance.ref().child('assets'); // Replace 'your_folder' with your folder path
      final ListResult result = await ref.listAll();
      
      for (final Reference fileRef in result.items) {
        String downloadUrl = await fileRef.getDownloadURL();
        localImageUrls[fileRef.fullPath] = downloadUrl;
      }
    } catch (e) {
      print('Error retrieving image URLs: $e');
    }
    
    return localImageUrls;
  }


  String getDetails(String checkToGet){
    if (checkToGet == 'username'){
      return userProfile[uuid]!['username'];
    } else if( checkToGet == 'number'){
      return userProfile[uuid]!['number'];
    } 
    else {
      return userProfile[uuid]!['email'];
    }
  }
  
  Future<String> getUserName(String uuid) async{
    var userData = await _firestore.collection('users').doc(uuid).get();
    return userData["username"]!;
  }
  
  Future<void> addFund(String amount)async{
    String fund = (double.parse(userProfile[userId]!['fund']) + double.parse(amount)).toString();
    String deposit = (double.parse(userProfile[userId]!['deposit']) + double.parse(amount)).toString();
    var userRef = _firestore.collection('users').doc(uuid);
      await userRef.set({
        'fund':fund,
        'deposit':deposit
      },SetOptions(merge: true));
  }

 bool checkHaveNumberOrAddress(){
  
  if (userProfile[uuid]!["number"].isNotEmpty){
    return true;
  } 
  return false;
 }
  void _setupListeners() {
    if (uuid != null) {
      _firestore.collection('match').doc('collection').snapshots().listen((snapshot){
        var item = snapshot.data()!['match'];
        List<List> itemStore = [];
        for (var key in item.keys){
          itemStore.add(item[key]);
        }
        itemInfo[uuid!] = itemStore;


      });
          // New listener for user profile changes
        _firestore.collection('users').doc(uuid).snapshots().listen((snapshot) {
          if (snapshot.exists) {
            userProfile[uuid!] = {
              'username': snapshot['username'],
              'profileImage': snapshot['profileImage'],
              'email': snapshot['email'],
              'number': snapshot['number'],
              'fund': snapshot['fund'],
              'deposit': snapshot['deposit'],
              'winning': snapshot['winning'],
              'status': snapshot['status'],
              'currentEntryPrice': snapshot['currentEntryPrice'],
            };
          }
        });
    //   // Listen to alert changes
    //   _firestore.collection('users').doc(uuid).collection('order').snapshots().listen((snapshot) {
    //     var item = snapshot.docs.map((doc) {
    //       var data = doc.data();
    //       return data;
    //     }).toList();
    //     if(item.isNotEmpty){
    //       List<List> damOrder = [];
    //       for (var i in (List.generate(item.length, (i) => i))){
    //         for (var key in item[i].keys){
    //         damOrder.add(item[i][key]);
    //         }
    //       }
    //       orderActiveStatus[uuid!] = damOrder;
    //     }
    //   });
    }
    //   // love to load
    //   _firestore.collection('users').doc(uuid).collection('love').snapshots().listen((snapshot){
    //       var baseLoveData = snapshot.docs.map((doc){
    //       var ddata = doc.data();
    //       return ddata;
    //     }).toList();
    //     if (baseLoveData.isNotEmpty){
    //       List<List> ddlove = [];
    //       for (var i in (List.generate( baseLoveData.length, (i) => i))){
    //         for (var key in baseLoveData[i].keys){
    //           ddlove.add(baseLoveData[i][key]);
    //         }
    //       }
    //       loveItem[uuid!] = ddlove;
    //     } else{
    //       loveItem[uuid!] = [];
    //     }
    //   });
     
      
    // }
  }
  bool itemCheck(List<String>listOfItem,String itemName){
    if (listOfItem.contains(itemName)) {
        return true;
      } else {
        return false;
      }
  }
  Future<void> updateUserProfile(String username, String profileImage,String email, String number,String fund,[String deposit = '0.0',String winning = '0.0',String gameStatus = "DeActive",String currentEntryPrice="0.0"]) async {
    if (uuid != null) {
      var userRef = _firestore.collection('users').doc(uuid);
      await userRef.set({
        'username': username,
        'profileImage': profileImage,
        'email': email,
        'number': number,
        'fund':fund,
        'deposit':deposit,
        'winning':winning,
        'status':gameStatus,
        'currentEntryPrice':currentEntryPrice
      }, SetOptions(merge: true));
      // Update local data
      userProfile[uuid!] = {
        'username': username,
        'profileImage': profileImage,
        'email': email,
        'number':number,
        'fund': fund,
        'deposit': deposit,
        'winning':winning,
        'status':gameStatus,
        'currentEntryPrice':currentEntryPrice
      };
    }
  }

 // First, let's modify the findGamePartner function in your info file to check entry prices:
Future<Map<String, dynamic>> findGamePartner(String userId, String entryPrice) async {
  QuerySnapshot querySnapshot = await _firestore.collection('users').get();
  var allUserProfile = querySnapshot.docs.map((doc) => {doc.id: doc.data() as Map}).toList();

  if (allUserProfile.isNotEmpty) {
    for (var data in allUserProfile) {
      for (var id in data.keys) {
        if ((id != userId) && 
            (data[id]!['status'] == 'Active') && 
            (data[id]!['currentEntryPrice'] == entryPrice)) {  // Check matching entry price
          List users = [userId, id];
          users.sort();
          String matchId = users.join('+');

          DocumentSnapshot matchSnapshot = await _firestore.collection('games').doc(matchId).get();
          if (!matchSnapshot.exists) {
            return {id: data[id]!};
          }
        }
      }
    }
  }
  return {};
}
 Future<void> deleteMatch(String matchId) async {
  await _firestore.collection('games').doc(matchId).delete();
}
  // Add these methods to your existing Firebase service class

Future<void> updateMatchStatus(String gameId, String playerId, bool isReady) async {
  final docRef = _firestore.collection('games').doc(gameId);
  
  await docRef.update({
    '${playerId}Ready': isReady,
  });
}

Future<Map<String, dynamic>> getMatchStatus(String gameId) async {
  final docSnapshot = await _firestore.collection('games').doc(gameId).get();
  return docSnapshot.data() as Map<String, dynamic>;
}

// Update your existing createMatch method to include ready status fields
Future<Map<String, dynamic>> createMatch(String userId, String partnerId, String userIdName) async {
  List<String> users = [userId, partnerId];
  users.sort();
  String matchId = users.join('+');
  String partnerIdName = await getUserName(partnerId);

  return await _firestore.runTransaction((transaction) async {
    DocumentSnapshot matchSnapshot = await transaction.get(
      _firestore.collection('games').doc(matchId)
    );

    if (matchSnapshot.exists) {
      Map<String, dynamic> matchData = matchSnapshot.data() as Map<String, dynamic>;
      matchData["gameId"] = matchId;
      return matchData;
    } else {
      Map<String, dynamic> matchData = {
        'gameId': matchId,
        "player1Id": userId,
        "player2Id": partnerId,
        userId: userIdName,
        partnerId: partnerIdName,
        "player1Stone": "black",
        "player2Stone": "white",
        "activePlayers": [userId, partnerId],
        'currentTurn': "black",
        "createdAt": DateTime.now().toIso8601String(),
        // Add ready status fields
        "${userId}Ready": false,
        "${partnerId}Ready": false,
      };

      transaction.set(_firestore.collection('games').doc(matchId), matchData);
      return matchData;
    }
  });
}

Future<void> updateUserWinning(String userId, double amount) async {
    try {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(userId);
      
      // Use a transaction to ensure atomic updates
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userDoc);
        
        if (!userSnapshot.exists) {
          throw Exception('User not found');
        }

        // Get current fund amount
        double currentFund = double.parse(userSnapshot.data()?['winning']);
        
        // Calculate new fund amount
        double winning;
        winning = currentFund + amount;
        

        // Update the fund
        transaction.update(userDoc, {
          'winning': winning.toString(),
        });
        
      });


    } catch (e) {
      rethrow; // Rethrow to handle in the calling function
    }
  }


 // Update the updateGameStatus function to include entry price:
Future updateGameStatus(String status, String uuid, String entryPrice) async {
  var userRef = _firestore.collection('users').doc(uuid);
  await userRef.set({
    'status': status,
    'currentEntryPrice': entryPrice,  // Add entry price
  },SetOptions(merge: true));
}
Future<void> updateUserFund(String userId, double amount, [String category = "add"]) async {
    try {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(userId);
      
      // Use a transaction to ensure atomic updates
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userDoc);
        
        if (!userSnapshot.exists) {
          throw Exception('User not found');
        }

        // Get current fund amount
        double currentFund = double.parse(userSnapshot.data()?['fund']);
        
        // Calculate new fund amount
        double newFund;
        if (category == 'add'){
          newFund = currentFund + amount;
        } else {
          newFund = currentFund - amount;
        }
        // Ensure fund doesn't go below 0
        if (newFund < 0) {
          throw Exception('Insufficient funds');
        }

        // Update the fund
        transaction.update(userDoc, {
          'fund': newFund.toString(),
        });
        
      });


    } catch (e) {
      rethrow; // Rethrow to handle in the calling function
    }
  }


  // Method to remove an order from Firestore
Future<void> removeOrderFromFirestore(String orderId,int index) async {
  if (uuid != null) {
    //first locally delete:
    orderActiveStatus[uuid]!.removeAt(index);
    // Access the Firestore collection for the user's orders
    var docRef = _firestore
        .collection('users')
        .doc(uuid)
        .collection('order')
        .doc(orderId);

    // Delete the order document
    await docRef.delete();
  }
}

Future<void> removeLoveFromFirestore(String loveId) async{
  if (uuid != null){
    var docRef = _firestore
        .collection('users')
        .doc(uuid)
        .collection('love')
        .doc(loveId);
    
    //Delete the love document
    await docRef.delete();
  }
}


  Future<void> _saveOrderToFirestore(Map<String,List> order,String index) async {
    if (uuid != null) {
      var docRef = _firestore
          .collection('users')
          .doc(uuid)
          .collection('order')
          .doc(index);

      await docRef.set(order);
    }
  }

  Future<void> _saveLoveToFirestore(Map<String,List> item , String index) async{
    if (uuid != null){
      var docRef = _firestore
          .collection('users')
          .doc(uuid)
          .collection('love')
          .doc(index);
      
      await docRef.set(item);
    }
  }
  
  bool checkLoveHave(String pindex){
    for (var item in loveItem[uuid!]!){
      if (item[3] == pindex){
        return true;
      }
    }
    return false;
  }

  void addLove(String image,String itemName, String price,String pindex,List iSize,String iTitle,String idesc){

    _saveLoveToFirestore({"$pindex":[image,itemName,price,pindex,iTitle,idesc,{"isize":iSize}]},pindex.toString());

  }

  void addOrder(String itemName,String image, String price,String pindex, String userName,  String number,
                String status, String size ,String date, String expactedDate,
                String outForOrderDate, String DeliveredDate, String quantity,String totalPrice,String deliveryAddress, String email,
                String time){
      int aindex = 0;
      if (orderActiveStatus[uuid]!.isNotEmpty){
        for (var item in orderActiveStatus[uuid]!){
          if (int.parse(item[8])>aindex){
            aindex  = int.parse(item[8]); 
          }
        } 
        aindex += 1;
      }

      _saveOrderToFirestore({"$aindex":[itemName,image,price,pindex,userName,number,size,status,aindex.toString(),date,expactedDate,
                            outForOrderDate,DeliveredDate,quantity,totalPrice,deliveryAddress,email,time]}, aindex.toString());
  }

   // Search for user by ID
  Future<Map<String, dynamic>?> searchUserById(String searchId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(searchId).get();
      if (userDoc.exists) {
        return {
          'id': userDoc.id,
          'username': userDoc.data()?['username'],
          'status': userDoc.data()?['status']
        };
      }
      return null;
    } catch (e) {
      print('Error searching user: $e');
      return null;
    }
  }

  // Send match request
  Future<bool> sendMatchRequest(String senderId, String receiverId) async {
    try {
      await _firestore.collection('matchRequests').add({
        'senderId': senderId,
        'receiverId': receiverId,
        'receiverConfirmed':false,
        "senderConfirmed":false,
        'showConfirmation':false,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error sending match request: $e');
      return false;
    }
  }

  // Get match requests for a user
  Stream<QuerySnapshot> getMatchRequests(String userId) {
    return _firestore
        .collection('matchRequests')
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  // Accept match request
  Future<void> acceptMatchRequest(String requestId, String senderId, String receiverId) async {
    try {
      // Update request status
      await _firestore.collection('matchRequests').doc(requestId).update({
        'status': 'accepted',
      });

      // Create match session
      await _firestore.collection('matches').add({
        'players': [senderId, receiverId],
        'status': 'starting',
        'timestamp': FieldValue.serverTimestamp(),
        'countdownStarted': false,
      });
    } catch (e) {
      print('Error accepting match request: $e');
      rethrow;
    }
  }

}