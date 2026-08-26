import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../widgets/app_snackbar.dart';
import 'home_screen.dart' show PropertyModel;
import 'map_screen.dart';
import 'full_screen_image_viewer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PropertyDetailsScreen extends StatefulWidget {
  final PropertyModel property;

  const PropertyDetailsScreen({super.key, required this.property});

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  int _currentImageIndex = 0;
  bool _hasReviewed = false;
  String? _deviceId;
  Map<String, dynamic>? _myReview;

  @override
  void initState() {
    super.initState();
    _checkIfReviewed();
  }

  Future<void> _checkIfReviewed() async {
    if (widget.property.id == null) return;
    final prefs = await SharedPreferences.getInstance();
    
    String? dId = prefs.getString('device_id');
    if (dId == null) {
      dId = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString('device_id', dId);
    }
    _deviceId = dId;

    final reviewedProperties = prefs.getStringList('reviewed_properties') ?? [];
    if (reviewedProperties.contains(widget.property.id)) {
      try {
        _myReview = widget.property.reviews.firstWhere(
          (r) => r['device_id'] == _deviceId,
          orElse: () => widget.property.reviews.last,
        );
      } catch (_) {}

      setState(() {
        _hasReviewed = true;
      });
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    final url = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        AppSnackbar.error(context, 'Could not launch WhatsApp');
      }
    }
  }

  Future<void> _launchPhone(String phone) async {
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF7F7),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Carousel and Top Bar Stack
            Stack(
              children: [
                SizedBox(
                  height: 350,
                  child: PageView.builder(
                    itemCount: widget.property.imageUrls.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentImageIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final imagePath = widget.property.imageUrls[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FullScreenImageViewer(
                                imageUrls: widget.property.imageUrls,
                                initialIndex: index,
                              ),
                            ),
                          );
                        },
                        child: imagePath.startsWith('http')
                            ? CachedNetworkImage(
                                imageUrl: imagePath,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey.shade300,
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey.shade300,
                                  child: const Center(
                                    child: Icon(Iconsax.image, color: Colors.grey, size: 40),
                                  ),
                                ),
                              )
                            : Image.file(
                                File(imagePath),
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: Colors.grey.shade300,
                                  child: const Center(
                                    child: Icon(Iconsax.image, color: Colors.grey, size: 40),
                                  ),
                                ),
                              ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildIconButton(
                          icon: Iconsax.arrow_left_2,
                          onTap: () => Navigator.pop(context),
                        ),
                        if (widget.property.isAvailable)
                          _buildIconButton(
                            icon: Iconsax.slash,
                            onTap: _showAvailabilityBottomSheet,
                          )
                        else
                          _buildIconButton(
                            icon: Iconsax.refresh,
                            onTap: () {
                              setState(() {
                                widget.property.isAvailable = true;
                              });
                              AppSnackbar.success(context, 'Revoked to Available');
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                // Pagination Dots
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      widget.property.imageUrls.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentImageIndex == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentImageIndex == index ? Colors.white : Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title, Type Badge & Price
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      widget.property.type == 'PG' ? 'PG / Hostel' : 'Rental House/Flat',
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  if (widget.property.reviewCount > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Iconsax.star1, color: Colors.amber, size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            widget.property.averageRating.toStringAsFixed(1),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                          ),
                                          Text(
                                            ' (${widget.property.reviewCount})',
                                            style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.property.title,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              widget.property.price,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                            if (widget.property.securityDeposit != null)
                              Text(
                                'Deposit: ${widget.property.securityDeposit}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    
                    // Location
                    Row(
                      children: [
                        const Icon(Iconsax.location5, color: Colors.grey, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.property.locationStr,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showContributePhotosSheet,
                        icon: const Icon(Iconsax.camera, size: 18, color: Colors.black),
                        label: const Text('Contribute Photos', style: TextStyle(color: Colors.black)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.black, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Quick Stats Wrap
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildStatItem(Iconsax.moon5, widget.property.beds),
                        _buildStatItem(Iconsax.drop, widget.property.baths),
                        _buildStatItem(Iconsax.maximize_45, widget.property.area),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Financial & Tenure Info Grid
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F9FB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow('Security Deposit', widget.property.securityDeposit ?? '1-2 Months Rent', Iconsax.wallet_3),
                          const Divider(height: 16),
                          _buildDetailRow('Notice Period', widget.property.noticePeriod ?? '1 Month', Iconsax.calendar),
                          const Divider(height: 16),
                          _buildDetailRow('Agreement / Lock-in', widget.property.agreementDuration ?? '11 Months Standard', Iconsax.document_text),
                          if (widget.property.maintenanceCharges != null) ...[
                            const Divider(height: 16),
                            _buildDetailRow('Maintenance', widget.property.maintenanceCharges!, Iconsax.receipt_item),
                          ],
                          if (widget.property.type == 'PG' && widget.property.perDayWithFood != null && widget.property.perDayWithFood!.isNotEmpty) ...[
                            const Divider(height: 16),
                            _buildDetailRow('Per Day (With Food)', '₹${widget.property.perDayWithFood}/day', Iconsax.calendar),
                          ],
                          if (widget.property.type == 'PG' && widget.property.perDayWithoutFood != null && widget.property.perDayWithoutFood!.isNotEmpty) ...[
                            const Divider(height: 16),
                            _buildDetailRow('Per Day (Without Food)', '₹${widget.property.perDayWithoutFood}/day', Iconsax.calendar_1),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Description
                    const Text(
                      'Description',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.property.description ??
                          'Well-maintained property with essential amenities, good ventilation, and peaceful surroundings.',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5),
                    ),
                    const SizedBox(height: 24),

                    // SPECIFIC CATEGORY BREAKDOWNS (PG vs Rental) - ONLY DISPLAY ADDED DATA
                    if (widget.property.type == 'PG') ...[
                      // PG: Food & Mess Plan
                      _buildDynamicSection('Food & Mess Plan', Iconsax.coffee, [
                        if (widget.property.foodDetails != null && widget.property.foodDetails!.trim().isNotEmpty)
                          'Meal Plan: ${widget.property.foodDetails}',
                        if (widget.property.foodQuality != null && widget.property.foodQuality!.trim().isNotEmpty)
                          'Food Quality: ${widget.property.foodQuality}',
                        if (widget.property.drinkingWater != null && widget.property.drinkingWater!.trim().isNotEmpty)
                          'Drinking Water: ${widget.property.drinkingWater}',
                      ]),

                      // PG: Utilities & Living Setup
                      _buildDynamicSection('Utilities & Living Setup', Iconsax.flash_1, [
                        if (widget.property.waterSupply != null && widget.property.waterSupply!.trim().isNotEmpty)
                          'Water Supply: ${widget.property.waterSupply}',
                        if (widget.property.powerBackup != null && widget.property.powerBackup!.trim().isNotEmpty)
                          'Power Backup: ${widget.property.powerBackup}',
                        if (widget.property.acType != null && widget.property.acType!.trim().isNotEmpty)
                          'AC / Climate: ${widget.property.acType}',
                        if (widget.property.bathroomType != null && widget.property.bathroomType!.trim().isNotEmpty)
                          'Bathroom Setup: ${widget.property.bathroomType}',
                      ]),

                      // PG: Security, Hygiene & Rules
                      _buildDynamicSection('Security, Hygiene & Rules', Iconsax.shield_tick, [
                        if (widget.property.cleanlinessInfo != null && widget.property.cleanlinessInfo!.trim().isNotEmpty)
                          'Cleanliness: ${widget.property.cleanlinessInfo}',
                        if (widget.property.securityInfo != null && widget.property.securityInfo!.trim().isNotEmpty)
                          'Security & CCTV: ${widget.property.securityInfo}',
                        if (widget.property.verificationPolicy != null && widget.property.verificationPolicy!.trim().isNotEmpty)
                          'Verification: ${widget.property.verificationPolicy}',
                        if (widget.property.managementInfo != null && widget.property.managementInfo!.trim().isNotEmpty)
                          'Management: ${widget.property.managementInfo}',
                        if (widget.property.gateRules != null && widget.property.gateRules!.trim().isNotEmpty)
                          'Gate Rules: ${widget.property.gateRules}',
                        if (widget.property.genderPreference != null && widget.property.genderPreference!.trim().isNotEmpty)
                          'Gender Preference: ${widget.property.genderPreference}',
                        if (widget.property.sharingType != null && widget.property.sharingType!.trim().isNotEmpty)
                          'Room Sharing: ${widget.property.sharingType}',
                      ]),
                    ] else ...[
                      // Rental: Space & Physical Condition
                      _buildDynamicSection('Space & Physical Condition', Iconsax.home, [
                        if (widget.property.bhkType != null && widget.property.bhkType!.trim().isNotEmpty)
                          'BHK Configuration: ${widget.property.bhkType}',
                        if (widget.property.furnishingStatus != null && widget.property.furnishingStatus!.trim().isNotEmpty)
                          'Furnishing Status: ${widget.property.furnishingStatus}',
                        if (widget.property.plumbingStatus != null && widget.property.plumbingStatus!.trim().isNotEmpty)
                          'Plumbing: ${widget.property.plumbingStatus}',
                        if (widget.property.seepageStatus != null && widget.property.seepageStatus!.trim().isNotEmpty)
                          'Wall & Roof Condition: ${widget.property.seepageStatus}',
                        if (widget.property.electricalStatus != null && widget.property.electricalStatus!.trim().isNotEmpty)
                          'Electrical & Wiring: ${widget.property.electricalStatus}',
                      ]),

                      // Rental: Water, Electricity & Bills
                      _buildDynamicSection('Water, Electricity & Bills', Iconsax.receipt_item, [
                        if (widget.property.meterStatus != null && widget.property.meterStatus!.trim().isNotEmpty)
                          'EB Metering: ${widget.property.meterStatus}',
                        if (widget.property.billsInfo != null && widget.property.billsInfo!.trim().isNotEmpty)
                          'Bills Policy: ${widget.property.billsInfo}',
                        if (widget.property.waterSupply != null && widget.property.waterSupply!.trim().isNotEmpty)
                          'Water Facility: ${widget.property.waterSupply}',
                        if (widget.property.parkingInfo != null && widget.property.parkingInfo!.trim().isNotEmpty)
                          'Parking: ${widget.property.parkingInfo}',
                      ]),

                      // Rental: Agreement & House Rules
                      _buildDynamicSection('Rental Agreement & House Rules', Iconsax.document_text, [
                        if (widget.property.agreementDuration != null && widget.property.agreementDuration!.trim().isNotEmpty)
                          'Agreement Tenure: ${widget.property.agreementDuration}',
                        if (widget.property.noticePeriod != null && widget.property.noticePeriod!.trim().isNotEmpty)
                          'Notice Period: ${widget.property.noticePeriod}',
                        if (widget.property.tenantPreference != null && widget.property.tenantPreference!.trim().isNotEmpty)
                          'Tenant Preference: ${widget.property.tenantPreference}',
                        if (widget.property.petPolicy != null && widget.property.petPolicy!.trim().isNotEmpty)
                          'Pet Policy: ${widget.property.petPolicy}',
                      ]),
                    ],
                    // Features & Amenities List (Shows only unique extra amenities not covered in other sections)
                    () {
                      final filteredFeatures = _getFilteredFeatures();
                      if (filteredFeatures.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Features & Amenities',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          _buildFeaturesList(filteredFeatures),
                          const SizedBox(height: 28),
                        ],
                      );
                    }(),
                    
                    // Reviews & Ratings
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Reviews & Ratings',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        _hasReviewed
                            ? OutlinedButton.icon(
                                onPressed: _showAddReviewSheet,
                                icon: const Icon(Iconsax.edit, size: 16, color: Colors.black),
                                label: const Text('Edit Review', style: TextStyle(color: Colors.black)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.black, width: 1.2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                ),
                              )
                            : OutlinedButton.icon(
                                onPressed: _showAddReviewSheet,
                                icon: const Icon(Iconsax.edit, size: 16, color: Colors.black),
                                label: const Text('Write a Review', style: TextStyle(color: Colors.black)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.black, width: 1.2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                ),
                              ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (widget.property.reviews.isEmpty)
                      const Text(
                        'No reviews yet. Be the first to review!',
                        style: TextStyle(color: Colors.grey),
                      )
                    else
                      ...widget.property.reviews.map((r) => _buildReviewItem(r)),
                    const SizedBox(height: 28),

                    // Location Map
                    const Text(
                      'Location Map',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MapScreen(
                              latitude: widget.property.latitude,
                              longitude: widget.property.longitude,
                              title: widget.property.title,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: IgnorePointer(
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter: LatLng(widget.property.latitude, widget.property.longitude),
                              initialZoom: 14.0,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
                                userAgentPackageName: 'com.example.rental',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(widget.property.latitude, widget.property.longitude),
                                    width: 40,
                                    height: 40,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Iconsax.location5, color: Colors.red, size: 30),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
        ),
      ),
      // Sticky Bottom Action Bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, -4),
              blurRadius: 16,
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _launchPhone(widget.property.ownerPhone),
                    style: ElevatedButton.styleFrom(
                      // Inherits from global theme
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Contact Owner',
                      style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _launchWhatsApp(widget.property.ownerPhone),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                    padding: const EdgeInsets.all(14),
                    shape: const CircleBorder(),
                    elevation: 0,
                  ),
                  child: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white, size: 22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAvailabilityBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Is this house/PG still vacant?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('Yes', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          widget.property.isAvailable = false;
                        });
                        Navigator.pop(context);
                        AppSnackbar.success(context, 'Marked as Not Available');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                      child: const Text('No', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.7),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: const Color(0xFF1E1E1E), size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: Colors.black87),
          const SizedBox(width: 8),
          Flexible(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade700),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          value,
          style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildDynamicSection(String title, IconData icon, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title, icon),
        const SizedBox(height: 8),
        _buildInfoBox(items),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.black),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildInfoBox(List<String> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) {
          final parts = item.split(': ');
          Widget textWidget;
          if (parts.length >= 2) {
            final label = parts[0];
            final value = parts.sublist(1).join(': ');
            textWidget = RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13.5,
                  color: Colors.grey.shade800,
                  height: 1.35,
                  fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
                ),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            );
          } else {
            textWidget = Text(
              item,
              style: TextStyle(fontSize: 13.5, color: Colors.grey.shade800, height: 1.35),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: textWidget,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  List<String> _getFilteredFeatures() {
    final Set<String> alreadyShown = {};

    void addNormalized(String? val) {
      if (val != null && val.trim().isNotEmpty) {
        alreadyShown.add(val.trim().toLowerCase());
      }
    }

    // Gather all structured values shown in financial box and category breakdown sections
    addNormalized(widget.property.securityDeposit);
    addNormalized(widget.property.noticePeriod);
    addNormalized(widget.property.agreementDuration);
    addNormalized(widget.property.maintenanceCharges);
    addNormalized(widget.property.perDayWithFood);
    addNormalized(widget.property.perDayWithoutFood);
    addNormalized(widget.property.genderPreference);
    addNormalized(widget.property.sharingType);
    addNormalized(widget.property.foodDetails);
    addNormalized(widget.property.foodQuality);
    addNormalized(widget.property.drinkingWater);
    addNormalized(widget.property.waterSupply);
    addNormalized(widget.property.powerBackup);
    addNormalized(widget.property.acType);
    addNormalized(widget.property.bathroomType);
    addNormalized(widget.property.cleanlinessInfo);
    addNormalized(widget.property.securityInfo);
    addNormalized(widget.property.verificationPolicy);
    addNormalized(widget.property.managementInfo);
    addNormalized(widget.property.gateRules);
    addNormalized(widget.property.bhkType);
    addNormalized(widget.property.furnishingStatus);
    addNormalized(widget.property.plumbingStatus);
    addNormalized(widget.property.seepageStatus);
    addNormalized(widget.property.electricalStatus);
    addNormalized(widget.property.meterStatus);
    addNormalized(widget.property.billsInfo);
    addNormalized(widget.property.tenantPreference);
    addNormalized(widget.property.petPolicy);
    addNormalized(widget.property.parkingInfo);
    addNormalized(widget.property.beds);
    addNormalized(widget.property.baths);
    addNormalized(widget.property.area);

    final List<String> result = [];
    final Set<String> seenResult = {};

    for (final feat in widget.property.features) {
      final trimmed = feat.trim();
      if (trimmed.isEmpty) continue;
      final lower = trimmed.toLowerCase();

      // Check if already shown in other sections
      bool isDuplicate = false;
      for (final shown in alreadyShown) {
        if (shown == lower || (shown.length > 3 && (shown.contains(lower) || lower.contains(shown)))) {
          isDuplicate = true;
          break;
        }
      }

      if (!isDuplicate && !seenResult.contains(lower)) {
        seenResult.add(lower);
        result.add(trimmed);
      }
    }

    return result;
  }

  Widget _buildFeaturesList(List<String> features) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: features.asMap().entries.map((entry) {
          int index = entry.key;
          String feature = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: index == features.length - 1 ? 0 : 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Iconsax.tick_circle, color: Colors.green, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    feature,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade800, height: 1.4),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReviewItem(dynamic review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(5, (index) {
                return Icon(
                  index < (review['rating'] as num).toInt() ? Iconsax.star1 : Iconsax.star,
                  color: Colors.amber,
                  size: 16,
                );
              }),
              const Spacer(),
              Text(
                review['date'] ?? '',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review['text'] ?? '',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          if (review['photos'] != null && (review['photos'] as List).isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: (review['photos'] as List).length,
                itemBuilder: (context, idx) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FullScreenImageViewer(
                              imageUrls: List<String>.from(review['photos']),
                              initialIndex: idx,
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: review['photos'][idx],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ]
        ],
      ),
    );
  }

  void _showAddReviewSheet() {
    int _rating = _myReview != null ? (_myReview!['rating'] as num).toInt() : 0;
    final TextEditingController _reviewController = TextEditingController(text: _myReview != null ? _myReview!['text'] : '');
    List<File> _selectedPhotos = [];
    bool _isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20, right: 20, top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Write a Review', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < _rating ? Iconsax.star1 : Iconsax.star,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed: () {
                          setModalState(() {
                            _rating = index + 1;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _reviewController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Share your experience...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          final picker = ImagePicker();
                          final pickedFiles = await picker.pickMultiImage();
                          if (pickedFiles.isNotEmpty) {
                            setModalState(() {
                              _selectedPhotos.addAll(pickedFiles.map((e) => File(e.path)));
                            });
                          }
                        },
                        icon: const Icon(Iconsax.camera),
                        label: const Text('Add Photos'),
                      ),
                    ],
                  ),
                  if (_myReview != null && _myReview!['photos'] != null && _myReview!['photos'].isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0, bottom: 4.0),
                      child: Text('Existing Photos:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                    SizedBox(
                      height: 60,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: (_myReview!['photos'] as List).length,
                        itemBuilder: (context, idx) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: _myReview!['photos'][idx],
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        (_myReview!['photos'] as List).removeAt(idx);
                                      });
                                    },
                                    child: Container(
                                      color: Colors.black54,
                                      child: const Icon(Iconsax.close_circle, color: Colors.white, size: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_selectedPhotos.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4.0),
                      child: Text('New Photos:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 60,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedPhotos.length,
                        itemBuilder: (context, idx) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(_selectedPhotos[idx], width: 60, height: 60, fit: BoxFit.cover),
                                ),
                                Positioned(
                                  right: 0, top: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        _selectedPhotos.removeAt(idx);
                                      });
                                    },
                                    child: Container(
                                      color: Colors.black54,
                                      child: const Icon(Iconsax.close_circle, color: Colors.white, size: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () async {
                              if (_reviewController.text.trim().isEmpty) {
                                AppSnackbar.error(context, 'Please enter a review');
                                return;
                              }
                              setModalState(() => _isSubmitting = true);

                              try {
                                final supabase = Supabase.instance.client;
                                List<String> photoUrls = _myReview != null ? List<String>.from(_myReview!['photos'] ?? []) : [];
                                
                                if (_selectedPhotos.isNotEmpty) {
                                  for (var file in _selectedPhotos) {
                                    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
                                    await supabase.storage.from('property_images').upload(fileName, file);
                                    final url = supabase.storage.from('property_images').getPublicUrl(fileName);
                                    photoUrls.add(url);
                                  }
                                }

                                final newReview = {
                                  'rating': _rating,
                                  'text': _reviewController.text.trim(),
                                  'photos': photoUrls,
                                  'date': DateTime.now().toIso8601String().split('T').first,
                                  'device_id': _deviceId,
                                };

                                final updatedReviews = List<dynamic>.from(widget.property.reviews);
                                if (_hasReviewed && _myReview != null) {
                                  final index = updatedReviews.indexWhere((r) => r['device_id'] == _deviceId || r == _myReview);
                                  if (index != -1) {
                                    updatedReviews[index] = newReview;
                                  } else {
                                    updatedReviews.add(newReview);
                                  }
                                } else {
                                  updatedReviews.add(newReview);
                                }

                                await supabase
                                    .from('properties')
                                    .update({'reviews': updatedReviews})
                                    .eq('id', widget.property.id!);

                                final prefs = await SharedPreferences.getInstance();
                                final reviewedProps = prefs.getStringList('reviewed_properties') ?? [];
                                if (widget.property.id != null && !reviewedProps.contains(widget.property.id)) {
                                  reviewedProps.add(widget.property.id!);
                                  await prefs.setStringList('reviewed_properties', reviewedProps);
                                }

                                setState(() {
                                  widget.property.reviews = updatedReviews;
                                  _myReview = newReview;
                                  _hasReviewed = true;
                                });

                                Navigator.pop(context);
                                AppSnackbar.success(context, _hasReviewed ? 'Review updated successfully!' : 'Review added successfully!');
                              } catch (e) {
                                AppSnackbar.error(context, 'Failed to save review: $e');
                              } finally {
                                setModalState(() => _isSubmitting = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                          : const Text('Submit Review'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showContributePhotosSheet() {
    List<File> _suggestedPhotos = [];
    bool _isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Contribute Photos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Help others by adding more photos of this property. Your photos will appear after admin approval.',
                      style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 24),
                  
                  if (_suggestedPhotos.isNotEmpty) ...[
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _suggestedPhotos.length,
                        itemBuilder: (context, idx) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(_suggestedPhotos[idx], width: 80, height: 80, fit: BoxFit.cover),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        _suggestedPhotos.removeAt(idx);
                                      });
                                    },
                                    child: Container(
                                      color: Colors.black54,
                                      child: const Icon(Iconsax.close_circle, color: Colors.white, size: 18),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  OutlinedButton.icon(
                    onPressed: () async {
                      final ImagePicker picker = ImagePicker();
                      final List<XFile> images = await picker.pickMultiImage();
                      if (images.isNotEmpty) {
                        setModalState(() {
                          _suggestedPhotos.addAll(images.map((img) => File(img.path)));
                        });
                      }
                    },
                    icon: const Icon(Iconsax.gallery_add, color: Colors.black),
                    label: const Text('Select Photos', style: TextStyle(color: Colors.black)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.black, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _suggestedPhotos.isEmpty || _isSubmitting
                          ? null
                          : () async {
                              setModalState(() => _isSubmitting = true);
                              try {
                                final supabase = Supabase.instance.client;
                                List<Map<String, dynamic>> newSuggestions = [];

                                for (var file in _suggestedPhotos) {
                                  final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
                                  await supabase.storage.from('property_images').upload(fileName, file);
                                  final url = supabase.storage.from('property_images').getPublicUrl(fileName);
                                  newSuggestions.add({
                                    'url': url,
                                    'status': 'pending',
                                    'device_id': _deviceId,
                                    'date': DateTime.now().toIso8601String().split('T').first,
                                  });
                                }

                                final updatedSuggestions = List<dynamic>.from(widget.property.suggestedPhotos)..addAll(newSuggestions);

                                await supabase
                                    .from('properties')
                                    .update({'suggested_photos': updatedSuggestions})
                                    .eq('id', widget.property.id!);

                                setState(() {
                                  widget.property.suggestedPhotos = updatedSuggestions;
                                });

                                Navigator.pop(context);
                                AppSnackbar.success(context, 'Photos submitted for approval!');
                              } catch (e) {
                                AppSnackbar.error(context, 'Failed to submit photos: $e');
                              } finally {
                                setModalState(() => _isSubmitting = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Submit Photos', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
