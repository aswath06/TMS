import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tms/components/leave_card.dart';
import 'package:tms/store/admin_dashboard_store.dart';
import 'package:tms/store/driver_store.dart';
import 'package:tms/store/request_store.dart';

class ViewAllLeavesPage extends StatefulWidget {
  final List<Map<String, dynamic>> leaves;

  const ViewAllLeavesPage({super.key, required this.leaves});

  @override
  State<ViewAllLeavesPage> createState() => _ViewAllLeavesPageState();
}

class _ViewAllLeavesPageState extends State<ViewAllLeavesPage> {
  late List<Map<String, dynamic>> _filteredLeaves;
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All'; // All, Pending, Approved, Rejected

  @override
  void initState() {
    super.initState();
    _filteredLeaves = widget.leaves;
  }

  void _filterLeaves(String query) {
    setState(() {
      _filteredLeaves = widget.leaves.where((leaf) {
        // Filter by status
        if (_selectedFilter != 'All' && leaf['status'] != _selectedFilter) {
          return false;
        }

        // Filter by search query (driver name or date)
        if (query.isNotEmpty) {
          final driverName = (leaf['driver'] ?? "").toLowerCase();
          final fromDate = (leaf['from'] ?? "").toLowerCase();
          final toDate = (leaf['to'] ?? "").toLowerCase();
          final searchLower = query.toLowerCase();

          return driverName.contains(searchLower) ||
              fromDate.contains(searchLower) ||
              toDate.contains(searchLower);
        }

        return true;
      }).toList();
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    _filterLeaves(_searchController.text);
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
            onPressed: () => _showApplyLeaveBottomSheet(context, isDark, primaryBlue, cardColor),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<RequestStore>(
        builder: (context, store, child) {
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
              await store.fetchLeaves(page: 1, limit: 100);
              // Also refresh dashboard stats to keep counts accurate
              await useAdminDashboardStore.fetchTodayDriverCount();
            },
            color: primaryBlue,
            child: Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) => setState(() {}), // Trigger UI update for local filtering
                            style: TextStyle(color: titleColor),
                            decoration: InputDecoration(
                              hintText: "Search driver name or date...",
                              hintStyle: TextStyle(
                                color: titleColor.withOpacity(0.4),
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
                                        color: titleColor.withOpacity(0.4),
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
                        onTap: () =>
                            _showFilterModal(context, isDark, primaryBlue, cardColor),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: primaryBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: primaryBlue.withOpacity(0.2),
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
                        color: primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: primaryBlue.withOpacity(0.3),
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
                            child: Icon(Icons.close, color: primaryBlue, size: 16),
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
                      ? _buildEmptyState(titleColor)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          physics: const AlwaysScrollableScrollPhysics(), // Important for RefreshIndicator
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
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
        _filterLeaves(_searchController.text);
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
                    color: primaryBlue.withOpacity(0.2),
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
            color: titleColor.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            "No leave requests found",
            style: TextStyle(
              color: titleColor.withOpacity(0.5),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplyLeaveBottomSheet extends StatefulWidget {
  final bool isDark;
  final Color primaryBlue;
  final Color cardColor;

  const _ApplyLeaveBottomSheet({
    required this.isDark,
    required this.primaryBlue,
    required this.cardColor,
  });

  @override
  State<_ApplyLeaveBottomSheet> createState() => _ApplyLeaveBottomSheetState();
}

class _ApplyLeaveBottomSheetState extends State<_ApplyLeaveBottomSheet> {
  final _reasonController = TextEditingController();
  final _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  int _selectedLeaveType = 1; // 1: Sick, 2: Casual, 3: Emergency, 4: Other
  Map<String, dynamic>? _selectedDriver;
  List<Map<String, dynamic>> _filteredDrivers = [];

  final Map<int, String> _leaveTypes = {
    1: "Sick",
    2: "Casual",
    3: "Emergency",
    4: "Other",
  };

  @override
  void initState() {
    super.initState();
    final driverStore = Provider.of<DriverStore>(context, listen: false);
    _filteredDrivers = driverStore.drivers;
  }

  void _filterDrivers(String query) {
    final driverStore = Provider.of<DriverStore>(context, listen: false);
    setState(() {
      if (query.isEmpty) {
        _filteredDrivers = driverStore.drivers;
      } else {
        _filteredDrivers = driverStore.drivers
            .where((d) => (d['name'] ?? "").toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = widget.isDark ? Colors.white : const Color(0xFF1E293B);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75, // Adjust height as needed
      margin: EdgeInsets.only(top: 100), // Ensure it's not full screen
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
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
                Text(
                  "Apply Leave for Driver",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
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
                    color: _selectedDriver != null ? widget.primaryBlue : Colors.grey.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedDriver != null ? Icons.person_rounded : Icons.person_search_rounded,
                      color: _selectedDriver != null ? widget.primaryBlue : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedDriver != null ? _selectedDriver!['name'] : "Choose a driver...",
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

            // Date Range Picker
            _buildSectionTitle("Select Date Range"),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickDateRange,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: widget.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _startDate != null ? widget.primaryBlue : Colors.grey.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.date_range_rounded,
                      color: _startDate != null ? widget.primaryBlue : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _startDate != null && _endDate != null
                            ? "${DateFormat('dd MMM').format(_startDate!)} - ${DateFormat('dd MMM').format(_endDate!)}"
                            : "Choose dates...",
                        style: TextStyle(
                          color: _startDate != null ? titleColor : Colors.grey,
                          fontWeight: _startDate != null ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Time Selection
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle("Start Time"),
                      const SizedBox(height: 12),
                      _buildTimePicker(true),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle("End Time"),
                      const SizedBox(height: 12),
                      _buildTimePicker(false),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Leave Type
            _buildSectionTitle("Leave Type"),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: widget.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedLeaveType,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
                  onChanged: (val) => setState(() => _selectedLeaveType = val!),
                  items: _leaveTypes.entries.map((e) {
                    return DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 24),

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
                hintStyle: TextStyle(color: Colors.grey.withOpacity(0.6)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _submitLeave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text(
                  "Submit Application",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
    );
  }

  Widget _buildTimePicker(bool isStart) {
    final time = isStart ? _startTime : _endTime;
    return GestureDetector(
      onTap: () => _pickTime(isStart),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: widget.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded, size: 16, color: widget.primaryBlue),
            const SizedBox(width: 8),
            Text(
              time == null ? "Select" : time.format(context),
              style: TextStyle(
                fontWeight: time == null ? FontWeight.normal : FontWeight.bold,
                color: widget.isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) _startTime = picked;
        else _endTime = picked;
      });
    }
  }

  void _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: widget.isDark ? ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: widget.primaryBlue,
              onPrimary: Colors.white,
              surface: widget.cardColor,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: widget.cardColor,
          ) : ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: widget.primaryBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
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
            final titleColor = widget.isDark ? Colors.white : const Color(0xFF1E293B);
            return Container(
              height: MediaQuery.of(context).size.height * 0.5,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  TextField(
                    onChanged: (val) {
                      setModalState(() {
                        final driverStore = Provider.of<DriverStore>(context, listen: false);
                        if (val.isEmpty) {
                          _filteredDrivers = driverStore.drivers;
                        } else {
                          _filteredDrivers = driverStore.drivers
                              .where((d) => (d['name'] ?? "").toLowerCase().contains(val.toLowerCase()))
                              .toList();
                        }
                      });
                    },
                    decoration: InputDecoration(
                      hintText: "Search driver...",
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: widget.cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _filteredDrivers.length,
                      itemBuilder: (context, index) {
                        final d = _filteredDrivers[index];
                        return ListTile(
                          title: Text(d['name'] ?? "Unknown", style: TextStyle(color: titleColor)),
                          subtitle: Text(d['phone'] ?? "", style: const TextStyle(color: Colors.grey)),
                          onTap: () {
                            setState(() => _selectedDriver = d);
                            Navigator.pop(context);
                          },
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
    if (_selectedDriver == null || _startDate == null || _endDate == null || 
        _startTime == null || _endTime == null || _reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields including time")),
      );
      return;
    }

    final requestStore = Provider.of<RequestStore>(context, listen: false);
    
    // Format time to HH:mm for the API
    final String startStr = "${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}";
    final String endStr = "${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}";

    final success = await requestStore.createLeave(
      driverId: _selectedDriver!['id'],
      fromDate: DateFormat('yyyy-MM-dd').format(_startDate!),
      toDate: DateFormat('yyyy-MM-dd').format(_endDate!),
      startTime: startStr,
      endTime: endStr,
      leaveType: _selectedLeaveType,
      reason: _reasonController.text,
    );

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Leave applied successfully")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(requestStore.leavesErrorMessage ?? "Failed to apply leave")),
      );
    }
  }
}
