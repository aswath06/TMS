import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/utils/toast_utils.dart';

class MergeVehicleScreen extends StatefulWidget {
  final int currentRunId;

  const MergeVehicleScreen({super.key, required this.currentRunId});

  @override
  State<MergeVehicleScreen> createState() => _MergeVehicleScreenState();
}

class _MergeVehicleScreenState extends State<MergeVehicleScreen> {
  // Selected route data
  Map<String, dynamic>? _selectedRoute;
  // Selected stop data
  Map<String, dynamic>? _selectedStop;

  // Form controllers
  final TextEditingController _placeController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();
  final TextEditingController _endOdometerController = TextEditingController();

  // Allowance needed
  bool? _allowanceNeeded;

  // Loading states
  bool _isLoadingRoutes = false;
  bool _isLoadingStops = false;
  bool _isSubmitting = false;

  // Data lists
  List<Map<String, dynamic>> _routes = [];
  List<Map<String, dynamic>> _stops = [];

  @override
  void dispose() {
    _placeController.dispose();
    _remarkController.dispose();
    _endOdometerController.dispose();
    super.dispose();
  }

  // ─── API: Fetch Route Names ────────────────────────────────────────
  Future<void> _fetchRoutes() async {
    setState(() => _isLoadingRoutes = true);

    try {
      final String? token = await UserStore.getToken();
      if (token == null) {
        if (mounted) showTopToast(context, "Session expired", isError: true);
        return;
      }

      final String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final String url =
          "${ApiConstants.baseUrl}/daily-bus/bus-run/list-simple?service_date=$todayDate&status=STARTED";

      debugPrint("---- [MERGE: GET ROUTES] ----\ncurl '$url' -H 'Authorization: TMS $token'\n----------------------------");

      final response = await http.get(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
      );

      debugPrint("---- [MERGE: ROUTES RESPONSE ${response.statusCode}] ----\n${response.body}\n----------------------------");

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> routeList = data['data'] ?? [];
          setState(() {
            _routes = routeList
                .map((r) => Map<String, dynamic>.from(r))
                .toList();
          });
        }
      } else if (response.statusCode == 401) {
        await UserStore.forceLogout();
      }
    } catch (e) {
      debugPrint("Error fetching routes: $e");
      if (mounted) showTopToast(context, "Failed to load routes", isError: true);
    } finally {
      setState(() => _isLoadingRoutes = false);
    }
  }

  // ─── API: Fetch Route Stops ────────────────────────────────────────
  Future<void> _fetchStops(int routeId) async {
    setState(() => _isLoadingStops = true);

    try {
      final String? token = await UserStore.getToken();
      if (token == null) {
        if (mounted) showTopToast(context, "Session expired", isError: true);
        return;
      }

      final String url =
          "${ApiConstants.baseUrl}/daily-bus/bus-run/$routeId/stops";

      debugPrint("---- [MERGE: GET STOPS] ----\ncurl '$url' -H 'Authorization: TMS $token'\n----------------------------");

      final response = await http.get(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
      );

      debugPrint("---- [MERGE: STOPS RESPONSE ${response.statusCode}] ----\n${response.body}\n----------------------------");

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> stopList = data['data'] ?? [];
          setState(() {
            _stops = stopList
                .map((s) => Map<String, dynamic>.from(s))
                .toList();
            // Sort by stop_order
            _stops.sort((a, b) =>
                (a['stop_order'] ?? 0).compareTo(b['stop_order'] ?? 0));
          });
        }
      } else if (response.statusCode == 401) {
        await UserStore.forceLogout();
      }
    } catch (e) {
      debugPrint("Error fetching stops: $e");
      if (mounted) showTopToast(context, "Failed to load stops", isError: true);
    } finally {
      setState(() => _isLoadingStops = false);
    }
  }

  // ─── API: Submit Merge ─────────────────────────────────────────────
  Future<void> _submitMerge() async {
    if (_selectedRoute == null || _selectedStop == null) {
      showTopToast(context, "Please select route and stop", isError: true);
      return;
    }

    if (_endOdometerController.text.trim().isEmpty) {
      showTopToast(context, "Please enter end odometer reading", isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final String? token = await UserStore.getToken();
      if (token == null) {
        if (mounted) showTopToast(context, "Session expired", isError: true);
        return;
      }

      final String url =
          "${ApiConstants.baseUrl}/daily-bus/daily-bus-runs/operations/${widget.currentRunId}/cancel-and-shift";

      final Map<String, dynamic> body = {
        "targetRunId": _selectedRoute!['id'],
        "mergeStopId": _selectedStop!['id'],
        "shiftPeriod": "MORNING",
        "place": _placeController.text.trim(),
        "remark": _remarkController.text.trim(),
        "endOdometer": int.tryParse(_endOdometerController.text.trim()) ?? 0,
        "allowanceNeeded": _allowanceNeeded,
      };

      debugPrint("---- [MERGE: SUBMIT] ----\nPATCH $url\nBody: ${json.encode(body)}\n----------------------------");

      final response = await http.patch(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
        body: json.encode(body),
      );

      debugPrint("---- [MERGE: SUBMIT RESPONSE ${response.statusCode}] ----\n${response.body}\n----------------------------");

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          showTopToast(context, "Vehicle merged successfully!");
          Navigator.pop(context, true);
        }
      } else if (response.statusCode == 401) {
        await UserStore.forceLogout();
      } else {
        final resBody = json.decode(response.body);
        if (mounted) {
          showTopToast(
            context,
            resBody['message'] ?? "Failed to merge vehicle",
            isError: true,
          );
        }
      }
    } catch (e) {
      debugPrint("Error submitting merge: $e");
      if (mounted) showTopToast(context, "Connection failed", isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ─── Bottom Sheet: Route Name Picker ───────────────────────────────
  void _showRouteNamePicker() {

    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> filtered = List.from(_routes);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        bool isInitialLoad = _routes.isEmpty && !_isLoadingRoutes;
        
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            if (isInitialLoad) {
              isInitialLoad = false;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setModalState(() {
                  _isLoadingRoutes = true;
                });
                _fetchRoutes().then((_) {
                  if (mounted) {
                    setModalState(() {
                      filtered = List.from(_routes);
                    });
                  }
                });
              });
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 40,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Route Name",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TextField(
                      controller: searchCtrl,
                      onChanged: (val) {
                        setModalState(() {
                          filtered = _routes
                              .where((r) => (r['run_name'] ?? '')
                                  .toString()
                                  .toLowerCase()
                                  .contains(val.toLowerCase()))
                              .toList();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: "Search route...",
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: Color(0xFF6366F1)),
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoadingRoutes)
                    const Expanded(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                "No routes found",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: filtered.length,
                              separatorBuilder: (_, a) => const Divider(
                                height: 1,
                                indent: 70,
                                color: Colors.black12,
                              ),
                              itemBuilder: (context, index) {
                                final route = filtered[index];
                                final isSelected =
                                    _selectedRoute?['id'] == route['id'];
                                return ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1)
                                          .withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.route_rounded,
                                      color: Color(0xFF6366F1),
                                      size: 22,
                                    ),
                                  ),
                                  title: Text(
                                    route['run_name'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    route['run_code'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(0xFF6366F1),
                                        )
                                      : null,
                                  onTap: () {
                                    setState(() {
                                      _selectedRoute =
                                          Map<String, dynamic>.from(route);
                                      // Reset stop selection when route changes
                                      _selectedStop = null;
                                      _stops = [];
                                    });
                                    Navigator.pop(context);
                                    // Fetch stops for the selected route
                                    _fetchStops(route['id']);
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

  // ─── Bottom Sheet: Stop Name Picker ────────────────────────────────
  void _showStopNamePicker() {
    if (_selectedRoute == null) {
      showTopToast(context, "Please select a route first", isError: true);
      return;
    }

    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> filtered = List.from(_stops);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        bool isInitialLoad = _stops.isEmpty && !_isLoadingStops;
        
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            if (isInitialLoad && _selectedRoute != null) {
              isInitialLoad = false;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setModalState(() {
                  _isLoadingStops = true;
                });
                _fetchStops(_selectedRoute!['id']).then((_) {
                  if (mounted) {
                    setModalState(() {
                      filtered = List.from(_stops);
                    });
                  }
                });
              });
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 40,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Select Start Stop Name",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TextField(
                      controller: searchCtrl,
                      onChanged: (val) {
                        setModalState(() {
                          filtered = _stops
                              .where((s) => (s['stop_name'] ?? '')
                                  .toString()
                                  .toLowerCase()
                                  .contains(val.toLowerCase()))
                              .toList();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: "Search stop...",
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: Color(0xFF6366F1)),
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoadingStops)
                    const Expanded(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                "No stops found",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: filtered.length,
                              separatorBuilder: (_, a) => const Divider(
                                height: 1,
                                indent: 70,
                                color: Colors.black12,
                              ),
                              itemBuilder: (context, index) {
                                final stop = filtered[index];
                                final isSelected =
                                    _selectedStop?['id'] == stop['id'];
                                final int stopOrder =
                                    stop['stop_order'] ?? 0;
                                return ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981)
                                          .withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      "$stopOrder",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF10B981),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    stop['stop_name'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    "Pickup: ${stop['pickup_plan_time'] ?? '-'}  •  Drop: ${stop['drop_plan_time'] ?? '-'}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(0xFF10B981),
                                        )
                                      : null,
                                  onTap: () {
                                    setState(() {
                                      _selectedStop =
                                          Map<String, dynamic>.from(stop);
                                    });
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

  // ─── UI ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color cardColor =
        isDark ? const Color(0xFF1E293B) : Colors.white;
    const Color primaryBlue = Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: titleColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Merge Vehicle",
          style: GoogleFonts.outfit(
            color: titleColor,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryBlue.withValues(alpha: 0.08),
                    primaryBlue.withValues(alpha: 0.02),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: primaryBlue.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.merge_rounded,
                      color: primaryBlue,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Merge Bus Routes",
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Select a route and stop to merge vehicles",
                          style: TextStyle(
                            fontSize: 13,
                            color: subColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ─── Route Name Dropdown ──────────────────────────
            _buildSectionLabel("Route Name", Icons.route_rounded, primaryBlue),
            const SizedBox(height: 10),
            _buildDropdownTile(
              cardColor: cardColor,
              titleColor: titleColor,
              subColor: subColor,
              primaryBlue: primaryBlue,
              isDark: isDark,
              label: _selectedRoute != null
                  ? _selectedRoute!['run_name'] ?? 'Selected'
                  : "Select Route Name",
              subtitle: _selectedRoute?['run_code'],
              icon: Icons.route_rounded,
              isSelected: _selectedRoute != null,
              onTap: _showRouteNamePicker,
            ),

            // ─── Route Stop Name Dropdown ─────────────────────
            if (_selectedRoute != null) ...[
              const SizedBox(height: 24),
              _buildSectionLabel(
                  "Route Stop Name", Icons.location_on_rounded, primaryBlue),
              const SizedBox(height: 10),
              _buildDropdownTile(
                cardColor: cardColor,
                titleColor: titleColor,
                subColor: subColor,
                primaryBlue: primaryBlue,
                isDark: isDark,
                label: _selectedStop != null
                    ? "${_selectedStop!['stop_order']}. ${_selectedStop!['stop_name'] ?? 'Selected'}"
                    : "Select Start Stop Name",
                subtitle: _selectedStop != null
                    ? "Pickup: ${_selectedStop!['pickup_plan_time'] ?? '-'}  •  Drop: ${_selectedStop!['drop_plan_time'] ?? '-'}"
                    : null,
                icon: Icons.location_on_rounded,
                isSelected: _selectedStop != null,
                onTap: _showStopNamePicker,
                isLoading: _isLoadingStops,
              ),
            ],

            // ─── Form Fields (after stop selected) ────────────
            if (_selectedStop != null) ...[
              const SizedBox(height: 28),
              _buildSectionLabel(
                  "Place Name", Icons.place_rounded, primaryBlue),
              const SizedBox(height: 10),
              _buildInputField(
                controller: _placeController,
                hint: "Enter place name",
                icon: Icons.place_rounded,
                isDark: isDark,
                accentColor: primaryBlue,
              ),

              const SizedBox(height: 24),
              _buildSectionLabel(
                  "Remark", Icons.notes_rounded, primaryBlue),
              const SizedBox(height: 10),
              _buildInputField(
                controller: _remarkController,
                hint: "Enter remark",
                icon: Icons.notes_rounded,
                isDark: isDark,
                accentColor: primaryBlue,
                maxLines: 3,
              ),

              const SizedBox(height: 24),
              _buildSectionLabel("End Odometer",
                  Icons.speed_rounded, primaryBlue),
              const SizedBox(height: 10),
              _buildInputField(
                controller: _endOdometerController,
                hint: "Enter end odometer reading",
                icon: Icons.speed_rounded,
                isDark: isDark,
                accentColor: primaryBlue,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),

              const SizedBox(height: 24),
              _buildSectionLabel("DA/TA Needed",
                  Icons.account_balance_wallet_rounded, primaryBlue),
              const SizedBox(height: 10),
              _buildAllowanceToggle(
                cardColor: cardColor,
                titleColor: titleColor,
                subColor: subColor,
                primaryBlue: primaryBlue,
                isDark: isDark,
              ),

              const SizedBox(height: 36),
              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitMerge,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    disabledBackgroundColor:
                        primaryBlue.withValues(alpha: 0.4),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.merge_rounded, size: 22),
                            const SizedBox(width: 10),
                            Text(
                              "Submit Merge",
                              style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Section Label ─────────────────────────────────────────────────
  Widget _buildSectionLabel(String label, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  // ─── Dropdown Tile ─────────────────────────────────────────────────
  Widget _buildDropdownTile({
    required Color cardColor,
    required Color titleColor,
    required Color subColor,
    required Color primaryBlue,
    required bool isDark,
    required String label,
    String? subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? primaryBlue.withValues(alpha: 0.4)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06)),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: primaryBlue, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 15,
                      color: isSelected ? titleColor : subColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: subColor.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF6366F1),
                ),
              )
            else
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: subColor.withValues(alpha: 0.5),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Input Field ───────────────────────────────────────────────────
  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    required Color accentColor,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: isDark ? Colors.white30 : Colors.black38,
          fontWeight: FontWeight.normal,
        ),
        prefixIcon: Icon(icon,
            color: accentColor.withValues(alpha: 0.6), size: 20),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: accentColor.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 16),
      ),
    );
  }

  // ─── Allowance Toggle (Yes / No) ──────────────────────────────────
  Widget _buildAllowanceToggle({
    required Color cardColor,
    required Color titleColor,
    required Color subColor,
    required Color primaryBlue,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _allowanceNeeded = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _allowanceNeeded == true
                      ? const Color(0xFF10B981)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _allowanceNeeded == true
                      ? [
                          BoxShadow(
                            color: const Color(0xFF10B981)
                                .withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: _allowanceNeeded == true
                          ? Colors.white : subColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Yes",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: _allowanceNeeded == true
                            ? Colors.white
                            : subColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _allowanceNeeded = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _allowanceNeeded == false
                      ? const Color(0xFFEF4444)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _allowanceNeeded == false
                      ? [
                          BoxShadow(
                            color: const Color(0xFFEF4444)
                                .withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cancel_rounded,
                      size: 20,
                      color: _allowanceNeeded == false
                          ? Colors.white
                          : subColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "No",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: _allowanceNeeded == false
                            ? Colors.white
                            : subColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
