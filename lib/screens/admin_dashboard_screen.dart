import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/app_snackbar.dart';
import 'home_screen.dart' show PropertyModel;
import 'property_details_screen.dart';
import 'posting_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _supabase = Supabase.instance.client;
  List<PropertyModel> _properties = [];
  bool _isLoading = true;
  String _filter = 'pending'; // pending, approved, rejected, all

  @override
  void initState() {
    super.initState();
    _fetchProperties();
  }

  Future<void> _fetchProperties() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await _supabase.from('properties').select().order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _properties = (data as List).map((e) => PropertyModel.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Failed to fetch: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateStatus(String id, String newStatus) async {
    try {
      await _supabase.from('properties').update({'status': newStatus}).eq('id', id);
      if (mounted) {
        AppSnackbar.success(context, 'Property $newStatus successfully');
        _fetchProperties();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Failed to update status: $e');
      }
    }
  }

  Future<void> _deleteProperty(String id) async {
    try {
      await _supabase.from('properties').delete().eq('id', id);
      if (mounted) {
        AppSnackbar.success(context, 'Property deleted');
        _fetchProperties();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Failed to delete: $e');
      }
    }
  }

  Future<void> _confirmDelete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Property', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this property? This action cannot be undone.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _deleteProperty(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'all'
        ? _properties
        : _filter == 'pending_photos'
            ? _properties.where((p) => p.suggestedPhotos.any((photo) => photo['status'] == 'pending')).toList()
            : _properties.where((p) => p.status == _filter).toList();

    int total = _properties.length;
    int pendingCount = _properties.where((p) => p.status == 'pending').length;
    int pendingPhotosCount = _properties.where((p) => p.suggestedPhotos.any((photo) => photo['status'] == 'pending')).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left_2, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.refresh, color: Colors.black),
            onPressed: _fetchProperties,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Analytics Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(child: _buildStatCard('Total', total.toString(), Iconsax.buildings, Colors.blue)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('Pending', pendingCount.toString(), Iconsax.clock, Colors.orange)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('Photos', pendingPhotosCount.toString(), Iconsax.gallery, Colors.purple)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('pending', 'Pending Review'),
                const SizedBox(width: 10),
                _buildFilterChip('pending_photos', 'Pending Photos'),
                const SizedBox(width: 10),
                _buildFilterChip('approved', 'Approved Live'),
                const SizedBox(width: 10),
                _buildFilterChip('rejected', 'Rejected'),
                const SizedBox(width: 10),
                _buildFilterChip('all', 'All Properties'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              '${filtered.length} Properties',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
            ),
          ),

          // Property List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.black))
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Iconsax.folder_cross, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text('No properties found.', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 40),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _buildAdminPropertyCard(filtered[index]);
                        },
                      ),
          )
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: isSelected ? Colors.black : Colors.grey.shade300),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildAdminPropertyCard(PropertyModel prop) {
    Color statusColor = Colors.grey;
    if (prop.status == 'pending') statusColor = Colors.orange;
    if (prop.status == 'approved') statusColor = Colors.green;
    if (prop.status == 'rejected') statusColor = Colors.redAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header / Content
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CachedNetworkImage(
                    imageUrl: prop.imageUrls.isNotEmpty ? prop.imageUrls.first : '',
                    height: 100,
                    width: 100,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 100,
                      width: 100,
                      color: Colors.grey.shade100,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 100,
                      width: 100,
                      color: Colors.grey.shade100,
                      child: const Center(child: Icon(Iconsax.image, color: Colors.grey)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              prop.status?.toUpperCase() ?? 'UNKNOWN',
                              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Spacer(),
                          Text(prop.type, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        prop.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, height: 1.2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        prop.price,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Iconsax.location5, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              prop.locationStr,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          
          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
            child: Row(
              children: [
                if (prop.status == 'pending' || prop.status == 'rejected') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateStatus(prop.id!, 'approved'),
                      icon: const Icon(Iconsax.tick_circle, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (prop.status == 'pending' || prop.status == 'approved') ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _updateStatus(prop.id!, 'rejected'),
                      icon: const Icon(Iconsax.close_circle, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                IconButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: const Color(0xFFF7F7F9),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      builder: (context) => PostBottomSheet(
                        propertyToEdit: prop,
                        onPropertyCreated: (_) => _fetchProperties(),
                      ),
                    ).then((_) => _fetchProperties());
                  },
                  icon: const Icon(Iconsax.edit, color: Colors.blueAccent),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _confirmDelete(prop.id!),
                  icon: const Icon(Iconsax.trash, color: Colors.redAccent),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          
          // Pending Photos Section
          if (_filter == 'pending_photos' && prop.suggestedPhotos.any((photo) => photo['status'] == 'pending'))
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.purple.withValues(alpha: 0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pending Photo Contributions:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  ...prop.suggestedPhotos.where((photo) => photo['status'] == 'pending').map((photo) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: photo['url'],
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _approvePhoto(prop, photo),
                              icon: const Icon(Iconsax.tick_circle, size: 16),
                              label: const Text('Approve'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _rejectPhoto(prop, photo),
                              icon: const Icon(Iconsax.close_circle, size: 16),
                              label: const Text('Reject'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _approvePhoto(PropertyModel prop, dynamic photo) async {
    try {
      final updatedImageUrls = List<String>.from(prop.imageUrls)..add(photo['url']);
      final updatedSuggestedPhotos = List<dynamic>.from(prop.suggestedPhotos)..remove(photo);

      await _supabase.from('properties').update({
        'image_urls': updatedImageUrls,
        'suggested_photos': updatedSuggestedPhotos,
      }).eq('id', prop.id!);

      AppSnackbar.success(context, 'Photo approved and added to property');
      _fetchProperties();
    } catch (e) {
      AppSnackbar.error(context, 'Error approving photo: $e');
    }
  }

  Future<void> _rejectPhoto(PropertyModel prop, dynamic photo) async {
    try {
      final updatedSuggestedPhotos = List<dynamic>.from(prop.suggestedPhotos)..remove(photo);

      await _supabase.from('properties').update({
        'suggested_photos': updatedSuggestedPhotos,
      }).eq('id', prop.id!);

      AppSnackbar.success(context, 'Photo rejected and removed');
      _fetchProperties();
    } catch (e) {
      AppSnackbar.error(context, 'Error rejecting photo: $e');
    }
  }
}
