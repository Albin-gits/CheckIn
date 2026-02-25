import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:check_in_app/app/routes/app_pages.dart';
import 'dart:async';

class AuthController extends GetxController {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final emailMessage = ''.obs;
  final passwordMessage = ''.obs;
  final isEmailValid = false.obs;
  final isPasswordValid = false.obs;

  Timer? _emailDebounce;
  Timer? _passwordDebounce;
  Timer? _credentialsDebounce;

  int _emailValidationGeneration = 0;
  int _credentialsValidationGeneration = 0;

  bool _loginInProgress = false;

  static final RegExp _eduEmailRegex = RegExp(
    r'^[^\s@]+@[^\s@]+\.edu$',
    caseSensitive: false,
  );

  String _normalizeEmail(String raw) => raw.trim().toLowerCase();

  void onEmailChanged(String value) {
    _emailDebounce?.cancel();
    // Hide message while user is typing.
    emailMessage.value = '';
    isEmailValid.value = false;

    _emailDebounce = Timer(const Duration(milliseconds: 500), () {
      _validateEmailAndMaybeCheckAccount(value, showEmptyError: false);
    });

    _scheduleCredentialCheck();
  }

  void onPasswordChanged(String value) {
    _passwordDebounce?.cancel();
    // Hide message while user is typing.
    passwordMessage.value = '';
    isPasswordValid.value = false;

    _passwordDebounce = Timer(const Duration(milliseconds: 500), () {
      _validatePasswordAndSetMessage(value, showEmptyError: false);
    });

    _scheduleCredentialCheck();
  }

  void _scheduleCredentialCheck() {
    _credentialsDebounce?.cancel();
    // Give the user a small pause after typing both fields.
    _credentialsDebounce = Timer(const Duration(milliseconds: 700), () {
      _verifyCredentialsIfReady();
    });
  }

  bool _validateEmailAndMaybeCheckAccount(
    String raw, {
    required bool showEmptyError,
  }) {
    final email = _normalizeEmail(raw);

    if (email.isEmpty) {
      emailMessage.value = showEmptyError ? 'Email cannot be empty' : '';
      isEmailValid.value = false;
      return false;
    }

    if (!email.contains('@')) {
      emailMessage.value = 'Email must contain @';
      isEmailValid.value = false;
      return false;
    }

    if (!email.toLowerCase().endsWith('.edu')) {
      emailMessage.value = 'End with .edu';
      isEmailValid.value = false;
      return false;
    }

    // Basic .edu email structure validation (no spaces, something@something.edu)
    if (!_eduEmailRegex.hasMatch(email)) {
      // Keep messaging limited to the required rule feedback.
      emailMessage.value = 'Email must contain @';
      isEmailValid.value = false;
      return false;
    }

    // Format is valid.
    emailMessage.value = '';
    isEmailValid.value = true;
    return true;
  }

  Future<bool> _checkEmailRegistered(
    String email, {
    int? generation,
    required bool showNotFoundMessage,
  }) async {
    try {
      final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(
        email,
      );

      if (kDebugMode) {
        // Helpful for diagnosing “email not found” issues.
        print('fetchSignInMethodsForEmail($email) => $methods');
      }

      if (generation != null && generation != _emailValidationGeneration) {
        return false;
      }

      if (methods.isEmpty) {
        if (showNotFoundMessage) {
          emailMessage.value = 'Email not found';
          isEmailValid.value = false;
        }
        return false;
      } else {
        emailMessage.value = 'Email verified';
        isEmailValid.value = true;
        return true;
      }
    } on FirebaseAuthException catch (e) {
      if (generation != null && generation != _emailValidationGeneration) {
        return false;
      }

      if (e.code == 'invalid-email') {
        emailMessage.value = 'Email must contain @';
        isEmailValid.value = false;
        return false;
      }

      // Any other auth errors: keep current message; don't claim “not found”.
      return false;
    } catch (_) {
      if (generation != null && generation != _emailValidationGeneration) {
        return false;
      }
      return false;
    }
  }

  bool _validateEmailFormatOnly(String raw, {required bool showEmptyError}) {
    final email = _normalizeEmail(raw);

    if (email.isEmpty) {
      emailMessage.value = showEmptyError ? 'Email cannot be empty' : '';
      isEmailValid.value = false;
      return false;
    }

    if (!email.contains('@')) {
      emailMessage.value = 'Email must contain @';
      isEmailValid.value = false;
      return false;
    }

    if (!email.endsWith('.edu')) {
      emailMessage.value = 'End with .edu';
      isEmailValid.value = false;
      return false;
    }

    if (!_eduEmailRegex.hasMatch(email)) {
      emailMessage.value = 'Email must contain @';
      isEmailValid.value = false;
      return false;
    }

    // Format is OK; don’t claim registration here.
    emailMessage.value = '';
    isEmailValid.value = true;
    return true;
  }

  bool _validatePasswordAndSetMessage(
    String raw, {
    required bool showEmptyError,
  }) {
    final password = raw;

    if (password.trim().isEmpty) {
      passwordMessage.value = showEmptyError ? 'Password cannot be empty' : '';
      isPasswordValid.value = false;
      return false;
    }

    if (password.length < 6) {
      passwordMessage.value = 'Password must be at least 6 characters';
      isPasswordValid.value = false;
      return false;
    }

    // Length is OK. Correctness is checked via Firebase Auth.
    passwordMessage.value = '';
    isPasswordValid.value = true;
    return true;
  }

  Future<void> _verifyCredentialsIfReady() async {
    if (_loginInProgress) return;

    final email = _normalizeEmail(emailController.text);
    final password = passwordController.text;

    final emailOk = _validateEmailFormatOnly(email, showEmptyError: false);
    final passwordOk = _validatePasswordAndSetMessage(
      password,
      showEmptyError: false,
    );
    if (!emailOk || !passwordOk) return;

    final int generation = ++_credentialsValidationGeneration;

    try {
      // This is the only reliable way to know the password is correct.
      // NOTE: This signs in briefly, then signs out.
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (generation != _credentialsValidationGeneration) return;
      if (_loginInProgress) return;

      emailMessage.value = 'Email is correct';
      isEmailValid.value = true;
      passwordMessage.value = 'Password is correct';
      isPasswordValid.value = true;

      // Avoid staying signed in because the user might still be editing.
      // (Actual login happens when they tap Sign In.)
      await FirebaseAuth.instance.signOut();

      // If signOut raced with newer validation, don't overwrite messages.
      if (generation != _credentialsValidationGeneration) return;

      // Keep the "correct" messages visible.
      if (kDebugMode) {
        print('Credential check success for ${credential.user?.email}');
      }
    } on FirebaseAuthException catch (e) {
      if (generation != _credentialsValidationGeneration) return;
      if (_loginInProgress) return;

      final code = e.code.toLowerCase();
      if (code == 'wrong-password') {
        emailMessage.value = 'Email is correct';
        isEmailValid.value = true;
        passwordMessage.value = 'Incorrect password';
        isPasswordValid.value = false;
        return;
      }
      if (code == 'user-not-found') {
        emailMessage.value = 'Email not found';
        isEmailValid.value = false;
        passwordMessage.value = '';
        isPasswordValid.value = true;
        return;
      }
      if (code == 'invalid-credential' ||
          code == 'invalid-login-credentials' ||
          code == 'invalid_login_credentials') {
        // Ambiguous (can be wrong password or other issues). Treat as password wrong.
        passwordMessage.value = 'Incorrect email or password';
        isPasswordValid.value = false;
        return;
      }
      // For rate limit / network etc, don't claim not found.
      passwordMessage.value = '';
      isPasswordValid.value = true;
    } catch (_) {
      if (generation != _credentialsValidationGeneration) return;
      if (_loginInProgress) return;
      // Ignore unexpected errors for live validation.
    }
  }

  void login() async {
    try {
      final email = _normalizeEmail(emailController.text);
      final password = passwordController.text;

      if (kDebugMode) {
        print('Login attempt: $email');
      }

      // Cancel any pending debounce so messages are up-to-date.
      _emailDebounce?.cancel();
      _passwordDebounce?.cancel();
      _credentialsDebounce?.cancel();
      _credentialsValidationGeneration++;

      // For login, validate format synchronously and rely on the actual
      // Firebase Auth sign-in response for “Email not found/Incorrect password”.
      final emailOk = _validateEmailFormatOnly(email, showEmptyError: true);
      final passwordOk = _validatePasswordAndSetMessage(
        password,
        showEmptyError: true,
      );

      if (!emailOk || !passwordOk) return;

      _loginInProgress = true;

      // Clear previous auth error message (if any) before attempting login.
      if (passwordMessage.value == 'Incorrect password') {
        passwordMessage.value = '';
      }

      if (kDebugMode) {
        print('Attempting Firebase authentication...');
      }
      UserCredential credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      if (kDebugMode) {
        print('Authentication successful, getting user data...');
      }
      final uid = credential.user!.uid;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (kDebugMode) {
        print('User document exists: ${userDoc.exists}');
      }

      if (!userDoc.exists) {
        Get.snackbar(
          "Error",
          "User data not found in database",
          backgroundColor: const Color(0xFFD32F2F),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
        return;
      }

      final userData = userDoc.data();
      final role = userData?['role'];
      final isActive = userData?['isActive'] ?? true;

      if (kDebugMode) {
        print('User role: $role, isActive: $isActive');
      }

      // Check if user account is active
      if (!isActive) {
        await FirebaseAuth.instance.signOut();
        Get.snackbar(
          "Account Inactive",
          "Your account has been deactivated. Please contact the administrator.",
          backgroundColor: const Color(0xFFD32F2F),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          duration: const Duration(seconds: 5),
        );
        return;
      }

      if (role == 'admin') {
        Get.offAllNamed(Routes.ADMIN);
      } else if (role == 'hod') {
        Get.offAllNamed(Routes.HOD);
      } else if (role == 'teacher') {
        Get.offAllNamed(Routes.TEACHER);
      } else if (role == 'student') {
        Get.offAllNamed(Routes.STUDENT);
      } else {
        Get.snackbar(
          "Error",
          "Invalid user role: $role",
          backgroundColor: const Color(0xFFD32F2F),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
      }
    } on FirebaseAuthException catch (e) {
      // Show field-level errors where possible.
      final code = e.code.toLowerCase();

      if (code == 'wrong-password') {
        passwordMessage.value = 'Incorrect password';
        isPasswordValid.value = false;
        return;
      }
      if (code == 'user-not-found') {
        emailMessage.value = 'Email not found';
        isEmailValid.value = false;
        return;
      }
      if (code == 'invalid-email') {
        emailMessage.value = 'Email must contain @';
        isEmailValid.value = false;
        return;
      }
      // Incorrect credentials (newer + older variants across platforms).
      if (code == 'invalid-credential' ||
          code == 'invalid-login-credentials' ||
          code == 'invalid_login_credentials') {
        passwordMessage.value = 'Incorrect username or password';
        isPasswordValid.value = false;
        return;
      }

      Get.snackbar(
        'Login Failed',
        e.message ?? e.code,
        backgroundColor: const Color(0xFFD32F2F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } catch (e) {
      Get.snackbar(
        'Login Failed',
        e.toString(),
        backgroundColor: const Color(0xFFD32F2F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } finally {
      _loginInProgress = false;
    }
  }

  final isPasswordVisible = false.obs;

  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  @override
  void onClose() {
    _emailDebounce?.cancel();
    _passwordDebounce?.cancel();
    _credentialsDebounce?.cancel();
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
