import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TeacherManagementView extends StatefulWidget {
  const TeacherManagementView({super.key});

  @override
  State<TeacherManagementView> createState() => _TeacherManagementViewState();
}

class _TeacherManagementViewState extends State<TeacherManagementView> {
  String departmentId = '';
  bool isLoading = true;
  List<Map<String, dynamic>> teachers = [];

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final deptId = doc.data()?['departmentId']?.toString() ?? '';
          if (mounted) {
            setState(() {
              departmentId = deptId;
            });
          }

          // Load teachers in department
          final teachersSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'teacher')
              .where('departmentId', isEqualTo: deptId)
              .get();

          List<Map<String, dynamic>> teachersList = [];

          for (var teacherDoc in teachersSnapshot.docs) {
            final data = teacherDoc.data();
            final classIds = data['classIds'];
            List<String> classNames = [];

            if (classIds is List) {
              for (var classId in classIds) {
                try {
                  final classDoc = await FirebaseFirestore.instance
                      .collection('classes')
                      .doc(classId)
                      .get();
                  if (classDoc.exists) {
                    classNames.add(classDoc.data()?['name'] ?? classId);
                  }
                } catch (e) {
                  classNames.add(classId);
                }
              }
            }

            teachersList.add({
              'uid': teacherDoc.id,
              'name': data['name'] ?? 'Unknown',
              'email': data['email'] ?? '',
              'isActive': data['isActive'] ?? true,
              'classes': classNames,
            });
          }

          if (mounted) {
            setState(() {
              teachers = teachersList;
              isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading teachers: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Teacher Management',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
            )
          : teachers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.people_outline, size: 64, color: Colors.white24),
                  SizedBox(height: 16),
                  Text(
                    'No teachers found',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: teachers.length,
              itemBuilder: (context, index) {
                final teacher = teachers[index];
                return _buildTeacherCard(teacher);
              },
            ),
    );
  }

  Widget _buildTeacherCard(Map<String, dynamic> teacher) {
    final isActive = teacher['isActive'] as bool;
    final classes = teacher['classes'] as List<String>;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue.withOpacity(0.2),
                child: Text(
                  teacher['name'][0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teacher['name'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      teacher['email'],
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.green.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: isActive ? Colors.green : Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (classes.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.class_, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Classes: ',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Expanded(
                  child: Text(
                    classes.join(', '),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
