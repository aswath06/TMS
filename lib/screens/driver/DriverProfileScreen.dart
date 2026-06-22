import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tripzo/components/profile/info_card.dart';
import 'package:tripzo/components/profile/profile_hero.dart';
import 'package:tripzo/components/profile/typing_text.dart';
import 'package:tripzo/screens/setting/settings_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/providers.dart';
import 'package:tripzo/store/driver_store.dart';
import 'package:tripzo/store/istamil.dart';
import 'package:tripzo/screens/setting/scanner_page.dart';
import 'package:tripzo/utils/toast_utils.dart';
import 'package:tripzo/utils/api_constants.dart';

class DriverProfileScreen extends ConsumerStatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  ConsumerState<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends ConsumerState<DriverProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (useDriverStore.profileData.value == null) {
        useDriverStore.fetchProfile();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isTamil = LanguageStore.isTamil;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTitleColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          _buildBackgroundDecor(isDark),
          RefreshIndicator(
            onRefresh: () => useDriverStore.fetchProfile(),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverSafeArea(
                  sliver: SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildHeader(context, titleColor, isTamil),
                        const SizedBox(height: 30),
                        Consumer(
builder: (context, ref, _) {
final store = ref.watch(driverStoreProvider);
                            if (store.profileError != null) {
                              return _buildErrorState(
                                store.profileError!,
                                titleColor,
                                isTamil,
                              );
                            }
                            return ValueListenableBuilder(
                              valueListenable: store.profileData,
                              builder: (context, profile, _) {
                                return ValueListenableBuilder(
                                  valueListenable: store.ongoingTask,
                                  builder: (context, task, _) {
                                    return ValueListenableBuilder(
                                      valueListenable: store.upcomingRoutes,
                                      builder: (context, routes, _) {
                                        return _buildProfileContent(
                                          profile,
                                          store.isLoading,
                                          isDark,
                                          titleColor,
                                          cardColor,
                                          subTitleColor,
                                          isTamil,
                                          task,
                                          routes,
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 100),
                      ]),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(
    Map<String, dynamic>? data,
    bool isLoading,
    bool isDark,
    Color titleColor,
    Color cardColor,
    Color subColor,
    bool isTamil,
    Map<String, dynamic>? task,
    List<dynamic> routes,
  ) {
    final bool showTyping = isLoading && data == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileHero(
          name: showTyping
              ? "..."
              : (data?['name'] ?? (isTamil ? "ஓட்டுநர்" : "Driver")),
          subtitle: showTyping
              ? (isTamil ? "புதுப்பிக்கிறது..." : "Updating...")
              : "${isTamil ? 'ஓட்டுநர்' : 'Driver'} • ${data?['email'] ?? ''}",
          cardColor: cardColor,
          titleColor: titleColor,
          subColor: subColor,
          isDark: isDark,
          profileImageUrl: data?['profile_photo'],
          onAvatarTap: () => _showProfileImagePicker(context),
        ),
        const SizedBox(height: 32),

        if (task != null) ...[
          _buildSectionTitle(
            isTamil ? "தற்போதைய பணி" : "Ongoing Task",
            titleColor,
          ),
          const SizedBox(height: 16),
          _buildOngoingTaskCard(task, cardColor, titleColor, subColor, isTamil),
          const SizedBox(height: 32),
        ],

        _buildSectionTitle(
          isTamil ? "ஓட்டுநர் விவரங்கள்" : "Driver Details",
          titleColor,
        ),
        const SizedBox(height: 16),
        _buildDriverGrid(
          data,
          isLoading,
          cardColor,
          titleColor,
          subColor,
          isTamil,
        ),
        const SizedBox(height: 32),

        _buildSectionTitle(
          isTamil ? "கணக்கு விவரங்கள்" : "Account Details",
          titleColor,
        ),
        const SizedBox(height: 16),
        _buildAccountGrid(
          data,
          isLoading,
          cardColor,
          titleColor,
          subColor,
          isTamil,
        ),
        const SizedBox(height: 32),
        
        _buildSectionTitle(
          isTamil ? "தனிப்பட்ட விவரங்கள்" : "Personal Details",
          titleColor,
        ),
        const SizedBox(height: 16),
        _buildPersonalGrid(
          data,
          isLoading,
          cardColor,
          titleColor,
          subColor,
          isTamil,
        ),
        const SizedBox(height: 32),
        _buildDocumentPreview(data, isDark, titleColor, cardColor, isTamil),
        const SizedBox(height: 32),

        _buildSectionTitle(
          isTamil ? "வங்கி விவரங்கள்" : "Bank Details",
          titleColor,
        ),
        const SizedBox(height: 16),
        _buildBankGrid(
          data,
          isLoading,
          cardColor,
          titleColor,
          subColor,
          isTamil,
        ),
        const SizedBox(height: 32),

        _buildSectionTitle(
          isTamil ? "சம்பள விவரங்கள்" : "Salary Details",
          titleColor,
        ),
        const SizedBox(height: 16),
        _buildSalaryGrid(
          data,
          isLoading,
          cardColor,
          titleColor,
          subColor,
          isTamil,
        ),
        const SizedBox(height: 32),

        _buildSectionTitle(
          isTamil ? "விரைவான செயல்கள்" : "Quick Actions",
          titleColor,
        ),
        const SizedBox(height: 16),
        _buildScannerTile(context, isDark, cardColor, titleColor, isTamil),
        const SizedBox(height: 40),
      ],
    );
  }

  void _showProfileImagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (pickedFile != null && mounted) {
        final File imageFile = File(pickedFile.path);
        
        // Show loading toast
        showTopToast(context, "Uploading profile photo...", isError: false);
        
        // Call API
        final result = await useDriverStore.updateDriverMultipart(
          {}, // No text fields needed for just profile photo upload
          files: {'profile_photo': imageFile},
        );

        if (mounted) {
          if (result['success']) {
            showTopToast(context, "Profile photo updated successfully!", isError: false);
            useDriverStore.fetchProfile(); // Refresh profile to get new image URL
          } else {
            showTopToast(context, result['message'] ?? "Failed to update profile photo", isError: true);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        showTopToast(context, "Error picking image: $e", isError: true);
      }
    }
  }

  Widget _buildOngoingTaskCard(Map<String, dynamic> task, Color card, Color title, Color sub, bool isTamil) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF6366F1), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.location_searching_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['routeName'] ?? "Active Trip",
                  style: TextStyle(color: title, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  "${task['startLocation']} → ${task['destinationLocation']}",
                  style: TextStyle(color: sub, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleRouteCard(Map<String, dynamic> route, Color card, Color title, Color sub, bool isTamil) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: title.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today_rounded, size: 18, color: sub.withOpacity(0.5)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  route['routeName'] ?? "Unknown",
                  style: TextStyle(color: title, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  _formatDate(route['startDate']),
                  style: TextStyle(color: sub, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildDriverGrid(
    Map<String, dynamic>? data,
    bool isLoading,
    Color cardColor,
    Color titleColor,
    Color subColor,
    bool isTamil,
  ) {
    final List<Map<String, dynamic>> items = [
      {
        'title': isTamil ? 'பெயர்' : 'Full Name',
        'val': data?['name'],
        'icon': Icons.badge_rounded,
        'color': Colors.indigo,
      },
      {
        'title': isTamil ? 'பணியாளர் குறியீடு' : 'Employee Code',
        'val': data?['driverProfile']?['employee_code'],
        'icon': Icons.badge_outlined,
        'color': Colors.blueGrey,
      },
      {
        'title': isTamil ? 'அனுமதி எண்' : 'License Number',
        'val': data?['driverProfile']?['license_number'],
        'icon': Icons.description_rounded,
        'color': Colors.orange,
      },
      {
        'title': isTamil ? 'இரத்த வகை' : 'Blood Group',
        'val': data?['driverProfile']?['blood_group'],
        'icon': Icons.bloodtype_rounded,
        'color': Colors.redAccent,
      },
      {
        'title': isTamil ? 'அனுமதி காலாவதி' : 'License Expiry',
        'val': _formatDate(data?['driverProfile']?['license_expiry_date']),
        'icon': Icons.calendar_today_rounded,
        'color': Colors.amber.shade700,
      },
      {
        'title': isTamil ? 'அனுபவம்' : 'Experience',
        'val': "${data?['driverProfile']?['experience_years'] ?? 0} ${isTamil ? 'ஆண்டுகள்' : 'Years'}",
        'icon': Icons.work_history_rounded,
        'color': Colors.green,
      },
      {
        'title': isTamil ? 'சேர்ந்த தேதி' : 'Joining Date',
        'val': _formatDate(data?['driverProfile']?['joining_date']),
        'icon': Icons.login_rounded,
        'color': Colors.cyan,
      },
      {
        'title': isTamil ? 'முகவரி' : 'Address',
        'val': data?['driverProfile']?['address'],
        'icon': Icons.location_on_rounded,
        'color': Colors.deepOrange,
      },
    ];
    return _renderGrid(items, isLoading, cardColor, titleColor, subColor);
  }

  Widget _buildAccountGrid(
    Map<String, dynamic>? data,
    bool isLoading,
    Color cardColor,
    Color titleColor,
    Color subColor,
    bool isTamil,
  ) {
    final List<Map<String, dynamic>> items = [
      {
        'title': isTamil ? 'மின்னஞ்சல்' : 'Email',
        'val': data?['email'],
        'icon': Icons.alternate_email_rounded,
        'color': Colors.teal,
      },
      {
        'title': isTamil ? 'தொலைபேசி' : 'Phone',
        'val': data?['phone'],
        'icon': Icons.phone_android_rounded,
        'color': Colors.blue,
      },
      {
        'title': isTamil ? 'அவசர தொடர்பு' : 'Emergency Contact',
        'val': data?['driverProfile']?['emergency_contact_name'],
        'icon': Icons.contact_emergency_rounded,
        'color': Colors.red,
      },
      {
        'title': isTamil ? 'அவசர எண்' : 'Emergency Phone',
        'val': data?['driverProfile']?['emergency_contact_phone'],
        'icon': Icons.phone_callback_rounded,
        'color': Colors.orange,
      },
      {
        'title': isTamil ? 'மொத்த கிமீ' : 'Total KM',
        'val': data?['driverProfile']?['total_kilometer_drived'],
        'icon': Icons.speed_rounded,
        'color': Colors.blue,
      },
      {
        'title': isTamil ? 'மொத்த பயணங்கள்' : 'Total Routes',
        'val': data?['driverProfile']?['total_routes'],
        'icon': Icons.route_rounded,
        'color': Colors.purple,
      },
      {
        'title': isTamil ? 'நிலை' : 'Status',
        'val': data?['status'],
        'icon': Icons.info_outline,
        'color': Colors.green,
      },
      {
        'title': isTamil ? 'புஷ் அறிவிப்பு' : 'Push Notifications',
        'val': data?['push_notification_enabled'] == true ? 'Enabled' : 'Disabled',
        'icon': Icons.notifications_active_rounded,
        'color': Colors.amber,
      },
      {
        'title': isTamil ? 'கடைசி உள்நுழைவு' : 'Last Login At',
        'val': _formatDate(data?['last_login_at']),
        'icon': Icons.login_rounded,
        'color': Colors.indigo,
      },
    ];
    return _renderGrid(items, isLoading, cardColor, titleColor, subColor);
  }

  Widget _buildPersonalGrid(
    Map<String, dynamic>? data,
    bool isLoading,
    Color cardColor,
    Color titleColor,
    Color subColor,
    bool isTamil,
  ) {
    final List<Map<String, dynamic>> items = [
      {
        'title': isTamil ? 'வயது' : 'Age',
        'val': data?['age'],
        'icon': Icons.cake_rounded,
        'color': Colors.pink,
      },
      {
        'title': isTamil ? 'பாலினம்' : 'Gender',
        'val': data?['gender'],
        'icon': Icons.person_rounded,
        'color': Colors.blueAccent,
      },
      {
        'title': isTamil ? 'பிறந்த தேதி' : 'Date of Birth',
        'val': _formatDate(data?['dob']),
        'icon': Icons.calendar_month_rounded,
        'color': Colors.orange,
      },
      {
        'title': isTamil ? 'மதம்' : 'Religion',
        'val': data?['religious'],
        'icon': Icons.church_rounded,
        'color': Colors.purple,
      },
      {
        'title': isTamil ? 'சாதி' : 'Caste',
        'val': data?['caste'],
        'icon': Icons.group_rounded,
        'color': Colors.teal,
      },
      {
        'title': isTamil ? 'சமூகம்' : 'Community',
        'val': data?['community'],
        'icon': Icons.people_alt_rounded,
        'color': Colors.brown,
      },
      {
        'title': isTamil ? 'தந்தை பெயர்' : 'Father Name',
        'val': data?['father_name'],
        'icon': Icons.family_restroom_rounded,
        'color': Colors.deepOrange,
      },
      {
        'title': isTamil ? 'தாய் பெயர்' : 'Mother Name',
        'val': data?['mother_name'],
        'icon': Icons.pregnant_woman_rounded,
        'color': Colors.cyan,
      },
      {
        'title': isTamil ? 'துணைவர் பெயர்' : 'Spouse Name',
        'val': data?['spouse_name'],
        'icon': Icons.favorite_rounded,
        'color': Colors.redAccent,
      },
      {
        'title': isTamil ? 'மாற்று தொலைபேசி' : 'Mobile Number 2',
        'val': data?['mobile_number_2'],
        'icon': Icons.phone_android_rounded,
        'color': Colors.lightBlue,
      },
      {
        'title': isTamil ? 'ஆதார் எண்' : 'Aadhar Number',
        'val': data?['aadhar_number'],
        'icon': Icons.credit_card_rounded,
        'color': Colors.green,
      },
      {
        'title': isTamil ? 'திருமண நிலை' : 'Marital Status',
        'val': data?['driverProfile']?['marital_status'],
        'icon': Icons.diversity_1_rounded,
        'color': Colors.indigo,
      },
      {
        'title': isTamil ? 'நியமனப் பெயர்' : 'Nominee Name',
        'val': data?['driverProfile']?['nominee_name'],
        'icon': Icons.person_pin_rounded,
        'color': Colors.deepPurple,
      },
      {
        'title': isTamil ? 'நியமனப் பிறந்த தேதி' : 'Nominee DOB',
        'val': _formatDate(data?['driverProfile']?['nominee_dob']),
        'icon': Icons.calendar_today_rounded,
        'color': Colors.amber,
      },
      {
        'title': isTamil ? 'நியமன உறவு' : 'Nominee Relation',
        'val': data?['driverProfile']?['nominee_relation'],
        'icon': Icons.handshake_rounded,
        'color': Colors.teal,
      },
    ];
    return _renderGrid(items, isLoading, cardColor, titleColor, subColor);
  }

  Widget _buildDocumentPreview(Map<String, dynamic>? data, bool isDark, Color titleColor, Color cardColor, bool isTamil) {
    if (data == null) return const SizedBox();

    final aadhar = data['aadhar_photo'];
    final pan = data['driverProfile']?['pan_image'];
    final licFront = data['driverProfile']?['licence_image_front'];
    final licBack = data['driverProfile']?['licence_image_back'];

    if (aadhar == null && pan == null && licFront == null && licBack == null) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(isTamil ? "ஆவணங்கள்" : "Documents", titleColor),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
          children: [
            if (aadhar != null) _buildDocCard(isTamil ? "ஆதார் அட்டை" : "Aadhar Card", aadhar, cardColor, titleColor, isDark),
            if (pan != null) _buildDocCard(isTamil ? "பான் அட்டை" : "PAN Card", pan, cardColor, titleColor, isDark),
            if (licFront != null) _buildDocCard(isTamil ? "உரிமம் முன் பக்கம்" : "License Front", licFront, cardColor, titleColor, isDark),
            if (licBack != null) _buildDocCard(isTamil ? "உரிமம் பின் பக்கம்" : "License Back", licBack, cardColor, titleColor, isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildDocCard(String title, String path, Color cardColor, Color titleColor, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.02),
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: titleColor),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      backgroundColor: Colors.black,
                      appBar: AppBar(
                        backgroundColor: Colors.black,
                        iconTheme: const IconThemeData(color: Colors.white),
                        title: Text(title, style: const TextStyle(color: Colors.white)),
                      ),
                      body: Center(
                        child: InteractiveViewer(
                          panEnabled: true,
                          minScale: 0.5,
                          maxScale: 4,
                          child: Image.network(
                            ApiConstants.getImageUrl(path),
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey, size: 50),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
              child: Image.network(
                ApiConstants.getImageUrl(path),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankGrid(
    Map<String, dynamic>? data,
    bool isLoading,
    Color cardColor,
    Color titleColor,
    Color subColor,
    bool isTamil,
  ) {
    final List<Map<String, dynamic>> items = [
      {
        'title': isTamil ? 'வங்கி பெயர்' : 'Bank Name',
        'val': data?['bank_name'],
        'icon': Icons.account_balance_rounded,
        'color': Colors.blue,
      },
      {
        'title': isTamil ? 'கணக்கு எண்' : 'Account Number',
        'val': data?['account_number'],
        'icon': Icons.numbers_rounded,
        'color': Colors.green,
      },
      {
        'title': isTamil ? 'IFSC குறியீடு' : 'IFSC Code',
        'val': data?['ifsc_code'],
        'icon': Icons.code_rounded,
        'color': Colors.orange,
      },
      {
        'title': isTamil ? 'கிளை பெயர்' : 'Branch Name',
        'val': data?['branch_name'],
        'icon': Icons.store_rounded,
        'color': Colors.purple,
      },
      {
        'title': isTamil ? 'துணை வங்கி' : 'Sub Bank Name',
        'val': data?['sub_bank_name'],
        'icon': Icons.account_balance_wallet_rounded,
        'color': Colors.teal,
      },
      {
        'title': isTamil ? 'துணை கணக்கு' : 'Sub Account Number',
        'val': data?['sub_account_number'],
        'icon': Icons.numbers_rounded,
        'color': Colors.cyan,
      },
      {
        'title': isTamil ? 'துணை IFSC' : 'Sub IFSC Code',
        'val': data?['sub_bank_ifsc_code'],
        'icon': Icons.code_rounded,
        'color': Colors.deepOrange,
      },
      {
        'title': isTamil ? 'துணை கிளை' : 'Sub Branch Name',
        'val': data?['sub_bank_branch_name'],
        'icon': Icons.store_mall_directory_rounded,
        'color': Colors.indigo,
      },
    ];
    return _renderGrid(items, isLoading, cardColor, titleColor, subColor);
  }

  Widget _buildSalaryGrid(
    Map<String, dynamic>? data,
    bool isLoading,
    Color cardColor,
    Color titleColor,
    Color subColor,
    bool isTamil,
  ) {
    final List<Map<String, dynamic>> items = [
      {
        'title': isTamil ? 'அடிப்படை சம்பளம்' : 'Basic Salary',
        'val': data?['driverProfile']?['salary_basic'],
        'icon': Icons.currency_rupee_rounded,
        'color': Colors.green,
      },
      {
        'title': isTamil ? 'மொத்த சம்பளம்' : 'Gross Salary',
        'val': data?['driverProfile']?['gross_salary'],
        'icon': Icons.account_balance_wallet_rounded,
        'color': Colors.blue,
      },
      {
        'title': isTamil ? 'அகவிலைப்படி (DA)' : 'DA',
        'val': data?['driverProfile']?['da'],
        'icon': Icons.trending_up_rounded,
        'color': Colors.orange,
      },
      {
        'title': isTamil ? 'சிறப்பு படி (SA)' : 'SA',
        'val': data?['driverProfile']?['sa'],
        'icon': Icons.star_rounded,
        'color': Colors.purple,
      },
      {
        'title': isTamil ? 'EPFO பங்களிப்பு' : 'EPFO Contribution',
        'val': data?['driverProfile']?['epfo_management_contribution'],
        'icon': Icons.savings_rounded,
        'color': Colors.teal,
      },
      {
        'title': isTamil ? 'ஷிப்ட்' : 'Shift',
        'val': data?['driverProfile']?['shift'],
        'icon': Icons.schedule_rounded,
        'color': Colors.indigo,
      },
    ];
    return _renderGrid(items, isLoading, cardColor, titleColor, subColor);
  }

  Widget _renderGrid(
    List<Map<String, dynamic>> items,
    bool isLoading,
    Color cardColor,
    Color titleColor,
    Color subColor,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final bool isDataMissing = item['val'] == null && isLoading;
        return InfoCard(
          title: item['title'],
          value: isDataMissing ? "" : (item['val'] ?? "—").toString(),
          valueWidget: isDataMissing
              ? TypingText(
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
          icon: item['icon'],
          iconColor: item['color'],
          cardColor: cardColor,
          titleColor: titleColor,
          subColor: subColor,
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, Color titleColor, bool isTamil) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          isTamil ? "ஓட்டுநர் விவரம்" : "Driver Profile",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: titleColor,
          ),
        ),
        IconButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            );
            if (mounted) setState(() {});
          },
          icon: Icon(
            Icons.settings_outlined,
            color: titleColor.withOpacity(0.6),
            size: 26,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String error, Color titleColor, bool isTamil) {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 10),
          Text(error, style: TextStyle(color: titleColor)),
          TextButton(
            onPressed: () => useDriverStore.fetchProfile(),
            child: Text(isTamil ? "மீண்டும் முயற்சி" : "Retry"),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundDecor(bool isDark) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -60,
            child: CircleAvatar(
              radius: 140,
              backgroundColor: const Color(
                0xFF6366F1,
              ).withOpacity(isDark ? 0.06 : 0.04),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -40,
            child: CircleAvatar(
              radius: 80,
              backgroundColor: const Color(
                0xFFA855F7,
              ).withOpacity(isDark ? 0.04 : 0.02),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return "—";
    try {
      final dt = DateTime.parse(dateStr);
      return "${dt.day}/${dt.month}/${dt.year}";
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildScannerTile(
    BuildContext context,
    bool isDark,
    Color surfaceColor,
    Color titleColor,
    bool isTamil,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
        ),
      ),
      child: ListTile(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ScannerPage(),
            ),
          );
          if (result != null) {
            showTopToast(context, isTamil ? "ஸ்கேன் செய்யப்பட்டது: $result" : "Scanned: $result");
          }
        },
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF6366F1), size: 22),
        ),
        title: Text(
          isTamil ? "ஸ்கேன் செய்க" : "Scan Code",
          style: TextStyle(fontWeight: FontWeight.w800, color: titleColor),
        ),
        subtitle: Text(
          isTamil ? "கேமராவை வைத்து ஸ்கேன் செய்யவும்" : "Scan using camera",
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      ),
    );
  }
}
