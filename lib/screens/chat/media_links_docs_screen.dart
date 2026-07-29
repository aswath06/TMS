import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'youtube_player_screen.dart';
import 'full_screen_image_viewer.dart';

class MediaLinksDocsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> allMessages;

  const MediaLinksDocsScreen({super.key, required this.allMessages});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    const Color brandColor = Color(0xFF6366F1);

    // Filter Media
    final List<Map<String, dynamic>> mediaItems = [];
    for (var msg in allMessages) {
      if (msg['imagePaths'] != null) {
        List<String> paths = List<String>.from(msg['imagePaths']);
        for (var p in paths) {
          mediaItems.add({
            'path': p,
            'isVideo': false,
            'senderName': msg['senderName'] ?? (msg['isMe'] == true ? 'You' : 'Unknown'),
            'time': msg['time'] ?? ''
          });
        }
      } else if (msg['imagePath'] != null) {
        mediaItems.add({
          'path': msg['imagePath'],
          'isVideo': false,
          'senderName': msg['senderName'] ?? (msg['isMe'] == true ? 'You' : 'Unknown'),
          'time': msg['time'] ?? ''
        });
      } else if (msg['videoPath'] != null) {
        mediaItems.add({
          'path': msg['videoPath'],
          'isVideo': true,
          'senderName': msg['senderName'] ?? (msg['isMe'] == true ? 'You' : 'Unknown'),
          'time': msg['time'] ?? ''
        });
      }
    }

    // Filter Docs
    final docMessages = allMessages.where((msg) => msg['documentPath'] != null || msg['fileName'] != null || msg['documentName'] != null).toList();

    // Filter Links
    final linkRegex = RegExp(r'(https?:\/\/[^\s]+)');
    final linkMessages = allMessages.where((msg) {
      if (msg['text'] != null) {
        return linkRegex.hasMatch(msg['text']);
      }
      return false;
    }).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: cardColor,
          elevation: 0.5,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: titleColor),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            "Media, Links, and Docs",
            style: GoogleFonts.plusJakartaSans(
              color: titleColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          bottom: TabBar(
            indicatorColor: brandColor,
            labelColor: brandColor,
            unselectedLabelColor: subColor,
            labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            tabs: const [
              Tab(text: "Media"),
              Tab(text: "Links"),
              Tab(text: "Docs"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMediaTab(mediaItems, subColor),
            _buildLinksTab(linkMessages, titleColor, subColor, brandColor, linkRegex),
            _buildDocsTab(docMessages, titleColor, subColor, brandColor),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaTab(List<Map<String, dynamic>> items, Color subColor) {
    if (items.isEmpty) {
      return Center(
        child: Text("No media found", style: GoogleFonts.plusJakartaSans(color: subColor)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final String path = item['path'];
        final bool isVideo = item['isVideo'] == true;

        return GestureDetector(
          onTap: () {
            if (!isVideo) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullScreenImageViewer(
                    imagePaths: [path],
                    senderName: item['senderName'],
                    time: item['time'],
                  ),
                ),
              );
            }
          },
          child: Hero(
            tag: 'media_${path}_$index',
            child: Container(
              color: Colors.grey.shade300,
              child: isVideo
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(color: Colors.black87),
                        const Center(
                          child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 36),
                        ),
                      ],
                    )
                  : Image.file(File(path), fit: BoxFit.cover),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLinksTab(List<Map<String, dynamic>> messages, Color titleColor, Color subColor, Color brandColor, RegExp regex) {
    if (messages.isEmpty) {
      return Center(
        child: Text("No links found", style: GoogleFonts.plusJakartaSans(color: subColor)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final message = messages[index];
        final String text = message['text'];
        final match = regex.firstMatch(text);
        final url = match?.group(0) ?? '';

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: brandColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.link_rounded, color: brandColor),
          ),
          title: Text(
            url,
            style: GoogleFonts.plusJakartaSans(
              color: brandColor,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            message['senderName'] ?? (message['isMe'] == true ? 'You' : 'Unknown'),
            style: GoogleFonts.plusJakartaSans(color: subColor, fontSize: 12),
          ),
          onTap: () async {
            if (url.isNotEmpty) {
              final isYoutube = url.contains('youtube.com') || url.contains('youtu.be');
              if (isYoutube) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => YoutubePlayerScreen(videoUrl: url),
                  ),
                );
                return;
              }

              final uri = Uri.parse(url);
              try {
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Could not launch link")),
                    );
                  }
                }
              } catch (e) {
                debugPrint("Error launching link: $e");
              }
            }
          },
        );
      },
    );
  }

  Widget _buildDocsTab(List<Map<String, dynamic>> messages, Color titleColor, Color subColor, Color brandColor) {
    if (messages.isEmpty) {
      return Center(
        child: Text("No documents found", style: GoogleFonts.plusJakartaSans(color: subColor)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final message = messages[index];
        final String fileName = message['documentName'] ?? message['fileName'] ?? 'Document';
        final String? docPath = message['documentPath'];

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.insert_drive_file_rounded, color: Colors.amber),
          ),
          title: Text(
            fileName,
            style: GoogleFonts.plusJakartaSans(
              color: titleColor,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            message['senderName'] ?? (message['isMe'] == true ? 'You' : 'Unknown'),
            style: GoogleFonts.plusJakartaSans(color: subColor, fontSize: 12),
          ),
          onTap: () {
            // Placeholder for opening docs since open_filex is not used here yet.
            if (docPath != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Document tapped.")),
              );
            }
          },
        );
      },
    );
  }
}
