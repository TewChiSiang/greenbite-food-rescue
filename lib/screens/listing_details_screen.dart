import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../services/database_service.dart';

class ListingDetailsScreen extends StatefulWidget {
  final QueryDocumentSnapshot listing;

  const ListingDetailsScreen({super.key, required this.listing});

  @override
  State<ListingDetailsScreen> createState() => _ListingDetailsScreenState();
}

class _ListingDetailsScreenState extends State<ListingDetailsScreen> {
  int _orderQuantity = 1;
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = false;

  // --- HELPER FUNCTIONS ---
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown Date';
    DateTime date = timestamp.toDate();
    return "${date.day}/${date.month}/${date.year}";
  }

  bool _isExpired(Timestamp? timestamp) {
    if (timestamp == null) return true; 
    DateTime itemDate = timestamp.toDate();
    DateTime now = DateTime.now();
    return !(itemDate.year == now.year && itemDate.month == now.month && itemDate.day == now.day);
  }

  // --- open the pickup location in Google Maps ---
  Future<void> _openInMaps(double? lat, double? lng, String address) async {
    final String query = (lat != null && lng != null)
        ? '$lat,$lng'
        : Uri.encodeComponent(address);
    final Uri mapsUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');

    if (await canLaunchUrl(mapsUri)) {
      await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Maps')),
      );
    }
  }

  void _handleReservation() async {
    setState(() => _isLoading = true);

    String consumerId = FirebaseAuth.instance.currentUser!.uid;

    var dataMap = widget.listing.data() as Map<String, dynamic>;
    String imageUrl = dataMap.containsKey('imageUrl') ? dataMap['imageUrl'] : '';

    bool success = await _dbService.reserveListing(
      listingId: widget.listing.id,
      consumerId: consumerId,
      vendorId: widget.listing['vendorID'],
      quantityToReserve: _orderQuantity,
      listingTitle: widget.listing['title'],
      pickupWindow: widget.listing['pickupWindow'],
      imageUrl: imageUrl, 
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text('Reservation Successful!')));
      Navigator.pop(context); 
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.red, content: Text('Failed to reserve. Item might be sold out.')));
    }
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.green, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQtyButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int maxQty = widget.listing['currentQuantity'];

    var dataMap = widget.listing.data() as Map<String, dynamic>;
    String imageUrl = dataMap.containsKey('imageUrl') ? dataMap['imageUrl'] : '';
    bool isItemHalal = dataMap.containsKey('isHalal') ? dataMap['isHalal'] : false;
    bool isItemVegan = dataMap.containsKey('isVegan') ? dataMap['isVegan'] : false;
    bool expired = _isExpired(dataMap['createdAt'] as Timestamp?);
    String postedDate = _formatDate(dataMap['createdAt'] as Timestamp?);

    String pickupAddress = dataMap.containsKey('pickupAddress') ? (dataMap['pickupAddress'] ?? '') : '';
    double? latitude = dataMap.containsKey('latitude') ? (dataMap['latitude'] as num?)?.toDouble() : null;
    double? longitude = dataMap.containsKey('longitude') ? (dataMap['longitude'] as num?)?.toDouble() : null;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            backgroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.black),
            flexibleSpace: FlexibleSpaceBar(
              background: imageUrl.isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Center(child: Icon(Icons.fastfood, size: 80, color: Colors.grey)))
                  : const Center(child: Icon(Icons.fastfood, size: 80, color: Colors.grey)),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(20)),
                          child: Text(widget.listing['category'], style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: isItemHalal ? Colors.green.shade100 : Colors.red.shade100, borderRadius: BorderRadius.circular(20)),
                          child: Text(isItemHalal ? 'Halal' : 'Non-Halal', style: TextStyle(color: isItemHalal ? Colors.green.shade800 : Colors.red.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        if (isItemVegan)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(20)),
                            child: Text('Vegan', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    Text(widget.listing['title'], style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    // --- NEW: VENDOR DETAILS & RATING ---
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('Users').doc(widget.listing['vendorID']).get(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox(height: 16); 
                        
                        var vendorData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                        String vendorName = vendorData['businessName'] ?? 'Unknown Vendor';
                        double averageRating = (vendorData['averageRating'] ?? 0).toDouble();
                        int ratingCount = (vendorData['ratingCount'] ?? 0).toInt();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(Icons.storefront, size: 20, color: Colors.deepOrange),
                              const SizedBox(width: 6),
                              Text(
                                vendorName,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.orange, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      ratingCount > 0 
                                          ? '${averageRating.toStringAsFixed(1)} ($ratingCount)' 
                                          : 'New',
                                      style: TextStyle(
                                        color: Colors.orange.shade800, 
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 12
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    // ------------------------------------
                    
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text('Posted on: $postedDate', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pickup Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          _buildInfoRow(icon: Icons.access_time, label: 'Pickup Window', value: widget.listing['pickupWindow']),
                          if (pickupAddress.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildInfoRow(icon: Icons.location_on, label: 'Pickup Address', value: pickupAddress),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _openInMaps(latitude, longitude, pickupAddress),
                                icon: const Icon(Icons.directions, size: 18),
                                label: const Text('Get Directions'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.green,
                                  side: const BorderSide(color: Colors.green),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          _buildInfoRow(icon: Icons.shopping_bag_outlined, label: 'Available', value: '$maxQty boxes left'),
                        ],
                      ),
                    ),
                    
                    if (!expired) ...[
                      const SizedBox(height: 24),
                      const Text('Select Quantity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildQtyButton(
                              icon: Icons.remove_rounded,
                              color: Colors.red,
                              onTap: () { if (_orderQuantity > 1) setState(() => _orderQuantity--); },
                            ),
                            Text('$_orderQuantity', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                            _buildQtyButton(
                              icon: Icons.add_rounded,
                              color: Colors.green,
                              onTap: () { if (_orderQuantity < maxQty) setState(() => _orderQuantity++); },
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text('This listing has expired and is no longer available.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 40), 
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
      
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))]),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: expired || _isLoading ? null : _handleReservation, 
              style: ElevatedButton.styleFrom(
                backgroundColor: expired ? Colors.grey.shade400 : Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(expired ? 'Expired' : 'Reserve Now', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}