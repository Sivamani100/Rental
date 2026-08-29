import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/home_screen.dart' show PropertyModel;
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

  static const String _defaultApiKey = '';
  String? _customApiKey;

  static const String primaryModel = 'openrouter/free';
  static const String fallbackModel = 'meta-llama/llama-3.3-70b-instruct:free';

  final List<PropertyModel> _databaseCache = [];
  bool _isSynced = false;
  final List<ChatMessage> _chatHistory = [];

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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('openrouter_api_key', _customApiKey!);
  }

  Future<void> loadSavedApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('openrouter_api_key');
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

  /// Persist local chat history
  Future<void> _persistChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_chatHistory.map((m) => m.toJson()).toList());
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

  /// Process natural language query via OpenRouter Free AI with conversation memory
  Future<ChatMessage> processQuery(String userQueryText, {String? imagePath}) async {
    final cleanInput = userQueryText.trim();
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
      sb.writeln('--- PROPERTY ID: $id ---');
      sb.writeln('Title: ${p.title}');
      sb.writeln('Type: ${p.type} | BHK: ${p.bhkType ?? p.beds + " Bed"} | Baths: ${p.baths}');
      sb.writeln('Location: ${p.locationStr}');
      sb.writeln('Rent: ${p.price}/month | Deposit: ₹${p.securityDeposit ?? "Contact owner"}');
      sb.writeln('Tenant Preference: ${p.tenantPreference ?? "Any"} | Gender: ${p.genderPreference ?? "All"}');
      sb.writeln('Cleanliness: ${p.cleanlinessInfo ?? "Regular cleaning & well maintained"}');
      if (p.foodDetails != null && p.foodDetails!.isNotEmpty) {
        sb.writeln('Food/Mess: ${p.foodDetails} (Per day food: ${p.perDayWithFood ?? "Included"})');
      }
      if (p.drinkingWater != null) sb.writeln('Water: ${p.drinkingWater} | Supply: ${p.waterSupply ?? "24/7"}');
      if (p.powerBackup != null) sb.writeln('Power Backup: ${p.powerBackup}');
      if (p.parkingInfo != null) sb.writeln('Parking: ${p.parkingInfo}');
      if (p.features.isNotEmpty) sb.writeln('Features: ${p.features.join(", ")}');
      if (p.description != null && p.description!.isNotEmpty) sb.writeln('Description: ${p.description}');
      sb.writeln('Owner Contact: ${p.ownerPhone}');
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
