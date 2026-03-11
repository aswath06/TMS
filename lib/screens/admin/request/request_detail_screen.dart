import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tripzo/store/request_store.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

class RequestDetailScreen extends StatefulWidget {
  final Map<String, dynamic> request;
  const RequestDetailScreen({super.key, required this.request});

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dbId = widget.request['dbId'] ?? widget.request['id'];
      if (dbId != null) {
        useRequestStore.fetchRequestById(
            dbId is int ? dbId : int.tryParse(dbId.toString()) ?? 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RequestStore>();
    final data = store.currentRequest ?? widget.request;
    final bool isFetching = store.isFetchingDetails;

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    const Color primaryIndigo = Color(0xFF4F46E5);
    const Color accentBlue = Color(0xFF6366F1);
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final Color subTextColor = isDark ? Colors.white70 : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: textColor,
            ),
            children: [
              const TextSpan(
                  text: "Trip", style: TextStyle(color: primaryIndigo)),
              TextSpan(
                  text: "Zo",
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black)),
            ],
          ),
        ),
        actions: [
          if (isFetching)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: primaryIndigo)),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final dbId = widget.request['dbId'] ?? widget.request['id'];
          if (dbId != null) {
            await useRequestStore.fetchRequestById(
                dbId is int ? dbId : int.tryParse(dbId.toString()) ?? 0);
          }
        },
        child: isFetching && store.currentRequest == null
            ? _buildSkeleton(isDark)
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  // --- TRAVEL INFO SECTION ---
                  _buildSectionHeader("Travel Information", textColor),
                  _buildTravelInfoCard(data, cardBg, subTextColor, accentBlue, textColor),
                  const SizedBox(height: 24),

                  // --- ROUTE SECTION ---
                  _buildSectionHeader("Route Path", textColor),
                  _buildRouteCard(data, cardBg, subTextColor, accentBlue, textColor),
                  const SizedBox(height: 24),

                  // --- ADDITIONAL INFO & STATS ---
                  _buildSectionHeader("Request Details", textColor),
                  _buildRequestStatsCard(data, cardBg, subTextColor, accentBlue, textColor),
                  const SizedBox(height: 24),

                  // --- REMARKS SECTION ---
                  if (data['admin_remark'] != null || data['faculty_remark'] != null) ...[
                    _buildSectionHeader("Remarks", textColor),
                    _buildRemarksCard(data, cardBg, subTextColor, accentBlue, textColor),
                    const SizedBox(height: 24),
                  ],

                  // --- GUESTS SECTION ---
                  _buildSectionHeader(
                      "Guest List (${data['total_guest'] ?? (data['guests'] as List?)?.length ?? 0})",
                      textColor),
                  _buildGuestList(data['guests'] as List? ?? [], cardBg, subTextColor,
                      accentBlue, textColor),
                  const SizedBox(height: 24),

                  // --- ASSIGNMENTS SECTION ---
                  if (data['schedules'] != null &&
                      (data['schedules'] as List).isNotEmpty) ...[
                    _buildSectionHeader("Assignments", textColor),
                    ... (data['schedules'] as List).map((s) => _buildScheduleCard(
                        s is Map<String, dynamic> ? s : {},
                        cardBg,
                        subTextColor,
                        accentBlue,
                        textColor)),
                    const SizedBox(height: 24),
                  ],

                  // --- CREATOR SECTION ---
                  _buildSectionHeader("Created By", textColor),
                  _buildCreatorCard(data['creator'] as Map<String, dynamic>?, cardBg,
                      subTextColor, accentBlue, textColor),

                  const SizedBox(height: 48),
                ],
              ),
      ),
    );
  }

  Widget _buildSkeleton(bool isDark) {
    final Color baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final Color highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: List.generate(4, (index) => _skeletonCard()),
      ),
    );
  }

  Widget _skeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 120, height: 16, color: Colors.white),
          const SizedBox(height: 12),
          Container(width: double.infinity, height: 80, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTravelInfoCard(Map<String, dynamic> data, Color cardBg,
      Color subTextColor, Color primary, Color textColor) {
    final travelInfo = data['travel_info'] as Map<String, dynamic>? ?? {};
    final status = _getStatusLabel(data['route_status']);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: cardBg, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      travelInfo['route_name']?.toString() ?? 'Unnamed Route',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor),
                    ),
                    Text(
                      travelInfo['type']?.toString() ?? 'N/A',
                      style: TextStyle(fontSize: 12, color: subTextColor),
                    ),
                  ],
                ),
              ),
              _statusBadge(status),
            ],
          ),
          const Divider(height: 32),
          _infoTile(Icons.calendar_month_rounded, "Start Date",
              _formatDate(travelInfo['start_date']), primary, subTextColor),
          if (travelInfo['end_date'] != null) ...[
            const SizedBox(height: 16),
            _infoTile(Icons.event_available_rounded, "End Date",
                _formatDate(travelInfo['end_date']), primary, subTextColor),
          ],
        ],
      ),
    );
  }

  Widget _buildRouteCard(Map<String, dynamic> data, Color cardBg,
      Color subTextColor, Color primary, Color textColor) {
    final routeDetails = data['route_details'] as Map<String, dynamic>? ?? {};
    final locations = routeDetails['selected_locations'] as List? ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: cardBg, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(Icons.radio_button_checked_rounded,
                      color: Colors.green, size: 20),
                  Container(
                    width: 2,
                    height: 40,
                    color: Colors.grey.withOpacity(0.3),
                  ),
                  const Icon(Icons.place_rounded,
                      color: Colors.redAccent, size: 20),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locations.isNotEmpty ? locations.first.toString() : "N/A",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      locations.length > 1 ? locations.last.toString() : "N/A",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: textColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _smallBadge(Icons.straighten_rounded,
                  "${routeDetails['distance_km'] ?? 0} KM"),
              const SizedBox(width: 12),
              _smallBadge(Icons.timer_outlined,
                  "${routeDetails['duration_mins'] ?? 0} Mins"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequestStatsCard(Map<String, dynamic> data, Color cardBg,
      Color subTextColor, Color primary, Color textColor) {
    final vehicleConfig = data['vehicle_config'] as Map<String, dynamic>? ?? {};
    final additionalInfo = data['additional_info'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: cardBg, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: _infoTile(Icons.groups_rounded, "Passengers",
                      "${vehicleConfig['passenger_count'] ?? 0} Persons", primary, subTextColor)),
              Expanded(
                  child: _infoTile(Icons.shopping_bag_rounded, "Luggage",
                      additionalInfo['luggage_details']?.toString() ?? 'None', primary, subTextColor)),
            ],
          ),
          if (additionalInfo['special_requirements'] != null &&
              additionalInfo['special_requirements'].toString().isNotEmpty) ...[
            const Divider(height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.stars_rounded, size: 18, color: primary.withOpacity(0.7)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Special Requirements",
                          style: TextStyle(
                              fontSize: 10,
                              color: subTextColor,
                              fontWeight: FontWeight.w600)),
                      Text(additionalInfo['special_requirements'].toString(),
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRemarksCard(Map<String, dynamic> data, Color cardBg,
      Color subTextColor, Color primary, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: cardBg, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          if (data['faculty_remark'] != null)
            _remarkTile("Faculty", data['faculty_remark'].toString(), primary, subTextColor),
          if (data['faculty_remark'] != null && data['admin_remark'] != null)
            const Divider(height: 24),
          if (data['admin_remark'] != null)
            _remarkTile("Admin", data['admin_remark'].toString(), Colors.orange, subTextColor),
        ],
      ),
    );
  }

  Widget _remarkTile(String label, String value, Color color, Color subTextColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.chat_bubble_outline_rounded, size: 18, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("$label Remark",
                  style: TextStyle(
                      fontSize: 10,
                      color: subTextColor,
                      fontWeight: FontWeight.w600)),
              Text(value, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGuestList(List<dynamic> guests, Color cardBg, Color subTextColor,
      Color primary, Color textColor) {
    if (guests.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: cardBg, borderRadius: BorderRadius.circular(24)),
        child:
            Text("No guests recorded.", style: TextStyle(color: subTextColor)),
      );
    }
    return Container(
      decoration: BoxDecoration(
          color: cardBg, borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: guests.length,
        separatorBuilder: (context, index) =>
            Divider(height: 1, color: subTextColor.withOpacity(0.1)),
        itemBuilder: (context, index) {
          final guest = guests[index] as Map<String, dynamic>? ?? {};
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: primary.withOpacity(0.1),
              child: Text("${guest['seat_number'] ?? '?'}",
                  style:
                      TextStyle(color: primary, fontWeight: FontWeight.bold)),
            ),
            title: Text(guest['name']?.toString() ?? 'Guest ${index + 1}',
                style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
            subtitle: Text(guest['phone']?.toString() ?? 'No Phone',
                style: TextStyle(color: subTextColor, fontSize: 13)),
            trailing: _statusIcon(guest['status']),
          );
        },
      ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule, Color cardBg,
      Color subTextColor, Color primary, Color textColor) {
    final vehicle = schedule['vehicle'] as Map<String, dynamic>? ?? {};
    final driver = schedule['driver'] as Map<String, dynamic>? ?? {};
    final assignedGuests = schedule['guests'] as List? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: primary.withOpacity(0.1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_ind_rounded, size: 18, color: primary),
              const SizedBox(width: 8),
              Text((schedule['status']?.toString() ?? 'ASSIGNED').toUpperCase(),
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: primary,
                      fontSize: 12,
                      letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _infoTile(
                      Icons.local_taxi_rounded,
                      "Vehicle",
                      vehicle['vehicle_number']?.toString() ?? 'N/A',
                      primary,
                      subTextColor)),
              Expanded(
                  child: _infoTile(
                      Icons.person_rounded,
                      "Driver",
                      driver['name']?.toString() ?? 'N/A',
                      primary,
                      subTextColor)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.people_alt_rounded, size: 16, color: subTextColor),
              const SizedBox(width: 8),
              Text(
                "${schedule['guest_count'] ?? 0} Guests Assigned",
                style: TextStyle(fontSize: 12, color: subTextColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (assignedGuests.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: assignedGuests.map((g) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  g['name']?.toString() ?? 'Guest',
                  style: TextStyle(fontSize: 11, color: primary, fontWeight: FontWeight.w600),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCreatorCard(Map<String, dynamic>? creator, Color cardBg,
      Color subTextColor, Color primary, Color textColor) {
    if (creator == null) return const SizedBox();
    final role = creator['Role'] as Map<String, dynamic>? ?? {};
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: cardBg, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: primary.withOpacity(0.1),
            child: Icon(Icons.person_rounded, color: primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(creator['name']?.toString() ?? 'N/A',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: textColor)),
                Text(creator['email']?.toString() ?? 'N/A',
                    style: TextStyle(color: subTextColor, fontSize: 12)),
                Text(role['name']?.toString() ?? 'User',
                    style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.phone_in_talk_rounded, color: primary, size: 20),
            style: IconButton.styleFrom(
                backgroundColor: primary.withOpacity(0.05)),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value, Color primary,
      Color subTextColor) {
    return Row(
      children: [
        Icon(icon, size: 18, color: primary.withOpacity(0.7)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: subTextColor,
                      fontWeight: FontWeight.w600)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(String status) {
    Color color = const Color(0xFF6366F1);
    if (status.toLowerCase().contains("completed")) color = Colors.green;
    if (status.toLowerCase().contains("pending")) color = Colors.amber;
    if (status.toLowerCase().contains("approved"))
      color = const Color(0xFF10B981); // Emerald

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2))),
      child: Text(status.toUpperCase(),
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _smallBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _statusIcon(dynamic status) {
    if (status?.toString().toLowerCase() == 'active')
      return const Icon(Icons.check_circle_rounded,
          color: Colors.green, size: 18);
    return const Icon(Icons.info_outline_rounded, color: Colors.grey, size: 18);
  }

  String _getStatusLabel(dynamic code) {
    if (code == 6) return "Completed";
    if (code == 4) return "Approved";
    if (code == 1) return "Pending";
    return "In Progress";
  }

  String _formatDate(dynamic iso) {
    if (iso == null || iso.toString().isEmpty) return "N/A";
    try {
      final dt = DateTime.parse(iso.toString());
      return DateFormat('EEE, MMM dd, yyyy • hh:mm a').format(dt);
    } catch (_) {
      return iso.toString();
    }
  }
}
