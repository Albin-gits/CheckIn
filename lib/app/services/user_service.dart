import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  static Future<String?> resolveDepartmentName(
    String? departmentIdOrCode,
  ) async {
    final value = departmentIdOrCode?.trim();
    if (value == null || value.isEmpty) return null;

    // Try direct doc id first (e.g. "dept_bca")
    final byId = await FirebaseFirestore.instance
        .collection('departments')
        .doc(value)
        .get();
    if (byId.exists) {
      return (byId.data()?['name'] ?? '').toString().trim().isEmpty
          ? null
          : (byId.data()!['name']).toString();
    }

    // Fallback: try matching the department "code" field (e.g. "BCA")
    final byCode = await FirebaseFirestore.instance
        .collection('departments')
        .where('code', isEqualTo: value)
        .limit(1)
        .get();
    if (byCode.docs.isNotEmpty) {
      final data = byCode.docs.first.data();
      final name = (data['name'] ?? '').toString().trim();
      return name.isEmpty ? null : name;
    }

    return null;
  }

  static Future<String?> resolveClassName(String? classIdOrName) async {
    final value = classIdOrName?.trim();
    if (value == null || value.isEmpty) return null;

    // Try direct doc id first
    final byId = await FirebaseFirestore.instance
        .collection('classes')
        .doc(value)
        .get();
    if (byId.exists) {
      final name = (byId.data()?['name'] ?? '').toString().trim();
      return name.isEmpty ? null : name;
    }

    // Fallback: if user doc already stores class name
    final byName = await FirebaseFirestore.instance
        .collection('classes')
        .where('name', isEqualTo: value)
        .limit(1)
        .get();
    if (byName.docs.isNotEmpty) {
      final data = byName.docs.first.data();
      final name = (data['name'] ?? '').toString().trim();
      return name.isEmpty ? null : name;
    }

    return null;
  }

  static Future<Map<String, dynamic>?> getCurrentUserData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data();
    if (data == null) return null;

    final resolved = Map<String, dynamic>.from(data);

    // Prefer the human-readable department stored directly on the user doc.
    // This avoids extra reads and respects security rules (teachers/students
    // may not have permission to read `departments`).
    final deptFromUser = resolved['department']?.toString().trim();
    if (deptFromUser != null && deptFromUser.isNotEmpty) {
      resolved['departmentName'] = deptFromUser;
    }
    try {
      // Fallback to resolving from departments collection only if needed.
      if ((resolved['departmentName']?.toString().trim() ?? '').isEmpty) {
        final deptName = await resolveDepartmentName(
          resolved['departmentId']?.toString(),
        );
        if (deptName != null) {
          resolved['departmentName'] = deptName;
        }
      }
    } catch (_) {}

    try {
      final className = await resolveClassName(resolved['classId']?.toString());
      if (className != null) {
        resolved['className'] = className;
      }
    } catch (_) {}

    return resolved;
  }

  static Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }
}
