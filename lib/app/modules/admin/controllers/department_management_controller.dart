import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DepartmentManagementController extends GetxController {
  final departments = <Map<String, dynamic>>[].obs;
  final classes = <Map<String, dynamic>>[].obs;
  final isLoading = false.obs;

  // Form controllers for department
  final deptNameController = TextEditingController();
  final deptCodeController = TextEditingController();
  final selectedHOD = Rxn<String>();

  // Form controllers for class
  final classNameController = TextEditingController();
  final selectedDepartmentForClass = Rxn<String>();
  final selectedTeacher = Rxn<String>();

  // HODs and Teachers list
  final hods = <Map<String, dynamic>>[].obs;
  final teachers = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadDepartments();
    loadClasses();
    loadHODs();
    loadTeachers();
  }

  @override
  void onClose() {
    deptNameController.dispose();
    deptCodeController.dispose();
    classNameController.dispose();
    super.onClose();
  }

  Future<void> loadHODs() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'hod')
          .get();
      hods.value = snapshot.docs.map((doc) {
        return {'id': doc.id, 'name': doc.data()['name'] ?? 'Unknown'};
      }).toList();
    } catch (e) {
      print('Error loading HODs: $e');
    }
  }

  Future<void> loadTeachers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'teacher')
          .get();
      teachers.value = snapshot.docs.map((doc) {
        return {'id': doc.id, 'name': doc.data()['name'] ?? 'Unknown'};
      }).toList();
    } catch (e) {
      print('Error loading teachers: $e');
    }
  }

  Future<void> loadDepartments() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('departments')
          .get();

      departments.value = await Future.wait(
        snapshot.docs.map((doc) async {
          final data = doc.data();

          // Count classes in this department
          final classSnapshot = await FirebaseFirestore.instance
              .collection('classes')
              .where('departmentId', isEqualTo: doc.id)
              .get();

          return {
            'id': doc.id,
            'name': data['name'] ?? 'Unknown',
            'code': data['code'] ?? '',
            'hodId': data['hodId'],
            'totalClasses': classSnapshot.docs.length,
          };
        }),
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to load departments: $e",
        backgroundColor: const Color(0xFFD32F2F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  Future<void> loadClasses() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('classes')
          .get();

      classes.value = await Future.wait(
        snapshot.docs.map((doc) async {
          final data = doc.data();

          // Count students in this class
          final studentSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'student')
              .where('classId', isEqualTo: doc.id)
              .get();

          return {
            'id': doc.id,
            'name': data['name'] ?? 'Unknown',
            'departmentId': data['departmentId'],
            'facultyAdvisorUid': data['facultyAdvisorUid'],
            'totalStudents': studentSnapshot.docs.length,
          };
        }),
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to load classes: $e",
        backgroundColor: const Color(0xFFD32F2F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  Future<void> createDepartment(String name, String code) async {
    try {
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
        ),
        barrierDismissible: false,
      );

      await FirebaseFirestore.instance.collection('departments').add({
        'name': name,
        'code': code,
        'hodId': selectedHOD.value,
        'createdAt': FieldValue.serverTimestamp(),
      });

      Get.back(); // Close loading
      Get.back(); // Close dialog

      clearDepartmentForm();
      loadDepartments();
      Get.snackbar(
        "Success",
        "Department created successfully",
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
        "Failed to create department: $e",
        backgroundColor: const Color(0xFFD32F2F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  Future<void> updateDepartment(String id, String name, String code) async {
    try {
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
        ),
        barrierDismissible: false,
      );

      await FirebaseFirestore.instance
          .collection('departments')
          .doc(id)
          .update({
            'name': name,
            'code': code,
            'hodId': selectedHOD.value,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      Get.back(); // Close loading
      Get.back(); // Close dialog

      clearDepartmentForm();
      loadDepartments();
      Get.snackbar(
        "Success",
        "Department updated successfully",
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
        "Failed to update department: $e",
        backgroundColor: const Color(0xFFD32F2F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  Future<void> deleteDepartment(String id) async {
    try {
      // Check if department has classes
      final classSnapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where('departmentId', isEqualTo: id)
          .get();

      if (classSnapshot.docs.isNotEmpty) {
        Get.snackbar(
          "Error",
          "Cannot delete department with existing classes",
          backgroundColor: const Color(0xFFD32F2F),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('departments')
          .doc(id)
          .delete();

      loadDepartments();
      Get.snackbar(
        "Success",
        "Department deleted successfully",
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to delete department: $e",
        backgroundColor: const Color(0xFFD32F2F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  Future<void> createClass(String name, String departmentId) async {
    try {
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
        ),
        barrierDismissible: false,
      );

      await FirebaseFirestore.instance.collection('classes').add({
        'name': name,
        'departmentId': departmentId,
        'facultyAdvisorUid': selectedTeacher.value,
        'createdAt': FieldValue.serverTimestamp(),
      });

      Get.back(); // Close loading
      Get.back(); // Close dialog

      clearClassForm();
      loadClasses();
      Get.snackbar(
        "Success",
        "Class created successfully",
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
        "Failed to create class: $e",
        backgroundColor: const Color(0xFFD32F2F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  Future<void> updateClass(String id, String name, String departmentId) async {
    try {
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
        ),
        barrierDismissible: false,
      );

      await FirebaseFirestore.instance.collection('classes').doc(id).update({
        'name': name,
        'departmentId': departmentId,
        'facultyAdvisorUid': selectedTeacher.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Get.back(); // Close loading
      Get.back(); // Close dialog

      clearClassForm();
      loadClasses();
      Get.snackbar(
        "Success",
        "Class updated successfully",
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
        "Failed to update class: $e",
        backgroundColor: const Color(0xFFD32F2F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  Future<void> deleteClass(String id) async {
    try {
      // Check if class has students
      final studentSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('classId', isEqualTo: id)
          .get();

      if (studentSnapshot.docs.isNotEmpty) {
        Get.snackbar(
          "Error",
          "Cannot delete class with enrolled students",
          backgroundColor: const Color(0xFFD32F2F),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
        return;
      }

      await FirebaseFirestore.instance.collection('classes').doc(id).delete();

      loadClasses();
      Get.snackbar(
        "Success",
        "Class deleted successfully",
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to delete class: $e",
        backgroundColor: const Color(0xFFD32F2F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  void clearDepartmentForm() {
    deptNameController.clear();
    deptCodeController.clear();
    selectedHOD.value = null;
  }

  void clearClassForm() {
    classNameController.clear();
    selectedDepartmentForClass.value = null;
    selectedTeacher.value = null;
  }
}
