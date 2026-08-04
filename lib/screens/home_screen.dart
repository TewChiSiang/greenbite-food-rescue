import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../services/database_service.dart';
import 'profile_screen.dart';
import 'listing_details_screen.dart';
import 'saved_screen.dart';
import 'my_orders_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _dbService = DatabaseService();
  final String _userId = FirebaseAuth.instance.currentUser!.uid; 
  
  int _selectedIndex = 0; 
  int _selectedCategoryIndex = 0; 
  String _searchQuery = ''; 
  bool _showHalalOnly = false;
  bool _showVeganOnly = false;
  
  // --- GEOLOCATION VARIABLES ---
  Position? _currentPosition;
  bool _sortByNearest = false;

  final TextEditingController _searchController = TextEditingController();
  final List<String> _categories = ['All', 'Meals', 'Pastries', 'Groceries'];

  @override
  void initState() {
    super.initState();
    _determinePosition(); // Fetch location when app opens
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- GET USER LOCATION ---
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return; // Location services are not enabled

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return; // Permissions denied
    }
    
    if (permission == LocationPermission.deniedForever) return;

    // Get actual coordinates
    Position position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() => _currentPosition = position);
    }
  }

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
    final List<Widget> screens = [
      _buildDiscoverFeed(), 
      const SavedScreen(), 
      const MyOrdersScreen(), 
      const ProfileScreen(), 
    ];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: screens[_selectedIndex], 
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.green, 
        unselectedItemColor: Colors.grey, 
        showUnselectedLabels: true, 
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Saved'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildDiscoverFeed() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _dbService.getUserData(_userId),
      builder: (context, userSnapshot) {
        
        List<dynamic> savedIds = [];
        if (userSnapshot.hasData && userSnapshot.data?.data() != null) {
          var userData = userSnapshot.data!.data() as Map<String, dynamic>;
          savedIds = userData.containsKey('savedListings') ? userData['savedListings'] : [];
        }

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.white, 
              pinned: true, 
              expandedHeight: 140.0, 
              elevation: 1,
              flexibleSpace: const FlexibleSpaceBar(
                titlePadding: EdgeInsets.only(left: 20, bottom: 16),
                title: Text('Discover', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24)),
              ),
            ),
            
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Search for food or vendors...', 
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        filled: true, fillColor: Colors.white, 
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal, 
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          bool isSelected = _selectedCategoryIndex == index;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedCategoryIndex = index),
                            child: Container(
                              margin: const EdgeInsets.only(right: 10), 
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.green : Colors.white, 
                                borderRadius: BorderRadius.circular(20), 
                                border: Border.all(color: isSelected ? Colors.green : Colors.grey.shade300)
                              ),
                              child: Center(child: Text(_categories[index], style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade700, fontWeight: FontWeight.bold))),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    
                    // --- FILTERS: chip-style, matches the category chips above ---
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildFilterChip(
                          label: 'Nearest',
                          icon: Icons.near_me_rounded,
                          selected: _sortByNearest,
                          onTap: () {
                            if (!_sortByNearest && _currentPosition == null) {
                              _determinePosition(); // Request location if they turn it on
                            }
                            setState(() => _sortByNearest = !_sortByNearest);
                          },
                        ),
                        _buildFilterChip(
                          label: 'Halal Only',
                          icon: Icons.check_circle_rounded,
                          selected: _showHalalOnly,
                          onTap: () => setState(() => _showHalalOnly = !_showHalalOnly),
                        ),
                        _buildFilterChip(
                          label: 'Vegan Only',
                          icon: Icons.eco_rounded,
                          selected: _showVeganOnly,
                          onTap: () => setState(() => _showVeganOnly = !_showVeganOnly),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            StreamBuilder<QuerySnapshot>(
              stream: _dbService.getActiveListings(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const SliverToBoxAdapter(child: Center(child: Text('Error loading data')));
                if (snapshot.connectionState == ConnectionState.waiting) return const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())));

                var availableListings = snapshot.requireData.docs.where((doc) {
                  Map<String, dynamic> docData = doc.data() as Map<String, dynamic>;
                  bool hasStock = docData['currentQuantity'] > 0;
                  bool matchesSearch = docData['title'].toString().toLowerCase().contains(_searchQuery);
                  bool matchesCategory = _selectedCategoryIndex == 0 || (docData['category'] == _categories[_selectedCategoryIndex]);
                  bool isHalal = docData.containsKey('isHalal') ? docData['isHalal'] : false;
                  bool isVegan = docData.containsKey('isVegan') ? docData['isVegan'] : false;
                  
                  if (_showHalalOnly && !isHalal) return false;
                  if (_showVeganOnly && !isVegan) return false;
                  return hasStock && matchesSearch && matchesCategory;
                }).toList();

                // --- DISTANCE CALCULATION & SORTING ---
                Map<String, double> distances = {};
                for (var doc in availableListings) {
                  var data = doc.data() as Map<String, dynamic>;
                  // Calculate distance in meters if both user and listing have coordinates
                  if (_currentPosition != null && data.containsKey('latitude') && data.containsKey('longitude')) {
                    double distInMeters = Geolocator.distanceBetween(
                      _currentPosition!.latitude, 
                      _currentPosition!.longitude, 
                      data['latitude'], 
                      data['longitude']
                    );
                    distances[doc.id] = distInMeters;
                  }
                }

                if (_sortByNearest && _currentPosition != null) {
                  availableListings.sort((a, b) {
                    // Items without location go to the bottom (Infinity)
                    double distA = distances[a.id] ?? double.infinity;
                    double distB = distances[b.id] ?? double.infinity;
                    return distA.compareTo(distB);
                  });
                }

                if (availableListings.isEmpty) return const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40.0), child: Center(child: Text('No mystery boxes right now.', style: TextStyle(color: Colors.grey)))));

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      var listing = availableListings[index];
                      bool isSaved = savedIds.contains(listing.id);
                      double? dist = distances[listing.id];
                      return _buildListingCard(listing, isSaved, dist); 
                    },
                    childCount: availableListings.length,
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        );
      }
    );
  }

  // --- FILTER CHIP: toggleable pill, fills solid green when active ---
  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.green : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.green : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- CARD SHOWING DISTANCE + REAL PICKUP ADDRESS ---
  Widget _buildListingCard(QueryDocumentSnapshot listing, bool isSaved, double? distanceInMeters) {
    var dataMap = listing.data() as Map<String, dynamic>;
    String imageUrl = dataMap.containsKey('imageUrl') ? dataMap['imageUrl'] : '';
    bool expired = _isExpired(dataMap['createdAt'] as Timestamp?);
    String postedDate = _formatDate(dataMap['createdAt'] as Timestamp?);
    bool isItemHalal = dataMap.containsKey('isHalal') ? dataMap['isHalal'] : false;
    bool isItemVegan = dataMap.containsKey('isVegan') ? dataMap['isVegan'] : false;
    // the human-readable address the vendor set (GPS-detected or manually typed)
    String pickupAddress = dataMap.containsKey('pickupAddress') ? (dataMap['pickupAddress'] ?? '') : '';

    // Convert meters to Kilometers (e.g., 2500m -> 2.5 km)
    String distanceString = '';
    if (distanceInMeters != null) {
      double km = distanceInMeters / 1000;
      distanceString = "${km.toStringAsFixed(1)} km";
    }

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
                    Positioned(
                      top: 12, left: 12,
                      child: GestureDetector(
                        onTap: () => _dbService.toggleSavedListing(_userId, listing.id, isSaved),
                        child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(isSaved ? Icons.favorite : Icons.favorite_border, color: isSaved ? Colors.red : Colors.grey, size: 20)),
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
                    // --- readable pickup address, so consumers know where to actually go ---
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
                        
                        // --- DISPLAY DISTANCE IF AVAILABLE ---
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