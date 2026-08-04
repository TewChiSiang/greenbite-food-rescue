import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';

class VendorReviewsScreen extends StatefulWidget {
  const VendorReviewsScreen({super.key});

  @override
  State<VendorReviewsScreen> createState() => _VendorReviewsScreenState();
}

class _VendorReviewsScreenState extends State<VendorReviewsScreen> {
  final DatabaseService _dbService = DatabaseService();
  final String _vendorId = FirebaseAuth.instance.currentUser!.uid;

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    DateTime date = timestamp.toDate();
    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Customer Reviews', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _dbService.getVendorReviews(_vendorId),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Error loading reviews'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          var reviews = snapshot.requireData.docs;

          reviews.sort((a, b) {
            var dataA = a.data() as Map<String, dynamic>;
            var dataB = b.data() as Map<String, dynamic>;
            Timestamp? timeA = dataA['createdAt'] as Timestamp?;
            Timestamp? timeB = dataB['createdAt'] as Timestamp?;
            
            if (timeA == null || timeB == null) return 0;
            return timeB.compareTo(timeA); // Descending order (newest first)
          });

          if (reviews.isEmpty) {
            return const Center(
              child: Text('No reviews yet. Keep saving food!', style: TextStyle(color: Colors.grey, fontSize: 16)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              var reviewData = reviews[index].data() as Map<String, dynamic>;
              int rating = reviewData['rating'] ?? 5;
              String comment = reviewData['comment'] ?? '';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Render the stars dynamically
                          Row(
                            children: List.generate(5, (starIndex) {
                              return Icon(
                                starIndex < rating ? Icons.star : Icons.star_border,
                                color: Colors.orange,
                                size: 20,
                              );
                            }),
                          ),
                          Text(
                            _formatDate(reviewData['createdAt'] as Timestamp?),
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Show comment, or a placeholder if they didn't write anything
                      Text(
                        comment.isNotEmpty ? '"$comment"' : 'No written comment left.',
                        style: TextStyle(
                          fontSize: 15,
                          fontStyle: comment.isNotEmpty ? FontStyle.italic : FontStyle.normal,
                          color: comment.isNotEmpty ? Colors.black87 : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}