import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../../utils/api_constants.dart';
import '../../../store/user_store.dart';

class FuelPriceUpdatePage extends StatefulWidget {
  const FuelPriceUpdatePage({super.key});

  @override
  State<FuelPriceUpdatePage> createState() => _FuelPriceUpdatePageState();
}

class _FuelPriceUpdatePageState extends State<FuelPriceUpdatePage> {
  List<dynamic> _bunks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBunks();
  }

  Future<void> _fetchBunks() async {
    try {
      final token = await UserStore.getToken();
      final response = await http.get(
        Uri.parse(ApiConstants.fuelBunks),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          setState(() {
            _bunks = responseData['data'];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching bunks: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePrice(int id, String type, double newPrice) async {
    try {
      final token = await UserStore.getToken();
      final response = await http.patch(
        Uri.parse(ApiConstants.updateBunkPrice(id)),
        headers: ApiConstants.getHeaders(token),
        body: json.encode({
          "type": type,
          "amount": newPrice,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("$type price updated successfully"), backgroundColor: Colors.green),
          );
          _fetchBunks();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(responseData['message'] ?? "Update failed"), backgroundColor: Colors.red),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Server error: ${response.statusCode}"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Network error"), backgroundColor: Colors.red),
      );
    }
  }

  void _showEditSheet(dynamic bunk, String type) {
    String currentPrice = '0.00';
    if (type == 'PETROL') {
      currentPrice = bunk['petrol_price']?.toString() ?? '0.00';
    } else if (type == 'DIESEL') {
      currentPrice = bunk['diesel_price']?.toString() ?? '0.00';
    } else if (type == 'CNG') {
      currentPrice = bunk['cng_price']?.toString() ?? '0.00';
    }

    final TextEditingController priceController = TextEditingController(text: currentPrice);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primary = const Color(0xFF6366F1);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          top: 24,
          left: 24,
          right: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
                  color: titleColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Update $type Price",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: titleColor,
              ),
            ),
            Text(
              bunk['name'],
              style: GoogleFonts.plusJakartaSans(fontSize: 14, color: titleColor.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primary.withValues(alpha: 0.1)),
              ),
              child: TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: titleColor),
                decoration: InputDecoration(
                  icon: Icon(Icons.currency_rupee_rounded, color: primary, size: 20),
                  border: InputBorder.none,
                  hintText: "Enter price per liter",
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final price = double.tryParse(priceController.text);
                  if (price != null) {
                    Navigator.pop(context);
                    _updatePrice(bunk['id'], type, price);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text("Update Price", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFuelPriceTag(
    String type,
    dynamic priceVal,
    dynamic bunk,
    Color primary,
    Color titleColor,
    bool isDark,
  ) {
    final double price = double.tryParse(priceVal?.toString() ?? '0.0') ?? 0.0;
    
    Color typeColor;
    IconData icon;
    if (type == 'PETROL') {
      typeColor = const Color(0xFFF59E0B);
      icon = Icons.local_gas_station_rounded;
    } else if (type == 'DIESEL') {
      typeColor = const Color(0xFF10B981);
      icon = Icons.oil_barrel_rounded;
    } else {
      typeColor = const Color(0xFF06B6D4);
      icon = Icons.local_gas_station_outlined;
    }

    return GestureDetector(
      onTap: () => _showEditSheet(bunk, type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: typeColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: typeColor.withValues(alpha: 0.15), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: typeColor),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  type,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: typeColor,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  "₹${price.toStringAsFixed(2)}",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.edit_rounded, size: 8, color: typeColor),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color primary = const Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: titleColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Amount Updates",
          style: GoogleFonts.plusJakartaSans(color: titleColor, fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: _bunks.length,
            itemBuilder: (context, index) {
              final bunk = _bunks[index];
              return TweenAnimationBuilder(
                duration: Duration(milliseconds: 400 + (index * 100)),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 30 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(Icons.local_gas_station_rounded, color: primary),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bunk['name'],
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: titleColor,
                                  ),
                                ),
                                Text(
                                  bunk['owner_name'],
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: titleColor.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildFuelPriceTag("PETROL", bunk['petrol_price'], bunk, primary, titleColor, isDark),
                          _buildFuelPriceTag("DIESEL", bunk['diesel_price'], bunk, primary, titleColor, isDark),
                          _buildFuelPriceTag("CNG", bunk['cng_price'], bunk, primary, titleColor, isDark),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }
}
