import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:open_filex/open_filex.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'youtube_player_screen.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'group_info_screen.dart';
import 'package:tripzo/screens/chat/full_screen_image_viewer.dart';

class ChatDetailScreen extends StatefulWidget {
  final String name;
  final String avatarUrl;
  final bool isGroup;
  final Map<String, bool>? permissions;

  const ChatDetailScreen({
    super.key,
    required this.name,
    required this.avatarUrl,
    this.isGroup = false,
    this.permissions,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late String _currentAvatarUrl;
  Set<int> _selectedMessageIndices = {};
  String? _pinnedMessage;
  Map<String, dynamic>? _replyingToMessage;
  bool _isSearching = false;
  String _searchQuery = "";
  List<int> _searchResults = [];
  int _currentSearchIndex = 0;
  Timer? _timeUpdateTimer;
  
  String? _inlineYoutubeUrl;
  YoutubePlayerController? _inlineYoutubeController;

  final List<Map<String, dynamic>> _messages = [];

  String _getInitials(String name) {
    if (name.isEmpty) return "";
    List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return "?";
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return "${parts[0][0]}${parts[1][0]}".toUpperCase();
  }

  Widget _buildInitialsAvatar({required String name, double radius = 20}) {
    final initials = _getInitials(name);
    const Color brandColor = Color(0xFF818CF8);
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [brandColor, brandColor.withValues(alpha: 0.75)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.7,
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _currentAvatarUrl = widget.avatarUrl;
    _loadSavedMessages();
    _timeUpdateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _inlineYoutubeController?.close();
    _timeUpdateTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _getFormattedRelativeTime(String? timestampStr, String fallbackTime) {
    if (timestampStr == null) return fallbackTime;
    final time = DateTime.tryParse(timestampStr);
    if (time == null) return fallbackTime;

    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return "Just now";
    }

    int hour = time.hour;
    String ampm = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    String minute = time.minute.toString().padLeft(2, '0');
    return "$hour:$minute $ampm";
  }

  Future<void> _loadSavedMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString('chat_messages_${widget.name}');
      if (jsonStr != null) {
        final List<dynamic> decoded = json.decode(jsonStr);
        setState(() {
          _messages.clear();
          _messages.addAll(decoded.map((m) => Map<String, dynamic>.from(m)));
        });
      }
    } catch (e) {
      debugPrint("Error loading messages: $e");
    }
  }
  String _getCurrentTime() {
    final now = DateTime.now();
    int hour = now.hour;
    String ampm = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    String minute = now.minute.toString().padLeft(2, '0');
    return "$hour:$minute $ampm";
  }

  Future<void> _saveMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonStr = json.encode(_messages);
      await prefs.setString('chat_messages_${widget.name}', jsonStr);
    } catch (e) {
      debugPrint("Error saving messages: $e");
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _showQuickMessageDialog() async {
    final TextEditingController subjectController = TextEditingController();
    final TextEditingController msgController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              title: const Text("Send Quick Message"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: subjectController,
                      decoration: const InputDecoration(
                        hintText: "Subject",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: msgController,
                      decoration: const InputDecoration(
                        hintText: "Enter your message...",
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF818CF8)),
                  onPressed: () async {
                    if (subjectController.text.trim().isEmpty || msgController.text.trim().isEmpty) return;
                    
                    final prefs = await SharedPreferences.getInstance();
                    final quickData = {
                      "id": DateTime.now().millisecondsSinceEpoch.toString(),
                      "subject": subjectController.text.trim(),
                      "message": msgController.text.trim(),
                      "sender": UserStore.role ?? "Admin",
                      "timestamp": DateTime.now().toIso8601String(),
                      "targets": ["All Members"],
                      "groupName": widget.name,
                      "groupAvatar": widget.avatarUrl,
                    };
                    
                    await prefs.setString('quick_message', json.encode(quickData));
                    
                    setState(() {
                      _messages.add({
                        "text": "[Quick Message] ${subjectController.text.trim()}\n${msgController.text.trim()}\nTo: All Members",
                        "isMe": true,
                        "time": _getCurrentTime(),
                        "timestamp": DateTime.now().toIso8601String(),
                        "status": "sent",
                      });
                    });
                    _saveMessages();
                    _scrollToBottom();
                    
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Quick Message Sent!"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: const Text("Send", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showMessageInfo(Map<String, dynamic> message) {
    showDialog(
      context: context,
      builder: (context) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final Color txtColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final Color subTxtColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

        final String sentTime = _getFormattedRelativeTime(message['timestamp'], message['time'] ?? 'Now');
        final String seenTime = message['status'] == 'read' ? 'Seen 2m ago' : 'Not seen yet';

        return AlertDialog(
          backgroundColor: cardBg,
          title: Text(
            "Message Info",
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: txtColor),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Sent Time", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: txtColor)),
              Text(sentTime, style: GoogleFonts.plusJakartaSans(color: subTxtColor)),
              const SizedBox(height: 16),
              Text("Seen Time", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: txtColor)),
              Text(seenTime, style: GoogleFonts.plusJakartaSans(color: subTxtColor)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Close", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF818CF8))),
            ),
          ],
        );
      },
    );
  }

  void _copyMessage(Map<String, dynamic> message) {
    Clipboard.setData(ClipboardData(text: message['text']));
    setState(() {
      _selectedMessageIndices.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Message copied to clipboard"), backgroundColor: Color(0xFF818CF8)),
    );
  }

  void _pinMessage(Map<String, dynamic> message) {
    setState(() {
      _pinnedMessage = message['text'];
      _selectedMessageIndices.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Message pinned"), backgroundColor: Color(0xFF818CF8)),
    );
  }

  void _showDeleteDialog(int index) {
    final msg = _messages[index];
    bool canDeleteForEveryone = false;
    if (msg['isMe'] == true && msg['timestamp'] != null && msg['isDeleted'] != true) {
      final sentTime = DateTime.parse(msg['timestamp']);
      if (DateTime.now().difference(sentTime).inMinutes <= 30) {
        canDeleteForEveryone = true;
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final Color txtColor = isDark ? Colors.white : const Color(0xFF0F172A);

        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.only(top: 12, left: 24, right: 24, bottom: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 32),
              ),
              const SizedBox(height: 16),
              Text("Delete Message", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 20, color: txtColor)),
              const SizedBox(height: 8),
              Text(
                "This action cannot be undone.",
                style: GoogleFonts.plusJakartaSans(color: txtColor.withValues(alpha: 0.6), fontSize: 14),
              ),
              const SizedBox(height: 32),
              if (canDeleteForEveryone)
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _messages[index]['text'] = "🚫 This message was deleted";
                      _messages[index]['isDeleted'] = true;
                      _messages[index].remove('imagePath');
                      _messages[index].remove('imagePaths');
                      _messages[index].remove('pollQuestion');
                      _messages[index].remove('pollOptions');
                      _messages[index].remove('locationLat');
                      _messages[index].remove('locationLng');
                      _messages[index].remove('locationName');
                    });
                    _saveMessages();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Message deleted for everyone"), backgroundColor: Color(0xFF818CF8)),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 8),
                        Text("Delete for Everyone", style: GoogleFonts.plusJakartaSans(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              if (canDeleteForEveryone) const SizedBox(height: 12),
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _messages.removeAt(index);
                  });
                  _saveMessages();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Message deleted for you"), backgroundColor: Color(0xFF818CF8)),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: txtColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text("Delete for Me", style: GoogleFonts.plusJakartaSans(color: txtColor, fontWeight: FontWeight.w600, fontSize: 16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text("Cancel", style: GoogleFonts.plusJakartaSans(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _toggleStarMessage(int index) {
    setState(() {
      final isStarred = _messages[index]['isStarred'] ?? false;
      _messages[index]['isStarred'] = !isStarred;
    });
    _saveMessages();
    final bool nowStarred = _messages[index]['isStarred'] ?? false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(nowStarred ? "Message starred ⭐" : "Message unstarred"),
        backgroundColor: const Color(0xFF818CF8),
      ),
    );
  }

  void _showForwardSheet(Map<String, dynamic> message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final Color sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final Color txtColor = isDark ? Colors.white : const Color(0xFF0F172A);

        final contacts = [
          {"name": "Transport Admin"},
          {"name": "Security Team"},
          {"name": "Driver John"},
          {"name": "Support Hub"},
          {"name": "Maintenance"},
          {"name": "HR Department"},
        ];

        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Forward message to...",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: txtColor,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _buildInitialsAvatar(name: contact['name']!, radius: 20),
                      title: Text(
                        contact['name']!,
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: txtColor),
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF818CF8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          setState(() {
                            _selectedMessageIndices.clear();
                          });
                          try {
                            final prefs = await SharedPreferences.getInstance();
                            final String key = 'chat_messages_${contact['name']}';
                            final String? existingJson = prefs.getString(key);
                            List<dynamic> existingMsgs = existingJson != null ? json.decode(existingJson) : [];
                            existingMsgs.add({
                              "text": "Forwarded: ${message['text']}",
                              "isMe": true,
                              "time": _getCurrentTime(), "timestamp": DateTime.now().toIso8601String(),
                              "status": "sent",
                            });
                            await prefs.setString(key, json.encode(existingMsgs));
                          } catch (e) {
                            debugPrint("Error forwarding message: $e");
                          }
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Forwarded to ${contact['name']}"),
                                backgroundColor: const Color(0xFF818CF8),
                              ),
                            );
                          }
                        },
                        child: const Text("Send", style: TextStyle(color: Colors.white)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMultiForwardSheet() {
    if (_selectedMessageIndices.isEmpty) return;
    final firstIdx = _selectedMessageIndices.first;
    _showForwardSheet(_messages[firstIdx]);
  }

  void _showMultiDeleteDialog() {
    if (_selectedMessageIndices.isEmpty) return;

    bool canDeleteForEveryone = _selectedMessageIndices.every((idx) {
      final msg = _messages[idx];
      if (msg['isMe'] != true) return false;
      if (msg['isDeleted'] == true) return false;
      if (msg['timestamp'] != null) {
        final sentTime = DateTime.parse(msg['timestamp']);
        if (DateTime.now().difference(sentTime).inMinutes > 30) {
          return false;
        }
      }
      return true;
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final Color txtColor = isDark ? Colors.white : const Color(0xFF0F172A);

        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.only(top: 12, left: 24, right: 24, bottom: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 32),
              ),
              const SizedBox(height: 16),
              Text("Delete ${_selectedMessageIndices.length} Messages", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 20, color: txtColor)),
              const SizedBox(height: 8),
              Text(
                "This action cannot be undone.",
                style: GoogleFonts.plusJakartaSans(color: txtColor.withValues(alpha: 0.6), fontSize: 14),
              ),
              const SizedBox(height: 32),
              if (canDeleteForEveryone)
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      for (var idx in _selectedMessageIndices) {
                        _messages[idx]['text'] = "🚫 This message was deleted";
                        _messages[idx]['isDeleted'] = true;
                        _messages[idx].remove('imagePath');
                        _messages[idx].remove('imagePaths');
                        _messages[idx].remove('pollQuestion');
                        _messages[idx].remove('pollOptions');
                        _messages[idx].remove('locationLat');
                        _messages[idx].remove('locationLng');
                        _messages[idx].remove('locationName');
                      }
                      _selectedMessageIndices.clear();
                    });
                    _saveMessages();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Messages deleted for everyone"), backgroundColor: Color(0xFF818CF8)));
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 8),
                        Text("Delete for Everyone", style: GoogleFonts.plusJakartaSans(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              if (canDeleteForEveryone) const SizedBox(height: 12),
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    final indices = _selectedMessageIndices.toList()..sort((a, b) => b.compareTo(a));
                    for (var idx in indices) {
                      _messages.removeAt(idx);
                    }
                    _selectedMessageIndices.clear();
                  });
                  _saveMessages();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selected messages deleted for you"), backgroundColor: Color(0xFF818CF8)));
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: txtColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text("Delete for Me", style: GoogleFonts.plusJakartaSans(color: txtColor, fontWeight: FontWeight.w600, fontSize: 16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text("Cancel", style: GoogleFonts.plusJakartaSans(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handlePickPhoto() async {
    Navigator.pop(context);
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          if (images.length == 1) {
            _messages.add({
              "imagePath": images.first.path,
              "text": "Photo",
              "isMe": true,
              "time": _getCurrentTime(), "timestamp": DateTime.now().toIso8601String(),
              "status": "sent",
            });
          } else {
            _messages.add({
              "imagePaths": images.map((e) => e.path).toList(),
              "text": "Photos",
              "isMe": true,
              "time": _getCurrentTime(), "timestamp": DateTime.now().toIso8601String(),
              "status": "sent",
            });
          }
        });
        _saveMessages();
      }
    } catch (e) {
      debugPrint("Error picking photo: $e");
    }
  }

  Future<void> _handleTakePhoto() async {
    Navigator.pop(context);
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() {
          _messages.add({
            "imagePath": image.path,
            "text": "Photo",
            "isMe": true,
            "time": _getCurrentTime(), "timestamp": DateTime.now().toIso8601String(),
            "status": "sent",
          });
        });
        _saveMessages();
      }
    } catch (e) {
      debugPrint("Error taking photo: $e");
    }
  }

  Future<void> _handlePickDocument() async {
    Navigator.pop(context);
    try {
      fp.FilePickerResult? result = await fp.FilePicker.pickFiles(
        type: fp.FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        final fp.PlatformFile file = result.files.first;
        final String name = file.name;
        
        String sizeStr = "";
        final double sizeInKb = file.size / 1024;
        if (sizeInKb > 1024) {
          sizeStr = "${(sizeInKb / 1024).toStringAsFixed(1)} MB";
        } else {
          sizeStr = "${sizeInKb.toStringAsFixed(0)} KB";
        }

        setState(() {
          _messages.add({
            "documentName": name,
            "documentSize": sizeStr,
            "documentPath": file.path,
            "text": "Document: $name",
            "isMe": true,
            "time": _getCurrentTime(), "timestamp": DateTime.now().toIso8601String(),
            "status": "sent",
          });
        });
        _saveMessages();
      }
    } catch (e) {
      debugPrint("Error picking document: $e");
    }
  }

  Future<void> _handleSendLocation() async {
    Navigator.pop(context);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location services are disabled. Please enable GPS.")));
        }
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location permission denied.")));
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location permissions are permanently denied.")));
        return;
      }
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fetching location...")));
      
      Position? position = await Geolocator.getCurrentPosition(timeLimit: const Duration(seconds: 10))
          .catchError((e) async {
        return await Geolocator.getLastKnownPosition() ?? Position(longitude: 0, latitude: 0, timestamp: DateTime.now(), accuracy: 0, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0);
      });

      if (position.latitude == 0 && position.longitude == 0) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not determine your location.")));
        return;
      }

      setState(() {
        _messages.add({
          "locationName": "My Location",
          "locationCoords": "${position.latitude.toStringAsFixed(4)}° N, ${position.longitude.toStringAsFixed(4)}° E",
          "locationLat": position.latitude,
          "locationLng": position.longitude,
          "isMe": true,
          "time": _getCurrentTime(), "timestamp": DateTime.now().toIso8601String(),
          "status": "sent",
        });
      });
      _saveMessages();
    } catch (e) {
      debugPrint("Error getting location: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _handleSendContact() async {
    Navigator.pop(context); // Close the attachment menu

    final status = await Permission.contacts.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Contact permissions required to share contacts.")));
      }
      return;
    }

    final Contact? picked = await FlutterContacts.native.showPicker();
    if (picked != null) {
      Contact contact = picked;
      final String? pickedId = picked.id;
      if (pickedId != null && pickedId.isNotEmpty) {
        final Contact? fullContact = await FlutterContacts.get(
          pickedId,
          properties: {ContactProperty.phone},
        );
        if (fullContact != null) {
          contact = fullContact;
        }
      }

      final name = (contact.displayName ?? '').trim();
      final phone = contact.phones.isNotEmpty ? (contact.phones.first.number ?? "") : "";

      if (name.isNotEmpty) {
        setState(() {
          _messages.add({
            "contactName": name,
            "contactPhone": phone,
            "text": "Contact: $name",
            "isMe": true,
            "time": _getCurrentTime(), "timestamp": DateTime.now().toIso8601String(),
            "status": "sent",
          });
        });
        _saveMessages();
      }
    }
  }

  void _handleCreatePoll() {
    Navigator.pop(context);
    final questionController = TextEditingController();
    final List<TextEditingController> optControllers = [
      TextEditingController(),
      TextEditingController(),
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool isDark = Theme.of(context).brightness == Brightness.dark;
            final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
            final Color txtColor = isDark ? Colors.white : const Color(0xFF0F172A);
            final Color inputBg = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

            InputDecoration customInputDecoration(String hint) {
              return InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                filled: true,
                fillColor: inputBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF818CF8), width: 1.5)),
              );
            }

            return AlertDialog(
              backgroundColor: cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.poll_rounded, color: Color(0xFF818CF8)),
                  const SizedBox(width: 8),
                  Text("Create Poll", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: txtColor)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: questionController,
                        decoration: customInputDecoration("Ask a question..."),
                        style: TextStyle(color: txtColor, fontWeight: FontWeight.bold),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      ...optControllers.asMap().entries.map((entry) {
                        int idx = entry.key;
                        var controller = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: controller,
                                  decoration: customInputDecoration("Option ${idx + 1}"),
                                  style: TextStyle(color: txtColor, fontSize: 14),
                                ),
                              ),
                              if (optControllers.length > 2)
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
                                  onPressed: () {
                                    setDialogState(() {
                                      optControllers.removeAt(idx);
                                    });
                                  },
                                )
                            ],
                          ),
                        );
                      }),
                      if (optControllers.length < 6)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                optControllers.add(TextEditingController());
                              });
                            },
                            icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: Color(0xFF818CF8)),
                            label: const Text("Add Option", style: TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.w600)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final q = questionController.text.trim();
                    final options = optControllers
                        .map((c) => c.text.trim())
                        .where((text) => text.isNotEmpty)
                        .toList();

                    if (q.isNotEmpty && options.length >= 2) {
                      Navigator.pop(context);
                      setState(() {
                        _messages.add({
                          "pollQuestion": q,
                          "pollOptions": options.map((o) => {"text": o, "votes": 0}).toList(),
                          "text": "Poll: $q",
                          "isMe": true,
                          "time": _getCurrentTime(), "timestamp": DateTime.now().toIso8601String(),
                          "status": "sent",
                        });
                      });
                      _saveMessages();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF818CF8),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: const Text("Create", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showInAppNotification(String senderName, String messageText) {
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        return Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: -80.0, end: 0.0),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, value),
                  child: child,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF818CF8),
                      child: Text(
                        senderName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            senderName,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            messageText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(overlayEntry);
    HapticFeedback.vibrate();

    Future.delayed(const Duration(seconds: 3), () {
      overlayEntry.remove();
    });
  }

  String _getRealisticReply(String name) {
    if (name.contains("Admin")) {
      return "Got it, I will coordinate with the team.";
    } else if (name.contains("Security")) {
      return "Main campus gates are clear. All logs uploaded.";
    } else if (name.contains("Driver")) {
      return "Leaving the yard now. Will update on traffic.";
    } else if (name.contains("Maintenance")) {
      return "Work completed. Bus #42 is ready.";
    } else if (name.contains("HR")) {
      return "Acknowledged. Please submit by Friday.";
    } else {
      return "Received. I will look into it.";
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      final int msgIndex = _messages.length;
      setState(() {
        _messages.add({
          "text": text,
          "isMe": true,
          "time": _getCurrentTime(), "timestamp": DateTime.now().toIso8601String(),
          "status": "sent",
          "replyText": _replyingToMessage != null ? _replyingToMessage!['text'] : null,
        });
        _replyingToMessage = null;
      });
      _messageController.clear();
      FocusScope.of(context).unfocus();
      HapticFeedback.lightImpact();
      _saveMessages();
      _scrollToBottom();

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && msgIndex < _messages.length) {
          setState(() {
            _messages[msgIndex]['status'] = 'delivered';
          });
          HapticFeedback.selectionClick();
          _saveMessages();
        }
      });

      Future.delayed(const Duration(milliseconds: 3500), () {
        if (mounted && msgIndex < _messages.length) {
          setState(() {
            _messages[msgIndex]['status'] = 'read';
          });
          HapticFeedback.mediumImpact();
          _saveMessages();
        }
      });

      Future.delayed(const Duration(milliseconds: 6000), () {
        if (mounted) {
          final replyText = _getRealisticReply(widget.name);
          String senderName = widget.name;
          
          if (widget.isGroup) {
            List<String> members = ["John", "Sarah", "Mike", "Admin", "Driver Bob"];
            members.shuffle();
            senderName = members.first;
          }

          setState(() {
            _messages.add({
              "text": replyText,
              "isMe": false,
              "time": _getCurrentTime(), "timestamp": DateTime.now().toIso8601String(),
              "senderName": senderName,
            });
          });
          _showInAppNotification(senderName, replyText);
          _saveMessages();
        }
      });
    }
  }

  Widget _attachmentIcon(IconData icon, List<Color> gradientColors, String label, Color textColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: gradientColors[0].withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Icon(icon, color: Colors.white, size: 28),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final Color bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
        final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);

        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 20, left: 24, right: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _attachmentIcon(Icons.insert_photo_rounded, const [Color(0xFF8B5CF6), Color(0xFF818CF8)], "Photo", textColor, _handlePickPhoto),
                      _attachmentIcon(Icons.camera_alt_rounded, const [Color(0xFFF43F5E), Color(0xFFE11D48)], "Camera", textColor, _handleTakePhoto),
                      _attachmentIcon(Icons.insert_drive_file_rounded, const [Color(0xFF3B82F6), Color(0xFF2563EB)], "Document", textColor, _handlePickDocument),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _attachmentIcon(Icons.location_on_rounded, const [Color(0xFF10B981), Color(0xFF059669)], "Location", textColor, _handleSendLocation),
                      _attachmentIcon(Icons.person_rounded, const [Color(0xFF0EA5E9), Color(0xFF0284C7)], "Contact", textColor, _handleSendContact),
                      _attachmentIcon(Icons.poll_rounded, const [Color(0xFFF59E0B), Color(0xFFD97706)], "Poll", textColor, _handleCreatePoll),
                    ],
                  ),
                  if (_selectedMessageIndices.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.reply_rounded, color: textColor),
                      onPressed: () {
                        final firstIdx = _selectedMessageIndices.first;
                        setState(() {
                          _replyingToMessage = _messages[firstIdx];
                          _selectedMessageIndices.clear();
                        });
                      },
                    ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageTextWidget(String text, bool isMe, Color textColor, bool isDeleted) {
    final linkRegex = RegExp(r'(https?:\/\/[^\s]+)');
    final hasLink = linkRegex.hasMatch(text);

    Widget textWidget = Text(
      text,
      style: TextStyle(
        color: isMe ? Colors.white : textColor,
        fontSize: 15,
        height: 1.3,
        fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
        decoration: hasLink ? TextDecoration.underline : null,
      ),
    );

    if (hasLink) {
      return GestureDetector(
        onTap: () async {
          final match = linkRegex.firstMatch(text);
          if (match != null) {
            final url = match.group(0);
            if (url != null) {
              final isYoutube = url.contains('youtube.com') || url.contains('youtu.be');
              if (isYoutube) {
                final videoId = YoutubePlayerController.convertUrlToId(url);
                if (videoId != null) {
                  setState(() {
                    _inlineYoutubeUrl = url;
                    _inlineYoutubeController?.close();
                    _inlineYoutubeController = YoutubePlayerController.fromVideoId(
                      videoId: videoId,
                      autoPlay: true,
                      params: const YoutubePlayerParams(
                        showControls: true,
                        showFullscreenButton: true,
                      ),
                    );
                  });
                }
                return;
              }

              final uri = Uri.parse(url);
              try {
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              } catch (e) {
                debugPrint("Could not launch $url");
              }
            }
          }
        },
        child: textWidget,
      );
    }
    return textWidget;
  }

  Widget _buildImageStack(BuildContext context, Map<String, dynamic> message, bool isMe, Color subTextColor) {
    List<String> paths = List<String>.from(message['imagePaths']);
    int count = paths.length;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullScreenImageViewer(
              imagePaths: paths,
              senderName: message['senderName'] ?? (isMe ? 'You' : widget.name),
              time: _getFormattedRelativeTime(message['timestamp'], message['time']),
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, right: 4.0, left: 4.0),
            child: Text(
              isMe ? "You sent $count photos" : "${message['senderName'] ?? widget.name} sent $count photos",
              style: TextStyle(color: subTextColor, fontSize: 12),
            ),
          ),
          _buildCollage(paths),
        ],
      ),
    );
  }

  Widget _buildCollage(List<String> paths) {
    int count = paths.length;
    int displayCount = count > 5 ? 5 : count;

    return SizedBox(
      height: 220,
      width: 260,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(displayCount, (index) {
          // Progress from 0.0 (leftmost) to 1.0 (rightmost)
          double progress = displayCount <= 1 ? 0.5 : (index / (displayCount - 1));
          
          // Spread angle: e.g. from -0.3 to +0.3 radians
          double angle = -0.3 + (0.6 * progress);
          
          // Horizontal spread
          double offsetX = -60.0 + (120.0 * progress);
          
          // V-shape dip (edges are higher, center is lower)
          double vShapeLift = (progress - 0.5).abs() * -60.0;
          
          return Positioned(
            left: 65 + offsetX, 
            top: 50 + vShapeLift,
            width: 130,
            height: 150,
            child: Transform.rotate(
              angle: angle,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildCollageImage(paths[index]),
                  if (index == displayCount - 1 && count > displayCount)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "+${count - displayCount + 1}",
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCollageImage(String path) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 2), // Added white border for pop
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          cacheWidth: 600, // Optimize loading performance
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: frame != null
                  ? child
                  : Container(
                      color: Colors.grey.withValues(alpha: 0.1),
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF818CF8)),
                        ),
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryBlue = const Color(0xFF818CF8);
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final String? userRole = UserStore.role?.toLowerCase();
    bool isPermitted = true;
    
    if (widget.isGroup) {
      if (widget.permissions != null) {
        String permissionKey = "";
        if (userRole == 'super admin' || userRole == 'transport admin') {
          permissionKey = "Transport Admin";
        } else if (userRole == 'driver') {
          permissionKey = "Driver";
        } else if (userRole == 'security') {
          permissionKey = "Security";
        } else if (userRole == 'faculty') {
          permissionKey = "Faculty";
        } else if (userRole == 'student') {
          permissionKey = "Student";
        }
        
        if (permissionKey.isNotEmpty) {
          isPermitted = widget.permissions![permissionKey] ?? true;
        }
      } else {
        if (widget.name == 'Security Team') {
          isPermitted = userRole == 'super admin' || userRole == 'transport admin' || userRole == 'security';
        } else if (widget.name == 'Maintenance') {
          isPermitted = userRole == 'super admin' || userRole == 'transport admin' || userRole == 'driver' || userRole == 'security';
        } else if (widget.name == 'HR Department') {
          isPermitted = userRole == 'super admin' || userRole == 'transport admin';
        }
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedMessageIndices.isNotEmpty) {
          setState(() {
            _selectedMessageIndices.clear();
          });
          return;
        }
        final String lastMsg = _messages.isNotEmpty ? _messages.last['text'] : "";
        final String lastTime = _messages.isNotEmpty ? _messages.last['time'] : "";
        Navigator.pop(context, {
          "avatar": _currentAvatarUrl,
          "lastMessage": lastMsg,
          "lastTime": lastTime,
        });
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: _selectedMessageIndices.isNotEmpty
            ? AppBar(
                backgroundColor: surfaceColor,
                elevation: 0,
                scrolledUnderElevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.close_rounded, color: textColor),
                  onPressed: () {
                    setState(() {
                      _selectedMessageIndices.clear();
                    });
                  },
                ),
                title: Text(
                  "${_selectedMessageIndices.length}",
                  style: GoogleFonts.plusJakartaSans(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.reply_rounded, color: textColor),
                    onPressed: () {
                      setState(() {
                        _replyingToMessage = _messages[_selectedMessageIndices.first];
                        _selectedMessageIndices.clear();
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      _selectedMessageIndices.isNotEmpty && _messages[_selectedMessageIndices.first]['isStarred'] == true
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: _selectedMessageIndices.isNotEmpty && _messages[_selectedMessageIndices.first]['isStarred'] == true
                          ? const Color(0xFFF59E0B)
                          : textColor,
                    ),
                    onPressed: () {
                      for (var idx in _selectedMessageIndices) { _toggleStarMessage(idx); }
                        _selectedMessageIndices.clear();
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_rounded, color: textColor),
                    onPressed: () {
                      HapticFeedback.heavyImpact();
                      _showMultiDeleteDialog();
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.forward_rounded, color: textColor),
                    onPressed: () {
                      _showMultiForwardSheet();
                    },
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, color: textColor),
                    onSelected: (val) {
                      if (_selectedMessageIndices.isEmpty) return;
                      final selectedMsg = _messages[_selectedMessageIndices.first];
                      if (val == "info") {
                        _showMessageInfo(selectedMsg);
                      } else if (val == "copy") {
                        _copyMessage(selectedMsg);
                      } else if (val == "pin") {
                        _pinMessage(selectedMsg);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: "info",
                        child: Text("Info"),
                      ),
                      const PopupMenuItem(
                        value: "copy",
                        child: Text("Copy"),
                      ),
                      const PopupMenuItem(
                        value: "pin",
                        child: Text("Pin"),
                      ),
                    ],
                  ),
                ],
              )
            : AppBar(
                backgroundColor: surfaceColor,
                elevation: 0,
                scrolledUnderElevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
                  onPressed: () {
                    final String lastMsg = _messages.isNotEmpty ? _messages.last['text'] : "";
                    final String lastTime = _messages.isNotEmpty ? _messages.last['time'] : "";
                    Navigator.pop(context, {
                      "avatar": _currentAvatarUrl,
                      "lastMessage": lastMsg,
                      "lastTime": lastTime,
                    });
                  },
                ),
                titleSpacing: 0,
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            HapticFeedback.lightImpact();
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupInfoScreen(
                  name: widget.name,
                  avatarUrl: _currentAvatarUrl,
                  isGroup: widget.isGroup,
                ),
              ),
            );
            if (result == "delete" && context.mounted) {
              Navigator.pop(context, "delete");
            } else if (result == "clear" && context.mounted) {
              setState(() {
                _messages.clear();
              });
              _saveMessages();
            } else if (result != null && result is Map<String, dynamic> && result.containsKey("avatar")) {
              setState(() {
                _currentAvatarUrl = result["avatar"];
              });
            }
          },
          child: Row(
            children: [
              widget.isGroup
                  ? CircleAvatar(
                      radius: 18,
                      backgroundImage: _currentAvatarUrl.startsWith('http')
                          ? NetworkImage(_currentAvatarUrl)
                          : FileImage(File(_currentAvatarUrl)) as ImageProvider,
                      backgroundColor: Colors.grey.shade300,
                    )
                  : _buildInitialsAvatar(name: widget.name, radius: 18),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Online",
                    style: TextStyle(
                      color: primaryBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          if (widget.isGroup && (UserStore.role == "super admin" || UserStore.role == "transport admin"))
            IconButton(
              icon: const Icon(Icons.flash_on_rounded, color: Color(0xFF818CF8)),
              onPressed: _showQuickMessageDialog,
            ),
        ],
        shape: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      body: Column(
        children: [
          if (_inlineYoutubeUrl != null && _inlineYoutubeController != null)
            Container(
              margin: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      color: const Color(0xFF1E293B),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () async {
                              if (_inlineYoutubeUrl != null) {
                                final uri = Uri.parse(_inlineYoutubeUrl!);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              }
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.play_circle_fill_rounded, color: Colors.red, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  "Open in YouTube",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _inlineYoutubeUrl = null;
                                _inlineYoutubeController?.close();
                                _inlineYoutubeController = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                    YoutubePlayer(
                      controller: _inlineYoutubeController!,
                      aspectRatio: 16 / 9,
                    ),
                  ],
                ),
              ),
            ),
          if (_pinnedMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: primaryBlue.withValues(alpha: 0.12),
              child: Row(
                children: [
                  Icon(Icons.pin_drop_rounded, color: primaryBlue, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Pinned: $_pinnedMessage",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _pinnedMessage = null;
                      });
                    },
                    child: Icon(Icons.close_rounded, color: subTextColor, size: 16),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              reverse: true,
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final actualIndex = _messages.length - 1 - index;
                final message = _messages[actualIndex];
                final isMe = message['isMe'];
                final isSelected = _selectedMessageIndices.contains(actualIndex);

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: () {
                    HapticFeedback.heavyImpact();
                    setState(() {
                       _selectedMessageIndices.add(actualIndex);
                     });
                  },
                  onTap: () {
                    if (_selectedMessageIndices.isNotEmpty) {
                      setState(() {
                        if (_selectedMessageIndices.contains(actualIndex)) {
                          _selectedMessageIndices.remove(actualIndex);
                        } else {
                          _selectedMessageIndices.add(actualIndex);
                        }
                      });
                    }
                  },
                  child: Container(
                    color: isSelected
                         ? const Color(0xFF10B981).withValues(alpha: 0.15)
                         : Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: isMe ? Alignment.topRight : Alignment.topLeft,
                      children: [
                        Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Row(
                          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMe) ...[
                              if (message['avatarUrl'] != null)
                                CircleAvatar(
                                  radius: 12,
                                  backgroundImage: (message['avatarUrl'] as String).startsWith('http')
                                      ? NetworkImage(message['avatarUrl'])
                                      : FileImage(File(message['avatarUrl'])) as ImageProvider,
                                )
                              else
                                _buildInitialsAvatar(name: message['senderName'] ?? widget.name, radius: 12),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    padding: (message['imagePath'] != null || message['imagePaths'] != null)
                                        ? const EdgeInsets.all(4)
                                        : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: message['imagePaths'] != null ? Colors.transparent : (isMe ? primaryBlue : surfaceColor),
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(20),
                                        topRight: const Radius.circular(20),
                                        bottomLeft: Radius.circular(isMe ? 20 : 0),
                                        bottomRight: Radius.circular(isMe ? 0 : 20),
                                      ),
                                      boxShadow: message['imagePaths'] != null ? [] : [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.03),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                      border: (isMe || message['imagePaths'] != null) ? null : Border.all(
                                        color: isDark ? Colors.white10 : Colors.transparent,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        if (!isMe) ...[
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              message['senderName'] ?? widget.name,
                                              style: TextStyle(
                                                color: primaryBlue,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                        ],
                                        if (message['replyText'] != null) ...[
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(8),
                                            margin: const EdgeInsets.only(bottom: 6),
                                            decoration: BoxDecoration(
                                              color: isMe
                                                  ? Colors.white.withValues(alpha: 0.18)
                                                  : primaryBlue.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border(
                                                left: BorderSide(
                                                  color: isMe ? Colors.white : primaryBlue,
                                                  width: 3,
                                                ),
                                              ),
                                            ),
                                            child: Text(
                                              message['replyText'],
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: isMe ? Colors.white70 : subTextColor,
                                                fontSize: 12,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                        ],
                                        if (message['imagePaths'] != null) ...[
                                          _buildImageStack(context, message, isMe, subTextColor),
                                          const SizedBox(height: 4),
                                        ] else if (message['imagePath'] != null) ...[
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => FullScreenImageViewer(
                                                    imagePaths: [message['imagePath']],
                                                    senderName: message['senderName'] ?? (isMe ? 'You' : widget.name),
                                                    time: _getFormattedRelativeTime(message['timestamp'], message['time']),
                                                  ),
                                                ),
                                              );
                                            },
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(16),
                                              child: ConstrainedBox(
                                                constraints: const BoxConstraints(maxHeight: 320),
                                                child: Image.file(
                                                  File(message['imagePath']),
                                                  width: 240,
                                                  fit: BoxFit.cover,
                                                  cacheWidth: 600, // Optimize loading performance
                                                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                                    if (wasSynchronouslyLoaded) return child;
                                                    return AnimatedSwitcher(
                                                      duration: const Duration(milliseconds: 500),
                                                      child: frame != null
                                                          ? child
                                                          : Container(
                                                              width: 240,
                                                              height: 240, // Placeholder height while loading
                                                              color: Colors.grey.withValues(alpha: 0.1),
                                                              child: const Center(
                                                                child: SizedBox(
                                                                  width: 24,
                                                                  height: 24,
                                                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF818CF8)),
                                                                ),
                                                              ),
                                                            ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                        ],
                                        if (message['documentName'] != null) ...[
                                          GestureDetector(
                                            onTap: () async {
                                              if (message['documentPath'] != null) {
                                                final result = await OpenFilex.open(message['documentPath']);
                                                if (result.type != ResultType.done) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text("Could not open file: ${result.message}"), backgroundColor: Colors.redAccent),
                                                    );
                                                  }
                                                }
                                              } else {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text("File path not found. Try sending a new document."), backgroundColor: Colors.orange),
                                                );
                                              }
                                            },
                                            child: Container(
                                              width: 220,
                                              padding: const EdgeInsets.all(10),
                                              margin: const EdgeInsets.only(bottom: 6),
                                              decoration: BoxDecoration(
                                                color: isMe ? Colors.white.withValues(alpha: 0.18) : primaryBlue.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 32),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          message['documentName'],
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: TextStyle(
                                                            color: isMe ? Colors.white : textColor,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                        Text(
                                                          message['documentSize'] ?? '0 KB',
                                                          style: TextStyle(
                                                            color: isMe ? Colors.white70 : subTextColor,
                                                            fontSize: 11,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                        if (message['locationName'] != null || (message['locationLat'] != null && message['locationLng'] != null)) ...[
                                          GestureDetector(
                                            onTap: () async {
                                              if (message['locationLat'] != null && message['locationLng'] != null) {
                                                final lat = message['locationLat'];
                                                final lng = message['locationLng'];
                                                final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                                                if (await canLaunchUrl(url)) {
                                                  await launchUrl(url);
                                                }
                                              } else {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No coordinates found for this location.")));
                                                }
                                              }
                                            },
                                            child: Container(
                                              margin: const EdgeInsets.only(bottom: 2),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              clipBehavior: Clip.hardEdge,
                                              child: (message['locationLat'] != null && message['locationLng'] != null)
                                                  ? SizedBox(
                                                      height: 160,
                                                      width: 230,
                                                      child: IgnorePointer(
                                                        child: Stack(
                                                          children: [
                                                            FlutterMap(
                                                              options: MapOptions(
                                                                initialCenter: LatLng(message['locationLat'], message['locationLng']),
                                                                initialZoom: 15.0,
                                                                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                                                              ),
                                                              children: [
                                                                TileLayer(
                                                                  urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                                                                ),
                                                                MarkerLayer(
                                                                  markers: [
                                                                    Marker(
                                                                      point: LatLng(message['locationLat'], message['locationLng']),
                                                                      width: 40,
                                                                      height: 40,
                                                                      child: const AnimatedLocationMarker(),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                            Container(
                                                              decoration: BoxDecoration(
                                                                gradient: LinearGradient(
                                                                  begin: Alignment.topCenter,
                                                                  end: Alignment.bottomCenter,
                                                                  colors: [
                                                                    Colors.black.withValues(alpha: 0.0),
                                                                    Colors.black.withValues(alpha: 0.15),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    )
                                                  : SizedBox(
                                                      height: 160,
                                                      width: 230,
                                                      child: Center(
                                                        child: Icon(Icons.location_on_rounded, color: subTextColor, size: 50),
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        ],
                                        if (message['contactName'] != null) ...[
                                          GestureDetector(
                                            onTap: () async {
                                              final phone = message['contactPhone'];
                                              if (phone != null && phone.toString().isNotEmpty) {
                                                final cleanPhone = phone.toString().replaceAll(RegExp(r'[^\d+]'), '');
                                                final Uri uri = Uri(scheme: 'tel', path: cleanPhone);
                                                try {
                                                  final success = await launchUrl(uri);
                                                  if (!success && context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not open dialer for $cleanPhone")));
                                                  }
                                                } catch (e) {
                                                  debugPrint("Could not launch $uri: $e");
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error opening dialer: $e")));
                                                  }
                                                }
                                              } else {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No phone number available for this contact.")));
                                                }
                                              }
                                            },
                                            child: Container(
                                              width: 220,
                                              padding: const EdgeInsets.all(10),
                                              margin: const EdgeInsets.only(bottom: 6),
                                              decoration: BoxDecoration(
                                                color: isMe ? Colors.white.withValues(alpha: 0.18) : primaryBlue.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      _buildInitialsAvatar(name: message['contactName'], radius: 14),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          message['contactName'],
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: TextStyle(
                                                            color: isMe ? Colors.white : textColor,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    message['contactPhone'] ?? '',
                                                    style: TextStyle(
                                                      color: isMe ? Colors.white70 : subTextColor,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                        if (message['pollQuestion'] != null) ...[
                                          Container(
                                            width: 240,
                                            padding: const EdgeInsets.all(10),
                                            margin: const EdgeInsets.only(bottom: 6),
                                            decoration: BoxDecoration(
                                              color: isMe ? Colors.white.withValues(alpha: 0.18) : primaryBlue.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  message['pollQuestion'],
                                                  style: TextStyle(
                                                    color: isMe ? Colors.white : textColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Builder(
                                                  builder: (context) {
                                                    int totalVotes = 0;
                                                    for (var opt in message['pollOptions']) {
                                                      totalVotes += (opt['votes'] as int?) ?? 0;
                                                    }
                                                    return Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        ...(message['pollOptions'] as List).map((opt) {
                                                          final int votes = opt['votes'] ?? 0;
                                                          final bool hasVoted = opt['hasVoted'] ?? false;
                                                          final double percentage = totalVotes > 0 ? (votes / totalVotes) : 0.0;
                                                          
                                                          return GestureDetector(
                                                            onTap: () {
                                                              HapticFeedback.lightImpact();
                                                              setState(() {
                                                                if (hasVoted) {
                                                                  opt['votes'] = votes - 1;
                                                                  opt['hasVoted'] = false;
                                                                } else {
                                                                  for (var o in message['pollOptions']) {
                                                                    if (o['hasVoted'] == true) {
                                                                      o['votes'] = (o['votes'] ?? 1) - 1;
                                                                      o['hasVoted'] = false;
                                                                    }
                                                                  }
                                                                  opt['votes'] = (opt['votes'] ?? 0) + 1;
                                                                  opt['hasVoted'] = true;
                                                                }
                                                              });
                                                              _saveMessages();
                                                            },
                                                            child: Container(
                                                              margin: const EdgeInsets.only(bottom: 6),
                                                              clipBehavior: Clip.hardEdge,
                                                              decoration: BoxDecoration(
                                                                color: isMe ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
                                                                borderRadius: BorderRadius.circular(8),
                                                                border: hasVoted ? Border.all(color: isMe ? Colors.white : primaryBlue, width: 1.5) : null,
                                                              ),
                                                              child: Stack(
                                                                children: [
                                                                  if (percentage > 0)
                                                                    Positioned.fill(
                                                                      child: FractionallySizedBox(
                                                                        alignment: Alignment.centerLeft,
                                                                        widthFactor: percentage,
                                                                        child: AnimatedContainer(
                                                                          duration: const Duration(milliseconds: 300),
                                                                          color: isMe ? Colors.white24 : primaryBlue.withValues(alpha: 0.2),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  Container(
                                                                    height: 36,
                                                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                                                    alignment: Alignment.centerLeft,
                                                                    child: Row(
                                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                      children: [
                                                                        Expanded(
                                                                          child: Text(
                                                                            opt['text'],
                                                                            style: TextStyle(
                                                                              color: isMe ? Colors.white : textColor,
                                                                              fontSize: 12,
                                                                              fontWeight: hasVoted ? FontWeight.bold : FontWeight.normal,
                                                                            ),
                                                                            maxLines: 1,
                                                                            overflow: TextOverflow.ellipsis,
                                                                          ),
                                                                        ),
                                                                        Text(
                                                                          totalVotes > 0 ? "${(percentage * 100).toInt()}%" : "0%",
                                                                          style: TextStyle(
                                                                            color: isMe ? (hasVoted ? Colors.white : Colors.white70) : (hasVoted ? textColor : subTextColor),
                                                                            fontSize: 11,
                                                                            fontWeight: hasVoted ? FontWeight.bold : FontWeight.normal,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          );
                                                        }),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          "$totalVotes vote${totalVotes == 1 ? '' : 's'}",
                                                          style: TextStyle(
                                                            color: isMe ? Colors.white70 : subTextColor,
                                                            fontSize: 10,
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  }
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        if (message['text'] != null && !(message['imagePath'] != null && message['text'] == 'Photo') && !(message['imagePaths'] != null && message['text'] == 'Photos'))
                                          _buildMessageTextWidget(
                                            message['text'],
                                            isMe,
                                            textColor,
                                            message['isDeleted'] == true,
                                          ),
                                        if ((message['imagePath'] == null && message['imagePaths'] == null) || (message['text'] != null && message['text'] != 'Photo' && message['text'] != 'Photos'))
                                          const SizedBox(height: 4),
                                        Padding(
                                          padding: (message['imagePath'] != null || message['imagePaths'] != null)
                                              ? const EdgeInsets.only(right: 8, bottom: 4)
                                              : EdgeInsets.zero,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (message['isStarred'] == true) ...[
                                                const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF59E0B)),
                                                const SizedBox(width: 4),
                                              ],
                                              Text(
                                                _getFormattedRelativeTime(message['timestamp'], message['time']),
                                                style: TextStyle(
                                                  color: (isMe && message['imagePaths'] == null) ? Colors.white70 : subTextColor,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              if (isMe) ...[
                                                const SizedBox(width: 4),
                                                Icon(
                                                  message['status'] == 'sent'
                                                      ? Icons.check_rounded
                                                      : Icons.done_all_rounded,
                                                  size: 14,
                                                  color: message['status'] == 'read'
                                                      ? const Color(0xFF34D399) // Emerald green for read
                                                      : Colors.white, // Solid white for sent/delivered
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (message['reaction'] != null)
                                    Positioned(
                                      bottom: -10,
                                      right: isMe ? null : 10,
                                      left: isMe ? 10 : null,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          message['reaction'],
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 8),
                              const CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.transparent,
                              ),
                            ],
                          ],
                        ), // End of Row
                      ], // End of Column children
                    ), // End of Column
                    if (isSelected && _selectedMessageIndices.length == 1)
                      Positioned(
                        top: -15, // Overlaps the top edge of the bubble
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                              border: Border.all(
                                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: ["👍", "❤️", "😂", "😮", "😢", "🙏", "💙"].map((emoji) {
                                final bool isSelectedEmoji = message['reaction'] == emoji;
                                return GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setState(() {
                                      if (message['reaction'] == emoji) {
                                        message.remove('reaction');
                                      } else {
                                        message['reaction'] = emoji;
                                      }
                                      _selectedMessageIndices.clear();
                                    });
                                    _saveMessages();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                                    decoration: isSelectedEmoji
                                        ? BoxDecoration(
                                            color: const Color(0xFF818CF8).withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(12),
                                          )
                                        : null,
                                    child: Text(
                                      emoji,
                                      style: const TextStyle(fontSize: 22),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                  ], // End of Stack children
                ), // End of Stack
              ), // End of Container
            ); // End of GestureDetector
          }, // End of itemBuilder
        ),
      ),
          
          if (_replyingToMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border(
                  top: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                  left: BorderSide(color: primaryBlue, width: 4),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (_replyingToMessage!['avatarUrl'] != null)
                          CircleAvatar(
                            radius: 12,
                            backgroundImage: (_replyingToMessage!['avatarUrl'] as String).startsWith('http')
                                ? NetworkImage(_replyingToMessage!['avatarUrl'])
                                : FileImage(File(_replyingToMessage!['avatarUrl'])) as ImageProvider,
                          )
                        else
                          const SizedBox(width: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Replying to ${_replyingToMessage!['isMe'] ? 'Yourself' : _replyingToMessage!['senderName'] ?? widget.name}",
                                style: GoogleFonts.plusJakartaSans(
                                  color: primaryBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _replyingToMessage!['text'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  color: subTextColor,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: subTextColor, size: 18),
                          onPressed: () {
                            setState(() {
                              _replyingToMessage = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: surfaceColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: isPermitted
                ? Row(
                    children: [
                      IconButton(
                        onPressed: () => _showAttachmentMenu(context),
                        icon: Icon(Icons.add_circle_outline_rounded, color: subTextColor, size: 26),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: TextField(
                            controller: _messageController,
                            style: TextStyle(color: textColor, fontSize: 15),
                            decoration: InputDecoration(
                              hintText: "Message...",
                              hintStyle: TextStyle(color: subTextColor),
                              border: InputBorder.none,
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _sendMessage,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: primaryBlue,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primaryBlue.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline_rounded, color: subTextColor, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            "Only permitted roles can send messages to this group.",
                            style: TextStyle(
                              color: subTextColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}
}

class AnimatedLocationMarker extends StatefulWidget {
  const AnimatedLocationMarker({super.key});

  @override
  State<AnimatedLocationMarker> createState() => _AnimatedLocationMarkerState();
}

class _AnimatedLocationMarkerState extends State<AnimatedLocationMarker> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), // Faster pulse
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Instantiate here to avoid LateInitializationError on Hot Reload
    final curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    );

    return AnimatedBuilder(
      animation: curvedAnimation,
      builder: (context, child) {
        // Completely shrinks to 0 and expands to 1.5
        final scale = curvedAnimation.value * 1.5;
        // Fades out as it expands
        final opacity = 1.0 - curvedAnimation.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: scale,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF818CF8).withValues(alpha: 0.6 * opacity),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF818CF8),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF818CF8).withValues(alpha: 0.6),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

