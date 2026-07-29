import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'media_links_docs_screen.dart'; 

class ManageStorageScreen extends StatelessWidget {
  final String groupName;
  final List<Map<String, dynamic>> allMessages;

  const ManageStorageScreen({super.key, required this.groupName, required this.allMessages});

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
          "Manage Storage",
          style: GoogleFonts.plusJakartaSans(
            color: titleColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: subColor.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Total Storage Used",
                        style: GoogleFonts.plusJakartaSans(
                          color: subColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        "177 MB",
                        style: GoogleFonts.plusJakartaSans(
                          color: titleColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Storage Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      children: [
                        Expanded(flex: 70, child: Container(height: 12, color: brandColor)),
                        Expanded(flex: 20, child: Container(height: 12, color: Colors.amber)),
                        Expanded(flex: 10, child: Container(height: 12, color: Colors.teal)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Breakdown
                  _buildStorageRow(Icons.photo_library_rounded, brandColor, "Media (Photos & Videos)", "120 MB", titleColor, subColor),
                  const Divider(height: 24),
                  _buildStorageRow(Icons.description_rounded, Colors.amber, "Documents", "45 MB", titleColor, subColor),
                  const Divider(height: 24),
                  _buildStorageRow(Icons.mic_rounded, Colors.teal, "Voice Messages", "12 MB", titleColor, subColor),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Storage Details",
              style: GoogleFonts.plusJakartaSans(
                color: titleColor,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: subColor.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: brandColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.folder_shared_rounded, color: brandColor),
                    ),
                    title: Text("Media, Links, and Docs", style: GoogleFonts.plusJakartaSans(color: titleColor, fontWeight: FontWeight.w700)),
                    subtitle: Text("Review and delete media files", style: GoogleFonts.plusJakartaSans(color: subColor, fontSize: 13)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B)),
                    onTap: () {
                      if (allMessages.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MediaLinksDocsScreen(
                              allMessages: allMessages,
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text("No shared media, links, or docs yet."),
                            backgroundColor: titleColor,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStorageRow(IconData icon, Color color, String title, String size, Color titleColor, Color subColor) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.plusJakartaSans(color: titleColor, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          size,
          style: GoogleFonts.plusJakartaSans(color: subColor, fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
