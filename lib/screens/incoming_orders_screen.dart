import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import 'qr_scanner_screen.dart';

class IncomingOrdersScreen extends StatefulWidget {
  const IncomingOrdersScreen({super.key});

  @override
  State<IncomingOrdersScreen> createState() => _IncomingOrdersScreenState();
}

class _IncomingOrdersScreenState extends State<IncomingOrdersScreen> {
  final DatabaseService _dbService = DatabaseService();
  final String _vendorId = FirebaseAuth.instance.currentUser!.uid;

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    DateTime date = timestamp.toDate();
    return "${date.day}/${date.month}/${date.year}";
  }

  // Function to handle the status update
  void _completeOrder(String orderId) async {
    bool success = await _dbService.updateOrderStatus(orderId, 'Completed');
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.green, content: Text('Order marked as Completed!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.red, content: Text('Failed to update order.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Incoming Orders', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 1,
          centerTitle: true,
          bottom: const TabBar(
            labelColor: Colors.deepOrange,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.deepOrange,
            tabs: [
              Tab(text: 'To Prepare'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // 1. Open the scanner screen and wait for a result
          final scannedOrderId = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const QRScannerScreen()),
          );

          // 2. If a QR code was successfully scanned, mark it complete!
          if (scannedOrderId != null && scannedOrderId is String && mounted) {
            _completeOrder(scannedOrderId);
          }
        },
        backgroundColor: Colors.deepOrange,
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: const Text('Scan QR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _dbService.getVendorOrders(_vendorId),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Center(child: Text('Error loading orders'));
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

            var rawDocs = snapshot.requireData.docs;

            // Sort newest first
            rawDocs.sort((a, b) {
              Timestamp? timeA = a['createdAt'] as Timestamp?;
              Timestamp? timeB = b['createdAt'] as Timestamp?;
              if (timeA == null || timeB == null) return 0;
              return timeB.compareTo(timeA); 
            });

            // Split by status
            var pendingOrders = rawDocs.where((doc) => doc['status'] == 'Pending').toList();
            var completedOrders = rawDocs.where((doc) => doc['status'] == 'Completed').toList();

            return TabBarView(
              children: [
                // TAB 1: TO PREPARE (Pending)
                pendingOrders.isEmpty
                    ? const Center(child: Text('No incoming orders right now.', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: pendingOrders.length,
                        itemBuilder: (context, index) => _buildOrderCard(pendingOrders[index], isActive: true),
                      ),

                // TAB 2: COMPLETED
                completedOrders.isEmpty
                    ? const Center(child: Text('No completed orders yet.', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: completedOrders.length,
                        itemBuilder: (context, index) => _buildOrderCard(completedOrders[index], isActive: false),
                      ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrderCard(QueryDocumentSnapshot order, {required bool isActive}) {
    int qty = order['quantity'];
    String orderIdText = order.id.substring(0, 8).toUpperCase();

    var dataMap = order.data() as Map<String, dynamic>;
    String imageUrl = dataMap.containsKey('imageUrl') ? dataMap['imageUrl'] : 'https://images.unsplash.com/photo-1495147466023-e6a925cd9294?q=80&w=600&auto=format&fit=crop';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isActive ? Colors.orange.shade200 : Colors.grey.shade300, width: isActive ? 2 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Order #$orderIdText', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              Text(_formatDate(order['createdAt'] as Timestamp?), style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const Divider(height: 24),
          
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        height: 60,
                        width: 60,
                        fit: BoxFit.cover,
                        // 1. If the link is broken, show the icon
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 60, width: 60,
                            color: Colors.orange.shade100,
                            child: const Icon(Icons.fastfood, color: Colors.deepOrange),
                          );
                        },
                      )
                    // 2. If there is no image URL, show the icon
                    : Container(
                        height: 60, width: 60,
                        color: Colors.orange.shade100,
                        child: const Icon(Icons.fastfood, color: Colors.deepOrange),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order['listingTitle'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Qty: $qty', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                const Icon(Icons.directions_run, size: 16, color: Colors.deepOrange),
                const SizedBox(width: 8),
                Expanded(child: Text('Expected Pickup: ${order['pickupWindow']}', style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600))),
              ],
            ),
          ),

          // Action Button for Active Orders
          if (isActive) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _completeOrder(order.id),
                icon: const Icon(Icons.check_circle, color: Colors.white),
                label: const Text('Mark as Picked Up', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }
}