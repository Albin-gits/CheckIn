import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class LeaveManagementView extends StatefulWidget {
  const LeaveManagementView({super.key});

  @override
  State<LeaveManagementView> createState() => _LeaveManagementViewState();
}

class _LeaveManagementViewState extends State<LeaveManagementView> {
  bool isLoading = true;
  List<Map<String, dynamic>> leaveRequests = [];
  String selectedFilter = 'pending';
  String teacherClassId = '';
  String teacherName = '';
  String className = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadTeacherInfo();
    await _loadLeaveRequests();
  }

  Future<void> _loadTeacherInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data() != null && mounted) {
        final data = doc.data()!;
        setState(() {
          teacherName = data['name'] ?? '';
        });

        print('Teacher UID: ${user.uid}');
        print('Teacher Name: ${teacherName}');

        // Get classes where teacher is faculty advisor
        final classesSnapshot = await FirebaseFirestore.instance
            .collection('classes')
            .where('facultyAdvisorUid', isEqualTo: user.uid)
            .get();

        print('Classes found: ${classesSnapshot.docs.length}');

        if (classesSnapshot.docs.isNotEmpty) {
          final classDoc = classesSnapshot.docs.first;
          final assignedClassId = classDoc.id;
          final assignedClassName = classDoc.data()['name'] ?? assignedClassId;

          print('===== CLASS INFO =====');
          print('Assigned Class ID: $assignedClassId');
          print('Class Name: $assignedClassName');
          print('======================');

          if (mounted) {
            setState(() {
              teacherClassId = assignedClassId;
              className = assignedClassName;
            });
          }
        } else {
          print('===== ERROR =====');
          print('No class found where teacher is faculty advisor');
          print('Teacher UID to check: ${user.uid}');
          print('=================');
        }
      }
    } catch (e) {
      print('Error loading teacher info: $e');
    }
  }

  Future<void> _loadLeaveRequests() async {
    if (teacherClassId.isEmpty) {
      print('Cannot load leave requests: teacherClassId is empty');
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      setState(() {
        isLoading = true;
      });

      print('===== LOADING LEAVE REQUESTS =====');
      print('Query classId: $teacherClassId');
      print('Filter: $selectedFilter');

      // Fetch all leave requests for this class (no compound index needed)
      final snapshot = await FirebaseFirestore.instance
          .collection('leaveRequests')
          .where('classId', isEqualTo: teacherClassId)
          .get();

      print('===== QUERY RESULTS =====');
      print(
        'Found ${snapshot.docs.length} total leave requests for this class',
      );

      if (mounted) {
        // Convert to list and filter in memory
        final allRequests = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'studentId': data['studentId']?.toString() ?? '',
            'studentName': data['studentName']?.toString() ?? '',
            'reason': data['reason']?.toString() ?? '',
            'startDate': data['startDate'],
            'endDate': data['endDate'],
            'totalDays': data['totalDays'] ?? 0,
            'status': data['status']?.toString() ?? 'pending',
            'requestedAt': data['requestedAt'],
            'responseMessage': data['responseMessage']?.toString(),
            'reviewedAt': data['reviewedAt'],
          };
        }).toList();

        // Filter by status if not 'all'
        final filteredRequests = selectedFilter == 'all'
            ? allRequests
            : allRequests
                  .where((req) => req['status'] == selectedFilter)
                  .toList();

        // Sort by requestedAt (newest first)
        filteredRequests.sort((a, b) {
          final aTime = a['requestedAt'] as Timestamp?;
          final bTime = b['requestedAt'] as Timestamp?;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        print(
          'After filtering by "$selectedFilter": ${filteredRequests.length} requests',
        );
        for (var req in filteredRequests) {
          print(
            '  - ${req['studentName']}: ${req['status']} (${req['totalDays']} days)',
          );
        }
        print('=========================');

        setState(() {
          leaveRequests = filteredRequests;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading leave requests: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _handleLeaveAction(
    String leaveId,
    String action,
    String responseMessage,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('leaveRequests')
          .doc(leaveId)
          .update({
            'status': action,
            'reviewedByUid': user.uid,
            'reviewerRole': 'faculty advisor',
            'responseMessage': responseMessage,
            'reviewedAt': FieldValue.serverTimestamp(),
          });

      Get.snackbar(
        'Success',
        'Leave request $action successfully',
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );

      _loadLeaveRequests();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update leave request: $e',
        backgroundColor: const Color(0xFFD32F2F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  void _showResponseDialog(Map<String, dynamic> request, String action) {
    final responseController = TextEditingController();
    final status = action == 'approved' ? 'approve' : 'reject';

    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '${action == 'approved' ? 'Approve' : 'Reject'} Leave Request',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Student: ${request['studentName']}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Duration: ${_formatDateRange(request)}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: responseController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Response Message (Optional)',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: 'Enter your response...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF00D9FF)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              _handleLeaveAction(
                request['id'],
                action,
                responseController.text.trim(),
              );
            },
            child: Text(
              action == 'approved' ? 'Approve' : 'Reject',
              style: TextStyle(
                color: action == 'approved' ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
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
      return 'Date error';
    } catch (e) {
      return 'Date error';
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    return DateFormat('MMM dd, yyyy hh:mm a').format(timestamp.toDate());
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Leave Management',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            if (className.isNotEmpty)
              Text(
                className,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
          ],
        ),
      ),
      body: teacherClassId.isEmpty
          ? _buildNoClassAssigned()
          : Column(
              children: [
                _buildFilterChips(),
                Expanded(
                  child: isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF00D9FF),
                          ),
                        )
                      : leaveRequests.isEmpty
                      ? _buildEmptyState()
                      : _buildLeaveRequestsList(),
                ),
              ],
            ),
    );
  }

  Widget _buildNoClassAssigned() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Class Assigned',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You are not assigned as a faculty advisor for any class',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _init,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D9FF),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('Pending', 'pending'),
            const SizedBox(width: 8),
            _buildFilterChip('Approved', 'approved'),
            const SizedBox(width: 8),
            _buildFilterChip('Rejected', 'rejected'),
            const SizedBox(width: 8),
            _buildFilterChip('All', 'all'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          selectedFilter = value;
        });
        _loadLeaveRequests();
      },
      backgroundColor: const Color(0xFF16213E),
      selectedColor: const Color(0xFF00D9FF),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      checkmarkColor: Colors.white,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No ${selectedFilter == 'all' ? '' : selectedFilter} leave requests',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveRequestsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: leaveRequests.length,
      itemBuilder: (context, index) {
        return _buildLeaveRequestCard(leaveRequests[index]);
      },
    );
  }

  Widget _buildLeaveRequestCard(Map<String, dynamic> request) {
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

    final isPending = status == 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(statusIcon, color: statusColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request['studentName'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateRange(request),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
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

          // Duration Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF00D9FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today,
                  color: Color(0xFF00D9FF),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  '${request['totalDays']} day${request['totalDays'] > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: Color(0xFF00D9FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white24),
          const SizedBox(height: 12),

          // Reason
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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

          // Response Message (if exists)
          if (request['responseMessage'] != null &&
              request['responseMessage'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.message, color: Colors.white54, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Response: ',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Expanded(
                  child: Text(
                    request['responseMessage'],
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],

          // Reviewed At (if reviewed)
          if (request['reviewedAt'] != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.white54, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Reviewed: ${_formatTimestamp(request['reviewedAt'])}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ],

          // Action Buttons (only for pending requests)
          if (isPending) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showResponseDialog(request, 'rejected'),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showResponseDialog(request, 'approved'),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
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
