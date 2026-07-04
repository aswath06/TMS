import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tripzo/store/driver_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/providers.dart';
import 'package:tripzo/screens/admin/edit_driver_screen.dart';
import 'package:tripzo/utils/api_constants.dart';

class AdminDriverDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> driver;

  const AdminDriverDetailScreen({super.key, required this.driver});

  @override
  ConsumerState<AdminDriverDetailScreen> createState() => _AdminDriverDetailScreenState();
}

class _AdminDriverDetailScreenState extends ConsumerState<AdminDriverDetailScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Map<String, dynamic> _driverData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _driverData = Map<String, dynamic>.from(widget.driver);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.forward();
    _loadFullDetails();
  }

  Future<void> _loadFullDetails() async {
    final driverId = _driverData['user_id'] ?? _driverData['id'];
    if (driverId == null) return;
    
    if (mounted) {
      setState(() => _isLoading = true);
    }

    final store = ref.read(driverStoreProvider);
    final fullData = await store.fetchDriverById(driverId);
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (fullData != null) {
          _driverData = fullData;
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final base = ApiConstants.baseUrl;
    final relative = path.startsWith('/') ? path : '/$path';
    final url = '$base$relative';
    return url.contains('?') ? '$url&v=2' : '$url?v=2';
  }

  void _showFullScreenImage(String imageUrl) {
    if (imageUrl.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            imageUrl,
            headers: const {'X-Tunnel-Skip-Anti-Phishing-Page': 'true'},
          ),
        ),
      ),
    )));
  }

  Widget _buildAnimatedSection(Widget child, int index) {
    final delay = index * 0.1;
    final animation = CurvedAnimation(
      parent: _animationController,
      curve: Interval(delay > 1.0 ? 1.0 : delay, 1.0, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - animation.value)),
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final Color surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF1E293B);

    final store = ref.read(driverStoreProvider);
    final status = _driverData['status'] ?? 1;
    final statusLabel = store.getStatusLabel(status);
    final statusColor = store.getStatusColor(status);
    final dp = _driverData['driverProfile'] ?? _driverData;

    int sectionIndex = 0;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: titleColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Driver Details",
          style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: primaryBlue),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditDriverScreen(driver: _driverData),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadFullDetails,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          child: Column(
            children: [
            const SizedBox(height: 20),
            _buildAnimatedSection(
              _buildProfileHero(context, isDark, surfaceColor, primaryBlue, statusLabel, statusColor),
              sectionIndex++,
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAnimatedSection(
                    _buildSectionBlock(
                      "Personal Information",
                      [
                        _InfoItem(Icons.person, "Full Name", _driverData['name'] ?? 'N/A'),
                        _InfoItem(Icons.phone, "Phone", _driverData['phone'] ?? 'N/A'),
                        _InfoItem(Icons.phone_android, "Alt Phone", _driverData['mobile_number_2'] ?? 'N/A'),
                        _InfoItem(Icons.email, "Email", _driverData['email'] ?? 'N/A'),
                        _InfoItem(Icons.cake, "DOB / Age", "${_formatDate(_driverData['dob'])} (${_driverData['age'] ?? '-'})"),
                        _InfoItem(Icons.wc, "Gender", _driverData['gender'] ?? 'N/A'),
                        _InfoItem(Icons.bloodtype, "Blood Group", dp['blood_group'] ?? 'N/A'),
                        _InfoItem(Icons.family_restroom, "Marital Status", dp['marital_status'] ?? 'N/A'),
                        _InfoItem(Icons.location_on, "Address", dp['address'] ?? 'N/A'),
                      ],
                      titleColor, surfaceColor, isDark,
                    ),
                    sectionIndex++,
                  ),

                  _buildAnimatedSection(
                    _buildSectionBlock(
                      "Identity & Demographics",
                      [
                        _InfoItem(Icons.credit_card, "Aadhar No", _driverData['aadhar_number'] ?? 'N/A'),
                        _InfoItem(Icons.mosque, "Religion", _driverData['religious'] ?? 'N/A'),
                        _InfoItem(Icons.groups, "Caste", _driverData['caste'] ?? 'N/A'),
                        _InfoItem(Icons.group_work, "Community", _driverData['community'] ?? 'N/A'),
                      ],
                      titleColor, surfaceColor, isDark,
                    ),
                    sectionIndex++,
                  ),

                  _buildAnimatedSection(
                    _buildSectionBlock(
                      "Family Details",
                      [
                        _InfoItem(Icons.man, "Father's Name", _driverData['father_name'] ?? 'N/A'),
                        _InfoItem(Icons.woman, "Mother's Name", _driverData['mother_name'] ?? 'N/A'),
                        _InfoItem(Icons.favorite, "Spouse's Name", _driverData['spouse_name'] ?? 'N/A'),
                      ],
                      titleColor, surfaceColor, isDark,
                    ),
                    sectionIndex++,
                  ),

                  _buildAnimatedSection(
                    _buildSectionBlock(
                      "Professional Details",
                      [
                        _InfoItem(Icons.badge, "Employee Code", dp['employee_code'] ?? 'N/A'),
                        _InfoItem(Icons.description, "License No", dp['license_number'] ?? 'N/A'),
                        _InfoItem(Icons.event, "License Expiry", _formatDate(dp['license_expiry_date'] ?? dp['license_expiry'])),
                        _InfoItem(Icons.event_busy, "Non-Transport Exp.", _formatDate(dp['non_transport_expiry_date'])),
                        _InfoItem(Icons.calendar_today, "Joining Date", _formatDate(dp['joining_date'] ?? dp['created_at'])),
                        _InfoItem(Icons.history, "Exp. Total", "${dp['experience_years'] ?? 0} Years"),
                        _InfoItem(Icons.work_history, "Exp. at BIT", "${dp['experience_at_Bit'] ?? 0} Years"),
                        _InfoItem(Icons.directions_car, "Vehicle Type", dp['Vehicle_type'] ?? 'N/A'),
                        _InfoItem(Icons.schedule, "Shift", dp['shift'] ?? 'N/A'),
                      ],
                      titleColor, surfaceColor, isDark,
                    ),
                    sectionIndex++,
                  ),

                  _buildAnimatedSection(
                    _buildSectionBlock(
                      "Emergency & Nominee",
                      [
                        _InfoItem(Icons.contact_emergency, "Emg. Name", dp['emergency_contact_name'] ?? 'N/A'),
                        _InfoItem(Icons.phone_callback, "Emg. Phone", dp['emergency_contact_phone'] ?? 'N/A'),
                        _InfoItem(Icons.person_outline, "Nominee", dp['nominee_name'] ?? 'N/A'),
                        _InfoItem(Icons.people_outline, "Relation", dp['nominee_relation'] ?? 'N/A'),
                        _InfoItem(Icons.event_available, "Nominee DOB", _formatDate(dp['nominee_dob'])),
                      ],
                      titleColor, surfaceColor, isDark,
                    ),
                    sectionIndex++,
                  ),

                  _buildAnimatedSection(
                    _buildSectionBlock(
                      "Bank & Salary",
                      [
                        _InfoItem(Icons.account_balance, "Bank Name", _driverData['bank_name'] ?? 'N/A'),
                        _InfoItem(Icons.numbers, "Account No", _driverData['account_number'] ?? 'N/A'),
                        _InfoItem(Icons.code, "IFSC Code", _driverData['ifsc_code'] ?? 'N/A'),
                        _InfoItem(Icons.store, "Branch", _driverData['branch_name'] ?? 'N/A'),
                        _InfoItem(Icons.account_balance, "Sub Bank", _driverData['sub_bank_name'] ?? 'N/A'),
                        _InfoItem(Icons.numbers, "Sub Acc No", _driverData['sub_account_number'] ?? 'N/A'),
                        _InfoItem(Icons.payments, "Basic Salary", "₹${dp['salary_basic'] ?? '0.00'}"),
                        _InfoItem(Icons.trending_up, "DA", "₹${dp['da'] ?? '0.00'}"),
                        _InfoItem(Icons.card_membership, "SA", "₹${dp['sa'] ?? '0.00'}"),
                        _InfoItem(Icons.security, "EPFO", "₹${dp['epfo_management_contribution'] ?? '0.00'}"),
                        _InfoItem(Icons.account_balance_wallet, "Gross Salary", "₹${dp['gross_salary'] ?? '0.00'}"),
                      ],
                      titleColor, surfaceColor, isDark,
                    ),
                    sectionIndex++,
                  ),

                  _buildAnimatedSection(
                    _buildAttachmentsSection(titleColor, surfaceColor, isDark),
                    sectionIndex++,
                  ),

                  _buildAnimatedSection(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle("Statistics", titleColor),
                        const SizedBox(height: 16),
                        _buildStatsRow(primaryBlue, surfaceColor, isDark),
                      ],
                    ),
                    sectionIndex++,
                  ),
                  
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildAttachmentsSection(Color titleColor, Color surfaceColor, bool isDark) {
    final dp = _driverData['driverProfile'] ?? _driverData;
    
    final attachments = [
      {'title': 'Profile Photo', 'url': _driverData['profile_photo']},
      {'title': 'Aadhar Photo', 'url': _driverData['aadhar_photo']},
      {'title': 'License Front', 'url': dp['licence_image_front']},
      {'title': 'License Back', 'url': dp['licence_image_back']},
      {'title': 'PAN Image', 'url': dp['pan_image']},
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Attachments & Documents", titleColor),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: attachments.length,
            itemBuilder: (context, index) {
              final item = attachments[index];
              final String title = item['title'] as String;
              final String? rawUrl = item['url'] as String?;
              final String url = _getImageUrl(rawUrl);
              final bool hasImage = url.isNotEmpty;

              return GestureDetector(
                onTap: hasImage ? () => _showFullScreenImage(url) : null,
                child: Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                          child: hasImage 
                            ? Image.network(
                                url, 
                                headers: const {'X-Tunnel-Skip-Anti-Phishing-Page': 'true'},
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, color: Colors.grey.withValues(alpha: 0.5), size: 40),
                              )
                            : Container(
                                color: isDark ? Colors.black12 : Colors.grey.shade100,
                                child: Icon(Icons.image_not_supported_outlined, color: Colors.grey.withValues(alpha: 0.3), size: 40),
                              ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black12 : Colors.grey.shade50,
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
                        ),
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSectionBlock(String title, List<_InfoItem> items, Color titleColor, Color surfaceColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title, titleColor),
        const SizedBox(height: 16),
        _buildInfoGrid(items, surfaceColor, isDark),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildProfileHero(
    BuildContext context,
    bool isDark,
    Color surfaceColor,
    Color primaryBlue,
    String statusLabel,
    Color statusColor,
  ) {
    final store = useDriverStore;
    final status = _driverData['status'] ?? 1;
    final profilePhotoUrl = _getImageUrl(_driverData['profile_photo']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              GestureDetector(
                onTap: profilePhotoUrl.isNotEmpty ? () => _showFullScreenImage(profilePhotoUrl) : null,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[200],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // If NOT loading and we have NO image, show initials
                      if (!_isLoading && profilePhotoUrl.isEmpty)
                        Center(
                          child: Text(
                            _getInitials(_driverData['name'] ?? ''),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      
                      // If NOT loading and we HAVE an image, show the image with its own loader
                      if (!_isLoading && profilePhotoUrl.isNotEmpty)
                        Image.network(
                          profilePhotoUrl,
                          headers: const {'X-Tunnel-Skip-Anti-Phishing-Page': 'true'},
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: Colors.white, size: 50),
                        ),

                      // If the API call is STILL loading, show spinner overlay
                      if (_isLoading)
                        const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    store.getStatusIcon(status),
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _driverData['name'] ?? 'Unknown',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "@${_driverData['username'] ?? _driverData['user_name'] ?? 'username'}",
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(store.getStatusIcon(status), color: statusColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

  Widget _buildInfoGrid(
    List<_InfoItem> items,
    Color surfaceColor,
    bool isDark,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(item.icon, size: 16, color: const Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.label,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.value,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsRow(Color primaryBlue, Color surfaceColor, bool isDark) {
    final dp = _driverData['driverProfile'] ?? _driverData;
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            "Total KM",
            "${dp['total_kilometer_drive'] ?? dp['total_kilometer_drived'] ?? 0}",
            Icons.speed,
            primaryBlue,
            surfaceColor,
            isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            "Total Routes",
            "${dp['total_routes'] ?? 0}",
            Icons.route,
            const Color(0xFF10B981),
            surfaceColor,
            isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    Color surfaceColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return "D";
    final parts = name.trim().split(RegExp(r'\s+'));
    String initials = parts.first[0];
    if (parts.length > 1) initials += parts.last[0];
    return initials.toUpperCase();
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr.toString());
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateStr.toString();
    }
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;
  _InfoItem(this.icon, this.label, this.value);
}
