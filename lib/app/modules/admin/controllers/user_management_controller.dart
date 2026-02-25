import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// User Management Controller
///
/// HOW AUTHENTICATION WORKS:
/// 1. Email & Password are stored in Firebase Authentication (not Firestore)
/// 2. User profile data is stored in Firestore 'users' collection
/// 3. The UID from Authentication links to the Firestore document
///
/// USER STRUCTURE BY ROLE:
/// - HOD: name, email, role, departmentId, department, isActive
/// - Teacher: name, email, role, departmentId, department, classIds (array), isActive
/// - Student: name, email, role, departmentId, department, classId (string), isActive
///   * departmentId and department name are AUTO-RESOLVED from class → department
///
/// IMPORTANT:
/// - NO DELETE functionality - use isActive flag instead
/// - Only active users (isActive=true) can login
/// - Inactive users see "Account Inactive" message at login
/// - Teachers use 'classIds' array (can teach multiple classes)
/// - Students use 'classId' string (belong to one class)
/// - Students' departmentId & department name are automatically fetched from their class
///
class UserManagementController extends GetxController {
  final users = <Map<String, dynamic>>[].obs;
  final departments = <Map<String, dynamic>>[].obs;
  final classes = <Map<String, dynamic>>[].obs;
  final isLoading = false.obs;
  final selectedUserType = 0.obs; // 0: Teachers, 1: Students, 2: HODs

  // Form controllers
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final rollNoController = TextEditingController(); // Roll No for students
  final adminPasswordController =
      TextEditingController(); // Admin password for re-auth
  final selectedDepartment = Rxn<String>();
  final selectedClass = Rxn<String>();
  final selectedClassIds = <String>[].obs; // For teachers - multiple classes
  final isPasswordVisible = false.obs;
  final isAdminPasswordVisible = false.obs;

  void toggleAdminPasswordVisibility() {
    isAdminPasswordVisible.value = !isAdminPasswordVisible.value;
  }

  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  @override
  void onInit() {
    super.onInit();
    loadUsers();
    loadDepartments();
    loadClasses();
  }

  @override
  void onClose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    rollNoController.dispose();
    adminPasswordController.dispose();
    super.onClose();
  }

  Future<void> loadDepartments() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('departments')
          .get();
      departments.value = snapshot.docs.map((doc) {
        return {'id': doc.id, 'name': doc.data()['name'] ?? 'Unknown'};
      }).toList();
    } catch (e) {
      print('Error loading departments: $e');
    }
  }

  Future<void> loadClasses() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('classes')
          .get();
      classes.value = snapshot.docs.map((doc) {
        return {'id': doc.id, 'name': doc.data()['name'] ?? 'Unknown'};
      }).toList();
    } catch (e) {
      print('Error loading classes: $e');
    }
  }

  void changeUserType(int type) {
    selectedUserType.value = type;
    loadUsers();
  }

  Future<void> loadUsers() async {
    try {
      isLoading.value = true;

      String role = '';
      switch (selectedUserType.value) {
        case 0:
          role = 'teacher';
          break;
        case 1:
          role = 'student';
          break;
        case 2:
          role = 'hod';
          break;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: role)
          .get();

      users.value = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'uid': doc.id,
          'name': data['name'] ?? 'Unknown',
          'email': data['email'] ?? '',
          'role': data['role'] ?? '',
          'isActive': data['isActive'] ?? true,
          'classId': data['classId'],
          'classIds': data['classIds'],
          'departmentId': data['departmentId'],
        };
      }).toList();
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to load users: $e",
        backgroundColor: const Color(0xFFD32F2F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // User deletion removed - use toggleUserStatus to activate/deactivate instead

  Future<void> toggleUserStatus(String uid, bool isActive) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isActive': !isActive,
      });

      final index = users.indexWhere((user) => user['uid'] == uid);
      if (index != -1) {
        users[index]['isActive'] = !isActive;
        users.refresh();
      }

      Get.snackbar(
        "Success",
        "User status updated",
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to update user status: $e",
        backgroundColor: const Color(0xFFD32F2F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  Future<void> createUser(
    String name,
    String email,
    String password,
    String role,
    String? departmentId,
    String? classId,
    List<String>? classIds,
    String? rollNo,
    String adminPassword,
  ) async {
    try {
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
        ),
        barrierDismissible: false,
      );

      // Store admin credentials before creating new user
      final adminUser = FirebaseAuth.instance.currentUser;
      final adminEmail = adminUser?.email;

      if (adminEmail == null) {
        throw Exception('Admin not logged in');
      }

      // Step 1: Auto-resolve departmentId and name
      String? resolvedDepartmentId = departmentId;
      String? resolvedDepartmentName;

      // For students: resolve from class
      if (role == 'student' && classId != null && departmentId == null) {
        final classDoc = await FirebaseFirestore.instance
            .collection('classes')
            .doc(classId)
            .get();
        if (classDoc.exists) {
          resolvedDepartmentId = classDoc.data()?['departmentId'];
        }
      }

      // Fetch department name for all roles
      if (resolvedDepartmentId != null) {
        final deptDoc = await FirebaseFirestore.instance
            .collection('departments')
            .doc(resolvedDepartmentId)
            .get();
        if (deptDoc.exists) {
          resolvedDepartmentName = deptDoc.data()?['name'];
        }
      }

      // Step 2: Create Firebase Auth user (this auto-signs in as new user!)
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // Step 3: Store user data in Firestore (now signed in as new user)
      final Map<String, dynamic> userData = {
        'name': name,
        'email': email,
        'role': role,
        'isActive': true, // New users are active by default
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Add departmentId and department name for all roles except admin
      if (role != 'admin' && resolvedDepartmentId != null) {
        userData['departmentId'] = resolvedDepartmentId;
        if (resolvedDepartmentName != null) {
          userData['department'] = resolvedDepartmentName;
        }
      }

      // Field structure based on role:
      // - Teachers: use 'classIds' (array) - can teach multiple classes
      // - Students: use 'classId' (string) - belong to one class
      // - HODs: no class field needed
      if (role == 'teacher' && classIds != null && classIds.isNotEmpty) {
        userData['classIds'] = classIds; // Array for teachers
        userData['classId'] = classIds; // Legacy support
      } else if (role == 'student' && classId != null) {
        userData['classId'] = classId; // String for students
        if (rollNo != null && rollNo.isNotEmpty) {
          userData['rollNo'] = rollNo; // Roll No for students
        }
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(userData);

      // Step 4: Sign back in as admin
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: adminEmail,
        password: adminPassword,
      );

      Get.back(); // Close loading
      Get.back(); // Close dialog

      clearForm();
      loadUsers();
      Get.snackbar(
        "Success",
        "User created successfully. Login credentials: $email",
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      Get.back(); // Close loading
      Get.snackbar(
        "Error",
        "Failed to create user: $e",
        backgroundColor: const Color(0xFFD32F2F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  Future<void> updateUser(
    String uid,
    String name,
    String? departmentId,
    String? classId,
    List<String>? classIds,
    String? rollNo,
  ) async {
    try {
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
        ),
        barrierDismissible: false,
      );

      // Get user's current role to determine field structure
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final userData = userDoc.data();
      final role = userData?['role'] ?? '';

      // Auto-resolve departmentId for students from their class
      String? resolvedDepartmentId = departmentId;
      String? resolvedDepartmentName;
      if (role == 'student' && classId != null && departmentId == null) {
        final classDoc = await FirebaseFirestore.instance
            .collection('classes')
            .doc(classId)
            .get();
        if (classDoc.exists) {
          resolvedDepartmentId = classDoc.data()?['departmentId'];
        }
      }

      // Fetch department name for all roles
      if (resolvedDepartmentId != null) {
        final deptDoc = await FirebaseFirestore.instance
            .collection('departments')
            .doc(resolvedDepartmentId)
            .get();
        if (deptDoc.exists) {
          resolvedDepartmentName = deptDoc.data()?['name'];
        }
      }

      final Map<String, dynamic> updateData = {
        'name': name,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add departmentId and department name for all roles except admin
      if (role != 'admin' && resolvedDepartmentId != null) {
        updateData['departmentId'] = resolvedDepartmentId;
        if (resolvedDepartmentName != null) {
          updateData['department'] = resolvedDepartmentName;
        }
      }

      // Field structure based on role:
      // - Teachers: use 'classIds' (array)
      // - Students: use 'classId' (string)
      // - HODs: no class field
      if (role == 'teacher' && classIds != null && classIds.isNotEmpty) {
        updateData['classIds'] = classIds; // Array for teachers
        updateData['classId'] = classIds; // Legacy support
      } else if (role == 'student' && classId != null) {
        updateData['classId'] = classId; // String for students
        if (rollNo != null && rollNo.isNotEmpty) {
          updateData['rollNo'] = rollNo; // Roll No for students
        }
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(updateData);

      Get.back(); // Close loading
      Get.back(); // Close dialog

      clearForm();
      loadUsers();
      Get.snackbar(
        "Success",
        "User updated successfully",
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } catch (e) {
      Get.back(); // Close loading
      Get.snackbar(
        "Error",
        "Failed to update user: $e",
        backgroundColor: const Color(0xFFD32F2F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  void clearForm() {
    nameController.clear();
    emailController.clear();
    passwordController.clear();
    rollNoController.clear();
    adminPasswordController.clear();
    selectedDepartment.value = null;
    selectedClass.value = null;
    selectedClassIds.clear();
  }

  void populateForEdit(Map<String, dynamic> user) {
    nameController.text = user['name'] ?? '';
    rollNoController.text = user['rollNo'] ?? '';
    selectedDepartment.value = user['departmentId'];

    // Teachers have 'classIds' (array), Students have 'classId' (string)
    // Teachers NEVER have 'classId' field - only 'classIds'
    selectedClassIds.clear();
    if (user['classIds'] != null &&
        user['classIds'] is List &&
        (user['classIds'] as List).isNotEmpty) {
      selectedClassIds.addAll(
        (user['classIds'] as List).map((e) => e.toString()).toList(),
      );
      selectedClass.value = selectedClassIds.first;
    } else {
      selectedClass.value = user['classId'];
    }
  }

  // Toggle class selection for teachers (multi-select)
  void toggleClassSelection(String classId) {
    if (selectedClassIds.contains(classId)) {
      selectedClassIds.remove(classId);
    } else {
      selectedClassIds.add(classId);
    }
  }

  // Get department name by id
  String? getDepartmentName(String? deptId) {
    if (deptId == null) return null;
    final dept = departments.firstWhereOrNull((d) => d['id'] == deptId);
    return dept?['name'];
  }

  Future<void> createUserFromDialog() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final rollNo = rollNoController.text.trim();
    final adminPassword = adminPasswordController.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        adminPassword.isEmpty) {
      Get.snackbar(
        'Error',
        'Please fill all required fields including your admin password',
        backgroundColor: const Color(0xFFD32F2F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      return;
    }

    String role = '';
    switch (selectedUserType.value) {
      case 0:
        role = 'teacher';
        break;
      case 1:
        role = 'student';
        break;
      case 2:
        role = 'hod';
        break;
    }

    await createUser(
      name,
      email,
      password,
      role,
      selectedDepartment.value,
      selectedClass.value,
      selectedClassIds.isNotEmpty ? selectedClassIds.toList() : null,
      rollNo.isEmpty ? null : rollNo,
      adminPassword,
    );
  }

  Future<void> updateUserFromDialog(String uid) async {
    final name = nameController.text.trim();
    final rollNo = rollNoController.text.trim();

    if (name.isEmpty) {
      Get.snackbar(
        'Error',
        'Name cannot be empty',
        backgroundColor: const Color(0xFFD32F2F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      return;
    }

    await updateUser(
      uid,
      name,
      selectedDepartment.value,
      selectedClass.value,
      selectedClassIds.isNotEmpty ? selectedClassIds.toList() : null,
      rollNo.isEmpty ? null : rollNo,
    );
  }
}
