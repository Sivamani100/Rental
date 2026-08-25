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

class PropertyDetailsScreen extends StatefulWidget {
  final PropertyModel property;

  const PropertyDetailsScreen({super.key, required this.property});

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  int _currentImageIndex = 0;

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
      backgroundColor: Colors.white,
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
                            ? Image.network(
                                imagePath,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
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
                            icon: Icons.refresh,
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
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
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
                    
                    // Quick Stats Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

                    // SPECIFIC CATEGORY BREAKDOWNS (PG vs Rental)
                    if (widget.property.type == 'PG') ...[
                      // PG: Food, Water, Security, Hygiene
                      _buildSectionTitle('Food & Mess Plan', Iconsax.coffee),
                      const SizedBox(height: 8),
                      _buildInfoBox([
                        'Meal Plan: ${widget.property.foodDetails ?? "3 Meals Daily"}',
                        'Food Quality: ${widget.property.foodQuality ?? "Hygienic Home-Style Cook"}',
                        'Drinking Water: ${widget.property.drinkingWater ?? "RO Purified + Cool Water Dispenser"}',
                      ]),
                      const SizedBox(height: 20),

                      _buildSectionTitle('Utilities & Power Backup', Iconsax.flash_1),
                      const SizedBox(height: 8),
                      _buildInfoBox([
                        'Water Supply: ${widget.property.waterSupply ?? "24/7 Continuous Water"}',
                        'Power Backup: ${widget.property.powerBackup ?? "Full Inverter Backup"}',
                        'Hot Water: Geyser in Bathrooms / 24/7 Hot Water',
                      ]),
                      const SizedBox(height: 20),

                      _buildSectionTitle('Security, Hygiene & Rules', Iconsax.shield_tick),
                      const SizedBox(height: 8),
                      _buildInfoBox([
                        'Cleanliness: ${widget.property.cleanlinessInfo ?? "Daily Room & Bathroom Housekeeping"}',
                        'Security & CCTV: ${widget.property.securityInfo ?? "24/7 CCTV & Security Guard"}',
                        'Verification: ${widget.property.verificationPolicy ?? "Police & ID Verification Mandatory"}',
                        'Management: ${widget.property.managementInfo ?? "Resident Warden & Friendly Management"}',
                        'Gate Rules: ${widget.property.gateRules ?? "10:30 PM Gate Close"}',
                      ]),
                    ] else ...[
                      // Rental: Physical Condition, Metering & Bills, Rules
                      _buildSectionTitle('Plumbing & Physical Inspection', Iconsax.verify),
                      const SizedBox(height: 8),
                      _buildInfoBox([
                        'Plumbing Status: ${widget.property.plumbingStatus ?? "All Taps, Showers & Geysers Tested"}',
                        'Wall & Roof Condition: ${widget.property.seepageStatus ?? "Zero Seepage & Freshly Painted"}',
                        'Electrical & Wiring: ${widget.property.electricalStatus ?? "All Switches & Sockets Checked"}',
                        'Furnishing Status: ${widget.property.furnishingStatus ?? "Semi-Furnished"}',
                      ]),
                      const SizedBox(height: 20),

                      _buildSectionTitle('Water, Electricity & Bills', Iconsax.receipt_item),
                      const SizedBox(height: 8),
                      _buildInfoBox([
                        'EB Metering: ${widget.property.meterStatus ?? "Dedicated Digital EB Meter"}',
                        'Bills Policy: ${widget.property.billsInfo ?? "EB as per meter unit rate"}',
                        'Water Facility: 24/7 Municipal & Borewell Supply',
                        'Parking: ${widget.property.parkingInfo ?? "Covered Car & Bike Parking"}',
                      ]),
                      const SizedBox(height: 20),

                      _buildSectionTitle('Rental Agreement & House Rules', Iconsax.document_text),
                      const SizedBox(height: 8),
                      _buildInfoBox([
                        'Agreement Tenure: ${widget.property.agreementDuration ?? "11 Months Standard"}',
                        'Notice Period: ${widget.property.noticePeriod ?? "1 Month Notice"}',
                        'Tenant Preference: ${widget.property.tenantPreference ?? "Family & Working Professionals"}',
                        'Pet Policy: ${widget.property.petPolicy ?? "Pets Allowed"}',
                      ]),
                    ],
                    const SizedBox(height: 24),
                    
                    // Features & Amenities Chips
                    const Text(
                      'Features & Amenities',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.property.features.map((feature) {
                        return _buildAmenityChip(Iconsax.tick_circle, feature);
                      }).toList(),
                    ),
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
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
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
        children: [
          Icon(icon, size: 20, color: Colors.black87),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(Icons.circle, size: 6, color: Colors.black54),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(fontSize: 13.5, color: Colors.grey.shade800, height: 1.3),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAmenityChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: Colors.grey.shade800, fontSize: 12.5, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

