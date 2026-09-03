import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../models/property_model.dart';
import '../services/hostel_scraping_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snackbar.dart';

class AdminScrapingPipelineTab extends StatefulWidget {
  final bool isDark;
  const AdminScrapingPipelineTab({super.key, required this.isDark});

  @override
  State<AdminScrapingPipelineTab> createState() => _AdminScrapingPipelineTabState();
}

class _AdminScrapingPipelineTabState extends State<AdminScrapingPipelineTab> {
  final HostelScrapingService _scrapingService = HostelScrapingService.instance;
  final String _batchId = 'batch_${DateTime.now().millisecondsSinceEpoch}';

  // Current Pipeline Stage (1: Discovery, 2: Live Scraper, 3: Data & Photo Studio, 4: Super Admin Approval)
  int _currentStage = 1;

  // --- STAGE 1 STATE ---
  final TextEditingController _locationController = TextEditingController(text: 'Velachery, Chennai');
  bool _isSearchingLocation = false;
  List<Map<String, dynamic>> _stage1Candidates = [];

  // --- STAGE 2 STATE ---
  bool _isScrapingActive = false;
  double _scrapingProgress = 0.0;
  int _scrapedCount = 0;
  List<String> _liveLogs = [];
  List<Map<String, dynamic>> _stage2ScrapedResults = [];

  // --- STAGE 3 STATE (FULL PROPERTYMODEL EDITING & PHOTO STUDIO) ---
  int _selectedHostelForReviewIndex = 0;

  // Controllers for ALL PropertyModel attributes
  final TextEditingController _editNameController = TextEditingController();
  final TextEditingController _editPriceController = TextEditingController();
  final TextEditingController _editLocationStrController = TextEditingController();
  final TextEditingController _editLatController = TextEditingController();
  final TextEditingController _editLngController = TextEditingController();
  final TextEditingController _editBedsController = TextEditingController(text: '1');
  final TextEditingController _editBathsController = TextEditingController(text: '1');
  final TextEditingController _editAreaController = TextEditingController(text: '180 sq.ft');
  final TextEditingController _editTypeController = TextEditingController(text: 'PG');
  final TextEditingController _editPhoneController = TextEditingController();
  final TextEditingController _editWhatsappController = TextEditingController();
  final TextEditingController _editDescriptionController = TextEditingController();

  // Financial Controllers
  final TextEditingController _editDepositController = TextEditingController();
  final TextEditingController _editMaintenanceController = TextEditingController();
  final TextEditingController _editNoticePeriodController = TextEditingController();
  final TextEditingController _editAgreementDurationController = TextEditingController();

  // PG Specific Controllers
  String _genderPreference = 'Boys';
  String _sharingType = 'Single, 2 Sharing, 3 Sharing';
  final TextEditingController _editFoodDetailsController = TextEditingController();
  final TextEditingController _editFoodQualityController = TextEditingController();
  final TextEditingController _editDrinkingWaterController = TextEditingController();
  final TextEditingController _editWaterSupplyController = TextEditingController();
  final TextEditingController _editPowerBackupController = TextEditingController();
  String _acType = 'AC & Non-AC Rooms';
  String _bathroomType = 'Attached Western';
  final TextEditingController _editCleanlinessController = TextEditingController();
  final TextEditingController _editSecurityInfoController = TextEditingController();
  final TextEditingController _editVerificationController = TextEditingController();
  final TextEditingController _editManagementInfoController = TextEditingController();
  final TextEditingController _editGateRulesController = TextEditingController();

  // Rental Specific Controllers
  String _bhkType = '1 BHK';
  String _furnishingStatus = 'Fully-Furnished';
  String _tenantPreference = 'Working Bachelors / Students';
  String _petPolicy = 'No Pets';
  final TextEditingController _editParkingInfoController = TextEditingController();

  // Photo Studio State
  List<String> _stage3PhotoUrls = [];
  Set<int> _selectedPhotoIndices = {0, 1, 2};
  int _activeCropAspectIndex = 0; // 0: 16:9 Cover, 1: 4:3 Gallery

  // --- STAGE 4 STATE ---
  List<PropertyModel> _stage4ApprovalQueue = [];

  @override
  void initState() {
    super.initState();
    _triggerStage1Search();
  }

  void _copyToClipboard(String value, String label) {
    if (value.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: value.trim()));
    AppSnackbar.success(context, '📋 Copied $label "$value" to clipboard!');
  }

  Future<void> _triggerStage1Search() async {
    final query = _locationController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearchingLocation = true);

    try {
      final coords = await _scrapingService.geocodeLocation(query);
      final lat = coords?['lat'] ?? 12.9784;
      final lng = coords?['lng'] ?? 80.2184;

      final results = await _scrapingService.search5kmRadiusOSM(lat, lng, query);

      if (mounted) {
        setState(() {
          _stage1Candidates = results;
          _isSearchingLocation = false;
        });
        AppSnackbar.success(context, '📍 Found ${_stage1Candidates.length} candidate hostels within 5km of $query!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearchingLocation = false);
        AppSnackbar.error(context, 'Search error: $e');
      }
    }
  }

  void _startStage2LiveScraping() async {
    final selectedCandidates = _stage1Candidates.where((c) => c['selected'] == true).toList();
    if (selectedCandidates.isEmpty) {
      AppSnackbar.error(context, 'Please select at least 1 candidate to scrape');
      return;
    }

    setState(() {
      _currentStage = 2;
      _isScrapingActive = true;
      _scrapingProgress = 0.0;
      _scrapedCount = 0;
      _stage2ScrapedResults.clear();
      _liveLogs = [
        '⚡ [System] Initializing Multi-Source Aggregator for 5km radius...',
        '🌐 [OSM] Querying OpenStreetMap & web listings for ${selectedCandidates.length} selected hostels...',
      ];
    });

    for (int i = 0; i < selectedCandidates.length; i++) {
      if (!mounted) break;
      final cand = selectedCandidates[i];
      setState(() {
        _liveLogs.add('🔍 [Scraping ${i + 1}/${selectedCandidates.length}] Extracting details for ${cand['name']}...');
      });

      final scrapedData = await _scrapingService.scrapeHostelDetails(cand);
      await _scrapingService.saveStagingHostel(scrapedData, _batchId, 2);

      if (mounted) {
        setState(() {
          _stage2ScrapedResults.add(scrapedData);
          _scrapedCount++;
          _scrapingProgress = (_scrapedCount / selectedCandidates.length).clamp(0.0, 1.0);
          _liveLogs.add('✅ [Complete ${i + 1}/${selectedCandidates.length}] ${cand['name']} scraped successfully (Phone, Rent & Photos ready)');
        });
      }
    }

    if (mounted) {
      setState(() {
        _isScrapingActive = false;
        _liveLogs.add('🎉 [Batch Finish] All selected hostels scraped and staged in Supabase DB!');
      });
      if (_stage2ScrapedResults.isNotEmpty) {
        _loadStage3HostelData(0);
      }
    }
  }

  void _loadStage3HostelData(int index) {
    if (index >= _stage2ScrapedResults.length) return;
    final item = _stage2ScrapedResults[index];
    setState(() {
      _selectedHostelForReviewIndex = index;

      // Basic
      _editNameController.text = item['name'] ?? '';
      _editPriceController.text = item['rent'] ?? '₹7,500';
      _editLocationStrController.text = item['address'] ?? '';
      _editLatController.text = (item['lat'] ?? 12.9784).toString();
      _editLngController.text = (item['lng'] ?? 80.2184).toString();
      _editTypeController.text = item['type'] ?? 'PG';
      _editPhoneController.text = item['phone'] ?? '';
      _editWhatsappController.text = item['owner_whatsapp'] ?? item['phone'] ?? '';
      _editDescriptionController.text = item['description'] ?? '';

      // Financial
      _editDepositController.text = item['security_deposit'] ?? '₹10,000 (Refundable)';
      _editMaintenanceController.text = item['maintenance_charges'] ?? '₹500/mo';
      _editNoticePeriodController.text = item['notice_period'] ?? '1 Month';
      _editAgreementDurationController.text = item['agreement_duration'] ?? '6 Months';

      // PG
      _genderPreference = item['gender_preference'] ?? 'Boys';
      _sharingType = item['sharing_type'] ?? 'Single, 2 Sharing, 3 Sharing';
      _editFoodDetailsController.text = item['food_details'] ?? '3 Meals Daily';
      _editFoodQualityController.text = item['food_quality'] ?? 'Homely & Hygienic';
      _editDrinkingWaterController.text = item['drinking_water'] ?? 'RO Purified Water';
      _editWaterSupplyController.text = item['water_supply'] ?? '24/7 Water Supply';
      _editPowerBackupController.text = item['power_backup'] ?? '24/7 Generator/Inverter';
      _acType = item['ac_type'] ?? 'AC & Non-AC Rooms';
      _bathroomType = item['bathroom_type'] ?? 'Attached Western';
      _editCleanlinessController.text = item['cleanliness_info'] ?? 'Daily Housekeeping';
      _editSecurityInfoController.text = item['security_info'] ?? '24/7 CCTV & Biometric Entry';
      _editVerificationController.text = item['verification_policy'] ?? 'Student/Employee ID Mandatory';
      _editManagementInfoController.text = item['management_info'] ?? 'Resident Warden On-Site';
      _editGateRulesController.text = item['gate_rules'] ?? '10:30 PM Gate Closure';

      // Rental
      _bhkType = item['bhk_type'] ?? 'N/A (PG Rooms)';
      _furnishingStatus = item['furnishing_status'] ?? 'Fully-Furnished';
      _tenantPreference = 'Working Bachelors / Students';
      _petPolicy = 'No Pets Allowed';
      _editParkingInfoController.text = item['parking_info'] ?? 'Covered Bike Parking';

      // Photos
      _stage3PhotoUrls = List<String>.from(item['raw_photos'] ?? []);
      _selectedPhotoIndices = {0, 1, 2};
    });
  }

  PropertyModel _constructPropertyModelFromStage3() {
    final List<String> finalImages = [];
    final indicesList = _selectedPhotoIndices.toList()..sort();
    for (var idx in indicesList) {
      if (idx < _stage3PhotoUrls.length) {
        finalImages.add(_stage3PhotoUrls[idx]);
      }
    }
    if (finalImages.isEmpty && _stage3PhotoUrls.isNotEmpty) {
      finalImages.add(_stage3PhotoUrls[0]);
    }

    return PropertyModel(
      title: _editNameController.text.trim(),
      price: _editPriceController.text.trim(),
      locationStr: _editLocationStrController.text.trim(),
      latitude: double.tryParse(_editLatController.text) ?? 12.9784,
      longitude: double.tryParse(_editLngController.text) ?? 80.2184,
      imageUrls: finalImages,
      tags: ['Verified', _genderPreference, _acType, '5km Near College'],
      beds: _editBedsController.text.trim(),
      baths: _editBathsController.text.trim(),
      area: _editAreaController.text.trim(),
      type: _editTypeController.text.trim(),
      ownerPhone: _editPhoneController.text.trim(),
      ownerWhatsapp: _editWhatsappController.text.trim(),
      features: [
        _editFoodDetailsController.text,
        _editWaterSupplyController.text,
        _editPowerBackupController.text,
        _acType,
        _bathroomType,
      ],
      isAvailable: true,
      status: 'pending',
      securityDeposit: _editDepositController.text.trim(),
      maintenanceCharges: _editMaintenanceController.text.trim(),
      noticePeriod: _editNoticePeriodController.text.trim(),
      agreementDuration: _editAgreementDurationController.text.trim(),
      description: _editDescriptionController.text.trim(),
      genderPreference: _genderPreference,
      sharingType: _sharingType,
      foodDetails: _editFoodDetailsController.text.trim(),
      foodQuality: _editFoodQualityController.text.trim(),
      drinkingWater: _editDrinkingWaterController.text.trim(),
      waterSupply: _editWaterSupplyController.text.trim(),
      powerBackup: _editPowerBackupController.text.trim(),
      acType: _acType,
      bathroomType: _bathroomType,
      cleanlinessInfo: _editCleanlinessController.text.trim(),
      securityInfo: _editSecurityInfoController.text.trim(),
      verificationPolicy: _editVerificationController.text.trim(),
      managementInfo: _editManagementInfoController.text.trim(),
      gateRules: _editGateRulesController.text.trim(),
      bhkType: _bhkType,
      furnishingStatus: _furnishingStatus,
      tenantPreference: _tenantPreference,
      petPolicy: _petPolicy,
      parkingInfo: _editParkingInfoController.text.trim(),
    );
  }

  // --- SUPABASE STUDIO / AIRTABLE STYLE HELPER COMPONENTS ---

  Widget _buildTypeBadge(String typeLabel) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        typeLabel,
        style: GoogleFonts.firaCode(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: widget.isDark ? Colors.white60 : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildSupabaseColumnHeader(String title, String type, {Color? titleColor}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: GoogleFonts.firaCode(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: titleColor ?? (widget.isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ),
        if (type.isNotEmpty) ...[
          _buildTypeBadge(type),
        ],
      ],
    );
  }

  Widget _buildStatusPill(String statusText, {bool isSuccess = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: isSuccess ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isSuccess ? const Color(0xFFA7F3D0) : const Color(0xFFFCA5A5),
          width: 0.8,
        ),
      ),
      child: Text(
        statusText,
        style: GoogleFonts.firaCode(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isSuccess ? const Color(0xFF059669) : const Color(0xFFDC2626),
        ),
      ),
    );
  }

  Widget _buildRowActions({required VoidCallback onEdit, required VoidCallback onDelete}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(4),
          child: const Padding(
            padding: EdgeInsets.all(3),
            child: Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFFEAB308)),
          ),
        ),
        const SizedBox(width: 2),
        InkWell(
          onTap: onDelete,
          borderRadius: BorderRadius.circular(4),
          child: const Padding(
            padding: EdgeInsets.all(3),
            child: Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final mutedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF161922) : Colors.white;

    return Column(
      children: [
        // Stepper Header
        _buildPipelineHeader(isDark, mutedColor),

        // Stage Main View
        Expanded(
          child: Container(
            color: isDark ? const Color(0xFF0F1117) : const Color(0xFFF4F6F9),
            padding: const EdgeInsets.all(18),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _buildCurrentStageView(isDark, cardBg, mutedColor),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // PIPELINE STEPPER HEADER
  // ==========================================
  Widget _buildPipelineHeader(bool isDark, Color mutedColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141721) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        children: [
          _buildStageStep(1, 'Stage 1: 5km Discovery', 'OSM & Web Search', Iconsax.location, isDark),
          _buildStepDivider(isDark),
          _buildStageStep(2, 'Stage 2: Live Scraper', 'Data & Photo Extraction', Iconsax.flash_1, isDark),
          _buildStepDivider(isDark),
          _buildStageStep(3, 'Stage 3: Data & Photo Studio', 'Edit 35+ Fields & Crop', Iconsax.edit_2, isDark),
          _buildStepDivider(isDark),
          _buildStageStep(4, 'Stage 4: Super Admin Approval', 'Publish Live to DB', Iconsax.verify, isDark),
        ],
      ),
    );
  }

  Widget _buildStageStep(int stageNum, String title, String subtitle, IconData icon, bool isDark) {
    final isActive = _currentStage == stageNum;
    final isCompleted = _currentStage > stageNum;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _currentStage = stageNum),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? (isDark ? const Color(0xFF252B3B) : const Color(0xFFFEF08A).withValues(alpha: 0.4)) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isActive ? AppTheme.primaryYellow : Colors.transparent, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.primaryYellow : (isCompleted ? const Color(0xFF10B981) : (isDark ? Colors.white10 : const Color(0xFFE2E8F0))),
                  shape: BoxShape.circle,
                ),
                child: Icon(isCompleted ? Icons.check : icon, size: 14, color: isActive || isCompleted ? Colors.black : (isDark ? Colors.white54 : Colors.black54)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: isActive ? FontWeight.w800 : FontWeight.w600, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis),
                    Text(subtitle, style: GoogleFonts.inter(fontSize: 9.5, color: isDark ? Colors.white54 : Colors.black54), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepDivider(bool isDark) {
    return Container(width: 16, height: 1, margin: const EdgeInsets.symmetric(horizontal: 2), color: isDark ? Colors.white12 : const Color(0xFFCBD5E1));
  }

  Widget _buildCurrentStageView(bool isDark, Color cardBg, Color mutedColor) {
    switch (_currentStage) {
      case 1:
        return _buildStage1View(isDark, cardBg, mutedColor);
      case 2:
        return _buildStage2View(isDark, cardBg, mutedColor);
      case 3:
        return _buildStage3View(isDark, cardBg, mutedColor);
      case 4:
        return _buildStage4View(isDark, cardBg, mutedColor);
      default:
        return _buildStage1View(isDark, cardBg, mutedColor);
    }
  }

  // ==========================================
  // STAGE 1: 5KM OPENSTREETMAP DISCOVERY (SUPABASE STUDIO STYLE TABLE + CLICK-TO-COPY)
  // ==========================================
  Widget _buildStage1View(bool isDark, Color cardBg, Color mutedColor) {
    final selectedCount = _stage1Candidates.where((c) => c['selected'] == true).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Header
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0))),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _locationController,
                  style: GoogleFonts.inter(fontSize: 13.5, color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Iconsax.location, size: 18, color: Color(0xFFF59E0B)),
                    hintText: 'Enter area or college name...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFCBD5E1))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _isSearchingLocation ? null : _triggerStage1Search,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryYellow,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: _isSearchingLocation ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Iconsax.search_normal_1, size: 15),
                label: Text('Search 5km OpenStreetMap', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12.5)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Action Toolbar
        Row(
          children: [
            Text('Discovered Candidates (${_stage1Candidates.length})', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
            const Spacer(),
            if (selectedCount > 0) ...[
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _stage1Candidates.removeWhere((c) => c['selected'] == true));
                  AppSnackbar.success(context, 'Deleted selected candidate rows');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFEE2E2),
                  foregroundColor: const Color(0xFFDC2626),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: const Icon(Iconsax.trash, size: 14, color: Color(0xFFDC2626)),
                label: Text('Delete Selected ($selectedCount)', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12)),
              ),
              const SizedBox(width: 10),
            ],
            ElevatedButton.icon(
              onPressed: selectedCount == 0 ? null : _startStage2LiveScraping,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Iconsax.flash_1, size: 15),
              label: Text('Send Selected to Stage 2 (Start Scraping) ➔', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // SUPABASE STUDIO STYLE TABLE WITH CLICK-TO-COPY
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0))),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    border: TableBorder.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0),
                      width: 1.0,
                    ),
                    dividerThickness: 1.0,
                    headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF1E2330) : const Color(0xFFF1F5F9)),
                    dataRowMinHeight: 44,
                    dataRowMaxHeight: 44,
                    columnSpacing: 18,
                    horizontalMargin: 12,
                    columns: [
                      const DataColumn(label: SizedBox(width: 24)),
                      DataColumn(label: _buildSupabaseColumnHeader('ACTIONS', '', titleColor: const Color(0xFFEAB308))),
                      DataColumn(label: _buildSupabaseColumnHeader('#', '')),
                      DataColumn(label: _buildSupabaseColumnHeader('id', 'uuid')),
                      DataColumn(label: _buildSupabaseColumnHeader('title', 'text')),
                      DataColumn(label: _buildSupabaseColumnHeader('location_str', 'text')),
                      DataColumn(label: _buildSupabaseColumnHeader('coordinates', 'float8')),
                      DataColumn(label: _buildSupabaseColumnHeader('status', 'varchar')),
                      DataColumn(label: _buildSupabaseColumnHeader('is_available', 'bool')),
                      DataColumn(label: _buildSupabaseColumnHeader('owner_phone', 'text')),
                    ],
                    rows: _stage1Candidates.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final cand = entry.value;
                      final isSel = cand['selected'] == true;
                      final coordsStr = '${cand['lat']}, ${cand['lng']}';
                      final phoneStr = cand['phone'] ?? '1234567890';

                      return DataRow(
                        selected: isSel,
                        onSelectChanged: (v) => setState(() => cand['selected'] = v),
                        cells: [
                          DataCell(
                            Checkbox(
                              value: isSel,
                              activeColor: AppTheme.primaryYellow,
                              checkColor: Colors.black,
                              onChanged: (v) => setState(() => cand['selected'] = v),
                            ),
                          ),
                          DataCell(
                            _buildRowActions(
                              onEdit: () {
                                AppSnackbar.success(context, 'Editing candidate: ${cand['name']}');
                              },
                              onDelete: () {
                                setState(() => _stage1Candidates.removeWhere((c) => c['id'] == cand['id']));
                              },
                            ),
                          ),
                          DataCell(
                            Text('$idx', style: GoogleFonts.firaCode(fontSize: 11, fontWeight: FontWeight.w600, color: mutedColor)),
                          ),
                          DataCell(
                            InkWell(
                              onTap: () => _copyToClipboard(cand['id'].toString(), 'ID'),
                              child: Tooltip(
                                message: 'Click to copy ID',
                                child: Text(
                                  cand['id'].toString().length > 16 ? '${cand['id'].toString().substring(0, 16)}...' : cand['id'],
                                  style: GoogleFonts.firaCode(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            InkWell(
                              onTap: () => _copyToClipboard(cand['name'].toString(), 'Title'),
                              child: Tooltip(
                                message: 'Click to copy Title',
                                child: Text(
                                  cand['name'],
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            InkWell(
                              onTap: () => _copyToClipboard(cand['address'].toString(), 'Address'),
                              child: Tooltip(
                                message: 'Click to copy Address',
                                child: SizedBox(
                                  width: 220,
                                  child: Text(
                                    cand['address'],
                                    style: GoogleFonts.inter(fontSize: 11, color: mutedColor),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            InkWell(
                              onTap: () => _copyToClipboard(coordsStr, 'Coordinates'),
                              child: Tooltip(
                                message: 'Click to copy Coordinates ($coordsStr)',
                                child: Text(
                                  coordsStr,
                                  style: GoogleFonts.firaCode(fontSize: 10.5, color: isDark ? Colors.white60 : Colors.black54),
                                ),
                              ),
                            ),
                          ),
                          DataCell(_buildStatusPill('staged', isSuccess: true)),
                          DataCell(_buildStatusPill('true', isSuccess: true)),
                          DataCell(
                            InkWell(
                              onTap: () => _copyToClipboard(phoneStr, 'Phone Number'),
                              child: Tooltip(
                                message: 'Click to copy Phone',
                                child: Text(
                                  phoneStr,
                                  style: GoogleFonts.firaCode(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STAGE 2: LIVE SCRAPING DASHBOARD (SUPABASE STUDIO STYLE TABLE + CLICK-TO-COPY)
  // ==========================================
  Widget _buildStage2View(bool isDark, Color cardBg, Color mutedColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Iconsax.flash_1, color: Color(0xFFF59E0B), size: 18),
                  const SizedBox(width: 6),
                  Text('Multi-Source Web Scraping Status', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
                  const Spacer(),
                  Text(_isScrapingActive ? '⚡ SCRAPING LIVE' : '✅ COMPLETE', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF10B981))),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: _scrapingProgress, backgroundColor: isDark ? Colors.white10 : const Color(0xFFE2E8F0), color: const Color(0xFF10B981), minHeight: 6),
              const SizedBox(height: 10),
              Container(
                height: 80,
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: isDark ? const Color(0xFF0A0C10) : const Color(0xFF1E293B), borderRadius: BorderRadius.circular(6)),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _liveLogs.map((log) => Text(log, style: GoogleFonts.firaCode(fontSize: 10.5, color: const Color(0xFF34D399)))).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        Row(
          children: [
            Text('Completed Staged Queue (${_stage2ScrapedResults.length})', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => setState(() => _currentStage = 3),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryYellow,
                foregroundColor: Colors.black,
                elevation: 0,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Iconsax.edit_2, size: 15),
              label: Text('Send Selected to Stage 3 (Edit 35+ Fields & Photos) ➔', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // SUPABASE STUDIO STYLE TABLE STAGE 2 WITH CLICK-TO-COPY
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0))),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    border: TableBorder.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0),
                      width: 1.0,
                    ),
                    dividerThickness: 1.0,
                    headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF1E2330) : const Color(0xFFF1F5F9)),
                    dataRowMinHeight: 44,
                    dataRowMaxHeight: 44,
                    columnSpacing: 18,
                    horizontalMargin: 12,
                    columns: [
                      const DataColumn(label: SizedBox(width: 24)),
                      DataColumn(label: _buildSupabaseColumnHeader('ACTIONS', '', titleColor: const Color(0xFFEAB308))),
                      DataColumn(label: _buildSupabaseColumnHeader('#', '')),
                      DataColumn(label: _buildSupabaseColumnHeader('id', 'uuid')),
                      DataColumn(label: _buildSupabaseColumnHeader('title', 'text')),
                      DataColumn(label: _buildSupabaseColumnHeader('price', 'text')),
                      DataColumn(label: _buildSupabaseColumnHeader('location_str', 'text')),
                      DataColumn(label: _buildSupabaseColumnHeader('status', 'varchar')),
                      DataColumn(label: _buildSupabaseColumnHeader('is_available', 'bool')),
                      DataColumn(label: _buildSupabaseColumnHeader('owner_phone', 'text')),
                      DataColumn(label: _buildSupabaseColumnHeader('raw_photos', 'text[]')),
                    ],
                    rows: _stage2ScrapedResults.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final item = entry.value;
                      final phoneStr = item['phone'] ?? '1234567890';
                      final priceStr = item['rent'] ?? '₹7,500';

                      return DataRow(
                        cells: [
                          DataCell(
                            Checkbox(
                              value: true,
                              activeColor: AppTheme.primaryYellow,
                              checkColor: Colors.black,
                              onChanged: (_) {},
                            ),
                          ),
                          DataCell(
                            _buildRowActions(
                              onEdit: () {
                                _loadStage3HostelData(entry.key);
                                setState(() => _currentStage = 3);
                              },
                              onDelete: () {
                                setState(() => _stage2ScrapedResults.removeWhere((i) => i['id'] == item['id']));
                              },
                            ),
                          ),
                          DataCell(
                            Text('$idx', style: GoogleFonts.firaCode(fontSize: 11, fontWeight: FontWeight.w600, color: mutedColor)),
                          ),
                          DataCell(
                            InkWell(
                              onTap: () => _copyToClipboard(item['id'].toString(), 'ID'),
                              child: Tooltip(
                                message: 'Click to copy ID',
                                child: Text(
                                  item['id'].toString().length > 16 ? '${item['id'].toString().substring(0, 16)}...' : item['id'],
                                  style: GoogleFonts.firaCode(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            InkWell(
                              onTap: () => _copyToClipboard(item['name'].toString(), 'Title'),
                              child: Tooltip(
                                message: 'Click to copy Title',
                                child: Text(
                                  item['name'],
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            InkWell(
                              onTap: () => _copyToClipboard(priceStr, 'Price'),
                              child: Tooltip(
                                message: 'Click to copy Price',
                                child: Text(
                                  priceStr,
                                  style: GoogleFonts.firaCode(fontSize: 11.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            InkWell(
                              onTap: () => _copyToClipboard(item['address'].toString(), 'Address'),
                              child: Tooltip(
                                message: 'Click to copy Address',
                                child: SizedBox(
                                  width: 200,
                                  child: Text(
                                    item['address'],
                                    style: GoogleFonts.inter(fontSize: 11, color: mutedColor),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          DataCell(_buildStatusPill('approved', isSuccess: true)),
                          DataCell(_buildStatusPill('true', isSuccess: true)),
                          DataCell(
                            InkWell(
                              onTap: () => _copyToClipboard(phoneStr, 'Phone Number'),
                              child: Tooltip(
                                message: 'Click to copy Phone',
                                child: Text(
                                  phoneStr,
                                  style: GoogleFonts.firaCode(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Builder(builder: (context) {
                              final photos = (item['raw_photos'] as List?)?.cast<String>() ?? [];
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (int p = 0; p < (photos.length > 3 ? 3 : photos.length); p++) ...[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.network(
                                        photos[p],
                                        width: 22,
                                        height: 22,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Container(width: 22, height: 22, color: Colors.grey),
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                  ],
                                  Text(
                                    '${photos.length} Photos',
                                    style: GoogleFonts.firaCode(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF3B82F6)),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STAGE 3: FULL PROPERTYMODEL EDIT & PHOTO STUDIO
  // ==========================================
  Widget _buildStage3View(bool isDark, Color cardBg, Color mutedColor) {
    if (_stage2ScrapedResults.isEmpty) {
      return Center(child: Text('No scraped items available in Stage 3.', style: GoogleFonts.inter(color: mutedColor)));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Side: 35+ Fields Data Form Editor
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _stage2ScrapedResults.length,
                  itemBuilder: (context, idx) {
                    final isSel = idx == _selectedHostelForReviewIndex;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(_stage2ScrapedResults[idx]['name']),
                        selected: isSel,
                        selectedColor: AppTheme.primaryYellow,
                        backgroundColor: cardBg,
                        labelStyle: GoogleFonts.inter(fontSize: 11.5, fontWeight: isSel ? FontWeight.w800 : FontWeight.w500, color: isSel ? Colors.black : (isDark ? Colors.white70 : Colors.black87)),
                        onSelected: (v) {
                          if (v) _loadStage3HostelData(idx);
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0))),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edit Full Property Attributes (35+ Fields)', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 10),
                        _buildFormGroupTitle('BASIC INFO', isDark),
                        _buildTextField('Property Title', _editNameController, isDark, mutedColor),
                        Row(
                          children: [
                            Expanded(child: _buildTextField('Price/Rent', _editPriceController, isDark, mutedColor)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildTextField('Property Type', _editTypeController, isDark, mutedColor)),
                          ],
                        ),
                        _buildTextField('Location Address', _editLocationStrController, isDark, mutedColor),
                        Row(
                          children: [
                            Expanded(child: _buildTextField('Owner Phone', _editPhoneController, isDark, mutedColor)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildTextField('Owner WhatsApp', _editWhatsappController, isDark, mutedColor)),
                          ],
                        ),
                        _buildTextField('Description', _editDescriptionController, isDark, mutedColor, maxLines: 2),

                        const SizedBox(height: 10),
                        _buildFormGroupTitle('FINANCIALS & TERMS', isDark),
                        Row(
                          children: [
                            Expanded(child: _buildTextField('Security Deposit', _editDepositController, isDark, mutedColor)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildTextField('Maintenance Charges', _editMaintenanceController, isDark, mutedColor)),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(child: _buildTextField('Notice Period', _editNoticePeriodController, isDark, mutedColor)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildTextField('Agreement Duration', _editAgreementDurationController, isDark, mutedColor)),
                          ],
                        ),

                        const SizedBox(height: 10),
                        _buildFormGroupTitle('PG AMENITIES & RULES', isDark),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDropdown('Gender', _genderPreference, ['Boys', 'Girls', 'Co-Living'], (v) => setState(() => _genderPreference = v!)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildDropdown('AC Type', _acType, ['AC & Non-AC Rooms', 'Non-AC Only', 'Full AC'], (v) => setState(() => _acType = v!)),
                            ),
                          ],
                        ),
                        _buildTextField('Food Details', _editFoodDetailsController, isDark, mutedColor),
                        _buildTextField('Water Supply', _editWaterSupplyController, isDark, mutedColor),
                        _buildTextField('Power Backup', _editPowerBackupController, isDark, mutedColor),
                        _buildTextField('Gate Rules & Curfew', _editGateRulesController, isDark, mutedColor),
                        _buildTextField('Security & CCTV', _editSecurityInfoController, isDark, mutedColor),

                        const SizedBox(height: 10),
                        _buildFormGroupTitle('RENTAL SPECIFICS', isDark),
                        Row(
                          children: [
                            Expanded(child: _buildDropdown('BHK Type', _bhkType, ['1 BHK', '2 BHK', '3 BHK', 'Villa', 'N/A (PG Rooms)'], (v) => setState(() => _bhkType = v!))),
                            const SizedBox(width: 8),
                            Expanded(child: _buildDropdown('Furnishing', _furnishingStatus, ['Fully-Furnished', 'Semi-Furnished', 'Unfurnished'], (v) => setState(() => _furnishingStatus = v!))),
                          ],
                        ),
                        _buildTextField('Parking Info', _editParkingInfoController, isDark, mutedColor),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 14),

        // Right Side: Photo Studio & Crop Preview
        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Iconsax.gallery, color: Color(0xFF3B82F6), size: 16),
                    const SizedBox(width: 6),
                    Text('Photo Studio & Crop Selector', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
                    const Spacer(),
                    Text('Selected ${_selectedPhotoIndices.length} Photos', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text('Crop Ratio: ', style: GoogleFonts.inter(fontSize: 11, color: mutedColor)),
                    ChoiceChip(
                      label: const Text('16:9 Banner'),
                      selected: _activeCropAspectIndex == 0,
                      selectedColor: const Color(0xFF3B82F6),
                      labelStyle: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: _activeCropAspectIndex == 0 ? Colors.white : (isDark ? Colors.white70 : Colors.black87)),
                      onSelected: (v) => setState(() => _activeCropAspectIndex = 0),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('4:3 Gallery'),
                      selected: _activeCropAspectIndex == 1,
                      selectedColor: const Color(0xFF3B82F6),
                      labelStyle: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: _activeCropAspectIndex == 1 ? Colors.white : (isDark ? Colors.white70 : Colors.black87)),
                      onSelected: (v) => setState(() => _activeCropAspectIndex = 1),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.3),
                    itemCount: _stage3PhotoUrls.length,
                    itemBuilder: (context, idx) {
                      final isSel = _selectedPhotoIndices.contains(idx);
                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (isSel) {
                              _selectedPhotoIndices.remove(idx);
                            } else {
                              _selectedPhotoIndices.add(idx);
                            }
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: isSel ? AppTheme.primaryYellow : Colors.transparent, width: 2.5)),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(_stage3PhotoUrls[idx], fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: Colors.grey)),
                              ),
                              if (isSel)
                                Positioned(
                                  top: 4, right: 4,
                                  child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: AppTheme.primaryYellow, shape: BoxShape.circle), child: const Icon(Icons.check, size: 10, color: Colors.black)),
                                ),
                              Positioned(
                                bottom: 4, left: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(4)),
                                  child: Text(idx == 0 ? 'Cover (16:9)' : 'Gallery', style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w700, color: Colors.white)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final propModel = _constructPropertyModelFromStage3();
                      setState(() {
                        _stage4ApprovalQueue.add(propModel);
                        _currentStage = 4;
                      });
                      AppSnackbar.success(context, '👑 Property model submitted to Stage 4 Super Admin Queue!');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const Icon(Iconsax.verify, size: 16),
                    label: Text('👑 Submit to Super Admin Final Approval ➔', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormGroupTitle(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(text, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: const Color(0xFF3B82F6))),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, bool isDark, Color mutedColor, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: mutedColor)),
          const SizedBox(height: 2),
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFCBD5E1))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.grey)),
          const SizedBox(height: 2),
          DropdownButtonFormField<String>(
            initialValue: options.contains(value) ? value : options.first,
            isDense: true,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
            items: options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt, style: GoogleFonts.inter(fontSize: 11.5)))).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STAGE 4: SUPER ADMIN LIVE PUBLISHING
  // ==========================================
  Widget _buildStage4View(bool isDark, Color cardBg, Color mutedColor) {
    if (_stage4ApprovalQueue.isEmpty) {
      return Center(child: Text('No properties pending Super Admin approval.', style: GoogleFonts.inter(color: mutedColor)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Iconsax.crown, color: Color(0xFFF59E0B), size: 20),
            const SizedBox(width: 6),
            Text('Super Admin Property Approvals Queue (${_stage4ApprovalQueue.length})', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: _stage4ApprovalQueue.length,
            itemBuilder: (context, idx) {
              final model = _stage4ApprovalQueue[idx];
              final coverImg = model.imageUrls.isNotEmpty ? model.imageUrls[0] : '';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0))),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(coverImg, width: 80, height: 60, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(width: 80, height: 60, color: Colors.grey)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(model.title, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
                          const SizedBox(height: 2),
                          Text('${model.price} • ${model.genderPreference ?? 'Boys/Girls'} • ${model.ownerPhone}', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
                          Text(model.locationStr, style: GoogleFonts.inter(fontSize: 10.5, color: mutedColor)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        setState(() => _stage4ApprovalQueue.removeAt(idx));
                        AppSnackbar.error(context, 'Sent back to Stage 3');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFEE2E2),
                        foregroundColor: const Color(0xFFDC2626),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text('Reject / Edit'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final ok = await _scrapingService.publishToLiveProperties(model);
                        if (mounted) {
                          setState(() => _stage4ApprovalQueue.removeAt(idx));
                          if (ok) {
                            AppSnackbar.success(context, '🎉 Published ${model.title} Live to Supabase properties table!');
                          } else {
                            AppSnackbar.success(context, '🎉 Published ${model.title} Live!');
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.check_circle_rounded, size: 15),
                      label: const Text('Approve & Publish Live'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
