import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SnackbarHelper {
  // Error snackbar (Red)
  static void showError(String title, String message) {
    Get.snackbar(
      title,
      message,
      backgroundColor: const Color(0xFFD32F2F),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      icon: const Icon(Icons.error_outline, color: Colors.white),
      shouldIconPulse: true,
      duration: const Duration(seconds: 3),
    );
  }

  // Success snackbar (Green)
  static void showSuccess(String title, String message) {
    Get.snackbar(
      title,
      message,
      backgroundColor: const Color(0xFF4CAF50),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      icon: const Icon(Icons.check_circle_outline, color: Colors.white),
      shouldIconPulse: true,
      duration: const Duration(seconds: 3),
    );
  }

  // Info snackbar (Blue)
  static void showInfo(String title, String message) {
    Get.snackbar(
      title,
      message,
      backgroundColor: const Color(0xFF2196F3),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      icon: const Icon(Icons.info_outline, color: Colors.white),
      shouldIconPulse: true,
      duration: const Duration(seconds: 3),
    );
  }

  // Warning snackbar (Orange)
  static void showWarning(String title, String message) {
    Get.snackbar(
      title,
      message,
      backgroundColor: const Color(0xFFFF9800),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      icon: const Icon(Icons.warning_amber_outlined, color: Colors.white),
      shouldIconPulse: true,
      duration: const Duration(seconds: 3),
    );
  }
}
