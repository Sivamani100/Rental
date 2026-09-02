import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env.dart';
import 'notification_broadcast_service.dart';

class AutoNotifierSettings {
  final String id;
  final bool isEnabled;
  final List<String> scheduleTimes;
  final String aiInstructions;
  final DateTime? lastDispatchAt;

  AutoNotifierSettings({
    required this.id,
    required this.isEnabled,
    required this.scheduleTimes,
    required this.aiInstructions,
    this.lastDispatchAt,
  });

  factory AutoNotifierSettings.fromJson(Map<String, dynamic> json) {
    List<String> times = ['08:00', '13:00', '18:00'];
    if (json['schedule_times'] != null) {
      times = List<String>.from(json['schedule_times']);
    }

    return AutoNotifierSettings(
      id: json['id']?.toString() ?? '',
      isEnabled: json['is_enabled'] == true,
      scheduleTimes: times,
      aiInstructions: json['ai_instructions']?.toString() ??
          'You are the Growth AI for Rental App. Generate catchy, friendly push notifications encouraging tenants to explore flats, PGs, or post properties in any city or location everywhere. Title max 45 chars with 1-2 emojis. Body max 90 chars with clear call-to-action. Target route must be one of: pg, rental, ai_chat, posting, nearby, search. NEVER link to a specific property ID.',
      lastDispatchAt: json['last_dispatch_at'] != null
          ? DateTime.tryParse(json['last_dispatch_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'is_enabled': isEnabled,
      'schedule_times': scheduleTimes,
      'ai_instructions': aiInstructions,
      'last_dispatch_at': lastDispatchAt?.toIso8601String(),
    };
  }
}

class AiAutoNotifierService {
  AiAutoNotifierService._();
  static final AiAutoNotifierService instance = AiAutoNotifierService._();

  final _supabase = Supabase.instance.client;
  AutoNotifierSettings? _currentSettings;
  Timer? _schedulerTimer;

  AutoNotifierSettings? get currentSettings => _currentSettings;

  /// Starts periodic background checker for 8:00 AM, 1:00 PM & 6:00 PM IST dispatches
  void startPeriodicSchedulerTimer() {
    _schedulerTimer?.cancel();
    _schedulerTimer = Timer.periodic(const Duration(minutes: 15), (_) async {
      await _checkAndTriggerScheduledDispatch();
    });
    _checkAndTriggerScheduledDispatch();
  }

  Future<void> _checkAndTriggerScheduledDispatch() async {
    try {
      final settings = await fetchSettings();
      if (settings == null || !settings.isEnabled) return;

      // Current time in IST (Asia/Kolkata = UTC + 5:30)
      final nowUtc = DateTime.now().toUtc();
      final nowIst = nowUtc.add(const Duration(hours: 5, minutes: 30));

      final currentHour = nowIst.hour; // 8 for 8 AM, 13 for 1 PM, 18 for 6 PM
      final isScheduledSlot = currentHour == 8 || currentHour == 13 || currentHour == 18;

      if (!isScheduledSlot) return;

      // Check if last dispatch was already sent during this same hour today
      if (settings.lastDispatchAt != null) {
        final lastDispatchIst = settings.lastDispatchAt!.toUtc().add(const Duration(hours: 5, minutes: 30));
        if (lastDispatchIst.year == nowIst.year &&
            lastDispatchIst.month == nowIst.month &&
            lastDispatchIst.day == nowIst.day &&
            lastDispatchIst.hour == currentHour) {
          return;
        }
      }

      debugPrint('⏰ Automated AI Notification Schedule Triggered for ${nowIst.hour}:00 IST!');
      await dispatchPersonalizedMultiSegmentNotifications();
    } catch (e) {
      debugPrint('Error in scheduled notification trigger: $e');
    }
  }

  /// Fetches current settings from Supabase database table `auto_notification_settings`
  Future<AutoNotifierSettings?> fetchSettings() async {
    try {
      final response = await _supabase
          .from('auto_notification_settings')
          .select()
          .limit(1)
          .maybeSingle();

      if (response != null) {
        _currentSettings = AutoNotifierSettings.fromJson(response);
        return _currentSettings;
      }
    } catch (e) {
      debugPrint('Error fetching auto notification settings: $e');
    }
    return _currentSettings;
  }

  /// Updates toggle switch state or AI instruction prompt guidelines
  Future<bool> updateSettings({bool? isEnabled, String? aiInstructions}) async {
    try {
      if (_currentSettings == null) await fetchSettings();

      final Map<String, dynamic> updateData = {
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (isEnabled != null) updateData['is_enabled'] = isEnabled;
      if (aiInstructions != null) updateData['ai_instructions'] = aiInstructions;

      if (_currentSettings != null && _currentSettings!.id.isNotEmpty) {
        await _supabase
            .from('auto_notification_settings')
            .update(updateData)
            .eq('id', _currentSettings!.id);
      } else {
        await _supabase.from('auto_notification_settings').insert(updateData);
      }

      await fetchSettings();
      return true;
    } catch (e) {
      debugPrint('Error updating auto notification settings: $e');
      return false;
    }
  }

  /// Uses AI (OpenRouter) to dynamically generate content for notification
  Future<Map<String, String>?> generateAiNotification({
    String? customPrompt,
    TargetAudience targetAudience = TargetAudience.allUsers,
  }) async {
    final apiKey = Env.openRouterApiKey;
    if (apiKey.isEmpty) {
      debugPrint('OpenRouter API key is empty');
      return null;
    }

    final instructions = customPrompt ??
        _currentSettings?.aiInstructions ??
        'You are the Growth AI for Rental App. Generate catchy, friendly push notifications encouraging tenants to explore flats, PGs, or post properties in any city or location everywhere. Title max 45 chars with 1-2 emojis. Body max 90 chars with clear call-to-action. Target route must be one of: pg, rental, ai_chat, posting, nearby, search. NEVER link to a specific property ID.';

    String audienceContext = 'Target Audience: All App Users.';
    if (targetAudience == TargetAudience.pgSeekers) {
      audienceContext = 'Target Audience: PG & Hostel Seekers looking for student rooms, co-living, or hostels with food.';
    } else if (targetAudience == TargetAudience.roomSeekers) {
      audienceContext = 'Target Audience: Room & Flat Seekers looking for 1BHK/2BHK/3BHK zero-brokerage apartments.';
    } else if (targetAudience == TargetAudience.buyers) {
      audienceContext = 'Target Audience: Property Buyers & Commercial Space Seekers.';
    }

    const systemPrompt = '''
You are the dedicated Notification Content Generator AI for "Rental App" — a universal 100% zero-brokerage rental, flat, house, and hostel/PG discovery platform for users everywhere in any city or location.

STRICT CONSTRAINTS & RULES:
1. TITLE: Max 45 characters. Must contain 1-2 relevant emojis (e.g. 🏡, 🔑, 🎓, ⚡).
2. BODY: Max 90 characters. Clear, urgent, non-spammy call-to-action tailored to the target audience.
3. TARGET ROUTE: Must be strictly one of these approved generic routes:
   - "pg": For hostel & student room search prompts.
   - "rental": For 2BHK/3BHK zero-brokerage flat search prompts.
   - "ai_chat": For asking the AI assistant to find homes.
   - "posting": For encouraging landlords to list properties.
   - "nearby": For discovering properties nearby.
   - "search": For general property search & filters.
4. NEVER include any specific property ID or individual listing link!
5. OUTPUT FORMAT: Respond strictly with valid JSON only in this format:
{"title": "...", "body": "...", "target_route": "..."}
''';

    final userPrompt = '''
Guidelines: $instructions

$audienceContext

Current Local Time Context: ${DateTime.now().toLocal().toString()}
Generate 1 fresh, highly engaging, personalized notification title, body, and target route now.
''';

    try {
      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'HTTP-Referer': 'https://rental.arkio.in',
          'X-Title': 'Rental Rajahmundry Notification AI',
        },
        body: jsonEncode({
          'model': 'openrouter/free',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'temperature': 0.8,
          'response_format': {'type': 'json_object'},
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final content = decoded['choices']?[0]?['message']?['content']?.toString() ?? '';
        final cleanJson = content.replaceAll(RegExp(r'```json|```'), '').trim();
        final Map<String, dynamic> jsonResult = jsonDecode(cleanJson);

        final title = jsonResult['title']?.toString() ?? '🏡 Find Verified Homes Near You!';
        final body = jsonResult['body']?.toString() ?? 'Browse 100% zero-brokerage flats and PGs today on Rental.';
        final route = jsonResult['target_route']?.toString() ?? 'search';

        return {
          'title': title,
          'body': body,
          'target_route': route,
        };
      }
    } catch (e) {
      debugPrint('Error generating AI notification: $e');
    }

    // Fallback template based on audience
    if (targetAudience == TargetAudience.pgSeekers) {
      return {
        'title': '🎓 Looking for a Verified PG or Hostel?',
        'body': 'Discover student-friendly PGs with home food and 0 broker fee!',
        'target_route': 'pg',
      };
    } else if (targetAudience == TargetAudience.roomSeekers) {
      return {
        'title': '🏡 Spacious 1/2/3 BHK Flats Available!',
        'body': 'Contact direct owners directly with zero brokerage fee today.',
        'target_route': 'rental',
      };
    }

    return {
      'title': '⚡ Still Searching for a Flat or PG?',
      'body': 'Discover 100% direct owner listings with 0 broker fee near your location!',
      'target_route': 'rental',
    };
  }

  /// Dispatches the notification by inserting it into broadcast_notifications
  /// which triggers Supabase Webhook & FCM push delivery automatically to the targeted audience segment.
  Future<bool> dispatchAutoNotification({
    required String title,
    required String body,
    required String targetRoute,
    TargetAudience targetAudience = TargetAudience.allUsers,
  }) async {
    try {
      NotificationActionType actionType = NotificationActionType.general;
      if (targetRoute == 'postProperty' || targetRoute == 'posting') {
        actionType = NotificationActionType.postProperty;
      } else if (targetRoute == 'category' || targetRoute == 'pg' || targetRoute == 'rental') {
        actionType = NotificationActionType.category;
      } else if (targetRoute == 'searchFilter' || targetRoute == 'search' || targetRoute == 'nearby') {
        actionType = NotificationActionType.searchFilter;
      }

      final notif = BroadcastNotificationModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        body: body,
        targetAudience: targetAudience,
        actionType: actionType,
        targetRouteOrId: targetRoute,
        targetLabel: targetRoute.toUpperCase(),
        isHighPriority: true,
        createdAt: DateTime.now(),
        status: 'sent',
      );

      final success = await NotificationBroadcastService.instance.sendBroadcast(notif);

      // Record dispatch timestamp in auto_notification_settings
      if (_currentSettings != null && _currentSettings!.id.isNotEmpty) {
        await _supabase.from('auto_notification_settings').update({
          'last_dispatch_at': DateTime.now().toIso8601String(),
        }).eq('id', _currentSettings!.id);
      }

      return success;
    } catch (e) {
      debugPrint('Error dispatching auto notification: $e');
      return false;
    }
  }

  /// Dispatches smart personalized AI notifications to each segregated audience group
  Future<Map<String, bool>> dispatchPersonalizedMultiSegmentNotifications() async {
    final Map<String, bool> results = {};

    final audiences = [
      TargetAudience.pgSeekers,
      TargetAudience.roomSeekers,
      TargetAudience.buyers,
    ];

    for (final audience in audiences) {
      final content = await generateAiNotification(targetAudience: audience);
      if (content != null) {
        final success = await dispatchAutoNotification(
          title: content['title']!,
          body: content['body']!,
          targetRoute: content['target_route']!,
          targetAudience: audience,
        );
        results[audience.name] = success;
      } else {
        results[audience.name] = false;
      }
    }

    return results;
  }
}
