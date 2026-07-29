import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class ContactModel {
  final String name;
  final String role;
  final String avatar;
  bool isSelected;

  ContactModel({
    required this.name,
    required this.role,
    required this.avatar,
    this.isSelected = false,
  });
}

String getInitials(String name) {
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

Widget buildInitialsAvatar(String name, double radius) {
  final initials = getInitials(name);
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

class SelectMembersScreen extends StatefulWidget {
  const SelectMembersScreen({super.key});

  @override
  State<SelectMembersScreen> createState() => _SelectMembersScreenState();
}

class _SelectMembersScreenState extends State<SelectMembersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // Contact list showing only users already existing in the app
  final List<ContactModel> _contacts = [
    ContactModel(name: "Transport Admin", role: "Transport Admin", avatar: ""),
    ContactModel(name: "Security Team", role: "Security", avatar: ""),
    ContactModel(name: "Driver John", role: "Driver", avatar: ""),
    ContactModel(name: "Support Hub", role: "Faculty", avatar: ""),
    ContactModel(name: "Maintenance", role: "Staff", avatar: ""),
    ContactModel(name: "HR Department", role: "Staff", avatar: ""),
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    const Color brandColor = Color(0xFF6366F1); // Brand Blue Theme

    final filtered = _contacts.where((c) {
      return c.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final selectedContacts = _contacts.where((c) => c.isSelected).toList();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: titleColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          onChanged: (v) {
            setState(() {
              _searchQuery = v;
            });
          },
          style: GoogleFonts.plusJakartaSans(
            color: titleColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: "Name, number, username",
            hintStyle: GoogleFonts.plusJakartaSans(color: subColor, fontSize: 16),
            border: InputBorder.none,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selectedContacts.isNotEmpty) ...[
            Container(
              height: 80,
              padding: const EdgeInsets.symmetric(vertical: 10),
              color: cardColor.withValues(alpha: 0.5),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: selectedContacts.length,
                itemBuilder: (context, index) {
                  final contact = selectedContacts[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Stack(
                      children: [
                        buildInitialsAvatar(contact.name, 24),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                contact.isSelected = false;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                            ),
                          ),
                        )
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              "Frequently contacted",
              style: GoogleFonts.plusJakartaSans(
                color: subColor,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              padding: const EdgeInsets.only(bottom: 100),
              itemBuilder: (context, index) {
                final contact = filtered[index];
                return ListTile(
                  onTap: () {
                    setState(() {
                      contact.isSelected = !contact.isSelected;
                    });
                    HapticFeedback.lightImpact();
                  },
                  leading: buildInitialsAvatar(contact.name, 24),
                  title: Text(
                    contact.name,
                    style: GoogleFonts.plusJakartaSans(
                      color: titleColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    contact.role,
                    style: GoogleFonts.plusJakartaSans(
                      color: subColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: contact.isSelected ? brandColor : subColor.withValues(alpha: 0.5),
                        width: 2,
                      ),
                      color: contact.isSelected ? brandColor : Colors.transparent,
                    ),
                    child: contact.isSelected
                        ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: selectedContacts.isNotEmpty
          ? FloatingActionButton(
              onPressed: () async {
                HapticFeedback.mediumImpact();
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GroupDetailsScreen(selectedMembers: selectedContacts),
                  ),
                );
                if (result != null && mounted) {
                  Navigator.pop(context, result);
                }
              },
              backgroundColor: brandColor,
              shape: const CircleBorder(),
              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            )
          : null,
    );
  }
}

class GroupDetailsScreen extends StatefulWidget {
  final List<ContactModel> selectedMembers;
  const GroupDetailsScreen({super.key, required this.selectedMembers});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  File? _selectedGroupImage;

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _selectedGroupImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  // Role toggles
  final Map<String, bool> _rolePermissions = {
    "Transport Admin": true,
    "Driver": true,
    "Security": true,
    "Faculty": true,
    "Student": true,
    "Assigned Faculty": true,
  };

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    const Color brandColor = Color(0xFF6366F1); // Brand Blue Theme

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
          "New group",
          style: GoogleFonts.plusJakartaSans(
            color: titleColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: cardColor,
              child: Row(
                children: [
                  // Camera / Icon Picker
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_selectedGroupImage != null)
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: DecorationImage(
                                image: FileImage(_selectedGroupImage!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        else
                          buildInitialsAvatar(
                            _groupNameController.text.isNotEmpty
                                ? _groupNameController.text
                                : "New Group",
                            26,
                          ),
                        if (_selectedGroupImage == null)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: cardColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.camera_alt_rounded, size: 12, color: subColor),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _groupNameController,
                      onChanged: (val) {
                        setState(() {});
                      },
                      style: GoogleFonts.plusJakartaSans(
                        color: titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        hintText: "Group name (optional)",
                        hintStyle: GoogleFonts.plusJakartaSans(
                          color: subColor.withValues(alpha: 0.6),
                        ),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: brandColor, width: 2),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: brandColor, width: 2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                "Role permissions (Toggled ON to send messages, OFF for view-only)",
                style: GoogleFonts.plusJakartaSans(
                  color: subColor,
                  fontSize: 12,
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
                itemCount: _rolePermissions.keys.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final roleName = _rolePermissions.keys.elementAt(index);
                  final isToggled = _rolePermissions[roleName]!;
                  return ListTile(
                    title: Text(
                      roleName,
                      style: GoogleFonts.plusJakartaSans(
                        color: titleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    trailing: Switch.adaptive(
                      value: isToggled,
                      activeColor: brandColor,
                      onChanged: (val) {
                        setState(() {
                          _rolePermissions[roleName] = val;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Members: ${widget.selectedMembers.length}",
                style: GoogleFonts.plusJakartaSans(
                  color: subColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: widget.selectedMembers.length,
                itemBuilder: (context, index) {
                  final contact = widget.selectedMembers[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Column(
                      children: [
                        buildInitialsAvatar(contact.name, 26),
                        const SizedBox(height: 6),
                        Text(
                          contact.name.split(" ")[0],
                          style: GoogleFonts.plusJakartaSans(
                            color: titleColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          
          final String groupName = _groupNameController.text.isNotEmpty 
              ? _groupNameController.text 
              : "New Group";

          // Show Success SnackBar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Group '$groupName' created successfully!"),
              backgroundColor: brandColor,
            ),
          );

          // Return group details to SelectMembersScreen which will bubble it back to ChatScreen
          Navigator.pop(context, {
            'name': groupName,
            'message': 'Group created with ${widget.selectedMembers.length} members',
            'time': 'Just now',
            'unread': 0,
            'avatar': _selectedGroupImage?.path ?? '',
            'isGroup': true,
          });
        },
        backgroundColor: brandColor,
        shape: const CircleBorder(),
        child: const Icon(Icons.check_rounded, color: Colors.white),
      ),
    );
  }
}
