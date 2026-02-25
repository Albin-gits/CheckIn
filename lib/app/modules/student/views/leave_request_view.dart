import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class LeaveRequestView extends StatefulWidget {
  const LeaveRequestView({super.key});

  @override
  State<LeaveRequestView> createState() => _LeaveRequestViewState();
}

class _LeaveRequestViewState extends State<LeaveRequestView> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool isLoading = false;
  List<Map<String, dynamic>> leaveRequests = [];
  String studentName = '';
  String className = '';
  String classId = '';
  String departmentId = '';

  @override
  void initState() {
    super.initState();
    _loadStudentInfo();
    _loadLeaveRequests();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && doc.data() != null && mounted) {
          final data = doc.data()!;
          final studentClassId = data['classId']?.toString() ?? '';
          setState(() {
            studentName = data['name'] ?? '';
            classId = studentClassId;
            departmentId = data['departmentId']?.toString() ?? '';
          });

          // Load class name
          if (studentClassId.isNotEmpty) {
            final classDoc = await FirebaseFirestore.instance
                .collection('classes')
                .doc(studentClassId)
                .get();
            if (classDoc.exists && mounted) {
              setState(() {
                className = classDoc.data()?['name'] ?? studentClassId;
              });
            }
          }
        }
      }
    } catch (e) {
      print('Error loading student info: $e');
    }
  }

  Future<void> _loadLeaveRequests() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No user logged in');
        return;
      }

      print('===== LOADING STUDENT LEAVE REQUESTS =====');
      print('Student UID: ${user.uid}');

      final snapshot = await FirebaseFirestore.instance
          .collection('leaveRequests')
          .where('studentId', isEqualTo: user.uid)
          .get();

      print('Found ${snapshot.docs.length} leave requests');

      if (snapshot.docs.isEmpty) {
        print('No leave requests found for this student');
      }

      if (mounted) {
        final requests = snapshot.docs.map((doc) {
          final data = doc.data();
          print('Leave Request: ${doc.id} - Status: ${data['status']}');
          return {
            'id': doc.id,
            'reason': data['reason']?.toString() ?? '',
            'startDate': data['startDate'],
            'endDate': data['endDate'],
            'totalDays': data['totalDays'] ?? 0,
            'status': data['status']?.toString() ?? 'pending',
            'requestedAt': data['requestedAt'],
            'responseMessage': data['responseMessage']?.toString(),
            'reviewerRole': data['reviewerRole']?.toString(),
            'reviewedAt': data['reviewedAt'],
          };
        }).toList();

        // Sort by requestedAt in memory
        requests.sort((a, b) {
          final aTime = a['requestedAt'] as Timestamp?;
          final bTime = b['requestedAt'] as Timestamp?;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        setState(() {
          leaveRequests = requests;
        });

        print('Leave requests loaded: ${leaveRequests.length}');
        print('==========================================');
      }
    } catch (e) {
      print('Error loading leave requests: $e');
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00D9FF),
              surface: Color(0xFF16213E),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = picked;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      Get.snackbar(
        'Error',
        'Please select both start and end dates',
        backgroundColor: const Color(0xFFD32F2F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    if (classId.isEmpty || departmentId.isEmpty) {
      Get.snackbar(
        'Error',
        'Student class/department information is missing',
        backgroundColor: const Color(0xFFD32F2F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Calculate total days
      final totalDays = _endDate!.difference(_startDate!).inDays + 1;

      print('Submitting leave request:');
      print('Student ID: ${user.uid}');
      print('Student Name: $studentName');
      print('Class ID: $classId');
      print('Department ID: $departmentId');
      print('Total Days: $totalDays');

      await FirebaseFirestore.instance.collection('leaveRequests').add({
        'studentId': user.uid,
        'studentName': studentName,
        'classId': classId,
        'departmentId': departmentId,
        'reason': _reasonController.text.trim(),
        'startDate': Timestamp.fromDate(_startDate!),
        'endDate': Timestamp.fromDate(_endDate!),
        'totalDays': totalDays,
        'status': 'pending',
        'reviewedByUid': '',
        'reviewerRole': '',
        'responseMessage': '',
        'requestedAt': FieldValue.serverTimestamp(),
      });

      print('Leave request submitted successfully!');

      Get.snackbar(
        'Success',
        'Leave request submitted successfully',
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );

      _reasonController.clear();
      setState(() {
        _startDate = null;
        _endDate = null;
      });

      _loadLeaveRequests();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to submit leave request: $e',
        backgroundColor: const Color(0xFFD32F2F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    } finally {
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
          'Leave Request',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Request Form
            const Text(
              'Request Leave',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Selection
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _selectDate(context, true),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Start Date',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _startDate == null
                                        ? 'Select'
                                        : DateFormat(
                                            'MMM dd, yyyy',
                                          ).format(_startDate!),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _selectDate(context, false),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'End Date',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _endDate == null
                                        ? 'Select'
                                        : DateFormat(
                                            'MMM dd, yyyy',
                                          ).format(_endDate!),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Reason Field
                    TextFormField(
                      controller: _reasonController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Reason for Leave',
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: 'Enter reason...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF00D9FF),
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a reason';
                        }
                        if (value.trim().length < 10) {
                          return 'Reason must be at least 10 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _submitRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D9FF),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Submit Request',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Previous Requests
            const Text(
              'My Leave Requests',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            if (leaveRequests.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'No leave requests yet',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              )
            else
              ...leaveRequests.map((request) => _buildRequestCard(request)),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final status = request['status'].toString();
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDateRange(request),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${request['totalDays']} day${request['totalDays'] > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: Colors.white70,
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
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
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
              const Icon(Icons.description, color: Colors.white54, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Reason: ',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              Expanded(
                child: Text(
                  request['reason'],
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
          if (request['responseMessage'] != null &&
              request['responseMessage'].toString().trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: statusColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.chat_bubble_outline, color: statusColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Faculty Advisor Response:',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          request['responseMessage'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (request['reviewedAt'] != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.white54, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Reviewed: ${_formatReviewDate(request['reviewedAt'])}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateRange(Map<String, dynamic> request) {
    try {
      final startDate = request['startDate'];
      final endDate = request['endDate'];

      if (startDate is Timestamp && endDate is Timestamp) {
        final start = DateFormat('MMM dd, yyyy').format(startDate.toDate());
        final end = DateFormat('MMM dd, yyyy').format(endDate.toDate());
        return '$start to $end';
      }
      return '${request['startDate']} to ${request['endDate']}';
    } catch (e) {
      return 'Date error';
    }
  }

  String _formatReviewDate(dynamic reviewedAt) {
    try {
      if (reviewedAt is Timestamp) {
        return DateFormat('MMM dd, yyyy h:mm a').format(reviewedAt.toDate());
      }
      return reviewedAt.toString();
    } catch (e) {
      return 'Date error';
    }
  }
}
