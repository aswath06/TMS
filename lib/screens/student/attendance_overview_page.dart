import 'package:flutter/material.dart';

class AttendanceOverviewPage extends StatelessWidget {
  const AttendanceOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    // Mock Data Grouped by Date (Only Present records as requested)
    final List<Map<String, dynamic>> dailyRecords = [
      {
        "date": "24 Oct 2023",
        "trips": [
          {
            "tripName": "Morning Trip",
            "time": "08:30 AM",
            "busNumber": "4",
            "vehicleNo": "TN-01-AB-1234",
          },
          {
            "tripName": "Evening Trip",
            "time": "04:15 PM",
            "busNumber": "12",
            "vehicleNo": "TN-02-XY-9876",
          }
        ]
      },
      {
        "date": "23 Oct 2023",
        "trips": [
          {
            "tripName": "Morning Trip",
            "time": "08:32 AM",
            "busNumber": "4",
            "vehicleNo": "TN-01-AB-1234",
          },
        ]
      },
      {
        "date": "21 Oct 2023",
        "trips": [
          {
            "tripName": "Evening Trip",
            "time": "04:20 PM",
            "busNumber": "15",
            "vehicleNo": "TN-03-ZZ-5555",
          }
        ]
      },
      {
        "date": "20 Oct 2023",
        "trips": [
          {
            "tripName": "Morning Trip",
            "time": "08:35 AM",
            "busNumber": "4",
            "vehicleNo": "TN-01-AB-1234",
          },
          {
            "tripName": "Evening Trip",
            "time": "04:10 PM",
            "busNumber": "12",
            "vehicleNo": "TN-02-XY-9876",
          }
        ]
      },
    ];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: titleColor),
        title: Text(
          "Attendance Overview",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: titleColor,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          physics: const BouncingScrollPhysics(),
          itemCount: dailyRecords.length,
          itemBuilder: (context, index) {
            final dailyRecord = dailyRecords[index];
            final String date = dailyRecord["date"];
            final List<Map<String, dynamic>> trips = dailyRecord["trips"];

            return Container(
              margin: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          date,
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(left: 12),
                          height: 1,
                          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Trip Cards for this date
                  ...trips.map((trip) => _buildTripCard(
                        trip: trip,
                        cardColor: cardColor,
                        titleColor: titleColor,
                        subColor: subColor,
                        isDark: isDark,
                      )).toList(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTripCard({
    required Map<String, dynamic> trip,
    required Color cardColor,
    required Color titleColor,
    required Color subColor,
    required bool isDark,
  }) {
    final isMorning = trip["tripName"].toString().toLowerCase().contains("morning");
    final Color tripColor = isMorning ? Colors.orange : Colors.indigo;
    final IconData tripIcon = isMorning ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(tripIcon, color: tripColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    trip["tripName"],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
                    SizedBox(width: 4),
                    Text(
                      "Present",
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              // Bus Number Badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tripColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    trip["busNumber"],
                    style: TextStyle(
                      color: tripColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Vehicle and Time Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Vehicle: ${trip["vehicleNo"]}",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, color: subColor, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          "Boarded at ${trip["time"]}",
                          style: TextStyle(
                            fontSize: 13,
                            color: subColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
