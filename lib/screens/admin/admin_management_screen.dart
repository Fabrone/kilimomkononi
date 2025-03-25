import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kilimomkononi/screens/admin/filter_users_screen.dart';
import 'package:logger/logger.dart';
import 'package:kilimomkononi/screens/collection_management_screen.dart';
import 'package:kilimomkononi/screens/pest%20management/admin_pest_management_page.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  final logger = Logger(printer: PrettyPrinter());
  final TextEditingController _uidController = TextEditingController();
  List<String> _allCollections = [];
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _fetchCollections();
    _initializeNotifications();
    _checkForNewMessages();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _checkForNewMessages() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('ManualRequests')
        .where('responded', isEqualTo: false)
        .get();
    final count = snapshot.docs.length;
    if (count > 0) {
      _showNotification(count);
    }
  }

  Future<void> _showNotification(int count) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'new_messages_channel',
      'New Messages',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      0,
      'New Manual Requests',
      'You have $count new manual requests.',
      notificationDetails,
    );
  }

  Future<void> _fetchCollections() async {
    try {
      setState(() {
        _allCollections = [
          'Users',
          'marketdata',
          'fielddata',
          'Admins',
          'admin_logs',
          'diseaseinterventiondata',
          'pestinterventiondata',
          'User_logs',
        ];
      });
    } catch (e) {
      logger.e('Error fetching collections: $e');
    }
  }

  Future<void> _assignRole(String uid, String collection) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
      if (!userDoc.exists) throw 'User not found';
      await FirebaseFirestore.instance.collection(collection).doc(uid).set({'added': true});
      _logActivity('Assigned $collection role to $uid');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${collection.replaceAll('s', '')} role assigned successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error assigning role: $e')));
      }
    }
  }

  Future<void> _deleteUser(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('Users').doc(uid).delete();
      _logActivity('Deleted user $uid');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User deleted from Firestore!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting user: $e')));
      }
    }
  }

  Future<void> _resetPassword(String email) async {
    try {
      if (email.isEmpty) throw 'Email is required';
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _logActivity('Sent password reset for $email');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sending password reset: $e')));
      }
    }
  }

  Future<void> _logActivity(String action) async {
    try {
      await FirebaseFirestore.instance.collection('admin_logs').add({
        'action': action,
        'timestamp': Timestamp.now(),
        'adminUid': FirebaseAuth.instance.currentUser?.uid,
      });
    } catch (e) {
      logger.e('Error logging activity: $e');
    }
  }

  @override
  void dispose() {
    _uidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.grey[200],
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCollectionStats(),
              const SizedBox(height: 20),
              _buildManagementOptions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionStats() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Collection Statistics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (_allCollections.isEmpty)
              const CircularProgressIndicator()
            else
              ..._allCollections.map((collection) => StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection(collection).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }
                      final count = snapshot.data?.docs.length ?? 0;
                      return ListTile(
                        title: Text(collection, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        trailing: Text('$count', style: const TextStyle(fontSize: 16, color: Color.fromARGB(255, 3, 39, 4))),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CollectionManagementScreen(collectionName: collection),
                          ),
                        ),
                      );
                    },
                  )),
          ],
        ),
      ),
    );
  }

  /*Widget _buildManagementOptions() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildOptionCard('Assign Admin', Icons.person_add, () => _showAssignRoleDialog('Admins')),
        _buildOptionCard('Manage Pests', Icons.bug_report, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminPestManagementPage()))),
        _buildOptionCard('Add Price Analyst', Icons.monetization_on, () => _showAssignRoleDialog('PriceAnalysts')),
        _buildOptionCard('Manage Users', Icons.people, () => _showManageUsersScreen()),
        _buildOptionCard('Filter Users', Icons.filter_list, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FilterUsersScreen()))),
        _buildOptionCard('Messages',
          Icons.message,
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MessagesScreen())),
          badge: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('ManualRequests').where('responded', isEqualTo: false).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
              return Positioned(
                right: 0,
                top: 0,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.red,
                  child: Text('${snapshot.data!.docs.length}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOptionCard(String title, IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: onTap == null ? Colors.grey[300] : Colors.white,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 40, color: const Color.fromARGB(255, 3, 39, 4)),
                  const SizedBox(height: 8),
                  Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            if (badge != null) badge,
          ],
        ),
      ),
    );
  }*/
  Widget _buildManagementOptions() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildOptionCard('Assign Admin', Icons.person_add, () => _showAssignRoleDialog('Admins')),
        _buildOptionCard('Manage Pests', Icons.bug_report, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminPestManagementPage()))),
        _buildOptionCard('Add Price Analyst', Icons.monetization_on, () => _showAssignRoleDialog('PriceAnalysts')),
        _buildOptionCard('Manage Users', Icons.people, () => _showManageUsersScreen()),
        _buildOptionCard('Filter Users', Icons.filter_list, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FilterUsersScreen()))),
        _buildOptionCard(
          'Messages',
          Icons.message,
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MessagesScreen())),
          badge: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('ManualRequests').where('responded', isEqualTo: false).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
              return Positioned(
                right: 0,
                top: 0,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.red,
                  child: Text('${snapshot.data!.docs.length}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOptionCard(String title, IconData icon, VoidCallback? onTap, {Widget? badge}) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: onTap == null ? Colors.grey[300] : Colors.white,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 40, color: const Color.fromARGB(255, 3, 39, 4)),
                  const SizedBox(height: 8),
                  Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            if (badge != null) badge, // Use the badge parameter here
          ],
        ),
      ),
    );
  }

  void _showAssignRoleDialog(String collection) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assign ${collection.replaceAll('s', '')} Role', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _uidController,
                decoration: InputDecoration(
                  labelText: 'Enter User UID',
                  hintText: 'e.g., abc123xyz789',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.paste),
              onPressed: () async {
                final clipboardData = await Clipboard.getData('text/plain');
                if (clipboardData != null && clipboardData.text != null) {
                  _uidController.text = clipboardData.text!;
                }
              },
              tooltip: 'Paste UID',
            ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => _showUserListDialog(),
              tooltip: 'Select User',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (_uidController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a UID')));
                return;
              }
              _assignRole(_uidController.text, collection);
              Navigator.pop(context);
              _uidController.clear();
            },
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }

  void _showUserListDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select User', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('Users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Text('No users found.');
              }
              final users = snapshot.data!.docs;
              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index].data() as Map<String, dynamic>;
                  final uid = users[index].id;
                  return ListTile(
                    title: Text(user['fullName'] ?? 'No Name'),
                    subtitle: Text('UID: $uid'),
                    onTap: () {
                      _uidController.text = uid;
                      Navigator.pop(context);
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showManageUsersScreen() {
    String? bulkAction;
    List<String> selectedUids = [];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => Scaffold(
            appBar: AppBar(
              title: const Text('Manage Users', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: const Color.fromARGB(255, 3, 39, 4),
              foregroundColor: Colors.white,
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.menu),
                  onSelected: (value) {
                    setState(() {
                      bulkAction = value;
                      selectedUids.clear();
                    });
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'Bulk Delete', child: Text('Bulk Delete')),
                    const PopupMenuItem(value: 'Bulk Reset Password', child: Text('Bulk Reset Password')),
                  ],
                ),
              ],
            ),
            body: Column(
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('Users').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Total Users: ${snapshot.data!.docs.length}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('Users').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('No users found.'));
                      }

                      final users = snapshot.data!.docs;
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Profile', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('County', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Constituency', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Ward', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Phone Number', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: users.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final uid = doc.id;
                              return DataRow(cells: [
                                DataCell(
                                  data['profileImage'] != null
                                      ? Image.memory(
                                          base64Decode(data['profileImage']),
                                          width: 28,
                                          height: 28,
                                          fit: BoxFit.cover,
                                        )
                                      : const Icon(Icons.person, size: 28),
                                ),
                                DataCell(Text(data['fullName'] ?? 'N/A')),
                                DataCell(Text(data['email'] ?? 'N/A')),
                                DataCell(Text(data['county'] ?? 'N/A')),
                                DataCell(Text(data['constituency'] ?? 'N/A')),
                                DataCell(Text(data['ward'] ?? 'N/A')),
                                DataCell(Text(data['phoneNumber'] ?? 'N/A')),
                                DataCell(Text(data['isDisabled'] == true ? 'Disabled' : 'Active')),
                                DataCell(
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'Delete') {
                                        _confirmDeleteUser(uid);
                                      }
                                      if (value == 'Reset Password') {
                                        _resetPassword(data['email'] ?? '');
                                      }
                                      if (value == 'Copy UID') {
                                        Clipboard.setData(ClipboardData(text: uid));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('UID copied to clipboard!')),
                                        );
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(value: 'Delete', child: Text('Delete User')),
                                      const PopupMenuItem(value: 'Reset Password', child: Text('Reset Password')),
                                      const PopupMenuItem(value: 'Copy UID', child: Text('Copy UID')),
                                    ],
                                    icon: const Icon(Icons.more_vert),
                                  ),
                                ),
                              ]);
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (bulkAction != null && selectedUids.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () async {
                        if (bulkAction == 'Bulk Delete') {
                          for (var uid in selectedUids) {
                            _confirmDeleteUser(uid);
                          }
                        } else if (bulkAction == 'Bulk Reset Password') {
                          for (var uid in selectedUids) {
                            final doc = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
                            await _resetPassword(doc['email'] ?? '');
                          }
                        }
                        setState(() {
                          bulkAction = null;
                          selectedUids.clear();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Execute $bulkAction'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteUser(String uid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this user? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _deleteUser(uid);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  Future<void> _sendResponse(String requestId, String response) async {
    await FirebaseFirestore.instance.collection('ManualRequests').doc(requestId).update({
      'response': response,
      'responded': true,
      'responseTimestamp': Timestamp.now(),
    });
    if (mounted) { 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Response sent!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('ManualRequests').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final messages = snapshot.data!.docs;
          return ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              final data = message.data() as Map<String, dynamic>;
              return ListTile(
                title: Text('${data['fullName']}: ${data['message']}'),
                subtitle: Text(data['responded'] ? 'Responded: ${data['response']}' : 'Pending'),
                trailing: IconButton(
                  icon: const Icon(Icons.reply, color: Color.fromARGB(255, 3, 39, 4)),
                  onPressed: () => _showResponseDialog(message.id),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showResponseDialog(String requestId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Response'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter your response'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _sendResponse(requestId, controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}