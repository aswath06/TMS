import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StarredMessagesScreen extends StatefulWidget {
  final String groupName;

  const StarredMessagesScreen({super.key, required this.groupName});

  @override
  State<StarredMessagesScreen> createState() => _StarredMessagesScreenState();
}

class _StarredMessagesScreenState extends State<StarredMessagesScreen> {
  List<Map<String, dynamic>> _starredMessages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStarredMessages();
  }

  Future<void> _loadStarredMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString('chat_messages_${widget.groupName}');
      
      if (jsonStr != null) {
        final List<dynamic> decoded = json.decode(jsonStr);
        List<Map<String, dynamic>> starred = [];
        for (var m in decoded) {
          final msg = Map<String, dynamic>.from(m);
          if (msg['isStarred'] == true && msg['isDeleted'] != true) {
            starred.add(msg);
          }
        }
        
        if (mounted) {
          setState(() {
            _starredMessages = starred.reversed.toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint("Error loading starred messages: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTime(Map<String, dynamic> msg) {
    if (msg.containsKey('time') && msg['time'] != null) {
      return msg['time'];
    }
    return "Unknown time";
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    const Color brandColor = Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: titleColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Starred Messages",
          style: GoogleFonts.plusJakartaSans(
            color: titleColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: brandColor))
          : _starredMessages.isEmpty
              ? _buildEmptyState(subColor)
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _starredMessages.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final msg = _starredMessages[index];
                    return _buildMessageCard(index, msg, cardColor, titleColor, subColor, brandColor);
                  },
                ),
    );
  }

  Widget _buildEmptyState(Color subColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_border_rounded, size: 80, color: subColor.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            "No starred messages yet.",
            style: GoogleFonts.plusJakartaSans(
              color: subColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _unstarMessage(int index) async {
    HapticFeedback.mediumImpact();
    final msg = _starredMessages[index];
    setState(() {
      _starredMessages.removeAt(index);
    });
    
    final prefs = await SharedPreferences.getInstance();
    final String key = 'chat_messages_${widget.groupName}';
    final String? messagesJson = prefs.getString(key);
    if (messagesJson != null) {
      final List<dynamic> decoded = json.decode(messagesJson);
      final List<Map<String, dynamic>> allMessages = List<Map<String, dynamic>>.from(decoded);
      
      for (var m in allMessages) {
        if (m['timestamp'] == msg['timestamp'] && m['text'] == msg['text']) {
          m['isStarred'] = false;
          break;
        }
      }
      await prefs.setString(key, json.encode(allMessages));
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Message unstarred"),
        backgroundColor: Color(0xFF64748B),
        duration: Duration(seconds: 1),
      ));
    }
  }

  Widget _buildMessageCard(int index, Map<String, dynamic> msg, Color cardColor, Color titleColor, Color subColor, Color brandColor) {
    final bool isSender = msg['isSender'] ?? false;
    final String senderLabel = isSender ? "You" : "Contact";
    final String time = _formatTime(msg);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: subColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(isSender ? Icons.person_rounded : Icons.group_rounded, size: 16, color: subColor),
                  const SizedBox(width: 6),
                  Text(
                    senderLabel,
                    style: GoogleFonts.plusJakartaSans(color: subColor, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    time,
                    style: GoogleFonts.plusJakartaSans(color: subColor, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _unstarMessage(index),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                    ),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'unstar') {
                        _unstarMessage(index);
                      }
                    },
                    color: cardColor,
                    icon: Icon(Icons.more_vert_rounded, size: 18, color: subColor),
                    itemBuilder: (BuildContext context) => [
                      PopupMenuItem<String>(
                        value: 'unstar',
                        child: Row(
                          children: [
                            const Icon(Icons.star_border_rounded, size: 18, color: Colors.amber),
                            const SizedBox(width: 8),
                            Text("Unstar Message", style: GoogleFonts.plusJakartaSans(color: titleColor, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 12),
          _buildMessageContent(msg, titleColor, brandColor),
        ],
      ),
    );
  }

  Widget _buildMessageContent(Map<String, dynamic> msg, Color titleColor, Color brandColor) {
    if (msg.containsKey('text') && (msg['text'] as String).isNotEmpty) {
      return Text(
        msg['text'],
        style: GoogleFonts.plusJakartaSans(color: titleColor, fontSize: 15, height: 1.4),
      );
    }
    
    if (msg.containsKey('imagePaths') || msg.containsKey('imagePath')) {
      return Row(
        children: [
          Icon(Icons.photo_library_rounded, color: brandColor),
          const SizedBox(width: 8),
          Text("Photo", style: GoogleFonts.plusJakartaSans(color: titleColor, fontSize: 15, fontStyle: FontStyle.italic)),
        ],
      );
    }

    if (msg.containsKey('documentName')) {
      return Row(
        children: [
          Icon(Icons.description_rounded, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg['documentName'], style: GoogleFonts.plusJakartaSans(color: titleColor, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      );
    }

    return Text("Unknown message type", style: GoogleFonts.plusJakartaSans(color: titleColor, fontSize: 15, fontStyle: FontStyle.italic));
  }
}
