import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart'; 
import '../services/database_service.dart';

class EditListingScreen extends StatefulWidget {
  final QueryDocumentSnapshot listing;

  const EditListingScreen({super.key, required this.listing});

  @override
  State<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends State<EditListingScreen> {
  late TextEditingController _titleController;
  final TextEditingController _addressController = TextEditingController();

  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = false;

  late int _quantity;
  late String _selectedCategory;
  final List<String> _categories = ['Meals', 'Pastries', 'Groceries'];

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  // --- WEB-SAFE IMAGE VARIABLES ---
  Uint8List? _newImageBytes; // Used instead of File for web compatibility
  String _existingImageUrl = ''; 
  final ImagePicker _picker = ImagePicker();

  late bool _isHalal;
  late bool _isVegan;

  // --- PICKUP LOCATION STATE ---
  bool _useCurrentLocation = false; 
  bool _isResolvingLocation = false;
  double? _latitude;
  double? _longitude;
  String _pickupAddress = '';

  @override
  void initState() {
    super.initState();
    var data = widget.listing.data() as Map<String, dynamic>;

    _titleController = TextEditingController(text: widget.listing['title']);
    _quantity = widget.listing['currentQuantity'];
    _selectedCategory = data.containsKey('category') ? data['category'] : 'Meals';
    _existingImageUrl = data.containsKey('imageUrl') ? data['imageUrl'] : '';

    _latitude = data.containsKey('latitude') ? (data['latitude'] as num?)?.toDouble() : null;
    _longitude = data.containsKey('longitude') ? (data['longitude'] as num?)?.toDouble() : null;
    _pickupAddress = data.containsKey('pickupAddress') ? (data['pickupAddress'] ?? '') : '';
    _addressController.text = _pickupAddress;

    String savedTime = widget.listing['pickupWindow'];
    List<String> times = savedTime.split(' - ');
    if (times.length == 2) {
      _startTime = _parseTimeString(times[0]);
      _endTime = _parseTimeString(times[1]);
    }
    _isHalal = data.containsKey('isHalal') ? data['isHalal'] : false;
    _isVegan = data.containsKey('isVegan') ? data['isVegan'] : false;
  }

  TimeOfDay? _parseTimeString(String timeString) {
    try {
      final parts = timeString.split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);
      if (parts.length > 1) {
        if (parts[1].toUpperCase() == 'PM' && hour != 12) hour += 12;
        if (parts[1].toUpperCase() == 'AM' && hour == 12) hour = 0;
      }
      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return null;
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _newImageBytes = bytes;
      });
    }
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return "Select Time";
    return MaterialLocalizations.of(context).formatTimeOfDay(time);
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (_startTime ?? TimeOfDay.now())
          : (_endTime ?? TimeOfDay.now()),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: Colors.green,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<Position?> _getVendorLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  // --- WEB-SAFE REVERSE GEOCODING ---
  Future<void> _detectCurrentLocation() async {
    setState(() => _isResolvingLocation = true);

    Position? position = await _getVendorLocation();
    if (!mounted) return;

    if (position == null) {
      setState(() => _isResolvingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Could not get your location. Please enable GPS and try again.'),
        ),
      );
      return;
    }

    String address = 'Current location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
    
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=${position.latitude}&lon=${position.longitude}&format=json');
      final response = await http.get(url, headers: {'User-Agent': 'GreenBite_Web_App'});
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['display_name'] != null) {
          address = data['display_name'];
        }
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;
      _pickupAddress = address;
      _addressController.text = address;
      _isResolvingLocation = false;
    });
  }

  // --- WEB-SAFE FORWARD GEOCODING ---
  Future<void> _verifyManualAddress() async {
    final input = _addressController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please type a pickup address first')),
      );
      return;
    }

    setState(() => _isResolvingLocation = true);

    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(input)}&format=json&limit=1');
      final response = await http.get(url, headers: {'User-Agent': 'GreenBite_Web_App'});
      
      if (!mounted) return;

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          setState(() {
            _latitude = double.parse(data[0]['lat']);
            _longitude = double.parse(data[0]['lon']);
            _pickupAddress = data[0]['display_name']; 
            _isResolvingLocation = false;
          });
          return;
        }
      }

      setState(() => _isResolvingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Address not found. Try adding more detail (e.g. city, postcode).'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResolvingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Could not verify that address. Check your connection and try again.'),
        ),
      );
    }
  }

  void _saveChanges() async {
    if (_titleController.text.isEmpty || _startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields')),
      );
      return;
    }

    if (!_useCurrentLocation && _addressController.text.trim() != _pickupAddress) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please tap "Verify Address" after changing the pickup address')),
      );
      return;
    }

    if (_latitude == null || _longitude == null || _pickupAddress.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a pickup location before saving')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String finalImageUrl = _existingImageUrl; 

      // Web-safe image upload using putData instead of putFile
      if (_newImageBytes != null) {
        String fileName = DateTime.now().millisecondsSinceEpoch.toString();
        Reference storageRef = FirebaseStorage.instance.ref().child('listing_images/$fileName.jpg');
        
        await storageRef.putData(_newImageBytes!, SettableMetadata(contentType: 'image/jpeg'));
        finalImageUrl = await storageRef.getDownloadURL();
      }

      String pickupWindow = "${_formatTime(_startTime)} - ${_formatTime(_endTime)}";

      bool success = await _dbService.updateListing(
        widget.listing.id,
        _titleController.text,
        _selectedCategory,
        _quantity,
        pickupWindow,
        finalImageUrl,
        _isHalal,
        _isVegan,
        _latitude!,
        _longitude!,
        _pickupAddress,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Updated Successfully!'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Failed to update. Try again.'),
        ),
      );
    }
  }

  Widget _buildLocationModeChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? Colors.green : Colors.grey.shade500, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.green.shade700 : Colors.grey.shade600,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
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
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine which image to show using MemoryImage instead of FileImage
    ImageProvider? currentImage;
    if (_newImageBytes != null) {
      currentImage = MemoryImage(_newImageBytes!);
    } else if (_existingImageUrl.isNotEmpty) {
      currentImage = NetworkImage(_existingImageUrl);
    } else {
      currentImage = const NetworkImage(
        'https://images.unsplash.com/photo-1495147466023-e6a925cd9294?q=80&w=600&auto=format&fit=crop',
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Edit Mystery Box',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                      image: DecorationImage(
                        image: currentImage,
                        fit: BoxFit.cover,
                        opacity: 0.8,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Food Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Listing Title',
                      prefixIcon: const Icon(Icons.fastfood, color: Colors.green),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Food Category',
                      prefixIcon: const Icon(Icons.category, color: Colors.green),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: _categories.map((String category) => DropdownMenuItem(value: category, child: Text(category))).toList(),
                    onChanged: (newValue) {
                       if (newValue != null) setState(() => _selectedCategory = newValue);
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: Colors.green,
                      title: const Text('Halal / Muslim Friendly', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(_isHalal ? 'Yes, this item is Halal' : 'No, this is Non-Halal', style: TextStyle(color: _isHalal ? Colors.green : Colors.red)),
                      value: _isHalal,
                      onChanged: (value) => setState(() => _isHalal = value),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: Colors.green,
                      title: const Text('Vegan', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(_isVegan ? 'Yes, this item is Vegan' : 'No, this is not Vegan', style: TextStyle(color: _isVegan ? Colors.green : Colors.grey)),
                      value: _isVegan,
                      onChanged: (value) => setState(() => _isVegan = value),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Quantity Available', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildQtyButton(
                          icon: Icons.remove_rounded,
                          color: Colors.red,
                          onTap: () { if (_quantity > 0) setState(() => _quantity--); },
                        ),
                        Text('$_quantity', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        _buildQtyButton(
                          icon: Icons.add_rounded,
                          color: Colors.green,
                          onTap: () => setState(() => _quantity++),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pickup Window', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectTime(context, true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              children: [
                                const Text('Starts At', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(_formatTime(_startTime), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectTime(context, false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              children: [
                                const Text('Ends At', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(_formatTime(_endTime), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pickup Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildLocationModeChip(
                            label: 'Current Location',
                            icon: Icons.my_location,
                            selected: _useCurrentLocation,
                            onTap: () => setState(() => _useCurrentLocation = true),
                          ),
                        ),
                        Expanded(
                          child: _buildLocationModeChip(
                            label: 'Enter Address',
                            icon: Icons.edit_location_alt,
                            selected: !_useCurrentLocation,
                            onTap: () => setState(() => _useCurrentLocation = false),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_useCurrentLocation)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isResolvingLocation ? null : _detectCurrentLocation,
                        icon: _isResolvingLocation
                            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.gps_fixed, color: Colors.green),
                        label: Text(_isResolvingLocation ? 'Detecting...' : 'Detect My Location'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _addressController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Pickup Address',
                            hintText: 'e.g. 12 Jalan Bakery, Taman Perling, Johor Bahru',
                            prefixIcon: const Icon(Icons.location_on, color: Colors.green),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _isResolvingLocation ? null : _verifyManualAddress,
                          icon: _isResolvingLocation
                              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.check_circle_outline, color: Colors.green),
                          label: Text(_isResolvingLocation ? 'Verifying...' : 'Verify Address'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            side: const BorderSide(color: Colors.green),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  if (_pickupAddress.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _pickupAddress,
                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isLoading ? null : _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Changes', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}