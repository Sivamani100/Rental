import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/bouncing_button.dart';
import '../widgets/app_snackbar.dart';
import '../services/ai_assistant_service.dart';
import 'home_screen.dart' show PropertyModel;
import 'property_details_screen.dart';

class AiChatScreen extends StatefulWidget {
  final List<PropertyModel>? initialProperties;

  const AiChatScreen({super.key, this.initialProperties});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isDbReady = false;
  bool _hasInputText = false;
  String? _selectedAttachmentPath;

  final List<_PromptIdea> _promptIdeas = [
    _PromptIdea(
      icon: Iconsax.home_hashtag,
      title: "Bachelor Stay in Diwanchervu",
      subtitle: "Single room for bachelor under ₹10,000 clean & proper",
      prompt: "Which home is best for me in Diwanchervu as a bachelor wanting a clean single room for rental under 10000?",
    ),
    _PromptIdea(
      icon: Iconsax.cup,
      title: "PG with 3-Time Food",
      subtitle: "Hostels with daily meals and wifi included",
      prompt: "Show me best PGs with food included and good cleanliness",
    ),
    _PromptIdea(
      icon: Iconsax.building_3,
      title: "Family 2 BHK Rental",
      subtitle: "Spacious apartments with car parking & water",
      prompt: "Find clean 2 BHK family flats with car parking and no water problem",
    ),
    _PromptIdea(
      icon: Iconsax.wallet_2,
      title: "Budget Stays under ₹5,000",
      subtitle: "Affordable rooms and sharing options",
      prompt: "Show me affordable budget rooms under ₹5000 per month",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);

    // Immediately populate chat messages synchronously so history shows instantly with 0ms delay
    final existing = AiAssistantService.instance.chatHistory;
    if (existing.isNotEmpty) {
      _messages.addAll(existing);
      _isDbReady = true;
      _scrollToBottom();
    }

    _initAssistant();
  }

  void _onTextChanged() {
    final hasText = _textController.text.trim().isNotEmpty || _selectedAttachmentPath != null;
    if (hasText != _hasInputText) {
      setState(() {
        _hasInputText = hasText;
      });
    }
  }

  Future<void> _initAssistant() async {
    // Load local history fast
    final saved = await AiAssistantService.instance.loadSavedChatHistory();
    if (mounted && saved.isNotEmpty) {
      setState(() {
        _messages.clear();
        _messages.addAll(saved);
        _isDbReady = true;
      });
      _scrollToBottom();
    }

    // Sync database in background without blocking screen
    AiAssistantService.instance.syncDatabase(initialProperties: widget.initialProperties).then((_) {
      if (mounted) {
        setState(() {
          _isDbReady = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _pickImage() async {
    HapticFeedback.selectionClick();
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _selectedAttachmentPath = picked.path;
        _hasInputText = true;
      });
    }
  }

  void _removeAttachment() {
    setState(() {
      _selectedAttachmentPath = null;
      _hasInputText = _textController.text.trim().isNotEmpty;
    });
  }

  Future<void> _handleSend([String? presetText]) async {
    final text = (presetText ?? _textController.text).trim();
    final attachment = _selectedAttachmentPath;

    if (text.isEmpty && attachment == null) return;
    if (_isTyping) return;

    HapticFeedback.lightImpact();
    _textController.clear();
    setState(() {
      _selectedAttachmentPath = null;
      _hasInputText = false;
    });

    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text.isNotEmpty ? text : "Shared an image with the assistant",
      isUser: true,
      timestamp: DateTime.now(),
      imagePath: attachment,
    );

    setState(() {
      _messages.add(userMsg);
      _isTyping = true;
    });
    _scrollToBottom();

    final aiResponse = await AiAssistantService.instance.processQuery(text, imagePath: attachment);

    if (mounted) {
      setState(() {
        _messages.add(aiResponse);
        _isTyping = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _resetChat() async {
    HapticFeedback.selectionClick();
    await AiAssistantService.instance.clearHistory();
    setState(() {
      _messages.clear();
      _messages.add(
        ChatMessage(
          id: 'welcome',
          text: "👋 **New conversation started!**\n\nWhat area, budget, or type of stay would you like to explore?",
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
    AppSnackbar.success(context, 'Chat restarted');
  }

  void _openPropertyDetails(PropertyModel property) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PropertyDetailsScreen(property: property),
      ),
    );
  }

  Future<void> _makeCall(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String? whatsapp, String? phone, String propTitle) async {
    final num = (whatsapp != null && whatsapp.isNotEmpty) ? whatsapp : phone;
    if (num == null || num.isEmpty) return;
    final clean = num.replaceAll(RegExp(r'[^0-9]'), '');
    final url = 'https://wa.me/$clean?text=${Uri.encodeComponent("Hello, I am interested in your property: $propTitle via Rental Assistant")}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffold : const Color(0xFFFBF7F7),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                // 10px top margin from top bar
                const SizedBox(height: 10),

                // Clean Header (Key Icon hidden as requested)
                _buildCleanHeader(isDark),

                // Chat Messages or Clean Landing
                Expanded(
                  child: _messages.isEmpty
                      ? _buildEmptyLanding(isDark)
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          itemCount: _messages.length + (_isTyping ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _messages.length && _isTyping) {
                              return _buildTypingState(isDark);
                            }
                            final msg = _messages[index];
                            return _buildMessageRow(msg, isDark);
                          },
                        ),
                ),

                // ChatGPT Input with '+' Image attachment
                _buildChatGptInput(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCleanHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button (Transparent ghost button like ChatGPT)
          BouncingButton(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Iconsax.arrow_left_2,
                color: isDark ? Colors.white : Colors.black,
                size: 19,
              ),
            ),
          ),

          // Center Title Badge (Transparent like ChatGPT)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _isDbReady ? const Color(0xFF00E676) : const Color(0xFFFFEB3A),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Rental Assistant',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 5),
              Icon(
                Iconsax.magicpen,
                size: 14,
                color: isDark ? const Color(0xFFFFEB3A) : Colors.black87,
              ),
            ],
          ),

          // New Chat Button (Transparent ghost button like ChatGPT)
          BouncingButton(
            onTap: _resetChat,
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Iconsax.add,
                color: isDark ? Colors.white : Colors.black87,
                size: 19,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyLanding(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEB3A),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFEB3A).withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(
              Iconsax.magicpen,
              color: Colors.black,
              size: 28,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            "What property are you looking for?",
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: -0.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            "Tell me your budget, locality, or requirements in plain words",
            style: TextStyle(
              fontSize: 13.5,
              color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),

          // 2x2 Suggestion Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 550;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _promptIdeas.map((idea) {
                  final cardWidth = isWide
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;

                  return BouncingButton(
                    onTap: () => _handleSend(idea.prompt),
                    child: Container(
                      width: cardWidth,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppTheme.darkBorder : Colors.black.withValues(alpha: 0.08),
                          width: 1,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEB3A).withValues(alpha: isDark ? 0.15 : 0.25),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              idea.icon,
                              color: isDark ? const Color(0xFFFFEB3A) : Colors.black87,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  idea.title,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  idea.subtitle,
                                  style: TextStyle(
                                    color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                                    fontSize: 12.5,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Iconsax.arrow_right_3,
                            size: 16,
                            color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMessageRow(ChatMessage msg, bool isDark) {
    if (msg.isUser) {
      final isOnlyImage = msg.imagePath != null &&
          (msg.text.isEmpty || msg.text == "Shared an image with the assistant" || msg.text == "Shared a photo with the assistant");

      return Padding(
        padding: const EdgeInsets.only(bottom: 24, left: 40),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                padding: isOnlyImage
                    ? const EdgeInsets.all(4)
                    : const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF26262B) : Colors.black,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (msg.imagePath != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.file(
                          File(msg.imagePath!),
                          width: 220,
                          height: 160,
                          fit: BoxFit.cover,
                        ),
                      ),
                      if (!isOnlyImage) const SizedBox(height: 10),
                    ],
                    if (!isOnlyImage)
                      Text(
                        msg.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Assistant response: Clean left-aligned layout directly from the left edge
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMarkdownBody(msg.text, isDark),

          // Recommended Properties Card List
          if (msg.recommendedProperties != null && msg.recommendedProperties!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Iconsax.home_2, color: Color(0xFFFFEB3A), size: 15),
                    const SizedBox(width: 6),
                    Text(
                      msg.recommendedProperties!.length == 1
                          ? 'Top Match For You'
                          : 'Top Matches For You (${msg.recommendedProperties!.length})',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (msg.recommendedProperties!.length == 1)
                  _buildPropertyCard(msg.recommendedProperties!.first, isDark, isFullWidth: true)
                else
                  SizedBox(
                    height: 215,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: msg.recommendedProperties!.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final prop = msg.recommendedProperties![i];
                        return _buildPropertyCard(prop, isDark, isFullWidth: false);
                      },
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPropertyCard(PropertyModel prop, bool isDark, {bool isFullWidth = false}) {
    final hasImg = prop.imageUrls.isNotEmpty;
    final priceStr = prop.price.replaceAll(RegExp(r'[^0-9.]'), '');

    return Container(
      width: isFullWidth ? double.infinity : 260,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.black.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: isFullWidth ? 160 : 110,
                width: double.infinity,
                color: isDark ? Colors.black38 : Colors.grey.shade200,
                child: hasImg
                    ? CachedNetworkImage(
                        imageUrl: prop.imageUrls.first,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Center(
                          child: Icon(Iconsax.gallery_slash, size: 24, color: Colors.grey),
                        ),
                      )
                    : const Center(
                        child: Icon(Iconsax.home, size: 28, color: Colors.grey),
                      ),
              ),
              // Fully Rounded Type Badge
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    prop.type,
                    style: const TextStyle(
                      color: Color(0xFFFFEB3A),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              // Fully Rounded Price Badge
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEB3A),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '₹${priceStr.isNotEmpty ? priceStr : prop.price}/m',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: '${prop.title} '),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Icon(
                                Iconsax.verify5,
                                size: 15,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Iconsax.location,
                      size: 12,
                      color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        prop.locationStr,
                        style: TextStyle(
                          color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                          fontSize: 11.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),

                // Fully Rounded View Button Only
                BouncingButton(
                  onTap: () => _openPropertyDetails(prop),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 7.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEB3A),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Iconsax.eye, size: 14, color: Colors.black),
                        SizedBox(width: 5),
                        Text(
                          'View Details',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownBody(String text, bool isDark) {
    // Sanitize any raw markdown hashes, dividers, quotes, or pipes
    final sanitizedText = text
        .replaceAll(RegExp(r'^[#]+\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^[>]\s*', multiLine: true), '')
        .replaceAll(RegExp(r'[-]{3,}', multiLine: true), '')
        .replaceAll('|', ' ');

    final lines = sanitizedText.split('\n');
    final children = <Widget>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        children.add(const SizedBox(height: 6));
        continue;
      }

      if (trimmed.startsWith('• ') || trimmed.startsWith('* ') || trimmed.startsWith('- ')) {
        final bulletContent = trimmed.substring(2).trim();
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '• ',
                  style: TextStyle(
                    color: Color(0xFFFFEB3A),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: _parseFormattedInline(bulletContent, isDark),
                ),
              ],
            ),
          ),
        );
      } else {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _parseFormattedInline(trimmed, isDark),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _parseFormattedInline(String text, bool isDark) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'(\*\*.*?\*\*|\*.*?\*)');
    int lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: TextStyle(
              color: isDark ? const Color(0xFFECECF1) : const Color(0xFF1E1E24),
              fontSize: 16,
              height: 1.5,
            ),
          ),
        );
      }

      final matchedStr = match.group(0)!;
      if (matchedStr.startsWith('**') && matchedStr.endsWith('**')) {
        spans.add(
          TextSpan(
            text: matchedStr.substring(2, matchedStr.length - 2),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        );
      } else if (matchedStr.startsWith('*') && matchedStr.endsWith('*')) {
        spans.add(
          TextSpan(
            text: matchedStr.substring(1, matchedStr.length - 1),
            style: TextStyle(
              color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
              fontStyle: FontStyle.italic,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        );
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastIndex),
          style: TextStyle(
            color: isDark ? const Color(0xFFECECF1) : const Color(0xFF1E1E24),
            fontSize: 16,
            height: 1.5,
          ),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildTypingState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24, left: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFEB3A)),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Thinking...',
            style: TextStyle(
              color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatGptInput(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Column(
        children: [
          // Selected Attachment Preview chip (ChatGPT style card with close badge)
          if (_selectedAttachmentPath != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10, left: 4),
              alignment: Alignment.centerLeft,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(_selectedAttachmentPath!),
                        width: 68,
                        height: 68,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: GestureDetector(
                      onTap: _removeAttachment,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF333338) : Colors.black87,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? Colors.black : Colors.white,
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(Icons.close, size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Input pill
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B1B1E) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? const Color(0xFF2E2E35) : Colors.black.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
            child: Row(
              children: [
                // Clean '+' button for images/files without background box
                BouncingButton(
                  onTap: _pickImage,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Icon(
                      Iconsax.add,
                      color: isDark ? Colors.white70 : Colors.black87,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // Text field
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _handleSend(),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 15.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Message Rental Assistant...',
                      hintStyle: TextStyle(
                        color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade500,
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Send button
                BouncingButton(
                  onTap: _hasInputText ? () => _handleSend() : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _hasInputText
                          ? const Color(0xFFFFEB3A)
                          : (isDark ? const Color(0xFF2C2C32) : const Color(0xFFE5E5EA)),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Iconsax.arrow_up_3,
                      color: _hasInputText
                          ? Colors.black
                          : (isDark ? Colors.grey.shade600 : Colors.grey.shade500),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Rental Assistant provides verified real estate insights.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptIdea {
  final IconData icon;
  final String title;
  final String subtitle;
  final String prompt;

  _PromptIdea({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.prompt,
  });
}
