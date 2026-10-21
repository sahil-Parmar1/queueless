import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/office_details/office_details_screen.dart';
import '../screens/queue/active_token_screen.dart';
import '../screens/search/office_search_screen.dart';
import '../services/office_service.dart';

class AiAssistantSheet extends StatefulWidget {
  final Map<String, dynamic>? activeToken;

  const AiAssistantSheet({super.key, this.activeToken});

  static Future<void> show(BuildContext context, {Map<String, dynamic>? activeToken}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiAssistantSheet(activeToken: activeToken),
    );
  }

  @override
  State<AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final List<dynamic>? actions;
  final DateTime timestamp;

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.actions,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class _AiAssistantSheetState extends State<AiAssistantSheet> {
  final OfficeService _officeService = OfficeService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_ChatMessage> _messages = [];
  bool _isThinking = false;

  final List<String> _quickPrompts = [
    '⏱️ How long until my turn?',
    '☕ Do I have time for lunch?',
    '🏥 Least crowded clinics right now',
    '📍 Directions to my clinic',
    '⭐ How does priority token work?',
  ];

  @override
  void initState() {
    super.initState();
    _initWelcomeMessage();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initWelcomeMessage() {
    final active = widget.activeToken;
    final bool hasToken = active != null &&
        (active['hasActiveToken'] == true ||
            (active['tokenNumber'] != null && active['tokenNumber'].toString().isNotEmpty));

    if (hasToken) {
      final tokenNum = active['tokenNumber'] ?? '---';
      final officeName = active['officeName'] ?? 'your office';
      final ahead = active['peopleAhead'] ?? 0;
      final waitMins = active['estimatedWaitMinutes'] ?? 15;

      _messages.add(
        _ChatMessage(
          text: '👋 **Hello! I\'m your Queueless AI Assistant.**\n\n'
              'You currently have token **#$tokenNum** at **$officeName** with **$ahead ${ahead == 1 ? "person" : "people"} ahead** (~$waitMins mins wait).\n\n'
              'Ask me anything about your wait time, lunch breaks, or finding nearby clinics!',
          isUser: false,
          actions: [
            {'type': 'VIEW_TOKEN', 'label': 'View Token #$tokenNum', 'data': active},
            if (active['officeAddress'] != null)
              {'type': 'OPEN_MAP', 'label': 'Directions in Maps', 'data': active},
          ],
        ),
      );
    } else {
      _messages.add(
        _ChatMessage(
          text: '👋 **Hello! I\'m your Queueless AI Assistant.**\n\n'
              'I can help you:\n'
              '• ⏱️ **Predict wait times** & tell you if you have time for lunch\n'
              '• 🏥 **Find clinics & salons** with the shortest queues right now\n'
              '• ⭐ **Explain Priority queue** requests & app features\n'
              '• 🗺️ **Get navigation directions** to your appointments\n\n'
              'How can I help you today?',
          isUser: false,
          actions: [
            {'type': 'SEARCH_OFFICES', 'label': 'Find Clinics & Salons', 'data': {}},
          ],
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isThinking) return;

    _inputController.clear();

    setState(() {
      _messages.add(_ChatMessage(text: trimmed, isUser: true));
      _isThinking = true;
    });
    _scrollToBottom();

    // Prepare history
    final historyList = _messages
        .take(_messages.length - 1)
        .map((m) => {
              'role': m.isUser ? 'user' : 'assistant',
              'text': m.text,
            })
        .toList();

    final response = await _officeService.askAiAssistant(
      message: trimmed,
      history: historyList,
    );

    if (mounted) {
      final replyText = response['reply'] ?? 'I could not process that request. Please try again.';
      final actions = response['suggestedActions'] as List<dynamic>?;

      setState(() {
        _messages.add(_ChatMessage(
          text: replyText.toString(),
          isUser: false,
          actions: actions,
        ));
        _isThinking = false;
      });
      _scrollToBottom();
    }
  }

  void _handleAction(dynamic action) {
    if (action is! Map) return;
    final type = action['type'];
    final data = action['data'] is Map ? action['data'] as Map<String, dynamic> : <String, dynamic>{};

    switch (type) {
      case 'VIEW_TOKEN':
        Navigator.pop(context); // Close sheet
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ActiveTokenScreen()),
        );
        break;

      case 'OPEN_MAP':
        _launchDirections(data);
        break;

      case 'BOOK_TOKEN':
        final officeId = data['id'] ?? data['officeId'];
        if (officeId != null) {
          final int? id = int.tryParse(officeId.toString());
          if (id != null) {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => OfficeDetailsScreen(officeId: id)),
            );
          }
        }
        break;

      case 'SEARCH_OFFICES':
      case 'SEARCH_CATEGORY':
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OfficeSearchScreen(
              initialCategory: data['category']?.toString(),
            ),
          ),
        );
        break;

      default:
        break;
    }
  }

  Future<void> _launchDirections(Map<String, dynamic> data) async {
    final lat = data['latitude'];
    final lng = data['longitude'];
    final name = data['officeName'] ?? data['name'] ?? '';
    final address = data['officeAddress'] ?? data['address'] ?? '';

    Uri? uri;
    if (lat != null && lng != null) {
      uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    } else if (address.toString().trim().isNotEmpty) {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent("$name $address")}');
    } else if (name.toString().trim().isNotEmpty) {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(name)}');
    }

    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('Could not open map: $e');
      }
    }
  }

  void _resetChat() {
    setState(() {
      _messages.clear();
      _initWelcomeMessage();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final totalHeight = mediaQuery.size.height * 0.85;

    return Container(
      height: totalHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            children: [
              _buildHeader(),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Expanded(
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  itemCount: _messages.length + (_isThinking ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index >= _messages.length) {
                      return _buildThinkingBubble();
                    }
                    final msg = _messages[index];
                    return _buildMessageItem(msg);
                  },
                ),
              ),
              _buildQuickPromptsBar(),
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 10, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(
                      children: [
                        Text(
                          'Queueless AI Assistant',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.verified_rounded, size: 15, color: Color(0xFF6366F1)),
                      ],
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Live Queue & Clinic Concierge',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF64748B)),
                tooltip: 'Reset Chat',
                onPressed: _resetChat,
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF64748B)),
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPromptsBar() {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: _quickPrompts.map((prompt) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                label: Text(
                  prompt,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4338CA),
                  ),
                ),
                backgroundColor: const Color(0xFFEEF2FF),
                side: const BorderSide(color: Color(0xFFC7D2FE)),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                visualDensity: VisualDensity.compact,
                onPressed: () => _sendMessage(prompt),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _inputController,
                textInputAction: TextInputAction.send,
                onSubmitted: _sendMessage,
                maxLines: null,
                style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                decoration: const InputDecoration(
                  hintText: 'Ask anything about your queue or clinics...',
                  hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: IconButton(
              icon: _isThinking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 22),
              onPressed: () => _sendMessage(_inputController.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(_ChatMessage msg) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.18),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            msg.text,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ),
      );
    }

    // Assistant Message
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(top: 2, right: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
          ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: _buildRichMarkdownText(msg.text),
                ),

                // Interactive Action Buttons under Assistant Response
                if (msg.actions != null && msg.actions!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: msg.actions!.map((act) {
                      final label = act['label']?.toString() ?? 'View';
                      final type = act['type']?.toString() ?? '';
                      IconData icon = Icons.touch_app_rounded;
                      Color btnColor = const Color(0xFF4F46E5);

                      if (type == 'VIEW_TOKEN') {
                        icon = Icons.confirmation_number_outlined;
                        btnColor = const Color(0xFF4F46E5);
                      } else if (type == 'OPEN_MAP') {
                        icon = Icons.directions_rounded;
                        btnColor = const Color(0xFF059669);
                      } else if (type == 'BOOK_TOKEN') {
                        icon = Icons.add_circle_outline_rounded;
                        btnColor = const Color(0xFF7C3AED);
                      }

                      return OutlinedButton.icon(
                        onPressed: () => _handleAction(act),
                        icon: Icon(icon, size: 14, color: btnColor),
                        label: Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: btnColor,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: btnColor.withValues(alpha: 0.35)),
                          backgroundColor: btnColor.withValues(alpha: 0.05),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6366F1), size: 16),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
                ),
                SizedBox(width: 8),
                Text(
                  'Queueless is analyzing your queue...',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Helper to render markdown bold (**text**) and bullet points cleanly
  Widget _buildRichMarkdownText(String text) {
    final List<TextSpan> spans = [];
    final lines = text.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Parse bold tags within each line
      final parts = line.split('**');
      for (int j = 0; j < parts.length; j++) {
        final isBold = j % 2 == 1;
        spans.add(
          TextSpan(
            text: parts[j],
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: const Color(0xFF0F172A),
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w400,
            ),
          ),
        );
      }

      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}
