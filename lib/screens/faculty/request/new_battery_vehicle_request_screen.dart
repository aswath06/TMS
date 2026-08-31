import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/providers.dart';

class NewBatteryVehicleRequestScreen extends ConsumerStatefulWidget {
  const NewBatteryVehicleRequestScreen({super.key});

  @override
  ConsumerState<NewBatteryVehicleRequestScreen> createState() => _NewBatteryVehicleRequestScreenState();
}

class _NewBatteryVehicleRequestScreenState extends ConsumerState<NewBatteryVehicleRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  
  dynamic _fromLocationId;
  dynamic _toLocationId;
  String? _department;
  final TextEditingController _remarkController = TextEditingController();

  final List<String> _departments = [
    "Computer Science", "Mechanical", "Electrical", "Civil", "Management", "General"
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = ref.read(batteryVehicleStoreProvider);
      store.fetchLocations();
      store.fetchBookingConfig();
    });
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      final store = ref.read(batteryVehicleStoreProvider);
      try {
        await store.bookVehicle(
          _fromLocationId,
          _toLocationId,
          0.0, // lat
          0.0, // lng
          _remarkController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking Created Successfully')));
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
        }
      }
    }
  }

  void _showLocationSheet(bool isFrom) {
    final store = ref.read(batteryVehicleStoreProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isFrom ? "Select Departure" : "Select Destination",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: store.locations.length,
                  itemBuilder: (context, index) {
                    final loc = store.locations[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        loc['name'] ?? 'Unknown',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          if (isFrom) {
                            _fromLocationId = loc['id'];
                          } else {
                            _toLocationId = loc['id'];
                          }
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
  }

  void _showDepartmentSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Select Department",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _departments.length,
                  itemBuilder: (context, index) {
                    final dep = _departments[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        dep,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _department = dep;
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
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(batteryVehicleStoreProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBlue = const Color(0xFF6366F1);
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final hintColor = isDark ? Colors.white54 : Colors.black54;

    InputDecoration premiumDeco(String hint, IconData icon) {
      return InputDecoration(
        labelText: hint,
        labelStyle: TextStyle(color: hintColor, fontWeight: FontWeight.w500),
        prefixIcon: Icon(icon, color: primaryBlue, size: 22),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text('Request Battery Vehicle', style: TextStyle(color: textColor, fontWeight: FontWeight.w800)),
      ),
      body: store.isLoading && store.locations.isEmpty
        ? Center(child: CircularProgressIndicator(color: primaryBlue))
        : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: () => _showLocationSheet(true),
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: TextEditingController(
                          text: _fromLocationId != null 
                              ? store.locations.firstWhere((l) => l['id'] == _fromLocationId, orElse: () => {'name': ''})['name']
                              : null,
                        ),
                        style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600),
                        decoration: premiumDeco('From Location*', Icons.my_location_rounded).copyWith(
                          suffixIcon: Icon(Icons.keyboard_arrow_down_rounded, color: hintColor),
                        ),
                        validator: (val) => _fromLocationId == null ? 'Required' : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => _showLocationSheet(false),
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: TextEditingController(
                          text: _toLocationId != null 
                              ? store.locations.firstWhere((l) => l['id'] == _toLocationId, orElse: () => {'name': ''})['name']
                              : null,
                        ),
                        style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600),
                        decoration: premiumDeco('To Location*', Icons.location_on_rounded).copyWith(
                          suffixIcon: Icon(Icons.keyboard_arrow_down_rounded, color: hintColor),
                        ),
                        validator: (val) => _toLocationId == null ? 'Required' : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _showDepartmentSheet,
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: TextEditingController(text: _department),
                        style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w500),
                        decoration: premiumDeco('Department (Optional)', Icons.business_rounded).copyWith(
                          suffixIcon: Icon(Icons.keyboard_arrow_down_rounded, color: hintColor),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _remarkController,
                    style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w500),
                    decoration: premiumDeco('Reason for booking*', Icons.notes_rounded).copyWith(
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              minimumSize: const Size(double.infinity, 56),
            ),
            onPressed: store.isLoading ? null : _submit,
            child: store.isLoading
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Request Vehicle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    );
  }
}
