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
import 'home_screen.dart' show HomeScreen, PropertyModel;
import 'posting_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _supabase = Supabase.instance.client;

  // Navigation State
  // 0: Overview, 1: Properties, 2: Analytics & Click Radar, 3: Push Notifications, 4: Users, 5: Banners, 6: Settings
  int _selectedTabIndex = 0;
  bool _isSidebarCollapsed = false;

  // Live iPhone User App Preview on Right Side
  bool _showLiveUserAppPreview = false;
  bool _previewDarkMode = false;
  int _previewKeyIndex = 0;
  double _previewPanelWidth = 520.0;

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

  // Rajamahendravaram Key Localities
  final List<String> _rajahmundryLocalities = const [
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

  // Top Trending Search Terms in Rajahmundry
  final List<Map<String, dynamic>> _trendingSearchTerms = const [
    {'query': '2BHK Danavaipeta with Car Parking', 'count': 840, 'growth': '+24%'},
    {'query': 'Boys PG near Godavari Institute / GIET', 'count': 620, 'growth': '+38%'},
    {'query': 'Single Room with Attached Bath Morampudi', 'count': 510, 'growth': '+15%'},
    {'query': 'Independent House for Sale Prakash Nagar', 'count': 430, 'growth': '+12%'},
    {'query': 'Girls Hostel with Food VL Puram', 'count': 390, 'growth': '+19%'},
    {'query': 'Commercial Shop Main Road Kotipalli', 'count': 280, 'growth': '+8%'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchProperties();
    _fetchNotificationHistory();
  }

  @override
  void dispose() {
    _notifTitleController.dispose();
    _notifBodyController.dispose();
    _notifImageController.dispose();
    _customUrlController.dispose();
    super.dispose();
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
      await _supabase.from('properties').delete().eq('id', id);
      if (mounted) {
        AppSnackbar.success(context, 'Property deleted successfully');
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
      recipientCount: _selectedAudience == TargetAudience.allUsers
          ? 3420
          : (_selectedAudience == TargetAudience.tenants ? 2180 : 1240),
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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1117) : const Color(0xFFF4F6F9),
      body: isDesktop ? _buildDesktopLayout(isDark) : _buildMobileTabletLayout(isDark),
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
                child: Row(
                  children: [
                    // Main Admin Content Area
                    Expanded(
                      child: Container(
                        color: isDark ? const Color(0xFF0F1117) : const Color(0xFFF4F6F9),
                        child: _buildActiveTabContent(isDark),
                      ),
                    ),

                    // Right-Side Live iPhone 16 Pro User App Preview
                    if (_showLiveUserAppPreview)
                      _buildLiveUserAppSidePanel(isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // LIVE IPHONE 16 PRO SIDE PANEL WIDGET
  // ==========================================
  Widget _buildLiveUserAppSidePanel(bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Draggable Resizer Splitter Bar
        MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: (details) {
              setState(() {
                _previewPanelWidth = (_previewPanelWidth - details.delta.dx).clamp(380.0, 950.0);
              });
            },
            child: Container(
              width: 12,
              color: isDark ? const Color(0xFF161922) : const Color(0xFFE5E7EB),
              child: Center(
                child: Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white30 : const Color(0xFF9CA3AF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Preview Container
        Container(
          width: _previewPanelWidth,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF13161F) : const Color(0xFFEEF2F6),
            border: Border(
              left: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFD1D5DB),
                width: 1.5,
              ),
            ),
          ),
          child: Column(
            children: [
              // Ultra-Compact Control Bar (Minimal Height, Zero Wasted Space)
              Container(
                height: 38,
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
                    const Icon(Iconsax.mobile, size: 15, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 6),
                    Text(
                      'iPhone 16 Pro',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Quick Size Presets
                    _buildSizePresetPill('S', 420.0, isDark),
                    const SizedBox(width: 4),
                    _buildSizePresetPill('M', 520.0, isDark),
                    const SizedBox(width: 4),
                    _buildSizePresetPill('L', 660.0, isDark),
                    const SizedBox(width: 4),
                    _buildSizePresetPill('XL', 820.0, isDark),

                    const Spacer(),

                    // Device Theme Toggle
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      icon: Icon(
                        _previewDarkMode ? Iconsax.sun_1 : Iconsax.moon,
                        size: 15,
                        color: _previewDarkMode ? Colors.amber : (isDark ? Colors.white70 : Colors.black87),
                      ),
                      tooltip: 'Toggle iPhone Dark/Light Mode',
                      onPressed: () => setState(() => _previewDarkMode = !_previewDarkMode),
                    ),
                    const SizedBox(width: 4),

                    // Reload Device State
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      icon: Icon(Iconsax.refresh, size: 15, color: isDark ? Colors.white70 : Colors.black87),
                      tooltip: 'Restart & Reload Preview',
                      onPressed: () {
                        setState(() => _previewKeyIndex++);
                        AppSnackbar.success(context, '🔄 iPhone 16 Pro preview reloaded!');
                      },
                    ),
                    const SizedBox(width: 4),

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

              // Embedded iPhone 16 Pro Device Frame running REAL User App
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                  alignment: Alignment.topCenter,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: 430,
                      height: 932,
                      child: DeviceFrame(
                        device: Devices.ios.iPhone13ProMax.copyWith(
                          name: 'iPhone 16 Pro',
                        ),
                        isFrameVisible: true,
                        orientation: Orientation.portrait,
                        screen: Container(
                          color: _previewDarkMode ? AppTheme.darkScaffold : Colors.white,
                          child: MaterialApp(
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
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSizePresetPill(String label, double width, bool isDark) {
    final isSelected = (_previewPanelWidth - width).abs() < 20;

    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () => setState(() => _previewPanelWidth = width),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF59E0B)
              : (isDark ? const Color(0xFF272D3B) : const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
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
  // SIDEBAR NAVIGATION
  // ==========================================
  Widget _buildSidebar(bool isDark) {
    final width = _isSidebarCollapsed ? 80.0 : 265.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
      ),
      child: _buildSidebarContent(isDark, isDrawer: false),
    );
  }

  Widget _buildSidebarContent(bool isDark, {required bool isDrawer}) {
    final pendingCount = _properties.where((p) => p.status == 'pending').length;
    final isCollapsed = _isSidebarCollapsed && !isDrawer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Branding Header
        Container(
          padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 12 : 18, vertical: 20),
          child: isCollapsed
              ? Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          'assets/logo.png',
                          width: 24,
                          height: 24,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.home, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ),
                )
              : Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/logo.png',
                            width: 24,
                            height: 24,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(Icons.home, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Rental App',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'Rajamahendravaram',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF6B7280),
                                  ),
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

        const Divider(height: 1, thickness: 1),
        const SizedBox(height: 12),

        // Navigation Items List
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: [
              _buildSidebarItem(
                index: 0,
                icon: Iconsax.category,
                label: 'Dashboard Overview',
                isDark: isDark,
                isDrawer: isDrawer,
              ),
              _buildSidebarItem(
                index: 1,
                icon: Iconsax.buildings_2,
                label: 'Property Approvals',
                badgeCount: pendingCount > 0 ? pendingCount : null,
                badgeColor: const Color(0xFFF59E0B),
                isDark: isDark,
                isDrawer: isDrawer,
              ),
              _buildSidebarItem(
                index: 2,
                icon: Iconsax.chart_21,
                label: 'Click & Demand Radar',
                isHighlight: true,
                isDark: isDark,
                isDrawer: isDrawer,
              ),
              _buildSidebarItem(
                index: 3,
                icon: Iconsax.notification_bing,
                label: 'Push Broadcast Hub',
                isDark: isDark,
                isDrawer: isDrawer,
              ),
              _buildSidebarItem(
                index: 4,
                icon: Iconsax.people,
                label: 'Landlords & Users',
                isDark: isDark,
                isDrawer: isDrawer,
              ),
              _buildSidebarItem(
                index: 5,
                icon: Iconsax.gallery_export,
                label: 'Banners & Promos',
                isDark: isDark,
                isDrawer: isDrawer,
              ),
              _buildSidebarItem(
                index: 6,
                icon: Iconsax.setting_2,
                label: 'City & App Settings',
                isDark: isDark,
                isDrawer: isDrawer,
              ),
            ],
          ),
        ),

        // Bottom User / Theme Profile Section
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB),
              ),
            ),
          ),
          child: Column(
            children: [
              if (!isCollapsed)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F232E) : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFFF59E0B),
                        child: Text(
                          'A',
                          style: GoogleFonts.inter(
                            color: Colors.black,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Super Admin',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              'admin@rental.in',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF6B7280),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),

              // OPEN USER APP ACTION (TOGGLES LIVE IPHONE PREVIEW)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!isCollapsed)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _showLiveUserAppPreview = !_showLiveUserAppPreview);
                          if (_showLiveUserAppPreview) {
                            AppSnackbar.success(context, '📱 Opened Live iPhone User App Preview on right side!');
                          }
                        },
                        icon: Icon(
                          Iconsax.mobile,
                          size: 15,
                          color: _showLiveUserAppPreview ? const Color(0xFF10B981) : (isDark ? Colors.white70 : const Color(0xFF374151)),
                        ),
                        label: Text(
                          _showLiveUserAppPreview ? 'Hide User App' : 'Open User App',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: _showLiveUserAppPreview ? const Color(0xFF10B981) : (isDark ? Colors.white70 : const Color(0xFF374151)),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: _showLiveUserAppPreview ? const Color(0xFF10B981) : (isDark ? Colors.white24 : const Color(0xFFD1D5DB)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Iconsax.logout, color: Colors.redAccent, size: 18),
                    tooltip: 'Log Out',
                    onPressed: _handleLogout,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarItem({
    required int index,
    required IconData icon,
    required String label,
    int? badgeCount,
    Color? badgeColor,
    bool isHighlight = false,
    required bool isDark,
    required bool isDrawer,
  }) {
    final isSelected = _selectedTabIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() => _selectedTabIndex = index);
            if (isDrawer) Navigator.pop(context);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10.5),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.15) : const Color(0xFFF59E0B).withValues(alpha: 0.12))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(
                      color: isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.4) : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? const Color(0xFFF59E0B)
                      : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                ),
                if (!_isSidebarCollapsed || isDrawer) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? (isDark ? Colors.white : Colors.black87)
                            : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563)),
                      ),
                    ),
                  ),
                  if (badgeCount != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor ?? Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeCount.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  if (isHighlight && badgeCount == null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'LIVE',
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TOP DESKTOP HEADER BAR
  // ==========================================
  Widget _buildTopHeader(bool isDark) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isSidebarCollapsed ? Iconsax.sidebar_right : Iconsax.sidebar_left,
              color: isDark ? Colors.white : Colors.black87,
              size: 20,
            ),
            onPressed: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _getTabTitle(_selectedTabIndex),
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),

          // TOGGLE LIVE IPHONE USER APP BUTTON (KEY FEATURE)
          ElevatedButton.icon(
            onPressed: () => setState(() => _showLiveUserAppPreview = !_showLiveUserAppPreview),
            icon: Icon(
              Iconsax.mobile,
              size: 15,
              color: _showLiveUserAppPreview ? Colors.black : Colors.white,
            ),
            label: Text(
              _showLiveUserAppPreview ? '📱 Close User App' : '📱 Open User App',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: _showLiveUserAppPreview ? Colors.black : Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _showLiveUserAppPreview ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),

          // Export CSV Shortcut
          OutlinedButton.icon(
            onPressed: _exportPropertiesCSV,
            icon: const Icon(Iconsax.document_download, size: 15),
            label: Text('CSV', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.white70 : const Color(0xFF374151),
              side: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFD1D5DB)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),

          // Quick Create Broadcast Shortcut
          ElevatedButton.icon(
            onPressed: () => setState(() => _selectedTabIndex = 3),
            icon: const Icon(Iconsax.notification_bing, size: 15),
            label: Text(
              'Broadcast',
              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),

          IconButton(
            icon: Icon(Iconsax.refresh, color: isDark ? Colors.white : Colors.black87, size: 18),
            tooltip: 'Refresh All Data',
            onPressed: () {
              _fetchProperties();
              _fetchNotificationHistory();
            },
          ),
          const SizedBox(width: 4),

          IconButton(
            icon: Icon(
              isDark ? Iconsax.sun_1 : Iconsax.moon,
              color: isDark ? Colors.amber : Colors.black87,
              size: 18,
            ),
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: () => ThemeController.instance.toggleTheme(),
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
      case 5:
        return 'Home Banners & Announcements';
      case 6:
        return 'City Configuration & Settings';
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
      case 5:
        return _buildBannersTab(isDark);
      case 6:
        return _buildSettingsTab(isDark);
      default:
        return _buildOverviewTab(isDark);
    }
  }

  // ==========================================
  // TAB 1: OVERVIEW & ANALYTICS DASHBOARD
  // ==========================================
  Widget _buildOverviewTab(bool isDark) {
    final total = _properties.length;
    final pendingCount = _properties.where((p) => p.status == 'pending').length;
    final occupiedCount = _properties.where((p) => !p.isAvailable).length;
    final availableCount = _properties.where((p) => p.isAvailable && p.status == 'approved').length;

    double portfolioCr = 0;
    for (final p in _properties) {
      final rentNum = double.tryParse(p.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 10000;
      portfolioCr += (rentNum * 200) / 10000000;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E2430), const Color(0xFF161A23)]
                    : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
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
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '📍 RAJAMAHENDRAVARAM REGION COMMAND',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFF59E0B),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (pendingCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '⚡ $pendingCount Pending Approvals',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.orangeAccent,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Rental App Rajamahendravaram Operations',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Real-time moderation, tenant inquiry heatmaps, occupancy tracking, and instant push notification broadcasting across Rajahmundry.',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          color: const Color(0xFF94A3B8),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (pendingCount > 0) ...[
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _batchApproveAllPending,
                    icon: const Icon(Iconsax.tick_circle, color: Colors.black, size: 18),
                    label: Text(
                      'Approve All ($pendingCount)',
                      style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 1200 ? 6 : (constraints.maxWidth > 800 ? 3 : 2);
              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.8,
                children: [
                  _buildMetricCard(
                    title: 'Total Listings',
                    value: total.toString(),
                    subtitle: 'In Database',
                    icon: Iconsax.buildings,
                    color: const Color(0xFF3B82F6),
                    isDark: isDark,
                  ),
                  _buildMetricCard(
                    title: 'Pending Review',
                    value: pendingCount.toString(),
                    subtitle: 'Awaiting Action',
                    icon: Iconsax.clock,
                    color: const Color(0xFFF59E0B),
                    isDark: isDark,
                    onTap: () => setState(() {
                      _selectedTabIndex = 1;
                      _statusFilter = 'pending';
                    }),
                  ),
                  _buildMetricCard(
                    title: 'Live Vacant',
                    value: availableCount.toString(),
                    subtitle: 'Ready to Move',
                    icon: Iconsax.tick_circle,
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                  ),
                  _buildMetricCard(
                    title: 'Occupied / Sold',
                    value: occupiedCount.toString(),
                    subtitle: 'Zero Vacancy',
                    icon: Iconsax.lock,
                    color: const Color(0xFFEC4899),
                    isDark: isDark,
                    onTap: () => setState(() {
                      _selectedTabIndex = 1;
                      _statusFilter = 'occupied';
                    }),
                  ),
                  _buildMetricCard(
                    title: 'Portfolio Value',
                    value: '₹${portfolioCr.toStringAsFixed(1)} Cr',
                    subtitle: 'Asset Multiplier',
                    icon: Iconsax.money_recive,
                    color: const Color(0xFF8B5CF6),
                    isDark: isDark,
                  ),
                  _buildMetricCard(
                    title: 'Tenant Clicks',
                    value: '14.8K',
                    subtitle: 'This Month',
                    icon: Iconsax.chart_21,
                    color: const Color(0xFF06B6D4),
                    isDark: isDark,
                    onTap: () => setState(() => _selectedTabIndex = 2),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),

          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 950) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildLocalityDistributionCard(isDark)),
                    const SizedBox(width: 20),
                    Expanded(flex: 4, child: _buildQuickApprovalQueueCard(isDark)),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildLocalityDistributionCard(isDark),
                    const SizedBox(height: 20),
                    _buildQuickApprovalQueueCard(isDark),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161922) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF4B5563),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                      ),
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildLocalityDistributionCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Top Rajahmundry Localities',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Icon(Iconsax.location, color: Color(0xFFF59E0B), size: 18),
            ],
          ),
          const SizedBox(height: 16),
          ..._rajahmundryLocalities.take(6).map((loc) {
            final count = _properties.where((p) => p.locationStr.toLowerCase().contains(loc.toLowerCase())).length;
            final pct = _properties.isEmpty ? 0.0 : (count / _properties.length).clamp(0.05, 1.0);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        loc,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF374151),
                        ),
                      ),
                      Text(
                        '$count listings',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
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

  Widget _buildQuickApprovalQueueCard(bool isDark) {
    final pendingList = _properties.where((p) => p.status == 'pending').take(5).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pending Review Queue (${pendingList.length})',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _selectedTabIndex = 1;
                  _statusFilter = 'pending';
                }),
                child: Text('View All', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (pendingList.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Iconsax.tick_circle, size: 42, color: Color(0xFF10B981)),
                  const SizedBox(height: 10),
                  Text(
                    'All caught up! No pending properties.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pendingList.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (context, idx) {
                final prop = pendingList[idx];
                final propId = prop.id ?? '';

                return Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: prop.imageUrls.isNotEmpty ? prop.imageUrls.first : '',
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 52,
                          height: 52,
                          color: const Color(0xFFE5E7EB),
                          child: const Icon(Iconsax.image, size: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            prop.title,
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '₹${prop.price} • ${prop.locationStr}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF6B7280),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Iconsax.tick_circle, color: Color(0xFF10B981), size: 22),
                      tooltip: 'Approve Live',
                      onPressed: () => _updatePropertyStatus(propId, 'approved'),
                    ),
                    IconButton(
                      icon: const Icon(Iconsax.close_circle, color: Colors.redAccent, size: 22),
                      tooltip: 'Reject',
                      onPressed: () => _showRejectDialog(propId),
                    ),
                  ],
                );
              },
            ),
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

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161922) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        onChanged: (val) => setState(() => _propertySearchQuery = val),
                        style: GoogleFonts.inter(color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'Search properties by Title, Owner Phone, Locality, or ID...',
                          hintStyle: GoogleFonts.inter(color: isDark ? Colors.white38 : Colors.grey.shade400, fontSize: 13.5),
                          prefixIcon: const Icon(Iconsax.search_normal, size: 18),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1F232E) : const Color(0xFFF9FAFB),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    DropdownButtonHideUnderline(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1F232E) : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
                        ),
                        child: DropdownButton<String>(
                          value: _typeFilter,
                          dropdownColor: isDark ? const Color(0xFF1F232E) : Colors.white,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All Types')),
                            DropdownMenuItem(value: 'Rental', child: Text('House / Flat')),
                            DropdownMenuItem(value: 'PG', child: Text('Hostel / PG')),
                            DropdownMenuItem(value: 'Commercial', child: Text('Commercial')),
                          ],
                          onChanged: (val) => setState(() => _typeFilter = val ?? 'all'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    DropdownButtonHideUnderline(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1F232E) : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
                        ),
                        child: DropdownButton<String>(
                          value: _localityFilter,
                          dropdownColor: isDark ? const Color(0xFF1F232E) : Colors.white,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                          items: [
                            const DropdownMenuItem(value: 'all', child: Text('All Localities')),
                            ..._rajahmundryLocalities.map((loc) => DropdownMenuItem(value: loc, child: Text(loc))),
                          ],
                          onChanged: (val) => setState(() => _localityFilter = val ?? 'all'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

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
                        badgeColor: const Color(0xFFF59E0B),
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
                        badgeColor: const Color(0xFFEC4899),
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
                        badgeColor: Colors.redAccent,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Expanded(
            child: _isLoadingProperties
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)))
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Iconsax.buildings, size: 54, color: isDark ? Colors.white24 : Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              'No properties matching the selected filters.',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, idx) => _buildDesktopPropertyRow(filtered[idx], isDark),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(String value, String label, bool isDark, {Color? badgeColor}) {
    final isSelected = _statusFilter == value;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _statusFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (badgeColor?.withValues(alpha: 0.2) ?? const Color(0xFFF59E0B).withValues(alpha: 0.2))
              : (isDark ? const Color(0xFF1F232E) : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? (badgeColor ?? const Color(0xFFF59E0B))
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (isDark ? Colors.white : Colors.black87)
                : (isDark ? AppTheme.darkTextSecondary : const Color(0xFF4B5563)),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopPropertyRow(PropertyModel prop, bool isDark) {
    final propId = prop.id ?? '';
    final statusColor = prop.status == 'approved'
        ? const Color(0xFF10B981)
        : (prop.status == 'pending' ? const Color(0xFFF59E0B) : Colors.redAccent);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: prop.imageUrls.isNotEmpty ? prop.imageUrls.first : '',
                  width: 90,
                  height: 75,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    width: 90,
                    height: 75,
                    color: const Color(0xFFE5E7EB),
                    child: const Icon(Iconsax.image, size: 28),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${prop.imageUrls.length} photos',
                      style: GoogleFonts.inter(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        prop.title,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: prop.type == 'PG'
                            ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                            : const Color(0xFF3B82F6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        prop.type,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: prop.type == 'PG' ? const Color(0xFF8B5CF6) : const Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  prop.locationStr,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF6B7280),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Owner: ${prop.ownerPhone}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _contactOwnerWhatsApp(prop.ownerPhone, prop.title),
                      child: const Icon(Icons.chat_bubble_outline, size: 14, color: Color(0xFF10B981)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₹${prop.price}/mo',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
                Text(
                  'Deposit: ₹${prop.securityDeposit ?? 'N/A'}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),

          InkWell(
            onTap: () => _toggleAvailability(propId, prop.isAvailable),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: prop.isAvailable
                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                    : const Color(0xFFEC4899).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: prop.isAvailable
                      ? const Color(0xFF10B981).withValues(alpha: 0.4)
                      : const Color(0xFFEC4899).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    prop.isAvailable ? Iconsax.tick_circle : Iconsax.lock,
                    size: 13,
                    color: prop.isAvailable ? const Color(0xFF10B981) : const Color(0xFFEC4899),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    prop.isAvailable ? 'VACANT' : 'OCCUPIED',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: prop.isAvailable ? const Color(0xFF10B981) : const Color(0xFFEC4899),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              prop.status.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 16),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Iconsax.eye, size: 20),
                tooltip: 'Inspect Details & Photos',
                onPressed: () => _showPropertyInspectionModal(prop, isDark),
              ),
              if (prop.status != 'approved')
                IconButton(
                  icon: const Icon(Iconsax.tick_circle, color: Color(0xFF10B981), size: 22),
                  tooltip: 'Approve Listing',
                  onPressed: () => _updatePropertyStatus(propId, 'approved'),
                ),
              if (prop.status != 'rejected')
                IconButton(
                  icon: const Icon(Iconsax.close_circle, color: Colors.redAccent, size: 22),
                  tooltip: 'Reject Listing',
                  onPressed: () => _showRejectDialog(propId),
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (val) {
                  if (val == 'availability') _toggleAvailability(propId, prop.isAvailable);
                  if (val == 'delete') _deleteProperty(propId);
                  if (val == 'broadcast') {
                    setState(() {
                      _selectedTabIndex = 3;
                      _selectedActionType = NotificationActionType.property;
                      _selectedPropertyId = propId;
                      _notifTitleController.text = '🔥 Check out this property in ${prop.locationStr.split(',').first}!';
                      _notifBodyController.text = '${prop.title} available now for ₹${prop.price}/month. Zero broker fee.';
                    });
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'availability',
                    child: Text(prop.isAvailable ? 'Mark as Occupied' : 'Mark as Available'),
                  ),
                  const PopupMenuItem(
                    value: 'broadcast',
                    child: Text('Create Push Notification'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete Listing', style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: CLICK ANALYTICS & TENANT DEMAND RADAR
  // ==========================================
  Widget _buildClickRadarTab(bool isDark) {
    final topClickedProps = _properties.take(8).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E1A33), const Color(0xFF131024)]
                    : [const Color(0xFFF3E8FF), const Color(0xFFEDE9FE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Iconsax.chart_21, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🔥 User Click Heatmap & Demand Radar',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF5B21B6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Understand what tenants are watching most, trending searches across Rajahmundry colleges and IT hubs, and PG room occupancy velocities.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF6D28D9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 1050) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: _buildMostWatchedLeaderboard(topClickedProps, isDark)),
                    const SizedBox(width: 24),
                    Expanded(flex: 3, child: _buildTrendingSearchesRadar(isDark)),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildMostWatchedLeaderboard(topClickedProps, isDark),
                    const SizedBox(height: 24),
                    _buildTrendingSearchesRadar(isDark),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMostWatchedLeaderboard(List<PropertyModel> props, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🏆 Top 10 Most Clicked & Watched Properties',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'HIGH DEMAND',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFFF59E0B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: props.length,
            separatorBuilder: (_, __) => const Divider(height: 20),
            itemBuilder: (context, idx) {
              final p = props[idx];
              final views = 2400 - (idx * 210);
              final inquiries = 84 - (idx * 7);

              return Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: idx == 0
                          ? const Color(0xFFF59E0B)
                          : (idx == 1
                              ? Colors.grey.shade400
                              : (idx == 2 ? Colors.brown.shade300 : (isDark ? Colors.white12 : Colors.black12))),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '#${idx + 1}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: idx < 3 ? Colors.black : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: p.imageUrls.isNotEmpty ? p.imageUrls.first : '',
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(width: 48, height: 48, color: Colors.grey.shade300),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.title,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${p.locationStr} • ₹${p.price}/mo',
                          style: GoogleFonts.inter(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          const Icon(Iconsax.eye, size: 14, color: Color(0xFF3B82F6)),
                          const SizedBox(width: 4),
                          Text(
                            '$views views',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      Text(
                        '🔥 $inquiries calls/chats',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingSearchesRadar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '⚡ Trending Search Demand',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Icon(Iconsax.search_status, color: Color(0xFF8B5CF6), size: 18),
            ],
          ),
          const SizedBox(height: 14),
          ..._trendingSearchTerms.map((term) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F232E) : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          term['query'],
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${term['count']} queries this week',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      term['growth'],
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF10B981)),
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
  // TAB 4: PUSH NOTIFICATION BROADCAST HUB
  // ==========================================
  Widget _buildPushNotificationsTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF2C2210), const Color(0xFF1E1708)]
                    : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Iconsax.notification_bing, color: Colors.black, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Push Notification & Deep-Link Broadcast Hub',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF92400E),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Compose and blast instant push alerts to all Rajamahendravaram users. Select deep-link routing to open exact property IDs, categories, or post screens upon user tap.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: isDark ? AppTheme.darkTextSecondary : const Color(0xFFB45309),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 1000) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildNotificationComposerForm(isDark)),
                    const SizedBox(width: 24),
                    Expanded(flex: 2, child: _buildNotificationLiveMockupAndHistory(isDark)),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildNotificationComposerForm(isDark),
                    const SizedBox(height: 24),
                    _buildNotificationLiveMockupAndHistory(isDark),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationComposerForm(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Compose Broadcast Notification',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 18),

          Text(
            'Quick Inspiration Templates:',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTemplatePill('🔥 Price Drop in Danavaipeta', isDark),
                const SizedBox(width: 8),
                _buildTemplatePill('🏡 New 2BHK Near RTC Complex', isDark),
                const SizedBox(width: 8),
                _buildTemplatePill('📢 Zero Broker Fee Weekend Alert', isDark),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Text(
            'Notification Title *',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _notifTitleController,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.inter(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: 'e.g. 🔥 New Luxury 3BHK in Danavaipeta!',
              filled: true,
              fillColor: isDark ? const Color(0xFF1F232E) : const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Message Body *',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _notifBodyController,
            onChanged: (_) => setState(() {}),
            maxLines: 3,
            style: GoogleFonts.inter(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: 'e.g. Spacious East-facing flat near RTC Complex with 100% Vastu and car parking.',
              filled: true,
              fillColor: isDark ? const Color(0xFF1F232E) : const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Target Audience Segment:',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<TargetAudience>(
            value: _selectedAudience,
            dropdownColor: isDark ? const Color(0xFF1F232E) : Colors.white,
            style: GoogleFonts.inter(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? const Color(0xFF1F232E) : const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: TargetAudience.allUsers,
                child: Text('All Users in Rajamahendravaram (~3,420 Users)'),
              ),
              DropdownMenuItem(
                value: TargetAudience.tenants,
                child: Text('Tenants & Rent Seekers (~2,180 Users)'),
              ),
              DropdownMenuItem(
                value: TargetAudience.buyers,
                child: Text('Property Buyers for Sale (~1,240 Users)'),
              ),
              DropdownMenuItem(
                value: TargetAudience.landlords,
                child: Text('Landlords & Property Owners (~380 Owners)'),
              ),
            ],
            onChanged: (val) => setState(() => _selectedAudience = val ?? TargetAudience.allUsers),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F232E) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Iconsax.link_21, size: 18, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 8),
                    Text(
                      'Action on Click (Deep-Link Destination):',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<NotificationActionType>(
                  value: _selectedActionType,
                  dropdownColor: isDark ? const Color(0xFF1F232E) : Colors.white,
                  style: GoogleFonts.inter(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark ? const Color(0xFF161922) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: NotificationActionType.property,
                      child: Text('Open Specific Property Details (Deep-Link to Listing)'),
                    ),
                    DropdownMenuItem(
                      value: NotificationActionType.category,
                      child: Text('Open Specific Locality / Category Filter'),
                    ),
                    DropdownMenuItem(
                      value: NotificationActionType.postProperty,
                      child: Text('Open Post Property Screen (Encourage Listing)'),
                    ),
                    DropdownMenuItem(
                      value: NotificationActionType.buyAndSell,
                      child: Text('Open Buy & Sell Hub'),
                    ),
                    DropdownMenuItem(
                      value: NotificationActionType.general,
                      child: Text('Open App Home Feed'),
                    ),
                  ],
                  onChanged: (val) => setState(() => _selectedActionType = val ?? NotificationActionType.property),
                ),
                const SizedBox(height: 12),

                if (_selectedActionType == NotificationActionType.property && _properties.isNotEmpty) ...[
                  Text(
                    'Select Target Listing to Open:',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFF59E0B)),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedPropertyId ?? _properties.first.id,
                    dropdownColor: isDark ? const Color(0xFF1F232E) : Colors.white,
                    style: GoogleFonts.inter(color: isDark ? Colors.white : Colors.black87, fontSize: 12.5),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF161922) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: _properties.take(20).map((prop) {
                      final propId = prop.id ?? '';
                      return DropdownMenuItem<String>(
                        value: propId,
                        child: Text(
                          '${prop.title} (₹${prop.price} - ${prop.locationStr.split(',').first})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedPropertyId = val),
                  ),
                ],

                if (_selectedActionType == NotificationActionType.category ||
                    _selectedActionType == NotificationActionType.searchFilter) ...[
                  Text(
                    'Select Target Locality in Rajahmundry:',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFF59E0B)),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedCategoryOrLocality ?? 'Danavaipeta',
                    dropdownColor: isDark ? const Color(0xFF1F232E) : Colors.white,
                    style: GoogleFonts.inter(color: isDark ? Colors.white : Colors.black87, fontSize: 12.5),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF161922) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: _rajahmundryLocalities.map((loc) {
                      return DropdownMenuItem<String>(value: loc, child: Text(loc));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedCategoryOrLocality = val),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSendingNotification ? null : _sendPushNotificationBroadcast,
              icon: _isSendingNotification
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Iconsax.send_1, size: 20),
              label: Text(
                _isSendingNotification ? 'Broadcasting to Users...' : 'Blast Push Notification Now',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.black,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplatePill(String template, bool isDark) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        setState(() {
          _notifTitleController.text = template;
          if (template.contains('Price Drop')) {
            _notifBodyController.text = 'Price reduced by ₹2,000/mo on verified Danavaipeta flat. Call owner directly.';
          } else if (template.contains('New 2BHK')) {
            _notifBodyController.text = 'Brand new East-facing 2BHK flat available for immediate move-in. Zero brokerage.';
          } else {
            _notifBodyController.text = 'Post your property in Rajahmundry today and connect with 5,000+ verified tenants for free.';
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F232E) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
        ),
        child: Text(
          template,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationLiveMockupAndHistory(bool isDark) {
    final title = _notifTitleController.text.isEmpty ? 'Notification Title' : _notifTitleController.text;
    final body = _notifBodyController.text.isEmpty ? 'Message body content goes here...' : _notifBodyController.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161922) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '📱 Live Mobile Phone Preview',
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'REALTIME',
                      style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFF10B981)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '9:41',
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        Row(
                          children: const [
                            Icon(Icons.wifi, color: Colors.white70, size: 12),
                            SizedBox(width: 4),
                            Icon(Icons.battery_full, color: Colors.white70, size: 12),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.asset(
                                  'assets/logo.png',
                                  width: 22,
                                  height: 22,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.home, color: Colors.white, size: 18),
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
                                      'Rental App',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      'now',
                                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 10),
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
                                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 11, height: 1.3),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161922) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent Broadcast History',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 14),
              if (_broadcastHistory.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'No past broadcasts found.',
                      style: GoogleFonts.inter(color: isDark ? Colors.white38 : Colors.grey),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _broadcastHistory.take(5).length,
                  separatorBuilder: (_, __) => const Divider(height: 16),
                  itemBuilder: (context, idx) {
                    final item = _broadcastHistory[idx];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                item.title,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${item.recipientCount} sent',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Target: ${item.actionDisplayName}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF6B7280),
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
  // TAB 5: USERS & LANDLORDS DIRECTORY
  // ==========================================
  Widget _buildUsersTab(bool isDark) {
    final Map<String, List<PropertyModel>> ownerMap = {};
    for (final prop in _properties) {
      if (prop.ownerPhone.isNotEmpty) {
        ownerMap.putIfAbsent(prop.ownerPhone, () => []).add(prop);
      }
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Registered Landlords & Property Owners (${ownerMap.length})',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: ownerMap.length,
              itemBuilder: (context, idx) {
                final phone = ownerMap.keys.elementAt(idx);
                final props = ownerMap[phone]!;
                final ownerName = props.first.title.split('-').first.trim().isNotEmpty
                    ? props.first.title.split('-').first.trim()
                    : 'Property Owner';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161922) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                        child: Text(
                          ownerName.isNotEmpty ? ownerName[0].toUpperCase() : 'O',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF3B82F6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ownerName.isNotEmpty ? ownerName : 'Property Owner',
                              style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              'Phone: $phone • Localities: ${props.map((p) => p.locationStr.split(',').first).toSet().join(', ')}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF10B981), size: 20),
                        tooltip: 'Message Landlord on WhatsApp',
                        onPressed: () => _contactOwnerWhatsApp(phone, props.first.title),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${props.length} Listings',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFF59E0B),
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
      ),
    );
  }

  // ==========================================
  // TAB 6: BANNERS & PROMOTIONS
  // ==========================================
  Widget _buildBannersTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Promotional Banners & In-App Announcements',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161922) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Home Carousel Banner: Zero Brokerage Guaranteed',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 130,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '🏡 100% Direct Owner Listings in Rajahmundry',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Save up to ₹25,000 on broker fees. Directly contact verified homeowners in Danavaipeta, Morampudi & Prakash Nagar.',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.black87),
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
    );
  }

  // ==========================================
  // TAB 7: SETTINGS & CITY CONFIGURATION
  // ==========================================
  Widget _buildSettingsTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rajahmundry Locality & Market Settings',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161922) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Supported Operational Localities (${_rajahmundryLocalities.length})',
                  style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _rajahmundryLocalities.map((loc) {
                    return Chip(
                      label: Text(loc, style: GoogleFonts.inter(fontSize: 12)),
                      backgroundColor: isDark ? const Color(0xFF1F232E) : const Color(0xFFF3F4F6),
                    );
                  }).toList(),
                ),
              ],
            ),
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
                      color: const Color(0xFFF59E0B),
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
