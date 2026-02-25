import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:check_in_app/app/routes/app_pages.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    // Wait for the first frame to be rendered before checking auth
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthState();
    });
  }

  Future<void> _checkAuthState() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        // No user logged in, navigate to login screen
        Get.offAllNamed(Routes.AUTH);
        return;
      }

      // User is logged in, fetch their role from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        // User document doesn't exist, log out and go to login
        await FirebaseAuth.instance.signOut();
        Get.offAllNamed(Routes.AUTH);
        return;
      }

      final userData = userDoc.data();
      final role = userData?['role'];

      // Navigate based on role
      if (role == 'admin') {
        Get.offAllNamed(Routes.ADMIN);
      } else if (role == 'hod') {
        Get.offAllNamed(Routes.HOD);
      } else if (role == 'teacher') {
        Get.offAllNamed(Routes.TEACHER);
      } else if (role == 'student') {
        Get.offAllNamed(Routes.STUDENT);
      } else {
        // Invalid role, log out and go to login
        await FirebaseAuth.instance.signOut();
        Get.offAllNamed(Routes.AUTH);
      }
    } catch (e) {
      print('Error in AuthGate: $e');
      // Error fetching user data, navigate to login
      Get.offAllNamed(Routes.AUTH);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a minimal loading indicator while checking auth state
    return const Scaffold(
      backgroundColor: Color(0xFF1A1A2E),
      body: Center(child: CircularProgressIndicator(color: Color(0xFF00D9FF))),
    );
  }
}
