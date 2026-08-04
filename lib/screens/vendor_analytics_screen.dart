import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';

class VendorAnalyticsScreen extends StatefulWidget {
  const VendorAnalyticsScreen({super.key});

  @override
  State<VendorAnalyticsScreen> createState() => _VendorAnalyticsScreenState();
}

class _VendorAnalyticsScreenState extends State<VendorAnalyticsScreen> {
  final DatabaseService _dbService = DatabaseService();
  final String _vendorId = FirebaseAuth.instance.currentUser!.uid;

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Overall Impact', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _dbService.getVendorOrders(_vendorId),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Error loading data'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.requireData.docs;

          // --- 1. CALCULATE TOTALS ---
          int totalCompletedOrders = 0;

          // Chart Data: Last 7 Days Boxes Donated
          DateTime now = DateTime.now();
          DateTime startOfToday = DateTime(now.year, now.month, now.day);
          
          List<int> weeklyBoxes = List.filled(7, 0);
          List<String> weekLabels = [];
          
          for (int i = 6; i >= 0; i--) {
            DateTime day = now.subtract(Duration(days: i));
            weekLabels.add(_getDayName(day.weekday));
          }

          for (var doc in docs) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            
            if (data['status'] == 'Completed' && data['createdAt'] != null) {
              int qty = data.containsKey('quantity') ? (data['quantity'] as num).toInt() : 1;
              
              totalCompletedOrders += qty;

              DateTime orderDate = (data['createdAt'] as Timestamp).toDate();
              DateTime startOfOrderDay = DateTime(orderDate.year, orderDate.month, orderDate.day);
              
              int differenceInDays = startOfToday.difference(startOfOrderDay).inDays;
              if (differenceInDays >= 0 && differenceInDays < 7) {
                int chartIndex = 6 - differenceInDays;
                weeklyBoxes[chartIndex] += qty;
              }
            }
          }

          // --- 2. CALCULATE ENVIRONMENTAL IMPACT ---
          double foodSavedKg = totalCompletedOrders * 0.5;
          double co2PreventedKg = totalCompletedOrders * 1.25;

          // Find max boxes for chart scaling
          int maxBoxes = 0;
          for (int boxes in weeklyBoxes) {
            if (boxes > maxBoxes) maxBoxes = boxes;
          }
          if (maxBoxes == 0) maxBoxes = 5; // Fallback to avoid division by zero and give the chart empty scale

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Lifetime Contributions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                
                // First Row of Metrics
                Row(
                  children: [
                    Expanded(child: _buildMetricCard('Boxes Donated', '$totalCompletedOrders', Icons.card_giftcard, Colors.blue)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildMetricCard('Food Saved', '${foodSavedKg.toStringAsFixed(1)} kg', Icons.restaurant, Colors.orange)),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Second Row of Metrics
                Row(
                  children: [
                    Expanded(child: _buildMetricCard('CO₂ Prevented', '${co2PreventedKg.toStringAsFixed(1)} kg', Icons.eco, Colors.teal)),
                    const SizedBox(width: 16),
                    Expanded(child: const SizedBox.shrink()), // Keeps the layout balanced
                  ],
                ),
                
                const SizedBox(height: 32),

                // --- CUSTOM BAR CHART ---
                const Text('Boxes Donated (Last 7 Days)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Container(
                  height: 250,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(7, (index) {
                      double barHeightRatio = weeklyBoxes[index] / maxBoxes;
                      return _buildChartBar(weekLabels[index], weeklyBoxes[index], barHeightRatio);
                    }),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- UI COMPONENTS ---
  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildChartBar(String label, int amount, double heightRatio) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(amount > 0 ? amount.toString() : '', style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          width: 30,
          height: 150 * heightRatio,
          decoration: BoxDecoration(
            color: amount > 0 ? Colors.green : Colors.grey.shade200,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }
}