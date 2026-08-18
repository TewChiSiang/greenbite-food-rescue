import 'dart:typed_data'; 
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;

  void _handleLogout() async {
    await _authService.signOut();
    if (!mounted) {
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _changeProfilePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );

    if (image == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String uid = currentUser!.uid;
      Reference ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$uid.jpg');

      Uint8List imageBytes = await image.readAsBytes();
      
      await ref.putData(
        imageBytes, 
        SettableMetadata(contentType: 'image/jpeg')
      );
      
      String downloadUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('Users').doc(uid).update({
        'profileImageUrl': downloadUrl,
      });

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo updated!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _changePassword() async {
    if (currentUser?.email == null) {
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change Password'),
        content: Text(
          'We will send a password reset link to ${currentUser!.email}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Navigator.pop(dialogContext); 
              String result = await _authService.resetPassword(
                currentUser!.email!,
              );

              if (!mounted) {
                return;
              }

              if (result == 'Success') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reset link sent to your email.'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text(
              'Send Link',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteAccount() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Delete Account',
          style: TextStyle(color: Colors.red),
        ),
        content: const Text(
          'Are you sure you want to permanently delete your account? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogContext); 
              setState(() {
                _isLoading = true;
              });

              try {
                String uid = currentUser!.uid;
                await FirebaseFirestore.instance
                    .collection('Users')
                    .doc(uid)
                    .delete();
                await currentUser!.delete();

                if (!mounted) {
                  return;
                }
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              } on FirebaseAuthException catch (e) {
                if (!mounted) {
                  return;
                }
                setState(() {
                  _isLoading = false;
                });

                if (e.code == 'requires-recent-login') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Security required: Please log out and log back in before deleting your account.',
                      ),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 4),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.message}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(String currentName) {
    TextEditingController nameController = TextEditingController(
      text: currentName,
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Profile'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;

              Navigator.pop(dialogContext);

              setState(() {
                _isLoading = true;
              });

              try {
                await FirebaseFirestore.instance
                    .collection('Users')
                    .doc(currentUser!.uid)
                    .update({'name': nameController.text.trim()});

                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profile Updated!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to update profile: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- NEW: CONTACT US DIALOG ---
  void _showContactUsDialog(String userEmail) {
    String selectedType = 'General';
    final TextEditingController descController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          // FIX: Renamed 'context' to 'innerContext' to prevent shadowing
          builder: (innerContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Contact Support'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Issue Type',
                        border: OutlineInputBorder(),
                      ),
                      items: ['General', 'Bug Report', 'Feature Request']
                          .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Describe your issue or feedback...',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
                  onPressed: () async {
                    if (descController.text.trim().isEmpty) return;
                    
                    Navigator.pop(dialogContext); // Close dialog

                    try {
                      // Submit to Feedback Collection for Admin to see
                      await FirebaseFirestore.instance.collection('Feedback').add({
                        'uid': currentUser!.uid,
                        'email': userEmail,
                        'reportType': selectedType,
                        'description': descController.text.trim(),
                        'status': 'Open',
                        'timestamp': FieldValue.serverTimestamp(),
                      });

                      if (!mounted) return;
                      // This now safely uses the outer context!
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Feedback sent! Our admin will review it soon.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      // This now safely uses the outer context!
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to send feedback: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text('Submit', style: TextStyle(color: Colors.white)),
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
    if (currentUser == null) {
      return const Center(child: Text('Not logged in'));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _dbService.getUserData(currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          Map<String, dynamic> userData = {};
          if (snapshot.hasData && snapshot.data!.data() != null) {
            userData = snapshot.data!.data() as Map<String, dynamic>;
          }
          String name = userData['name'] ?? 'Consumer';
          String initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';
          String email = userData['email'] ?? currentUser!.email ?? '';
          String? profileImageUrl = userData['profileImageUrl'];

          return SafeArea(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      GestureDetector(
                        onTap: _changeProfilePhoto,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.green.shade100,
                              backgroundImage: profileImageUrl != null
                                  ? NetworkImage(profileImageUrl)
                                  : null,
                              child: profileImageUrl == null
                                  ? Text(
                                      initial,
                                      style: TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade800,
                                      ),
                                    )
                                  : null,
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 40),

                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit, color: Colors.black87),
                        ),
                        title: const Text(
                          'Edit Profile',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _showEditProfileDialog(name),
                      ),
                      const Divider(),

                      // --- NEW: CONTACT US BUTTON ---
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.support_agent, color: Colors.blue),
                        ),
                        title: const Text(
                          'Contact Support',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _showContactUsDialog(email),
                      ),
                      const Divider(),

                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.lock, color: Colors.black87),
                        ),
                        title: const Text(
                          'Change Password',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: _changePassword,
                      ),
                      const Divider(),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.delete_forever,
                            color: Colors.red,
                          ),
                        ),
                        title: const Text(
                          'Delete Account',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: _deleteAccount,
                      ),
                      const Divider(),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.logout,
                            color: Colors.black87,
                          ),
                        ),
                        title: const Text(
                          'Log Out',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: _handleLogout,
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  Container(
                    color: Colors.black26,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}