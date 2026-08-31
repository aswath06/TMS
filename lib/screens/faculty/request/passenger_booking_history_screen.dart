import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/providers.dart';

class PassengerBookingHistoryScreen extends ConsumerStatefulWidget {
  const PassengerBookingHistoryScreen({super.key});

  @override
  ConsumerState<PassengerBookingHistoryScreen> createState() => _PassengerBookingHistoryScreenState();
}

class _PassengerBookingHistoryScreenState extends ConsumerState<PassengerBookingHistoryScreen> {
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
    if (status == 'CANCELLED') return Colors.red;
    if (status == 'PENDING' || status == 'REQUESTED') return Colors.orange;
    if (status == 'ACCEPTED' || status == 'STARTED') return Colors.pink;
    if (status == 'ONGOING') return Colors.blue;
    return Colors.grey;
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
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text('My EV Bookings', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
      ),
      body: store.isLoading && store.passengerBookings.isEmpty
          ? Center(child: CircularProgressIndicator(color: primaryBlue))
          : store.passengerBookings.isEmpty
              ? Center(child: Text("No bookings found", style: TextStyle(color: subColor, fontSize: 16)))
              : RefreshIndicator(
                  color: primaryBlue,
                  onRefresh: () => ref.read(batteryVehicleStoreProvider).fetchPassengerBookings(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: store.passengerBookings.length,
                    itemBuilder: (context, index) {
                      final b = store.passengerBookings[index];
                      final status = b['status'] ?? 'UNKNOWN';
                      final statusColor = _getStatusColor(status);
                      
                      String fromName = b['from_location'] ?? b['from_location_id']?.toString() ?? '-';
                      String toName = b['to_location'] ?? b['to_location_id']?.toString() ?? '-';
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))]
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Booking #${b['id']}", style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 16)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(height: 1),
                            ),
                            Row(
                              children: [
                                Icon(Icons.location_on, color: primaryBlue, size: 20),
                                const SizedBox(width: 8),
                                Expanded(child: Text("From: $fromName", style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.flag, color: Colors.green, size: 20),
                                const SizedBox(width: 8),
                                Expanded(child: Text("To: $toName", style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text("Reason: ${b['reason'] ?? '-'}", style: TextStyle(color: subColor)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
