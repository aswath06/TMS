import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io' show Platform;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_update/in_app_update.dart';
import '../utils/api_constants.dart';

class AppVersionService {
  static String get _checkUrl => '${ApiConstants.baseUrl}/api/app-version/check';

  static Future<void> checkAppVersion(BuildContext context, {bool showNoUpdateFound = false}) async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final int currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
      final String currentVersion = packageInfo.version;

      final response = await http.post(
        Uri.parse(_checkUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'buildNumber': currentBuild, 'version': currentVersion}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (data['updateRequired'] == true) {
            final bool forceUpdate = data['forceUpdate'] == true;
            final String playStoreUrl = (data['playStoreUrl'] != null && data['playStoreUrl'].toString().isNotEmpty)
                ? data['playStoreUrl']
                : "https://play.google.com/store/apps/details?id=com.aswath.tripzo";
            final String appStoreUrl = (data['appStoreUrl'] != null && data['appStoreUrl'].toString().isNotEmpty)
                ? data['appStoreUrl']
                : "https://apps.apple.com/app/tripzo-transport-management/id6780758783";
            final String releaseNotes = data['releaseNotes'] ?? "A new version of the app is available.";
            
            final String storeUrl = Platform.isIOS ? (appStoreUrl.isNotEmpty ? appStoreUrl : playStoreUrl) : playStoreUrl;

            if (!forceUpdate && !showNoUpdateFound) { // if checking manually, ignore dismissed
              final prefs = await SharedPreferences.getInstance();
              final lastDismissedStr = prefs.getString('update_dismissed_date');
              if (lastDismissedStr != null) {
                final lastDismissedDate = DateTime.tryParse(lastDismissedStr);
                if (lastDismissedDate != null) {
                  final now = DateTime.now();
                  if (now.year == lastDismissedDate.year &&
                      now.month == lastDismissedDate.month &&
                      now.day == lastDismissedDate.day) {
                    // Already dismissed today
                    return;
                  }
                }
              }
            }

            if (Platform.isAndroid) {
              try {
                final updateInfo = await InAppUpdate.checkForUpdate();
                if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
                  if (forceUpdate) {
                    await InAppUpdate.performImmediateUpdate();
                  } else {
                    await InAppUpdate.startFlexibleUpdate();
                    await InAppUpdate.completeFlexibleUpdate();
                  }
                  return; // Successfully triggered Android native update
                }
              } catch (e) {
                debugPrint("InAppUpdate failed or not available yet: \$e");
              }
            }

            if (context.mounted) {
              _showUpdateDialog(context, forceUpdate, storeUrl, releaseNotes);
            }
          } else if (showNoUpdateFound && context.mounted) {
            _showNoUpdateDialog(context);
          }
        }
      }
    } catch (e) {
      debugPrint("Error checking app version: \$e");
    }
  }

  static void _showNoUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Up to Date!",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "You are already using the latest version of Tripzo.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "Awesome",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void _showUpdateDialog(BuildContext context, bool forceUpdate, String storeUrl, String releaseNotes) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) {
        return PopScope(
          canPop: !forceUpdate,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.rocket_launch_rounded,
                      color: Color(0xFF6366F1),
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Time to Update!",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "A new and improved version of Tripzo is available. Update now to enjoy the latest features and a seamless experience.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (releaseNotes.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "✨ What's New",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            releaseNotes,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF334155),
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Row(
                    children: [
                      if (!forceUpdate)
                        Expanded(
                          child: TextButton(
                            onPressed: () async {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setString('update_dismissed_date', DateTime.now().toIso8601String());
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              "Later",
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      if (!forceUpdate) const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () async {
                            final Uri url = Uri.parse(storeUrl);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            "Update Now",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
