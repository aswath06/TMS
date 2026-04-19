import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tripzo/store/driver_store.dart';
import 'package:tripzo/store/istamil.dart'; 
import 'package:tripzo/screens/faculty/missions/mission_details_screen.dart';

class DriverRoutesScreen extends StatefulWidget {
  const DriverRoutesScreen({super.key});

  @override
  State<DriverRoutesScreen> createState() => _DriverRoutesScreenState();
}

class _DriverRoutesScreenState extends State<DriverRoutesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      useDriverStore.fetchMissions();
      useDriverStore.fetchProfile(); // Refresh upcoming/ongoing
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final bool isTamil = LanguageStore.isTamil;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: isTamil ? "பயண பெயரைத் தேடுக..." : "Search route name...",
                  hintStyle: const TextStyle(color: Colors.grey, fontWeight: FontWeight.normal),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  context.read<DriverStore>().updateSearch(val);
                },
              )
            : Text(
                isTamil ? "உங்கள் பயணங்கள்" : "My Journeys",
                style: TextStyle(color: titleColor, fontWeight: FontWeight.w900),
              ),
        actions: [
          _isSearching
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  onPressed: () {
                    if (_searchController.text.isEmpty) {
                      setState(() => _isSearching = false);
                    } else {
                      _searchController.clear();
                      context.read<DriverStore>().updateSearch("");
                    }
                  },
                )
              : IconButton(
                  icon: Icon(Icons.search_rounded, color: titleColor),
                  onPressed: () => setState(() => _isSearching = true),
                ),
        ],
        bottom: TabBar(


          controller: _tabController,
          labelColor: primaryBlue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryBlue,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: [
            Tab(text: isTamil ? "வரவிருப்பவை" : "Upcoming"),
            Tab(text: isTamil ? "முடிந்தவை" : "Completed"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRouteList('upcoming'),
          _buildRouteList('completed'),
        ],
      ),
    );
  }

  Widget _buildRouteList(String type) {
    return Consumer<DriverStore>(
      builder: (context, store, _) {
        final isTamil = LanguageStore.isTamil;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final Color primaryBlue = const Color(0xFF6366F1);
        final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        final Color surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;

        List<Map<String, dynamic>> list = [];
        final allMissions = List<Map<String, dynamic>>.from(store.missions);
        allMissions.sort((a, b) {
          final aTime = DateTime.tryParse(a['start_datetime'] ?? '') ?? DateTime(0);
          final bTime = DateTime.tryParse(b['start_datetime'] ?? '') ?? DateTime(0);
          return aTime.compareTo(bTime);
        });

        // Helper to normalize status for filtering
        bool isCompleted(dynamic s) {
          if (s is int) return s >= 8;
          if (s is String) return s.toUpperCase() == 'COMPLETED';
          return false;
        }




        // identify search query
        final query = store.searchQuery.toLowerCase().trim();
        
        // Helper to normalize status for filtering



        if (type == 'upcoming') {
          list = allMissions.where((m) => !isCompleted(m['status'])).toList();
        } else if (type == 'completed') {
          list = allMissions.where((m) => isCompleted(m['status'])).toList();
        }

        // Apply Search Filtering (Frontend)
        if (query.isNotEmpty) {
          list = list.where((m) {
            final String routeName = (m['routeName'] ?? "").toString().toLowerCase();
            final String pickup = (m['startLocation'] ?? "").toString().toLowerCase();
            final String drop = (m['destinationLocation'] ?? "").toString().toLowerCase();
            final String driveId = (m['id'] ?? "").toString().toLowerCase();
            
            return routeName.contains(query) || 
                   pickup.contains(query) || 
                   drop.contains(query) ||
                   driveId.contains(query);
          }).toList();
        }


        if (store.isLoadingMissions && list.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (list.isEmpty) {
          return _buildEmptyState(type, isSearch: query.isNotEmpty);
        }


        return RefreshIndicator(
          onRefresh: () async {
            await store.fetchMissions();
            await store.fetchProfile();
          },
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            physics: const BouncingScrollPhysics(),
            itemCount: list.length,
            itemBuilder: (context, index) {
              return _buildMissionCard(
                context: context,
                mission: list[index],
                surface: surfaceColor,
                primary: primaryBlue,
                titleColor: titleColor,
                subColor: subColor,
                isDark: isDark,
                isTamil: isTamil,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMissionCard({
    required BuildContext context,
    required Map<String, dynamic> mission,
    required Color surface,
    required Color primary,
    required Color titleColor,
    required Color subColor,
    required bool isDark,
    required bool isTamil,
  }) {
    final String id = "MSN-${mission['id']}";
    final String routeName = mission['routeName'] ?? "Unknown Route";
    final String pickup = mission['startLocation'] ?? 'Unknown';
    final String drop = mission['destinationLocation'] ?? 'Unknown';
    final String time = _formatDate(mission['start_datetime'] ?? mission['startDate']);
    final dynamic rawStatusValue = mission['status'];
    final tripStatuses = mission['trip_instance_statuses'] as List?;
    final String? tripStatus = (tripStatuses != null && tripStatuses.isNotEmpty) ? tripStatuses[0]['status']?.toString().toUpperCase() : null;
    
    // Status Logic - Using backend status directly as requested
    final String backendStatus = (mission['status'] ?? "UNKNOWN").toString().toUpperCase();
    String statusStr = backendStatus;
    Color statusColor = Colors.grey;

    if (backendStatus == 'READY' || backendStatus == 'APPROVED' || backendStatus == 'PLANNED' || backendStatus == 'ASSIGNED') {
      if (isTamil) statusStr = "ஒதுக்கப்பட்டது";
      statusColor = Colors.blue;
    } else if (backendStatus == 'ON_TRIP' || backendStatus == 'STARTED' || backendStatus == 'ONGOING') {
      if (isTamil) statusStr = "நடைபெறுகிறது";
      statusColor = Colors.orange;
    } else if (backendStatus == 'COMPLETED' || backendStatus == 'FINISHED') {
      if (isTamil) statusStr = "முடிந்தது";
      statusColor = Colors.green;
    } else if (backendStatus == 'REJECTED' || backendStatus == 'CANCELLED' || backendStatus == 'DRAFT') {
      if (isTamil) statusStr = "ரத்து செய்யப்பட்டது";
      statusColor = backendStatus == 'DRAFT' ? Colors.amber : Colors.red;
    }


    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MissionDetailsScreen(
            missionTitle: routeName,
            time: time,
            driverName: "You",
            driverPhone: "",
            vehicleInfo: mission['vehiclePlate'] != null 
                ? "${mission['vehicleType'] ?? 'Vehicle'} (${mission['vehiclePlate']})" 
                : "Vehicle #${mission['vehicleAssigned']}",
            capacity: "${mission['passengerCount']} Guests",
            passengerCount: mission['passengerCount']?.toString() ?? "0",
            pathType: mission['travelType'] ?? "One-Way",
            stops: [
              {'location': pickup, 'eta': 'Start'},
              if (mission['intermediateStops'] is List)
                ...(mission['intermediateStops'] as List).map((s) {
                  if (s is Map) return {'location': (s['stop_name'] ?? '').toString(), 'eta': 'Transit'};
                  return {'location': s.toString(), 'eta': 'Transit'};
                }),
              {'location': drop, 'eta': 'End'},
            ],
            status: statusStr,
            statusColor: statusColor,
            requestId: mission['id'].toString(),
            rawStatus: rawStatusValue is int ? rawStatusValue : 0,
            creatorName: mission['createdBy']?['name'] ?? "Admin",
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 14, color: primary),
                    const SizedBox(width: 6),
                    Text(time, style: TextStyle(fontWeight: FontWeight.w800, color: subColor, fontSize: 13)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Text(statusStr.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(routeName, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: titleColor)),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.person_pin_circle_rounded, size: 14, color: subColor),
                const SizedBox(width: 4),
                Text("${isTamil ? 'உருவாக்கியவர்' : 'Created by'}: ", style: TextStyle(fontSize: 12, color: subColor, fontWeight: FontWeight.w600)),
                Text(mission['createdBy']?['name'] ?? "Admin", style: TextStyle(fontSize: 12, color: primary, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 20),
            _buildTimeline(pickup, drop, primary, titleColor),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _iconInfo(Icons.assignment_ind_rounded, id, isDark),
                 _iconInfo(
                  Icons.directions_car_filled_rounded, 
                  mission['vehiclePlate'] ?? "Vehicle #${mission['vehicleAssigned']}", 
                  isDark
                ),
                _iconInfo(Icons.group_rounded, "${mission['passengerCount']} ${isTamil ? 'பயணிகள்' : 'Guests'}", isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline(String pickup, String drop, Color primary, Color title) {
    return Row(
      children: [
        Column(
          children: [
            Icon(Icons.radio_button_checked, color: primary, size: 18),
            Container(width: 2, height: 20, color: primary.withValues(alpha: 0.2)),
            Icon(Icons.location_on, color: Colors.redAccent.withValues(alpha: 0.7), size: 18),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pickup, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: title), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 18),
              Text(drop, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: title), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _iconInfo(IconData icon, String text, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: isDark ? Colors.white38 : Colors.black26),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.black54)),
      ],
    );
  }

  Widget _buildEmptyState(String type, {bool isSearch = false}) {
    final bool isTamil = LanguageStore.isTamil;
    String text = "";
    if (isSearch) {
      text = isTamil ? "பொருத்தமான பயணங்கள் எதுவும் இல்லை" : "No matching journeys found";
    } else {
      if (type == 'upcoming') text = isTamil ? "வரவிருக்கும் பயணங்கள் இல்லை" : "No upcoming assignments";
      if (type == 'completed') text = isTamil ? "முடிந்த பயணங்கள் இல்லை" : "No finished history";
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearch ? Icons.search_off_rounded : Icons.subtitles_off_rounded,
            size: 64,
            color: Colors.grey.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(text, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }



  String _formatDate(String? dateStr) {
    if (dateStr == null) return "TBD";
    try {
      final dt = DateTime.parse(dateStr).toUtc();
      return "${dt.day}/${dt.month}/${dt.year}";
    } catch (_) {
      return dateStr;
    }
  }
}
