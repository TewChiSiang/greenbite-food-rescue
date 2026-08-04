import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import 'add_listing_screen.dart';
import 'edit_listing_screen.dart';
import 'vendor_profile_screen.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'incoming_orders_screen.dart';
import 'vendor_analytics_screen.dart'; 

class VendorDashboard extends StatefulWidget {
  const VendorDashboard({super.key});

  @override
  State<VendorDashboard> createState() => _VendorDashboardState();
}

class _VendorDashboardState extends State<VendorDashboard> {
  final DatabaseService _dbService = DatabaseService();
  final String _vendorId = FirebaseAuth.instance.currentUser!.uid;

  // Navigation State
  int _selectedIndex = 0;

  void _confirmDelete(String listingId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Listing?'),
        content: const Text(
          'Are you sure you want to permanently delete this mystery box?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _dbService.deleteListing(listingId);
              if (!mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Listing Deleted')));
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _dbService.getUserData(_vendorId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data?.data() != null) {
          var userData = snapshot.data!.data() as Map<String, dynamic>;
          String status = userData.containsKey('accountStatus')
              ? userData['accountStatus']
              : 'Pending';

          if (status == 'Pending') {
            return Scaffold(
              backgroundColor: Colors.white,
              body: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.admin_panel_settings,
                          size: 80,
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Under Review',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Your business application has been received. Our admin team is currently verifying your SSM details. You will be able to post listings once approved.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 40),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await AuthService().signOut();
                            if (!context.mounted) return;
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                              (route) => false,
                            );
                          },
                          icon: const Icon(Icons.logout, color: Colors.red),
                          label: const Text(
                            'Log Out',
                            style: TextStyle(color: Colors.red),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
        }

        final List<Widget> screens = [
          _buildDashboardFeed(), 
          const IncomingOrdersScreen(), 
          const VendorAnalyticsScreen(), 
          const VendorProfileScreen(), 
        ];

        return Scaffold(
          backgroundColor: Colors.grey[50],
          body: screens[_selectedIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            selectedItemColor: Colors.deepOrange,
            unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard),
                label: 'Dash',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long),
                label: 'Orders',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.eco), // Changed from bar_chart to eco
                label: 'Impact',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.store),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDashboardFeed() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Dashboard',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: _dbService.getVendorOrders(_vendorId),
              builder: (context, snapshot) {
                int ordersToday = 0;
                int itemsDonatedToday = 0;

                if (snapshot.hasData) {
                  DateTime today = DateTime.now();
                  for (var doc in snapshot.data!.docs) {
                    if (doc['createdAt'] != null) {
                      DateTime orderDate = (doc['createdAt'] as Timestamp).toDate();
                      if (orderDate.year == today.year &&
                          orderDate.month == today.month &&
                          orderDate.day == today.day) {
                        ordersToday++;
                        var data = doc.data() as Map<String, dynamic>;
                        itemsDonatedToday += data.containsKey('quantity') ? (data['quantity'] as num).toInt() : 1;
                      }
                    }
                  }
                }

                return Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Orders Today',
                        '$ordersToday',
                        Colors.orange.withValues(alpha: 0.1),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Boxes Donated',
                        '$itemsDonatedToday',
                        Colors.green.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Active Listings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddListingScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    '+ Add New',
                    style: TextStyle(
                      color: Colors.deepOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _dbService.getVendorListings(_vendorId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text('Error loading data');
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final data = snapshot.requireData;
                  if (data.size == 0) {
                    return const Center(
                      child: Text(
                        "No active listings. Tap '+ Add New'.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: data.size,
                    itemBuilder: (context, index) {
                      var listing = data.docs[index];
                      var dataMap = listing.data() as Map<String, dynamic>;
                      String imageUrl = dataMap.containsKey('imageUrl')
                          ? dataMap['imageUrl']
                          : '';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imageUrl.isNotEmpty
                                  ? imageUrl
                                  : 'https://images.unsplash.com/photo-1495147466023-e6a925cd9294?q=80&w=200&auto=format&fit=crop', 
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          ),
                          title: Text(
                            listing['title'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('Pickup: ${listing['pickupWindow']}'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: Colors.blue,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          EditListingScreen(listing: listing),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () => _confirmDelete(listing.id),
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
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.deepOrange,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }
}