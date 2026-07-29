import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tripzo/screens/chat/full_screen_image_viewer.dart';
import 'package:tripzo/store/user_store.dart';
import 'manage_storage_screen.dart';
import 'starred_messages_screen.dart';
import 'media_links_docs_screen.dart';

class GroupInfoScreen extends StatefulWidget {
  final String name;
  final String avatarUrl;
  final bool isGroup;

  const GroupInfoScreen({
    super.key,
    required this.name,
    required this.avatarUrl,
    required this.isGroup,
  });

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  late String _groupName;
  late String _avatarUrl;
  XFile? _localImageFile;

  // Persisted list of members
  List<Map<String, String>> _members = [];

  // Group Permissions
  bool _canEditInfo = true;
  bool _canSendMessages = true;
  bool _canAddMembers = true;

  // Notification Settings
  bool _isMuted = false;
  String _notifyFor = 'all'; // 'all', 'highlights'
  String _vibrateMode = 'default'; // 'off', 'default', 'short', 'long'

  // Real shared media
  List<String> _mediaList = [];
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _groupName = widget.name;
    _avatarUrl = widget.avatarUrl;
    _loadChatMedia();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load Permissions & Notifications
      setState(() {
        _canEditInfo = prefs.getBool('group_perm_edit_${widget.name}') ?? true;
        _canSendMessages = prefs.getBool('group_perm_msg_${widget.name}') ?? true;
        _canAddMembers = prefs.getBool('group_perm_add_${widget.name}') ?? true;

        _isMuted = prefs.getBool('group_notif_mute_${widget.name}') ?? false;
        _notifyFor = prefs.getString('group_notif_for_${widget.name}') ?? 'all';
        _vibrateMode = prefs.getString('group_notif_vibe_${widget.name}') ?? 'default';
      });

      // Load Members
      final String? membersJson = prefs.getString('group_members_${widget.name}');
      if (membersJson != null) {
        final List<dynamic> decoded = json.decode(membersJson);
        setState(() {
          _members = decoded.map((e) => Map<String, String>.from(e)).toList();
        });
      } else {
        // Initialize with defaults if empty
        setState(() {
          _members = [
            {"name": "Transport Admin", "role": "Transport Admin", "avatar": ""},
            {"name": "Security Team", "role": "Security", "avatar": ""},
            {"name": "Driver John", "role": "Driver", "avatar": ""},
            {"name": "Support Hub", "role": "Faculty", "avatar": ""},
          ];
        });
        _saveMembers();
      }
    } catch (e) {
      debugPrint("Error loading group settings: $e");
    }
  }

  Future<void> _saveMembers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('group_members_${widget.name}', json.encode(_members));
  }

  Future<void> _loadChatMedia() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString('chat_messages_${widget.name}');
      if (jsonStr != null) {
        final List<dynamic> decoded = json.decode(jsonStr);
        List<String> media = [];
        List<Map<String, dynamic>> allMsgs = [];
        for (var m in decoded) {
          final Map<String, dynamic> msg = Map<String, dynamic>.from(m);
          allMsgs.add(msg);
          if (msg['imagePaths'] != null) {
            List<String> paths = List<String>.from(msg['imagePaths']);
            media.addAll(paths);
          } else if (msg['imagePath'] != null) {
            media.add(msg['imagePath']);
          }
        }
        if (mounted) {
          setState(() {
            _messages = allMsgs;
            _mediaList = media.reversed.toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading chat media: $e");
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
    const Color brandColor = Color(0xFF6366F1);
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

  Future<void> _changeProfilePicture() async {
    HapticFeedback.mediumImpact();
    final ImagePicker picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final Color txtColor = isDark ? Colors.white : const Color(0xFF0F172A);

        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Change Profile Photo",
                style: GoogleFonts.plusJakartaSans(
                  color: txtColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF6366F1)),
                title: Text("Choose from Gallery", style: GoogleFonts.plusJakartaSans(color: txtColor)),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 80,
                    );
                    if (image != null) {
                      setState(() {
                        _localImageFile = image;
                      });
                      HapticFeedback.lightImpact();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Profile picture updated from Gallery!"),
                          backgroundColor: Color(0xFF6366F1),
                        ),
                      );
                    }
                  } catch (e) {
                    debugPrint("Error picking image: $e");
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF6366F1)),
                title: Text("Take Photo", style: GoogleFonts.plusJakartaSans(color: txtColor)),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 80,
                    );
                    if (image != null) {
                      setState(() {
                        _localImageFile = image;
                      });
                      HapticFeedback.lightImpact();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Profile picture updated from Camera!"),
                          backgroundColor: Color(0xFF6366F1),
                        ),
                      );
                    }
                  } catch (e) {
                    debugPrint("Error taking photo: $e");
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditAdminsSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final Color txtColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final Color subTxtColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        const Color brandColor = Color(0xFF6366F1);

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: subTxtColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Edit Group Admins",
                          style: GoogleFonts.plusJakartaSans(
                            color: txtColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: subTxtColor),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _members.length,
                      itemBuilder: (context, index) {
                        final member = _members[index];
                        final String role = member["role"]?.toLowerCase() ?? "";
                        final bool isMemberAdmin = role.contains("admin");

                        return ListTile(
                          leading: _buildInitialsAvatar(name: member["name"] ?? "User", radius: 20),
                          title: Text(
                            member["name"] ?? "",
                            style: GoogleFonts.plusJakartaSans(color: txtColor, fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            isMemberAdmin ? "Admin" : "Member",
                            style: GoogleFonts.plusJakartaSans(
                              color: isMemberAdmin ? brandColor : subTxtColor,
                              fontWeight: isMemberAdmin ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                          trailing: Switch(
                            value: isMemberAdmin,
                            activeColor: brandColor,
                            onChanged: (val) {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _members[index]["role"] = val ? "Admin" : "Member";
                              });
                              setModalState(() {});
                              _saveMembers();
                            },
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
      },
    );
  }

  void _showAddMembersSheet() {
    HapticFeedback.mediumImpact();
    
    // Sample app users list
    final List<Map<String, String>> appUsers = [
      {"name": "Transport Admin", "role": "Transport Admin", "avatar": ""},
      {"name": "Security Team", "role": "Security", "avatar": ""},
      {"name": "Driver John", "role": "Driver", "avatar": ""},
      {"name": "Support Hub", "role": "Faculty", "avatar": ""},
      {"name": "Maintenance", "role": "Staff", "avatar": ""},
      {"name": "HR Department", "role": "Staff", "avatar": ""},
      {"name": "Jane Smith", "role": "Student", "avatar": ""},
      {"name": "Robert Brown", "role": "Student", "avatar": ""},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final Color txtColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final Color subTxtColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        const Color brandColor = Color(0xFF6366F1);

        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: subTxtColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text("Add Members", style: GoogleFonts.plusJakartaSans(color: txtColor, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: appUsers.length,
                  itemBuilder: (context, index) {
                    final user = appUsers[index];
                    final bool isAlreadyMember = _members.any((m) => m["name"] == user["name"]);

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _buildInitialsAvatar(name: user["name"]!, radius: 20),
                      title: Text(user["name"]!, style: GoogleFonts.plusJakartaSans(color: txtColor, fontWeight: FontWeight.w600)),
                      subtitle: Text(user["role"]!, style: GoogleFonts.plusJakartaSans(color: subTxtColor, fontSize: 13)),
                      trailing: isAlreadyMember
                          ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                          : IconButton(
                              icon: const Icon(Icons.person_add_rounded, color: brandColor),
                              onPressed: () {
                                setState(() {
                                  _members.add({
                                    "name": user["name"]!,
                                    "role": user["role"]!,
                                    "avatar": "",
                                  });
                                  _saveMembers();
                                });
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("${user["name"]} added to the group"), backgroundColor: brandColor),
                                );
                              },
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

  void _showNotificationsSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final Color txtColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final Color subTxtColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        const Color brandColor = Color(0xFF6366F1);

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: subTxtColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Notifications",
                          style: GoogleFonts.plusJakartaSans(
                            color: txtColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: subTxtColor),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeColor: brandColor,
                          title: Text("Mute notifications", style: GoogleFonts.plusJakartaSans(color: txtColor, fontWeight: FontWeight.w600)),
                          value: _isMuted,
                          onChanged: (val) async {
                            HapticFeedback.selectionClick();
                            setState(() => _isMuted = val);
                            setModalState(() {});
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('group_notif_mute_${widget.name}', val);
                          },
                        ),
                        const Divider(height: 32),
                        Text(
                          "Notify For",
                          style: GoogleFonts.plusJakartaSans(
                            color: brandColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildRadioTile("All messages", 'all', _notifyFor, (val) async {
                          HapticFeedback.selectionClick();
                          setState(() => _notifyFor = val!);
                          setModalState(() {});
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('group_notif_for_${widget.name}', val!);
                        }, txtColor, brandColor),
                        _buildRadioTile("Highlights", 'highlights', _notifyFor, (val) async {
                          HapticFeedback.selectionClick();
                          setState(() => _notifyFor = val!);
                          setModalState(() {});
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('group_notif_for_${widget.name}', val!);
                        }, txtColor, brandColor),
                        const Divider(height: 32),
                        Text(
                          "Vibrate",
                          style: GoogleFonts.plusJakartaSans(
                            color: brandColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildRadioTile("Off", 'off', _vibrateMode, (val) async {
                          HapticFeedback.selectionClick();
                          setState(() => _vibrateMode = val!);
                          setModalState(() {});
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('group_notif_vibe_${widget.name}', val!);
                        }, txtColor, brandColor),
                        _buildRadioTile("Default", 'default', _vibrateMode, (val) async {
                          HapticFeedback.selectionClick();
                          setState(() => _vibrateMode = val!);
                          setModalState(() {});
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('group_notif_vibe_${widget.name}', val!);
                        }, txtColor, brandColor),
                        _buildRadioTile("Short", 'short', _vibrateMode, (val) async {
                          HapticFeedback.selectionClick();
                          setState(() => _vibrateMode = val!);
                          setModalState(() {});
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('group_notif_vibe_${widget.name}', val!);
                        }, txtColor, brandColor),
                        _buildRadioTile("Long", 'long', _vibrateMode, (val) async {
                          HapticFeedback.selectionClick();
                          setState(() => _vibrateMode = val!);
                          setModalState(() {});
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('group_notif_vibe_${widget.name}', val!);
                        }, txtColor, brandColor),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRadioTile(String title, String value, String groupValue, ValueChanged<String?> onChanged, Color txtColor, Color activeColor) {
    return RadioListTile<String>(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: GoogleFonts.plusJakartaSans(color: txtColor, fontWeight: FontWeight.w600)),
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      activeColor: activeColor,
    );
  }

  void _showGroupPermissionsSheet() {
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final Color txtColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final Color subTxtColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        const Color brandColor = Color(0xFF6366F1);



        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: subTxtColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Group Permissions",
                          style: GoogleFonts.plusJakartaSans(
                            color: txtColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: subTxtColor),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        Text(
                          "Members can:",
                          style: GoogleFonts.plusJakartaSans(
                            color: brandColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeColor: brandColor,
                          title: Text("Edit group info", style: GoogleFonts.plusJakartaSans(color: txtColor, fontWeight: FontWeight.w600)),
                          subtitle: Text("Change name, icon, description", style: GoogleFonts.plusJakartaSans(color: subTxtColor, fontSize: 13)),
                          value: _canEditInfo,
                          onChanged: (val) async {
                            HapticFeedback.selectionClick();
                            setState(() => _canEditInfo = val);
                            setModalState(() {});
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('group_perm_edit_${widget.name}', val);
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeColor: brandColor,
                          title: Text("Send messages", style: GoogleFonts.plusJakartaSans(color: txtColor, fontWeight: FontWeight.w600)),
                          value: _canSendMessages,
                          onChanged: (val) async {
                            HapticFeedback.selectionClick();
                            setState(() => _canSendMessages = val);
                            setModalState(() {});
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('group_perm_msg_${widget.name}', val);
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeColor: brandColor,
                          title: Text("Add other members", style: GoogleFonts.plusJakartaSans(color: txtColor, fontWeight: FontWeight.w600)),
                          value: _canAddMembers,
                          onChanged: (val) async {
                            HapticFeedback.selectionClick();
                            setState(() => _canAddMembers = val);
                            setModalState(() {});
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('group_perm_add_${widget.name}', val);
                          },
                        ),
                        const Divider(height: 32),
                        Text(
                          "Admins",
                          style: GoogleFonts.plusJakartaSans(
                            color: brandColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: brandColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.admin_panel_settings_rounded, color: brandColor, size: 20),
                          ),
                          title: Text("Edit group admins", style: GoogleFonts.plusJakartaSans(color: txtColor, fontWeight: FontWeight.w600)),
                          subtitle: Text("Make new admins or remove them", style: GoogleFonts.plusJakartaSans(color: subTxtColor, fontSize: 13)),
                          trailing: const Icon(Icons.chevron_right_rounded, color: brandColor),
                          onTap: () {
                            Navigator.pop(context); // Close the permissions sheet
                            _showEditAdminsSheet();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteGroupDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            "Delete Group",
            style: GoogleFonts.plusJakartaSans(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            "Are you sure you want to delete this group? This action cannot be undone.",
            style: GoogleFonts.plusJakartaSans(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancel",
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context, "delete"); // Close group info screen and return "delete"
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Group deleted successfully"),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              },
              child: Text(
                "Delete",
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    const Color brandColor = Color(0xFF6366F1);

    // Permission checks
    final String? userRole = UserStore.role?.toLowerCase();
    final bool isAdmin = userRole != null && userRole.contains('admin');
    final bool canDeleteGroup = userRole != null && (userRole.contains('super admin') || userRole.contains('transport admin'));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final String avatarPath = _localImageFile != null ? _localImageFile!.path : _avatarUrl;
        Navigator.pop(context, {"avatar": avatarPath});
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: cardColor,
          elevation: 0.5,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: titleColor),
            onPressed: () {
              final String avatarPath = _localImageFile != null ? _localImageFile!.path : _avatarUrl;
              Navigator.pop(context, {"avatar": avatarPath});
            },
          ),
          title: Text(
            widget.isGroup ? "Group Info" : "Contact Info",
            style: GoogleFonts.plusJakartaSans(
              color: titleColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Profile Card
            Container(
              width: double.infinity,
              color: cardColor,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                children: [
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (_localImageFile != null) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImageViewer(imagePaths: [_localImageFile!.path], senderName: _groupName, time: "")));
                          } else if (_avatarUrl.isNotEmpty) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImageViewer(imagePaths: [_avatarUrl], senderName: _groupName, time: "")));
                          }
                        },
                        child: (_localImageFile != null)
                            ? CircleAvatar(
                                radius: 56,
                                backgroundImage: FileImage(File(_localImageFile!.path)),
                                backgroundColor: subColor.withValues(alpha: 0.1),
                              )
                            : (_avatarUrl.isNotEmpty)
                                ? ClipOval(
                                    child: _avatarUrl.startsWith('http')
                                        ? Image.network(
                                            _avatarUrl,
                                            width: 112,
                                            height: 112,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => _buildInitialsAvatar(name: _groupName, radius: 56),
                                          )
                                        : Image.file(
                                            File(_avatarUrl),
                                            width: 112,
                                            height: 112,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => _buildInitialsAvatar(name: _groupName, radius: 56),
                                          ),
                                  )
                                : _buildInitialsAvatar(name: _groupName, radius: 56),
                      ),
                      if (isAdmin && widget.isGroup)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: _changeProfilePicture,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: brandColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _groupName,
                    style: GoogleFonts.plusJakartaSans(
                      color: titleColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.isGroup ? "Group • ${_members.length} members" : "Personal Chat",
                    style: GoogleFonts.plusJakartaSans(
                      color: subColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isAdmin && widget.isGroup) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _changeProfilePicture,
                      icon: const Icon(Icons.edit_rounded, size: 16, color: brandColor),
                      label: Text(
                        "Change Group Icon",
                        style: GoogleFonts.plusJakartaSans(
                          color: brandColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ]
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Shared Media Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Media, links, and docs",
                    style: GoogleFonts.plusJakartaSans(
                      color: titleColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (_mediaList.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MediaLinksDocsScreen(
                              allMessages: _messages,
                            ),
                          ),
                        );
                      }
                    },
                    child: Row(
                      children: [
                        Text(
                          _mediaList.isNotEmpty ? "${_mediaList.length}" : "0",
                          style: GoogleFonts.plusJakartaSans(
                            color: subColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded, color: subColor, size: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_mediaList.isEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 8),
                child: Text("No media shared yet.", style: GoogleFonts.plusJakartaSans(color: subColor, fontSize: 13)),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: List.generate(
                    _mediaList.length > 4 ? 4 : _mediaList.length,
                    (index) {
                      bool isLast = index == 3 && _mediaList.length > 4;
                      int remainingCount = _mediaList.length - 3;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (isLast) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MediaLinksDocsScreen(
                                    allMessages: _messages,
                                  ),
                                ),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FullScreenImageViewer(
                                    imagePaths: [_mediaList[index]],
                                    senderName: widget.name,
                                    time: "",
                                  ),
                                ),
                              );
                            }
                          },
                          child: Container(
                            height: 80,
                            margin: EdgeInsets.only(right: index < (_mediaList.length > 4 ? 3 : _mediaList.length - 1) ? 8 : 0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: _mediaList[index].startsWith('http')
                                    ? NetworkImage(_mediaList[index])
                                    : FileImage(File(_mediaList[index])) as ImageProvider,
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: isLast
                                ? Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      "+$remainingCount",
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Group Members Section
            if (widget.isGroup) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  "Members in the group",
                  style: GoogleFonts.plusJakartaSans(
                    color: titleColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: subColor.withValues(alpha: 0.1)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _members.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    return ListTile(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => GroupInfoScreen(
                          name: member["name"]!,
                          avatarUrl: member["avatar"] ?? "",
                          isGroup: false,
                        )));
                      },
                      leading: _buildInitialsAvatar(name: member["name"]!, radius: 20),
                      title: Text(
                        member["name"]!,
                        style: GoogleFonts.plusJakartaSans(
                          color: titleColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        member["role"]!,
                        style: GoogleFonts.plusJakartaSans(
                          color: subColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: canDeleteGroup ? IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent),
                        onPressed: () {
                          final removedName = member['name'];
                          showDialog(
                            context: context,
                            builder: (context) {
                              final bool isDark = Theme.of(context).brightness == Brightness.dark;
                              return AlertDialog(
                                backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: Text(
                                  "Remove Member",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                content: Text(
                                  "Are you sure you want to remove $removedName from this group?",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(
                                      "Cancel",
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFF64748B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context); // Close dialog
                                      setState(() {
                                        _members.removeAt(index);
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text("$removedName removed from group"),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    },
                                    child: Text(
                                      "Remove",
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ) : null,
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Action Tiles List
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: subColor.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.star_rounded, color: Colors.amber),
                    title: Text(
                      "Starred messages",
                      style: GoogleFonts.plusJakartaSans(color: titleColor, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    trailing: Icon(Icons.chevron_right_rounded, color: subColor),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StarredMessagesScreen(groupName: widget.name),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.notifications_rounded, color: brandColor),
                    title: Text(
                      "Notifications",
                      style: GoogleFonts.plusJakartaSans(color: titleColor, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    trailing: Icon(Icons.chevron_right_rounded, color: subColor),
                    onTap: _showNotificationsSheet,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.sd_storage_rounded, color: Colors.teal),
                    title: Text(
                      "Manage storage",
                      style: GoogleFonts.plusJakartaSans(color: titleColor, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    trailing: Icon(Icons.chevron_right_rounded, color: subColor),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ManageStorageScreen(
                            groupName: widget.name,
                            allMessages: _messages,
                          ),
                        ),
                      );
                    },
                  ),
                  if (widget.isGroup && isAdmin) ...[
                    const Divider(height: 1),
                    ListTile(
                      onTap: _showGroupPermissionsSheet,
                      leading: const Icon(Icons.admin_panel_settings_rounded, color: brandColor),
                      title: Text(
                        "Group permissions",
                        style: GoogleFonts.plusJakartaSans(color: titleColor, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded, color: subColor),
                    ),
                  ],
                  if (widget.isGroup) ...[
                    const Divider(height: 1),
                    ListTile(
                      onTap: _showAddMembersSheet,
                      leading: const Icon(Icons.person_add_rounded, color: brandColor),
                      title: Text(
                        "Add member",
                        style: GoogleFonts.plusJakartaSans(color: titleColor, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded, color: subColor),
                    ),
                  ],
                  if (widget.isGroup && canDeleteGroup) ...[
                    const Divider(height: 1),
                    ListTile(
                      onTap: _showDeleteGroupDialog,
                      leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                      title: Text(
                        "Delete group",
                        style: GoogleFonts.plusJakartaSans(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    ),
  );
}
}

