import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  final AuthService _authService = AuthService();

  void _handleLogout() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  final List<Widget> _adminPages = [
    const VendorApprovalsView(), 
    const UserManagementView(),
    const FeedbackInboxView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: Colors.white,
            extended: MediaQuery.of(context).size.width > 800, 
            elevation: 2,
            minExtendedWidth: 250,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Column(
                children: [
                  Icon(Icons.admin_panel_settings, size: 40, color: Colors.green),
                  SizedBox(height: 8),
                  Text('Admin Panel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: IconButton(
                    icon: const Icon(Icons.logout, color: Colors.red),
                    onPressed: _handleLogout,
                    tooltip: 'Log Out',
                  ),
                ),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.verified_user_outlined),
                selectedIcon: Icon(Icons.verified_user),
                label: Text('Vendor Approvals'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('User Management'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.forum_outlined),
                selectedIcon: Icon(Icons.forum),
                label: Text('Feedback Inbox'),
              ),
            ],
            selectedIconTheme: const IconThemeData(color: Colors.green),
            selectedLabelTextStyle: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
          
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(32.0),
              child: _adminPages[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 1. VENDOR APPROVALS VIEW
// ==========================================
class VendorApprovalsView extends StatelessWidget {
  const VendorApprovalsView({super.key});

  @override
  Widget build(BuildContext context) {
    final DatabaseService dbService = DatabaseService();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pending Vendor Approvals', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: dbService.getAllVendors(), // Get all vendors
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No vendor accounts found.', style: TextStyle(color: Colors.grey)));
              }

              // Safely filter for pending vendors locally
              var pendingVendors = snapshot.data!.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                String status = data.containsKey('accountStatus') ? data['accountStatus'] : 'Pending';
                return status == 'Pending'; // Only show if Pending
              }).toList();

              if (pendingVendors.isEmpty) {
                return const Center(child: Text('No pending vendor approvals.', style: TextStyle(color: Colors.grey)));
              }

              return ListView.builder(
                itemCount: pendingVendors.length,
                itemBuilder: (context, index) {
                  var vendor = pendingVendors[index];
                  var data = vendor.data() as Map<String, dynamic>;
                  String businessName = data.containsKey('businessName') ? data['businessName'] : 'Unknown Business';
                  String email = data.containsKey('email') ? data['email'] : 'No Email';
                  String ssm = data.containsKey('ssmNumber') ? data['ssmNumber'] : 'N/A';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.store, color: Colors.white)),
                      title: Text(businessName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Email: $email\nSSM: $ssm"),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () => dbService.updateUserStatus(vendor.id, 'Rejected'),
                            child: const Text('Reject', style: TextStyle(color: Colors.white)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            onPressed: () => dbService.updateUserStatus(vendor.id, 'Active'),
                            child: const Text('Approve', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 2. USER MANAGEMENT VIEW (UPDATED)
// ==========================================
class UserManagementView extends StatefulWidget {
  const UserManagementView({super.key});

  @override
  State<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends State<UserManagementView> {
  // Toggle state: 'consumer' or 'vendor'
  String _selectedRole = 'consumer';

  void _confirmDeleteUser(String uid, String userName, DatabaseService dbService) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Consumer', style: TextStyle(color: Colors.red)),
        content: Text('Are you sure you want to permanently delete $userName? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogContext); // Close dialog
              await dbService.deleteUserDocument(uid);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Consumer deleted successfully.'), backgroundColor: Colors.green),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DatabaseService dbService = DatabaseService();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('User Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        
        // --- ROLE SELECTION TOGGLE ---
        Row(
          children: [
            ChoiceChip(
              label: const Text('Consumers', style: TextStyle(fontWeight: FontWeight.bold)),
              selected: _selectedRole == 'consumer',
              onSelected: (selected) {
                if (selected) setState(() => _selectedRole = 'consumer');
              },
              selectedColor: Colors.blue.shade100,
              checkmarkColor: Colors.blue,
            ),
            const SizedBox(width: 12),
            ChoiceChip(
              label: const Text('Vendors', style: TextStyle(fontWeight: FontWeight.bold)),
              selected: _selectedRole == 'vendor',
              onSelected: (selected) {
                if (selected) setState(() => _selectedRole = 'vendor');
              },
              selectedColor: Colors.orange.shade100,
              checkmarkColor: Colors.orange,
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // --- USER LIST ---
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: dbService.getAllUsers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No users found.', style: TextStyle(color: Colors.grey)));
              }

              // Safely filter the list based on the selected role chip
              var filteredUsers = snapshot.data!.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                String role = data.containsKey('role') ? data['role'].toString().toLowerCase() : '';
                return role == _selectedRole;
              }).toList();

              if (filteredUsers.isEmpty) {
                return Center(
                  child: Text('No ${_selectedRole}s found.', style: const TextStyle(color: Colors.grey))
                );
              }

              return ListView.builder(
                itemCount: filteredUsers.length,
                itemBuilder: (context, index) {
                  var user = filteredUsers[index];
                  var data = user.data() as Map<String, dynamic>;
                  
                  String status = data.containsKey('accountStatus') ? data['accountStatus'] : 'Active';
                  String email = data.containsKey('email') ? data['email'] : 'No Email';
                  
                  // Determine display name based on role
                  String displayName = 'User';
                  if (_selectedRole == 'vendor' && data.containsKey('businessName')) {
                    displayName = data['businessName'];
                  } else if (data.containsKey('name')) {
                    displayName = data['name'];
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _selectedRole == 'vendor' ? Colors.orange : Colors.blue,
                        child: Icon(_selectedRole == 'vendor' ? Icons.store : Icons.person, color: Colors.white),
                      ),
                      title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Status: $status\nEmail: $email"),
                      isThreeLine: true,
                      
                      // --- CONDITIONAL BUTTONS BASED ON ROLE ---
                      trailing: _selectedRole == 'consumer' 
                          // CONSUMER: Show Delete Button
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 28),
                              onPressed: () => _confirmDeleteUser(user.id, displayName, dbService),
                              tooltip: 'Delete Consumer',
                            )
                          // VENDOR: Show Active/Pending Toggle
                          : (status == 'Active'
                              ? ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                  onPressed: () => dbService.updateUserStatus(user.id, 'Pending'),
                                  child: const Text('Set Pending', style: TextStyle(color: Colors.white)),
                                )
                              : ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  onPressed: () => dbService.updateUserStatus(user.id, 'Active'),
                                  child: const Text('Set Active', style: TextStyle(color: Colors.white)),
                                )),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 3. FEEDBACK INBOX VIEW
// ==========================================
class FeedbackInboxView extends StatelessWidget {
  const FeedbackInboxView({super.key});

  @override
  Widget build(BuildContext context) {
    final DatabaseService dbService = DatabaseService();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Feedback Inbox', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: dbService.getFeedbackTickets(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No feedback tickets found.', style: TextStyle(color: Colors.grey)));
              }

              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var feedback = snapshot.data!.docs[index];
                  var data = feedback.data() as Map<String, dynamic>;
                  String status = data.containsKey('status') ? data['status'] : 'Open';
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Icon(
                        Icons.message, 
                        color: status == 'Resolved' ? Colors.green : Colors.blue,
                        size: 32,
                      ),
                      title: Text(data['reportType'] ?? 'General Feedback', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("From: ${data['email'] ?? 'Unknown'}\nMessage: ${data['description'] ?? ''}"),
                      isThreeLine: true,
                      trailing: status == 'Resolved'
                          ? const Chip(
                              label: Text('Resolved', style: TextStyle(color: Colors.white)),
                              backgroundColor: Colors.green,
                            )
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                              onPressed: () => dbService.updateFeedbackStatus(feedback.id, 'Resolved'),
                              child: const Text('Mark Resolved', style: TextStyle(color: Colors.white)),
                            ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}