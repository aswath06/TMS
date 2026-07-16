import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/providers.dart';
import 'package:tripzo/components/leave_card.dart';
import 'package:tripzo/store/admin_dashboard_store.dart';
import 'package:tripzo/utils/toast_utils.dart';
import 'package:tripzo/components/common/custom_date_time_picker.dart';


class ViewAllLeavesPage extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> leaves;

  const ViewAllLeavesPage({super.key, required this.leaves});

  @override
  ConsumerState<ViewAllLeavesPage> createState() => _ViewAllLeavesPageState();
}

class _ViewAllLeavesPageState extends ConsumerState<ViewAllLeavesPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _selectedFilter = 'All'; // All, Pending, Approved, Rejected
  String _selectedRole = 'Driver';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(requestStoreProvider).fetchLeaves(role: _selectedRole, reset: true);
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final store = ref.read(requestStoreProvider);
      if (!store.isLoadingLeaves && store.hasMoreLeaves) {
        store.fetchLeaves(role: _selectedRole);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: titleColor,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "All Leave Requests",
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: titleColor, size: 28),
            onPressed: () => _showApplyLeaveBottomSheet(
              context,
              isDark,
              primaryBlue,
              cardColor,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer(
builder: (context, ref, child) {
final store = ref.watch(requestStoreProvider);
          // Use leaves from store instead of widget.leaves if we want reactivity
          final currentLeaves = store.leaves;

          // Re-apply local filtering logic to store leaves
          final filtered = currentLeaves.where((leaf) {
            if (_selectedFilter != 'All' && leaf['status'] != _selectedFilter) {
              return false;
            }
            if (_searchController.text.isNotEmpty) {
              final driverName = (leaf['driver'] ?? "").toLowerCase();
              final fromDate = (leaf['from'] ?? "").toLowerCase();
              final toDate = (leaf['to'] ?? "").toLowerCase();
              final searchLower = _searchController.text.toLowerCase();
              return driverName.contains(searchLower) ||
                  fromDate.contains(searchLower) ||
                  toDate.contains(searchLower);
            }
            return true;
          }).toList();

          return RefreshIndicator(
            onRefresh: () async {
              await store.fetchLeaves(role: _selectedRole, reset: true);
              // Also refresh dashboard stats to keep counts accurate
              await useAdminDashboardStore.fetchTodayDriverCount();
            },
            color: primaryBlue,
            child: Column(
              children: [
                // Role Toggle
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: ['Driver', 'Student', 'Faculty', 'Non Teaching', 'Intern'].map((role) {
                      final isSelected = _selectedRole == role;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedRole = role;
                            });
                            store.fetchLeaves(role: _selectedRole, reset: true);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? primaryBlue : cardColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? primaryBlue : primaryBlue.withValues(alpha: 0.2),
                                width: 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: primaryBlue.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Text(
                              role,
                              style: TextStyle(
                                color: isSelected ? Colors.white : titleColor,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 5,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.2 : 0.05,
                                ),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) => setState(
                              () {},
                            ), // Trigger UI update for local filtering
                            style: TextStyle(color: titleColor),
                            decoration: InputDecoration(
                              hintText: "Search driver name or date...",
                              hintStyle: TextStyle(
                                color: titleColor.withValues(alpha: 0.4),
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: primaryBlue,
                                size: 22,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 15,
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.clear_rounded,
                                        color: titleColor.withValues(alpha: 0.4),
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {});
                                      },
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => _showFilterModal(
                          context,
                          isDark,
                          primaryBlue,
                          cardColor,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: primaryBlue.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Icon(Icons.tune, color: primaryBlue, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),

                // Active Filter Display
                if (_selectedFilter != 'All') ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                        decoration: BoxDecoration(
                        color: primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: primaryBlue.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Filter: $_selectedFilter",
                            style: TextStyle(
                              color: primaryBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedFilter = 'All';
                              });
                            },
                            child: Icon(
                              Icons.close,
                              color: primaryBlue,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Leaves List
                Expanded(
                  child: filtered.isEmpty
                      ? (store.isLoadingLeaves
                          ? const Center(child: CircularProgressIndicator())
                          : _buildEmptyState(titleColor))
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: filtered.length + (store.hasMoreLeaves ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == filtered.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(
                                  child: CircularProgressIndicator(color: primaryBlue),
                                ),
                              );
                            }
                            return LeaveCard(
                              leaf: filtered[index],
                              isDark: isDark,
                              primaryColor: primaryBlue,
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showApplyLeaveBottomSheet(
    BuildContext context,
    bool isDark,
    Color primaryBlue,
    Color cardColor,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ApplyLeaveBottomSheet(
        isDark: isDark,
        primaryBlue: primaryBlue,
        cardColor: cardColor,
      ),
    );
  }

  void _showFilterModal(
    BuildContext context,
    bool isDark,
    Color primaryBlue,
    Color surfaceColor,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Filter Leave Requests",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildFilterChip(
                        "All",
                        setModalState,
                        primaryBlue,
                        surfaceColor,
                      ),
                      _buildFilterChip(
                        "Pending",
                        setModalState,
                        primaryBlue,
                        surfaceColor,
                      ),
                      _buildFilterChip(
                        "Approved",
                        setModalState,
                        primaryBlue,
                        surfaceColor,
                      ),
                      _buildFilterChip(
                        "Rejected",
                        setModalState,
                        primaryBlue,
                        surfaceColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(
    String title,
    StateSetter setModalState,
    Color primaryBlue,
    Color surfaceColor,
  ) {
    final isSelected = _selectedFilter == title;
    return GestureDetector(
      onTap: () {
        setModalState(() {
          _selectedFilter = title;
        });
        setState(() {});
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? primaryBlue : surfaceColor,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? primaryBlue : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryBlue.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check, color: Colors.white, size: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color titleColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off_rounded,
            size: 60,
            color: titleColor.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            "No leave requests found",
            style: TextStyle(
              color: titleColor.withValues(alpha: 0.5),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplyLeaveBottomSheet extends ConsumerStatefulWidget {
  final bool isDark;
  final Color primaryBlue;
  final Color cardColor;

  const _ApplyLeaveBottomSheet({
    required this.isDark,
    required this.primaryBlue,
    required this.cardColor,
  });

  @override
  ConsumerState<_ApplyLeaveBottomSheet> createState() => _ApplyLeaveBottomSheetState();
}

class _ApplyLeaveBottomSheetState extends ConsumerState<_ApplyLeaveBottomSheet> {
  final _reasonController = TextEditingController();
  DateTime? _selectedDate;
  int? _selectedLeaveType;
  Map<String, dynamic>? _selectedDriver;
  List<Map<String, dynamic>> _filteredDrivers = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    
    // Fetch dynamic leave types and all drivers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final driverStore = ref.read(driverStoreProvider);
      if (driverStore.allDrivers.isEmpty) {
        driverStore.fetchAllDriversWithoutPagination().then((_) {
          if (mounted) {
            setState(() {
              _filteredDrivers = driverStore.allDrivers;
            });
          }
        });
      } else {
        setState(() {
          _filteredDrivers = driverStore.allDrivers;
        });
      }
    });

    // Fetch dynamic leave types
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final requestStore = ref.read(requestStoreProvider);
      requestStore.fetchLeaveTypes().then((_) {
        if (mounted && requestStore.leaveTypes.isNotEmpty) {
          setState(() {
            _selectedLeaveType = requestStore.leaveTypes.first['id'];
          });
        }
      });
    });
  }


  @override
  Widget build(BuildContext context) {
    final titleColor = widget.isDark ? Colors.white : const Color(0xFF1E293B);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height:
          MediaQuery.of(context).size.height * 0.75, // Adjust height as needed
      margin: EdgeInsets.only(top: 100), // Ensure it's not full screen
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "Apply Leave for Driver",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: titleColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Driver Selection
            _buildSectionTitle("Select Driver"),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showDriverPicker(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: widget.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedDriver != null
                        ? widget.primaryBlue
                        : Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedDriver != null
                          ? Icons.person_rounded
                          : Icons.person_search_rounded,
                      color: _selectedDriver != null
                          ? widget.primaryBlue
                          : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedDriver != null
                            ? _selectedDriver!['name']
                            : "Choose a driver...",
                        style: TextStyle(
                          color: _selectedDriver != null ? titleColor : Colors.grey,
                          fontWeight: _selectedDriver != null ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle("Select Date"),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: widget.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedDate != null
                        ? widget.primaryBlue
                        : Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.date_range_rounded,
                      color: _selectedDate != null ? widget.primaryBlue : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedDate != null
                            ? DateFormat('dd MMM yyyy').format(_selectedDate!)
                            : "Choose a date...",
                        style: TextStyle(
                          color: _selectedDate != null ? titleColor : Colors.grey,
                          fontWeight: _selectedDate != null ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionTitle("Leave Type"),
            const SizedBox(height: 12),
            Consumer(
builder: (context, ref, child) {
final requestStore = ref.watch(requestStoreProvider);
                final types = requestStore.leaveTypes;
                if (requestStore.isLoadingLeaveTypes && _selectedLeaveType == null) {
                  return Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: widget.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: const Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                  );
                }
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: widget.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedLeaveType,
                      isExpanded: true,
                      hint: const Text("Select leave type", style: TextStyle(color: Colors.grey)),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
                      onChanged: (val) => setState(() => _selectedLeaveType = val),
                      items: types.map((type) {
                        return DropdownMenuItem<int>(
                          value: type['id'],
                          child: Text(type['name'] ?? type['code'] ?? ""),
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
            // Reason
            _buildSectionTitle("Reason"),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              style: TextStyle(color: titleColor),
              decoration: InputDecoration(
                filled: true,
                fillColor: widget.cardColor,
                hintText: "Enter the reason for leave...",
                hintStyle: TextStyle(
                  color: Colors.grey.withValues(alpha: 0.6),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitLeave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSubmitting
                      ? widget.primaryBlue.withValues(alpha: 0.6)
                      : widget.primaryBlue,
                  disabledBackgroundColor: widget.primaryBlue.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        "Submit Application",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
      ),
    );
  }

  void _pickDate() async {
    final picked = await CustomDateTimePicker.show(
      context,
      initialDate: _selectedDate ?? DateTime.now(),
      minDate: DateTime.now(),
      maxDate: DateTime.now().add(const Duration(days: 365)),
      showTime: false,
      accent: widget.primaryBlue,
      cardColor: widget.cardColor,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showDriverPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final titleColor = widget.isDark
                ? Colors.white
                : const Color(0xFF1E293B);
            final subColor = widget.isDark 
                ? const Color(0xFF94A3B8) 
                : const Color(0xFF64748B);

            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              padding: EdgeInsets.only(
                top: 16,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  Text(
                    "Select Driver",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Search and select a driver from the list below",
                    style: TextStyle(fontSize: 14, color: subColor, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    onChanged: (val) {
                      setModalState(() {
                        final driverStore = ref.read(driverStoreProvider);
                        if (val.isEmpty) {
                          _filteredDrivers = driverStore.allDrivers;
                        } else {
                          _filteredDrivers = driverStore.allDrivers
                              .where(
                                (d) => (d['name'] ?? "").toLowerCase().contains(
                                  val.toLowerCase(),
                                ),
                              )
                              .toList();
                        }
                      });
                    },
                    style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: "Search by name...",
                      hintStyle: TextStyle(color: subColor, fontWeight: FontWeight.normal),
                      prefixIcon: Icon(Icons.search_rounded, color: widget.primaryBlue),
                      filled: true,
                      fillColor: widget.isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _filteredDrivers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_off_rounded, size: 48, color: subColor.withValues(alpha: 0.3)),
                                const SizedBox(height: 12),
                                Text(
                                  "No drivers found",
                                  style: TextStyle(color: subColor, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: _filteredDrivers.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final d = _filteredDrivers[index];
                              final bool isSelected = _selectedDriver != null && _selectedDriver!['id'] == d['id'];
                              
                              return GestureDetector(
                                onTap: () {
                                  setState(() => _selectedDriver = d);
                                  Navigator.pop(context);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isSelected 
                                        ? widget.primaryBlue.withValues(alpha: 0.1)
                                        : (widget.isDark ? const Color(0xFF0F172A) : Colors.white),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected 
                                          ? widget.primaryBlue
                                          : Colors.grey.withValues(alpha: 0.2),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: widget.primaryBlue.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            (d['name'] ?? "U")[0].toUpperCase(),
                                            style: TextStyle(
                                              color: widget.primaryBlue,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              d['name'] ?? "Unknown",
                                              style: TextStyle(
                                                color: titleColor,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              d['phone'] ?? "No Phone Number",
                                              style: TextStyle(
                                                color: subColor,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(Icons.check_circle_rounded, color: widget.primaryBlue, size: 28),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _submitLeave() async {
    if (_selectedDriver == null ||
        _selectedDate == null ||
        _selectedLeaveType == null ||
        _reasonController.text.isEmpty) {
      showTopToast(
        context,
        "Please fill all fields",
        isError: true,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final navigator = Navigator.of(context);
    final requestStore = ref.read(requestStoreProvider);

    // Build ISO datetime strings for a full day (00:00:00 to 00:00:00)
    final String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    final String fromDatetime = "${dateStr}T00:00:00";
    final String toDatetime = "${dateStr}T00:00:00";

    final success = await requestStore.createLeave(
      driverId: _selectedDriver!['id'],
      fromDatetime: fromDatetime,
      toDatetime: toDatetime,
      leaveType: _selectedLeaveType!,
      reason: _reasonController.text,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        showTopToast(context, "Leave applied successfully");
        navigator.pop();
      } else {
        showTopToast(
          context,
          requestStore.leavesErrorMessage ?? "Failed to apply leave",
          isError: true,
        );
      }
    }
  }
}
