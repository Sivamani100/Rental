import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image/image.dart' as img;
import '../widgets/app_snackbar.dart';
import 'home_screen.dart' show PropertyModel;

class PostBottomSheet extends StatefulWidget {
  final Position? currentLocation;
  final Function(PropertyModel)? onPropertyCreated;
  final PropertyModel? propertyToEdit;

  const PostBottomSheet({
    super.key,
    this.currentLocation,
    this.onPropertyCreated,
    this.propertyToEdit,
  });

  @override
  State<PostBottomSheet> createState() => _PostBottomSheetState();
}

class _PostBottomSheetState extends State<PostBottomSheet> {
  int _currentStep = 1;
  static const int _totalSteps = 6;
  String _selectedType = 'Rental'; // 'Rental' or 'PG'
  
  List<String> _existingImages = [];
  bool get _isEditing => widget.propertyToEdit != null;

  // Image & Basic Info
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _selectedImages = [];
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _depositController = TextEditingController();
  final TextEditingController _maintenanceController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _perDayWithFoodController = TextEditingController();
  final TextEditingController _perDayWithoutFoodController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();

  // Location & Submission State
  bool _isLoadingLocation = false;
  bool _isSubmitting = false;
  String _locationAddress = '';
  double _latitude = 17.6868;
  double _longitude = 83.2185;

  // --- PG Specific State ---
  String _pgGender = 'Boys Only';
  String _pgSharing = '2 Sharing';
  String _pgAcType = 'AC Room';
  String _pgBathroom = 'Attached Bathroom';
  String _pgToiletType = 'Western Toilet';
  String _pgFoodPlan = '3 Meals Included';
  String _pgFoodType = 'Veg & Non-Veg';
  String _pgWaterSupply = '24/7 Continuous Water Supply';
  String _pgDrinkingWater = 'RO Purified + Cool Water Dispenser';
  String _pgPowerBackup = 'Full Inverter Power Backup';
  String _pgCleaning = 'Daily Room & Bathroom Cleaning';
  String _pgCurfew = '10:30 PM Gate Close';
  String _pgNotice = '15 Days';
  String _pgManagement = 'Owner on site & Resident Warden';

  final Set<String> _pgSelectedAmenities = {
    'Bed & Mattress',
    'Personal Cupboard',
    'High-Speed Wi-Fi',
    'Washing Machine',
    '24/7 Hot Water Geyser',
    'Common Refrigerator',
    '24/7 CCTV & Security',
    'Police & ID Verification',
    'Hall TV with OTT',
  };

  // --- Rental Specific State ---
  String _rentalBhk = '2 BHK';
  String _rentalFurnishing = 'Semi-Furnished';
  String _rentalBeds = '2 Beds';
  String _rentalBaths = '2 Baths';
  String _rentalArea = '1200';
  String _rentalFloor = '2nd Floor';
  String _rentalTotalFloors = '4 Floors';
  String _rentalAgreement = '11 Months Standard';
  String _rentalNotice = '1 Month';
  String _rentalWaterBill = 'Included in Maintenance';
  String _rentalEbMeter = 'Dedicated EB Digital Meter';
  String _rentalTenantPref = 'Family & Working Professionals';
  String _rentalPetPolicy = 'Pets Allowed';
  String _rentalParking = 'Covered Car & Bike Parking';

  final Set<String> _rentalSelectedFeatures = {
    'All Taps & Showers Tested',
    'Zero Seepage & Freshly Painted',
    'All Switches & Sockets Checked',
    'Geyser in Bathrooms',
    '24/7 Municipal & Borewell Water',
    'Inverter Wiring Ready',
    'Lift Available',
    'Gated Security',
    'Balcony',
  };

  @override
  void initState() {
    super.initState();
    if (widget.currentLocation != null) {
      _latitude = widget.currentLocation!.latitude;
      _longitude = widget.currentLocation!.longitude;
    }

    if (_isEditing) {
      final p = widget.propertyToEdit!;
      _selectedType = p.type;
      _titleController.text = p.title;
      _priceController.text = p.price.replaceAll(RegExp(r'[^0-9]'), '');
      _depositController.text = p.securityDeposit?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
      _maintenanceController.text = p.maintenanceCharges?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
      _addressController.text = p.locationStr;
      _phoneController.text = p.ownerPhone;
      _whatsappController.text = p.ownerWhatsapp ?? '';
      _descriptionController.text = p.description ?? '';
      _perDayWithFoodController.text = p.perDayWithFood ?? '';
      _perDayWithoutFoodController.text = p.perDayWithoutFood ?? '';
      _existingImages = List.from(p.imageUrls);
      _latitude = p.latitude;
      _longitude = p.longitude;
      
      if (p.type == 'PG') {
        _pgGender = p.genderPreference ?? _pgGender;
        _pgSharing = p.sharingType ?? _pgSharing;
        _pgAcType = p.acType ?? _pgAcType;
        _pgBathroom = p.bathroomType ?? _pgBathroom;
        _pgCleaning = p.cleanlinessInfo ?? _pgCleaning;
        _pgFoodPlan = p.foodDetails ?? _pgFoodPlan;
        _pgFoodType = p.foodQuality ?? _pgFoodType;
        _pgWaterSupply = p.waterSupply ?? _pgWaterSupply;
        _pgDrinkingWater = p.drinkingWater ?? _pgDrinkingWater;
        _pgPowerBackup = p.powerBackup ?? _pgPowerBackup;
        _pgCurfew = p.gateRules ?? _pgCurfew;
        _pgNotice = p.noticePeriod ?? _pgNotice;
        _pgManagement = p.managementInfo ?? _pgManagement;
        _pgSelectedAmenities.clear();
        _pgSelectedAmenities.addAll(p.features);
      } else {
        _rentalBhk = p.bhkType ?? _rentalBhk;
        _rentalFurnishing = p.furnishingStatus ?? _rentalFurnishing;
        _rentalBeds = p.beds.isNotEmpty ? p.beds : _rentalBeds;
        _rentalBaths = p.baths.isNotEmpty ? p.baths : _rentalBaths;
        _rentalArea = p.area.isNotEmpty ? p.area.replaceAll(RegExp(r'[^0-9]'), '') : _rentalArea;
        _rentalAgreement = p.agreementDuration ?? _rentalAgreement;
        _rentalNotice = p.noticePeriod ?? _rentalNotice;
        _rentalWaterBill = p.billsInfo ?? _rentalWaterBill;
        _rentalEbMeter = p.meterStatus ?? _rentalEbMeter;
        _rentalTenantPref = p.tenantPreference ?? _rentalTenantPref;
        _rentalPetPolicy = p.petPolicy ?? _rentalPetPolicy;
        _rentalParking = p.parkingInfo ?? _rentalParking;
        _rentalSelectedFeatures.clear();
        _rentalSelectedFeatures.addAll(p.features);
      }
    }
    
    _latController.text = _latitude.toString();
    _lngController.text = _longitude.toString();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _depositController.dispose();
    _maintenanceController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _descriptionController.dispose();
    _perDayWithFoodController.dispose();
    _perDayWithoutFoodController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Failed to pick images');
      }
    }
  }

  Future<void> _grabCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
      );
      List<Placemark> placemarks = await Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      String areaName = '';
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        areaName = '${place.subLocality ?? place.locality ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}'.trim().replaceAll(RegExp(r'^,\s*'), '');
      }

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _latController.text = _latitude.toString();
        _lngController.text = _longitude.toString();
        _locationAddress = areaName.isNotEmpty ? areaName : 'Lat: ${position.latitude}, Lng: ${position.longitude}';
        _addressController.text = _locationAddress;
      });
      if (mounted) {
        AppSnackbar.success(context, 'Location pinned successfully!');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Failed to get location. Enter address manually.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  void _submitProperty() {
    if (_titleController.text.trim().isEmpty) {
      AppSnackbar.error(context, 'Please enter a property title');
      setState(() => _currentStep = 2);
      return;
    }
    if (_priceController.text.trim().isEmpty) {
      AppSnackbar.error(context, 'Please enter monthly rent');
      setState(() => _currentStep = 2);
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      AppSnackbar.error(context, 'Please provide owner contact number');
      return;
    }

    final isPg = _selectedType == 'PG';
    final List<String> tags = [];
    final List<String> features = [];

    if (isPg) {
      tags.add(_pgGender);
      tags.add(_pgSharing);
      if (_pgFoodPlan.contains('Included')) tags.add('Food Included');
      if (_pgAcType.contains('AC')) tags.add(_pgAcType);
      tags.addAll(_pgSelectedAmenities.take(2));

      features.addAll(_pgSelectedAmenities);
    } else {
      tags.add(_rentalBhk);
      tags.add(_rentalFurnishing);
      tags.add(_rentalParking);
      tags.addAll(_rentalSelectedFeatures.take(2));

      features.addAll(_rentalSelectedFeatures);
    }

    final newProperty = PropertyModel(
      title: _titleController.text.trim(),
      price: '₹${_priceController.text.trim()}/m',
      locationStr: _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : (_locationAddress.isNotEmpty ? _locationAddress : 'Visakhapatnam, Andhra Pradesh'),
      latitude: double.tryParse(_latController.text.trim()) ?? _latitude,
      longitude: double.tryParse(_lngController.text.trim()) ?? _longitude,
      imageUrls: _selectedImages.isNotEmpty
          ? _selectedImages.map((f) => f.path).toList()
          : [
              isPg
                  ? 'https://images.unsplash.com/photo-1555854877-bab0e564b8d5?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
                  : 'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
            ],
      tags: tags.toSet().toList(),
      beds: isPg ? _pgSharing : _rentalBeds,
      baths: isPg ? _pgBathroom : _rentalBaths,
      area: isPg ? '180sqft' : '${_rentalArea.isNotEmpty ? _rentalArea : '1200'}sqft',
      type: isPg ? 'PG' : 'Rental',
      ownerPhone: _phoneController.text.trim(),
      ownerWhatsapp: _whatsappController.text.trim().isNotEmpty
          ? _whatsappController.text.trim()
          : _phoneController.text.trim(),
      features: features.toSet().toList(),
      securityDeposit: _depositController.text.trim().isNotEmpty ? '₹${_depositController.text.trim()}' : null,
      maintenanceCharges: _maintenanceController.text.trim().isNotEmpty ? '₹${_maintenanceController.text.trim()}' : 'Included',
      noticePeriod: isPg ? _pgNotice : _rentalNotice,
      agreementDuration: isPg ? 'Flexible Monthly' : _rentalAgreement,
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : (isPg
              ? 'Well maintained PG with delicious meals, high-speed Wi-Fi, 24/7 security, and clean housekeeping.'
              : 'Spacious well ventilated property with quality fittings, zero seepage, good water & power supply.'),
      // PG specifics
      genderPreference: isPg ? _pgGender : null,
      sharingType: isPg ? _pgSharing : null,
      foodDetails: isPg ? '$_pgFoodPlan ($_pgFoodType)' : null,
      drinkingWater: isPg ? _pgDrinkingWater : null,
      waterSupply: isPg ? _pgWaterSupply : null,
      powerBackup: isPg ? _pgPowerBackup : null,
      acType: isPg ? _pgAcType : null,
      bathroomType: isPg ? '$_pgBathroom ($_pgToiletType)' : null,
      cleanlinessInfo: isPg ? _pgCleaning : null,
      securityInfo: isPg ? '24/7 CCTV & Gated Security' : null,
      verificationPolicy: isPg ? 'Police & ID Verification Mandatory' : null,
      managementInfo: isPg ? _pgManagement : null,
      gateRules: isPg ? _pgCurfew : null,
      perDayWithFood: isPg && _perDayWithFoodController.text.trim().isNotEmpty ? _perDayWithFoodController.text.trim() : null,
      perDayWithoutFood: isPg && _perDayWithoutFoodController.text.trim().isNotEmpty ? _perDayWithoutFoodController.text.trim() : null,
      // Rental specifics
      bhkType: !isPg ? _rentalBhk : null,
      furnishingStatus: !isPg ? _rentalFurnishing : null,
      plumbingStatus: null,
      seepageStatus: null,
      electricalStatus: null,
      meterStatus: !isPg ? _rentalEbMeter : null,
      billsInfo: !isPg ? (_rentalWaterBill.isNotEmpty ? '$_rentalEbMeter, Water: $_rentalWaterBill' : _rentalEbMeter) : null,
      tenantPreference: !isPg ? _rentalTenantPref : null,
      petPolicy: !isPg ? _rentalPetPolicy : null,
      parkingInfo: !isPg ? _rentalParking : null,
      status: _isEditing ? widget.propertyToEdit!.status : 'approved',
    );

    _uploadAndSaveProperty(newProperty);
  }

  Future<void> _uploadAndSaveProperty(PropertyModel newProperty) async {
    setState(() => _isSubmitting = true);
    try {
      final supabase = Supabase.instance.client;
      List<String> uploadedUrls = List.from(_existingImages);

      // 1. Load watermark once
      img.Image? watermarkImage;
      try {
        final ByteData watermarkData = await rootBundle.load('assets/watermarkofrental.png');
        watermarkImage = img.decodeImage(watermarkData.buffer.asUint8List());
      } catch (e) {
        debugPrint('Failed to load watermark: $e');
      }

      for (var file in _selectedImages) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        final originalBytes = await file.readAsBytes();
        
        Uint8List bytesToUpload = originalBytes;
        
        // Apply watermark if possible
        if (watermarkImage != null) {
          final originalImg = img.decodeImage(originalBytes);
          if (originalImg != null) {
            // Scale watermark to be reasonable relative to the image
            // E.g., make it 25% of the image width
            int targetWatermarkWidth = (originalImg.width * 0.25).toInt().clamp(50, 800);
            img.Image scaledWatermark = img.copyResize(watermarkImage, width: targetWatermarkWidth);
            
            // Bottom Right with 20px padding
            int padding = 20;
            int dstX = originalImg.width - scaledWatermark.width - padding;
            int dstY = originalImg.height - scaledWatermark.height - padding;
            
            // Apply overlay
            img.compositeImage(originalImg, scaledWatermark, dstX: dstX, dstY: dstY);
            
            // Re-encode to JPG
            bytesToUpload = Uint8List.fromList(img.encodeJpg(originalImg, quality: 85));
          }
        }
        
        // Upload the bytes
        await supabase.storage.from('property_images').uploadBinary(
          fileName, 
          bytesToUpload,
          fileOptions: const FileOptions(contentType: 'image/jpeg')
        );
        
        final url = supabase.storage.from('property_images').getPublicUrl(fileName);
        uploadedUrls.add(url);
      }

      // Merge URLs
      final propertyJson = newProperty.toJson();
      if (uploadedUrls.isNotEmpty) {
        propertyJson['image_urls'] = uploadedUrls;
      }

      if (_isEditing) {
        await supabase.from('properties').update(propertyJson).eq('id', widget.propertyToEdit!.id!);
      } else {
        await supabase.from('properties').insert(propertyJson);
      }

      if (mounted) {
        widget.onPropertyCreated?.call(newProperty); // Optional if using refresh
        Navigator.pop(context);
        AppSnackbar.success(context, _isEditing ? 'Property updated successfully!' : '$_selectedType property posted successfully!');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Failed to post property: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double maxDialogHeight = MediaQuery.of(context).size.height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxDialogHeight),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Step indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isEditing ? 'Edit ${_selectedType == "PG" ? "PG / Hostel" : "Rental Property"}' : 'Post ${_selectedType == "PG" ? "PG / Hostel" : "Rental Property"}',
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Step $_currentStep of $_totalSteps: ${_getStepTitle()}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Iconsax.close_circle),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Step Progress Indicator Bar
          Row(
            children: List.generate(_totalSteps, (index) {
              final stepIndex = index + 1;
              final isPassed = stepIndex <= _currentStep;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: isPassed ? Colors.black : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _buildStepContent(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildActionButtons(),
        ],
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 1:
        return 'Property Type';
      case 2:
        return 'Photos & Basic Info';
      case 3:
        return _selectedType == 'PG' ? 'Room, Sharing & In-Room Amenities' : 'Space, BHK & Physical Condition';
      case 4:
        return _selectedType == 'PG' ? 'Food, Mess & Utilities' : 'Water, Metering & Bills';
      case 5:
        return _selectedType == 'PG' ? 'Security, Hygiene & Rules' : 'Agreement, Policies & Guidelines';
      case 6:
        return 'Owner Contact & Review';
      default:
        return '';
    }
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildStep1TypeSelection();
      case 2:
        return _buildStep2PhotosAndBasics();
      case 3:
        return _selectedType == 'PG' ? _buildStep3PgRooms() : _buildStep3RentalSpace();
      case 4:
        return _selectedType == 'PG' ? _buildStep4PgFoodAndUtilities() : _buildStep4RentalUtilitiesAndBills();
      case 5:
        return _selectedType == 'PG' ? _buildStep5PgSecurityAndRules() : _buildStep5RentalAgreementAndRules();
      case 6:
        return _buildStep6ContactAndReview();
      default:
        return const SizedBox.shrink();
    }
  }

  // ==========================================
  // ACTION BUTTONS
  // ==========================================
  Widget _buildActionButtons() {
    return Row(
      children: [
        if (_currentStep > 1)
          Expanded(
            child: OutlinedButton(
              onPressed: _isSubmitting ? null : () => setState(() => _currentStep--),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                side: const BorderSide(color: Colors.black, width: 1.5),
              ),
              child: const Text('Back', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        if (_currentStep > 1) const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isSubmitting
                ? null
                : () {
                    if (_currentStep < _totalSteps) {
                      setState(() => _currentStep++);
                    } else {
                      _submitProperty();
                    }
                  },
            style: ElevatedButton.styleFrom(
              // Inherits from global theme
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: _isSubmitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                    _currentStep == _totalSteps ? 'Post Property' : 'Next Step',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STEP 1: PROPERTY TYPE
  // ==========================================
  Widget _buildStep1TypeSelection() {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What type of property are you posting?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        _buildTypeCard(
          title: 'Rental House / Flat',
          subtitle: 'Independent houses, apartments, flats, or villas for family & bachelors.',
          typeKey: 'Rental',
          imagePath: 'assets/rentalimage.png',
          icon: Iconsax.home_2,
        ),
        const SizedBox(height: 16),
        _buildTypeCard(
          title: 'PG / Co-Living / Hostel',
          subtitle: 'Paying guest accommodations, hostels with food, Wi-Fi, sharing rooms & warden.',
          typeKey: 'PG',
          imagePath: 'assets/pgimage.png',
          icon: Iconsax.building_3,
        ),
      ],
    );
  }

  Widget _buildTypeCard({
    required String title,
    required String subtitle,
    required String typeKey,
    required String imagePath,
    required IconData icon,
  }) {
    final bool isSelected = _selectedType == typeKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = typeKey;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey.shade300,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                imagePath,
                width: 90,
                height: 90,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 90,
                  height: 90,
                  color: Colors.grey.shade200,
                  child: Icon(icon, size: 36, color: Colors.black54),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 18, color: isSelected ? Colors.black : Colors.grey.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.black : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Icon(
              isSelected ? Iconsax.tick_circle : Iconsax.record,
              color: isSelected ? Colors.black : Colors.grey.shade300,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // STEP 2: PHOTOS & BASIC DETAILS
  // ==========================================
  Widget _buildStep2PhotosAndBasics() {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Upload Photos', Iconsax.camera),
        const SizedBox(height: 8),
        _selectedImages.isEmpty && _existingImages.isEmpty
            ? GestureDetector(
                onTap: _pickImages,
                child: Container(
                  height: 130,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300, width: 1.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Iconsax.camera, size: 36, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text('Tap to Upload Photos', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 14)),
                      Text('Add clear photos of room, bath & hall', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                    ],
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_existingImages.length + _selectedImages.length} Photos Selected', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      TextButton.icon(
                        onPressed: _pickImages,
                        icon: const Icon(Iconsax.gallery_add, size: 18, color: Colors.black),
                        label: const Text('Add More', style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 90,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _existingImages.length + _selectedImages.length,
                      itemBuilder: (context, index) {
                        final isExisting = index < _existingImages.length;
                        return Stack(
                          children: [
                            Container(
                              width: 90,
                              height: 90,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                image: DecorationImage(
                                  image: isExisting 
                                      ? NetworkImage(_existingImages[index]) as ImageProvider
                                      : (kIsWeb 
                                          ? NetworkImage(_selectedImages[index - _existingImages.length].path) as ImageProvider 
                                          : FileImage(File(_selectedImages[index - _existingImages.length].path)) as ImageProvider),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 14,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (isExisting) {
                                      _existingImages.removeAt(index);
                                    } else {
                                      _selectedImages.removeAt(index - _existingImages.length);
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                                  child: const Icon(Iconsax.close_circle, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
        const SizedBox(height: 20),
        _buildSectionHeader('Basic Pricing & Location', Iconsax.wallet_3),
        const SizedBox(height: 12),
        _buildCustomInput(
          controller: _titleController,
          label: 'Property Title',
          hint: _selectedType == 'PG' ? 'e.g. Deluxe Boys PG - MVP Colony' : 'e.g. 2BHK House - Srinivasa Nagar',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildCustomInput(
                controller: _priceController,
                label: _selectedType == 'PG' ? 'Monthly Fee / Rent (₹)' : 'Monthly Rent (₹)',
                hint: 'e.g. 5500',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCustomInput(
                controller: _depositController,
                label: 'Security Deposit (₹)',
                hint: 'e.g. 5000',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        if (_selectedType == 'PG') ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCustomInput(
                  controller: _perDayWithFoodController,
                  label: 'Per Day (With Food) ₹',
                  hint: 'e.g. 300',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCustomInput(
                  controller: _perDayWithoutFoodController,
                  label: 'Per Day (Without Food) ₹',
                  hint: 'e.g. 200',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        _buildCustomInput(
          controller: _maintenanceController,
          label: 'Maintenance / Extra Charges (Optional)',
          hint: 'e.g. 500 (or leave blank if included)',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 14),
        const Text('Location & Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _locationAddress.isEmpty
            ? SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoadingLocation ? null : _grabCurrentLocation,
                  icon: _isLoadingLocation
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Iconsax.location5, color: Colors.black, size: 18),
                  label: Text(
                    _isLoadingLocation ? 'Pinning GPS Location...' : 'Pin Current GPS Location',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    side: const BorderSide(color: Colors.black),
                  ),
                ),
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.location5, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_locationAddress, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        _locationAddress = '';
                        _addressController.clear();
                      }),
                      child: const Icon(Iconsax.close_circle, color: Colors.redAccent, size: 18),
                    ),
                  ],
                ),
              ),
        const SizedBox(height: 10),
        _buildCustomInput(
          controller: _addressController,
          label: 'Complete Address / Landmark',
          hint: 'e.g. Near Satyam Junction, MVP Colony, Visakhapatnam',
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildCustomInput(
                controller: _latController,
                label: 'Latitude',
                hint: 'e.g. 17.6868',
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCustomInput(
                controller: _lngController,
                label: 'Longitude',
                hint: 'e.g. 83.2185',
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // STEP 3 (PG): ROOMS, OCCUPANCY & ESSENTIALS
  // ==========================================
  Widget _buildStep3PgRooms() {
    return Column(
      key: const ValueKey('pg_step3'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Occupancy & Gender Preference', Iconsax.profile_2user),
        const SizedBox(height: 10),
        _buildSingleSelectGroup(
          options: ['Boys Only', 'Girls Only', 'Co-Living (Unisex)'],
          selected: _pgGender,
          onSelected: (val) => setState(() => _pgGender = val),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Room Sharing Type', Iconsax.category),
        const SizedBox(height: 10),
        _buildSingleSelectGroup(
          options: ['Single Room', '2 Sharing', '3 Sharing', '4+ Sharing'],
          selected: _pgSharing,
          onSelected: (val) => setState(() => _pgSharing = val),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Air Conditioning / Climate', Iconsax.wind_2),
        const SizedBox(height: 10),
        _buildSingleSelectGroup(
          options: ['AC Room', 'Non-AC Room', 'Air Cooler Provided'],
          selected: _pgAcType,
          onSelected: (val) => setState(() => _pgAcType = val),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Bathroom Setup', Iconsax.drop),
        const SizedBox(height: 10),
        _buildSingleSelectGroup(
          options: ['Attached Bathroom', 'Common Bathroom (Cleaned Daily)'],
          selected: _pgBathroom,
          onSelected: (val) => setState(() => _pgBathroom = val),
        ),
        const SizedBox(height: 10),
        _buildSingleSelectGroup(
          options: ['Western Toilet', 'Indian Toilet', 'Both Available'],
          selected: _pgToiletType,
          onSelected: (val) => setState(() => _pgToiletType = val),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('In-Room Furnishings & Essentials', Iconsax.lamp_on),
        const SizedBox(height: 10),
        _buildMultiSelectChips(
          options: [
            'Bed & Mattress',
            'Personal Cupboard',
            'Study Table & Chair',
            '24/7 Hot Water Geyser',
            'Balcony / Ventilated Window',
            'Ceiling Fan & LED Tube',
            'Mirror & Charging Sockets',
            'Shoe Rack',
          ],
          selectedSet: _pgSelectedAmenities,
        ),
      ],
    );
  }

  // ==========================================
  // STEP 3 (RENTAL): SPACE & PHYSICAL CONDITION
  // ==========================================
  Widget _buildStep3RentalSpace() {
    return Column(
      key: const ValueKey('rental_step3'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('BHK Configuration', Iconsax.home),
        const SizedBox(height: 10),
        _buildSingleSelectGroup(
          options: ['1 RK', '1 BHK', '2 BHK', '3 BHK', '4+ BHK / Villa'],
          selected: _rentalBhk,
          onSelected: (val) => setState(() {
            _rentalBhk = val;
            if (val == '1 RK' || val == '1 BHK') {
              _rentalBeds = '1 Bed';
              _rentalBaths = '1 Bath';
            } else if (val == '2 BHK') {
              _rentalBeds = '2 Beds';
              _rentalBaths = '2 Baths';
            } else if (val == '3 BHK') {
              _rentalBeds = '3 Beds';
              _rentalBaths = '3 Baths';
            }
          }),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Furnishing Status', Iconsax.box),
        const SizedBox(height: 10),
        _buildSingleSelectGroup(
          options: ['Unfurnished', 'Semi-Furnished', 'Fully-Furnished'],
          selected: _rentalFurnishing,
          onSelected: (val) => setState(() => _rentalFurnishing = val),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Space & Floor Details', Iconsax.maximize_45),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildCustomInput(
                initialValue: _rentalArea,
                label: 'Carpet Area (sqft)',
                hint: 'e.g. 1250',
                keyboardType: TextInputType.number,
                onChanged: (val) => _rentalArea = val,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCustomInput(
                initialValue: _rentalBeds,
                label: 'Bedrooms',
                hint: 'e.g. 2 Beds',
                onChanged: (val) => _rentalBeds = val,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCustomInput(
                initialValue: _rentalBaths,
                label: 'Bathrooms',
                hint: 'e.g. 2 Baths',
                onChanged: (val) => _rentalBaths = val,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildCustomInput(
                initialValue: _rentalFloor,
                label: 'Property Floor',
                hint: 'e.g. 2nd Floor',
                onChanged: (val) => _rentalFloor = val,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCustomInput(
                initialValue: _rentalTotalFloors,
                label: 'Total Building Floors',
                hint: 'e.g. 4 Floors',
                onChanged: (val) => _rentalTotalFloors = val,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Physical Inspection Checklist', Iconsax.shield_tick),
        const SizedBox(height: 10),
        _buildMultiSelectChips(
          options: [
            'All Taps & Showers Tested',
            'High Water Pressure',
            'Zero Seepage & Freshly Painted',
            'Leak-Proof Ceiling & Walls',
            'All Switches & Sockets Checked',
            'Inverter Wiring Ready',
            'Geyser in Bathrooms',
            'Modular Kitchen Fitted',
            'Lift Available',
            'Balcony with View',
          ],
          selectedSet: _rentalSelectedFeatures,
        ),
      ],
    );
  }

  // ==========================================
  // STEP 4 (PG): FOOD, MESS, WATER & UTILITIES
  // ==========================================
  Widget _buildStep4PgFoodAndUtilities() {
    return Column(
      key: const ValueKey('pg_step4'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Food & Mess Plan', Iconsax.coffee),
        const SizedBox(height: 10),
        _buildSingleSelectGroup(
          options: [
            '3 Meals Included (Breakfast, Lunch, Dinner)',
            '2 Meals Included (Breakfast & Dinner)',
            'Food Optional / Extra Charge',
            'Self-Cooking Kitchen Access',
          ],
          selected: _pgFoodPlan,
          onSelected: (val) => setState(() => _pgFoodPlan = val),
        ),
        const SizedBox(height: 10),
        _buildSingleSelectGroup(
          options: ['Pure Veg Food', 'Veg & Non-Veg (Weekly)', 'Home-Style Cook'],
          selected: _pgFoodType,
          onSelected: (val) => setState(() => _pgFoodType = val),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Drinking Water & Water Supply', Iconsax.drop),
        const SizedBox(height: 10),
        _buildSingleSelectGroup(
          options: [
            'RO Purified + Cool Water Dispenser',
            '24/7 RO Purified Drinking Water',
            'Mineral Water Cans Provided',
          ],
          selected: _pgDrinkingWater,
          onSelected: (val) => setState(() => _pgDrinkingWater = val),
        ),
        const SizedBox(height: 10),
        _buildSingleSelectGroup(
          options: ['24/7 Continuous Water Supply', 'Timed Water Supply (Morning & Evening)'],
          selected: _pgWaterSupply,
          onSelected: (val) => setState(() => _pgWaterSupply = val),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Power Supply & Backup', Iconsax.flash_1),
        const SizedBox(height: 10),
        _buildSingleSelectGroup(
          options: [
            'Full Inverter Power Backup',
            'Diesel Generator Backup (100%)',
            'Standard 24/7 Electricity',
          ],
          selected: _pgPowerBackup,
          onSelected: (val) => setState(() => _pgPowerBackup = val),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Shared Appliances & Amenities', Iconsax.computing),
        const SizedBox(height: 10),
        _buildMultiSelectChips(
          options: [
            'High-Speed Wi-Fi',
            'Washing Machine',
            'Common Refrigerator',
            'Hall TV with OTT',
            'Microwave Oven',
            'Iron & Ironing Board',
            'Terrace Access',
            'Dedicated Study Lounge',
          ],
          selectedSet: _pgSelectedAmenities,
        ),
      ],
    );
  }

  // ==========================================
  // STEP 4 (RENTAL): WATER, METERING & BILLS
  // ==========================================
  Widget _buildStep4RentalUtilitiesAndBills() {
    return Column(
      key: const ValueKey('rental_step4'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Electricity Meter & Power', Iconsax.flash_1),
        const SizedBox(height: 10),
        _buildSingleSelectGroup(
          options: [
            'Dedicated EB Digital Meter',
            'Separate Sub-Meter',
            '3-Phase Connection',
          ],
          selected: _rentalEbMeter,
          onSelected: (val) => setState(() => _rentalEbMeter = val),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Water Supply & Drinking Line', Iconsax.drop),
        const SizedBox(height: 10),
        _buildSingleSelectGroup(
          options: [
            'Included in Maintenance',
            'Separate Water Bill',
            '24/7 Free Water Supply',
          ],
          selected: _rentalWaterBill,
          onSelected: (val) => setState(() => _rentalWaterBill = val),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Parking Facility', Iconsax.car),
        const SizedBox(height: 10),
        _buildSingleSelectGroup(
          options: [
            'Covered Car & Bike Parking',
            'Open Car Parking + Bike Parking',
            'Only Bike Parking',
            'No Parking',
          ],
          selected: _rentalParking,
          onSelected: (val) => setState(() => _rentalParking = val),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Utilities & Maintenance Checklist', Iconsax.tick_circle),
        const SizedBox(height: 10),
        _buildMultiSelectChips(
          options: [
            '24/7 Municipal & Borewell Water',
            'Overhead Water Storage Tank',
            'RO Drinking Water Line',
            'Solar Water Heater Installed',
            'Inverter Wiring Ready',
            'Modern MCB Fitted',
            'Gated Security Guard',
            'CCTV in Common Areas',
          ],
          selectedSet: _rentalSelectedFeatures,
        ),
      ],
    );
  }

  // ==========================================
  // STEP 5 (PG): SECURITY, HYGIENE & RULES
  // ==========================================
  Widget _buildStep5PgSecurityAndRules() {
    return Column(
      key: const ValueKey('pg_step5'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Cleanliness & Housekeeping', Iconsax.brush_1),
        const SizedBox(height: 10),
        _buildSingleSelectGroup(
          options: [
            'Daily Room & Bathroom Cleaning',
            'Alternate Day Cleaning',
            'Weekly Deep Cleaning',
          ],
          selected: _pgCleaning,
          onSelected: (val) => setState(() => _pgCleaning = val),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Owner & Warden Presence', Iconsax.user_tag),
        const SizedBox(height: 10),
        _buildSingleSelectGroup(
          options: [
            'Owner on site & Resident Warden',
            '24/7 Resident Warden Only',
            'Dedicated Caretaker on premises',
          ],
          selected: _pgManagement,
          onSelected: (val) => setState(() => _pgManagement = val),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Gate Timings & Curfew Rules', Iconsax.clock),
        const SizedBox(height: 10),
        _buildSingleSelectGroup(
          options: [
            '10:30 PM Gate Close',
            '10:00 PM Gate Close',
            '11:00 PM Gate Close',
            'No Curfew (24/7 Smart Access)',
          ],
          selected: _pgCurfew,
          onSelected: (val) => setState(() => _pgCurfew = val),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Notice Period for Vacating', Iconsax.calendar),
        const SizedBox(height: 10),
        _buildSingleSelectGroup(
          options: ['15 Days', '1 Month', 'No Lock-in'],
          selected: _pgNotice,
          onSelected: (val) => setState(() => _pgNotice = val),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Security & Verification Rules', Iconsax.security_user),
        const SizedBox(height: 10),
        _buildMultiSelectChips(
          options: [
            '24/7 CCTV & Security',
            'Police & ID Verification',
            'Biometric / Smart Entry',
            'Visitors Allowed in Common Lounge',
            'Strict No Smoking / Alcohol',
            'Parent Contact Verification',
          ],
          selectedSet: _pgSelectedAmenities,
        ),
      ],
    );
  }

  // ==========================================
  // STEP 5 (RENTAL): AGREEMENT & RULES
  // ==========================================
  Widget _buildStep5RentalAgreementAndRules() {
    return Column(
      key: const ValueKey('rental_step5'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Rental Agreement Duration', Iconsax.document_text),
        const SizedBox(height: 10),
        _buildSingleSelectGroup(
          options: [
            '11 Months Standard',
            '1 to 2 Years Agreement',
            'Flexible / No Lock-in',
          ],
          selected: _rentalAgreement,
          onSelected: (val) => setState(() => _rentalAgreement = val),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Notice Period for Vacating', Iconsax.calendar),
        const SizedBox(height: 10),
        _buildSingleSelectGroup(
          options: ['1 Month', '2 Months', '15 Days'],
          selected: _rentalNotice,
          onSelected: (val) => setState(() => _rentalNotice = val),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Tenant Preference', Iconsax.profile_2user),
        const SizedBox(height: 10),
        _buildSingleSelectGroup(
          options: [
            'Family & Working Professionals',
            'Family Only',
            'Bachelors Allowed',
            'Anyone Welcome',
          ],
          selected: _rentalTenantPref,
          onSelected: (val) => setState(() => _rentalTenantPref = val),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Pet Policy', Iconsax.heart),
        const SizedBox(height: 10),
        _buildSingleSelectGroup(
          options: ['Pets Allowed', 'No Pets Allowed'],
          selected: _rentalPetPolicy,
          onSelected: (val) => setState(() => _rentalPetPolicy = val),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('House Rules & Society Norms', Iconsax.info_circle),
        const SizedBox(height: 10),
        _buildMultiSelectChips(
          options: [
            'Non-Veg Allowed',
            'Veg Only Preferred',
            'Gated Security',
            'No Loud Music after 10 PM',
            'Visitor Parking Available',
          ],
          selectedSet: _rentalSelectedFeatures,
        ),
      ],
    );
  }

  // ==========================================
  // STEP 6: CONTACT & REVIEW
  // ==========================================
  Widget _buildStep6ContactAndReview() {
    return Column(
      key: const ValueKey(6),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Owner / Caretaker Contact', Iconsax.call),
        const SizedBox(height: 12),
        _buildCustomInput(
          controller: _phoneController,
          label: 'Primary Phone Number (For Calls)',
          hint: 'e.g. 9876543210',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        _buildCustomInput(
          controller: _whatsappController,
          label: 'WhatsApp Number (For Instant Chat)',
          hint: 'e.g. 9876543210 (leave blank if same)',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 14),
        _buildCustomInput(
          controller: _descriptionController,
          label: 'Detailed Description / Notes',
          hint: 'Highlight key benefits, nearby metro/bus stop, colleges, IT parks, etc.',
          maxLines: 3,
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Listing Summary Preview', Iconsax.eye),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _titleController.text.isNotEmpty ? _titleController.text : 'Property Title',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _selectedType,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '₹${_priceController.text.isNotEmpty ? _priceController.text : '0'}/month'
                '${_depositController.text.isNotEmpty ? " • Deposit: ₹${_depositController.text}" : ""}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 6),
              Text(
                _addressController.text.isNotEmpty
                    ? _addressController.text
                    : (_locationAddress.isNotEmpty ? _locationAddress : 'Location Pinned'),
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const Divider(height: 20),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: (_selectedType == 'PG'
                        ? [_pgGender, _pgSharing, _pgFoodPlan, _pgAcType, ..._pgSelectedAmenities.take(3)]
                        : [_rentalBhk, _rentalFurnishing, _rentalEbMeter, ..._rentalSelectedFeatures.take(3)])
                    .map((item) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(item, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // SHARED UI HELPER WIDGETS
  // ==========================================

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.black),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildCustomInput({
    TextEditingController? controller,
    String? initialValue,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.black, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleSelectGroup({
    required List<String> options,
    required String selected,
    required Function(String) onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final bool isSelected = opt == selected;
        return GestureDetector(
          onTap: () => onSelected(opt),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? Colors.black : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? Colors.black : Colors.grey.shade300,
              ),
            ),
            child: Text(
              opt,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMultiSelectChips({
    required List<String> options,
    required Set<String> selectedSet,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final bool isSelected = selectedSet.contains(opt);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                selectedSet.remove(opt);
              } else {
                selectedSet.add(opt);
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.black : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? Colors.black : Colors.grey.shade300,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  const Icon(Iconsax.tick_circle, color: Colors.white, size: 14),
                  const SizedBox(width: 5),
                ],
                Text(
                  opt,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade800,
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
