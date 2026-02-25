import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';

class AuthView extends GetView<AuthController> {
  const AuthView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF24243E),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 30),

                  // Floating circles decoration
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 2,
                          ),
                        ),
                      ),
                      Container(
                        width: 75,
                        height: 75,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                      ),
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF00D9FF).withOpacity(0.2),
                        ),
                        child: const Icon(
                          Icons.fingerprint_rounded,
                          size: 28,
                          color: Color(0xFF00D9FF),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // App name
                  const Text(
                    "CheckIn",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00D9FF),
                      letterSpacing: 2,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Welcome text
                  const Text(
                    "Welcome Back",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Sign in to continue",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Glassmorphism card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: Colors.white.withOpacity(0.1),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Email field
                        TextField(
                          controller: controller.emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.white),
                          onChanged: controller.onEmailChanged,
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              Icons.alternate_email_rounded,
                              color: Colors.white.withOpacity(0.7),
                            ),
                            hintText: "Email",
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFF00D9FF),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),

                        Obx(
                          () => controller.emailMessage.value.isEmpty
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.only(
                                    top: 8,
                                    left: 4,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      controller.emailMessage.value,
                                      style: TextStyle(
                                        color: controller.isEmailValid.value
                                            ? Colors.greenAccent
                                            : Colors.redAccent,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                        ),

                        const SizedBox(height: 14),

                        // Password field
                        Obx(
                          () => TextField(
                            controller: controller.passwordController,
                            obscureText: !controller.isPasswordVisible.value,
                            style: const TextStyle(color: Colors.white),
                            onChanged: controller.onPasswordChanged,
                            decoration: InputDecoration(
                              prefixIcon: Icon(
                                Icons.lock_outline_rounded,
                                color: Colors.white.withOpacity(0.7),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  controller.isPasswordVisible.value
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                                onPressed: controller.togglePasswordVisibility,
                              ),
                              hintText: "Password",
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFF00D9FF),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),

                        Obx(
                          () => controller.passwordMessage.value.isEmpty
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.only(
                                    top: 8,
                                    left: 4,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      controller.passwordMessage.value,
                                      style: TextStyle(
                                        color: controller.isPasswordValid.value
                                            ? Colors.greenAccent
                                            : Colors.redAccent,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                        ),

                        const SizedBox(height: 8),

                        // Forgot password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {},
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 30),
                            ),
                            child: Text(
                              "Forgot Password?",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Sign in button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: controller.login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00D9FF),
                              foregroundColor: const Color(0xFF0F0C29),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              "Sign In",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
