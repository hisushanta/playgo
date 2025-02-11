import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:playgo/main.dart';
import 'package:playgo/pages/fund_page.dart';
import 'package:playgo/pages/home.dart';
import 'package:playgo/pages/wallet_pages.dart';
import 'contact.dart';
import 'reset_password.dart';
import 'faq_page.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({Key? key}) : super(key: key);

  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  String? _profileImagePath;
  bool _isEditing = false;
  late TextEditingController _usernameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;

  String _fundBalance = '0'; // Fund balance variable

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();

    _initializeProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();

    super.dispose();
  }

  void _initializeProfile() {
    if (info != null && info!.userProfile[info!.uuid] != null) {
      if (info!.isLoading.value == false) {
        _profileImagePath = info!.userProfile[info!.uuid]!['profileImage'];
        File imageFile = File(_profileImagePath!);
        if (!imageFile.existsSync()) {
          _profileImagePath = "assets/homeIcon.png";
        }
        _usernameController.text = info!.userProfile[info!.uuid]!['username'] ?? '';
        _phoneController.text = info!.userProfile[info!.uuid]!['number'] ?? '';
        _emailController.text = info!.userProfile[info!.uuid]!['email'] ?? '';
        _fundBalance = info!.userProfile[info!.uuid]!['fund'] ?? '0';


        setState(() {});
      } else {
        info!.isLoading.addListener(() {
          if (info!.isLoading.value == false) {
            _profileImagePath = info!.userProfile[info!.uuid]!['profileImage'];
            File imageFile = File(_profileImagePath!);
            if (!imageFile.existsSync()) {
              _profileImagePath = "assets/homeIcon.png";
            }
            _usernameController.text = info!.userProfile[info!.uuid]!['username'] ?? '';
            _phoneController.text = info!.userProfile[info!.uuid]!['number'] ?? '';
            _emailController.text = info!.userProfile[info!.uuid]!['email'] ?? '';

            setState(() {});
          }
        });
      }
    } else {
      debugPrint('Info or user profile is null.');
    }
  }

  Future<void> _pickImage() async {
    try {
      final PermissionStatus status = await Permission.manageExternalStorage.request();
      if (status.isGranted) {
        final ImagePicker _picker = ImagePicker();
        final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);

        if (pickedFile != null) {
          setState(() {
            _profileImagePath = pickedFile.path;
            info!.updateUserProfile(
              _usernameController.text,
              _profileImagePath!,
              _emailController.text,
              _phoneController.text,
              info!.userProfile[info!.uuid]!['fund'],
            );
            imageCache.clear();
          });
        }
      } else if (status.isDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Storage permission is required to pick an image.'), duration: Duration(seconds: 1)),
        );
      } else if (status.isPermanentlyDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Storage permission is permanently denied. Please enable it in settings.') ,duration: Duration(seconds: 1)),
        );
        openAppSettings();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred while picking the image.'), duration: Duration(seconds: 1)),
      );
      debugPrint('Error in _pickImage: $e');
    }
  }
  void _showProfileImageDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                (_profileImagePath != null)
                ? _profileImagePath!.contains('assets') 
                ? Image.asset(_profileImagePath!)
                : Image.file(
                    File(_profileImagePath!),
                    fit: BoxFit.cover,
                  )
                  :Image.asset("assets/homeIcon.png")

                  ,
                const SizedBox(height: 8),
               ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child:  const Text('Close',style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold,color: Colors.black),),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  void _saveProfile() {
    if (_usernameController.text.isEmpty || _profileImagePath == null ) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('All fields are required.'), duration: Duration(seconds: 1)),
      );
      return;
    }

    try {
      info!.updateUserProfile(
        _usernameController.text,
        _profileImagePath!,
        _emailController.text,
        _phoneController.text,
        info!.userProfile[info!.uuid]!['fund']
      );

      setState(() {
        _isEditing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated successfully.'), duration: Duration(seconds: 1)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred while saving the profile.'), duration: Duration(seconds: 1)),
      );
      debugPrint('Error in _saveProfile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return  Scaffold(
            backgroundColor: const Color(0xFFF8F8F8),
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
              actions: [
                if (_isEditing)
                  IconButton(
                    icon: const Icon(Icons.save, color: Colors.blue),
                    onPressed: _saveProfile,
                  ),
              ],
            ),
            body: ValueListenableBuilder<bool>(
            valueListenable: info!.isLoading,
            builder: (context, isLoading, _) {
              if (isLoading) {
                return const Center(child: CircularProgressIndicator());
              } else {
              return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap:   _isEditing ? _pickImage : _showProfileImageDialog,
                            child: CircleAvatar(
                              radius: 40,
                              backgroundImage: _profileImagePath != null
                                  ? _profileImagePath!.contains('assets')
                                      ? AssetImage(_profileImagePath!) as ImageProvider
                                      : FileImage(File(_profileImagePath!))
                                  : const AssetImage("assets/homeIcon.png"),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _isEditing
                              ? TextField(
                                  controller: _usernameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Username',
                                  ),
                                )
                              : Text(
                                  _usernameController.text,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                          GestureDetector(
                            onTap: _toggleEdit,
                            child: const Text(
                              'Edit profile',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Fund Balance Display
                    GestureDetector( 
                      onTap: (){
                        Navigator.push(context, MaterialPageRoute(builder: (context) =>  WalletPage()));
                      },
                      child:Row ( 
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      color: const Color.fromARGB(255, 216, 246, 218),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              "Fund Balance",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              "₹$_fundBalance",
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                      ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildCustomDisplayTile(
                            title: 'USER ID',
                            content: userId,
                            icon: Icons.perm_identity_outlined,
                          ),
                    
                    
                    const SizedBox(height: 10),
                    _isEditing
                        ? TextField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                            ),
                          )
                        : _buildCustomDisplayTile(
                            title: 'Phone Number',
                            content: _phoneController.text.isEmpty
                                ? 'Number not provided'
                                : _phoneController.text,
                            icon: Icons.phone,
                          ),
                    const SizedBox(height: 10),
                    _isEditing
                        ? TextField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                            ),
                            keyboardType: TextInputType.emailAddress,
                          )
                        : _buildCustomDisplayTile(
                            title: 'Email',
                            content: _emailController.text.isEmpty
                                ? 'Email not provided'
                                : _emailController.text,
                            icon: Icons.email,
                          ),

                    const SizedBox(height: 20),
                    const Text(
                      'Account Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    buildMenuItem('Change Password'),
                    const SizedBox(height: 20),
                    const Text(
                      'Help Center',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    buildMenuItem('FAQ'),
                    buildMenuItem('Contact Us'),
                  ],
                ),
              ),
            );
              }
        },
          ),
    );
  }
  Widget _buildCustomDisplayTile({required String title, required String content, required IconData icon}) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueAccent),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      subtitle: SelectableText(
        content,
        style: TextStyle(
          color: content.contains('not provided') ? Colors.red : Colors.black87,
        ),
      ),
      tileColor: Colors.grey[200],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget buildMenuItem(String title) {
    return GestureDetector(
      onTap: () {
        // Add navigation or logic here
         if (title == 'Change Password') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PasswordResetGuideWidget(),
            ),
          );
        } else if (title == 'FAQ') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FAQPage(),
            ),
          );
        } else if (title == 'Contact Us') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ContactUsWidget(),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 3,
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 16,color: Colors.orange,),
          ],
        ),
      ),
    );
  }
}
