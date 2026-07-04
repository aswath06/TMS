import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/store/user_store.dart';

class UserSessionManagementPage extends StatefulWidget {
  const UserSessionManagementPage({super.key});

  @override
  State<UserSessionManagementPage> createState() => _UserSessionManagementPageState();
}

class _UserSessionManagementPageState extends State<UserSessionManagementPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _users = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  static const int _limit = 15;
  String _searchQuery = '';
  Timer? _searchDebounce;
  final Set<int> _loggingOut = {};

  @override
  void initState() {
    super.initState();
    _fetchUsers(isRefresh: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _fetchUsers();
      }
    }
  }

  Future<void> _fetchUsers({bool isRefresh = false}) async {
    if (isRefresh) {
      if (!mounted) return;
      setState(() {
        _currentPage = 1;
        _hasMore = true;
        _users = [];
        _isLoading = true;
      });
    } else {
      if (_isLoadingMore || !_hasMore) return;
      if (!mounted) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final token = await UserStore.getToken();
      String url = '${ApiConstants.baseUrl}/auth/users?page=$_currentPage&limit=$_limit';
      if (_searchQuery.isNotEmpty) {
        url += '&search=${Uri.encodeComponent(_searchQuery)}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> newUsers = data['data'] ?? data['users'] ?? [];
        setState(() {
          if (isRefresh) {
            _users = newUsers;
          } else {
            _users.addAll(newUsers);
          }
          _isLoading = false;
          _isLoadingMore = false;
          if (newUsers.length < _limit) {
            _hasMore = false;
          } else {
            _currentPage++;
          }
        });
      } else {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _searchQuery = query;
      _fetchUsers(isRefresh: true);
    });
  }

  Future<void> _logoutUser(dynamic user) async {
    final int userId = user['id'];
    final String name = user['name'] ?? 'this user';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.all(28),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded, color: Colors.red, size: 30),
              ),
              const SizedBox(height: 18),
              Text(
                'Force Logout?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'This will immediately end the active session of\n"$name".',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Force Logout', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    if (!mounted) return;
    setState(() => _loggingOut.add(userId));

    try {
      final token = await UserStore.getToken();
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/auth/admin/logout-user/$userId'),
        headers: ApiConstants.getHeaders(token),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          final idx = _users.indexWhere((u) => u['id'] == userId);
          if (idx != -1) _users[idx]['is_login'] = false;
          _loggingOut.remove(userId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text('$name has been logged out'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        setState(() => _loggingOut.remove(userId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to logout user'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loggingOut.remove(userId));
    }
  }

  Color _roleColor(String? code) {
    switch (code?.toUpperCase()) {
      case 'SUPER_ADMIN': return const Color(0xFF8B5CF6);
      case 'TRANSPORT_ADMIN': return const Color(0xFF6366F1);
      case 'FACULTY': return const Color(0xFF3B82F6);
      case 'DRIVER': return const Color(0xFF10B981);
      default: return const Color(0xFF64748B);
    }
  }

  IconData _roleIcon(String? code) {
    switch (code?.toUpperCase()) {
      case 'SUPER_ADMIN': return Icons.shield_rounded;
      case 'TRANSPORT_ADMIN': return Icons.admin_panel_settings_rounded;
      case 'FACULTY': return Icons.school_rounded;
      case 'DRIVER': return Icons.directions_car_filled_rounded;
      default: return Icons.person_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final Color surface = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    const Color primary = Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: bg,
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            backgroundColor: bg,
            elevation: 0,
            floating: true,
            snap: true,
            pinned: true,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: titleColor, size: 16),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            title: Text(
              'User Sessions',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: titleColor,
              ),
            ),
            centerTitle: true,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(70),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: TextStyle(color: titleColor),
                    decoration: InputDecoration(
                      hintText: 'Search by name, role, email…',
                      hintStyle: TextStyle(color: subColor, fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: subColor),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close_rounded, color: subColor, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        body: _isLoading
            ? _buildSkeletonList(isDark)
            : _users.isEmpty
                ? _buildEmptyState(subColor)
                : RefreshIndicator(
                    onRefresh: () => _fetchUsers(isRefresh: true),
                    color: primary,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _users.length + (_isLoadingMore ? 1 : 0) + (_hasMore && !_isLoadingMore && _users.isNotEmpty ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _users.length) {
                          if (_isLoadingMore) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: CircularProgressIndicator(color: primary, strokeWidth: 2.5)),
                            );
                          }
                          if (_hasMore) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted && !_isLoadingMore) _fetchUsers();
                            });
                            return const SizedBox.shrink();
                          }
                        }
                        if (index >= _users.length) return const SizedBox.shrink();
                        return _buildUserCard(_users[index], isDark, surface, titleColor, subColor);
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildUserCard(dynamic user, bool isDark, Color surface, Color titleColor, Color subColor) {
    final int userId = user['id'] ?? 0;
    final String name = user['name'] ?? 'Unknown';
    final String email = user['email'] ?? '';
    final String phone = user['phone'] ?? '';
    final bool isLoggedIn = user['is_login'] == true;
    final dynamic role = user['role'];
    final String roleCode = role?['code'] ?? '';
    final String roleName = role?['name'] ?? 'Unknown';
    final bool roleActive = role?['is_active'] == true;
    final Color roleClr = _roleColor(roleCode);
    final bool isLoggingOut = _loggingOut.contains(userId);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLoggedIn
              ? const Color(0xFF10B981).withValues(alpha: 0.25)
              : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04)),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: roleClr.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_roleIcon(roleCode), color: roleClr, size: 24),
                ),
                if (isLoggedIn)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(color: surface, width: 2),
                        boxShadow: [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.4), blurRadius: 4)],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Role badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: roleClr.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          roleName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: roleClr,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: subColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.phone_rounded, size: 12, color: subColor),
                        const SizedBox(width: 4),
                        Text(
                          phone,
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: subColor),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Login status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isLoggedIn
                              ? const Color(0xFF10B981).withValues(alpha: 0.1)
                              : subColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isLoggedIn ? const Color(0xFF10B981) : subColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isLoggedIn ? 'Active Session' : 'Offline',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isLoggedIn ? const Color(0xFF10B981) : subColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!roleActive) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Inactive',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      // Logout button only if active session
                      if (isLoggedIn)
                        GestureDetector(
                          onTap: isLoggingOut ? null : () => _logoutUser(user),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isLoggingOut
                                  ? Colors.red.withValues(alpha: 0.05)
                                  : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: isLoggingOut ? 0.2 : 0.3),
                              ),
                            ),
                            child: isLoggingOut
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      color: Colors.red,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.logout_rounded, size: 13, color: Colors.red),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Logout',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: 8,
      itemBuilder: (_, i) => _buildSkeletonCard(isDark),
    );
  }

  Widget _buildSkeletonCard(bool isDark) {
    final shimmerColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: shimmerColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _shimmerBox(52, 52, circular: true, isDark: isDark),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(12, 140, isDark: isDark),
                const SizedBox(height: 8),
                _shimmerBox(10, 200, isDark: isDark),
                const SizedBox(height: 8),
                _shimmerBox(10, 100, isDark: isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmerBox(double h, double w, {bool circular = false, required bool isDark}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 0.7),
      duration: const Duration(milliseconds: 900),
      builder: (_, value, _) => Container(
        height: h,
        width: w,
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: value * 0.08),
          borderRadius: BorderRadius.circular(circular ? 100 : 8),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color subColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.manage_accounts_rounded, size: 72, color: subColor.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            'No users found',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: subColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: subColor.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}
