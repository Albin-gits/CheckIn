import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentManagementView extends StatefulWidget {
  const StudentManagementView({super.key});

  @override
  State<StudentManagementView> createState() => _StudentManagementViewState();
}

class _StudentManagementViewState extends State<StudentManagementView> {
  String departmentId = '';
  bool isLoading = true;
  List<Map<String, dynamic>> students = [];
  String? selectedClassFilter;
  List<String> availableClasses = [];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
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

          // Load students in department
          final studentsSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'student')
              .where('departmentId', isEqualTo: deptId)
              .get();

          List<Map<String, dynamic>> studentsList = [];
          Set<String> classIds = {};

          for (var studentDoc in studentsSnapshot.docs) {
            final data = studentDoc.data();
            final classId = data['classId']?.toString() ?? '';
            String? className;

            if (classId.isNotEmpty) {
              classIds.add(classId);
              try {
                final classDoc = await FirebaseFirestore.instance
                    .collection('classes')
                    .doc(classId)
                    .get();
                if (classDoc.exists) {
                  className = classDoc.data()?['name'] ?? classId;
                }
              } catch (e) {
                className = classId;
              }
            }

            studentsList.add({
              'uid': studentDoc.id,
              'name': data['name'] ?? 'Unknown',
              'email': data['email'] ?? '',
              'classId': classId,
              'className': className ?? 'No Class',
              'isActive': data['isActive'] ?? true,
            });
          }

          // Sort by name
          studentsList.sort((a, b) => a['name'].compareTo(b['name']));

          if (mounted) {
            setState(() {
              students = studentsList;
              availableClasses = classIds.toList();
              isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading students: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get filteredStudents {
    if (selectedClassFilter == null) {
      return students;
    }
    return students.where((s) => s['classId'] == selectedClassFilter).toList();
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
          'Student Management',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
            )
          : Column(
              children: [
                // Filter by class
                if (availableClasses.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16213E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedClassFilter,
                        hint: const Text(
                          'Filter by class (All)',
                          style: TextStyle(color: Colors.white70),
                        ),
                        dropdownColor: const Color(0xFF16213E),
                        style: const TextStyle(color: Colors.white),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('All Classes'),
                          ),
                          ...availableClasses.map((classId) {
                            return DropdownMenuItem<String>(
                              value: classId,
                              child: Text(classId),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedClassFilter = value;
                          });
                        },
                      ),
                    ),
                  ),

                // Students list
                Expanded(
                  child: filteredStudents.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.school_outlined,
                                size: 64,
                                color: Colors.white24,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No students found',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredStudents.length,
                          itemBuilder: (context, index) {
                            final student = filteredStudents[index];
                            return _buildStudentCard(student);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final isActive = student['isActive'] as bool;

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
                backgroundColor: Colors.green.withOpacity(0.2),
                child: Text(
                  student['name'][0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.green,
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
                      student['name'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      student['email'],
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
          const SizedBox(height: 12),
          const Divider(color: Colors.white24),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.class_, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(
                'Class: ${student['className']}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
