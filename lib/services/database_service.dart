import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Function to add a new surplus food listing
  Future<bool> addListing(
    String vendorId,
    String title,
    String category,
    int qty,
    String pickupWindow,
    String imageUrl,
    bool isHalal,
    bool isVegan,
    double lat,
    double lng,
    String pickupAddress,
  ) async {
    try {
      await _firestore.collection('Listings').add({
        'vendorID': vendorId,
        'title': title,
        'category': category,
        'initialQuantity': qty,
        'currentQuantity': qty,
        'pickupWindow': pickupWindow,
        'imageUrl': imageUrl,
        'isHalal': isHalal,
        'isVegan': isVegan,
        'latitude': lat,
        'longitude': lng,
        'pickupAddress': pickupAddress,
        'status': 'Active',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint("Error adding listing: $e");
      return false;
    }
  }

  // --- VENDOR MANAGEMENT: UPDATE & DELETE ---

  // Update an existing listing
  Future<bool> updateListing(
    String listingId,
    String title,
    String category,
    int qty,
    String pickupWindow,
    String imageUrl,
    bool isHalal,
    bool isVegan,
    double latitude,
    double longitude,
    String pickupAddress,
  ) async {
    try {
      await _firestore.collection('Listings').doc(listingId).update({
        'title': title,
        'category': category,
        'currentQuantity': qty,
        'pickupWindow': pickupWindow,
        'imageUrl': imageUrl,
        'isHalal': isHalal,
        'isVegan': isVegan,
        'latitude': latitude,
        'longitude': longitude,
        'pickupAddress': pickupAddress,
      });
      return true;
    } catch (e) {
      debugPrint("Error updating listing: $e");
      return false;
    }
  }

  // Delete a listing completely
  Future<bool> deleteListing(String listingId) async {
    try {
      await _firestore.collection('Listings').doc(listingId).delete();
      return true;
    } catch (e) {
      debugPrint("Error deleting listing: $e");
      return false;
    }
  }

  // Fetch all orders for a vendor (Used to calculate real-time stats)
  Stream<QuerySnapshot> getVendorOrders(String vendorId) {
    return _firestore
        .collection('Orders')
        .where('vendorID', isEqualTo: vendorId)
        .snapshots();
  }

  // Stream to get live updates of a vendor's active listings
  Stream<QuerySnapshot> getVendorListings(String vendorId) {
    return _firestore
        .collection('Listings')
        .where('vendorID', isEqualTo: vendorId)
        .snapshots();
  }

  // Stream to get ALL active listings for consumers
  Stream<QuerySnapshot> getActiveListings() {
    return _firestore
        .collection('Listings')
        .where('status', isEqualTo: 'Active')
        .snapshots();
  }

  // --- SECURE RESERVATION TRANSACTION ---
  Future<bool> reserveListing({
    required String listingId,
    required String consumerId,
    required String vendorId,
    required int quantityToReserve,
    required double totalPrice,
    required String listingTitle,
    required String pickupWindow,
    required String imageUrl,
  }) async {
    try {
      // runTransaction ensures that reading the stock and updating it happens safely
      return await _firestore.runTransaction((transaction) async {
        DocumentReference listingRef = _firestore
            .collection('Listings')
            .doc(listingId);
        DocumentSnapshot snapshot = await transaction.get(listingRef);

        if (!snapshot.exists) return false;

        int currentQty = snapshot.get('currentQuantity');

        // Final safety check: Is there enough stock left?
        if (currentQty < quantityToReserve) {
          return false;
        }

        // 1. Deduct the stock
        transaction.update(listingRef, {
          'currentQuantity': currentQty - quantityToReserve,
        });

        // 2. Create the new Order record
        DocumentReference orderRef = _firestore.collection('Orders').doc();
        transaction.set(orderRef, {
          'orderID': orderRef.id,
          'consumerID': consumerId,
          'vendorID': vendorId,
          'listingID': listingId,
          'listingTitle': listingTitle,
          'quantity': quantityToReserve,
          'totalPrice': totalPrice,
          'pickupWindow': pickupWindow,
          'imageUrl': imageUrl,
          'status': 'Pending', // Pending means waiting for pickup
          'createdAt': FieldValue.serverTimestamp(),
        });

        return true; // Transaction successful
      });
    } catch (e) {
      debugPrint("Transaction Error: $e");
      return false;
    }
  }

  // --- CONSUMER FAVORITES (SAVED ITEMS) ---

  // Get a live stream of the user's profile data
  Stream<DocumentSnapshot> getUserData(String userId) {
    return _firestore.collection('Users').doc(userId).snapshots();
  }

  // Add or remove a listing ID from the user's saved list
  Future<void> toggleSavedListing(
    String userId,
    String listingId,
    bool isCurrentlySaved,
  ) async {
    try {
      DocumentReference userRef = _firestore.collection('Users').doc(userId);

      if (isCurrentlySaved) {
        // If it's already saved, remove it
        await userRef.update({
          'savedListings': FieldValue.arrayRemove([listingId]),
        });
      } else {
        // If it's not saved, add it
        await userRef.update({
          'savedListings': FieldValue.arrayUnion([listingId]),
        });
      }
    } catch (e) {
      debugPrint("Error toggling saved item: $e");
    }
  }

  // --- CONSUMER ORDERS ---
  // Fetch all orders for a specific consumer
  Stream<QuerySnapshot> getConsumerOrders(String consumerId) {
    return _firestore
        .collection('Orders')
        .where('consumerID', isEqualTo: consumerId)
        // Note: We will sort the dates locally in the app to avoid Firestore Index errors!
        .snapshots();
  }

  // --- VENDOR ORDER MANAGEMENT ---

  // Update the status of an order (e.g., Pending -> Completed)
  Future<bool> updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _firestore.collection('Orders').doc(orderId).update({
        'status': newStatus,
      });
      return true;
    } catch (e) {
      debugPrint("Error updating order status: $e");
      return false;
    }
  }

  Future<void> submitReview({
    required String orderId,
    required String vendorId,
    required String consumerId,
    required int rating,
    required String comment,
  }) async {
    // Safety check: Prevent crash if an old test order is missing a vendorId
    if (vendorId.isEmpty) {
      throw Exception("Vendor ID is missing from this order. Cannot submit rating.");
    }

    // 1. Mark order as rated
    await FirebaseFirestore.instance.collection('Orders').doc(orderId).update({
      'isRated': true,
      'rating': rating,
    });

    // 2. Save review to Reviews collection
    await FirebaseFirestore.instance.collection('Reviews').add({
      'vendorId': vendorId,
      'consumerId': consumerId,
      'orderId': orderId,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 3. Safely update Vendor Profile rating totals
    DocumentReference vendorRef = FirebaseFirestore.instance.collection('Users').doc(vendorId);
    
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot vendorSnapshot = await transaction.get(vendorRef);
      
      if (!vendorSnapshot.exists) {
        throw Exception("Vendor profile no longer exists.");
      }

      Map<String, dynamic>? data = vendorSnapshot.data() as Map<String, dynamic>?;
      
      // Use 0 if the fields don't exist yet
      int currentCount = (data?['ratingCount'] ?? 0).toInt();
      double currentPoints = (data?['totalRatingPoints'] ?? 0).toDouble();

      int newCount = currentCount + 1;
      double newPoints = currentPoints + rating;
      double averageRating = newPoints / newCount;

      transaction.update(vendorRef, {
        'ratingCount': newCount,
        'totalRatingPoints': newPoints,
        'averageRating': averageRating,
      });
    });
  }

  // 2. Fetch reviews for a specific vendor
 Stream<QuerySnapshot> getVendorReviews(String vendorId) {
    return FirebaseFirestore.instance.collection('Reviews')
        .where('vendorId', isEqualTo: vendorId)
        // REMOVED .orderBy('createdAt') to avoid index error
        .snapshots();
  }
}
