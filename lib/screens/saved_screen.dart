import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import 'listing_details_screen.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  final DatabaseService _dbService = DatabaseService();
  final String _userId = FirebaseAuth.instance.currentUser!.uid;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Saved Items', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _dbService.getUserData(_userId),
        builder: (context, userSnapshot) {
          if (userSnapshot.hasError) return const Center(child: Text('Error loading profile'));
          if (userSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          var userData = userSnapshot.data?.data() as Map<String, dynamic>?;
          List<dynamic> savedIds = userData != null && userData.containsKey('savedListings') 
              ? userData['savedListings'] 
              : [];

          if (savedIds.isEmpty) {
            return const Center(
              child: Text('You have no saved mystery boxes yet.\nTap the heart icon to save some!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16))
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: _dbService.getActiveListings(),
            builder: (context, listingsSnapshot) {
              if (listingsSnapshot.hasError) return const Center(child: Text('Error loading listings'));
              if (listingsSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

              final savedListings = listingsSnapshot.requireData.docs.where((doc) {
                return savedIds.contains(doc.id);
              }).toList();

              if (savedListings.isEmpty) {
                return const Center(child: Text('Your saved items are currently sold out or removed.', style: TextStyle(color: Colors.grey)));
              }

              return ListView.builder(
                padding: const EdgeInsets.only(top: 16, bottom: 32),
                itemCount: savedListings.length,
                itemBuilder: (context, index) {
                  return _buildListingCard(savedListings[index]);
                },
              );
            },
          );
        },
      ),
    );
  }

  // --- UPDATED CARD UI (Matches Home Screen exactly) ---
  Widget _buildListingCard(QueryDocumentSnapshot listing) {
    var dataMap = listing.data() as Map<String, dynamic>;
    String imageUrl = dataMap.containsKey('imageUrl') ? dataMap['imageUrl'] : '';
    
    bool expired = _isExpired(dataMap['createdAt'] as Timestamp?);
    String postedDate = _formatDate(dataMap['createdAt'] as Timestamp?);
    bool isItemHalal = dataMap.containsKey('isHalal') ? dataMap['isHalal'] : false;
    
    // NEW: Pulling the vegan and address data just like the home screen
    bool isItemVegan = dataMap.containsKey('isVegan') ? dataMap['isVegan'] : false;
    String pickupAddress = dataMap.containsKey('pickupAddress') ? (dataMap['pickupAddress'] ?? '') : '';
    String distanceString = ''; // Left empty since distance isn't calculated on the Saved Screen

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16), 
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: expired ? 0.02 : 0.04), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (expired) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This mystery box has expired and cannot be reserved.')));
            return;
          }
          Navigator.push(context, MaterialPageRoute(builder: (context) => ListingDetailsScreen(listing: listing)));
        },
        child: Opacity(
          opacity: expired ? 0.6 : 1.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200, borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                  image: imageUrl.isNotEmpty ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover) : null,
                ),
                child: Stack(
                  children: [
                    if (imageUrl.isEmpty) const Center(child: Icon(Icons.fastfood, size: 50, color: Colors.grey)),
                    // Heart button defaults to true because we are on the saved screen
                    Positioned(
                      top: 12, left: 12,
                      child: GestureDetector(
                        onTap: () => _dbService.toggleSavedListing(_userId, listing.id, true),
                        child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.favorite, color: Colors.red, size: 20)),
                      ),
                    ),
                    Positioned(
                      top: 12, right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                        decoration: BoxDecoration(color: expired ? Colors.grey.shade700 : Colors.red.shade400, borderRadius: BorderRadius.circular(12)), 
                        child: Text(expired ? 'Expired' : '${listing['currentQuantity']} Left', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(listing['title'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: isItemHalal ? Colors.green.shade100 : Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                                    child: Text(isItemHalal ? 'Halal' : 'Non-Halal', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isItemHalal ? Colors.green.shade800 : Colors.red.shade800)),
                                  ),
                                  if (isItemVegan)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)),
                                      child: Text('Vegan', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                                    ),
                                ],
                              ),
                            ],
                          )
                        ),
                      ],
                    ),
                    // --- NEW: readable pickup address added here ---
                    if (pickupAddress.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              pickupAddress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text('Posted on: $postedDate', style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.storefront, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(distanceString.isNotEmpty ? distanceString : 'Vendor Info', style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        const Icon(Icons.access_time, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(listing['pickupWindow'], style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}