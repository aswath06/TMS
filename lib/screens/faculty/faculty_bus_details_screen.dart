import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';

class FacultyBusDetailsScreen extends ConsumerStatefulWidget {
  final int runId;
  const FacultyBusDetailsScreen({super.key, required this.runId});

  @override
  ConsumerState<FacultyBusDetailsScreen> createState() => _FacultyBusDetailsScreenState();
}

class _FacultyBusDetailsScreenState extends ConsumerState<FacultyBusDetailsScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _detailData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchDetails() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final token = await UserStore.getToken();
      if (token == null) {
        if (mounted) {
          setState(() {
            _error = "Session expired. Please login again.";
            _isLoading = false;
          });
        }
        return;
      }
      final url = "${ApiConstants.baseUrl}/daily-bus/bus-run/${widget.runId}";
      final response = await http.get(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          setState(() {
            _detailData = decoded['data'];
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = decoded['message'] ?? "Failed to load route details.";
            _isLoading = false;
          });
        }
      } else {
        String errorMsg = "An unexpected error occurred.";
        try {
          final decoded = json.decode(response.body);
          if (decoded['message'] != null && decoded['message'].toString().trim().isNotEmpty) {
            errorMsg = decoded['message'].toString();
          } else if (decoded['error'] != null && decoded['error'].toString().trim().isNotEmpty) {
            errorMsg = decoded['error'].toString();
          }
        } catch (_) {}
        setState(() {
          _error = errorMsg;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Connection failed. Please try again.";
          _isLoading = false;
        });
      }
    }
  }

  String _formatShift(String? shiftCode) {
    if (shiftCode == null || shiftCode.isEmpty) return "N/A";
    return shiftCode.replaceAll('_', ' ').split(' ').map((str) {
      if (str.isEmpty) return "";
      return str[0].toUpperCase() + str.substring(1).toLowerCase();
    }).join(' ');
  }

  String _formatTimeString(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return "N/A";
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final int hour = int.parse(parts[0]);
        final int minute = int.parse(parts[1]);
        final DateTime dt = DateTime(2026, 1, 1, hour, minute);
        return DateFormat('hh:mm a').format(dt);
      }
    } catch (e) {
      // ignore
    }
    return timeStr;
  }

  String _getVehicleNumber(Map<String, dynamic> data) {
    final List<dynamic>? assignments = data['assignment'];
    if (assignments != null && assignments.isNotEmpty) {
      for (var assign in assignments) {
        final vehicle = assign['vehicle'];
        if (vehicle != null && vehicle['vehicle_number'] != null) {
          return vehicle['vehicle_number'].toString();
        }
      }
    }
    return "N/A";
  }

  String? _getBusNumber(Map<String, dynamic> data) {
    final List<dynamic>? assignments = data['assignment'];
    if (assignments != null && assignments.isNotEmpty) {
      for (var assign in assignments) {
        final vehicle = assign['vehicle'];
        if (vehicle != null && vehicle['bus_number'] != null) {
          return vehicle['bus_number'].toString();
        }
      }
    }
    return null;
  }

  String _getDriverName(Map<String, dynamic> data) {
    final List<dynamic>? assignments = data['assignment'];
    if (assignments != null && assignments.isNotEmpty) {
      for (var assign in assignments) {
        final driver = assign['driver'];
        if (driver != null) {
          final user = driver['user'];
          if (user != null && user['name'] != null) {
            return user['name'].toString();
          }
        }
      }
    }
    return "N/A";
  }

  String _getDriverPhone(Map<String, dynamic> data) {
    final List<dynamic>? assignments = data['assignment'];
    if (assignments != null && assignments.isNotEmpty) {
      for (var assign in assignments) {
        final driver = assign['driver'];
        if (driver != null) {
          final user = driver['user'];
          if (user != null && user['phone'] != null) {
            return user['phone'].toString();
          }
        }
      }
    }
    return "N/A";
  }

  Widget _buildStatusBadge(String status) {
    final String s = status.toUpperCase();
    final Map<String, Map<String, Color>> statusStyles = {
      'PLANNED': {
        'bg': const Color(0xFFFEF3C7),
        'text': const Color(0xFFD97706),
        'border': const Color(0xFFFDE68A),
      },
      'READY': {
        'bg': const Color(0xFFFCE7F3),
        'text': const Color(0xFFBE185D),
        'border': const Color(0xFFFBCFE8),
      },
      'STARTED': {
        'bg': const Color(0xFFDBEAFE),
        'text': const Color(0xFF2563EB),
        'border': const Color(0xFF93C5FD),
      },
      'ARRIVED_CAMPUS': {
        'bg': const Color(0xFFEEF2FF),
        'text': const Color(0xFF6366F1),
        'border': const Color(0xFFC7D2FE),
      },
      'CAMPUS_IN': {
        'bg': const Color(0xFFEEF2FF),
        'text': const Color(0xFF6366F1),
        'border': const Color(0xFFC7D2FE),
      },
      'FN_COMPLETED': {
        'bg': const Color(0xFFD1FAE5),
        'text': const Color(0xFF059669),
        'border': const Color(0xFFA7F3D0),
      },
      'DEPARTED_CAMPUS': {
        'bg': const Color(0xFFFEF3C7),
        'text': const Color(0xFFB45309),
        'border': const Color(0xFFFDE68A),
      },
      'HALTED': {
        'bg': const Color(0xFFFAF5FF),
        'text': const Color(0xFF8B5CF6),
        'border': const Color(0xFFE9D5FF),
      },
      'COMPLETED': {
        'bg': const Color(0xFFD1FAE5),
        'text': const Color(0xFF047857),
        'border': const Color(0xFFA7F3D0),
      },
      'CANCELLED': {
        'bg': const Color(0xFFFFE4E6),
        'text': const Color(0xFFBE123C),
        'border': const Color(0xFFFECDD3),
      },
    };

    final style = statusStyles[s] ??
        {
          'bg': const Color(0xFFF1F5F9),
          'text': const Color(0xFF475569),
          'border': const Color(0xFFE2E8F0),
        };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: style['bg'],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: style['border']!, width: 1),
      ),
      child: Text(
        s.replaceAll('_', ' '),
        style: TextStyle(
          color: style['text'],
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color scaffoldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    const Color primaryBlue = Color(0xFF6366F1);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: titleColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: titleColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: subColor, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _fetchDetails,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text("Retry"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final data = _detailData!;
    final runName = data['run_name']?.toString() ?? 'Route Details';
    final runCode = data['run_code']?.toString() ?? '';
    final serviceDate = data['service_date']?.toString() ?? '';
    final status = data['status']?.toString() ?? 'UNKNOWN';
    final shift = _formatShift(data['shift_code']);

    final routeData = data['dailyBusRoute'] as Map<String, dynamic>?;
    final maxCapacity = routeData?['max_vehicle_capacity'] ?? 60;

    final vehicleNo = _getVehicleNumber(data);
    final busNo = _getBusNumber(data);
    final driverName = _getDriverName(data);
    final driverPhone = _getDriverPhone(data);

    final List<dynamic> stops = List.from(routeData?['stops'] ?? []);
    stops.sort((a, b) => (a['stop_order'] ?? 0).compareTo(b['stop_order'] ?? 0));

    final List<dynamic> studentsList = data['students'] ?? [];
    final List<dynamic> facultiesList = data['faculties'] ?? [];
    final List<dynamic> nonTeachingList = data['nonTeachingStaffs'] ?? [];
    final List<dynamic> internsList = data['interns'] ?? [];

    final tabs = <Widget>[
      const Tab(text: "Timeline"),
    ];
    final tabViews = <Widget>[
      _buildTimelineView(stops, primaryBlue, titleColor, subColor),
    ];
    
    if (studentsList.isNotEmpty) {
      tabs.add(Tab(text: "Students (${studentsList.length})"));
      tabViews.add(_buildStudentsView(studentsList, cardColor, titleColor, subColor, primaryBlue));
    }
    if (facultiesList.isNotEmpty) {
      tabs.add(Tab(text: "Faculty (${facultiesList.length})"));
      tabViews.add(_buildFacultyView(facultiesList, cardColor, titleColor, subColor, primaryBlue));
    }
    if (nonTeachingList.isNotEmpty) {
      tabs.add(Tab(text: "Non-Teaching (${nonTeachingList.length})"));
      tabViews.add(_buildNonTeachingView(nonTeachingList, cardColor, titleColor, subColor, primaryBlue));
    }
    if (internsList.isNotEmpty) {
      tabs.add(Tab(text: "Interns (${internsList.length})"));
      tabViews.add(_buildInternsView(internsList, cardColor, titleColor, subColor, primaryBlue));
    }

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
      backgroundColor: scaffoldBg,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: titleColor),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF4F46E5),
                      Color(0xFF7C3AED),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                runName,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Code: $runCode",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info panel specs
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildInfoCol("Service Date", serviceDate, subColor, titleColor),
                            _buildStatusBadge(status),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildInfoCol("Shift", shift, subColor, titleColor),
                            _buildInfoCol("Capacity", "$maxCapacity Seats", subColor, titleColor),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Driver Details Panel
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: primaryBlue.withValues(alpha: 0.1),
                          child: const Icon(Icons.person, color: primaryBlue, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                driverName,
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Vehicle: $vehicleNo${busNo != null ? " (Bus $busNo)" : ""}",
                                style: TextStyle(fontSize: 13, color: subColor, fontWeight: FontWeight.w500),
                              ),
                              if (driverPhone != "N/A") ...[
                                const SizedBox(height: 4),
                                Text(
                                  "Phone: $driverPhone",
                                  style: TextStyle(fontSize: 12, color: subColor),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Tabs
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TabBar(
                      indicatorColor: primaryBlue,
                      labelColor: primaryBlue,
                      unselectedLabelColor: subColor,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      indicator: UnderlineTabIndicator(
                        borderSide: const BorderSide(width: 3.0, color: primaryBlue),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      tabs: tabs,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TabBarView(
            children: tabViews,
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildInfoCol(String label, String value, Color sub, Color title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(fontSize: 10, color: sub, fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: title),
        ),
      ],
    );
  }

  Widget _buildTimelineView(List<dynamic> stops, Color blue, Color titleColor, Color subColor) {
    if (stops.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text("No stops configured for this route.", style: TextStyle(color: subColor)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 16, bottom: 80),
      physics: const BouncingScrollPhysics(),
      itemCount: stops.length,
      itemBuilder: (context, index) {
        final stop = stops[index] as Map<String, dynamic>;
        final stopName = stop['stop_name']?.toString() ?? 'Stop';
        final isLast = index == stops.length - 1;
        final pickupTime = _formatTimeString(stop['pickup_plan_time']);
        final dropTime = _formatTimeString(stop['drop_plan_time']);

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: blue,
                      border: Border.all(
                        color: blue,
                        width: 2.5,
                      ),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: blue.withValues(alpha: 0.3),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stopName,
                        style: TextStyle(
                          fontSize: 15,
                          color: titleColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.arrow_upward_rounded, size: 12, color: subColor),
                          const SizedBox(width: 4),
                          Text("Pickup: $pickupTime", style: TextStyle(fontSize: 12, color: subColor)),
                          const SizedBox(width: 16),
                          Icon(Icons.arrow_downward_rounded, size: 12, color: subColor),
                          const SizedBox(width: 4),
                          Text("Drop: $dropTime", style: TextStyle(fontSize: 12, color: subColor)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStudentsView(List<dynamic> list, Color cardColor, Color titleColor, Color subColor, Color primaryBlue) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text("No students assigned to this route run.", style: TextStyle(color: subColor)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 16, bottom: 80),
      physics: const BouncingScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index] as Map<String, dynamic>;
        final student = item['student'] as Map<String, dynamic>?;
        final user = student?['user'] as Map<String, dynamic>?;
        final boardingStop = item['boardingStop'] as Map<String, dynamic>?;

        final name = user?['name']?.toString() ?? 'N/A';
        final rollNo = student?['roll_number']?.toString() ?? 'N/A';
        final dept = student?['department']?.toString() ?? 'N/A';
        final boardingStopName = boardingStop?['stop_name']?.toString() ?? 'N/A';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: primaryBlue.withValues(alpha: 0.08),
                child: Icon(Icons.school_rounded, color: primaryBlue, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: titleColor)),
                    const SizedBox(height: 2),
                    Text("$rollNo • $dept", style: TextStyle(fontSize: 12, color: subColor)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded, size: 12, color: subColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            "Boarding: $boardingStopName",
                            style: TextStyle(fontSize: 12, color: subColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFacultyView(List<dynamic> list, Color cardColor, Color titleColor, Color subColor, Color primaryBlue) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text("No faculties assigned to this route run.", style: TextStyle(color: subColor)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 16, bottom: 80),
      physics: const BouncingScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index] as Map<String, dynamic>;
        final faculty = item['faculty'] as Map<String, dynamic>?;
        final user = faculty?['user'] as Map<String, dynamic>?;
        final boardingStop = item['boardingStop'] as Map<String, dynamic>?;

        final name = user?['name']?.toString() ?? 'N/A';
        final empCode = faculty?['employee_code']?.toString() ?? 'N/A';
        final dept = faculty?['department']?.toString() ?? 'N/A';
        final boardingStopName = boardingStop?['stop_name']?.toString() ?? 'N/A';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: primaryBlue.withValues(alpha: 0.08),
                child: Icon(Icons.badge_rounded, color: primaryBlue, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: titleColor)),
                    const SizedBox(height: 2),
                    Text("$empCode • $dept", style: TextStyle(fontSize: 12, color: subColor)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded, size: 12, color: subColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            "Boarding: $boardingStopName",
                            style: TextStyle(fontSize: 12, color: subColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  Widget _buildNonTeachingView(List<dynamic> list, Color cardColor, Color titleColor, Color subColor, Color primaryBlue) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text("No non-teaching staff assigned to this route run.", style: TextStyle(color: subColor)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 16, bottom: 80),
      physics: const BouncingScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index] as Map<String, dynamic>;
        final nonTeaching = item['nonTeachingStaff'] as Map<String, dynamic>? ?? item['non_teaching_staff'] as Map<String, dynamic>?;
        final user = nonTeaching?['user'] as Map<String, dynamic>?;
        final boardingStop = item['boardingStop'] as Map<String, dynamic>?;

        final name = user?['name']?.toString() ?? 'N/A';
        final empCode = nonTeaching?['employee_code']?.toString() ?? 'N/A';
        final dept = nonTeaching?['department']?.toString() ?? 'N/A';
        final boardingStopName = boardingStop?['stop_name']?.toString() ?? 'N/A';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: primaryBlue.withValues(alpha: 0.08),
                child: Icon(Icons.engineering_rounded, color: primaryBlue, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: titleColor)),
                    const SizedBox(height: 2),
                    Text("$empCode • $dept", style: TextStyle(fontSize: 12, color: subColor)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded, size: 12, color: subColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            "Boarding: $boardingStopName",
                            style: TextStyle(fontSize: 12, color: subColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInternsView(List<dynamic> list, Color cardColor, Color titleColor, Color subColor, Color primaryBlue) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text("No interns assigned to this route run.", style: TextStyle(color: subColor)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 16, bottom: 80),
      physics: const BouncingScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index] as Map<String, dynamic>;
        final intern = item['intern'] as Map<String, dynamic>?;
        final user = intern?['user'] as Map<String, dynamic>?;
        final boardingStop = item['boardingStop'] as Map<String, dynamic>?;

        final name = user?['name']?.toString() ?? 'N/A';
        final code = intern?['roll_number']?.toString() ?? intern?['employee_code']?.toString() ?? 'N/A';
        final dept = intern?['department']?.toString() ?? 'N/A';
        final boardingStopName = boardingStop?['stop_name']?.toString() ?? 'N/A';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: primaryBlue.withValues(alpha: 0.08),
                child: Icon(Icons.assignment_ind_rounded, color: primaryBlue, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: titleColor)),
                    const SizedBox(height: 2),
                    Text("$code • $dept", style: TextStyle(fontSize: 12, color: subColor)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded, size: 12, color: subColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            "Boarding: $boardingStopName",
                            style: TextStyle(fontSize: 12, color: subColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
