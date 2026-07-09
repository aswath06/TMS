import 'package:flutter/material.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/screens/security/security_qr_scanner_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tripzo/store/providers.dart';
import 'package:tripzo/store/security_bus_store.dart';
import 'package:tripzo/components/common/custom_date_time_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class SecurityBusScreen extends ConsumerStatefulWidget {
  const SecurityBusScreen({super.key});

  @override
  ConsumerState<SecurityBusScreen> createState() => _SecurityBusScreenState();
}

class _SecurityBusScreenState extends ConsumerState<SecurityBusScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _userRole = "";
  String _selectedChip = "";

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(securityBusStoreProvider).fetchBusRuns();
    });
  }

  Future<void> _loadUserRole() async {
    final role = await UserStore.getRole();
    if (mounted) {
      setState(() {
        _userRole = role?.toLowerCase() ?? "";
      });
    }
  }
  
  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = "";
      _selectedChip = "";
    });
  }

  List<Map<String, dynamic>> _getFilteredData(SecurityBusStore store) {
    final now = DateTime.now();
    final isFN = now.hour >= 0 && now.hour < 11;
    final isAN = now.hour >= 11;

    return store.currentData.where((d) {
      final campusInVerifiedBy = d['campusInVerifiedBy'];
      final campusOutVerifiedBy = d['campusOutVerifiedBy'];

      bool shouldHide = false;
      if (isFN) {
        if (campusInVerifiedBy != null) {
          shouldHide = true;
        }
      } else if (isAN) {
        if (campusOutVerifiedBy != null) {
          shouldHide = true;
        }
      }

      return !shouldHide;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(securityBusStoreProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final Color subColor = isDark ? Colors.white70 : Colors.black54;
    final Color scaffoldBg =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => store.fetchBusRuns(force: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildHeader(store),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: _buildSearchBar(isDark, subColor),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: _buildChips(store, isDark, subColor),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              _buildListSection(isDark, titleColor, subColor, isMobile, store),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(SecurityBusStore store) {
    final now = DateTime.now();
    final bool isToday = store.selectedDate.year == now.year && store.selectedDate.month == now.month && store.selectedDate.day == now.day;
    
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 40.0, 24.0, 24.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Bus Monitor",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Track buses entering and leaving the campus",
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  if (!isToday) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('MMM dd, yyyy').format(store.selectedDate),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              store.setSelectedDate(DateTime.now());
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF6366F1)),
                onPressed: () async {
                  final DateTime? newDate = await CustomDateTimePicker.show(
                    context,
                    initialDate: store.selectedDate,
                    showTime: false,
                  );
                  if (newDate != null) {
                    store.setSelectedDate(newDate);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF6366F1)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SecurityQrScannerScreen(defaultMode: 'Bus')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, Color subColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
        decoration: InputDecoration(
          hintText: "Search by bus number...",
          hintStyle: TextStyle(color: subColor, fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: subColor),
          filled: true,
          fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
          ),
        ),
      ),
    );
  }
  
  Widget _buildChips(SecurityBusStore store, bool isDark, Color subColor) {
    Set<String> uniqueBuses = {};
    final activeData = _getFilteredData(store);
    for (var d in activeData) {
      final assignments = d['assignments'] as List? ?? [];
      for (var a in assignments) {
        final vehicle = a['vehicle'] ?? {};
        final busNum = (vehicle['bus_number'] ?? vehicle['vehicle_number'] ?? '').toString();
        if (busNum.isNotEmpty) {
          uniqueBuses.add(busNum);
        }
      }
    }
    List<String> sortedBuses = uniqueBuses.toList()..sort();
    
    if (sortedBuses.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        spacing: 8,
        runSpacing: 10,
        children: [
          _buildCustomChip(
            label: "Clear",
            isSelected: _selectedChip == "",
            onTap: () {
              setState(() {
                _selectedChip = "";
              });
            },
            isClearButton: true,
            isDark: isDark,
          ),
          ...sortedBuses.map((bus) {
            final isSelected = _selectedChip == bus;
            return _buildCustomChip(
              label: bus,
              isSelected: isSelected,
              onTap: () {
                setState(() {
                  _selectedChip = isSelected ? "" : bus;
                });
              },
              isClearButton: false,
              isDark: isDark,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCustomChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isClearButton,
    required bool isDark,
  }) {
    final activeColor = isClearButton ? Colors.redAccent : const Color(0xFF6366F1);
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isSelected ? activeColor : (isDark ? Colors.white70 : Colors.black54);
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.1) : bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildListSection(bool isDark, Color titleColor, Color subColor, bool isMobile, SecurityBusStore store) {
    if (store.isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final query = _searchQuery.toLowerCase();
    final activeData = _getFilteredData(store);
    
    final filteredData = activeData.where((d) {
      bool matchesSearch = query.isEmpty;
      bool matchesChip = _selectedChip.isEmpty;
      
      final assignments = d['assignments'] as List? ?? [];
      for (var a in assignments) {
        final vehicle = a['vehicle'] ?? {};
        final busNumber = (vehicle['bus_number'] ?? vehicle['vehicle_number'] ?? '').toString();
        if (query.isNotEmpty && busNumber.toLowerCase().contains(query)) {
          matchesSearch = true;
        }
        if (_selectedChip.isNotEmpty && busNumber == _selectedChip) {
          matchesChip = true;
        }
      }
      return matchesSearch && matchesChip;
    }).toList();

    if (filteredData.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_bus_filled_outlined,
                  size: 60, color: Colors.grey.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              Text(
                "No buses found",
                style: TextStyle(
                    color: subColor, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final data = filteredData[index];
            return TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: Duration(milliseconds: 400 + (index * 100)),
              builder: (context, double value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: _buildCard(data, isDark, titleColor, subColor, isMobile),
            );
          },
          childCount: filteredData.length,
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> data, bool isDark, Color titleColor,
      Color subColor, bool isMobile) {
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color primary = const Color(0xFF6366F1);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.directions_bus_rounded, color: primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            data['runName'] ?? 'Unknown Run',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: titleColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: data['status'] == 'PLANNED' ? Colors.blue.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            data['status'] ?? '',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: data['status'] == 'PLANNED' ? Colors.blue : Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildBadge(Icons.calendar_today_rounded,
                            data['serviceDate'] ?? 'N/A', Colors.orange),
                        _buildBadge(Icons.access_time_rounded,
                            data['shiftCode']?.toString().replaceAll('_', ' ') ?? 'N/A', Colors.purple),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildRouteLocations(data, titleColor, isMobile),
          const SizedBox(height: 20),
          Divider(
              height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
          const SizedBox(height: 16),
          _buildVerificationInfo(data, titleColor, subColor),
          const SizedBox(height: 16),
          Divider(
              height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
          const SizedBox(height: 16),
          _buildAssignments(data, isDark, titleColor, subColor),
        ],
      ),
    );
  }

  Widget _buildVerificationInfo(Map<String, dynamic> data, Color titleColor, Color subColor) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Campus In Verified By", style: TextStyle(fontSize: 11, color: subColor, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                data['campusInVerifiedBy'] ?? 'Pending',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: data['campusInVerifiedBy'] != null ? titleColor : Colors.grey),
              ),
            ],
          ),
        ),
        Container(
          height: 30,
          width: 1,
          color: Colors.grey.withValues(alpha: 0.2),
          margin: const EdgeInsets.symmetric(horizontal: 10),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Campus Out Verified By", style: TextStyle(fontSize: 11, color: subColor, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                data['campusOutVerifiedBy'] ?? 'Pending',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: data['campusOutVerifiedBy'] != null ? titleColor : Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAssignments(Map<String, dynamic> data, bool isDark, Color titleColor, Color subColor) {
    final assignments = data['assignments'] as List? ?? [];
    if (assignments.isEmpty) {
      return Text("No assignments", style: TextStyle(color: subColor, fontSize: 12));
    }
    
    final status = data['status'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: assignments.map((a) {
        final shift = a['shift_code'] ?? 'UNKNOWN';
        final vehicle = a['vehicle'] ?? {};
        final driverUser = a['driver']?['user'] ?? {};
        
        final vehicleReg = vehicle['vehicle_number'] ?? 'N/A';
        final busId = vehicle['bus_number'] ?? '';
        final displayVehicle = busId.toString().isNotEmpty && busId.toString() != 'null' ? "$vehicleReg ($busId)" : vehicleReg;
        
        final driverName = driverUser['name'] ?? 'Unassigned';
        final driverPhone = driverUser['phone'] ?? '';
        
        bool showGatePass = false;
        String gatePassType = '';
        if (status == 'STARTED' && shift == 'MORNING') {
          showGatePass = true;
          gatePassType = 'FN';
        } else if (status == 'AN_STARTED' && shift == 'EVENING') {
          showGatePass = true;
          gatePassType = 'AN';
        }
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(12),
            border: showGatePass ? Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3), width: 1.5) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(shift.toString().replaceAll('_', ' '), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF6366F1))),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.directions_bus_rounded, size: 16, color: subColor),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(displayVehicle, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: titleColor)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.person_rounded, size: 16, color: subColor),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(driverName, 
                      style: TextStyle(fontSize: 14, color: titleColor, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (driverPhone.toString().isNotEmpty && driverPhone != 'null' && driverPhone != 'N/A')
                    GestureDetector(
                      onTap: () async {
                        final Uri url = Uri.parse("tel:${driverPhone.toString()}");
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Could not launch dialer')),
                            );
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.call_rounded, size: 18, color: Colors.white),
                      ),
                    ),
                ],
              ),
              if (showGatePass) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      final otp = vehicle['vehicle_otp'] ?? '';
                      if(otp.toString().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP not found for this shift!')));
                        return;
                      }
                      
                      final actionText = gatePassType == 'FN' ? 'reached campus?' : 'departed from the campus?';
                      
                      showDialog(
                        context: context,
                        builder: (BuildContext ctx) {
                          return Dialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.verified_user_rounded, color: Color(0xFF6366F1), size: 36),
                                  ),
                                  const SizedBox(height: 20),
                                  Text("Confirm Gate Pass", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: titleColor)),
                                  const SizedBox(height: 12),
                                  RichText(
                                    textAlign: TextAlign.center,
                                    text: TextSpan(
                                      style: TextStyle(fontSize: 15, color: subColor, height: 1.5),
                                      children: [
                                        const TextSpan(text: "Has "),
                                        TextSpan(text: displayVehicle, style: TextStyle(fontWeight: FontWeight.bold, color: titleColor)),
                                        const TextSpan(text: " driven by "),
                                        TextSpan(text: driverName, style: TextStyle(fontWeight: FontWeight.bold, color: titleColor)),
                                        TextSpan(text: " $actionText"),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextButton(
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          onPressed: () => Navigator.pop(ctx),
                                          child: Text("CANCEL", style: TextStyle(color: subColor, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF6366F1),
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            elevation: 0,
                                          ),
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            ref.read(securityBusStoreProvider.notifier).triggerGatePass(context, gatePassType, otp.toString(), data['serviceDate']);
                                            _clearFilters();
                                          },
                                          child: const Text("OK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      );
                    },
                    child: Text('GATE PASS ($gatePassType)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteLocations(Map<String, dynamic> data, Color titleColor, bool isMobile) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const Icon(Icons.radio_button_checked, size: 14, color: Colors.green),
            Container(width: 2, height: 20, color: Colors.grey.withValues(alpha: 0.3)),
            const Icon(Icons.location_on, size: 14, color: Colors.redAccent),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['startLocation'] ?? 'Unknown Start',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: titleColor),
                maxLines: isMobile ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              Text(
                data['haltLocation'] ?? 'Unknown Halt',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: titleColor),
                maxLines: isMobile ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
