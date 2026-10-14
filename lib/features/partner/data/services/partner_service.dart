import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:rental/core/models/property_model.dart';
import 'package:rental/features/partner/data/models/partner_handover_request.dart';

class AuthResult {
  final bool success;
  final String? errorMessage;
  const AuthResult({required this.success, this.errorMessage});

  factory AuthResult.ok() => const AuthResult(success: true);
  factory AuthResult.fail(String message) => AuthResult(success: false, errorMessage: message);
}

class PartnerService extends ChangeNotifier {
  static final PartnerService instance = PartnerService._internal();
  PartnerService._internal();

  final _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  PartnerProfile? _currentPartner;
  PartnerProfile? get currentPartner => _currentPartner;
  bool get isLoggedIn => _currentPartner != null;

  bool _hasCompletedOnboarding = true;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;

  List<PropertyModel> _myProperties = [];
  List<PropertyModel> get myProperties => _myProperties;

  List<PartnerHandoverRequest> _myRequests = [];
  List<PartnerHandoverRequest> get myRequests => _myRequests;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _hasCompletedOnboarding = true;

    final partnerJson = prefs.getString('current_partner_profile');
    if (partnerJson != null) {
      try {
        _currentPartner = PartnerProfile.fromJson(jsonDecode(partnerJson));
        await fetchMyProperties();
        await fetchMyRequests();
      } catch (e) {
        debugPrint('Error restoring partner profile: $e');
      }
    }
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _hasCompletedOnboarding = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('partner_onboarding_completed', true);
    notifyListeners();
  }

  /// Sign Up with Email, Password & Role (No phone number required)
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String role,
  }) async {
    _isLoading = true;
    notifyListeners();

    final cleanEmail = email.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    final accounts = _loadLocalAccounts(prefs);

    // 1. Check if email already registered locally
    if (accounts.containsKey(cleanEmail)) {
      _isLoading = false;
      notifyListeners();
      return AuthResult.fail('An account with this email already exists. Please sign in instead.');
    }

    String partnerId = 'partner_${cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';

    // 2. Try Supabase Auth sign up
    try {
      final res = await _supabase.auth.signUp(
        email: cleanEmail,
        password: password,
      );
      if (res.user != null) {
        partnerId = res.user!.id;
      }
    } catch (e) {
      debugPrint('Supabase auth sign up note: $e');
    }

    // 3. Create persistent profile
    final profile = PartnerProfile(
      id: partnerId,
      name: cleanEmail.split('@').first,
      email: cleanEmail,
      phone: '',
      role: role,
      createdAt: DateTime.now(),
    );

    // 4. Save to registered accounts registry
    accounts[cleanEmail] = {
      'id': partnerId,
      'email': cleanEmail,
      'password': password,
      'role': role,
      'name': profile.name,
      'created_at': DateTime.now().toIso8601String(),
    };
    await prefs.setString('partner_accounts_db', jsonEncode(accounts));

    // 5. Save active session
    _currentPartner = profile;
    await prefs.setString('current_partner_profile', jsonEncode(profile.toJson()));
    await prefs.setBool('partner_onboarding_completed', true);
    _hasCompletedOnboarding = true;

    _isLoading = false;
    notifyListeners();

    await fetchMyProperties();
    await fetchMyRequests();
    return AuthResult.ok();
  }

  /// Sign In with Email & Password (No phone number required)
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    final cleanEmail = email.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    final accounts = _loadLocalAccounts(prefs);

    // 1. Check local registered accounts
    if (accounts.containsKey(cleanEmail)) {
      final record = accounts[cleanEmail] as Map<String, dynamic>;
      final savedPass = record['password']?.toString() ?? '';

      if (savedPass != password) {
        _isLoading = false;
        notifyListeners();
        return AuthResult.fail('Incorrect password. Please try again.');
      }

      final profile = PartnerProfile(
        id: record['id']?.toString() ?? 'partner_${cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}',
        name: record['name']?.toString() ?? cleanEmail.split('@').first,
        email: cleanEmail,
        phone: record['phone']?.toString() ?? '',
        role: record['role']?.toString() ?? 'Direct Property Owner',
        createdAt: DateTime.tryParse(record['created_at']?.toString() ?? '') ?? DateTime.now(),
      );

      _currentPartner = profile;
      await prefs.setString('current_partner_profile', jsonEncode(profile.toJson()));
      await prefs.setBool('partner_onboarding_completed', true);
      _hasCompletedOnboarding = true;

      _isLoading = false;
      notifyListeners();

      await fetchMyProperties();
      await fetchMyRequests();
      return AuthResult.ok();
    }

    // 2. Try Supabase Auth sign in
    try {
      final authRes = await _supabase.auth.signInWithPassword(
        email: cleanEmail,
        password: password,
      );

      if (authRes.user != null) {
        final profile = PartnerProfile(
          id: authRes.user!.id,
          name: cleanEmail.split('@').first,
          email: cleanEmail,
          phone: '',
          role: 'Direct Property Owner',
          createdAt: DateTime.now(),
        );

        // Store into local accounts
        accounts[cleanEmail] = {
          'id': authRes.user!.id,
          'email': cleanEmail,
          'password': password,
          'role': profile.role,
          'name': profile.name,
          'created_at': DateTime.now().toIso8601String(),
        };
        await prefs.setString('partner_accounts_db', jsonEncode(accounts));

        _currentPartner = profile;
        await prefs.setString('current_partner_profile', jsonEncode(profile.toJson()));
        await prefs.setBool('partner_onboarding_completed', true);
        _hasCompletedOnboarding = true;

        _isLoading = false;
        notifyListeners();

        await fetchMyProperties();
        await fetchMyRequests();
        return AuthResult.ok();
      }
    } catch (e) {
      debugPrint('Supabase signInWithPassword note: $e');
    }

    _isLoading = false;
    notifyListeners();
    return AuthResult.fail('No partner account found for "$cleanEmail". Please create an account.');
  }

  Map<String, dynamic> _loadLocalAccounts(SharedPreferences prefs) {
    final str = prefs.getString('partner_accounts_db');
    if (str != null) {
      try {
        return Map<String, dynamic>.from(jsonDecode(str));
      } catch (_) {}
    }
    return {};
  }

  Future<void> logout() async {
    _currentPartner = null;
    _myProperties.clear();
    _myRequests.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_partner_profile');
    try {
      await _supabase.auth.signOut();
    } catch (_) {}
    notifyListeners();
  }

  /// Real Fetch: queries all properties and finds those belonging to current partner
  Future<void> fetchMyProperties() async {
    if (_currentPartner == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final partnerEmail = _currentPartner!.email.toLowerCase().trim();
      final partnerId = _currentPartner!.id;

      // Query real properties directly from Supabase
      final res = await _supabase
          .from('properties')
          .select()
          .order('created_at', ascending: false);

      final List<PropertyModel> list = [];
      for (var row in (res as List)) {
        final p = PropertyModel.fromJson(Map<String, dynamic>.from(row));

        // 1. Tag match (e.g. partner:owner@gmail.com or partner_id:...)
        final hasPartnerTag = p.tags.any((t) {
          final low = t.toLowerCase().trim();
          return low == 'partner:$partnerEmail' ||
              low.startsWith('partner:$partnerEmail') ||
              low == 'partner_id:$partnerId';
        });

        // 2. Direct partner email or ID match
        final hasEmailMatch = p.partnerEmail != null &&
            p.partnerEmail!.toLowerCase().trim() == partnerEmail;
        final hasIdMatch = p.partnerId != null && p.partnerId == partnerId;

        // 3. Owner phone is partner email (fallback)
        final hasPhoneMatch = p.ownerPhone.toLowerCase().trim() == partnerEmail;

        if (hasPartnerTag || hasEmailMatch || hasIdMatch || hasPhoneMatch) {
          list.add(p);
        }
      }

      _myProperties = list;
    } catch (e) {
      debugPrint('Error fetching partner properties: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Real Live Availability Toggle (calls Supabase toggle_availability SECURITY DEFINER function)
  Future<bool> toggleAvailability(PropertyModel property) async {
    if (property.id == null) return false;
    final newStatus = !property.isAvailable;
    property.isAvailable = newStatus;
    notifyListeners();

    try {
      await _supabase.rpc('toggle_availability', params: {
        'p_property_id': property.id,
        'p_is_available': newStatus,
      });

      // Clear local property cache so home and search reflect the new state immediately
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_properties');
      await prefs.remove('cached_properties_ts');

      return true;
    } catch (e) {
      debugPrint('Error toggling availability via RPC: $e');
      try {
        await _supabase
            .from('properties')
            .update({'is_available': newStatus})
            .eq('id', property.id!);
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('cached_properties');
        await prefs.remove('cached_properties_ts');
        return true;
      } catch (fallbackErr) {
        debugPrint('Fallback direct update error: $fallbackErr');
        property.isAvailable = !newStatus; // rollback
        notifyListeners();
        return false;
      }
    }
  }

  /// Real Live Details Update (calls Supabase update_property_listing SECURITY DEFINER function)
  Future<bool> updatePropertyDetails({
    required String propertyId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      try {
        await _supabase.rpc('update_property_listing', params: {
          'p_property_id': propertyId,
          'p_data': updates,
        });
      } catch (rpcErr) {
        debugPrint('update_property_listing RPC error: $rpcErr, falling back to direct update');
        await _supabase.from('properties').update(updates).eq('id', propertyId);
      }

      // Clear local property cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_properties');
      await prefs.remove('cached_properties_ts');

      await fetchMyProperties();
      return true;
    } catch (e) {
      debugPrint('Error updating property: $e');
      return false;
    }
  }

  /// Real Handover / Claim Submission (writes to listing_reports for admin review)
  Future<bool> submitHandoverRequest({
    required PropertyModel property,
    required String role,
    required String note,
  }) async {
    if (_currentPartner == null) return false;

    try {
      final cleanEmail = _currentPartner!.email.toLowerCase().trim();
      final localReqId = _uuid.v4();

      final request = PartnerHandoverRequest(
        id: localReqId,
        partnerId: _currentPartner!.id,
        partnerName: _currentPartner!.name,
        partnerEmail: cleanEmail,
        partnerPhone: _currentPartner!.phone,
        propertyId: property.id ?? '',
        propertyTitle: property.title,
        propertyLocation: property.locationStr,
        propertyImage: property.imageUrls.isNotEmpty ? property.imageUrls.first : null,
        role: role,
        note: note,
        status: 'pending',
        createdAt: DateTime.now(),
      );

      _myRequests.insert(0, request);
      notifyListeners();
      await _saveLocalRequests();

      // Real Submission: push report notification to admin in Supabase listing_reports
      try {
        final Map<String, dynamic> commentsPayload = {
          'partner_id': _currentPartner!.id,
          'partner_name': _currentPartner!.name,
          'partner_email': cleanEmail,
          'partner_phone': _currentPartner!.phone,
          'role': role,
          'note': note,
          'request_id': localReqId,
          'property_title': property.title,
          'property_image': property.imageUrls.isNotEmpty ? property.imageUrls.first : '',
          'property_location': property.locationStr,
        };

        final insertRes = await _supabase.from('listing_reports').insert({
          'property_id': property.id ?? '',
          'property_title': property.title,
          'property_type': property.type,
          'owner_phone': property.ownerPhone.isNotEmpty ? property.ownerPhone : _currentPartner!.phone,
          'reason': 'PARTNER_HANDOVER_REQUEST: $role',
          'comments': jsonEncode(commentsPayload),
          'reporter_device_id': 'partner_$cleanEmail',
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        }).select();

        if (insertRes.isNotEmpty && insertRes.first['id'] != null) {
          final liveId = insertRes.first['id'].toString();
          final idx = _myRequests.indexWhere((r) => r.id == localReqId);
          if (idx != -1) {
            _myRequests[idx] = PartnerHandoverRequest(
              id: liveId,
              partnerId: request.partnerId,
              partnerName: request.partnerName,
              partnerEmail: request.partnerEmail,
              partnerPhone: request.partnerPhone,
              propertyId: request.propertyId,
              propertyTitle: request.propertyTitle,
              propertyLocation: request.propertyLocation,
              propertyImage: request.propertyImage,
              role: request.role,
              note: request.note,
              status: 'pending',
              createdAt: request.createdAt,
            );
            await _saveLocalRequests();
            notifyListeners();
          }
        }
      } catch (e2) {
        debugPrint('listing_reports insert note: $e2');
      }

      return true;
    } catch (e) {
      debugPrint('Error submitting handover request: $e');
      return false;
    }
  }

  /// Real Live Requests Sync from Supabase
  Future<void> fetchMyRequests() async {
    if (_currentPartner == null) return;
    await _loadLocalRequests();

    try {
      final partnerEmail = _currentPartner!.email.toLowerCase().trim();
      final partnerId = _currentPartner!.id;

      final res = await _supabase
          .from('listing_reports')
          .select()
          .like('reason', 'PARTNER_HANDOVER_REQUEST%')
          .order('created_at', ascending: false);

      final List<PartnerHandoverRequest> liveRequests = [];
      for (var row in (res as List)) {
        Map<String, dynamic> meta = {};
        try {
          final rawComments = row['comments']?.toString() ?? '{}';
          if (rawComments.trim().startsWith('{')) {
            meta = jsonDecode(rawComments);
          }
        } catch (_) {}

        final repDev = (row['reporter_device_id'] ?? '').toString().toLowerCase().trim();
        final metaEmail = (meta['partner_email'] ?? '').toString().toLowerCase().trim();
        final metaId = (meta['partner_id'] ?? '').toString();

        final isMyRequest = repDev == 'partner_$partnerEmail' ||
            metaEmail == partnerEmail ||
            (metaId.isNotEmpty && metaId == partnerId);

        if (isMyRequest) {
          final role = meta['role']?.toString() ??
              row['reason']?.toString().replaceFirst('PARTNER_HANDOVER_REQUEST:', '').trim() ??
              'Direct Property Owner';
          final note = meta['note']?.toString() ?? '';
          final title = meta['property_title']?.toString() ??
              row['property_title']?.toString() ??
              'Property Listing';
          final img = meta['property_image']?.toString();
          final loc = meta['property_location']?.toString();
          final status = (row['status'] ?? 'pending').toString().toLowerCase();

          liveRequests.add(PartnerHandoverRequest(
            id: row['id']?.toString() ?? meta['request_id']?.toString() ?? _uuid.v4(),
            partnerId: partnerId,
            partnerName: meta['partner_name']?.toString() ?? _currentPartner!.name,
            partnerEmail: partnerEmail,
            partnerPhone: meta['partner_phone']?.toString() ?? _currentPartner!.phone,
            propertyId: row['property_id']?.toString() ?? '',
            propertyTitle: title,
            propertyLocation: loc,
            propertyImage: img,
            role: role,
            note: note,
            status: status,
            createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
          ));
        }
      }

      if (liveRequests.isNotEmpty) {
        _myRequests = liveRequests;
        await _saveLocalRequests();
        notifyListeners();

        // If any request has been approved, re-fetch properties to show the claimed listing!
        if (_myRequests.any((r) => r.status.toLowerCase() == 'approved')) {
          await fetchMyProperties();
        }
      }
    } catch (e) {
      debugPrint('Error syncing live partner requests: $e');
    }
  }

  Future<void> _saveLocalRequests() async {
    if (_currentPartner == null) return;
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _myRequests.map((r) => r.toJson()).toList();
    await prefs.setString('partner_handover_requests_${_currentPartner!.email}', jsonEncode(jsonList));
  }

  Future<void> _loadLocalRequests() async {
    if (_currentPartner == null) return;
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('partner_handover_requests_${_currentPartner!.email}');
    if (str != null) {
      final list = jsonDecode(str) as List;
      _myRequests = list
          .map((r) => PartnerHandoverRequest.fromJson(Map<String, dynamic>.from(r)))
          .toList();
      notifyListeners();
    }
  }
}

