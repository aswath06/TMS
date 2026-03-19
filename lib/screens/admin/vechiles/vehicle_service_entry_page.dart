import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/components/common/custom_date_time_picker.dart';

class VehicleServiceEntryPage extends StatefulWidget {
  final dynamic vehicleId;
  final String vehicleNumber;

  const VehicleServiceEntryPage({
    super.key,
    required this.vehicleId,
    required this.vehicleNumber,
  });

  @override
  State<VehicleServiceEntryPage> createState() => _VehicleServiceEntryPageState();
}

class _VehicleServiceEntryPageState extends State<VehicleServiceEntryPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Form Controllers
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _currentKmController = TextEditingController();
  final TextEditingController _nextServiceKmController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? _nextServiceDate;

  // Data
  List<dynamic> _allServiceTypes = [];
  List<dynamic> _selectedServiceTypes = [];
  List<dynamic> _matchingShops = [];
  Map<String, dynamic>? _selectedShop;

  bool _isSubmitting = false;
  bool _isLoadingTypes = false;
  bool _isLoadingShops = false;
  
  StateSetter? _serviceModalState;
  StateSetter? _shopModalState;

  @override
  void initState() {
    super.initState();
    _fetchServiceTypes();
  }

  Future<void> _fetchServiceTypes() async {
    setState(() => _isLoadingTypes = true);
    try {
      final token = await UserStore.getToken();
      final response = await http.get(
        Uri.parse(ApiConstants.serviceTypes),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> types = data['data'] ?? [];
        
        // Sort: Put 'Other' at the end
        types.sort((a, b) {
          final nameA = (a['name'] ?? '').toString().toLowerCase();
          final nameB = (b['name'] ?? '').toString().toLowerCase();
          if (nameA.contains('other')) return 1;
          if (nameB.contains('other')) return -1;
          return nameA.compareTo(nameB);
        });
        
        setState(() => _allServiceTypes = types);
        _serviceModalState?.call(() {});
      }
    } catch (e) {
      debugPrint("Error fetching service types: $e");
    } finally {
      setState(() => _isLoadingTypes = false);
      _serviceModalState?.call(() {});
    }
  }

  Future<void> _fetchMatchingShops() async {
    if (_selectedServiceTypes.isEmpty) return;
    
    setState(() => _isLoadingShops = true);
    try {
      final token = await UserStore.getToken();
      final ids = _selectedServiceTypes.map((t) => t['id']).join(',');
      final response = await http.get(
        Uri.parse("${ApiConstants.serviceShops}?service_type_ids=$ids"),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _matchingShops = data['data'] ?? [];
          // Reset selected shop if it's no longer in the list
          if (_selectedShop != null && !_matchingShops.any((s) => s['id'] == _selectedShop!['id'])) {
            _selectedShop = null;
          }
        });
        _shopModalState?.call(() {});
      }
    } catch (e) {
      debugPrint("Error fetching shops: $e");
    } finally {
      setState(() => _isLoadingShops = false);
      _shopModalState?.call(() {});
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedServiceTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one service type")));
      return;
    }
    if (_selectedShop == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a shop")));
      return;
    }
    if (_nextServiceDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select next service date")));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final token = await UserStore.getToken();
      final body = {
        "vehicle_id": widget.vehicleId,
        "title": "Periodic Maintenance",
        "shop_id": _selectedShop!['id'],
        "maintance_type": _selectedServiceTypes.map((t) => t['id']).toList(),
        "description": _descriptionController.text,
        "current_km": int.tryParse(_currentKmController.text) ?? 0,
        "cost": int.tryParse(_costController.text) ?? 0,
        "next_service_km": int.tryParse(_nextServiceKmController.text) ?? 0,
        "next_service_date": DateFormat('yyyy-MM-dd').format(_nextServiceDate!),
      };

      final response = await http.post(
        Uri.parse(ApiConstants.vehicleMaintenance),
        headers: ApiConstants.getHeaders(token),
        body: json.encode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Maintenance logged successfully")));
        Navigator.pop(context, true);
      } else {
        if (!mounted) return;
        String errorMessage = "Failed to log maintenance";
        try {
          final errorData = json.decode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final primaryBlue = const Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("Service Entry", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildVehicleInfo(primaryBlue),
              const SizedBox(height: 24),
              _buildSelectionTile(
                label: "Select Services",
                hint: _selectedServiceTypes.isEmpty ? "No services selected" : _selectedServiceTypes.map((t) => t['name']).join(', '),
                icon: Icons.settings_outlined,
                onTap: () => _showServiceTypePicker(),
                surfaceColor: surfaceColor,
              ),
              const SizedBox(height: 16),
              _buildSelectionTile(
                label: "Select Shop",
                hint: _selectedShop?['name'] ?? "Select a service provider",
                icon: Icons.store_outlined,
                onTap: _selectedServiceTypes.isEmpty ? null : () => _showShopPicker(),
                surfaceColor: surfaceColor,
                isLoading: _isLoadingShops,
              ),
              const SizedBox(height: 24),
              _buildSectionTitle("Service Details"),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _costController,
                label: "Total Cost (₹)",
                icon: Icons.payments_outlined,
                keyboardType: TextInputType.number,
                surfaceColor: surfaceColor,
                validator: (v) => v!.isEmpty ? "Enter cost" : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _currentKmController,
                label: "Current Odometer (KM)",
                icon: Icons.speed_outlined,
                keyboardType: TextInputType.number,
                surfaceColor: surfaceColor,
                validator: (v) => v!.isEmpty ? "Enter current KM" : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _nextServiceKmController,
                label: "Next Service KM",
                icon: Icons.trending_up,
                keyboardType: TextInputType.number,
                surfaceColor: surfaceColor,
                validator: (v) => v!.isEmpty ? "Enter next service KM" : null,
              ),
              const SizedBox(height: 16),
              _buildDatePicker(surfaceColor, isDark),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _descriptionController,
                label: "Description/Notes",
                icon: Icons.note_alt_outlined,
                maxLines: 3,
                surfaceColor: surfaceColor,
              ),
              const SizedBox(height: 40),
              _buildSubmitButton(primaryBlue),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleInfo(Color primary) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.local_shipping_rounded, color: primary, size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.vehicleNumber, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              const Text("Logging new maintenance entry", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionTile({
    required String label,
    required String hint,
    required IconData icon,
    VoidCallback? onTap,
    required Color surfaceColor,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF6366F1), size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    hint,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: onTap == null ? Colors.grey : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            else
              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    required Color surfaceColor,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF6366F1)),
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildDatePicker(Color surfaceColor, bool isDark) {
    return InkWell(
      onTap: () async {
        final picked = await CustomDateTimePicker.show(
          context,
          initialDate: _nextServiceDate ?? DateTime.now().add(const Duration(days: 30)),
          minDate: DateTime.now(),
          showTime: false,
        );
        if (picked != null) {
          setState(() => _nextServiceDate = picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined, color: Color(0xFF6366F1)),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Next Service Date", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  _nextServiceDate == null ? "Select Date" : DateFormat('dd MMM, yyyy').format(_nextServiceDate!),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5));
  }

  Widget _buildShimmerList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.white10 : Colors.grey[300]!,
      highlightColor: isDark ? Colors.white24 : Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 8,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: double.infinity, height: 16, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(width: 150, height: 12, color: Colors.white),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(Color primary) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text("SUBMIT SERVICE RECORD", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.1)),
      ),
    );
  }

  void _showServiceTypePicker() {
    final TextEditingController searchController = TextEditingController();
    List<dynamic> filteredTypes = List.from(_allServiceTypes);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          _serviceModalState = setModalState;
          
          // Sync filtered list with main list if not searching
          if (searchController.text.isEmpty) {
            filteredTypes = List.from(_allServiceTypes);
          }
          
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 40, offset: const Offset(0, -10))],
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Select Services", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.grey)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  controller: searchController,
                  onChanged: (val) {
                    setModalState(() {
                      filteredTypes = _allServiceTypes.where((t) => (t['name'] ?? '').toString().toLowerCase().contains(val.toLowerCase())).toList();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: "Search service types...",
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF6366F1)),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              searchController.clear();
                              setModalState(() {
                                filteredTypes = List.from(_allServiceTypes);
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.04),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoadingTypes
                    ? _buildShimmerList()
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredTypes.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, indent: 56, color: Colors.black12),
                        itemBuilder: (context, index) {
                          final item = filteredTypes[index];
                          final isSelected = _selectedServiceTypes.any((t) => t['id'] == item['id']);
                          return CheckboxListTile(
                            value: isSelected,
                            title: Text(item['name'] ?? '', style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 16)),
                            secondary: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.settings_suggest_rounded, color: Color(0xFF6366F1), size: 18),
                            ),
                            activeColor: const Color(0xFF6366F1),
                            checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            onChanged: (val) {
                              setState(() {
                                if (val!) {
                                  _selectedServiceTypes.add(item);
                                } else {
                                  _selectedServiceTypes.removeWhere((t) => t['id'] == item['id']);
                                }
                              });
                              setModalState(() {});
                              _fetchMatchingShops();
                            },
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text("${_selectedServiceTypes.length} SERVICES SELECTED", style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),
              ),
            ],
          ),
        );
        },
      ),
    ).whenComplete(() => _serviceModalState = null);
  }

  void _showShopPicker() {
    final TextEditingController searchController = TextEditingController();
    List<dynamic> filteredShops = List.from(_matchingShops);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          _shopModalState = setModalState;
          
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Service Provider", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  controller: searchController,
                  onChanged: (val) {
                    setModalState(() {
                      filteredShops = _matchingShops.where((s) => (s['name'] ?? '').toString().toLowerCase().contains(val.toLowerCase())).toList();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: "Search providers...",
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF6366F1)),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.04),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoadingShops
                    ? _buildShimmerList()
                    : filteredShops.isEmpty
                        ? const Expanded(child: Center(child: Text("No records found", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filteredShops.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, indent: 70),
                            itemBuilder: (context, index) {
                              final shop = filteredShops[index];
                              final isSelected = _selectedShop?['id'] == shop['id'];
                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), shape: BoxShape.circle),
                                  child: const Icon(Icons.storefront_rounded, color: Color(0xFF10B981), size: 24),
                                ),
                                title: Text(shop['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(shop['address'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFF6366F1)) : null,
                                onTap: () {
                                  setState(() => _selectedShop = shop);
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
      ),
    ).whenComplete(() => _shopModalState = null);
  }
}
