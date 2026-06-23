import 'package:flutter/material.dart';
import 'package:tripzo/utils/api_constants.dart';

class ProfileHero extends StatelessWidget {
  final String name;
  final String subtitle;
  final Color cardColor;
  final Color titleColor;
  final Color subColor;
  final bool isDark;
  final String? profileImageUrl;
  final VoidCallback? onAvatarTap;

  const ProfileHero({
    super.key,
    required this.name,
    required this.subtitle,
    required this.cardColor,
    required this.titleColor,
    required this.subColor,
    required this.isDark,
    this.profileImageUrl,
    this.onAvatarTap,
  });

  String _getInitials(String fullName) {
    if (fullName.isEmpty || fullName == "...") return "NA";
    
    // Remove titles like Mr., Ms., Dr., etc.
    String cleanName = fullName.replaceAll(RegExp(r'^(Mr\.|Ms\.|Mrs\.|Dr\.)\s*', caseSensitive: false), '');
    
    List<String> parts = cleanName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return "NA";
    if (parts.length == 1) {
      return parts[0].length >= 2 ? parts[0].substring(0, 2).toUpperCase() : parts[0].toUpperCase();
    }
    
    String first = parts[0];
    String last = parts[parts.length - 1];
    
    if (first.isEmpty) return "NA";
    if (last.isEmpty) return first[0].toUpperCase();
    
    return "${first[0]}${last[0]}".toUpperCase();
  }

  String _getFullImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final base = ApiConstants.baseUrl;
    final relative = path.startsWith('/') ? path : '/$path';
    return '$base$relative';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onAvatarTap,
            child: _buildAvatar(),
          ),
          const SizedBox(height: 20),
          Text(
            name,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: subColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final String url = _getFullImageUrl(profileImageUrl);
    final bool hasImage = url.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
        ),
      ),
      child: CircleAvatar(
        radius: 50,
        backgroundColor: hasImage ? Colors.transparent : (isDark ? const Color(0xFF1E293B) : Colors.white),
        backgroundImage: hasImage ? NetworkImage(url) : null,
        child: !hasImage
            ? Text(
                _getInitials(name),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6366F1),
                ),
              )
            : null,
      ),
    );
  }
}
