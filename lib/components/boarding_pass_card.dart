import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

class BoardingPassCard extends StatelessWidget {
  final String startLocationCode;
  final String startLocationName;
  final String startTime;
  
  final String endLocationCode;
  final String endLocationName;
  final String endTime;

  final String routeNo;
  final String date;
  final String busNo;
  final String boardingTime;
  final String shift;
  final String duration;

  final String passengerName;
  final String seatNo;

  final bool isDark;

  const BoardingPassCard({
    super.key,
    required this.startLocationCode,
    required this.startLocationName,
    required this.startTime,
    required this.endLocationCode,
    required this.endLocationName,
    required this.endTime,
    required this.routeNo,
    required this.date,
    required this.busNo,
    required this.boardingTime,
    required this.shift,
    required this.duration,
    required this.passengerName,
    required this.seatNo,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    // Colors
    final Color topBgColor = const Color(0xFF4F46E5); // Indigo color
    final Color bottomBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bottomBgColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // TOP SECTION (Indigo)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: topBgColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // BOARDING PASS LABEL
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "BOARDING PASS",
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: topBgColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // AIRPLANE & FLIGHT PATH
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Row(
                            children: List.generate(
                              20,
                              (index) => Expanded(
                                child: Container(
                                  height: 2,
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  color: Colors.white.withOpacity(0.5),
                                ),
                              ),
                            ),
                          ),
                          Icon(
                            Icons.directions_bus_rounded, // Changed from airplane to bus for context
                            color: Colors.white,
                            size: 28,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // LOCATIONS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Start Location
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          startLocationCode,
                          style: GoogleFonts.outfit(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          startLocationName,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.8),
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          startTime,
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                    // End Location
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          endLocationCode,
                          style: GoogleFonts.outfit(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          endLocationName,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.8),
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          endTime,
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // MIDDLE SECTION (Details)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDetailItem("ROUTE", routeNo, subTextColor, textColor),
                    _buildDetailItem("DATE", date, subTextColor, textColor, crossAxisAlignment: CrossAxisAlignment.end),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDetailItem("BUS", busNo, subTextColor, textColor),
                    _buildDetailItem("BOARDING", boardingTime, subTextColor, textColor, crossAxisAlignment: CrossAxisAlignment.end),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDetailItem("SHIFT", shift, subTextColor, textColor),
                    _buildDetailItem("DURATION", duration, subTextColor, textColor, crossAxisAlignment: CrossAxisAlignment.end),
                  ],
                ),
              ],
            ),
          ),
          
          // DIVIDER with half circles
          Row(
            children: [
              SizedBox(
                height: 24,
                width: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor, // Should match background
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  children: List.generate(
                    30,
                    (index) => Expanded(
                      child: Container(
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        color: subTextColor.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 24,
                width: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor, // Should match background
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // BOTTOM SECTION (Passenger & Animation)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailItem("PASSENGER", passengerName, subTextColor, topBgColor, valueFontSize: 16),
                    const SizedBox(height: 16),
                    _buildDetailItem("SEAT", seatNo, subTextColor, topBgColor, valueFontSize: 16),
                  ],
                ),
                // Instead of QR Code, show animation coming from backend (here simulated with Lottie or CircularProgressIndicator if no Lottie available)
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: topBgColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: topBgColor.withOpacity(0.2)),
                  ),
                  child: Center(
                    child: _buildAnimationPlaceholder(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimationPlaceholder() {
    // You can replace this with actual Lottie network animation url from backend.
    // For now, using a default circular progress indicator to simulate "animation coming from backend"
    // Example: Lottie.network(backendAnimationUrl)
    return const SizedBox(
      width: 40,
      height: 40,
      child: CircularProgressIndicator(
        strokeWidth: 3,
        color: Color(0xFF4F46E5), // Indigo
      ),
    );
  }

  Widget _buildDetailItem(
    String label,
    String value,
    Color labelColor,
    Color valueColor, {
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
    double valueFontSize = 14,
  }) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: labelColor,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: valueFontSize,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
