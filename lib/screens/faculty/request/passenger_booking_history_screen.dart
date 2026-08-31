import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/providers.dart';

class PassengerBookingHistoryScreen extends ConsumerStatefulWidget {
  const PassengerBookingHistoryScreen({super.key});

  @override
  ConsumerState<PassengerBookingHistoryScreen> createState() =>
      _PassengerBookingHistoryScreenState();
}

class _PassengerBookingHistoryScreenState
    extends ConsumerState<PassengerBookingHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(batteryVehicleStoreProvider).initWebSocket();
      ref.read(batteryVehicleStoreProvider).fetchPassengerBookings();
    });
  }

  Color _getStatusColor(String status) {
    if (status == 'COMPLETED') return Colors.green;
    if (status == 'CANCELLED' || status == 'EXPIRED') return Colors.red;
    if (status == 'PENDING' || status == 'REQUESTED') return Colors.orange;
    if (status == 'STARTED') return Colors.blue;
    if (status == 'ONGOING') return const Color(0xFF8B5CF6);
    return Colors.grey;
  }

  IconData _getStatusIcon(String status) {
    if (status == 'COMPLETED') return Icons.check_circle;
    if (status == 'CANCELLED') return Icons.cancel;
    if (status == 'EXPIRED') return Icons.timer_off;
    if (status == 'STARTED') return Icons.directions_car;
    if (status == 'ONGOING') return Icons.electric_car;
    return Icons.pending;
  }

  Future<void> _showOtpDialog(BuildContext context, String bookingId) async {
    final otpController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool submitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.vpn_key, color: Color(0xFF6366F1)),
              const SizedBox(width: 8),
              Text('Enter OTP',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  )),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ask the driver for the vehicle OTP and enter it below to start your ride.',
                style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8),
                decoration: InputDecoration(
                  hintText: '——————',
                  counterText: '',
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: submitting
                  ? null
                  : () async {
                      final otp = otpController.text.trim();
                      if (otp.isEmpty) return;
                      setDialogState(() => submitting = true);
                      try {
                        await ref
                            .read(batteryVehicleStoreProvider)
                            .submitOtp(bookingId, otp);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Ride started! Enjoy your trip 🚗'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => submitting = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('Invalid OTP: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Start Ride'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(batteryVehicleStoreProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBlue = const Color(0xFF6366F1);
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text('My EV Bookings',
            style:
                TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: textColor),
            onPressed: () =>
                ref.read(batteryVehicleStoreProvider).fetchPassengerBookings(),
          )
        ],
      ),
      body: store.isLoading && store.passengerBookings.isEmpty
          ? Center(child: CircularProgressIndicator(color: primaryBlue))
          : store.passengerBookings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.electric_car,
                          size: 64, color: subColor.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      Text('No bookings found',
                          style: TextStyle(color: subColor, fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: primaryBlue,
                  onRefresh: () => ref
                      .read(batteryVehicleStoreProvider)
                      .fetchPassengerBookings(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: store.passengerBookings.length,
                    itemBuilder: (context, index) {
                      final b = store.passengerBookings[index];
                      final status =
                          (b['status'] ?? 'UNKNOWN').toString().toUpperCase();
                      final statusColor = _getStatusColor(status);
                      final statusIcon = _getStatusIcon(status);

                      // Location names
                      String fromName = '-';
                      String toName = '-';
                      if (b['fromLocation'] is Map) {
                        fromName = b['fromLocation']['name'] ?? '-';
                      } else if (b['from_location'] is String) {
                        fromName = b['from_location'];
                      }
                      if (b['toLocation'] is Map) {
                        toName = b['toLocation']['name'] ?? '-';
                      } else if (b['to_location'] is String) {
                        toName = b['to_location'];
                      }

                      // Driver info
                      String driverName = '-';
                      String driverPhone = '-';
                      if (b['driver'] is Map) {
                        final dUser = b['driver']['user'];
                        if (dUser is Map) {
                          driverName = dUser['name'] ?? '-';
                          driverPhone =
                              dUser['phone_number'] ?? dUser['phone'] ?? '-';
                        }
                      }

                      final bookingId = (b['id'] ?? b['booking_id']).toString();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.black12),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4))
                          ],
                        ),
                        child: Column(
                          children: [
                            // Header
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  // Title row
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Booking #$bookingId',
                                        style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(statusIcon,
                                                size: 13,
                                                color: statusColor),
                                            const SizedBox(width: 4),
                                            Text(status,
                                                style: TextStyle(
                                                    color: statusColor,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 12),
                                    child: Divider(height: 1),
                                  ),
                                  // From
                                  Row(
                                    children: [
                                      Icon(Icons.location_on,
                                          color: primaryBlue, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text('From: $fromName',
                                            style: TextStyle(
                                                color: textColor,
                                                fontSize: 14,
                                                fontWeight:
                                                    FontWeight.w600)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // To
                                  Row(
                                    children: [
                                      const Icon(Icons.flag,
                                          color: Colors.green, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text('To: $toName',
                                            style: TextStyle(
                                                color: textColor,
                                                fontSize: 14,
                                                fontWeight:
                                                    FontWeight.w600)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Reason
                                  Row(
                                    children: [
                                      Icon(Icons.note,
                                          color: subColor, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Reason: ${b['reason'] ?? '-'}',
                                          style: TextStyle(
                                              color: subColor,
                                              fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Driver info when assigned
                                  if ((status == 'STARTED' ||
                                          status == 'ONGOING' ||
                                          status == 'COMPLETED') &&
                                      driverName != '-') ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: primaryBlue.withOpacity(0.06),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.person,
                                              color: Color(0xFF6366F1),
                                              size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Driver: $driverName',
                                                  style: TextStyle(
                                                      color: textColor,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 13),
                                                ),
                                                if (driverPhone != '-')
                                                  Text(
                                                    driverPhone,
                                                    style: TextStyle(
                                                        color: primaryBlue,
                                                        fontSize: 12),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Action banner at bottom based on status
                            if (status == 'STARTED') ...[
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.08),
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(16),
                                    bottomRight: Radius.circular(16),
                                  ),
                                ),
                                padding: const EdgeInsets.fromLTRB(
                                    16, 0, 16, 16),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFF6366F1),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () =>
                                        _showOtpDialog(context, bookingId),
                                    icon: const Icon(Icons.vpn_key, size: 18),
                                    label: const Text(
                                      'Enter OTP to Start Ride',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ),
                            ] else if (status == 'ONGOING') ...[
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6)
                                      .withOpacity(0.08),
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(16),
                                    bottomRight: Radius.circular(16),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.electric_car,
                                        color: Color(0xFF8B5CF6), size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Ride in progress...',
                                      style: TextStyle(
                                        color: const Color(0xFF8B5CF6),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (status == 'COMPLETED') ...[
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.08),
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(16),
                                    bottomRight: Radius.circular(16),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.check_circle,
                                        color: Colors.green, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'Trip Completed',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
