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

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final base = ApiConstants.baseUrl.endsWith('/') ? ApiConstants.baseUrl.substring(0, ApiConstants.baseUrl.length - 1) : ApiConstants.baseUrl;
    final relative = path.startsWith('/') ? path : '/$path';
    return '$base$relative';
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
    final status = widget.driver['status'] ?? 1;
    final statusLabel = store.getStatusLabel(status);
    final statusColor = store.getStatusColor(status);
    final dp = widget.driver['driverProfile'] ?? widget.driver;

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
                  builder: (context) => EditDriverScreen(driver: widget.driver),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
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
                        _InfoItem(Icons.person, "Full Name", widget.driver['name'] ?? 'N/A'),
                        _InfoItem(Icons.phone, "Phone", widget.driver['phone'] ?? 'N/A'),
                        _InfoItem(Icons.phone_android, "Alt Phone", widget.driver['mobile_number_2'] ?? 'N/A'),
                        _InfoItem(Icons.email, "Email", widget.driver['email'] ?? 'N/A'),
                        _InfoItem(Icons.cake, "DOB / Age", "${_formatDate(widget.driver['dob'])} (${widget.driver['age'] ?? '-'})"),
                        _InfoItem(Icons.wc, "Gender", widget.driver['gender'] ?? 'N/A'),
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
                        _InfoItem(Icons.credit_card, "Aadhar No", widget.driver['aadhar_number'] ?? 'N/A'),
                        _InfoItem(Icons.mosque, "Religion", widget.driver['religious'] ?? 'N/A'),
                        _InfoItem(Icons.groups, "Caste", widget.driver['caste'] ?? 'N/A'),
                        _InfoItem(Icons.group_work, "Community", widget.driver['community'] ?? 'N/A'),
                      ],
                      titleColor, surfaceColor, isDark,
                    ),
                    sectionIndex++,
                  ),

                  _buildAnimatedSection(
                    _buildSectionBlock(
                      "Family Details",
                      [
                        _InfoItem(Icons.man, "Father's Name", widget.driver['father_name'] ?? 'N/A'),
                        _InfoItem(Icons.woman, "Mother's Name", widget.driver['mother_name'] ?? 'N/A'),
                        _InfoItem(Icons.favorite, "Spouse's Name", widget.driver['spouse_name'] ?? 'N/A'),
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
                        _InfoItem(Icons.account_balance, "Bank Name", widget.driver['bank_name'] ?? 'N/A'),
                        _InfoItem(Icons.numbers, "Account No", widget.driver['account_number'] ?? 'N/A'),
                        _InfoItem(Icons.code, "IFSC Code", widget.driver['ifsc_code'] ?? 'N/A'),
                        _InfoItem(Icons.store, "Branch", widget.driver['branch_name'] ?? 'N/A'),
                        _InfoItem(Icons.account_balance, "Sub Bank", widget.driver['sub_bank_name'] ?? 'N/A'),
                        _InfoItem(Icons.numbers, "Sub Acc No", widget.driver['sub_account_number'] ?? 'N/A'),
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
    );
  }

  Widget _buildAttachmentsSection(Color titleColor, Color surfaceColor, bool isDark) {
    final dp = widget.driver['driverProfile'] ?? widget.driver;
    
    final attachments = [
      {'title': 'Profile Photo', 'url': widget.driver['profile_photo']},
      {'title': 'Aadhar Photo', 'url': widget.driver['aadhar_photo']},
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

              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04)),
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
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, color: Colors.grey.withOpacity(0.5), size: 40),
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: isDark ? Colors.black12 : Colors.grey.shade100,
                              child: Icon(Icons.image_not_supported_outlined, color: Colors.grey.withOpacity(0.3), size: 40),
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
    final status = widget.driver['status'] ?? 1;
    final profilePhotoUrl = _getImageUrl(widget.driver['profile_photo']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: profilePhotoUrl.isEmpty ? LinearGradient(
                    colors: [primaryBlue, primaryBlue.withOpacity(0.6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ) : null,
                  image: profilePhotoUrl.isNotEmpty ? DecorationImage(
                    image: NetworkImage(profilePhotoUrl),
                    fit: BoxFit.cover,
                  ) : null,
                ),
                child: profilePhotoUrl.isEmpty ? Center(
                  child: Text(
                    _getInitials(widget.driver['name'] ?? ''),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ) : null,
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
            widget.driver['name'] ?? 'Unknown',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "@${widget.driver['username'] ?? widget.driver['user_name'] ?? 'username'}",
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
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(0.2)),
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
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
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
    final dp = widget.driver['driverProfile'] ?? widget.driver;
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
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
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
