import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:lottie/lottie.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/bouncing_button.dart';
import '../theme/app_theme.dart';
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
  String? _sheetErrorMessage;
  String _locationAddress = '';
  double _latitude = 17.6868;
  double _longitude = 83.2185;

  void _showSheetError(String message) {
    setState(() => _sheetErrorMessage = message);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _sheetErrorMessage == message) {
        setState(() => _sheetErrorMessage = null);
      }
    });
  }

  // --- PG Specific State (Clean default: nothing pre-selected) ---
  String _pgGender = '';
  String _pgSharing = '';
  String _pgAcType = '';
  String _pgBathroom = '';
  String _pgToiletType = '';
  String _pgFoodPlan = '';
  String _pgFoodType = '';
  String _pgWaterSupply = '';
  String _pgDrinkingWater = '';
  String _pgPowerBackup = '';
  String _pgCleaning = '';
  String _pgCurfew = '';
  String _pgNotice = '';
  String _pgManagement = '';

  final Set<String> _pgSelectedAmenities = {};

  // --- Rental Specific State (Clean default: nothing pre-selected) ---
  String _rentalBhk = '';
  String _rentalFurnishing = '';
  String _rentalBeds = '';
  String _rentalBaths = '';
  String _rentalArea = '';
  String _rentalFloor = '';
  String _rentalTotalFloors = '';
  String _rentalAgreement = '';
  String _rentalNotice = '';
  String _rentalWaterBill = '';
  String _rentalEbMeter = '';
  String _rentalTenantPref = '';
  String _rentalPetPolicy = '';
  String _rentalParking = '';

  final Set<String> _rentalSelectedFeatures = {};

  // --- Buy / Sale Specific State ---
  String _buyPropertyType = '';
  String _buyBhk = '';
  String _buyFurnishing = '';
  String _buyBeds = '';
  String _buyBaths = '';
  String _buyPlotArea = '';
  String _buyBuiltUpArea = '';
  String _buyFacing = '';
  String _buyConstructionStatus = '';
  String _buyTotalFloors = '';
  String _buyOwnershipType = '';
  String _buyApprovals = '';
  String _buyRoadWidth = '';
  String _buyWaterElectricity = '';
  String _buyPriceNegotiable = '';
  String _buyParking = '';

  final Set<String> _buySelectedFeatures = {};

  // --- Draft State ---
  static const String _draftKey = 'posting_draft_v1';
  bool _hasDraftLoaded = false;

  Future<void> _saveDraft() async {
    if (_isEditing || _isSubmitting) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftData = {
        'currentStep': _currentStep,
        'selectedType': _selectedType,
        'title': _titleController.text,
        'price': _priceController.text,
        'deposit': _depositController.text,
        'maintenance': _maintenanceController.text,
        'address': _addressController.text,
        'locationAddress': _locationAddress,
        'latitude': _latitude,
        'longitude': _longitude,
        'latText': _latController.text,
        'lngText': _lngController.text,
        'phone': _phoneController.text,
        'whatsapp': _whatsappController.text,
        'description': _descriptionController.text,
        'perDayWithFood': _perDayWithFoodController.text,
        'perDayWithoutFood': _perDayWithoutFoodController.text,
        'imagePaths': _selectedImages.map((f) => f.path).toList(),
        // PG
        'pgGender': _pgGender,
        'pgSharing': _pgSharing,
        'pgAcType': _pgAcType,
        'pgBathroom': _pgBathroom,
        'pgToiletType': _pgToiletType,
        'pgFoodPlan': _pgFoodPlan,
        'pgFoodType': _pgFoodType,
        'pgWaterSupply': _pgWaterSupply,
        'pgDrinkingWater': _pgDrinkingWater,
        'pgPowerBackup': _pgPowerBackup,
        'pgCleaning': _pgCleaning,
        'pgCurfew': _pgCurfew,
        'pgNotice': _pgNotice,
        'pgManagement': _pgManagement,
        'pgSelectedAmenities': _pgSelectedAmenities.toList(),
        // Rental
        'rentalBhk': _rentalBhk,
        'rentalFurnishing': _rentalFurnishing,
        'rentalBeds': _rentalBeds,
        'rentalBaths': _rentalBaths,
        'rentalArea': _rentalArea,
        'rentalFloor': _rentalFloor,
        'rentalTotalFloors': _rentalTotalFloors,
        'rentalAgreement': _rentalAgreement,
        'rentalNotice': _rentalNotice,
        'rentalWaterBill': _rentalWaterBill,
        'rentalEbMeter': _rentalEbMeter,
        'rentalTenantPref': _rentalTenantPref,
        'rentalPetPolicy': _rentalPetPolicy,
        'rentalParking': _rentalParking,
        'rentalSelectedFeatures': _rentalSelectedFeatures.toList(),
        // Buy / Sale
        'buyPropertyType': _buyPropertyType,
        'buyBhk': _buyBhk,
        'buyFurnishing': _buyFurnishing,
        'buyBeds': _buyBeds,
        'buyBaths': _buyBaths,
        'buyPlotArea': _buyPlotArea,
        'buyBuiltUpArea': _buyBuiltUpArea,
        'buyFacing': _buyFacing,
        'buyConstructionStatus': _buyConstructionStatus,
        'buyTotalFloors': _buyTotalFloors,
        'buyOwnershipType': _buyOwnershipType,
        'buyApprovals': _buyApprovals,
        'buyRoadWidth': _buyRoadWidth,
        'buyWaterElectricity': _buyWaterElectricity,
        'buyPriceNegotiable': _buyPriceNegotiable,
        'buyParking': _buyParking,
        'buySelectedFeatures': _buySelectedFeatures.toList(),
      };
      await prefs.setString(_draftKey, jsonEncode(draftData));
    } catch (e) {
      debugPrint('Error saving draft: $e');
    }
  }

  Future<void> _loadDraft() async {
    if (_isEditing) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftStr = prefs.getString(_draftKey);
      if (draftStr != null && draftStr.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(draftStr);
        if (mounted) {
          setState(() {
            _selectedType = data['selectedType'] ?? 'Rental';
            _currentStep = (data['currentStep'] as num?)?.toInt() ?? 1;
            _titleController.text = data['title'] ?? '';
            _priceController.text = data['price'] ?? '';
            _depositController.text = data['deposit'] ?? '';
            _maintenanceController.text = data['maintenance'] ?? '';
            _addressController.text = data['address'] ?? '';
            _locationAddress = data['locationAddress'] ?? '';
            _latitude = (data['latitude'] as num?)?.toDouble() ?? _latitude;
            _longitude = (data['longitude'] as num?)?.toDouble() ?? _longitude;
            _latController.text = data['latText'] ?? _latitude.toString();
            _lngController.text = data['lngText'] ?? _longitude.toString();
            _phoneController.text = data['phone'] ?? '';
            _whatsappController.text = data['whatsapp'] ?? '';
            _descriptionController.text = data['description'] ?? '';
            _perDayWithFoodController.text = data['perDayWithFood'] ?? '';
            _perDayWithoutFoodController.text = data['perDayWithoutFood'] ?? '';

            final List<dynamic>? paths = data['imagePaths'];
            if (paths != null && paths.isNotEmpty) {
              _selectedImages.clear();
              for (final p in paths) {
                if (p is String && p.isNotEmpty && File(p).existsSync()) {
                  _selectedImages.add(XFile(p));
                }
              }
            }

            // PG
            _pgGender = data['pgGender'] ?? '';
            _pgSharing = data['pgSharing'] ?? '';
            _pgAcType = data['pgAcType'] ?? '';
            _pgBathroom = data['pgBathroom'] ?? '';
            _pgToiletType = data['pgToiletType'] ?? '';
            _pgFoodPlan = data['pgFoodPlan'] ?? '';
            _pgFoodType = data['pgFoodType'] ?? '';
            _pgWaterSupply = data['pgWaterSupply'] ?? '';
            _pgDrinkingWater = data['pgDrinkingWater'] ?? '';
            _pgPowerBackup = data['pgPowerBackup'] ?? '';
            _pgCleaning = data['pgCleaning'] ?? '';
            _pgCurfew = data['pgCurfew'] ?? '';
            _pgNotice = data['pgNotice'] ?? '';
            _pgManagement = data['pgManagement'] ?? '';
            _pgSelectedAmenities.clear();
            if (data['pgSelectedAmenities'] != null) {
              _pgSelectedAmenities.addAll(List<String>.from(data['pgSelectedAmenities']));
            }

            // Rental
            _rentalBhk = data['rentalBhk'] ?? '';
            _rentalFurnishing = data['rentalFurnishing'] ?? '';
            _rentalBeds = data['rentalBeds'] ?? '';
            _rentalBaths = data['rentalBaths'] ?? '';
            _rentalArea = data['rentalArea'] ?? '';
            _rentalFloor = data['rentalFloor'] ?? '';
            _rentalTotalFloors = data['rentalTotalFloors'] ?? '';
            _rentalAgreement = data['rentalAgreement'] ?? '';
            _rentalNotice = data['rentalNotice'] ?? '';
            _rentalWaterBill = data['rentalWaterBill'] ?? '';
            _rentalEbMeter = data['rentalEbMeter'] ?? '';
            _rentalTenantPref = data['rentalTenantPref'] ?? '';
            _rentalPetPolicy = data['rentalPetPolicy'] ?? '';
            _rentalParking = data['rentalParking'] ?? '';
            _rentalSelectedFeatures.clear();
            if (data['rentalSelectedFeatures'] != null) {
              _rentalSelectedFeatures.addAll(List<String>.from(data['rentalSelectedFeatures']));
            }

            // Buy / Sale
            _buyPropertyType = data['buyPropertyType'] ?? '';
            _buyBhk = data['buyBhk'] ?? '';
            _buyFurnishing = data['buyFurnishing'] ?? '';
            _buyBeds = data['buyBeds'] ?? '';
            _buyBaths = data['buyBaths'] ?? '';
            _buyPlotArea = data['buyPlotArea'] ?? '';
            _buyBuiltUpArea = data['buyBuiltUpArea'] ?? '';
            _buyFacing = data['buyFacing'] ?? '';
            _buyConstructionStatus = data['buyConstructionStatus'] ?? '';
            _buyTotalFloors = data['buyTotalFloors'] ?? '';
            _buyOwnershipType = data['buyOwnershipType'] ?? '';
            _buyApprovals = data['buyApprovals'] ?? '';
            _buyRoadWidth = data['buyRoadWidth'] ?? '';
            _buyWaterElectricity = data['buyWaterElectricity'] ?? '';
            _buyPriceNegotiable = data['buyPriceNegotiable'] ?? '';
            _buyParking = data['buyParking'] ?? '';
            _buySelectedFeatures.clear();
            if (data['buySelectedFeatures'] != null) {
              _buySelectedFeatures.addAll(List<String>.from(data['buySelectedFeatures']));
            }

            _hasDraftLoaded = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading draft: $e');
    }
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (e) {
      debugPrint('Error clearing draft: $e');
    }
  }

  void _discardDraftAndReset() async {
    await _clearDraft();
    setState(() {
      _currentStep = 1;
      _selectedType = 'Rental';
      _titleController.clear();
      _priceController.clear();
      _depositController.clear();
      _maintenanceController.clear();
      _addressController.clear();
      _locationAddress = '';
      _phoneController.clear();
      _whatsappController.clear();
      _descriptionController.clear();
      _perDayWithFoodController.clear();
      _perDayWithoutFoodController.clear();
      _selectedImages.clear();
      _pgGender = '';
      _pgSharing = '';
      _pgAcType = '';
      _pgBathroom = '';
      _pgToiletType = '';
      _pgFoodPlan = '';
      _pgFoodType = '';
      _pgWaterSupply = '';
      _pgDrinkingWater = '';
      _pgPowerBackup = '';
      _pgCleaning = '';
      _pgCurfew = '';
      _pgNotice = '';
      _pgManagement = '';
      _pgSelectedAmenities.clear();
      _rentalBhk = '';
      _rentalFurnishing = '';
      _rentalBeds = '';
      _rentalBaths = '';
      _rentalArea = '';
      _rentalFloor = '';
      _rentalTotalFloors = '';
      _rentalAgreement = '';
      _rentalNotice = '';
      _rentalWaterBill = '';
      _rentalEbMeter = '';
      _rentalTenantPref = '';
      _rentalPetPolicy = '';
      _rentalParking = '';
      _rentalSelectedFeatures.clear();
      _buyPropertyType = '';
      _buyBhk = '';
      _buyFurnishing = '';
      _buyBeds = '';
      _buyBaths = '';
      _buyPlotArea = '';
      _buyBuiltUpArea = '';
      _buyFacing = '';
      _buyConstructionStatus = '';
      _buyTotalFloors = '';
      _buyOwnershipType = '';
      _buyApprovals = '';
      _buyRoadWidth = '';
      _buyWaterElectricity = '';
      _buyPriceNegotiable = '';
      _buyParking = '';
      _buySelectedFeatures.clear();
      _hasDraftLoaded = false;
    });
    if (mounted) {
      AppSnackbar.success(context, 'Draft discarded! Form reset.');
    }
  }

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
      } else if (p.type == 'Buy' || p.type == 'Sale') {
        _buyBhk = p.bhkType ?? _buyBhk;
        _buyFurnishing = p.furnishingStatus ?? _buyFurnishing;
        _buyBeds = p.beds.isNotEmpty ? p.beds : _buyBeds;
        _buyBaths = p.baths.isNotEmpty ? p.baths : _buyBaths;
        _buyBuiltUpArea = p.area.isNotEmpty ? p.area.replaceAll(RegExp(r'[^0-9]'), '') : _buyBuiltUpArea;
        _buyParking = p.parkingInfo ?? _buyParking;
        _buySelectedFeatures.clear();
        _buySelectedFeatures.addAll(p.features);
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
    } else {
      _loadDraft();
    }
    
    _latController.text = _latitude.toString();
    _lngController.text = _longitude.toString();
  }

  @override
  void dispose() {
    _saveDraft();
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
        _saveDraft();
      }
    } catch (e) {
      if (mounted) {
        _showSheetError('Failed to pick images: $e');
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
      _saveDraft();
      if (mounted) {
        AppSnackbar.success(context, 'Location pinned successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showSheetError('Failed to get location. Enter address manually.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  void _submitProperty() {
    if (_titleController.text.trim().isEmpty) {
      _showSheetError('Please enter a property title');
      setState(() => _currentStep = 2);
      return;
    }
    if (_priceController.text.trim().isEmpty) {
      _showSheetError('Please enter monthly rent');
      setState(() => _currentStep = 2);
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      _showSheetError('Please provide owner contact number');
      return;
    }

    final isPg = _selectedType == 'PG';
    final isBuy = _selectedType == 'Buy';
    final List<String> tags = [];
    final List<String> features = [];

    if (isPg) {
      if (_pgGender.isNotEmpty) tags.add(_pgGender);
      if (_pgSharing.isNotEmpty) tags.add(_pgSharing);
      if (_pgFoodPlan.isNotEmpty && _pgFoodPlan.contains('Included')) tags.add('Food Included');
      if (_pgAcType.isNotEmpty && _pgAcType.contains('AC')) tags.add(_pgAcType);
      tags.addAll(_pgSelectedAmenities.take(2));

      features.addAll(_pgSelectedAmenities);
    } else if (isBuy) {
      tags.add('Buy');
      if (_buyPropertyType.isNotEmpty) tags.add(_buyPropertyType);
      if (_buyBhk.isNotEmpty) tags.add(_buyBhk);
      if (_buyFacing.isNotEmpty) tags.add(_buyFacing);
      if (_buyConstructionStatus.isNotEmpty) tags.add(_buyConstructionStatus);
      if (_buyOwnershipType.isNotEmpty) tags.add(_buyOwnershipType);
      tags.addAll(_buySelectedFeatures.take(2));

      features.addAll(_buySelectedFeatures);
      if (_buyApprovals.isNotEmpty) features.add(_buyApprovals);
      if (_buyRoadWidth.isNotEmpty) features.add(_buyRoadWidth);
      if (_buyWaterElectricity.isNotEmpty) features.add(_buyWaterElectricity);
      if (_buyOwnershipType.isNotEmpty) features.add(_buyOwnershipType);
      if (_buyPriceNegotiable.isNotEmpty) features.add(_buyPriceNegotiable);
    } else {
      if (_rentalBhk.isNotEmpty) tags.add(_rentalBhk);
      if (_rentalFurnishing.isNotEmpty) tags.add(_rentalFurnishing);
      if (_rentalParking.isNotEmpty) tags.add(_rentalParking);
      tags.addAll(_rentalSelectedFeatures.take(2));

      features.addAll(_rentalSelectedFeatures);
    }

    String formattedPrice;
    if (isBuy) {
      formattedPrice = '₹${_priceController.text.trim()}';
    } else {
      formattedPrice = '₹${_priceController.text.trim()}/m';
    }

    String propBeds;
    if (isPg) {
      propBeds = _pgSharing.isNotEmpty ? _pgSharing : '1 Bed';
    } else if (isBuy) {
      propBeds = _buyBhk.isNotEmpty ? _buyBhk : '3 BHK';
    } else {
      propBeds = _rentalBeds.isNotEmpty ? _rentalBeds : '2 Beds';
    }

    String propBaths;
    if (isPg) {
      propBaths = _pgBathroom.isNotEmpty ? _pgBathroom : '1 Bath';
    } else if (isBuy) {
      propBaths = _buyFacing.isNotEmpty ? _buyFacing : (_buyBaths.isNotEmpty ? _buyBaths : 'East Facing');
    } else {
      propBaths = _rentalBaths.isNotEmpty ? _rentalBaths : '2 Baths';
    }

    String propArea;
    if (isPg) {
      propArea = '180sqft';
    } else if (isBuy) {
      propArea = _buyBuiltUpArea.isNotEmpty ? '${_buyBuiltUpArea}sqft' : (_buyPlotArea.isNotEmpty ? _buyPlotArea : '1800sqft');
    } else {
      propArea = '${_rentalArea.isNotEmpty ? _rentalArea : '1200'}sqft';
    }

    final newProperty = PropertyModel(
      title: _titleController.text.trim(),
      price: formattedPrice,
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
      beds: propBeds,
      baths: propBaths,
      area: propArea,
      type: isPg ? 'PG' : (isBuy ? 'Buy' : 'Rental'),
      ownerPhone: _phoneController.text.trim(),
      ownerWhatsapp: _whatsappController.text.trim().isNotEmpty
          ? _whatsappController.text.trim()
          : _phoneController.text.trim(),
      features: features.toSet().toList(),
      securityDeposit: isBuy
          ? (_depositController.text.trim().isNotEmpty ? 'Advance: ₹${_depositController.text.trim()}' : null)
          : (_depositController.text.trim().isNotEmpty ? '₹${_depositController.text.trim()}' : null),
      maintenanceCharges: isBuy
          ? (_maintenanceController.text.trim().isNotEmpty ? _maintenanceController.text.trim() : null)
          : (_maintenanceController.text.trim().isNotEmpty ? '₹${_maintenanceController.text.trim()}' : 'Included'),
      noticePeriod: (isPg ? _pgNotice : _rentalNotice).isNotEmpty ? (isPg ? _pgNotice : _rentalNotice) : null,
      agreementDuration: isBuy
          ? (_buyOwnershipType.isNotEmpty ? _buyOwnershipType : 'Direct Freehold Sale')
          : (!isPg && _rentalAgreement.isNotEmpty ? _rentalAgreement : (isPg ? 'Flexible Monthly' : null)),
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : (isPg
              ? 'Well maintained PG with delicious meals, high-speed Wi-Fi, 24/7 security, and clean housekeeping.'
              : (isBuy
                  ? 'Prime property for sale with 100% clear title, clear documentation, good road access and immediate registration ready.'
                  : 'Spacious well ventilated property with quality fittings, zero seepage, good water & power supply.')),
      // PG specifics
      genderPreference: isPg && _pgGender.isNotEmpty ? _pgGender : null,
      sharingType: isPg && _pgSharing.isNotEmpty ? _pgSharing : null,
      foodDetails: isPg && (_pgFoodPlan.isNotEmpty || _pgFoodType.isNotEmpty) ? '$_pgFoodPlan ${_pgFoodType.isNotEmpty ? "($_pgFoodType)" : ""}'.trim() : null,
      drinkingWater: isPg && _pgDrinkingWater.isNotEmpty ? _pgDrinkingWater : null,
      waterSupply: isPg && _pgWaterSupply.isNotEmpty ? _pgWaterSupply : null,
      powerBackup: isPg && _pgPowerBackup.isNotEmpty ? _pgPowerBackup : null,
      acType: isPg && _pgAcType.isNotEmpty ? _pgAcType : null,
      bathroomType: isPg && (_pgBathroom.isNotEmpty || _pgToiletType.isNotEmpty) ? '$_pgBathroom ${_pgToiletType.isNotEmpty ? "($_pgToiletType)" : ""}'.trim() : null,
      cleanlinessInfo: isPg && _pgCleaning.isNotEmpty ? _pgCleaning : null,
      securityInfo: isPg ? '24/7 CCTV & Gated Security' : (isBuy ? 'Clear Title & Approvals' : null),
      verificationPolicy: isPg ? 'ID Verification Mandatory' : (isBuy ? 'Documents Verified' : null),
      managementInfo: isPg && _pgManagement.isNotEmpty ? _pgManagement : null,
      gateRules: isPg && _pgCurfew.isNotEmpty ? _pgCurfew : null,
      perDayWithFood: isPg && _perDayWithFoodController.text.trim().isNotEmpty ? _perDayWithFoodController.text.trim() : null,
      perDayWithoutFood: isPg && _perDayWithoutFoodController.text.trim().isNotEmpty ? _perDayWithoutFoodController.text.trim() : null,
      // Rental / Buy specifics
      bhkType: isBuy ? (_buyBhk.isNotEmpty ? _buyBhk : null) : (!isPg && _rentalBhk.isNotEmpty ? _rentalBhk : null),
      furnishingStatus: isBuy ? (_buyFurnishing.isNotEmpty ? _buyFurnishing : null) : (!isPg && _rentalFurnishing.isNotEmpty ? _rentalFurnishing : null),
      plumbingStatus: null,
      seepageStatus: null,
      electricalStatus: null,
      meterStatus: !isPg && !isBuy && _rentalEbMeter.isNotEmpty ? _rentalEbMeter : (isBuy && _buyWaterElectricity.isNotEmpty ? _buyWaterElectricity : null),
      billsInfo: isBuy ? (_buyApprovals.isNotEmpty ? _buyApprovals : null) : (!isPg ? (_rentalWaterBill.isNotEmpty ? (_rentalEbMeter.isNotEmpty ? '$_rentalEbMeter, Water: $_rentalWaterBill' : 'Water: $_rentalWaterBill') : (_rentalEbMeter.isNotEmpty ? _rentalEbMeter : null)) : null),
      tenantPreference: isBuy ? (_buyPriceNegotiable.isNotEmpty ? _buyPriceNegotiable : null) : (!isPg && _rentalTenantPref.isNotEmpty ? _rentalTenantPref : null),
      petPolicy: isBuy ? (_buyRoadWidth.isNotEmpty ? _buyRoadWidth : null) : (!isPg && _rentalPetPolicy.isNotEmpty ? _rentalPetPolicy : null),
      parkingInfo: isBuy ? (_buyParking.isNotEmpty ? _buyParking : null) : (!isPg && _rentalParking.isNotEmpty ? _rentalParking : null),
      status: _isEditing ? widget.propertyToEdit!.status : 'pending',
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
        
        // Fast resize and apply watermark if possible
        try {
          final originalImg = img.decodeImage(originalBytes);
          if (originalImg != null) {
            img.Image processedImg = originalImg;
            // Downscale huge camera photos (e.g. >1280px) for blazing fast upload & smooth performance
            if (processedImg.width > 1280 || processedImg.height > 1280) {
              processedImg = processedImg.width > processedImg.height
                  ? img.copyResize(processedImg, width: 1280)
                  : img.copyResize(processedImg, height: 1280);
            }

            if (watermarkImage != null) {
              int targetWatermarkWidth = (processedImg.width * 0.22).toInt().clamp(50, 400);
              img.Image scaledWatermark = img.copyResize(watermarkImage, width: targetWatermarkWidth);
              
              int padding = 16;
              int dstX = processedImg.width - scaledWatermark.width - padding;
              int dstY = processedImg.height - scaledWatermark.height - padding;
              
              img.compositeImage(processedImg, scaledWatermark, dstX: dstX, dstY: dstY);
            }
            
            bytesToUpload = Uint8List.fromList(img.encodeJpg(processedImg, quality: 82));
          }
        } catch (imgErr) {
          debugPrint('Image watermarking fallback: $imgErr');
          bytesToUpload = originalBytes;
        }
        
        // Upload the bytes to Supabase storage
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
      propertyJson['status'] = _isEditing ? widget.propertyToEdit!.status : 'pending';

      if (_isEditing) {
        await supabase.from('properties').update(propertyJson).eq('id', widget.propertyToEdit!.id!);
      } else {
        await supabase.from('properties').insert(propertyJson);
        await _clearDraft();
      }

      if (mounted) {
        widget.onPropertyCreated?.call(newProperty);
        Navigator.pop(context);
        AppSnackbar.success(
          context,
          _isEditing
              ? 'Property updated successfully!'
              : 'Listing submitted for review! It will appear once approved by admin.',
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSheetError('Failed to post property: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double maxDialogHeight = MediaQuery.of(context).size.height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxDialogHeight),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkScaffold : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Step indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEditing ? 'Edit ${_selectedType == "PG" ? "PG / Hostel" : "Rental Property"}' : 'Post ${_selectedType == "PG" ? "PG / Hostel" : "Rental Property"}',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Step $_currentStep of $_totalSteps: ${_getStepTitle()}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    
                    IconButton(
                      onPressed: () {
                        _saveDraft();
                        Navigator.pop(context);
                      },
                      icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.black54),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_sheetErrorMessage != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.only(top: 10, bottom: 4, left: 10, right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFECEC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.warning_2, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _sheetErrorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _sheetErrorMessage = null),
                    child: const Icon(Icons.close, color: Colors.red, size: 16),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          // Step Progress Indicator Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: List.generate(_totalSteps, (index) {
                final stepIndex = index + 1;
                final isPassed = stepIndex <= _currentStep;
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: isPassed
                          ? (isDark ? AppTheme.primaryYellow : Colors.black)
                          : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 24),
          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _buildStepContent(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _buildActionButtons(),
          ),
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
        if (_selectedType == 'PG') return 'Room, Sharing & In-Room Amenities';
        if (_selectedType == 'Buy') return 'Property Type, Dimensions & Facing';
        return 'Space, BHK & Physical Condition';
      case 4:
        if (_selectedType == 'PG') return 'Food, Mess & Utilities';
        if (_selectedType == 'Buy') return 'Legal Clearances, Approvals & Access';
        return 'Water, Metering & Bills';
      case 5:
        if (_selectedType == 'PG') return 'Security, Hygiene & Rules';
        if (_selectedType == 'Buy') return 'Ownership, Amenities & Highlights';
        return 'Agreement, Policies & Guidelines';
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
        if (_selectedType == 'PG') return _buildStep3PgRooms();
        if (_selectedType == 'Buy') return _buildStep3BuySpace();
        return _buildStep3RentalSpace();
      case 4:
        if (_selectedType == 'PG') return _buildStep4PgFoodAndUtilities();
        if (_selectedType == 'Buy') return _buildStep4BuyLegalAndAccess();
        return _buildStep4RentalUtilitiesAndBills();
      case 5:
        if (_selectedType == 'PG') return _buildStep5PgSecurityAndRules();
        if (_selectedType == 'Buy') return _buildStep5BuyOwnershipAndAmenities();
        return _buildStep5RentalAgreementAndRules();
      case 6:
        return _buildStep6ContactAndReview();
      default:
        return const SizedBox.shrink();
    }
  }

  // ==========================================
  // ACTION BUTTONS (20px margin from bottom)
  // ==========================================
  Widget _buildActionButtons() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        if (_currentStep > 1)
          Expanded(
            child: BouncingButton(
              onTap: _isSubmitting
                  ? null
                  : () {
                      setState(() => _currentStep--);
                      _saveDraft();
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: isDark ? AppTheme.darkCardElevated : const Color(0xFFF2F2F2),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Back',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        if (_currentStep > 1) const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: BouncingButton(
            onTap: _isSubmitting
                ? null
                : () {
                    if (_currentStep < _totalSteps) {
                      setState(() => _currentStep++);
                      _saveDraft();
                    } else {
                      _submitProperty();
                    }
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.primaryYellow : Colors.black,
                borderRadius: BorderRadius.circular(30),
              ),
              alignment: Alignment.center,
              child: _isSubmitting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: isDark ? Colors.black : Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _currentStep == _totalSteps ? 'Post Property' : 'Next Step',
                      style: TextStyle(
                        color: isDark ? Colors.black : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STEP 1: PROPERTY TYPE (2 ROWS LAYOUT)
  // ==========================================
  Widget _buildStep1TypeSelection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Property Category',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.2),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose the category that best matches your listing',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 16),

        // ROW 1: Rental & PG side-by-side (2 columns)
        Row(
          children: [
            Expanded(
              child: _buildCompactTypeCard(
                title: 'Rental Flat / House',
                badge: 'Rent',
                subtitle: 'Flats, villas & apartments',
                typeKey: 'Rental',
                lottiePath: 'assets/rental.json',
                icon: Iconsax.home_2,
                lottieHeight: 110,
                lottieScale: 1.55,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCompactTypeCard(
                title: 'PG / Co-Living / Hostel',
                badge: 'Hostel / PG',
                subtitle: 'Rooms with food & Wi-Fi',
                typeKey: 'PG',
                lottiePath: 'assets/hostel.json',
                icon: Iconsax.building_3,
                lottieHeight: 85,
                lottieScale: 1.05,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ROW 2: Buy / Sell (Single full-width row)
        _buildFullWidthBuyCard(
          title: 'Sell Property (Buy / Sale)',
          badge: 'House',
          subtitle: 'List independent houses, luxury villas, flats, commercial buildings, or open plots for buyers.',
          typeKey: 'Buy',
          lottiePath: 'assets/buyorsell.json',
          icon: Iconsax.shop,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildCompactTypeCard({
    required String title,
    required String badge,
    required String subtitle,
    required String typeKey,
    required String lottiePath,
    required IconData icon,
    required double lottieHeight,
    required double lottieScale,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isSelected = _selectedType == typeKey;

    return BouncingButton(
      scaleFactor: 0.97,
      onTap: () {
        setState(() {
          _selectedType = typeKey;
        });
        _saveDraft();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        height: 222,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark
              ? (isSelected ? const Color(0xFF242424) : AppTheme.darkCard.withValues(alpha: 0.85))
              : (isSelected ? const Color(0xFFFFFDE7).withValues(alpha: 0.95) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (isDark ? AppTheme.primaryYellow : Colors.black)
                : (isDark ? AppTheme.darkBorder : Colors.grey.shade200),
            width: isSelected ? 2.2 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? (isDark
                      ? AppTheme.primaryYellow.withValues(alpha: 0.20)
                      : Colors.black.withValues(alpha: 0.12))
                  : Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
              blurRadius: isSelected ? 14 : 4,
              offset: isSelected ? const Offset(0, 4) : const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Category tag + Check circle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? AppTheme.primaryYellow.withValues(alpha: 0.2) : const Color(0xFFFFEB3A))
                        : (isDark ? AppTheme.darkCardElevated : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 13,
                        color: isSelected
                            ? (isDark ? AppTheme.primaryYellow : Colors.black)
                            : (isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        badge,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? (isDark ? AppTheme.primaryYellow : Colors.black)
                              : (isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? (isDark ? AppTheme.primaryYellow : Colors.black)
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? (isDark ? AppTheme.primaryYellow : Colors.black)
                          : (isDark ? AppTheme.darkBorder : Colors.grey.shade400),
                      width: 1.8,
                    ),
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          size: 14,
                          color: isDark ? Colors.black : Colors.white,
                        )
                      : null,
                ),
              ],
            ),

            // Lottie Animation Center
            Expanded(
              child: Center(
                child: AnimatedScale(
                  scale: isSelected ? lottieScale * 1.05 : lottieScale,
                  duration: const Duration(milliseconds: 250),
                  child: SizedBox(
                    height: lottieHeight,
                    child: Lottie.asset(
                      lottiePath,
                      fit: BoxFit.contain,
                      repeat: true,
                      animate: true,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Icon(
                          icon,
                          size: 40,
                          color: isDark ? AppTheme.primaryYellow : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Title & Subtitle
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: isSelected
                    ? (isDark ? AppTheme.primaryYellow : Colors.black)
                    : (isDark ? Colors.white : const Color(0xFF1E1E1E)),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullWidthBuyCard({
    required String title,
    required String badge,
    required String subtitle,
    required String typeKey,
    required String lottiePath,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isSelected = _selectedType == typeKey;

    return BouncingButton(
      scaleFactor: 0.98,
      onTap: () {
        setState(() {
          _selectedType = typeKey;
        });
        _saveDraft();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark
              ? (isSelected ? const Color(0xFF242424) : AppTheme.darkCard.withValues(alpha: 0.85))
              : (isSelected ? const Color(0xFFFFFDE7).withValues(alpha: 0.95) : Colors.white),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? (isDark ? AppTheme.primaryYellow : Colors.black)
                : (isDark ? AppTheme.darkBorder : Colors.grey.shade200),
            width: 2.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? (isDark
                      ? AppTheme.primaryYellow.withValues(alpha: 0.20)
                      : Colors.black.withValues(alpha: 0.12))
                  : Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
              blurRadius: isSelected ? 16 : 5,
              offset: isSelected ? const Offset(0, 5) : const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left content - aligned from top
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? AppTheme.primaryYellow.withValues(alpha: 0.2) : const Color(0xFFFFEB3A))
                              : (isDark ? AppTheme.darkCardElevated : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              size: 13,
                              color: isSelected
                                  ? (isDark ? AppTheme.primaryYellow : Colors.black)
                                  : (isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              badge,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? (isDark ? AppTheme.primaryYellow : Colors.black)
                                    : (isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? (isDark ? AppTheme.primaryYellow : Colors.black)
                              : (isDark ? Colors.white : const Color(0xFF1E1E1E)),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'List independent houses, luxury\nvillas, flats, commercial spaces,\nor open plots for buyers.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Right column: Selection tick & larger animation contained inside
              SizedBox(
                width: 155,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? (isDark ? AppTheme.primaryYellow : Colors.black)
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? (isDark ? AppTheme.primaryYellow : Colors.black)
                              : (isDark ? AppTheme.darkBorder : Colors.grey.shade400),
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check,
                              size: 15,
                              color: isDark ? Colors.black : Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      height: 135,
                      width: 155,
                      child: Transform.scale(
                        scale: 1.15,
                        child: Lottie.asset(
                          lottiePath,
                          fit: BoxFit.contain,
                          repeat: true,
                          animate: true,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Icon(
                              icon,
                              size: 52,
                              color: isDark ? AppTheme.primaryYellow : Colors.black54,
                            ),
                          ),
                        ),
                      ),
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

  // ==========================================
  // STEP 2: PHOTOS & BASIC DETAILS
  // ==========================================
  Widget _buildStep2PhotosAndBasics() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                    color: isDark ? AppTheme.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Iconsax.camera,
                        size: 36,
                        color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to Upload Photos',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Add clear photos of room, bath & hall',
                        style: TextStyle(
                          color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade400,
                          fontSize: 11,
                        ),
                      ),
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
                      Text(
                        '${_existingImages.length + _selectedImages.length} Photos Selected',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _pickImages,
                        icon: Icon(
                          Iconsax.gallery_add,
                          size: 18,
                          color: isDark ? AppTheme.primaryYellow : Colors.black,
                        ),
                        label: Text(
                          'Add More',
                          style: TextStyle(
                            color: isDark ? AppTheme.primaryYellow : Colors.black,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
        const SizedBox(height: 20),
        _buildSectionHeader('Location & Address', Iconsax.location5),
        const SizedBox(height: 10),
        _locationAddress.isEmpty
            ? SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoadingLocation ? null : _grabCurrentLocation,
                  icon: _isLoadingLocation
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDark ? AppTheme.primaryYellow : Colors.black,
                          ),
                        )
                      : Icon(
                          Iconsax.location5,
                          color: isDark ? AppTheme.primaryYellow : Colors.black,
                          size: 18,
                        ),
                  label: Text(
                    _isLoadingLocation ? 'Pinning GPS Location...' : 'Pin Current GPS Location',
                    style: TextStyle(
                      color: isDark ? AppTheme.primaryYellow : Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    side: BorderSide(
                      color: isDark ? AppTheme.primaryYellow : Colors.black,
                    ),
                  ),
                ),
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppTheme.primaryYellow : Colors.green.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Iconsax.location5,
                      color: isDark ? AppTheme.primaryYellow : Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _locationAddress,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
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
        _buildQuestionSection(
          title: 'Occupancy & Gender Preference',
          subtitle: 'Select who can stay in this PG / Hostel',
          icon: Iconsax.profile_2user,
          child: _buildSingleSelectGroup(
            options: ['Boys Only', 'Girls Only', 'Co-Living (Unisex)'],
            selected: _pgGender,
            onSelected: (val) => setState(() => _pgGender = val),
          ),
        ),
        _buildQuestionSection(
          title: 'Room Sharing Type',
          subtitle: 'Number of beds / occupants sharing per room',
          icon: Iconsax.category,
          child: _buildSingleSelectGroup(
            options: ['Single Room', '2 Sharing', '3 Sharing', '4+ Sharing'],
            selected: _pgSharing,
            onSelected: (val) => setState(() => _pgSharing = val),
          ),
        ),
        _buildQuestionSection(
          title: 'Air Conditioning / Climate',
          subtitle: 'Cooling provision provided in rooms',
          icon: Iconsax.wind_2,
          child: _buildSingleSelectGroup(
            options: ['AC Room', 'Non-AC Room', 'Air Cooler Provided'],
            selected: _pgAcType,
            onSelected: (val) => setState(() => _pgAcType = val),
          ),
        ),
        _buildQuestionSection(
          title: 'Bathroom Setup',
          subtitle: 'Washroom attachment and privacy level',
          icon: Iconsax.drop,
          child: _buildSingleSelectGroup(
            options: ['Attached Bathroom', 'Common Bathroom (Cleaned Daily)'],
            selected: _pgBathroom,
            onSelected: (val) => setState(() => _pgBathroom = val),
          ),
        ),
        _buildQuestionSection(
          title: 'Toilet Fixture Type',
          subtitle: 'Commode or pan type installed in washrooms',
          icon: Iconsax.setting_2,
          child: _buildSingleSelectGroup(
            options: ['Western Toilet', 'Indian Toilet', 'Both Available'],
            selected: _pgToiletType,
            onSelected: (val) => setState(() => _pgToiletType = val),
          ),
        ),
        _buildQuestionSection(
          title: 'In-Room Furnishings & Essentials',
          subtitle: 'Tap all items available inside the room',
          icon: Iconsax.lamp_on,
          child: _buildMultiSelectChips(
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
        _buildQuestionSection(
          title: 'BHK Configuration',
          subtitle: 'Select house or apartment layout type',
          icon: Iconsax.home,
          child: _buildSingleSelectGroup(
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
        ),
        _buildQuestionSection(
          title: 'Furnishing Status',
          subtitle: 'Degree of furniture & fixtures included',
          icon: Iconsax.box,
          child: _buildSingleSelectGroup(
            options: ['Unfurnished', 'Semi-Furnished', 'Fully-Furnished'],
            selected: _rentalFurnishing,
            onSelected: (val) => setState(() => _rentalFurnishing = val),
          ),
        ),
        _buildQuestionSection(
          title: 'Carpet Area & Built-up Space',
          subtitle: 'Total usable floor area in square feet',
          icon: Iconsax.maximize_4,
          child: _buildCustomInput(
            initialValue: _rentalArea,
            label: 'Carpet Area (sqft)',
            hint: 'e.g. 1250',
            keyboardType: TextInputType.number,
            onChanged: (val) => _rentalArea = val,
          ),
        ),
        _buildQuestionSection(
          title: 'Bedrooms & Bathrooms Count',
          subtitle: 'Total count of private bedrooms and washrooms',
          icon: Iconsax.building_3,
          child: Row(
            children: [
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
        ),
        _buildQuestionSection(
          title: 'Floor & Building Level',
          subtitle: 'Specific floor number and total building floors',
          icon: Iconsax.layer,
          child: Row(
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
        ),
        _buildQuestionSection(
          title: 'Physical Inspection Checklist',
          subtitle: 'Highlight confirmed verified features',
          icon: Iconsax.shield_tick,
          child: _buildMultiSelectChips(
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
        ),
      ],
    );
  }

  // ==========================================
  // STEP 3 (BUY): PROPERTY TYPE, DIMENSIONS & FACING
  // ==========================================
  Widget _buildStep3BuySpace() {
    return Column(
      key: const ValueKey('buy_step3'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuestionSection(
          title: 'Property Type / Category',
          subtitle: 'Select the exact nature of property for sale',
          icon: Iconsax.building_3,
          child: _buildSingleSelectGroup(
            options: [
              'Independent House / Villa',
              'Apartment / Flat',
              'Open Plot / Land',
              'Commercial Building',
              'Duplex / Penthouse',
            ],
            selected: _buyPropertyType,
            onSelected: (val) => setState(() => _buyPropertyType = val),
          ),
        ),
        _buildQuestionSection(
          title: 'BHK Configuration',
          subtitle: 'Select number of bedrooms / layout setup',
          icon: Iconsax.home,
          child: _buildSingleSelectGroup(
            options: ['1 BHK', '2 BHK', '3 BHK', '4 BHK', '5+ BHK', 'Plot / Non-BHK', 'Commercial Space'],
            selected: _buyBhk,
            onSelected: (val) => setState(() {
              _buyBhk = val;
              if (val == '1 BHK') {
                _buyBeds = '1 BHK';
                _buyBaths = '1 Bath';
              } else if (val == '2 BHK') {
                _buyBeds = '2 BHK';
                _buyBaths = '2 Baths';
              } else if (val == '3 BHK') {
                _buyBeds = '3 BHK';
                _buyBaths = '3 Baths';
              } else if (val == '4 BHK' || val == '5+ BHK') {
                _buyBeds = val;
                _buyBaths = '4+ Baths';
              } else {
                _buyBeds = val;
              }
            }),
          ),
        ),
        _buildQuestionSection(
          title: 'Property Entrance Facing',
          subtitle: 'Main entrance or gate facing direction',
          icon: Iconsax.routing_2,
          child: _buildSingleSelectGroup(
            options: [
              'East Facing',
              'North Facing',
              'West Facing',
              'South Facing',
              'North-East Corner',
              'Corner Property (Dual Road Access)',
            ],
            selected: _buyFacing,
            onSelected: (val) => setState(() => _buyFacing = val),
          ),
        ),
        _buildQuestionSection(
          title: 'Plot & Built-up Dimensions',
          subtitle: 'Total land area and constructed usable carpet area',
          icon: Iconsax.maximize_4,
          child: Row(
            children: [
              Expanded(
                child: _buildCustomInput(
                  initialValue: _buyPlotArea,
                  label: 'Total Land Area',
                  hint: 'e.g. 150 Sq.Yds / 3.5 Cents',
                  onChanged: (val) => _buyPlotArea = val,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCustomInput(
                  initialValue: _buyBuiltUpArea,
                  label: 'Built-up Area (sqft)',
                  hint: 'e.g. 1850',
                  keyboardType: TextInputType.number,
                  onChanged: (val) => _buyBuiltUpArea = val,
                ),
              ),
            ],
          ),
        ),
        _buildQuestionSection(
          title: 'Construction Age & Status',
          subtitle: 'Current physical development status of property',
          icon: Iconsax.timer_1,
          child: _buildSingleSelectGroup(
            options: [
              'Ready to Move (Brand New 0-1 yr)',
              '1 to 3 Years Old',
              '3 to 5 Years Old',
              '5+ Years Resale',
              'Under Construction',
              'Open Plot (Ready for Construction)',
            ],
            selected: _buyConstructionStatus,
            onSelected: (val) => setState(() => _buyConstructionStatus = val),
          ),
        ),
        _buildQuestionSection(
          title: 'Furnishing & Interior Level',
          subtitle: 'Interior work and woodworking done on property',
          icon: Iconsax.box,
          child: _buildSingleSelectGroup(
            options: [
              'Unfurnished / Raw Shell',
              'Semi-Furnished (Cupboards & Modular Kitchen)',
              'Fully Furnished (Luxury Interiors & AC)',
            ],
            selected: _buyFurnishing,
            onSelected: (val) => setState(() => _buyFurnishing = val),
          ),
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
        _buildQuestionSection(
          title: 'Meal Plan Included',
          subtitle: 'Select daily meal schedule provided to residents',
          icon: Iconsax.coffee,
          child: _buildSingleSelectGroup(
            options: [
              '3 Meals Included (Breakfast, Lunch, Dinner)',
              '2 Meals Included (Breakfast & Dinner)',
              'Food Optional / Extra Charge',
              'Self-Cooking Kitchen Access',
            ],
            selected: _pgFoodPlan,
            onSelected: (val) => setState(() => _pgFoodPlan = val),
          ),
        ),
        _buildQuestionSection(
          title: 'Food Quality & Dietary Type',
          subtitle: 'Dietary preferences and preparation style',
          icon: Iconsax.heart,
          child: _buildSingleSelectGroup(
            options: ['Pure Veg Food', 'Veg & Non-Veg (Weekly)', 'Home-Style Cook'],
            selected: _pgFoodType,
            onSelected: (val) => setState(() => _pgFoodType = val),
          ),
        ),
        _buildQuestionSection(
          title: 'Drinking Water Facility',
          subtitle: 'Water purification and dispensing setup',
          icon: Iconsax.drop,
          child: _buildSingleSelectGroup(
            options: [
              'RO Purified + Cool Water Dispenser',
              '24/7 RO Purified Drinking Water',
              'Mineral Water Cans Provided',
            ],
            selected: _pgDrinkingWater,
            onSelected: (val) => setState(() => _pgDrinkingWater = val),
          ),
        ),
        _buildQuestionSection(
          title: 'General Water Supply',
          subtitle: 'Availability schedule for daily utility use',
          icon: Iconsax.bucket,
          child: _buildSingleSelectGroup(
            options: ['24/7 Continuous Water Supply', 'Timed Water Supply (Morning & Evening)'],
            selected: _pgWaterSupply,
            onSelected: (val) => setState(() => _pgWaterSupply = val),
          ),
        ),
        _buildQuestionSection(
          title: 'Power Supply & Backup',
          subtitle: 'Electricity reliability and inverter/generator support',
          icon: Iconsax.flash_1,
          child: _buildSingleSelectGroup(
            options: [
              'Full Inverter Power Backup',
              'Diesel Generator Backup (100%)',
              'Standard 24/7 Electricity',
            ],
            selected: _pgPowerBackup,
            onSelected: (val) => setState(() => _pgPowerBackup = val),
          ),
        ),
        _buildQuestionSection(
          title: 'Shared Appliances & Common Amenities',
          subtitle: 'Check all appliances available for common use',
          icon: Iconsax.computing,
          child: _buildMultiSelectChips(
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
        _buildQuestionSection(
          title: 'Electricity Meter & Power',
          subtitle: 'Billing method for tenant electrical consumption',
          icon: Iconsax.flash_1,
          child: _buildSingleSelectGroup(
            options: [
              'Dedicated EB Digital Meter',
              'Separate Sub-Meter',
              '3-Phase Connection',
            ],
            selected: _rentalEbMeter,
            onSelected: (val) => setState(() => _rentalEbMeter = val),
          ),
        ),
        _buildQuestionSection(
          title: 'Water Supply & Charges',
          subtitle: 'Water connection and billing arrangement',
          icon: Iconsax.drop,
          child: _buildSingleSelectGroup(
            options: [
              'Included in Maintenance',
              'Separate Water Bill',
              '24/7 Free Water Supply',
            ],
            selected: _rentalWaterBill,
            onSelected: (val) => setState(() => _rentalWaterBill = val),
          ),
        ),
        _buildQuestionSection(
          title: 'Parking Facility',
          subtitle: 'Vehicle parking space inside the premises',
          icon: Iconsax.car,
          child: _buildSingleSelectGroup(
            options: [
              'Covered Car & Bike Parking',
              'Open Car Parking + Bike Parking',
              'Only Bike Parking',
              'No Parking',
            ],
            selected: _rentalParking,
            onSelected: (val) => setState(() => _rentalParking = val),
          ),
        ),
        _buildQuestionSection(
          title: 'Utilities & Maintenance Checklist',
          subtitle: 'Select all features verified for this unit',
          icon: Iconsax.tick_circle,
          child: _buildMultiSelectChips(
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
        ),
      ],
    );
  }

  // ==========================================
  // STEP 4 (BUY): LEGAL CLEARANCES, APPROVALS & ACCESS
  // ==========================================
  Widget _buildStep4BuyLegalAndAccess() {
    return Column(
      key: const ValueKey('buy_step4'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuestionSection(
          title: 'Legal Clearances & Approvals',
          subtitle: 'Title legitimacy, sanction plans and approved authority',
          icon: Iconsax.document_text,
          child: _buildSingleSelectGroup(
            options: [
              'Freehold 100% Clear Title',
              'RERA & DTCP / Municipality Approved',
              'Bank Loan Approved (SBI, HDFC, ICICI, etc.)',
              'Ready for Immediate Sub-Registrar Registration',
              'Panchayat / Grama Kantham Approved',
            ],
            selected: _buyApprovals,
            onSelected: (val) => setState(() => _buyApprovals = val),
          ),
        ),
        _buildQuestionSection(
          title: 'Front Road Width & Access',
          subtitle: 'Connecting approach road width in front of property',
          icon: Iconsax.routing,
          child: _buildSingleSelectGroup(
            options: [
              '30 Feet Blacktop Road',
              '40 Feet Wide CC Road',
              '60 Feet Master Plan Road',
              'Main Highway Facing Road',
              '20 to 25 Feet Internal Road',
            ],
            selected: _buyRoadWidth,
            onSelected: (val) => setState(() => _buyRoadWidth = val),
          ),
        ),
        _buildQuestionSection(
          title: 'Water Supply & Underground Drainage',
          subtitle: 'Borewell yield, municipal connection and drainage status',
          icon: Iconsax.drop,
          child: _buildSingleSelectGroup(
            options: [
              '24/7 Deep Borewell + Municipal Water Connection',
              'Dedicated Sweet Water Borewell Available',
              'Municipal Tap Connection Only',
              'Underground Drainage (UGD) Connected',
            ],
            selected: _buyWaterElectricity,
            onSelected: (val) => setState(() => _buyWaterElectricity = val),
          ),
        ),
        _buildQuestionSection(
          title: 'Floors & Structure Level',
          subtitle: 'Total number of floors built on site',
          icon: Iconsax.layer,
          child: _buildSingleSelectGroup(
            options: [
              'Ground Floor Only',
              'G+1 Duplex House',
              'G+2 Independent Building (Rental Income)',
              'G+3 / Multi-Family Structure',
              'Apartment Unit (In Gated Community)',
            ],
            selected: _buyTotalFloors,
            onSelected: (val) => setState(() => _buyTotalFloors = val),
          ),
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
        _buildQuestionSection(
          title: 'Cleanliness & Housekeeping',
          subtitle: 'Frequency of room and washroom sanitization',
          icon: Iconsax.brush_1,
          child: _buildSingleSelectGroup(
            options: [
              'Daily Room & Bathroom Cleaning',
              'Alternate Day Cleaning',
              'Weekly Deep Cleaning',
            ],
            selected: _pgCleaning,
            onSelected: (val) => setState(() => _pgCleaning = val),
          ),
        ),
        _buildQuestionSection(
          title: 'Owner & Warden Presence',
          subtitle: 'Management and supervision available on premises',
          icon: Iconsax.user_tag,
          child: _buildSingleSelectGroup(
            options: [
              'Owner on site & Resident Warden',
              '24/7 Resident Warden Only',
              'Dedicated Caretaker on premises',
            ],
            selected: _pgManagement,
            onSelected: (val) => setState(() => _pgManagement = val),
          ),
        ),
        _buildQuestionSection(
          title: 'Gate Timings & Curfew Rules',
          subtitle: 'Night entry deadline or 24/7 access',
          icon: Iconsax.clock,
          child: _buildSingleSelectGroup(
            options: [
              '10:30 PM Gate Close',
              '10:00 PM Gate Close',
              '11:00 PM Gate Close',
              'No Curfew (24/7 Smart Access)',
            ],
            selected: _pgCurfew,
            onSelected: (val) => setState(() => _pgCurfew = val),
          ),
        ),
        _buildQuestionSection(
          title: 'Notice Period for Vacating',
          subtitle: 'Prior notice required before leaving the accommodation',
          icon: Iconsax.calendar,
          child: _buildSingleSelectGroup(
            options: ['15 Days', '1 Month', 'No Lock-in'],
            selected: _pgNotice,
            onSelected: (val) => setState(() => _pgNotice = val),
          ),
        ),
        _buildQuestionSection(
          title: 'Security & Verification Norms',
          subtitle: 'Safety rules and guest policies enforced',
          icon: Iconsax.security_user,
          child: _buildMultiSelectChips(
            options: [
              '24/7 CCTV & Security',
              'ID Verification Required',
              'Biometric / Smart Entry',
              'Visitors Allowed in Common Lounge',
              'Strict No Smoking / Alcohol',
              'Parent Contact Verification',
            ],
            selectedSet: _pgSelectedAmenities,
          ),
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
        _buildQuestionSection(
          title: 'Rental Agreement Duration',
          subtitle: 'Standard tenure for the rent agreement',
          icon: Iconsax.document_text,
          child: _buildSingleSelectGroup(
            options: [
              '11 Months Standard',
              '1 to 2 Years Agreement',
              'Flexible / No Lock-in',
            ],
            selected: _rentalAgreement,
            onSelected: (val) => setState(() => _rentalAgreement = val),
          ),
        ),
        _buildQuestionSection(
          title: 'Notice Period for Vacating',
          subtitle: 'Advance notice required before moving out',
          icon: Iconsax.calendar,
          child: _buildSingleSelectGroup(
            options: ['1 Month', '2 Months', '15 Days'],
            selected: _rentalNotice,
            onSelected: (val) => setState(() => _rentalNotice = val),
          ),
        ),
        _buildQuestionSection(
          title: 'Tenant Preference',
          subtitle: 'Eligible resident profiles accepted by owner',
          icon: Iconsax.profile_2user,
          child: _buildSingleSelectGroup(
            options: [
              'Family & Working Professionals',
              'Family Only',
              'Bachelors Allowed',
              'Anyone Welcome',
            ],
            selected: _rentalTenantPref,
            onSelected: (val) => setState(() => _rentalTenantPref = val),
          ),
        ),
        _buildQuestionSection(
          title: 'Pet Policy',
          subtitle: 'Are household pets permitted on the property?',
          icon: Iconsax.heart,
          child: _buildSingleSelectGroup(
            options: ['Pets Allowed', 'No Pets Allowed'],
            selected: _rentalPetPolicy,
            onSelected: (val) => setState(() => _rentalPetPolicy = val),
          ),
        ),
        _buildQuestionSection(
          title: 'House Rules & Society Norms',
          subtitle: 'Guidelines for tenants regarding noise, diet & visitors',
          icon: Iconsax.info_circle,
          child: _buildMultiSelectChips(
            options: [
              'Non-Veg Allowed',
              'Veg Only Preferred',
              'Gated Security',
              'No Loud Music after 10 PM',
              'Visitor Parking Available',
            ],
            selectedSet: _rentalSelectedFeatures,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STEP 5 (BUY): OWNERSHIP, AMENITIES & HIGHLIGHTS
  // ==========================================
  Widget _buildStep5BuyOwnershipAndAmenities() {
    return Column(
      key: const ValueKey('buy_step5'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuestionSection(
          title: 'Ownership & Seller Profile',
          subtitle: 'Who is selling this property?',
          icon: Iconsax.user_tag,
          child: _buildSingleSelectGroup(
            options: [
              'Direct Owner (Zero Brokerage)',
              'Builder / Promoter Direct Sale',
              'Resale by First Owner',
              'Sole Authorized Relative / Representative',
            ],
            selected: _buyOwnershipType,
            onSelected: (val) => setState(() => _buyOwnershipType = val),
          ),
        ),
        _buildQuestionSection(
          title: 'Price Negotiability',
          subtitle: 'Flexibility on the quoted asking price',
          icon: Iconsax.tag,
          child: _buildSingleSelectGroup(
            options: [
              'Price Negotiable for Serious Buyers',
              'Slightly Negotiable across the table',
              'Fixed Price (Strictly No Bargain)',
            ],
            selected: _buyPriceNegotiable,
            onSelected: (val) => setState(() => _buyPriceNegotiable = val),
          ),
        ),
        _buildQuestionSection(
          title: 'Parking Infrastructure',
          subtitle: 'Parking space allocated inside boundaries',
          icon: Iconsax.car,
          child: _buildSingleSelectGroup(
            options: [
              'Covered Car + 2-Wheeler Parking',
              'Multiple Car Parking (2+ Large Cars)',
              'Open Dedicated Parking Inside Compound',
              'Street Parking Only',
            ],
            selected: _buyParking,
            onSelected: (val) => setState(() => _buyParking = val),
          ),
        ),
        _buildQuestionSection(
          title: 'Key Highlights & Property Features',
          subtitle: 'Select confirmed features to highlight for buyers',
          icon: Iconsax.tick_circle,
          child: _buildMultiSelectChips(
            options: [
              'Good Ventilation & Natural Sunlight',
              'Clear Title & Clean Documentation',
              'Bank Loan Sanction Support',
              'Ready for Immediate Registration',
              'Compound Boundary Wall with Gate',
              'Gated Community & 24/7 Security',
              'Passenger Lift Installed',
              'Power Backup Ready',
              'Rainwater Harvesting System',
              'Surrounded by Developed Houses',
              'Near Schools, Hospitals & Markets',
              'Zero Waterlogging in Rains',
              'High Rental Income Potential',
            ],
            selectedSet: _buySelectedFeatures,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STEP 6: CONTACT & REVIEW
  // ==========================================
  Widget _buildStep6ContactAndReview() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
            ),
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.primaryYellow : Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _selectedType,
                      style: TextStyle(
                        color: isDark ? Colors.black : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _selectedType == 'Buy'
                    ? 'Total Asking Price: ₹${_priceController.text.isNotEmpty ? _priceController.text : '0'}${_buyPriceNegotiable.isNotEmpty ? " • $_buyPriceNegotiable" : ""}'
                    : '₹${_priceController.text.isNotEmpty ? _priceController.text : '0'}/month${_depositController.text.isNotEmpty ? " • Deposit: ₹${_depositController.text}" : ""}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.primaryYellow : Colors.green,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _addressController.text.isNotEmpty
                    ? _addressController.text
                    : (_locationAddress.isNotEmpty ? _locationAddress : 'Location Pinned'),
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                ),
              ),
              Divider(
                height: 20,
                color: isDark ? AppTheme.darkBorder : null,
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: (_selectedType == 'PG'
                        ? [_pgGender, _pgSharing, _pgFoodPlan, _pgAcType, ..._pgSelectedAmenities.take(3)]
                        : (_selectedType == 'Buy'
                            ? [_buyPropertyType, _buyBhk, _buyFacing, _buyConstructionStatus, _buyOwnershipType, ..._buySelectedFeatures.take(3)]
                            : [_rentalBhk, _rentalFurnishing, _rentalEbMeter, ..._rentalSelectedFeatures.take(3)]))
                    .where((item) => item.isNotEmpty)
                    .map((item) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkCardElevated : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            item,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppTheme.darkTextSecondary : Colors.black87,
                            ),
                          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.primaryYellow.withValues(alpha: 0.15) : const Color(0xFFFFEB3A).withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: isDark ? AppTheme.primaryYellow : Colors.black),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionSection({
    required String title,
    String? subtitle,
    required IconData icon,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard.withValues(alpha: 0.7) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.primaryYellow.withValues(alpha: 0.15) : const Color(0xFFFFEB3A).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 15,
                  color: isDark ? AppTheme.primaryYellow : Colors.black,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 37),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.darkTextSecondary : Colors.black,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: (val) {
            onChanged?.call(val);
            _saveDraft();
          },
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white : Colors.black,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade400,
              fontSize: 13,
            ),
            filled: true,
            fillColor: isDark ? AppTheme.darkCard : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? AppTheme.primaryYellow : Colors.black,
                width: 1.5,
              ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final bool isSelected = opt == selected;
        return BouncingButton(
          scaleFactor: 0.97,
          onTap: () {
            onSelected(opt);
            _saveDraft();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? const Color(0xFF2B2800) : const Color(0xFFFFFDE7))
                  : (isDark ? AppTheme.darkCard : Colors.white),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? (isDark ? AppTheme.primaryYellow : Colors.black)
                    : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                width: isSelected ? 1.8 : 1.2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: (isDark ? AppTheme.primaryYellow : Colors.black).withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? Iconsax.tick_circle : Icons.radio_button_unchecked,
                  size: 15,
                  color: isSelected
                      ? (isDark ? AppTheme.primaryYellow : Colors.black)
                      : (isDark ? AppTheme.darkTextSecondary : Colors.grey.shade400),
                ),
                const SizedBox(width: 7),
                Text(
                  opt,
                  style: TextStyle(
                    color: isSelected
                        ? (isDark ? AppTheme.primaryYellow : Colors.black)
                        : (isDark ? Colors.white70 : const Color(0xFF2D2D2D)),
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final bool isSelected = selectedSet.contains(opt);
        return BouncingButton(
          scaleFactor: 0.97,
          onTap: () {
            setState(() {
              if (isSelected) {
                selectedSet.remove(opt);
              } else {
                selectedSet.add(opt);
              }
            });
            _saveDraft();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? const Color(0xFF2B2800) : const Color(0xFFFFFDE7))
                  : (isDark ? AppTheme.darkCard : Colors.white),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? (isDark ? AppTheme.primaryYellow : Colors.black)
                    : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                width: isSelected ? 1.8 : 1.2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: (isDark ? AppTheme.primaryYellow : Colors.black).withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? Iconsax.tick_circle : Iconsax.add_circle,
                  color: isSelected
                      ? (isDark ? AppTheme.primaryYellow : Colors.black)
                      : (isDark ? AppTheme.darkTextSecondary : Colors.grey.shade400),
                  size: 15,
                ),
                const SizedBox(width: 6),
                Text(
                  opt,
                  style: TextStyle(
                    color: isSelected
                        ? (isDark ? AppTheme.primaryYellow : Colors.black)
                        : (isDark ? Colors.white70 : const Color(0xFF2D2D2D)),
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: -0.1,
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
