import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/health_provider.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage([String? text]) {
    final msg = text ?? _messageController.text;
    if (msg.trim().isEmpty) return;

    final health = Provider.of<HealthProvider>(context, listen: false);
    health.sendChatMessage(msg);
    
    if (text == null) _messageController.clear();
    
    // Auto Scroll to bottom
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

  @override
  Widget build(BuildContext context) {
    final health = Provider.of<HealthProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<String> suggestions = [
      'What is Paracetamol used for?',
      'Tell me about Metformin',
      'Uses of Amoxicillin',
      'What is Omeprazole?',
      'Tell me about Amlodipine',
      'What to do if I miss a dose?',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Medicine Assistant 💊', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () => health.clearChatHistory(),
            tooltip: 'Clear History',
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat list messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: health.chatMessages.length,
              itemBuilder: (context, index) {
                final chat = health.chatMessages[index];
                final isUser = chat['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
                    decoration: BoxDecoration(
                      color: isUser
                          ? colorScheme.primary
                          : isDark
                              ? const Color(0xFF1E293B)
                              : Colors.grey.shade100,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                        bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                      ),
                    ),
                    child: Text(
                      chat['content'] ?? '',
                      style: TextStyle(
                        color: isUser
                            ? Colors.white
                            : isDark
                                ? Colors.grey.shade200
                                : Colors.grey.shade900,
                        fontSize: 15,
                        height: 1.35,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Typing Loader
          if (health.isChatLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary),
                  ),
                  const SizedBox(width: 10),
                  const Text('AI is thinking...', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13)),
                ],
              ),
            ),

          // Suggestion Chips Slider
          if (health.chatMessages.length <= 2)
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: suggestions.length,
                itemBuilder: (context, idx) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ActionChip(
                      label: Text(suggestions[idx]),
                      onPressed: () => _sendMessage(suggestions[idx]),
                      backgroundColor: colorScheme.primary.withValues(alpha: 0.06),
                      labelStyle: TextStyle(color: colorScheme.primary, fontSize: 13, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
              ),
            ),

          // Input form
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ask about a medicine or health question...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_rounded),
                  color: colorScheme.primary,
                  onPressed: () => _sendMessage(),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
