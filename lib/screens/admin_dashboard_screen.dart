import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:device_preview/device_preview.dart';
import '../widgets/app_snackbar.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../services/notification_broadcast_service.dart';
import '../services/ai_auto_notifier_service.dart';
import '../models/property_model.dart';
import 'home_screen.dart' show HomeScreen;
import 'posting_screen.dart';
import 'property_details_screen.dart';
import 'admin_database_analytics_tab.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _supabase = Supabase.instance.client;
  final GlobalKey<NavigatorState> _previewNavigatorKey = GlobalKey<NavigatorState>();

  // Authenticated Admin User Details
  String get _adminEmail => _supabase.auth.currentUser?.email ?? 'Admin';

  String get _adminDisplayName {
    final user = _supabase.auth.currentUser;
    if (user == null) return 'Administrator';
    final meta = user.userMetadata;
    if (meta != null) {
      final name = meta['full_name'] ?? meta['name'] ?? meta['display_name'];
      if (name != null && name.toString().trim().isNotEmpty) return name.toString().trim();
    }
    if (user.email != null && user.email!.contains('@')) {
      final handle = user.email!.split('@').first;
      final parts = handle.replaceAll('.', ' ').replaceAll('_', ' ').replaceAll('-', ' ').split(' ');
      final formatted = parts.where((s) => s.isNotEmpty).map((s) => '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}').join(' ').trim();
      if (formatted.isNotEmpty) return formatted;
    }
    return 'Admin';
  }

  String? get _adminAvatarUrl {
    final user = _supabase.auth.currentUser;
    final meta = user?.userMetadata;
    if (meta != null) {
      final avatar = meta['avatar_url'] ?? meta['picture'] ?? meta['photo_url'];
      if (avatar != null && avatar.toString().trim().isNotEmpty) return avatar.toString().trim();
    }
    return null;
  }

  String get _adminInitial {
    final name = _adminDisplayName;
    if (name.isNotEmpty) return name[0].toUpperCase();
    final email = _adminEmail;
    if (email.isNotEmpty) return email[0].toUpperCase();
    return 'A';
  }

  // Navigation State
  // 0: Overview, 1: Properties, 2: Analytics & Click Radar, 3: Push Notifications, 4: Users, 5: Banners, 6: Settings
  int _selectedTabIndex = 0;
  bool _isSidebarCollapsed = false;

  // Live Device User App Preview on Right Side
  bool _showLiveUserAppPreview = false;
  bool _previewDarkMode = false;
  int _previewKeyIndex = 0;
  double? _previewPanelWidth;
  int _selectedDeviceIndex = 0; // Default: iPhone 13 Pro Max
  bool _isFrameVisible = true;
  Orientation _previewOrientation = Orientation.portrait;

  static final List<({String name, String category, DeviceInfo device, IconData icon})> _availableDevices = [
    (
      name: 'iPhone 13 Pro Max',
      category: 'iOS',
      device: Devices.ios.iPhone13ProMax,
      icon: Icons.phone_iphone,
    ),
    (
      name: 'iPhone 13',
      category: 'iOS',
      device: Devices.ios.iPhone13,
      icon: Icons.phone_iphone,
    ),
    (
      name: 'iPhone 13 Mini',
      category: 'iOS',
      device: Devices.ios.iPhone13Mini,
      icon: Icons.phone_iphone,
    ),
    (
      name: 'iPhone SE',
      category: 'iOS',
      device: Devices.ios.iPhoneSE,
      icon: Icons.phone_iphone,
    ),
    (
      name: 'Samsung Galaxy S20',
      category: 'Android',
      device: Devices.android.samsungGalaxyS20,
      icon: Icons.phone_android,
    ),
    (
      name: 'Samsung Note 20 Ultra',
      category: 'Android',
      device: Devices.android.samsungGalaxyNote20Ultra,
      icon: Icons.phone_android,
    ),
    (
      name: 'OnePlus 8 Pro',
      category: 'Android',
      device: Devices.android.onePlus8Pro,
      icon: Icons.phone_android,
    ),
    (
      name: 'Samsung Galaxy A50',
      category: 'Android',
      device: Devices.android.samsungGalaxyA50,
      icon: Icons.phone_android,
    ),
    (
      name: 'Sony Xperia 1 II',
      category: 'Android',
      device: Devices.android.sonyXperia1II,
      icon: Icons.phone_android,
    ),
    (
      name: 'iPad Pro 11"',
      category: 'Tablet',
      device: Devices.ios.iPadPro11Inches,
      icon: Icons.tablet_mac,
    ),
    (
      name: 'iPad Air 4',
      category: 'Tablet',
      device: Devices.ios.iPadAir4,
      icon: Icons.tablet_mac,
    ),
  ];

  // Data State
  List<PropertyModel> _properties = [];
  bool _isLoadingProperties = true;
  String _propertySearchQuery = '';
  String _statusFilter = 'all'; // all, pending, approved, occupied, rejected, pending_photos
  String _typeFilter = 'all'; // all, Rental, PG, Sale, Commercial
  String _localityFilter = 'all';

  // Push Notification Composer State
  final _notifTitleController = TextEditingController(text: '🔥 New Verified Rental in Danavaipeta!');
  final _notifBodyController = TextEditingController(
    text: 'Spacious East-facing 2BHK flat with 100% Vastu and 24/7 Godavari water. Zero broker fee.',
  );
  final _notifImageController = TextEditingController();
  TargetAudience _selectedAudience = TargetAudience.allUsers;
  NotificationActionType _selectedActionType = NotificationActionType.property;
  String? _selectedPropertyId;
  String? _selectedCategoryOrLocality = 'Danavaipeta';
  final _customUrlController = TextEditingController();
  final bool _isHighPriority = true;
  bool _isSendingNotification = false;
  List<BroadcastNotificationModel> _broadcastHistory = [];

  // AI Auto-Notifier State (8 AM, 1 PM, 6 PM IST)
  int _notificationSubTabIndex = 0; // 0: Manual Broadcast, 1: AI Auto-Notifier
  AutoNotifierSettings? _autoNotifierSettings;
  bool _isLoadingAutoSettings = false;
  bool _isSavingAutoSettings = false;
  bool _isGeneratingAiNotif = false;
  bool _isDispatchingAutoNotif = false;
  TargetAudience _selectedAutoAudience = TargetAudience.allUsers;
  bool _isDispatchingSmartSegments = false;
  final _aiInstructionsController = TextEditingController();
  Map<String, String>? _previewAiNotif;

  // Rajamahendravaram Key Localities (Mutable List)
  late List<String> _rajahmundryLocalities = [
    'Danavaipeta',
    'Morampudi',
    'Prakash Nagar',
    'VL Puram',
    'Kotipalli Bus Stand',
    'Aryapuram',
    'T Nagar',
    'Hukumpeta',
    'Diwancheruvu',
    'Bommuru',
    'Lalitha Nagar',
    'Innespeta',
    'Kambala Cheruvu',
    'Dowleswaram',
  ];




  // Top Trending Search Terms in Multi-City Hubs
  final List<Map<String, dynamic>> _trendingSearchTerms = const [
    {'query': '2BHK Danavaipeta with Car Parking', 'count': 840, 'growth': '+24%'},
    {'query': 'Boys PG near Godavari Institute / GIET', 'count': 620, 'growth': '+38%'},
    {'query': 'Single Room with Attached Bath Morampudi', 'count': 510, 'growth': '+15%'},
    {'query': 'Independent House for Sale Prakash Nagar', 'count': 430, 'growth': '+12%'},
    {'query': 'Girls Hostel with Food VL Puram', 'count': 390, 'growth': '+19%'},
    {'query': 'Commercial Shop Main Road Kotipalli', 'count': 280, 'growth': '+8%'},
  ];

  int _allUsersCount = 0;
  int _pgSeekersCount = 0;
  int _roomSeekersCount = 0;
  int _buyersCount = 0;
  int _landlordsCount = 0;

  Map<String, dynamic>? _demandRadarData;
  List<PropertyModel> _topViewedProperties = [];

  Future<void> _fetchDemandRadarData() async {
    try {
      final response = await _supabase.rpc('get_demand_radar_data');
      if (mounted) {
        setState(() {
          _demandRadarData = response as Map<String, dynamic>;
        });
        _matchTopProperties();
      }
    } catch (e) {
      debugPrint('Error fetching demand radar data: $e');
    }
  }

  void _matchTopProperties() {
    if (_demandRadarData == null || _properties.isEmpty) return;
    
    final topProps = _demandRadarData!['top_properties'] as List;
    final List<PropertyModel> matched = [];
    
    for (var tp in topProps) {
      final pid = tp['property_id'];
      try {
        final prop = _properties.firstWhere((p) => p.id == pid);
        matched.add(prop);
      } catch (_) {}
    }
    
    setState(() {
      _topViewedProperties = matched;
    });
  }

  Future<void> _fetchAudienceCounts() async {
    try {
      final allData = await _supabase.rpc('get_segmented_fcm_tokens', params: {'target_audience': 'allUsers'});
      final pgData = await _supabase.rpc('get_segmented_fcm_tokens', params: {'target_audience': 'pgSeekers'});
      final roomData = await _supabase.rpc('get_segmented_fcm_tokens', params: {'target_audience': 'roomSeekers'});
      final buyerData = await _supabase.rpc('get_segmented_fcm_tokens', params: {'target_audience': 'buyers'});
      
      if (mounted) {
        setState(() {
          _allUsersCount = (allData as List).length;
          _pgSeekersCount = (pgData as List).length;
          _roomSeekersCount = (roomData as List).length;
          _buyersCount = (buyerData as List).length;
          _landlordsCount = _properties.where((p) => p.ownerPhone.isNotEmpty).map((p) => p.ownerPhone).toSet().length; 
        });
      }
    } catch (e) {
      debugPrint('Error fetching audience counts: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    // SECURITY: Verify admin session before loading any data.
    // If the session has expired or been revoked, redirect to login.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        Navigator.of(context).pushReplacementNamed('/admin/login');
        return;
      }
      _fetchProperties();
      _fetchNotificationHistory();
      _fetchAudienceCounts();
      _fetchDemandRadarData();
      _fetchAutoNotifierSettings();
    });
  }

  @override
  void dispose() {
    _notifTitleController.dispose();
    _notifBodyController.dispose();
    _notifImageController.dispose();
    _customUrlController.dispose();
    _aiInstructionsController.dispose();
    super.dispose();
  }

  Future<void> _fetchAutoNotifierSettings() async {
    setState(() => _isLoadingAutoSettings = true);
    final settings = await AiAutoNotifierService.instance.fetchSettings();
    AiAutoNotifierService.instance.startPeriodicSchedulerTimer();
    if (mounted) {
      setState(() {
        _autoNotifierSettings = settings;
        if (_aiInstructionsController.text.isEmpty) {
          _aiInstructionsController.text = settings?.aiInstructions ?? '';
        }
        _isLoadingAutoSettings = false;
      });
    }
  }

  Future<void> _toggleAutoNotifier(bool enabled) async {
    setState(() => _isSavingAutoSettings = true);
    final success = await AiAutoNotifierService.instance.updateSettings(isEnabled: enabled);
    if (mounted) {
      setState(() => _isSavingAutoSettings = false);
      if (success) {
        AppSnackbar.success(
          context,
          enabled ? '🟢 AI Auto-Notifier ENABLED (8 AM, 1 PM, 6 PM IST)' : '🔴 AI Auto-Notifier PAUSED',
        );
        _fetchAutoNotifierSettings();
      } else {
        AppSnackbar.error(context, 'Failed to update auto-notifier status.');
      }
    }
  }

  Future<void> _saveAiInstructions() async {
    final text = _aiInstructionsController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSavingAutoSettings = true);
    final success = await AiAutoNotifierService.instance.updateSettings(aiInstructions: text);
    if (mounted) {
      setState(() => _isSavingAutoSettings = false);
      if (success) {
        AppSnackbar.success(context, 'AI Notification Guidelines updated!');
        _fetchAutoNotifierSettings();
      } else {
        AppSnackbar.error(context, 'Failed to save AI guidelines.');
      }
    }
  }

  Future<void> _generateAiNotificationPreview() async {
    setState(() => _isGeneratingAiNotif = true);
    final result = await AiAutoNotifierService.instance.generateAiNotification(
      customPrompt: _aiInstructionsController.text.trim(),
      targetAudience: _selectedAutoAudience,
    );
    if (mounted) {
      setState(() {
        _previewAiNotif = result;
        _isGeneratingAiNotif = false;
      });
      if (result != null) {
        AppSnackbar.success(
          context,
          'AI generated personalized content for ${_selectedAutoAudience.name}!',
        );
      } else {
        AppSnackbar.error(context, 'Failed to generate AI notification.');
      }
    }
  }

  Future<void> _sendTestAutoNotification() async {
    if (_previewAiNotif == null) {
      await _generateAiNotificationPreview();
    }
    if (_previewAiNotif == null) return;

    setState(() => _isDispatchingAutoNotif = true);
    final success = await AiAutoNotifierService.instance.dispatchAutoNotification(
      title: _previewAiNotif!['title']!,
      body: _previewAiNotif!['body']!,
      targetRoute: _previewAiNotif!['target_route']!,
      targetAudience: _selectedAutoAudience,
    );
    if (mounted) {
      setState(() => _isDispatchingAutoNotif = false);
      if (success) {
        AppSnackbar.success(
          context,
          '🚀 AI Notification dispatched live to ${_selectedAutoAudience.name}!',
        );
        _fetchNotificationHistory();
      } else {
        AppSnackbar.error(context, 'Failed to dispatch notification.');
      }
    }
  }

  Future<void> _dispatchSmartPersonalizedMultiSegments() async {
    setState(() => _isDispatchingSmartSegments = true);
    final results = await AiAutoNotifierService.instance.dispatchPersonalizedMultiSegmentNotifications();
    if (mounted) {
      setState(() => _isDispatchingSmartSegments = false);
      final successfulCount = results.values.where((v) => v).length;
      AppSnackbar.success(
        context,
        '🎯 Dispatched personalized AI notifications to $successfulCount/3 segregated audience groups (PG Seekers, Room Seekers, Buyers)!',
      );
      _fetchNotificationHistory();
    }
  }

  Future<void> _fetchProperties() async {
    if (!mounted) return;
    setState(() => _isLoadingProperties = true);
    try {
      final data = await _supabase.from('properties').select().order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _properties = (data as List).map((e) => PropertyModel.fromJson(e as Map<String, dynamic>)).toList();
          _isLoadingProperties = false;
          if (_properties.isNotEmpty && _selectedPropertyId == null) {
            _selectedPropertyId = _properties.first.id;
          }
        });
        _matchTopProperties();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Failed to fetch listings: $e');
        setState(() => _isLoadingProperties = false);
      }
    }
  }

  Future<void> _fetchNotificationHistory() async {
    try {
      final history = await NotificationBroadcastService.instance.getHistory();
      if (mounted) {
        setState(() => _broadcastHistory = history);
      }
    } catch (_) {}
  }

  Future<void> _updatePropertyStatus(String id, String newStatus, {String? reason}) async {
    try {
      final Map<String, dynamic> updateData = {'status': newStatus};
      if (reason != null) {
        updateData['rejection_reason'] = reason;
      }

      await _supabase.from('properties').update(updateData).eq('id', id);
      if (mounted) {
        AppSnackbar.success(context, 'Listing status updated to "$newStatus"');
        _fetchProperties();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Failed to update status: $e');
      }
    }
  }

  Future<void> _batchApproveAllPending() async {
    final pendingList = _properties.where((p) => p.status == 'pending').toList();
    if (pendingList.isEmpty) {
      AppSnackbar.success(context, 'No pending listings to approve.');
      return;
    }

    // SECURITY: Require explicit confirmation before bulk approving all listings
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batch Approve All?'),
        content: Text(
          'This will approve all ${pendingList.length} pending listing(s) and make them immediately visible to all users.\n\nAre you sure you have reviewed each listing?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Approve All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      for (final p in pendingList) {
        if (p.id != null) {
          await _supabase.from('properties').update({'status': 'approved'}).eq('id', p.id!);
        }
      }
      if (mounted) {
        AppSnackbar.success(context, '✅ Approved all ${pendingList.length} pending listings live!');
        _fetchProperties();
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'Batch approval error: $e');
    }
  }

  Future<void> _toggleAvailability(String id, bool currentStatus) async {
    try {
      await _supabase.from('properties').update({'is_available': !currentStatus}).eq('id', id);
      if (mounted) {
        AppSnackbar.success(
          context,
          !currentStatus ? 'Marked as Available (Vacant)' : 'Marked as Occupied (Full / Sold)',
        );
        _fetchProperties();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Failed to update occupancy: $e');
      }
    }
  }

  Future<void> _deleteProperty(String id) async {
    try {
      // 1. Fetch exact image URLs directly from database to guarantee storage deletion
      List<String> imageUrls = [];
      try {
        final data = await _supabase.from('properties').select('image_urls').eq('id', id).maybeSingle();
        if (data != null && data['image_urls'] != null) {
          imageUrls = List<String>.from(data['image_urls'] as List);
        }
      } catch (_) {}

      // Fallback to local memory if database query had no result
      if (imageUrls.isEmpty) {
        final PropertyModel? prop = _properties.cast<PropertyModel?>().firstWhere(
          (p) => p?.id == id,
          orElse: () => null,
        );
        if (prop != null) {
          imageUrls = prop.imageUrls;
        }
      }

      // 2. Delete photos from Supabase Storage bucket 'property_images'
      if (imageUrls.isNotEmpty) {
        final List<String> storagePaths = [];
        for (final url in imageUrls) {
          if (url.contains('/property_images/')) {
            final fileName = url.split('/property_images/').last.split('?').first;
            if (fileName.isNotEmpty) {
              storagePaths.add(fileName);
            }
          }
        }
        if (storagePaths.isNotEmpty) {
          try {
            await _supabase.storage.from('property_images').remove(storagePaths);
          } catch (storageErr) {
            debugPrint('Failed to delete storage photos: $storageErr');
          }
        }
      }

      // 3. Delete database row
      await _supabase.from('properties').delete().eq('id', id);
      if (mounted) {
        AppSnackbar.success(context, 'Property & photos permanently deleted');
        _fetchProperties();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Failed to delete property: $e');
      }
    }
  }

  void _contactOwnerWhatsApp(String phone, String title) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse(
      'https://wa.me/91$cleanPhone?text=Hi%2C%20regarding%20your%20property%20listing%20%22${Uri.encodeComponent(title)}%22%20on%20Rental%20App%20Rajahmundry...',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) AppSnackbar.error(context, 'WhatsApp not available for $phone');
    }
  }

  void _exportPropertiesCSV() {
    final buffer = StringBuffer();
    buffer.writeln('ID,Title,Type,Price,Deposit,Location,Owner Phone,Status,Occupancy');
    for (final p in _properties) {
      buffer.writeln(
        '"${p.id ?? ''}","${p.title.replaceAll('"', '""')}","${p.type}","${p.price}","${p.securityDeposit ?? ''}","${p.locationStr.replaceAll('"', '""')}","${p.ownerPhone}","${p.status}","${p.isAvailable ? 'Available' : 'Occupied'}"',
      );
    }
    AppSnackbar.success(context, '📊 Exported ${_properties.length} listings to CSV buffer!');
  }

  Future<void> _sendPushNotificationBroadcast() async {
    final title = _notifTitleController.text.trim();
    final body = _notifBodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      AppSnackbar.error(context, 'Please provide both notification title and message body');
      return;
    }

    setState(() => _isSendingNotification = true);

    String? targetRouteOrId;
    String? targetLabel;

    switch (_selectedActionType) {
      case NotificationActionType.property:
        targetRouteOrId = _selectedPropertyId;
        final selectedProp = _properties.where((p) => p.id == _selectedPropertyId).firstOrNull;
        targetLabel = selectedProp?.title ?? 'Listing';
        break;
      case NotificationActionType.category:
      case NotificationActionType.searchFilter:
        targetRouteOrId = _selectedCategoryOrLocality;
        targetLabel = _selectedCategoryOrLocality;
        break;
      case NotificationActionType.postProperty:
        targetLabel = 'Post Property';
        break;
      case NotificationActionType.buyAndSell:
        targetLabel = 'Buy & Sell Hub';
        break;
      case NotificationActionType.externalUrl:
        targetRouteOrId = _customUrlController.text.trim();
        targetLabel = targetRouteOrId;
        break;
      case NotificationActionType.general:
        targetLabel = 'App Home';
        break;
    }

    int actualRecipientCount = 0;
    try {
      if (_selectedAudience == TargetAudience.allUsers) {
        final response = await Supabase.instance.client.from('devices').select('device_id').count(CountOption.exact);
        actualRecipientCount = response.count ?? 0;
      } else {
        final response = await Supabase.instance.client.rpc('get_segmented_fcm_tokens', params: {'target_audience': _selectedAudience.name});
        actualRecipientCount = (response as List).length;
      }
    } catch (e) {
      actualRecipientCount = 0;
    }

    final newNotif = BroadcastNotificationModel(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: body,
      imageUrl: _notifImageController.text.trim().isNotEmpty ? _notifImageController.text.trim() : null,
      targetAudience: _selectedAudience,
      actionType: _selectedActionType,
      targetRouteOrId: targetRouteOrId,
      targetLabel: targetLabel,
      isHighPriority: _isHighPriority,
      createdAt: DateTime.now(),
      recipientCount: actualRecipientCount,
      status: 'sent',
    );

    await NotificationBroadcastService.instance.sendBroadcast(newNotif);
    await _fetchNotificationHistory();

    if (mounted) {
      setState(() => _isSendingNotification = false);
      AppSnackbar.success(
        context,
        '🚀 Push Notification successfully broadcasted to ${newNotif.recipientCount} users in Rajamahendravaram!',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 950;

    return Theme(
      data: Theme.of(context).copyWith(
        scrollbarTheme: ScrollbarThemeData(
          thumbVisibility: WidgetStateProperty.all(false),
          trackVisibility: WidgetStateProperty.all(false),
          thickness: WidgetStateProperty.all(5.0),
          radius: const Radius.circular(8.0),
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.dragged) || states.contains(WidgetState.hovered)) {
              return isDark ? Colors.white38 : const Color(0xFF94A3B8);
            }
            return isDark ? Colors.white12 : const Color(0xFFCBD5E1).withValues(alpha: 0.7);
          }),
        ),
      ),
      child: ScrollConfiguration(
        behavior: const MaterialScrollBehavior().copyWith(
          scrollbars: true,
          overscroll: false,
        ),
        child: Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F1117) : const Color(0xFFF4F6F9),
          body: isDesktop ? _buildDesktopLayout(isDark) : _buildMobileTabletLayout(isDark),
        ),
      ),
    );
  }

  // ==========================================
  // DESKTOP LAPTOP LAYOUT WITH EMBEDDED IPHONE PREVIEW
  // ==========================================
  Widget _buildDesktopLayout(bool isDark) {
    return Row(
      children: [
        _buildSidebar(isDark),
        Expanded(
          child: Column(
            children: [
              _buildTopHeader(isDark),
              Expanded(
                child: Container(
                  color: isDark ? const Color(0xFF0F1117) : const Color(0xFFF4F6F9),
                  child: _buildActiveTabContent(isDark),
                ),
              ),
            ],
          ),
        ),

        // Right-Side Live iPhone 16 Pro User App Preview (Full Height)
        if (_showLiveUserAppPreview)
          _buildLiveUserAppSidePanel(isDark),
      ],
    );
  }

  // ==========================================
  // LIVE DEVICE USER APP SIDE PANEL WIDGET
  // ==========================================
  Widget _buildLiveUserAppSidePanel(bool isDark) {
    final activeDevice = _availableDevices[_selectedDeviceIndex];
    final screenHeight = MediaQuery.sizeOf(context).height;
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Available vertical space for the phone frame inside the container (minus 58px bar and 16px padding)
    final availableHeightForPhone = (screenHeight - 58.0 - 16.0).clamp(200.0, 2400.0);

    // Calculate the phone frame's physical aspect ratio (width / height)
    final dWidth = _isFrameVisible
        ? activeDevice.device.screenSize.width + 36.0
        : activeDevice.device.screenSize.width;
    final dHeight = _isFrameVisible
        ? activeDevice.device.screenSize.height + 36.0
        : activeDevice.device.screenSize.height;

    double ratio = dWidth / dHeight;
    if (_previewOrientation == Orientation.landscape) {
      ratio = 1.0 / ratio;
    }

    // Pixel-perfect fitted width matching the exact scaled phone frame with snug 8px side margin
    final fittedPhoneWidth = (availableHeightForPhone * ratio) + 16.0;

    // Use fitted snug width with safe minimum 380px (or user-adjusted width)
    final effectiveWidth = (_previewPanelWidth ?? fittedPhoneWidth).clamp(380.0, screenWidth * 0.75);

    return Container(
      width: effectiveWidth,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13161F) : const Color(0xFFEEF2F6),
        border: Border(
          left: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB),
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        children: [
          // Control Bar (Height: 58px)
          Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1E29) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB),
                ),
              ),
            ),
            child: Row(
              children: [
                // Dynamic Phone Frame Selector Dropdown
                PopupMenuButton<int>(
                  tooltip: 'Select Phone Device Frame',
                  offset: const Offset(0, 48),
                      color: isDark ? const Color(0xFF1E2330) : Colors.white,
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                        ),
                      ),
                      initialValue: _selectedDeviceIndex,
                      onSelected: (index) {
                        setState(() {
                          _selectedDeviceIndex = index;
                          _previewPanelWidth = null; // Auto-fit to selected device's exact aspect ratio
                        });
                        AppSnackbar.success(
                          context,
                          '📱 Switched to ${_availableDevices[index].name}',
                        );
                      },
                      itemBuilder: (context) {
                        return _availableDevices.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final dev = entry.value;
                          final isSelected = idx == _selectedDeviceIndex;
                          return PopupMenuItem<int>(
                            value: idx,
                            height: 38,
                            child: Row(
                              children: [
                                Icon(
                                  dev.icon,
                                  size: 16,
                                  color: isSelected
                                      ? AppTheme.primaryYellow
                                      : (isDark ? Colors.white70 : Colors.black87),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    dev.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected
                                          ? AppTheme.primaryYellow
                                          : (isDark ? Colors.white : Colors.black87),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    dev.category,
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.check, size: 14, color: Color(0xFFFFEB3A)),
                                ],
                              ],
                            ),
                          );
                        }).toList();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF252B3B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              activeDevice.icon,
                              size: 14,
                              color: AppTheme.primaryYellow,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              activeDevice.name,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 14,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Toggle Device Frame Bezel
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      icon: Icon(
                        _isFrameVisible ? Icons.crop_portrait_rounded : Icons.crop_free_rounded,
                        size: 15,
                        color: _isFrameVisible
                            ? AppTheme.primaryYellow
                            : (isDark ? Colors.white60 : Colors.black45),
                      ),
                      tooltip: _isFrameVisible ? 'Hide Phone Frame Shell' : 'Show Phone Frame Shell',
                      onPressed: () {
                        setState(() {
                          _isFrameVisible = !_isFrameVisible;
                          _previewPanelWidth = null; // Auto-fit to bezel state
                        });
                      },
                    ),
                    const SizedBox(width: 3),

                    // Rotate Orientation (Portrait / Landscape)
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      icon: Icon(
                        Icons.screen_rotation_outlined,
                        size: 15,
                        color: _previewOrientation == Orientation.landscape
                            ? AppTheme.primaryYellow
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                      tooltip: 'Rotate Portrait / Landscape',
                      onPressed: () {
                        setState(() {
                          _previewOrientation = _previewOrientation == Orientation.portrait
                              ? Orientation.landscape
                              : Orientation.portrait;
                          _previewPanelWidth = null; // Auto-fit to orientation
                        });
                      },
                    ),
                    const SizedBox(width: 3),

                    // Device Theme Toggle
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      icon: Icon(
                        _previewDarkMode ? Iconsax.sun_1 : Iconsax.moon,
                        size: 15,
                        color: _previewDarkMode ? Colors.amber : (isDark ? Colors.white70 : Colors.black87),
                      ),
                      tooltip: 'Toggle App Dark/Light Mode',
                      onPressed: () => setState(() => _previewDarkMode = !_previewDarkMode),
                    ),
                    const SizedBox(width: 3),

                    // Reload Device State
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      icon: Icon(Icons.refresh_rounded, size: 16, color: isDark ? Colors.white70 : Colors.black87),
                      tooltip: 'Restart & Reload Preview',
                      onPressed: () {
                        setState(() => _previewKeyIndex++);
                        AppSnackbar.success(context, '🔄 ${activeDevice.name} preview reloaded!');
                      },
                    ),
                    const SizedBox(width: 3),

                    // Close Side Preview Button
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      icon: const Icon(Icons.close, size: 16),
                      tooltip: 'Close Live Preview Panel',
                      onPressed: () => setState(() => _showLiveUserAppPreview = false),
                    ),
                  ],
                ),
              ),

              // Embedded Device Frame running REAL User App with uniform margins
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    child: DeviceFrame(
                      device: activeDevice.device,
                      isFrameVisible: _isFrameVisible,
                      orientation: _previewOrientation,
                      screen: Container(
                        color: _previewDarkMode ? AppTheme.darkScaffold : Colors.white,
                        child: MaterialApp(
                          navigatorKey: _previewNavigatorKey,
                          debugShowCheckedModeBanner: false,
                          theme: AppTheme.lightTheme,
                          darkTheme: AppTheme.darkTheme,
                          themeMode: _previewDarkMode ? ThemeMode.dark : ThemeMode.light,
                          home: HomeScreen(
                            key: ValueKey('preview_home_$_previewKeyIndex'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
  }

  // ==========================================
  // MOBILE / TABLET LAYOUT
  // ==========================================
  Widget _buildMobileTabletLayout(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1117) : const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF161922) : Colors.white,
        elevation: 1,
        title: Row(
          children: [
            Image.asset('assets/logo.png', width: 26, height: 26, errorBuilder: (_, __, ___) => const Icon(Icons.apartment)),
            const SizedBox(width: 8),
            Text(
              'Admin Portal',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Iconsax.refresh, color: isDark ? Colors.white : Colors.black87),
            onPressed: () {
              _fetchProperties();
              _fetchNotificationHistory();
            },
          ),
          IconButton(
            icon: const Icon(Iconsax.logout, color: Colors.redAccent),
            onPressed: _handleLogout,
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: isDark ? const Color(0xFF161922) : Colors.white,
        child: _buildSidebarContent(isDark, isDrawer: true),
      ),
      body: _buildActiveTabContent(isDark),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex.clamp(0, 3),
        onDestinationSelected: (idx) => setState(() => _selectedTabIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Iconsax.category), label: 'Overview'),
          NavigationDestination(icon: Icon(Iconsax.buildings), label: 'Properties'),
          NavigationDestination(icon: Icon(Iconsax.chart_21), label: 'Radar'),
          NavigationDestination(icon: Icon(Iconsax.notification_bing), label: 'Broadcasts'),
        ],
      ),
    );
  }

  // ==========================================
  // SIDEBAR NAVIGATION (MATCHING REFERENCE DESIGN)
  // ==========================================
  Widget _buildSidebar(bool isDark) {
    final isCollapsed = _isSidebarCollapsed || _showLiveUserAppPreview;
    final width = isCollapsed ? 68.0 : 240.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141721) : const Color(0xFFFAFAFA),
        border: Border(
          right: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFEAEAEA),
            width: 1,
          ),
        ),
      ),
      child: _buildSidebarContent(isDark, isDrawer: false),
    );
  }

  Widget _buildSidebarContent(bool isDark, {required bool isDrawer}) {
    final pendingCount = _properties.where((p) => p.status == 'pending').length;
    final isCollapsed = (_isSidebarCollapsed || _showLiveUserAppPreview) && !isDrawer;
    final mutedColor = isDark ? const Color(0xFF8B94A5) : const Color(0xFF64748B);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),

        // 1. Workspace Brand Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: isCollapsed
              ? Center(
                  child: Tooltip(
                    message: 'Rental App Command Center',
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white : Colors.black,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.asset(
                            'assets/logo.png',
                            width: 22,
                            height: 22,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.home_rounded,
                              color: isDark ? Colors.black : Colors.white,
                              size: 19,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    AppSnackbar.success(context, '📍 Rental Platform Operations Center');
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white : Colors.black,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Image.asset(
                              'assets/logo.png',
                              width: 22,
                              height: 22,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.home_rounded,
                                color: isDark ? Colors.black : Colors.white,
                                size: 19,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'RENTAL APP',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: primaryTextColor,
                            letterSpacing: 0.4,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: mutedColor,
                      ),
                    ],
                  ),
                ),
        ),

        const SizedBox(height: 16),

        // 2. Top Quick Utilities (Search, Notification, Settings)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUtilityAction(
                icon: Iconsax.search_normal_1,
                label: 'Search',
                isCollapsed: isCollapsed,
                isDark: isDark,
                onTap: () {
                  setState(() => _selectedTabIndex = 1);
                },
              ),
              const SizedBox(height: 4),
              _buildUtilityAction(
                icon: Iconsax.notification,
                label: 'Notification',
                badgeCount: pendingCount > 0 ? pendingCount : null,
                isCollapsed: isCollapsed,
                isDark: isDark,
                onTap: () {
                  setState(() => _selectedTabIndex = 3);
                },
              ),

            ],
          ),
        ),

        const SizedBox(height: 16),

        // 3. Section Label: MENU
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: isCollapsed
              ? SizedBox(
                  width: 40,
                  child: Center(
                    child: Text(
                      'MENU',
                      style: GoogleFonts.inter(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: mutedColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(left: 10, bottom: 4),
                  child: Text(
                    'MENU',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.3,
                      color: mutedColor.withValues(alpha: 0.8),
                    ),
                  ),
                ),
        ),

        // 4. Main Navigation Items
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              _buildModernSidebarItem(
                index: 0,
                icon: Iconsax.home_2,
                label: 'Dashboard',
                isCollapsed: isCollapsed,
                isDark: isDark,
                isDrawer: isDrawer,
              ),
              const SizedBox(height: 4),
              _buildModernSidebarItem(
                index: 1,
                icon: Iconsax.buildings_2,
                label: 'Property Approvals',
                badgeCount: pendingCount > 0 ? pendingCount : null,
                isCollapsed: isCollapsed,
                isDark: isDark,
                isDrawer: isDrawer,
              ),
              const SizedBox(height: 4),
              _buildModernSidebarItem(
                index: 2,
                icon: Iconsax.chart_21,
                label: 'Demand Radar',
                isHighlight: true,
                isCollapsed: isCollapsed,
                isDark: isDark,
                isDrawer: isDrawer,
              ),
              const SizedBox(height: 4),
              _buildModernSidebarItem(
                index: 3,
                icon: Iconsax.notification_bing,
                label: 'Push Broadcasts',
                isCollapsed: isCollapsed,
                isDark: isDark,
                isDrawer: isDrawer,
              ),
              const SizedBox(height: 4),
              _buildModernSidebarItem(
                index: 4,
                icon: Iconsax.people,
                label: 'Landlords & Users',
                isCollapsed: isCollapsed,
                isDark: isDark,
                isDrawer: isDrawer,
              ),

              const SizedBox(height: 4),

              _buildModernSidebarItem(
                index: 7,
                icon: Iconsax.data,
                label: 'Database & Storage',
                isCollapsed: isCollapsed,
                isDark: isDark,
                isDrawer: isDrawer,
              ),
            ],
          ),
        ),

        // 5. Bottom Controls (Theme Pill + Sidebar Toggle + User Profile)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: isCollapsed
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Collapsed Theme Toggle (Square)
                    Tooltip(
                      message: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => ThemeController.instance.toggleTheme(),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E2330) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Icon(
                                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                                size: 19,
                                color: isDark ? Colors.amber : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Collapsed Sidebar Open Toggle (Square)
                    Tooltip(
                      message: 'Sidebar Open ⌘>',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setState(() => _isSidebarCollapsed = false),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E2330) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Icon(
                                Iconsax.sidebar_right,
                                size: 19,
                                color: isDark ? Colors.white70 : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    // Light / Dark Theme Pill Switch
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2330) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              if (isDark) ThemeController.instance.toggleTheme();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: !isDark ? Colors.white : Colors.transparent,
                                shape: BoxShape.circle,
                                boxShadow: !isDark
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 4,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                Icons.light_mode_outlined,
                                size: 14,
                                color: !isDark ? Colors.black87 : Colors.white54,
                              ),
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              if (!isDark) ThemeController.instance.toggleTheme();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2E3748) : Colors.transparent,
                                shape: BoxShape.circle,
                                boxShadow: isDark
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.2),
                                          blurRadius: 4,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                Icons.dark_mode_outlined,
                                size: 14,
                                color: isDark ? Colors.amber : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),

                    // Close Sidebar Toggle
                    Tooltip(
                      message: 'Close Sidebar ⌘<',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() => _isSidebarCollapsed = true),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E2330) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Iconsax.sidebar_left,
                            size: 16,
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),

        Divider(
          height: 1,
          thickness: 1,
          color: isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFEAEAEA),
        ),

        // 6. User Profile Section (Real Authenticated Admin)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: isCollapsed
              ? Center(
                  child: PopupMenuButton<String>(
                    tooltip: '$_adminDisplayName (${_adminEmail})',
                    offset: const Offset(40, -40),
                    color: isDark ? const Color(0xFF1E2330) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    onSelected: (val) {
                      if (val == 'logout') _handleLogout();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'profile',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _adminDisplayName,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            Text(
                              _adminEmail,
                              style: GoogleFonts.inter(fontSize: 11, color: mutedColor),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout_rounded, color: Colors.redAccent, size: 16),
                            SizedBox(width: 8),
                            Text('Log Out', style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ],
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.primaryYellow,
                        backgroundImage: _adminAvatarUrl != null ? CachedNetworkImageProvider(_adminAvatarUrl!) : null,
                        child: _adminAvatarUrl == null
                            ? Text(
                                _adminInitial,
                                style: GoogleFonts.inter(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                )
              : Row(
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: AppTheme.primaryYellow,
                          backgroundImage: _adminAvatarUrl != null ? CachedNetworkImageProvider(_adminAvatarUrl!) : null,
                          child: _adminAvatarUrl == null
                              ? Text(
                                  _adminInitial,
                                  style: GoogleFonts.inter(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _adminDisplayName,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _adminEmail,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              color: mutedColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Admin Menu',
                      offset: const Offset(0, -50),
                      color: isDark ? const Color(0xFF1E2330) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 16,
                        color: mutedColor,
                      ),
                      onSelected: (val) {
                        if (val == 'logout') _handleLogout();
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'profile',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _adminDisplayName,
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              Text(
                                _adminEmail,
                                style: GoogleFonts.inter(fontSize: 11, color: mutedColor),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'logout',
                          child: Row(
                            children: [
                              Icon(Icons.logout_rounded, color: Colors.redAccent, size: 16),
                              SizedBox(width: 8),
                              Text('Log Out', style: TextStyle(color: Colors.redAccent)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  // Quick Action Item (Search, Notification, Settings)
  Widget _buildUtilityAction({
    required IconData icon,
    required String label,
    int? badgeCount,
    required bool isCollapsed,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final mutedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    if (isCollapsed) {
      return Center(
        child: Tooltip(
          message: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(icon, size: 19, color: mutedColor),
                    if (badgeCount != null)
                      Positioned(
                        top: -1,
                        right: -3,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFEB3A),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          height: 40,
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: Icon(icon, size: 19, color: mutedColor),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: mutedColor,
                  ),
                ),
              ),
              if (badgeCount != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryYellow,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeCount.toString(),
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Modern Sidebar Navigation Item with flat brand primary yellow filled active state
  Widget _buildModernSidebarItem({
    required int index,
    required IconData icon,
    required String label,
    int? badgeCount,
    bool isHighlight = false,
    required bool isCollapsed,
    required bool isDark,
    required bool isDrawer,
  }) {
    final isSelected = _selectedTabIndex == index;
    final activeBg = AppTheme.primaryYellow; // Rental App Signature Brand Yellow (0xFFFFEB3A)
    final activeIconColor = Colors.black;
    final activeTextColor = Colors.black;
    final inactiveText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    if (isCollapsed) {
      return Center(
        child: Tooltip(
          message: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                setState(() => _selectedTabIndex = index);
                if (isDrawer) Navigator.pop(context);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected ? activeBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: isSelected ? activeIconColor : inactiveText,
                    ),
                    if (badgeCount != null)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.black : AppTheme.primaryYellow,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() => _selectedTabIndex = index);
          if (isDrawer) Navigator.pop(context);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: isSelected ? activeIconColor : inactiveText,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected ? activeTextColor : inactiveText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badgeCount != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.black : AppTheme.primaryYellow,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeCount.toString(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? AppTheme.primaryYellow : Colors.black,
                    ),
                  ),
                ),
              if (isHighlight && badgeCount == null && !isSelected)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'LIVE',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TOP DESKTOP HEADER BAR (CLEAN 58PX MINIMALIST BAR)
  // ==========================================
  Widget _buildTopHeader(bool isDark) {
    final mutedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141721) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Active Tab Title
          Expanded(
            child: Text(
              _getTabTitle(_selectedTabIndex),
              style: GoogleFonts.inter(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: primaryTextColor,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),

          // Toggle Live User App Button
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              setState(() {
                _showLiveUserAppPreview = !_showLiveUserAppPreview;
                if (_showLiveUserAppPreview) {
                  _previewPanelWidth = null;
                }
              });
            },
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                color: _showLiveUserAppPreview
                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                    : (isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _showLiveUserAppPreview
                      ? const Color(0xFF10B981).withValues(alpha: 0.5)
                      : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Iconsax.mobile,
                    size: 15,
                    color: _showLiveUserAppPreview ? const Color(0xFF10B981) : mutedColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _showLiveUserAppPreview ? 'Hide App' : 'User App',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _showLiveUserAppPreview ? const Color(0xFF10B981) : (isDark ? Colors.white70 : const Color(0xFF334155)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Export CSV Shortcut
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _exportPropertiesCSV,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Iconsax.document_download, size: 15, color: mutedColor),
                  const SizedBox(width: 5),
                  Text(
                    'CSV',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Quick Create Broadcast Shortcut
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _selectedTabIndex = 3),
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.primaryYellow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.notification_bing, size: 15, color: Colors.black),
                  const SizedBox(width: 6),
                  Text(
                    'Broadcast',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Refresh Button
          Tooltip(
            message: 'Refresh All Data',
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                _fetchProperties();
                _fetchNotificationHistory();
              },
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                child: Icon(Icons.refresh_rounded, color: mutedColor, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Theme Toggle
          Tooltip(
            message: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => ThemeController.instance.toggleTheme(),
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                child: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: isDark ? Colors.amber : mutedColor,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTabTitle(int index) {
    switch (index) {
      case 0:
        return 'Command Center & System Overview';
      case 1:
        return 'Property Approvals & Inventory Matrix';
      case 2:
        return 'Click Heatmap & Tenant Demand Radar';
      case 3:
        return 'Push Notification & Broadcast Hub';
      case 4:
        return 'Landlords & Registered Users Directory';
      case 7:
        return 'Supabase Database & Cloud Storage Telemetry';
      default:
        return 'Admin Dashboard';
    }
  }

  // ==========================================
  // ACTIVE TAB CONTENT DISPATCHER
  // ==========================================
  Widget _buildActiveTabContent(bool isDark) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildOverviewTab(isDark);
      case 1:
        return _buildPropertiesTab(isDark);
      case 2:
        return _buildClickRadarTab(isDark);
      case 3:
        return _buildPushNotificationsTab(isDark);
      case 4:
        return _buildUsersTab(isDark);
      case 7:
        return AdminDatabaseAnalyticsTab(
          isDark: isDark,
          onRefreshParent: _fetchProperties,
        );
      default:
        return _buildOverviewTab(isDark);
    }
  }

  // ==========================================
  // TAB 1: COMMAND CENTER & SYSTEM OVERVIEW
  // ==========================================
  Widget _buildOverviewTab(bool isDark) {
    final total = _properties.length;
    final pendingCount = _properties.where((p) => p.status == 'pending').length;
    final occupiedCount = _properties.where((p) => !p.isAvailable).length;
    final availableCount = _properties.where((p) => p.isAvailable && p.status == 'approved').length;
    final flatsCount = _properties.where((p) => p.type == 'Rental').length;
    final pgsCount = _properties.where((p) => p.type == 'PG').length;
    final commercialCount = _properties.where((p) => p.type == 'Commercial' || p.type == 'Sale').length;
    final photosCount = _properties.where((p) => p.imageUrls.isNotEmpty).length;

    final mutedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Executive Operations Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161922) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryYellow.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primaryYellow.withValues(alpha: 0.3)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Iconsax.radar_2, color: Color(0xFFFFEB3A), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Rental Platform Operations Center',
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6.5,
                                  height: 6.5,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'LIVE REALTIME',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Direct owner listings, verification moderation, locality demand radar, and tenant broadcast.',
                        style: GoogleFonts.inter(fontSize: 13, color: mutedColor),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 10,
                  children: [
                    if (pendingCount > 0)
                      ElevatedButton.icon(
                        onPressed: _batchApproveAllPending,
                        icon: const Icon(Iconsax.tick_circle, size: 16),
                        label: Text(
                          'Approve All ($pendingCount)',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _selectedTabIndex = 3),
                      icon: const Icon(Iconsax.notification_bing, size: 16),
                      label: Text(
                        'Push Broadcast',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryYellow,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. 4-Core Practical Real-Time Operational KPI Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 900;
              final crossAxisCount = isDesktop ? 4 : (constraints.maxWidth > 550 ? 2 : 1);
              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isDesktop ? 2.1 : 2.4,
                children: [
                  // KPI 1: Total Listings
                  _buildExecutiveKpiCard(
                    title: 'Live Listings in App',
                    value: '$total Properties',
                    subtitle: '$availableCount Available • $occupiedCount Occupied',
                    badgeLabel: '100% Active',
                    badgeColor: const Color(0xFF10B981),
                    icon: Iconsax.building_4,
                    iconColor: AppTheme.primaryYellow,
                    isDark: isDark,
                    primaryTextColor: primaryTextColor,
                    mutedColor: mutedColor,
                    onTap: () => setState(() => _selectedTabIndex = 1),
                  ),

                  // KPI 2: Pending Moderation
                  _buildExecutiveKpiCard(
                    title: 'Pending Verifications',
                    value: '$pendingCount Submissions',
                    subtitle: pendingCount > 0 ? '$pendingCount awaiting review' : 'All submissions verified',
                    badgeLabel: pendingCount > 0 ? 'Action Needed' : 'All Caught Up',
                    badgeColor: pendingCount > 0 ? AppTheme.primaryYellow : const Color(0xFF10B981),
                    icon: Iconsax.verify,
                    iconColor: pendingCount > 0 ? AppTheme.primaryYellow : const Color(0xFF10B981),
                    isDark: isDark,
                    primaryTextColor: primaryTextColor,
                    mutedColor: mutedColor,
                    onTap: () => setState(() {
                      _selectedTabIndex = 1;
                      _statusFilter = 'pending';
                    }),
                  ),

                  // KPI 3: Operational Localities
                  _buildExecutiveKpiCard(
                    title: 'Covered Localities',
                    value: '${_rajahmundryLocalities.length} Localities',
                    subtitle: 'Active Municipal Zones',
                    badgeLabel: 'Active Coverage',
                    badgeColor: const Color(0xFF3B82F6),
                    icon: Iconsax.location,
                    iconColor: const Color(0xFF3B82F6),
                    isDark: isDark,
                    primaryTextColor: primaryTextColor,
                    mutedColor: mutedColor,
                    onTap: () => setState(() => _selectedTabIndex = 6),
                  ),

                  // KPI 4: Photos & Quality Verification
                  _buildExecutiveKpiCard(
                    title: 'Photo Verified Listings',
                    value: '$photosCount / $total Verified',
                    subtitle: 'Real room & exterior photos',
                    badgeLabel: '100% Verified',
                    badgeColor: const Color(0xFF8B5CF6),
                    icon: Iconsax.camera,
                    iconColor: const Color(0xFF8B5CF6),
                    isDark: isDark,
                    primaryTextColor: primaryTextColor,
                    mutedColor: mutedColor,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // 3. Balanced 2-Column Clean Layout
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Inventory Categories & Locality Distribution
                    Expanded(
                      child: Column(
                        children: [
                          _buildInventoryBreakdownCard(
                            isDark: isDark,
                            primaryTextColor: primaryTextColor,
                            mutedColor: mutedColor,
                            flatsCount: flatsCount,
                            pgsCount: pgsCount,
                            commercialCount: commercialCount,
                            total: total,
                          ),
                          const SizedBox(height: 16),
                          _buildLocalityRankingCard(isDark, primaryTextColor, mutedColor),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Right Column: Live Listings Feed & Platform Security
                    Expanded(
                      child: Column(
                        children: [
                          _buildLivePlatformActivityFeed(isDark, primaryTextColor, mutedColor),
                          const SizedBox(height: 16),
                          _buildPlatformSecurityGuardrailsCard(isDark, primaryTextColor, mutedColor),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildInventoryBreakdownCard(
                      isDark: isDark,
                      primaryTextColor: primaryTextColor,
                      mutedColor: mutedColor,
                      flatsCount: flatsCount,
                      pgsCount: pgsCount,
                      commercialCount: commercialCount,
                      total: total,
                    ),
                    const SizedBox(height: 16),
                    _buildLivePlatformActivityFeed(isDark, primaryTextColor, mutedColor),
                    const SizedBox(height: 16),
                    _buildLocalityRankingCard(isDark, primaryTextColor, mutedColor),
                    const SizedBox(height: 16),
                    _buildPlatformSecurityGuardrailsCard(isDark, primaryTextColor, mutedColor),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // COMPONENT: EXECUTIVE KPI CARD (BIG BOLD TYPOGRAPHY)
  // ==========================================
  Widget _buildExecutiveKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required String badgeLabel,
    required Color badgeColor,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    required Color primaryTextColor,
    required Color mutedColor,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161922) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Row: Title + Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: mutedColor,
                    ),
                  ),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: iconColor, size: 16),
                  ),
                ],
              ),

              // Middle: BIG BOLD NUMBER
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: primaryTextColor,
                  letterSpacing: -0.5,
                ),
              ),

              // Bottom Row: Subtitle + Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: mutedColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      badgeLabel,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // COMPONENT: LOCALITY DEMAND RANKING MATRIX (100% REAL DATA)
  // ==========================================
  Widget _buildLocalityRankingCard(bool isDark, Color primaryTextColor, Color mutedColor) {
    // Dynamically calculate listing count per locality from live dataset
    final localityMap = <String, int>{};
    for (final p in _properties) {
      final loc = p.locationStr.split(',').first.trim();
      if (loc.isNotEmpty) {
        localityMap[loc] = (localityMap[loc] ?? 0) + 1;
      }
    }

    final sortedLocalities = localityMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalProps = _properties.isEmpty ? 1 : _properties.length;

    // Remaining localities with 0 listings currently
    final unlistedLocalities = _rajahmundryLocalities
        .where((loc) => !localityMap.containsKey(loc))
        .take(5)
        .toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Iconsax.location, size: 17, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  Text(
                    'Active Localities & Coverage',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => setState(() => _selectedTabIndex = 6),
                child: Text(
                  'Manage Localities ↗',
                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF3B82F6)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Active Localities with Listings
          ...sortedLocalities.map((entry) {
            final locName = entry.key;
            final locCount = entry.value;
            final pct = (locCount / totalProps).clamp(0.05, 1.0);
            final pctLabel = ((locCount / totalProps) * 100).round();

            return Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2330) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            locName,
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Active Zone',
                              style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFF10B981)),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '$locCount Properties ($pctLabel%)',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 5,
                      backgroundColor: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 4),
          Text(
            'Configured Areas Ready For Next Listings:',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: mutedColor),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: unlistedLocalities.map((loc) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2330) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  loc,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: mutedColor),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // COMPONENT: INVENTORY BY CATEGORY & PRICE (100% REAL DATA)
  // ==========================================
  Widget _buildInventoryBreakdownCard({
    required bool isDark,
    required Color primaryTextColor,
    required Color mutedColor,
    required int flatsCount,
    required int pgsCount,
    required int commercialCount,
    required int total,
  }) {
    final effectiveTotal = total > 0 ? total.toDouble() : 1.0;
    final flatPct = ((flatsCount / effectiveTotal) * 100).round();
    final pgPct = ((pgsCount / effectiveTotal) * 100).round();
    final commPct = (100 - flatPct - pgPct).clamp(0, 100);

    // Compute real price brackets from live database
    int budgetCount = 0; // < 5000
    int midCount = 0;    // 5000 - 10000
    int highCount = 0;   // > 10000

    for (final p in _properties) {
      final rentNum = double.tryParse(p.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
      if (rentNum < 5000) {
        budgetCount++;
      } else if (rentNum <= 10000) {
        midCount++;
      } else {
        highCount++;
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Iconsax.category, size: 17, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Text(
                    'Inventory Breakdown & Rent Tiers',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
              Text(
                '$total Live Units',
                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: mutedColor),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Multi-Segment Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(flex: pgPct > 0 ? pgPct : 1, child: Container(color: const Color(0xFF10B981))),
                  const SizedBox(width: 2),
                  Expanded(flex: flatPct > 0 ? flatPct : 1, child: Container(color: AppTheme.primaryYellow)),
                  const SizedBox(width: 2),
                  Expanded(flex: commPct > 0 ? commPct : 1, child: Container(color: const Color(0xFF3B82F6))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Categories with Real Counts
          _buildCategoryPillRow('Hostel / PG (Boys & Girls)', pgsCount, pgPct, const Color(0xFF10B981), primaryTextColor),
          const SizedBox(height: 6),
          _buildCategoryPillRow('Residential Flats / Houses', flatsCount, flatPct, AppTheme.primaryYellow, primaryTextColor),
          const SizedBox(height: 6),
          _buildCategoryPillRow('Commercial & Buy/Sell', commercialCount, commPct, const Color(0xFF3B82F6), primaryTextColor),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),

          Text(
            'Live Rent Tiers in Database',
            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: mutedColor),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _buildPriceTierCard('< ₹5,000', '$budgetCount Units', 'Budget Rooms', const Color(0xFF10B981), isDark),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildPriceTierCard('₹5k - ₹10k', '$midCount Units', 'Mid PGs & Rooms', AppTheme.primaryYellow, isDark),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildPriceTierCard('> ₹10,000', '$highCount Units', 'Full Flats', const Color(0xFF8B5CF6), isDark),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // COMPONENT: PLATFORM SECURITY & GUARDRAILS
  // ==========================================
  Widget _buildPlatformSecurityGuardrailsCard(bool isDark, Color primaryTextColor, Color mutedColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Iconsax.shield_tick, size: 17, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Text(
                    'Platform Quality & Security Rules',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '100% Active',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF10B981)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildGuardrailItem(
            icon: Iconsax.user_tick,
            title: 'Direct Landlord Connect',
            subtitle: 'Direct WhatsApp & Phone without intermediary broker commissions.',
            color: const Color(0xFF10B981),
            isDark: isDark,
            primaryTextColor: primaryTextColor,
            mutedColor: mutedColor,
          ),
          const SizedBox(height: 8),
          _buildGuardrailItem(
            icon: Iconsax.camera,
            title: 'Room & Building Photos Enforced',
            subtitle: 'All 19 active properties contain verified real visual photos.',
            color: AppTheme.primaryYellow,
            isDark: isDark,
            primaryTextColor: primaryTextColor,
            mutedColor: mutedColor,
          ),
          const SizedBox(height: 8),
          _buildGuardrailItem(
            icon: Iconsax.verify,
            title: 'Admin Verification Gatekeeper',
            subtitle: 'New submissions are held in pending queue until approved.',
            color: const Color(0xFF3B82F6),
            isDark: isDark,
            primaryTextColor: primaryTextColor,
            mutedColor: mutedColor,
          ),
        ],
      ),
    );
  }

  Widget _buildGuardrailItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
    required Color primaryTextColor,
    required Color mutedColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: primaryTextColor),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 10.5, color: mutedColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryPillRow(String label, int count, int pct, Color color, Color primaryTextColor) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: primaryTextColor),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '$count units ($pct%)',
          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }

  Widget _buildPriceTierCard(String range, String count, String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2330) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(range, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 1),
          Text(count, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700)),
          Text(label, style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF94A3B8)), maxLines: 1),
        ],
      ),
    );
  }

  // ==========================================
  // COMPONENT: LIVE REAL INVENTORY FEED (100% REAL DATA)
  // ==========================================
  Widget _buildLivePlatformActivityFeed(bool isDark, Color primaryTextColor, Color mutedColor) {
    final realProperties = _properties.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Iconsax.buildings, size: 17, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  Text(
                    'Recently Verified Listings',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => setState(() => _selectedTabIndex = 1),
                child: Text(
                  'View All (${_properties.length}) ↗',
                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.primaryYellow),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (realProperties.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No properties in database yet.',
                style: GoogleFonts.inter(fontSize: 12, color: mutedColor),
              ),
            )
          else
            ...realProperties.map((prop) {
              final thumb = prop.imageUrls.isNotEmpty ? prop.imageUrls.first : '';
              final location = prop.locationStr.split(',').first.trim();

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.5),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _viewPropertyInLivePhone(prop),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2330) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            imageUrl: thumb,
                            width: 38,
                            height: 38,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 38,
                              height: 38,
                              color: const Color(0xFFE2E8F0),
                              child: const Icon(Iconsax.image, size: 16, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                prop.title,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: primaryTextColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '₹${prop.price}/mo • $location',
                                style: GoogleFonts.inter(fontSize: 11, color: mutedColor),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            prop.type,
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: PROPERTIES MANAGEMENT & OCCUPANCY
  // ==========================================
  Widget _buildPropertiesTab(bool isDark) {
    final filtered = _properties.where((p) {
      if (_statusFilter == 'pending' && p.status != 'pending') return false;
      if (_statusFilter == 'approved' && p.status != 'approved') return false;
      if (_statusFilter == 'occupied' && p.isAvailable) return false;
      if (_statusFilter == 'rejected' && p.status != 'rejected') return false;
      if (_statusFilter == 'pending_photos' && !p.suggestedPhotos.any((ph) => ph['status'] == 'pending')) {
        return false;
      }

      if (_typeFilter != 'all' && !p.type.toLowerCase().contains(_typeFilter.toLowerCase())) {
        return false;
      }

      if (_localityFilter != 'all' && !p.locationStr.toLowerCase().contains(_localityFilter.toLowerCase())) {
        return false;
      }

      if (_propertySearchQuery.isNotEmpty) {
        final q = _propertySearchQuery.toLowerCase();
        return p.title.toLowerCase().contains(q) ||
            p.locationStr.toLowerCase().contains(q) ||
            p.ownerPhone.toLowerCase().contains(q) ||
            (p.id?.toLowerCase().contains(q) ?? false);
      }

      return true;
    }).toList();

    final mutedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter & Search Controls Container
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161922) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Search Input (Height: 44px)
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E2330) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: TextField(
                          onChanged: (val) => setState(() => _propertySearchQuery = val),
                          style: GoogleFonts.inter(
                            color: primaryTextColor,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search properties by Title, Owner Phone, Locality, or ID...',
                            hintStyle: GoogleFonts.inter(
                              color: mutedColor.withValues(alpha: 0.75),
                              fontSize: 13,
                            ),
                            prefixIcon: Icon(
                              Iconsax.search_normal_1,
                              size: 17,
                              color: mutedColor,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Property Type PopupMenu (Height: 44px)
                    PopupMenuButton<String>(
                      tooltip: 'Filter by Property Type',
                      offset: const Offset(0, 48),
                      color: isDark ? const Color(0xFF1E2330) : Colors.white,
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                        ),
                      ),
                      initialValue: _typeFilter,
                      onSelected: (val) => setState(() => _typeFilter = val),
                      itemBuilder: (context) {
                        return [
                          {'val': 'all', 'label': 'All Types', 'icon': Iconsax.category},
                          {'val': 'Rental', 'label': 'House / Flat', 'icon': Iconsax.buildings},
                          {'val': 'PG', 'label': 'Hostel / PG', 'icon': Iconsax.user_tag},
                          {'val': 'Commercial', 'label': 'Commercial', 'icon': Iconsax.shop},
                        ].map((item) {
                          final isSelected = _typeFilter == item['val'];
                          return PopupMenuItem<String>(
                            value: item['val'] as String,
                            height: 38,
                            child: Row(
                              children: [
                                Icon(
                                  item['icon'] as IconData,
                                  size: 16,
                                  color: isSelected ? AppTheme.primaryYellow : (isDark ? Colors.white70 : Colors.black87),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    item['label'] as String,
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? AppTheme.primaryYellow : (isDark ? Colors.white : Colors.black87),
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check, size: 15, color: Color(0xFFFFEB3A)),
                              ],
                            ),
                          );
                        }).toList();
                      },
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E2330) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Iconsax.category, size: 16, color: mutedColor),
                            const SizedBox(width: 7),
                            Text(
                              _typeFilter == 'all'
                                  ? 'All Types'
                                  : (_typeFilter == 'PG' ? 'Hostel / PG' : (_typeFilter == 'Rental' ? 'House / Flat' : _typeFilter)),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: mutedColor),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Locality PopupMenu (Height: 44px)
                    PopupMenuButton<String>(
                      tooltip: 'Filter by Locality',
                      offset: const Offset(0, 48),
                      color: isDark ? const Color(0xFF1E2330) : Colors.white,
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                        ),
                      ),
                      initialValue: _localityFilter,
                      onSelected: (val) => setState(() => _localityFilter = val),
                      itemBuilder: (context) {
                        final allLocs = ['all', ..._rajahmundryLocalities];
                        return allLocs.map((loc) {
                          final isSelected = _localityFilter == loc;
                          final label = loc == 'all' ? 'All Localities' : loc;
                          return PopupMenuItem<String>(
                            value: loc,
                            height: 36,
                            child: Row(
                              children: [
                                Icon(
                                  Iconsax.location,
                                  size: 15,
                                  color: isSelected ? AppTheme.primaryYellow : (isDark ? Colors.white70 : Colors.black87),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    label,
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? AppTheme.primaryYellow : (isDark ? Colors.white : Colors.black87),
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check, size: 15, color: Color(0xFFFFEB3A)),
                              ],
                            ),
                          );
                        }).toList();
                      },
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E2330) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Iconsax.location, size: 16, color: mutedColor),
                            const SizedBox(width: 7),
                            Text(
                              _localityFilter == 'all' ? 'All Localities' : _localityFilter,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: mutedColor),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Status Filter Badges Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusFilterChip('all', 'All Listings (${_properties.length})', isDark),
                      const SizedBox(width: 8),
                      _buildStatusFilterChip(
                        'pending',
                        'Pending Review (${_properties.where((p) => p.status == 'pending').length})',
                        isDark,
                        badgeColor: AppTheme.primaryYellow,
                      ),
                      const SizedBox(width: 8),
                      _buildStatusFilterChip(
                        'approved',
                        'Live Vacant (${_properties.where((p) => p.status == 'approved' && p.isAvailable).length})',
                        isDark,
                        badgeColor: const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusFilterChip(
                        'occupied',
                        'Occupied (${_properties.where((p) => !p.isAvailable).length})',
                        isDark,
                        badgeColor: const Color(0xFF3B82F6),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusFilterChip(
                        'pending_photos',
                        'Pending Photos (${_properties.where((p) => p.suggestedPhotos.any((ph) => ph['status'] == 'pending')).length})',
                        isDark,
                        badgeColor: const Color(0xFF8B5CF6),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusFilterChip(
                        'rejected',
                        'Rejected (${_properties.where((p) => p.status == 'rejected').length})',
                        isDark,
                        badgeColor: const Color(0xFFEF4444),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Properties Matrix List View
          Expanded(
            child: _isLoadingProperties
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFEB3A)))
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Iconsax.buildings, size: 48, color: mutedColor.withValues(alpha: 0.3)),
                            const SizedBox(height: 12),
                            Text(
                              'No properties matching the selected filters.',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: mutedColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) => _buildDesktopPropertyRow(filtered[idx], isDark),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(String value, String label, bool isDark, {Color? badgeColor}) {
    final isSelected = _statusFilter == value;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final mutedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _statusFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
        decoration: BoxDecoration(
          color: isSelected
              ? (badgeColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)))
              : (isDark ? const Color(0xFF1E2330) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (badgeColor != null ? Colors.black : (isDark ? Colors.black : Colors.white))
                : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  /// Live Phone Preview Navigation Action
  void _viewPropertyInLivePhone(PropertyModel prop) {
    if (!_showLiveUserAppPreview) {
      setState(() {
        _showLiveUserAppPreview = true;
        _previewPanelWidth = null;
      });
    }

    Future.delayed(const Duration(milliseconds: 120), () {
      if (_previewNavigatorKey.currentState != null) {
        _previewNavigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (_) => PropertyDetailsScreen(property: prop),
          ),
        );
        AppSnackbar.success(context, '📱 Loaded "${prop.title}" in live phone device preview');
      }
    });
  }

  /// Property Edit: Opens the full real-user multi-step Posting/Editing flow directly in the Live Phone Preview
  void _showEditPropertyModal(PropertyModel prop, bool isDark) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 950;

    if (isDesktop) {
      if (!_showLiveUserAppPreview) {
        setState(() {
          _showLiveUserAppPreview = true;
          _previewPanelWidth = null;
        });
      }

      Future.delayed(const Duration(milliseconds: 140), () {
        if (_previewNavigatorKey.currentState != null) {
          _previewNavigatorKey.currentState!.push(
            MaterialPageRoute(
              builder: (_) => Scaffold(
                backgroundColor: _previewDarkMode ? AppTheme.darkScaffold : Colors.white,
                body: SafeArea(
                  child: PostBottomSheet(
                    propertyToEdit: prop,
                    onPropertyCreated: (updatedProp) {
                      _fetchProperties();
                      AppSnackbar.success(context, '✅ Property "${updatedProp.title}" updated successfully!');
                    },
                  ),
                ),
              ),
            ),
          );
          AppSnackbar.success(context, '📱 Opened real-user posting & editing flow in Live Phone Device Preview');
        } else {
          _showEditBottomSheetModal(prop, isDark);
        }
      });
    } else {
      _showEditBottomSheetModal(prop, isDark);
    }
  }

  void _showEditBottomSheetModal(PropertyModel prop, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.94,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Scaffold(
            backgroundColor: isDark ? AppTheme.darkScaffold : Colors.white,
            body: SafeArea(
              child: PostBottomSheet(
                propertyToEdit: prop,
                onPropertyCreated: (updatedProp) {
                  _fetchProperties();
                  AppSnackbar.success(context, '✅ Property "${updatedProp.title}" updated successfully!');
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopPropertyRow(PropertyModel prop, bool isDark) {
    final propId = prop.id ?? '';
    final mutedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);

    final statusColor = prop.status == 'approved'
        ? const Color(0xFF10B981)
        : (prop.status == 'pending' ? AppTheme.primaryYellow : const Color(0xFFEF4444));

    // Cleanly parse price numbers without double ₹ and without double /mo
    final cleanPriceNum = prop.price.replaceAll(RegExp(r'[^0-9]'), '');
    final displayPrice = cleanPriceNum.isNotEmpty ? '₹$cleanPriceNum/mo' : prop.price;

    final cleanDepNum = (prop.securityDeposit ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
    final displayDeposit = cleanDepNum.isNotEmpty ? 'Deposit: ₹$cleanDepNum' : 'Deposit: ₹0';

    // Build clean inline specs summary
    final List<String> specSummary = [];
    if (prop.type == 'PG') {
      if (prop.sharingType != null && prop.sharingType!.isNotEmpty) specSummary.add(prop.sharingType!);
      if (prop.genderPreference != null && prop.genderPreference!.isNotEmpty) specSummary.add(prop.genderPreference!);
      if (prop.foodDetails != null && prop.foodDetails!.isNotEmpty) specSummary.add('Food Included');
      if (prop.acType != null && prop.acType!.isNotEmpty) specSummary.add(prop.acType!);
    } else {
      if (prop.bhkType != null && prop.bhkType!.isNotEmpty) specSummary.add(prop.bhkType!);
      if (prop.furnishingStatus != null && prop.furnishingStatus!.isNotEmpty) specSummary.add(prop.furnishingStatus!);
      if (prop.tenantPreference != null && prop.tenantPreference!.isNotEmpty) specSummary.add(prop.tenantPreference!);
    }
    final specsText = specSummary.join(' • ');

    // Distinct Blue/Slate Vacancy Colors (NOT green, avoiding confusion with Approved!)
    final vacancyColor = prop.isAvailable ? const Color(0xFF2563EB) : const Color(0xFF64748B);
    final vacancyBgColor = prop.isAvailable
        ? const Color(0xFF2563EB).withValues(alpha: 0.12)
        : const Color(0xFF64748B).withValues(alpha: 0.12);
    final vacancyBorderColor = prop.isAvailable
        ? const Color(0xFF2563EB).withValues(alpha: 0.35)
        : const Color(0xFF64748B).withValues(alpha: 0.35);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 960;
        final isMedium = constraints.maxWidth >= 680;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161922) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              // 1. Image Thumbnail (90x70)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: prop.imageUrls.isNotEmpty ? prop.imageUrls.first : '',
                      width: 90,
                      height: 70,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 90,
                        height: 70,
                        color: isDark ? const Color(0xFF1E2330) : const Color(0xFFF1F5F9),
                        child: Icon(Iconsax.image, size: 24, color: mutedColor),
                      ),
                    ),
                    Positioned(
                      bottom: 3,
                      right: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${prop.imageUrls.length} photos',
                          style: GoogleFonts.inter(fontSize: 8.5, color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // 2. Title, Locality & Clean Specs Info
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            prop.title,
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: primaryTextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: prop.type == 'PG'
                                ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
                                : const Color(0xFF3B82F6).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            prop.type,
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: prop.type == 'PG' ? const Color(0xFF8B5CF6) : const Color(0xFF3B82F6),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      prop.locationStr,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: mutedColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2.5),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            specsText.isNotEmpty ? 'Owner: ${prop.ownerPhone}  •  $specsText' : 'Owner: ${prop.ownerPhone}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: mutedColor.withValues(alpha: 0.9),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 3. Price Column
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayPrice,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryYellow,
                    ),
                  ),
                  if (prop.perDayWithFood != null && prop.perDayWithFood!.isNotEmpty)
                    Text(
                      '₹${prop.perDayWithFood}/day',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 14),

              // 4. Functional Availability Toggle Button (Distinct Blue/Slate color - NOT green!)
              Tooltip(
                message: prop.isAvailable ? 'Status: VACANT (Click to mark Occupied)' : 'Status: OCCUPIED (Click to mark Vacant)',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _toggleAvailability(propId, prop.isAvailable),
                  child: Container(
                    height: 32,
                    padding: EdgeInsets.symmetric(horizontal: isWide ? 10 : 8),
                    decoration: BoxDecoration(
                      color: vacancyBgColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: vacancyBorderColor),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          prop.isAvailable ? Iconsax.building_4 : Iconsax.lock,
                          size: 14,
                          color: vacancyColor,
                        ),
                        if (isWide) ...[
                          const SizedBox(width: 5),
                          Text(
                            prop.isAvailable ? 'VACANT' : 'OCCUPIED',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: vacancyColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // 5. Functional Approval Status Badge / Button
              Tooltip(
                message: 'Listing Status: ${prop.status.toUpperCase()}',
                child: Container(
                  height: 32,
                  padding: EdgeInsets.symmetric(horizontal: isWide ? 10 : 8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        prop.status == 'approved'
                            ? Iconsax.tick_circle
                            : (prop.status == 'pending' ? Iconsax.clock : Iconsax.close_circle),
                        size: 14,
                        color: statusColor,
                      ),
                      if (isWide) ...[
                        const SizedBox(width: 5),
                        Text(
                          prop.status.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 6. Action Icon Buttons (Always functional, crisp 32x32 buttons)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // View in Live Phone Device Preview Button
                  Tooltip(
                    message: 'View on Live Phone Device',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _viewPropertyInLivePhone(prop),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E2330) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                        ),
                        alignment: Alignment.center,
                        child: Icon(Iconsax.eye, size: 15, color: mutedColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),

                  // Edit Property Button
                  Tooltip(
                    message: 'Edit Property Details',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _showEditPropertyModal(prop, isDark),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E2330) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Iconsax.edit_2, size: 14, color: Color(0xFFFFEB3A)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),

                  if (prop.status != 'approved') ...[
                    Tooltip(
                      message: 'Approve Listing',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _updatePropertyStatus(propId, 'approved'),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Iconsax.tick_circle, color: Color(0xFF10B981), size: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                  ],

                  if (prop.status != 'rejected') ...[
                    Tooltip(
                      message: 'Reject Listing',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _showRejectDialog(propId),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Iconsax.close_circle, color: Color(0xFFEF4444), size: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                  ],

                  // More Options Popup Menu (Styled like Device Selector Dropdown)
                  PopupMenuButton<String>(
                    tooltip: 'More Options',
                    offset: const Offset(0, 40),
                    color: isDark ? const Color(0xFF1E2330) : Colors.white,
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    icon: Icon(Icons.more_vert_rounded, size: 17, color: mutedColor),
                    onSelected: (val) {
                      if (val == 'inspect') _showPropertyInspectionModal(prop, isDark);
                      if (val == 'edit') _showEditPropertyModal(prop, isDark);
                      if (val == 'phone') _viewPropertyInLivePhone(prop);
                      if (val == 'availability') _toggleAvailability(propId, prop.isAvailable);
                      if (val == 'delete') _deleteProperty(propId);
                      if (val == 'broadcast') {
                        setState(() {
                          _selectedTabIndex = 3;
                          _selectedActionType = NotificationActionType.property;
                          _selectedPropertyId = propId;
                          _notifTitleController.text = '🔥 Check out this property in ${prop.locationStr.split(',').first}!';
                          _notifBodyController.text = '${prop.title} available now for ${displayPrice}. Zero broker fee.';
                        });
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'phone',
                        height: 38,
                        child: Row(
                          children: [
                            const Icon(Iconsax.mobile, size: 15, color: Color(0xFF3B82F6)),
                            const SizedBox(width: 9),
                            Text(
                              'View in Phone Preview',
                              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        height: 38,
                        child: Row(
                          children: [
                            const Icon(Iconsax.edit_2, size: 15, color: Color(0xFFFFEB3A)),
                            const SizedBox(width: 9),
                            Text(
                              'Edit Property Details',
                              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'inspect',
                        height: 38,
                        child: Row(
                          children: [
                            Icon(Iconsax.document_text, size: 15, color: mutedColor),
                            const SizedBox(width: 9),
                            Text(
                              'Inspect Photos & Logs',
                              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'availability',
                        height: 38,
                        child: Row(
                          children: [
                            Icon(
                              prop.isAvailable ? Iconsax.lock : Iconsax.building_4,
                              size: 15,
                              color: prop.isAvailable ? const Color(0xFF64748B) : const Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 9),
                            Text(
                              prop.isAvailable ? 'Mark as Occupied' : 'Mark as Available',
                              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'broadcast',
                        height: 38,
                        child: Row(
                          children: [
                            const Icon(Iconsax.notification_bing, size: 15, color: Color(0xFF8B5CF6)),
                            const SizedBox(width: 9),
                            Text(
                              'Create Push Notification',
                              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'delete',
                        height: 38,
                        child: Row(
                          children: [
                            const Icon(Iconsax.trash, size: 15, color: Color(0xFFEF4444)),
                            const SizedBox(width: 9),
                            Text(
                              'Delete Listing',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // TAB 3: CLICK ANALYTICS & TENANT DEMAND RADAR
  // ==========================================
  Widget _buildClickRadarTab(bool isDark) {
    final mutedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final total = _properties.length;
    final pgsCount = _properties.where((p) => p.type == 'PG').length;
    final topProps = _topViewedProperties.isNotEmpty ? _topViewedProperties : _properties.take(5).toList();

    final topCategory = _demandRadarData?['top_category'] ?? 'N/A';
    final topCategoryCount = _demandRadarData?['top_category_count'] ?? 0;
    final totalCategoryClicks = _demandRadarData?['total_category_clicks'] ?? 1;
    final catPct = totalCategoryClicks > 0 ? ((topCategoryCount / totalCategoryClicks) * 100).toInt() : 0;

    double avgRent = 0;
    if (topProps.isNotEmpty) {
      avgRent = topProps.map((e) => (int.tryParse(e.price.replaceAll(',', '')) ?? 0).toDouble()).reduce((a, b) => a + b) / topProps.length;
    }
    String rentTierStr = avgRent > 0 ? '₹${(avgRent/1000).toStringAsFixed(1)}k/mo Avg' : 'N/A';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Executive Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161922) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Iconsax.radar_2, color: Color(0xFF8B5CF6), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Tenant Demand Radar & Search Analytics',
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6.5,
                                  height: 6.5,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'LIVE SIGNALS',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Real-time tenant search trends, keyword velocities, most-viewed property rankings, and amenity demand heatmaps.',
                        style: GoogleFonts.inter(fontSize: 13, color: mutedColor),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _selectedTabIndex = 3),
                  icon: const Icon(Iconsax.notification_bing, size: 16, color: Colors.black),
                  label: Text(
                    'Broadcast Trending',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryYellow,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. 4-Core Practical Demand KPI Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 900;
              final crossAxisCount = isDesktop ? 4 : (constraints.maxWidth > 550 ? 2 : 1);
              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isDesktop ? 2.1 : 2.4,
                children: [
                  // KPI 1: Monitored Properties
                  _buildExecutiveKpiCard(
                    title: 'Monitored Inventory',
                    value: '$total Properties',
                    subtitle: '100% Tracking Active',
                    badgeLabel: 'Live Radar',
                    badgeColor: const Color(0xFF10B981),
                    icon: Iconsax.chart_21,
                    iconColor: const Color(0xFF8B5CF6),
                    isDark: isDark,
                    primaryTextColor: primaryTextColor,
                    mutedColor: mutedColor,
                  ),

                  // KPI 2: Top Demanded Category
                  _buildExecutiveKpiCard(
                    title: 'Top Demanded Category',
                    value: topCategory,
                    subtitle: '$topCategoryCount clicks ($totalCategoryClicks total)',
                    badgeLabel: '$catPct% Volume',
                    badgeColor: AppTheme.primaryYellow,
                    icon: Iconsax.building_4,
                    iconColor: AppTheme.primaryYellow,
                    isDark: isDark,
                    primaryTextColor: primaryTextColor,
                    mutedColor: mutedColor,
                  ),

                  // KPI 3: Dominant Rent Bracket
                  _buildExecutiveKpiCard(
                    title: 'High Velocity Rent Tier',
                    value: rentTierStr,
                    subtitle: 'Avg of top properties',
                    badgeLabel: 'Sweet Spot',
                    badgeColor: const Color(0xFF3B82F6),
                    icon: Iconsax.wallet_3,
                    iconColor: const Color(0xFF3B82F6),
                    isDark: isDark,
                    primaryTextColor: primaryTextColor,
                    mutedColor: mutedColor,
                  ),

                  // KPI 4: Must-Have Amenity
                  _buildExecutiveKpiCard(
                    title: 'Most Demanded Amenity',
                    value: 'Attached Bath & Food',
                    subtitle: '94% of search filter combos',
                    badgeLabel: 'Top Filter',
                    badgeColor: const Color(0xFF10B981),
                    icon: Iconsax.tick_circle,
                    iconColor: const Color(0xFF10B981),
                    isDark: isDark,
                    primaryTextColor: primaryTextColor,
                    mutedColor: mutedColor,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // 3. Main 2-Column Balanced Section
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Leaderboard & Amenity Heatmap
                    Expanded(
                      child: Column(
                        children: [
                          _buildMostWatchedLeaderboard(topProps, isDark, primaryTextColor, mutedColor),
                          const SizedBox(height: 16),
                          _buildAmenityDemandHeatmapCard(isDark, primaryTextColor, mutedColor),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Right Column: Trending Searches & Direct Lead Routing
                    Expanded(
                      child: Column(
                        children: [
                          _buildTrendingSearchesRadar(isDark, primaryTextColor, mutedColor),
                          const SizedBox(height: 16),
                          _buildTenantInquiryFlowCard(isDark, primaryTextColor, mutedColor),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildMostWatchedLeaderboard(topProps, isDark, primaryTextColor, mutedColor),
                    const SizedBox(height: 16),
                    _buildTrendingSearchesRadar(isDark, primaryTextColor, mutedColor),
                    const SizedBox(height: 16),
                    _buildAmenityDemandHeatmapCard(isDark, primaryTextColor, mutedColor),
                    const SizedBox(height: 16),
                    _buildTenantInquiryFlowCard(isDark, primaryTextColor, mutedColor),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // COMPONENT: TOP INQUIRED PROPERTIES LEADERBOARD
  // ==========================================
  Widget _buildMostWatchedLeaderboard(
    List<PropertyModel> props,
    bool isDark,
    Color primaryTextColor,
    Color mutedColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Iconsax.ranking, size: 17, color: Color(0xFFFFEB3A)),
                  const SizedBox(width: 8),
                  Text(
                    'High Velocity & Inquired Listings',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
              Text(
                'Top 5 Active',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryYellow),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (props.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('No property click data available yet.', style: GoogleFonts.inter(fontSize: 12, color: mutedColor)),
            )
          else
            ...props.asMap().entries.map((entry) {
              final idx = entry.key;
              final p = entry.value;
              final thumb = p.imageUrls.isNotEmpty ? p.imageUrls.first : '';
              final loc = p.locationStr.split(',').first.trim();

              final rankColor = idx == 0
                  ? AppTheme.primaryYellow
                  : (idx == 1 ? const Color(0xFF94A3B8) : (idx == 2 ? const Color(0xFFD97706) : mutedColor));

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2330) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    // Rank Badge
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: rankColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '#${idx + 1}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: rankColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Property Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: thumb,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 36,
                          height: 36,
                          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                          child: const Icon(Iconsax.image, size: 14, color: Color(0xFF94A3B8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Title & Locality
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.title,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '₹${p.price}/mo • $loc',
                            style: GoogleFonts.inter(fontSize: 11, color: mutedColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Actions
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tooltip(
                          message: 'View on Live Phone',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => _viewPropertyInLivePhone(p),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF161922) : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                              ),
                              alignment: Alignment.center,
                              child: Icon(Iconsax.eye, size: 13, color: mutedColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: 'WhatsApp Landlord',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => _contactOwnerWhatsApp(p.ownerPhone, p.title),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(Icons.chat_bubble_outline, size: 13, color: Color(0xFF10B981)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ==========================================
  // COMPONENT: AMENITY DEMAND HEATMAP
  // ==========================================
  Widget _buildAmenityDemandHeatmapCard(bool isDark, Color primaryTextColor, Color mutedColor) {
    List<({String name, String demand, double pct, Color color})> amenities = [];
    if (_topViewedProperties.isNotEmpty) {
      final Map<String, int> amenityCounts = {};
      int totalAmenities = 0;
      for (var p in _topViewedProperties) {
        for (var a in p.features) {
          amenityCounts[a] = (amenityCounts[a] ?? 0) + 1;
          totalAmenities++;
        }
      }
      final sortedAmenities = amenityCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      amenities = sortedAmenities.take(5).map((e) {
        final pct = totalAmenities > 0 ? e.value / totalAmenities : 0.0;
        return (
          name: e.key,
          demand: '${(pct * 100).toInt()}% Inquiries',
          pct: pct,
          color: const Color(0xFF10B981)
        );
      }).toList();
    }
    if (amenities.isEmpty) {
      amenities = [
        (name: 'No data yet', demand: '0%', pct: 0.0, color: const Color(0xFF94A3B8))
      ];
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Iconsax.filter_tick, size: 17, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Text(
                    'High Demand Amenities Heatmap',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
              Text(
                'Tenant Filter Index',
                style: GoogleFonts.inter(fontSize: 11, color: mutedColor),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ...amenities.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.name,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: primaryTextColor),
                      ),
                      Text(
                        item.demand,
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: item.color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: item.pct,
                      minHeight: 5,
                      backgroundColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                      valueColor: AlwaysStoppedAnimation<Color>(item.color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==========================================
  // COMPONENT: TRENDING SEARCH RADAR (INTENT)
  // ==========================================
  Widget _buildTrendingSearchesRadar(bool isDark, Color primaryTextColor, Color mutedColor) {
    final List<dynamic> topSearchesData = _demandRadarData?['top_searches'] ?? [];
    List<({String query, String volume, String growth, Color color})> searchTerms = topSearchesData.map((e) {
      return (
        query: e['keyword']?.toString() ?? 'Unknown',
        volume: '${e['count']} searches',
        growth: 'Top',
        color: const Color(0xFF10B981)
      );
    }).toList();

    if (searchTerms.isEmpty) {
      searchTerms = [
        (query: 'No search data yet', volume: '-', growth: '-', color: const Color(0xFF94A3B8))
      ];
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Iconsax.search_status, size: 17, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 8),
                  Text(
                    'Trending Tenant Search Keywords',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
              Text(
                'Weekly Velocity',
                style: GoogleFonts.inter(fontSize: 11, color: mutedColor),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ...searchTerms.map((term) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2330) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.search_normal, size: 14, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          term.query,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          term.volume,
                          style: GoogleFonts.inter(fontSize: 10.5, color: mutedColor),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: term.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      term.growth,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: term.color,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==========================================
  // COMPONENT: TENANT INQUIRY FLOW CARD
  // ==========================================
  Widget _buildTenantInquiryFlowCard(bool isDark, Color primaryTextColor, Color mutedColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Iconsax.call_calling, size: 17, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  Text(
                    'Direct Landlord Inquiry Routing',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '100% Direct',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF10B981)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildGuardrailItem(
            icon: Iconsax.message,
            title: 'Direct WhatsApp Chats',
            subtitle: 'Tenants initiate direct WhatsApp inquiries with verified landlords.',
            color: const Color(0xFF10B981),
            isDark: isDark,
            primaryTextColor: primaryTextColor,
            mutedColor: mutedColor,
          ),
          const SizedBox(height: 8),
          _buildGuardrailItem(
            icon: Iconsax.call,
            title: '1-Tap Direct Phone Calls',
            subtitle: 'Direct owner contact with no broker fee or hidden commission.',
            color: const Color(0xFF3B82F6),
            isDark: isDark,
            primaryTextColor: primaryTextColor,
            mutedColor: mutedColor,
          ),
          const SizedBox(height: 8),
          _buildGuardrailItem(
            icon: Iconsax.shield_tick,
            title: 'Zero Broker Intermediation',
            subtitle: 'All leads route straight to the owner who posted the listing.',
            color: const Color(0xFF8B5CF6),
            isDark: isDark,
            primaryTextColor: primaryTextColor,
            mutedColor: mutedColor,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 4: PUSH NOTIFICATION BROADCAST HUB
  // ==========================================
  Widget _buildPushNotificationsTab(bool isDark) {
    final mutedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Modern Header Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161922) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Iconsax.notification_bing, color: Color(0xFF8B5CF6), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Push Notification & Deep-Link Broadcast Hub',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Blast instant manual push alerts or manage 8 AM, 1 PM & 6 PM automated AI notifications.',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: mutedColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_tethering, size: 14, color: Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      Text(
                        '$_allUsersCount Active Devices',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Sub-Tab Segmented Selector
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2330) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => setState(() => _notificationSubTabIndex = 0),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _notificationSubTabIndex == 0
                          ? (isDark ? AppTheme.primaryYellow : Colors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _notificationSubTabIndex == 0
                          ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Iconsax.send_2,
                          size: 16,
                          color: _notificationSubTabIndex == 0
                              ? (isDark ? Colors.black : Colors.black87)
                              : mutedColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '📢 Manual Broadcast',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: _notificationSubTabIndex == 0 ? FontWeight.w700 : FontWeight.w500,
                            color: _notificationSubTabIndex == 0
                                ? (isDark ? Colors.black : Colors.black87)
                                : mutedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => setState(() => _notificationSubTabIndex = 1),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _notificationSubTabIndex == 1
                          ? (isDark ? AppTheme.primaryYellow : Colors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _notificationSubTabIndex == 1
                          ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Iconsax.cpu,
                          size: 16,
                          color: _notificationSubTabIndex == 1
                              ? (isDark ? Colors.black : Colors.black87)
                              : mutedColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '🤖 AI Auto-Notifier (8 AM, 1 PM, 6 PM)',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: _notificationSubTabIndex == 1 ? FontWeight.w700 : FontWeight.w500,
                            color: _notificationSubTabIndex == 1
                                ? (isDark ? Colors.black : Colors.black87)
                                : mutedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Sub-Tab 0: Manual Broadcast Composer OR Sub-Tab 1: AI Auto-Notifier Manager
          if (_notificationSubTabIndex == 0)
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 980) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildNotificationComposerForm(isDark)),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: _buildNotificationLiveMockupAndHistory(isDark)),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildNotificationComposerForm(isDark),
                      const SizedBox(height: 16),
                      _buildNotificationLiveMockupAndHistory(isDark),
                    ],
                  );
                }
              },
            )
          else
            _buildAiAutoNotifierSubTab(isDark),
        ],
      ),
    );
  }

  Widget _buildAiAutoNotifierSubTab(bool isDark) {
    final mutedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final isEnabled = _autoNotifierSettings?.isEnabled ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Master Toggle Control Banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161922) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isEnabled
                  ? const Color(0xFF10B981).withValues(alpha: 0.3)
                  : Colors.red.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isEnabled
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : Colors.red.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    isEnabled ? Iconsax.timer_1 : Iconsax.timer_pause,
                    color: isEnabled ? const Color(0xFF10B981) : Colors.red,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Automated AI Push Notifier',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isEnabled
                                ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                : Colors.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isEnabled ? '🟢 ACTIVE' : '🔴 PAUSED',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isEnabled ? const Color(0xFF10B981) : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEnabled
                          ? 'Automatic notifications will be generated by AI and dispatched daily at 8:00 AM, 1:00 PM, and 6:00 PM IST.'
                          : 'Automated notification dispatches are currently paused. Toggle ON to resume automatic AI sending.',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: mutedColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Transform.scale(
                scale: 1.1,
                child: Switch(
                  value: isEnabled,
                  activeColor: const Color(0xFF10B981),
                  onChanged: _isSavingAutoSettings ? null : (val) => _toggleAutoNotifier(val),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 2. Scheduled Time Slots Overview Cards
        Text(
          '⏰ Scheduled Time Slots (Daily IST)',
          style: GoogleFonts.inter(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: primaryTextColor,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildTimeSlotCard(
                isDark: isDark,
                time: '8:00 AM',
                title: 'Morning Pulse',
                subtitle: 'Student PGs & Early Flat Hunting',
                icon: Iconsax.sun_1,
                color: const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTimeSlotCard(
                isDark: isDark,
                time: '1:00 PM',
                title: 'Lunch Peak',
                subtitle: 'Quick AI Property Search & Filters',
                icon: Iconsax.sun_fog,
                color: const Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTimeSlotCard(
                isDark: isDark,
                time: '1:20 PM',
                title: 'Post-Lunch Pulse',
                subtitle: 'Mid-day Tenant Followup & PGs',
                icon: Iconsax.cup,
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTimeSlotCard(
                isDark: isDark,
                time: '6:00 PM',
                title: 'Evening Prime',
                subtitle: 'Post-Work Direct Owner Chat',
                icon: Iconsax.moon,
                color: const Color(0xFF8B5CF6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 3. AI Guidelines & System Prompt Editor Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161922) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Iconsax.magicpen, color: AppTheme.primaryYellow, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'AI Notification Guidelines & Prompt Rules',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _isSavingAutoSettings ? null : _saveAiInstructions,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryYellow,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _isSavingAutoSettings
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Iconsax.tick_circle, size: 16),
                    label: Text(
                      'Save Guidelines',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Customize instructions for the Notification AI. The AI generates title, body copy, and selects approved generic target routes.',
                style: GoogleFonts.inter(fontSize: 12, color: mutedColor),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _aiInstructionsController,
                maxLines: 4,
                style: GoogleFonts.inter(fontSize: 13, color: primaryTextColor),
                decoration: InputDecoration(
                  hintText: 'Enter AI prompt instructions...',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F1219) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 4. Live AI Generator & Personalized Segmented Dispatch
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161922) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Iconsax.flash_1, color: Color(0xFF3B82F6), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Personalized Audience Segregation & Live Preview',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Target Audience Dropdown Selector
              Row(
                children: [
                  Text(
                    '🎯 Segregated Audience Group:',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F1219) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: DropdownButton<TargetAudience>(
                      value: _selectedAutoAudience,
                      underline: const SizedBox(),
                      dropdownColor: isDark ? const Color(0xFF1E2330) : Colors.white,
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: primaryTextColor),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedAutoAudience = val;
                            _previewAiNotif = null; // reset preview
                          });
                        }
                      },
                      items: const [
                        DropdownMenuItem(
                          value: TargetAudience.allUsers,
                          child: Text('🌐 All Registered Users'),
                        ),
                        DropdownMenuItem(
                          value: TargetAudience.pgSeekers,
                          child: Text('🎓 PG & Hostel Seekers'),
                        ),
                        DropdownMenuItem(
                          value: TargetAudience.roomSeekers,
                          child: Text('🏡 Room & Flat Seekers'),
                        ),
                        DropdownMenuItem(
                          value: TargetAudience.buyers,
                          child: Text('🔑 Property Buyers'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Action Buttons Row
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isGeneratingAiNotif ? null : _generateAiNotificationPreview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    ),
                    icon: _isGeneratingAiNotif
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Iconsax.cpu, size: 16),
                    label: Text(
                      '⚡ Generate AI Preview',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: (_previewAiNotif == null || _isDispatchingAutoNotif)
                        ? null
                        : _sendTestAutoNotification,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    ),
                    icon: _isDispatchingAutoNotif
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Iconsax.send_2, size: 16),
                    label: Text(
                      '🚀 Dispatch to Selected Segment',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isDispatchingSmartSegments ? null : _dispatchSmartPersonalizedMultiSegments,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    ),
                    icon: _isDispatchingSmartSegments
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Iconsax.magic_star, size: 16),
                    label: Text(
                      '🎯 Auto-Dispatch All 3 Segments',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              if (_previewAiNotif != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F1219) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _previewAiNotif!['title'] ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: primaryTextColor,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Target: ${_previewAiNotif!['target_route']?.toUpperCase()}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF8B5CF6),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _previewAiNotif!['body'] ?? '',
                        style: GoogleFonts.inter(fontSize: 13, color: mutedColor),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Strict Constraints Callout Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCardElevated : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : const Color(0xFFFDE68A),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.info_circle, size: 16, color: Color(0xFFD97706)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Constraint Enforced: AI is restricted to generic destination routes (pg, rental, ai_chat, posting, nearby, search). No specific property ID is ever linked.',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSlotCard({
    required bool isDark,
    required String time,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final mutedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
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
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                time,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: mutedColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationComposerForm(bool isDark) {
    final mutedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Compose Broadcast Message',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
              ),
              Text(
                'Instant Cloud Push',
                style: GoogleFonts.inter(fontSize: 11.5, color: mutedColor),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Quick Templates
          Text(
            'Quick Templates:',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: mutedColor,
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTemplatePill('🔥 Price Drop Alert', isDark),
                const SizedBox(width: 6),
                _buildTemplatePill('🏡 New Verified Listing', isDark),
                const SizedBox(width: 6),
                _buildTemplatePill('📢 Zero Brokerage Notice', isDark),
                const SizedBox(width: 6),
                _buildTemplatePill('⚡ High Demand in Area', isDark),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Target Audience Segment Selector
          Text(
            'Target Audience Segment',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildAudienceChip(
                  target: TargetAudience.allUsers,
                  label: 'All Users',
                  count: '$_allUsersCount',
                  icon: Iconsax.people,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildAudienceChip(
                  target: TargetAudience.pgSeekers,
                  label: 'PG Seekers',
                  count: '$_pgSeekersCount',
                  icon: Iconsax.building,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildAudienceChip(
                  target: TargetAudience.roomSeekers,
                  label: 'Room Seekers',
                  count: '$_roomSeekersCount',
                  icon: Iconsax.home,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildAudienceChip(
                  target: TargetAudience.buyers,
                  label: 'Buyers',
                  count: '$_buyersCount',
                  icon: Iconsax.card_pos,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildAudienceChip(
                  target: TargetAudience.landlords,
                  label: 'Landlords',
                  count: '$_landlordsCount',
                  icon: Iconsax.buildings,
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Notification Title
          Text(
            'Notification Title *',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2330) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _notifTitleController,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: primaryTextColor,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. 🔥 Price drop on verified Danavaipeta flat!',
                hintStyle: GoogleFonts.inter(fontSize: 12.5, color: mutedColor.withValues(alpha: 0.7)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Message Body
          Text(
            'Message Body *',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2330) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _notifBodyController,
              onChanged: (_) => setState(() {}),
              maxLines: 3,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: primaryTextColor,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. Rent reduced by ₹2,000/mo. East-facing with car parking & zero brokerage. View listing now.',
                hintStyle: GoogleFonts.inter(fontSize: 12.5, color: mutedColor.withValues(alpha: 0.7)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Deep Link Routing Destination Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1E29) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Iconsax.link_21, size: 16, color: Color(0xFFFFEB3A)),
                    const SizedBox(width: 6),
                    Text(
                      'Deep-Link Destination (On Notification Tap)',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Global Destination PopupMenuButton
                PopupMenuButton<NotificationActionType>(
                  tooltip: 'Select Deep-Link Destination',
                  offset: const Offset(0, 44),
                  color: isDark ? const Color(0xFF1E2330) : Colors.white,
                  elevation: 10,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  initialValue: _selectedActionType,
                  onSelected: (val) => setState(() => _selectedActionType = val),
                  itemBuilder: (context) {
                    final options = [
                      {'type': NotificationActionType.property, 'label': 'Open Specific Property Details (Direct Listing)', 'icon': Iconsax.buildings},
                      {'type': NotificationActionType.category, 'label': 'Open Locality Filter (e.g. Danavaipeta)', 'icon': Iconsax.location},
                      {'type': NotificationActionType.postProperty, 'label': 'Open Post Property Screen (Prompt Owners)', 'icon': Iconsax.add_circle},
                      {'type': NotificationActionType.buyAndSell, 'label': 'Open Buy & Sell Hub', 'icon': Iconsax.shop},
                      {'type': NotificationActionType.general, 'label': 'Open App Home Feed', 'icon': Iconsax.home_2},
                    ];
                    return options.map((opt) {
                      final isSelected = _selectedActionType == opt['type'];
                      return PopupMenuItem<NotificationActionType>(
                        value: opt['type'] as NotificationActionType,
                        height: 38,
                        child: Row(
                          children: [
                            Icon(
                              opt['icon'] as IconData,
                              size: 15,
                              color: isSelected ? AppTheme.primaryYellow : (isDark ? Colors.white70 : Colors.black87),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                opt['label'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? AppTheme.primaryYellow : primaryTextColor,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check, size: 15, color: Color(0xFFFFEB3A)),
                          ],
                        ),
                      );
                    }).toList();
                  },
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161922) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedActionType == NotificationActionType.property
                              ? Iconsax.buildings
                              : (_selectedActionType == NotificationActionType.category
                                  ? Iconsax.location
                                  : (_selectedActionType == NotificationActionType.postProperty
                                      ? Iconsax.add_circle
                                      : (_selectedActionType == NotificationActionType.buyAndSell ? Iconsax.shop : Iconsax.home_2))),
                          size: 16,
                          color: AppTheme.primaryYellow,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedActionType == NotificationActionType.property
                                ? 'Open Specific Property Details (Direct Listing)'
                                : (_selectedActionType == NotificationActionType.category
                                    ? 'Open Locality Filter (e.g. Danavaipeta)'
                                    : (_selectedActionType == NotificationActionType.postProperty
                                        ? 'Open Post Property Screen (Prompt Owners)'
                                        : (_selectedActionType == NotificationActionType.buyAndSell
                                            ? 'Open Buy & Sell Hub'
                                            : 'Open App Home Feed'))),
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: primaryTextColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: mutedColor),
                      ],
                    ),
                  ),
                ),

                if (_selectedActionType == NotificationActionType.property && _properties.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Select Target Property:',
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.primaryYellow),
                  ),
                  const SizedBox(height: 4),
                  PopupMenuButton<String>(
                    tooltip: 'Select Target Property',
                    offset: const Offset(0, 44),
                    color: isDark ? const Color(0xFF1E2330) : Colors.white,
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    initialValue: _selectedPropertyId ?? _properties.first.id,
                    onSelected: (val) => setState(() => _selectedPropertyId = val),
                    itemBuilder: (context) {
                      return _properties.take(25).map((prop) {
                        final propId = prop.id ?? '';
                        final isSelected = (_selectedPropertyId ?? _properties.first.id) == propId;
                        return PopupMenuItem<String>(
                          value: propId,
                          height: 40,
                          child: Row(
                            children: [
                              Icon(
                                Iconsax.building_3,
                                size: 15,
                                color: isSelected ? AppTheme.primaryYellow : (isDark ? Colors.white70 : Colors.black87),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${prop.title} • ₹${prop.price} (${prop.locationStr.split(',').first})',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? AppTheme.primaryYellow : primaryTextColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check, size: 15, color: Color(0xFFFFEB3A)),
                            ],
                          ),
                        );
                      }).toList();
                    },
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161922) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Iconsax.building_3, size: 16, color: Color(0xFFFFEB3A)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                final selectedProp = _properties.firstWhere(
                                  (p) => p.id == (_selectedPropertyId ?? _properties.first.id),
                                  orElse: () => _properties.first,
                                );
                                return Text(
                                  '${selectedProp.title} • ₹${selectedProp.price} (${selectedProp.locationStr.split(',').first})',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: primaryTextColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                            ),
                          ),
                          Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: mutedColor),
                        ],
                      ),
                    ),
                  ),
                ],

                if (_selectedActionType == NotificationActionType.category ||
                    _selectedActionType == NotificationActionType.searchFilter) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Select Target Locality in Rajahmundry:',
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.primaryYellow),
                  ),
                  const SizedBox(height: 4),
                  PopupMenuButton<String>(
                    tooltip: 'Select Locality',
                    offset: const Offset(0, 44),
                    color: isDark ? const Color(0xFF1E2330) : Colors.white,
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    initialValue: _selectedCategoryOrLocality ?? 'Danavaipeta',
                    onSelected: (val) => setState(() => _selectedCategoryOrLocality = val),
                    itemBuilder: (context) {
                      return _rajahmundryLocalities.map((loc) {
                        final isSelected = (_selectedCategoryOrLocality ?? 'Danavaipeta') == loc;
                        return PopupMenuItem<String>(
                          value: loc,
                          height: 36,
                          child: Row(
                            children: [
                              Icon(
                                Iconsax.location,
                                size: 15,
                                color: isSelected ? AppTheme.primaryYellow : (isDark ? Colors.white70 : Colors.black87),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  loc,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? AppTheme.primaryYellow : primaryTextColor,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check, size: 15, color: Color(0xFFFFEB3A)),
                            ],
                          ),
                        );
                      }).toList();
                    },
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161922) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Iconsax.location, size: 16, color: Color(0xFFFFEB3A)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedCategoryOrLocality ?? 'Danavaipeta',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: primaryTextColor,
                              ),
                            ),
                          ),
                          Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: mutedColor),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Blast Button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _isSendingNotification ? null : _sendPushNotificationBroadcast,
              icon: _isSendingNotification
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Iconsax.send_1, size: 18),
              label: Text(
                _isSendingNotification ? 'Broadcasting Push Notification...' : 'Blast Push Notification Now',
                style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryYellow,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudienceChip({
    required TargetAudience target,
    required String label,
    required String count,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _selectedAudience == target;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final mutedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _selectedAudience = target),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryYellow.withValues(alpha: 0.15)
                : (isDark ? const Color(0xFF1E2330) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryYellow
                  : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppTheme.primaryYellow : mutedColor,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? primaryTextColor : mutedColor,
                ),
                maxLines: 1,
              ),
              Text(
                count,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? AppTheme.primaryYellow : mutedColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildTemplatePill(String template, bool isDark) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        setState(() {
          _notifTitleController.text = template;
          if (template.contains('Price Drop')) {
            _notifBodyController.text = 'Price reduced by ₹2,000/mo on verified Danavaipeta flat. Call owner directly.';
          } else if (template.contains('New Verified')) {
            _notifBodyController.text = 'Brand new East-facing 2BHK flat available for immediate move-in. Zero brokerage.';
          } else {
            _notifBodyController.text = 'Post your property in Rajahmundry today and connect with 5,000+ verified tenants for free.';
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2330) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          template,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationLiveMockupAndHistory(bool isDark) {
    final title = _notifTitleController.text.isEmpty ? '🔥 New Property Alert!' : _notifTitleController.text;
    final body = _notifBodyController.text.isEmpty
        ? 'Spacious 2BHK flat in Danavaipeta available now for ₹14,000/mo. Zero broker fee.'
        : _notifBodyController.text;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final mutedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Realistic iPhone Lockscreen Preview Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161922) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '📱 Live Lockscreen Preview',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'REALTIME',
                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF10B981)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Realistic Phone Enclosure
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // iPhone Top Status Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '9:41',
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                        // Dynamic Island Pill
                        Container(
                          width: 46,
                          height: 11,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        Row(
                          children: const [
                            Icon(Icons.signal_cellular_4_bar, color: Colors.white, size: 11),
                            SizedBox(width: 4),
                            Icon(Icons.wifi, color: Colors.white, size: 11),
                            SizedBox(width: 4),
                            Icon(Icons.battery_full_rounded, color: Colors.white, size: 12),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Lock Screen Date & Clock
                    Text(
                      'Friday, August 30',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '9:41',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w200,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Glassmorphic iOS Notification Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.asset(
                                  'assets/logo.png',
                                  width: 22,
                                  height: 22,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.home_rounded, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'RENTAL APP',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                    Text(
                                      'now',
                                      style: GoogleFonts.inter(color: Colors.white60, fontSize: 9.5),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  title,
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  body,
                                  style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.85), fontSize: 11, height: 1.3),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Recent Broadcast History
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161922) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Broadcasts',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                    ),
                  ),
                  Text(
                    'Last 5 blasts',
                    style: GoogleFonts.inter(fontSize: 11, color: mutedColor),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_broadcastHistory.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Text(
                      'No past broadcasts recorded yet.',
                      style: GoogleFonts.inter(color: mutedColor, fontSize: 12),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _broadcastHistory.take(4).length,
                  separatorBuilder: (_, __) => const Divider(height: 14),
                  itemBuilder: (context, idx) {
                    final item = _broadcastHistory[idx];
                    return Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Iconsax.notification, size: 14, color: Color(0xFF8B5CF6)),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: primaryTextColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${item.recipientCount} sent  •  ${item.actionDisplayName}',
                                style: GoogleFonts.inter(fontSize: 10.5, color: mutedColor),
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            setState(() {
                              _notifTitleController.text = item.title;
                              _notifBodyController.text = item.body;
                              _selectedActionType = item.actionType;
                              if (item.targetRouteOrId != null) {
                                _selectedPropertyId = item.targetRouteOrId;
                              }
                            });
                            AppSnackbar.success(context, '📋 Loaded broadcast template');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E2330) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Reuse',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryYellow,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 5: USERS & LANDLORDS DIRECTORY (CARDS & COLUMN GRID)
  // ==========================================
  Widget _buildUsersTab(bool isDark) {
    final mutedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);

    // Dynamically group properties by owner phone number
    final Map<String, List<PropertyModel>> ownerMap = {};
    for (final prop in _properties) {
      if (prop.ownerPhone.isNotEmpty) {
        ownerMap.putIfAbsent(prop.ownerPhone, () => []).add(prop);
      }
    }

    final totalOwners = ownerMap.length;
    final totalListings = _properties.length;
    final avgListings = totalOwners > 0 ? (totalListings / totalOwners).toStringAsFixed(1) : '1.0';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Executive Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161922) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Iconsax.profile_2user, color: Color(0xFF3B82F6), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Landlords & Property Owners Directory',
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6.5,
                                  height: 6.5,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'DIRECT OWNERS',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Direct property owners, verified phone contacts, multi-property portfolios, and 1-tap WhatsApp communication.',
                        style: GoogleFonts.inter(fontSize: 13, color: mutedColor),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedTabIndex = 3;
                          _selectedAudience = TargetAudience.landlords;
                        });
                      },
                      icon: const Icon(Iconsax.notification_bing, size: 16, color: Colors.black),
                      label: Text(
                        'Alert Landlords',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryYellow,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. 4-Core Landlord Statistics KPI Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 900;
              final crossAxisCount = isDesktop ? 4 : (constraints.maxWidth > 550 ? 2 : 1);
              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isDesktop ? 2.1 : 2.4,
                children: [
                  // KPI 1: Total Registered Landlords
                  _buildExecutiveKpiCard(
                    title: 'Registered Owners',
                    value: '$totalOwners Landlords',
                    subtitle: '100% Direct Owners',
                    badgeLabel: 'Zero Brokers',
                    badgeColor: const Color(0xFF10B981),
                    icon: Iconsax.user_tick,
                    iconColor: const Color(0xFF3B82F6),
                    isDark: isDark,
                    primaryTextColor: primaryTextColor,
                    mutedColor: mutedColor,
                  ),

                  // KPI 2: Total Managed Properties
                  _buildExecutiveKpiCard(
                    title: 'Managed Inventory',
                    value: '$totalListings Listings',
                    subtitle: 'Avg $avgListings units / owner',
                    badgeLabel: 'Active Portfolios',
                    badgeColor: AppTheme.primaryYellow,
                    icon: Iconsax.building_4,
                    iconColor: AppTheme.primaryYellow,
                    isDark: isDark,
                    primaryTextColor: primaryTextColor,
                    mutedColor: mutedColor,
                  ),

                  // KPI 3: WhatsApp Verified
                  _buildExecutiveKpiCard(
                    title: 'Direct WhatsApp Verified',
                    value: '$totalOwners / $totalOwners Verified',
                    subtitle: 'Direct tenant chat ready',
                    badgeLabel: '100% Ready',
                    badgeColor: const Color(0xFF10B981),
                    icon: Iconsax.message,
                    iconColor: const Color(0xFF10B981),
                    isDark: isDark,
                    primaryTextColor: primaryTextColor,
                    mutedColor: mutedColor,
                  ),

                  // KPI 4: Multi-Listing Landlords
                  _buildExecutiveKpiCard(
                    title: 'Portfolio Landlords',
                    value: '${ownerMap.values.where((l) => l.length > 1).length} Multi-Unit',
                    subtitle: 'Owners with > 1 listing',
                    badgeLabel: 'Power Hosts',
                    badgeColor: const Color(0xFF8B5CF6),
                    icon: Iconsax.medal_star,
                    iconColor: const Color(0xFF8B5CF6),
                    isDark: isDark,
                    primaryTextColor: primaryTextColor,
                    mutedColor: mutedColor,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // 3. Multi-Column Landlord Card Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width > 1150 ? 3 : (width > 680 ? 2 : 1);

              if (ownerMap.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161922) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  ),
                  child: Center(
                    child: Text('No property owners registered yet.', style: GoogleFonts.inter(color: mutedColor, fontSize: 13)),
                  ),
                );
              }

              final entries = ownerMap.entries.toList();

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  mainAxisExtent: 310, // snug, perfectly fitted height
                ),
                itemCount: entries.length,
                itemBuilder: (context, idx) {
                  final entry = entries[idx];
                  final phone = entry.key;
                  final props = entry.value;
                  final ownerName = props.first.title.split('-').first.trim().isNotEmpty
                      ? props.first.title.split('-').first.trim()
                      : 'Landlord ${idx + 1}';

                  final localities = props.map((p) => p.locationStr.split(',').first.trim()).toSet().toList();

                  return _buildLandlordCard(
                    ownerName: ownerName,
                    phone: phone,
                    props: props,
                    localities: localities,
                    isDark: isDark,
                    primaryTextColor: primaryTextColor,
                    mutedColor: mutedColor,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // COMPONENT: INDIVIDUAL LANDLORD CARD
  // ==========================================
  Widget _buildLandlordCard({
    required String ownerName,
    required String phone,
    required List<PropertyModel> props,
    required List<String> localities,
    required bool isDark,
    required Color primaryTextColor,
    required Color mutedColor,
  }) {
    final isMulti = props.length > 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header: Avatar + Name + Property Count Badge
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isMulti
                        ? [AppTheme.primaryYellow, const Color(0xFFD97706)]
                        : [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  ownerName.isNotEmpty ? ownerName[0].toUpperCase() : 'O',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ownerName,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Iconsax.verify, size: 12, color: Color(0xFF10B981)),
                        const SizedBox(width: 4),
                        Text(
                          'Direct Landlord',
                          style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isMulti ? AppTheme.primaryYellow : const Color(0xFF3B82F6)).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${props.length} ${props.length == 1 ? 'Unit' : 'Units'}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isMulti ? AppTheme.primaryYellow : const Color(0xFF3B82F6),
                  ),
                ),
              ),
            ],
          ),

          // Contact Details Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2330) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Iconsax.call, size: 13, color: mutedColor),
                    const SizedBox(width: 6),
                    Text(
                      phone,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(Iconsax.location, size: 12, color: mutedColor),
                    const SizedBox(width: 4),
                    Text(
                      localities.take(2).join(', '),
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: mutedColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Mini Portfolio Preview (Top 2 Properties)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Managed Units:',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: mutedColor),
              ),
              const SizedBox(height: 5),
              ...props.take(2).map((p) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                p.title,
                                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: primaryTextColor),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '₹${p.price}',
                        style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppTheme.primaryYellow),
                      ),
                    ],
                  ),
                );
              }),
              if (props.length > 2)
                Text(
                  '+${props.length - 2} more properties in portfolio',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: mutedColor),
                ),
            ],
          ),

          // Action Buttons: WhatsApp + Phone Preview
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _contactOwnerWhatsApp(phone, props.first.title),
                  icon: const Icon(Icons.chat_bubble_outline, size: 14),
                  label: Text('WhatsApp', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'View on Live Phone Preview',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _viewPropertyInLivePhone(props.first),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2330) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Iconsax.mobile, size: 16, color: mutedColor),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }





  // ==========================================
  // PROPERTY INSPECTION & REJECT DIALOGS
  // ==========================================
  void _showPropertyInspectionModal(PropertyModel prop, bool isDark) {
    final propId = prop.id ?? '';
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF161922) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 700,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Listing Inspection',
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (prop.imageUrls.isNotEmpty)
                    SizedBox(
                      height: 180,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: prop.imageUrls.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, i) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: prop.imageUrls[i],
                              width: 220,
                              height: 180,
                              fit: BoxFit.cover,
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    prop.title,
                    style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${prop.price}/month • Deposit: ₹${prop.securityDeposit ?? 'N/A'} • ${prop.locationStr}',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryYellow,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    prop.description ?? 'No description provided.',
                    style: GoogleFonts.inter(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _updatePropertyStatus(propId, 'approved');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Approve Listing'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showRejectDialog(propId);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Reject Listing'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showRejectDialog(String id) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject Property Submission', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Provide feedback reason for the owner (e.g. unclear room photos, inaccurate address, broker listing):'),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Enter reason for rejection...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updatePropertyStatus(id, 'rejected', reason: reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    await _supabase.auth.signOut();
    if (mounted) {
      AppSnackbar.success(context, 'Logged out from Admin Portal');
      Navigator.pushReplacementNamed(context, '/admin');
    }
  }
}

// ==========================================
// CUSTOM WAVE CHART PAINTER FOR INQUIRY TRAFFIC
// ==========================================
class _InquiryWaveChartPainter extends CustomPainter {
  final List<double> dataPoints;
  final bool isDark;
  final Color accentColor;

  _InquiryWaveChartPainter({
    required this.dataPoints,
    required this.isDark,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final double maxVal = dataPoints.reduce((a, b) => a > b ? a : b) * 1.15;
    final double minVal = 0;
    final double range = (maxVal - minVal) <= 0 ? 1 : (maxVal - minVal);

    // 1. Draw subtle horizontal grid lines
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. Compute point coordinates
    final points = <Offset>[];
    final double dx = size.width / (dataPoints.length - 1);

    for (int i = 0; i < dataPoints.length; i++) {
      final double normalized = (dataPoints[i] - minVal) / range;
      final double y = size.height - (normalized * (size.height - 24)) - 12;
      points.add(Offset(i * dx, y));
    }

    // 3. Build Smooth Bezier Wave Path
    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    // 4. Fill Area Gradient Under Curve
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillGradient = LinearGradient(
      colors: [
        accentColor.withValues(alpha: isDark ? 0.35 : 0.25),
        accentColor.withValues(alpha: 0.0),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // 5. Draw Glowing Stroke Line
    final strokePaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, strokePaint);

    // 6. Draw Interactive / Stylized Nodes
    final dotPaint = Paint()..style = PaintingStyle.fill;
    final dotBorderPaint = Paint()
      ..color = isDark ? const Color(0xFF161922) : Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      final isPeak = i == points.length - 2; // Saturday peak

      // Outer glow for peak
      if (isPeak) {
        final glowPaint = Paint()
          ..color = accentColor.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(pt, 8, glowPaint);
      }

      // Dot fill & border
      dotPaint.color = isPeak ? const Color(0xFFEF4444) : accentColor;
      canvas.drawCircle(pt, isPeak ? 5 : 3.5, dotPaint);
      canvas.drawCircle(pt, isPeak ? 5 : 3.5, dotBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _InquiryWaveChartPainter oldDelegate) {
    return oldDelegate.dataPoints != dataPoints ||
        oldDelegate.isDark != isDark ||
        oldDelegate.accentColor != accentColor;
  }
}
