import 'package:flutter/material.dart';
import 'package:tripzo/utils/toast_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/utils/ev_countdown_timer.dart';
import 'package:tripzo/store/user_store.dart' as tripzo_user_store;

import 'package:tripzo/store/providers.dart';

class DriverBatteryVehiclesPage extends ConsumerStatefulWidget {
  final String? dateFilter;
  const DriverBatteryVehiclesPage({super.key, this.dateFilter});

  @override
  ConsumerState<DriverBatteryVehiclesPage> createState() =>
      _DriverBatteryVehiclesPageState();
}

class _DriverBatteryVehiclesPageState
    extends ConsumerState<DriverBatteryVehiclesPage> {
  final TextEditingController _odoController = TextEditingController();
  final TextEditingController _battController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(batteryVehicleStoreProvider).fetchEvSchedules();
      if (mounted) {
        ref.read(batteryVehicleStoreProvider).fetchDriverBookings();
        ref.read(notificationProviderFamily).onEvRideUpdate = () {
          if (mounted)
            ref.read(batteryVehicleStoreProvider).fetchDriverBookings();
        };
      }
    });
  }

  @override
  void dispose() {
    _odoController.dispose();
    _battController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(batteryVehicleStoreProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBlue = const Color(0xFF6366F1);
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: store.error != null
          ? Center(
              child: Text(
                store.error!,
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            )
          : RefreshIndicator(
              color: primaryBlue,
              onRefresh: () async {
                await ref.read(batteryVehicleStoreProvider).fetchEvSchedules();
                ref.read(batteryVehicleStoreProvider).fetchDriverBookings();
              },
              child: _buildRequestsListRaw(
                store,
                cardColor,
                textColor,
                subColor,
                primaryBlue,
                isDark,
              ),
            ),
    );
  }

  Widget _buildRequestsListRaw(
    dynamic store,
    Color cardColor,
    Color textColor,
    Color subColor,
    Color primaryBlue,
    bool isDark,
  ) {
    final currentDriverId = tripzo_user_store.UserStore.driverId;
    final myBookings = store.driverBookings.where((b) {
      if (currentDriverId != null && b['requestDriver'] is List) {
        final rdList = b['requestDriver'] as List;
        final matches = rdList.where(
          (r) => r['driver_id']?.toString() == currentDriverId.toString(),
        );
        final myRd = matches.isNotEmpty ? matches.first : null;
        if (myRd == null) return false;
        b['response_status'] = myRd['response_status'];
        b['notified_at'] = myRd['notified_at'] ?? b['notified_at'];
      }
      return true;
    }).toList();

    if (store.isLoading && myBookings.isEmpty) {
      return Center(child: CircularProgressIndicator(color: primaryBlue));
    }
    if (myBookings.isEmpty) {
      return Center(
        child: Text(
          "No EV requests at the moment",
          textAlign: TextAlign.center,
          style: TextStyle(color: subColor, fontSize: 16),
        ),
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: myBookings.length,
      itemBuilder: (context, index) {
        final b = myBookings[index];
        final String rawStatus = (b['status'] ?? 'UNKNOWN')
            .toString()
            .toUpperCase();
        final String driverResponse = (b['response_status'] ?? '')
            .toString()
            .toUpperCase();
        final status = (driverResponse == 'EXPIRED' || rawStatus == 'EXPIRED')
            ? 'EXPIRED'
            : (rawStatus == 'REQUESTED' ? 'PENDING' : rawStatus);
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "EV Booking",
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (status == 'PENDING')
                          EvCountdownTimer(
                            timestampStr: (b['notified_at'] ??
                                    b['assigned_at'] ??
                                    b['updated_at'] ??
                                    b['created_at'] ??
                                    DateTime.now().toIso8601String())
                                .toString(),
                            onExpire: () {
                              ref.read(batteryVehicleStoreProvider).fetchDriverBookings();
                            },
                          ),
                        if (status == 'PENDING') const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: status == 'EXPIRED'
                                ? Colors.red.withOpacity(0.1)
                                : status == 'PENDING'
                                ? Colors.orange.withOpacity(0.1)
                                : primaryBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: status == 'EXPIRED'
                                  ? Colors.red
                                  : status == 'PENDING'
                                  ? Colors.orange
                                  : primaryBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Column(
                      children: [
                        Icon(Icons.trip_origin, color: primaryBlue, size: 16),
                        Container(
                          width: 2,
                          height: 24,
                          color: isDark ? Colors.white24 : Colors.black12,
                        ),
                        const Icon(
                          Icons.location_on,
                          color: Colors.green,
                          size: 16,
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getLocName(
                              b,
                              'fromLocation',
                              'from_location_id',
                              store.evLocations,
                            ),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _getLocName(
                              b,
                              'toLocation',
                              'to_location_id',
                              store.evLocations,
                            ),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.person, size: 16, color: primaryBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${_getPassengerName(b)} (${_getPassengerCode(b)})",
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (b['passenger_email'] != null &&
                              b['passenger_email'].toString().isNotEmpty)
                            Text(
                              "${b['passenger_email']}",
                              style: TextStyle(color: subColor, fontSize: 13),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.phone, size: 16, color: subColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getPassengerPhone(b),
                        style: TextStyle(
                          color: primaryBlue,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.call, color: Colors.green),
                      onPressed: () async {
                        final phone = _getPassengerPhone(b);
                        if (phone != 'N/A') {
                          final uri = Uri.parse('tel:$phone');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (status == 'PENDING' || status == 'EXPIRED') ...[
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: status == 'EXPIRED'
                                ? Colors.grey
                                : primaryBlue,

                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: status == 'EXPIRED'
                              ? null
                              : () async {
                                  try {
                                    await ref
                                        .read(batteryVehicleStoreProvider)
                                        .acceptRide(b['id'].toString());
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text("Cannot accept: $e"),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      ref
                                          .read(batteryVehicleStoreProvider)
                                          .fetchDriverBookings();
                                    }
                                  }
                                },
                          child: const Text(
                            'Accept',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (status == 'ACCEPTED') ...[
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            if (context.mounted) {
                              showTopToast(
                                context,
                                "Trip can only be started after the passenger entered the otp..",
                                isError: true,
                              );
                            }
                          },
                          child: const Text(
                            'Start Trip',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (status == 'ONGOING') ...[
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => ref
                              .read(batteryVehicleStoreProvider)
                              .completeRide(b['id'].toString()),
                          child: const Text(
                            'Complete Trip',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _getLocName(
  dynamic b,
  String key,
  String idKey,
  List<dynamic> locations,
) {
  if (b[key] is String) return b[key];
  if (b[key] is Map && b[key]['name'] != null) return b[key]['name'];
  final locId = b[idKey] ?? (b[key] is Map ? b[key]['id'] : null);
  if (locId != null) {
    final loc = locations.where(
      (l) => l['id'].toString() == locId.toString(),
    ).firstOrNull;
    if (loc != null && loc['name'] != null) return loc['name'];
  }
  return 'Unknown';
}

String _getPassengerName(dynamic b) {
  if (b['requestUser'] != null && b['requestUser']['name'] != null) {
    return b['requestUser']['name'];
  }
  return b['passenger_name'] ?? b['employee_code'] ?? 'Unknown Passenger';
}

String _getPassengerCode(dynamic b) {
  if (b['requestUser'] != null && b['requestUser']['employee_code'] != null) {
    return b['requestUser']['employee_code'];
  }
  return b['employee_code'] ?? 'N/A';
}

String _getPassengerPhone(dynamic b) {
  if (b['requestUser'] != null) {
    if (b['requestUser']['phone_number'] != null &&
        b['requestUser']['phone_number'].toString().isNotEmpty)
      return b['requestUser']['phone_number'].toString();
    if (b['requestUser']['phone'] != null &&
        b['requestUser']['phone'].toString().isNotEmpty)
      return b['requestUser']['phone'].toString();
    if (b['requestUser']['mobile'] != null &&
        b['requestUser']['mobile'].toString().isNotEmpty)
      return b['requestUser']['mobile'].toString();
  }
  if (b['passenger_phone'] != null &&
      b['passenger_phone'].toString().isNotEmpty)
    return b['passenger_phone'].toString();
  return 'N/A';
}
