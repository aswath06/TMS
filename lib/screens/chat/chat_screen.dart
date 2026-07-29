import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripzo/store/user_store.dart';
import 'chat_detail_screen.dart';
import 'create_group_screens.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  int _selectedFilterIndex = 0;
  final List<String> _filters = ['All', 'Unread', 'Groups'];
  bool _isSearching = false;
  String _searchQuery = '';
  final List<Map<String, dynamic>> _chats = [
    {
      'name': 'Transport Admin',
      'message': 'Please ensure the bus leaves at 8:00 AM.',
      'time': '10:30 AM',
      'unread': 2,
      'avatar': '',
    },
    {
      'name': 'Security Team',
      'message': 'All vehicles checked for today.',
      'time': '09:15 AM',
      'unread': 0,
      'avatar': '',
      'isGroup': true,
    },
    {
      'name': 'Driver John',
      'message': 'Route 5 has heavy traffic.',
      'time': 'Yesterday',
      'unread': 1,
      'avatar': '',
    },
    {
      'name': 'Support Hub',
      'message': 'How can we help you? I need assistance with my account.',
      'time': 'Yesterday',
      'unread': 0,
      'avatar': '',
    },
    {
      'name': 'Maintenance',
      'message': 'Bus #42 is ready for pickup in the garage.',
      'time': 'Monday',
      'unread': 0,
      'avatar': '',
    },
    {
      'name': 'HR Department',
      'message': 'Please submit your timesheet by Friday.',
      'time': 'Last Week',
      'unread': 0,
      'avatar': '',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString('chat_list_state');
      if (jsonStr != null) {
        final List<dynamic> decoded = json.decode(jsonStr);
        setState(() {
          _chats.clear();
          for (var c in decoded) {
            var map = Map<String, dynamic>.from(c);
            if (map['avatar'] != null && map['avatar'].toString().contains('pravatar.cc')) {
              map['avatar'] = '';
            }
            _chats.add(map);
          }
        });
      } else {
        _loadCustomAvatars();
      }
    } catch (e) {
      debugPrint("Error loading chats: $e");
    }
  }

  Future<void> _saveChats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonStr = json.encode(_chats);
      await prefs.setString('chat_list_state', jsonStr);
    } catch (e) {
      debugPrint("Error saving chats: $e");
    }
  }

  Future<void> _loadCustomAvatars() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        for (var chat in _chats) {
          final savedAvatar = prefs.getString('group_avatar_${chat['name']}');
          if (savedAvatar != null) {
            chat['avatar'] = savedAvatar;
          }
        }
      });
    } catch (e) {
      debugPrint("Error loading group avatars: $e");
    }
  }

  Future<void> _saveGroupAvatar(String groupName, String avatarPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('group_avatar_$groupName', avatarPath);
    } catch (e) {
      debugPrint("Error saving group avatar: $e");
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return "";
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    } else if (parts[0].length >= 2) {
      return parts[0].substring(0, 2).toUpperCase();
    } else {
      return parts[0][0].toUpperCase();
    }
  }

  Widget _buildInitialsAvatar({
    required String name,
    required double radius,
  }) {
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
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color primaryBlue = const Color(0xFF818CF8);
    final Color surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    final String? role = UserStore.role?.toLowerCase();
    final bool canCreateGroup = role == 'super admin' || role == 'transport admin';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background decorative circles for a premium feel
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    primaryBlue.withValues(alpha: isDark ? 0.15 : 0.08),
                    primaryBlue.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 200,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFEC4899).withValues(alpha: isDark ? 0.1 : 0.05),
                    const Color(0xFFEC4899).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (_isSearching)
                        Expanded(
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    autofocus: true,
                                    onChanged: (value) {
                                      setState(() {
                                        _searchQuery = value;
                                      });
                                    },
                                    style: TextStyle(color: titleColor, fontSize: 16),
                                    decoration: InputDecoration(
                                      hintText: "Search messages...",
                                      hintStyle: TextStyle(color: subColor),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: Icon(Icons.close_rounded, color: subColor, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _isSearching = false;
                                      _searchQuery = '';
                                    });
                                    HapticFeedback.lightImpact();
                                  },
                                ),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Messages",
                              style: TextStyle(
                                fontSize: screenWidth * 0.085,
                                fontWeight: FontWeight.w900,
                                color: titleColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "${_chats.fold<int>(0, (sum, c) => sum + (c['unread'] as int? ?? 0))} New Messages",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: primaryBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.04),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(Icons.search_rounded, color: titleColor, size: 26),
                            onPressed: () {
                              setState(() {
                                _isSearching = true;
                              });
                              HapticFeedback.lightImpact();
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                    itemCount: _filters.length,
                    itemBuilder: (context, index) {
                      final isSelected = _selectedFilterIndex == index;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedFilterIndex = index;
                          });
                          HapticFeedback.lightImpact();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? primaryBlue : (isDark ? surfaceColor : Colors.white),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? primaryBlue : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                            ),
                            boxShadow: isSelected ? [
                              BoxShadow(
                                color: primaryBlue.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ] : [],
                          ),
                          child: Center(
                            child: Text(
                              index == 1
                                  ? (() {
                                      final count = _chats.where((c) => (c['unread'] as int? ?? 0) > 0).length;
                                      return count > 0 ? "Unread ($count)" : "Unread";
                                    })()
                                  : index == 2
                                      ? (() {
                                          final count = _chats.where((c) => c['isGroup'] == true && (c['unread'] as int? ?? 0) > 0).length;
                                          return count > 0 ? "Groups ($count)" : "Groups";
                                        })()
                                      : _filters[index],
                              style: TextStyle(
                                color: isSelected ? Colors.white : subColor,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    List<Map<String, dynamic>> filteredChats = _chats;
                    if (_selectedFilterIndex == 1) {
                      filteredChats = filteredChats.where((c) => (c['unread'] as int) > 0).toList();
                    } else if (_selectedFilterIndex == 2) {
                      filteredChats = filteredChats.where((c) => c['isGroup'] == true).toList();
                    }
                    
                    if (_searchQuery.isNotEmpty) {
                      final query = _searchQuery.toLowerCase();
                      filteredChats = filteredChats.where((c) {
                        final name = c['name'].toString().toLowerCase();
                        final msg = c['message'].toString().toLowerCase();
                        return name.contains(query) || msg.contains(query);
                      }).toList();
                    }
                    
                    return Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.only(
                          left: screenWidth * 0.05,
                          right: screenWidth * 0.05,
                          bottom: 120, // Padding for bottom nav & FAB
                        ),
                        itemCount: filteredChats.length,
                        itemBuilder: (context, index) {
                          final chat = filteredChats[index];
                          final bool isUnread = chat['unread'] > 0;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isUnread 
                              ? primaryBlue.withValues(alpha: 0.3)
                              : (isDark ? Colors.white10 : Colors.transparent),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isUnread
                                  ? primaryBlue.withValues(alpha: 0.08)
                                  : (isDark ? Colors.black12 : Colors.black.withValues(alpha: 0.02)),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () async {
                              HapticFeedback.selectionClick();
                              setState(() {
                                chat['unread'] = 0;
                              });
                              _saveChats();
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatDetailScreen(
                                    name: chat['name'],
                                    avatarUrl: chat['avatar'],
                                    isGroup: chat['isGroup'] ?? false,
                                    permissions: chat['permissions'],
                                  ),
                                ),
                              );
                              if (result == "delete") {
                                setState(() {
                                  _chats.removeWhere((c) => c['name'] == chat['name']);
                                });
                                _saveChats();
                              } else if (result != null && result is Map<String, dynamic>) {
                                setState(() {
                                  if (result.containsKey("avatar")) {
                                    chat['avatar'] = result['avatar'];
                                  }
                                  if (result.containsKey("lastMessage")) {
                                    chat['message'] = result['lastMessage'];
                                  }
                                  if (result.containsKey("lastTime")) {
                                    chat['time'] = result['lastTime'];
                                  }
                                });
                                _saveChats();
                                if (result.containsKey("avatar")) {
                                  _saveGroupAvatar(chat['name'], result['avatar']);
                                }
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  // Avatar with optional unread indicator ring
                                  Container(
                                    padding: const EdgeInsets.all(2.5),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: isUnread 
                                          ? LinearGradient(
                                              colors: [primaryBlue, const Color(0xFF818CF8)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                          : null,
                                    ),
                                    child: (chat['avatar'] == null || chat['avatar'].toString().isEmpty)
                                        ? _buildInitialsAvatar(name: chat['name'], radius: 26)
                                        : CircleAvatar(
                                            radius: 26,
                                            backgroundColor: surfaceColor,
                                            child: CircleAvatar(
                                              radius: 24,
                                              backgroundImage: chat['avatar'].startsWith('http')
                                                  ? NetworkImage(chat['avatar'])
                                                  : FileImage(File(chat['avatar'])) as ImageProvider,
                                              backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 16),
                                  
                                  // Message Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              chat['name'],
                                              style: TextStyle(
                                                fontWeight: isUnread ? FontWeight.w800 : FontWeight.w700,
                                                fontSize: 16,
                                                color: titleColor,
                                                letterSpacing: -0.3,
                                              ),
                                            ),
                                            Text(
                                              chat['time'],
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isUnread ? primaryBlue : subColor,
                                                fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                chat['message'],
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: isUnread ? titleColor : subColor,
                                                  fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            if (isUnread) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: primaryBlue,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  chat['unread'].toString(),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              )
                                            ]
                                          ],
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
                  ),
                );
              },
            ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: canCreateGroup
          ? Padding(
              padding: const EdgeInsets.only(bottom: 95.0, right: 10.0), // Above bottom nav
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: FloatingActionButton(
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    final newGroup = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SelectMembersScreen(),
                      ),
                    );
                    if (newGroup != null && newGroup is Map<String, dynamic>) {
                      setState(() {
                        _chats.insert(0, newGroup);
                      });
                      _saveChats();
                    }
                  },
                  backgroundColor: primaryBlue,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.edit_rounded, color: Colors.white, size: 26),
                ),
              ),
            )
          : null,
    );
  }
}
