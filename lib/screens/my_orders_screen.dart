import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  final DatabaseService _dbService = DatabaseService();
  final String _userId = FirebaseAuth.instance.currentUser!.uid;

  // Formatting timestamp to a readable date (e.g. "Oct 12, 2023")
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    DateTime date = timestamp.toDate();
    return "${date.day}/${date.month}/${date.year}";
  }

  // Placeholder for the QR Code feature
  void _showPickupCodeDialog(String orderId, String pickupWindow) {
    // --- SAFETY CHECK FOR SHORT IDs ---
    String displayId = orderId.length >= 8
        ? orderId.substring(0, 8).toUpperCase()
        : orderId.toUpperCase();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Pickup Code', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Show this to the vendor to collect your food.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // --- STRICT SIZING FOR THE QR CODE ---
            SizedBox(
              height: 200,
              width: 200,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Center(
                  child: QrImageView(
                    data: orderId,
                    version: QrVersions.auto,
                    size: 160.0,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            Text(
              'Pickup Time: $pickupWindow',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Order ID: $displayId',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- NEW: RATING DIALOG FUNCTION ---
  void _showRatingDialog(String orderId, String vendorId) {
    int selectedRating = 5;
    TextEditingController commentController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Rate Vendor',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'How was your experience?',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),

                // STAR RATING ROW
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < selectedRating ? Icons.star : Icons.star_border,
                        color: Colors.orange,
                        size: 32,
                      ),
                      onPressed: () {
                        setStateDialog(() {
                          selectedRating = index + 1;
                        });
                      },
                    );
                  }),
                ),

                const SizedBox(height: 16),

                // COMMENT FIELD
                TextField(
                  controller: commentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Leave a comment (optional)...',
                    hintStyle: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.green),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setStateDialog(() => isSubmitting = true);
                        try {
                          // USE THE NEW DATABASE SERVICE METHOD!
                          await _dbService.submitReview(
                            orderId: orderId,
                            vendorId: vendorId,
                            consumerId: _userId,
                            rating: selectedRating,
                            comment: commentController.text.trim(),
                          );

                          if (!context.mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Rating submitted!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          setStateDialog(() => isSubmitting = false);
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Submit',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Two tabs: Active and History
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text(
            'My Orders',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          elevation: 1,
          centerTitle: true,
          bottom: const TabBar(
            labelColor: Colors.green,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.green,
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _dbService.getConsumerOrders(_userId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Error loading orders'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            var rawDocs = snapshot.requireData.docs;

            // Sort the documents locally by newest first
            rawDocs.sort((a, b) {
              Timestamp? timeA = a['createdAt'] as Timestamp?;
              Timestamp? timeB = b['createdAt'] as Timestamp?;
              if (timeA == null || timeB == null) return 0;
              return timeB.compareTo(timeA); // Descending order
            });

            // Split into two lists based on status
            var activeOrders = rawDocs
                .where(
                  (doc) =>
                      doc['status'] == 'Pending' ||
                      doc['status'] == 'Pending Pick-up',
                )
                .toList();
            var pastOrders = rawDocs
                .where(
                  (doc) =>
                      doc['status'] != 'Pending' &&
                      doc['status'] != 'Pending Pick-up',
                )
                .toList();

            return TabBarView(
              children: [
                // TAB 1: ACTIVE ORDERS
                activeOrders.isEmpty
                    ? const Center(
                        child: Text(
                          'No active orders right now.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: activeOrders.length,
                        itemBuilder: (context, index) => _buildOrderCard(
                          activeOrders[index],
                          isActive: true,
                        ),
                      ),

                // TAB 2: PAST ORDERS
                pastOrders.isEmpty
                    ? const Center(
                        child: Text(
                          'No past orders yet.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: pastOrders.length,
                        itemBuilder: (context, index) =>
                            _buildOrderCard(pastOrders[index], isActive: false),
                      ),
              ],
            );
          },
        ),
      ),
    );
  }

  // The UI for an individual Order Card
  Widget _buildOrderCard(
    QueryDocumentSnapshot order, {
    required bool isActive,
  }) {
    var dataMap = order.data() as Map<String, dynamic>;

    // Fallbacks for data to prevent null errors
    int qty = dataMap.containsKey('quantity') ? dataMap['quantity'] : 1;
    String imageUrl = dataMap.containsKey('imageUrl')
        ? dataMap['imageUrl']
        : '';
    String vendorId = dataMap.containsKey('vendorID')
        ? dataMap['vendorID']
        : (dataMap.containsKey('vendorId') ? dataMap['vendorId'] : '');
    String listingTitle = dataMap.containsKey('listingTitle')
        ? dataMap['listingTitle']
        : (dataMap.containsKey('title') ? dataMap['title'] : 'Mystery Box');

    // Rating variables
    bool isRated = dataMap.containsKey('isRated') ? dataMap['isRated'] : false;
    int ratingGiven = dataMap.containsKey('rating') ? dataMap['rating'] : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? Colors.green.shade200 : Colors.grey.shade300,
          width: isActive ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Date and Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(order['createdAt'] as Timestamp?),
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isActive ? Colors.green.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  order['status'].toUpperCase(),
                  style: TextStyle(
                    color: isActive ? Colors.green : Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Body: Order Details
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
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 60,
                            width: 60,
                            color: Colors.orange.shade100,
                            child: const Icon(
                              Icons.fastfood,
                              color: Colors.deepOrange,
                            ),
                          );
                        },
                      )
                    : Container(
                        height: 60,
                        width: 60,
                        color: Colors.orange.shade100,
                        child: const Icon(
                          Icons.fastfood,
                          color: Colors.deepOrange,
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listingTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Qty: $qty',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ],
          ),

          // Footer for ACTIVE Orders (QR Code)
          if (isActive) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pickup: ${order['pickupWindow']}',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    _showPickupCodeDialog(order.id, order['pickupWindow']),
                icon: const Icon(Icons.qr_code, color: Colors.white),
                label: const Text(
                  'Show Pickup Code',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],

          // --- NEW: Footer for HISTORY Orders (Rating) ---
          if (!isActive) ...[
            const SizedBox(height: 16),
            if (isRated)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star, color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'You rated this $ratingGiven stars',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showRatingDialog(order.id, vendorId),
                  icon: const Icon(Icons.star_outline, color: Colors.orange),
                  label: const Text(
                    'Rate Vendor',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Colors.orange),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
