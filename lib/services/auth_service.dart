import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Add this import for Firestore
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Instance of Firestore

  // --- EXISTING LOGIN METHOD ---
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(), 
        password: password.trim(),
      );
      return result.user; 
    } on FirebaseAuthException catch (e) {
      debugPrint("Login Error: ${e.message}"); 
      return null;
    }
  }

  // --- NEW: FORGOT PASSWORD METHOD ---
  Future<String> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return 'Success'; 
    } on FirebaseAuthException catch (e) {
      debugPrint("Password Reset Error: ${e.message}");
      return e.message ?? 'An error occurred';
    } catch (e) {
      debugPrint("Password Reset Error: $e");
      return 'An unexpected error occurred';
    }
  }

 //Registration Method
  Future<User?> registerWithEmailPassword(
    String name, 
    String email, 
    String password, 
    String role, {
    String? businessName,
    String? businessAddress,
    String? ssmNumber,
    String? gitaNumber, // <--- 1. NEW PARAMETER ADDED HERE
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(), 
        password: password.trim(),
      );
      
      User? user = result.user;

      if (user != null) {
        // Base user data
        Map<String, dynamic> userData = {
          'uid': user.uid,
          'name': name.trim(),
          'email': email.trim(),
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
        };

        // If they are a vendor, add business details and lock the account
        if (role == 'Vendor') {
          userData['businessName'] = businessName?.trim() ?? '';
          userData['businessAddress'] = businessAddress?.trim() ?? '';
          userData['ssmNumber'] = ssmNumber?.trim() ?? '';
          userData['gitaNumber'] = gitaNumber?.trim() ?? ''; // <--- 2. SAVED TO FIRESTORE HERE
          userData['accountStatus'] = 'Pending'; // <--- Requires Admin Approval
        } else {
          userData['accountStatus'] = 'Active'; // Consumers are instantly active
        }

        await _firestore.collection('Users').doc(user.uid).set(userData);
      }
      return user;
      
    } catch (e) { 
      debugPrint("Registration/Firestore Error: $e");
      return null;
    }
  }

  // --- ADD THIS TO YOUR AUTH SERVICE ---
  Future<String?> getUserRole(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('Users').doc(uid).get();
      if (doc.exists) {
        return doc.get('role') as String?;
      }
    } catch (e) {
      debugPrint("Error fetching role: $e");
    }
    return null;
  }

  // --- EXISTING LOGOUT METHOD ---
  Future<void> signOut() async {
    await _auth.signOut();
  }
}