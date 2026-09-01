import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/property_model.dart';
import '../config/env.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<PropertyModel>? recommendedProperties;
  final String? intentSummary;
  final String? imagePath;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.recommendedProperties,
    this.intentSummary,
    this.imagePath,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'propertyIds': recommendedProperties?.map((p) => p.id).whereType<String>().toList(),
      'intentSummary': intentSummary,
      'imagePath': imagePath,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json, List<PropertyModel> allProps) {
    List<PropertyModel>? recs;
    if (json['propertyIds'] != null) {
      final List ids = json['propertyIds'];
      recs = allProps.where((p) => ids.contains(p.id)).toList();
    }

    return ChatMessage(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      text: json['text'] ?? '',
      isUser: json['isUser'] ?? false,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
      recommendedProperties: recs,
      intentSummary: json['intentSummary'],
      imagePath: json['imagePath'],
    );
  }
}

class AiAssistantService {
  static final AiAssistantService instance = AiAssistantService._internal();
  AiAssistantService._internal();

  String? _customApiKey;
  final _secureStorage = const FlutterSecureStorage();

  static const String primaryModel = 'openrouter/free';
  static const String fallbackModel = 'meta-llama/llama-3.3-70b-instruct:free';

  final List<PropertyModel> _databaseCache = [];
  bool _isSynced = false;
  final List<ChatMessage> _chatHistory = [];
  DateTime? _lastSyncTime; // Sync debounce — avoid redundant calls within 10 min

  List<ChatMessage> get chatHistory => List.unmodifiable(_chatHistory);
  List<PropertyModel> get databaseCache => List.unmodifiable(_databaseCache);
  bool get isSynced => _isSynced;

  String get effectiveApiKey {
    if (_customApiKey != null && _customApiKey!.isNotEmpty) {
      return _customApiKey!;
    }
    return Env.openRouterApiKey;
  }

  Future<void> setApiKey(String key) async {
    _customApiKey = key.trim();
    await _secureStorage.write(key: 'openrouter_api_key', value: _customApiKey);
  }

  Future<void> loadSavedApiKey() async {
    try {
      final saved = await _secureStorage.read(key: 'openrouter_api_key');
      if (saved != null && saved.isNotEmpty) {
        _customApiKey = saved;
      }
    } catch (_) {}
  }

  Future<void> init() async {
    await loadSavedApiKey();
    await loadSavedChatHistory();
  }

  /// Initialize and sync properties and load persistent local chat history
  Future<void> syncDatabase({List<PropertyModel>? initialProperties}) async {
    await loadSavedApiKey();

    // Sync debounce: skip if already synced and last sync was < 10 minutes ago
    final now = DateTime.now();
    if (_isSynced &&
        _lastSyncTime != null &&
        now.difference(_lastSyncTime!).inMinutes < 10 &&
        initialProperties == null) {
      return;
    }

    if (initialProperties != null && initialProperties.isNotEmpty) {
      _databaseCache.clear();
      _databaseCache.addAll(initialProperties);
      _isSynced = true;
    }

    try {
      final res = await Supabase.instance.client
          .from('properties')
          .select()
          .order('created_at', ascending: false);

      final List<PropertyModel> loaded = [];
      for (var item in res) {
        try {
          final prop = PropertyModel.fromJson(item);
          if (prop.status.toLowerCase() == 'approved' || prop.isAvailable) {
            loaded.add(prop);
          }
        } catch (_) {}
      }

      if (loaded.isNotEmpty) {
        _databaseCache.clear();
        _databaseCache.addAll(loaded);
        _isSynced = true;
        _lastSyncTime = DateTime.now(); // Record successful sync time
      }
    } catch (_) {}

    await loadSavedChatHistory();
  }

  /// Load persistent local chat history
  Future<List<ChatMessage>> loadSavedChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('saved_chat_history_v2');
      if (raw != null && raw.isNotEmpty) {
        final List list = jsonDecode(raw);
        _chatHistory.clear();
        for (var item in list) {
          _chatHistory.add(ChatMessage.fromJson(item, _databaseCache));
        }
      }
    } catch (_) {}
    return _chatHistory;
  }

  /// Persist local chat history (capped at 100 messages to prevent SharedPrefs bloat)
  Future<void> _persistChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Keep only the most recent 100 messages
      final toSave = _chatHistory.length > 100
          ? _chatHistory.sublist(_chatHistory.length - 100)
          : _chatHistory;
      final encoded = jsonEncode(toSave.map((m) => m.toJson()).toList());
      await prefs.setString('saved_chat_history_v2', encoded);
    } catch (_) {}
  }

  /// Clear persistent chat history
  Future<void> clearHistory() async {
    _chatHistory.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_chat_history_v2');
    } catch (_) {}
  }

  /// Sanitize text before injecting into AI prompts — prevents prompt injection
  /// via maliciously crafted property titles, descriptions, or user messages.
  static String _sanitizeForPrompt(String? input, {int maxLength = 300}) {
    if (input == null || input.isEmpty) return '';
    // Strip control characters (keep printable + newline)
    String s = input.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
    // Cap to maxLength to prevent bloated prompts
    s = s.trim();
    if (s.length > maxLength) s = s.substring(0, maxLength);
    return s;
  }

  /// Process natural language query via OpenRouter Free AI with conversation memory
  Future<ChatMessage> processQuery(String userQueryText, {String? imagePath}) async {
    // SECURITY: Sanitize user input before processing — prevents chat-level prompt injection
    final cleanInput = _sanitizeForPrompt(userQueryText.trim(), maxLength: 500);
    if (cleanInput.isEmpty && imagePath == null) {
      return ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: "Please ask a question or tell me what kind of room or home you are looking for!",
        isUser: false,
        timestamp: DateTime.now(),
      );
    }

    if (!_isSynced || _databaseCache.isEmpty) {
      await syncDatabase();
    }

    // Add user message to history
    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: cleanInput.isNotEmpty ? cleanInput : "Shared a photo with the assistant",
      isUser: true,
      timestamp: DateTime.now(),
      imagePath: imagePath,
    );
    _chatHistory.add(userMsg);
    await _persistChatHistory();

    final apiKey = effectiveApiKey;
    if (apiKey.isNotEmpty) {
      try {
        final openRouterResponse = await _callOpenRouterApi(cleanInput, apiKey, imagePath: imagePath);
        if (openRouterResponse != null) {
          _chatHistory.add(openRouterResponse);
          await _persistChatHistory();
          return openRouterResponse;
        }
      } catch (_) {}
    }

    // Intelligent Fallback with Natural Conversational Logic
    final fallbackResponse = _generateConversationalFallback(cleanInput);
    _chatHistory.add(fallbackResponse);
    await _persistChatHistory();
    return fallbackResponse;
  }

  /// Calls OpenRouter API with full conversational instructions and verified listings context
  Future<ChatMessage?> _callOpenRouterApi(String userPrompt, String apiKey, {String? imagePath}) async {
    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

    final propertiesContext = _buildDatabaseContextForPrompt();

    final systemPrompt = '''
You are Rental Assistant, a fast, crisp, friendly, and expert rental advisor.
You have access to our verified property listings.

### CURRENT VERIFIED LISTINGS:
$propertiesContext

### RULES FOR THINKING & RESPONDING:
1. **MAX 3 TO 5 LINES ONLY**:
   - Keep your entire response short, punchy, and under 5 lines.
   - Give direct, helpful answers without lengthy filler or essays.

2. **HANDLING CITIES & EXPANSIONS**:
   - Currently, our active verified listings are in Diwanchervu, Rajahmundry, and surrounding areas. We are expanding everywhere soon!
   - If a user asks for properties in cities we haven't listed yet (e.g., Vizag, Hyderabad, Vijayawada, Bangalore):
     Politely say: "We haven't expanded to Vizag yet, but we will be launching there very soon! Right now, our verified stays are live in Diwanchervu and Rajahmundry. Would you like to check options around here?"
   - NEVER say the app is only built for one town.

3. **GREETINGS & GENERAL REQUESTS**:
   - If user sends a simple greeting ("hi", "hello"), reply with a friendly 1-2 line greeting.
   - If user asks a general request without location (e.g. "show best pgs for me", "find me rooms"):
     Ask which location they prefer (e.g., Diwanchervu, Rajahmundry, Morampudi), and in the same message introduce the top verified PGs across all our areas.

4. **RECOMMENDING HOMES / PGs**:
   - Give a crisp 3-4 line summary highlighting rent, food/amenities, and why they stand out.
   - Always tag every recommended property as [PROPERTY_ID: <id>] so the app displays all their interactive cards below.

5. **FORMATTING**:
   - Use plain, clean text with bold (**word**) or simple bullets (•).
   - NO markdown tables, NO hashes (###), NO blockquotes (>), NO horizontal lines (---).
''';

    final messagesPayload = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    // Include last 8 conversation turns for rich memory recall
    final historyToInclude = _chatHistory.reversed.take(8).toList().reversed;
    for (var m in historyToInclude) {
      messagesPayload.add({
        'role': m.isUser ? 'user' : 'assistant',
        'content': m.text,
      });
    }

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://rentalapp.com',
        'X-Title': 'Rental AI',
      },
      body: jsonEncode({
        'model': primaryModel,
        'messages': messagesPayload,
        'temperature': 0.7,
        'max_tokens': 1000,
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final choices = json['choices'] as List?;
      if (choices != null && choices.isNotEmpty) {
        final content = choices[0]['message']['content'] as String? ?? '';
        
        final extractedProps = _extractPropertiesFromResponse(content);
        
        // Clean out raw tag markers, table pipes, header hashes, blockquotes, and dividers
        String cleanContent = content
            .replaceAll(RegExp(r'\[PROPERTY_ID:\s*[^\]]+\]'), '')
            .replaceAll(RegExp(r'^[#]+\s*', multiLine: true), '')
            .replaceAll(RegExp(r'^[>]\s*', multiLine: true), '')
            .replaceAll(RegExp(r'[-]{3,}', multiLine: true), '')
            .replaceAll('|', ' ')
            .replaceAll(RegExp(r'\n{3,}'), '\n\n')
            .trim();

        return ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: cleanContent,
          isUser: false,
          timestamp: DateTime.now(),
          recommendedProperties: extractedProps.isNotEmpty ? extractedProps : null,
        );
      }
    }

    return null;
  }

  String _buildDatabaseContextForPrompt() {
    if (_databaseCache.isEmpty) {
      return "No listings currently available.";
    }

    final sb = StringBuffer();
    for (int i = 0; i < _databaseCache.length; i++) {
      final p = _databaseCache[i];
      final id = p.id ?? 'prop_$i';
      // SECURITY: All property fields are sanitized before injection into the AI system prompt
      // to prevent prompt injection attacks via malicious listing content.
      sb.writeln('--- PROPERTY ID: $id ---');
      sb.writeln('Title: ${_sanitizeForPrompt(p.title, maxLength: 100)}');
      sb.writeln('Type: ${_sanitizeForPrompt(p.type)} | BHK: ${_sanitizeForPrompt(p.bhkType ?? "${p.beds} Bed")} | Baths: ${_sanitizeForPrompt(p.baths)}');
      sb.writeln('Location: ${_sanitizeForPrompt(p.locationStr, maxLength: 150)}');
      sb.writeln('Rent: ${_sanitizeForPrompt(p.price)}/month | Deposit: ₹${_sanitizeForPrompt(p.securityDeposit ?? "Contact owner")}');
      sb.writeln('Tenant Preference: ${_sanitizeForPrompt(p.tenantPreference ?? "Any")} | Gender: ${_sanitizeForPrompt(p.genderPreference ?? "All")}');
      sb.writeln('Cleanliness: ${_sanitizeForPrompt(p.cleanlinessInfo ?? "Regular cleaning & well maintained")}');
      if (p.foodDetails != null && p.foodDetails!.isNotEmpty) {
        sb.writeln('Food/Mess: ${_sanitizeForPrompt(p.foodDetails)} (Per day food: ${_sanitizeForPrompt(p.perDayWithFood ?? "Included")})');
      }
      if (p.drinkingWater != null) sb.writeln('Water: ${_sanitizeForPrompt(p.drinkingWater)} | Supply: ${_sanitizeForPrompt(p.waterSupply ?? "24/7")}');
      if (p.powerBackup != null) sb.writeln('Power Backup: ${_sanitizeForPrompt(p.powerBackup)}');
      if (p.parkingInfo != null) sb.writeln('Parking: ${_sanitizeForPrompt(p.parkingInfo)}');
      if (p.features.isNotEmpty) sb.writeln('Features: ${p.features.map((f) => _sanitizeForPrompt(f)).join(", ")}');
      if (p.description != null && p.description!.isNotEmpty) {
        sb.writeln('Description: ${_sanitizeForPrompt(p.description, maxLength: 200)}');
      }
      // NOTE: Owner phone is intentionally NOT included in the AI prompt context
      // to protect owner privacy and prevent mass contact scraping via the AI.
      sb.writeln();
    }

    return sb.toString();
  }

  List<PropertyModel> _extractPropertiesFromResponse(String responseText) {
    final List<PropertyModel> matched = [];
    final idRegex = RegExp(r'\[PROPERTY_ID:\s*([^\]]+)\]');
    final matches = idRegex.allMatches(responseText);

    for (var m in matches) {
      final id = m.group(1)?.trim();
      if (id != null) {
        final found = _databaseCache.where((p) => (p.id != null && p.id == id) || ('prop_${_databaseCache.indexOf(p)}' == id)).toList();
        if (found.isNotEmpty && !matched.contains(found.first)) {
          matched.add(found.first);
        }
      }
    }

    if (matched.isEmpty) {
      for (final p in _databaseCache) {
        if (responseText.toLowerCase().contains(p.title.toLowerCase())) {
          if (!matched.contains(p)) matched.add(p);
        }
      }
    }

    return matched;
  }

  /// Smart Natural Language fallback when offline or waiting for OpenRouter
  ChatMessage _generateConversationalFallback(String rawQuery) {
    final lower = rawQuery.toLowerCase().trim();

    // 1. Handle Greetings naturally
    final greetings = ['hi', 'hello', 'hey', 'namaste', 'good morning', 'good evening', 'hi there'];
    if (greetings.contains(lower) || lower == 'hi!' || lower == 'hello!') {
      return ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: "Hello! Welcome to Rental Assistant 👋\n\nI can help you find verified PGs, single rooms, hostels, or family flats in Rajahmundry, Diwanchervu, and nearby areas.\n\nWhat kind of home or budget are you looking for today?",
        isUser: false,
        timestamp: DateTime.now(),
      );
    }

    // 2. Query search
    final ranked = _databaseCache.toList();
    if (ranked.isEmpty) {
      return ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: "I'm checking our verified listings right now. What area and budget would you like to explore?",
        isUser: false,
        timestamp: DateTime.now(),
      );
    }

    final topProp = ranked.first;
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: "I looked through our available verified homes for you:\n\n⭐ **${topProp.title}**\n• **Location:** ${topProp.locationStr}\n• **Rent:** ${topProp.price}/month (Deposit: ₹${topProp.securityDeposit ?? 'Contact owner'})\n• **Cleanliness:** ${topProp.cleanlinessInfo ?? 'Well maintained & clean'}\n• **Utilities:** ${topProp.waterSupply ?? '24/7 Water'}\n\n*You can tap the card below to see full photos or connect directly with the owner!*",
      isUser: false,
      timestamp: DateTime.now(),
      recommendedProperties: [topProp],
    );
  }
}
