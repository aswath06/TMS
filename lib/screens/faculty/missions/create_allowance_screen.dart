import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';

class CreateAllowanceScreen extends StatefulWidget {
  final int routeRequestId;
  final int tripId;
  final List<Map<String, dynamic>> drivers;

  const CreateAllowanceScreen({
    super.key,
    required this.routeRequestId,
    required this.tripId,
    required this.drivers,
  });

  @override
  State<CreateAllowanceScreen> createState() => _CreateAllowanceScreenState();
}

class _CreateAllowanceScreenState extends State<CreateAllowanceScreen> {
  final _formKey = GlobalKey<FormState>();
  String _dutyType = 'TRIP';
  String _allowanceType = 'BATA';
  final TextEditingController _remarksController = TextEditingController();
  final Map<int, TextEditingController> _amountControllers = {};
  final Map<int, TextEditingController> _reasonControllers = {};
  bool _isSaving = false;

  final List<String> _dutyTypes = ["TRIP", "MAINTENANCE", "EMERGENCY"];
  final List<String> _allowanceTypes = ["BATA", "FUEL", "SERVICE", "OTHER"];

  @override
  void initState() {
    super.initState();
    for (var driver in widget.drivers) {
      final id = driver['id'] as int;
      _amountControllers[id] = TextEditingController(text: "300");
      _reasonControllers[id] = TextEditingController(text: "Outstation bata");
    }
  }

  @override
  void dispose() {
    _remarksController.dispose();
    for (var c in _amountControllers.values) c.dispose();
    for (var c in _reasonControllers.values) c.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final token = await UserStore.getToken();
      
      List<Map<String, dynamic>> allowanceData = [];
      for (var driver in widget.drivers) {
        final id = driver['id'] as int;
        final amt = double.tryParse(_amountControllers[id]!.text) ?? 0.0;
        if (amt > 0) {
          allowanceData.add({
            "driver_id": id,
            "amount": amt,
            "reason": _reasonControllers[id]!.text.trim().isEmpty ? "Outstation bata" : _reasonControllers[id]!.text.trim(),
          });
        }
      }

      if (allowanceData.isEmpty) {
        throw "Please enter amount for at least one driver";
      }

      final body = {
        "route_request_id": widget.routeRequestId,
        "trip_id": widget.tripId,
        "duty_type": _dutyType,
        "allowance_type": _allowanceType,
        "remarks": _remarksController.text.trim().isEmpty ? "Allowance created via Mobile" : _remarksController.text.trim(),
        "allowances": allowanceData,
      };

      final url = "${ApiConstants.baseUrl}/request/create-allowance";
      
      // CURL Logging for Allowance
      debugPrint('curl --location \'$url\' \\');
      debugPrint('--header \'Authorization: TMS $token\' \\'); 
      debugPrint('--header \'Content-Type: application/json\' \\');
      debugPrint('--data-raw \'${jsonEncode(body)}\'');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          ...ApiConstants.getHeaders(token),
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      final respData = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Allowances Created Successfully"), backgroundColor: Color(0xFF10B981)),
        );
        Navigator.pop(context, true);
      } else {
        throw respData['message'] ?? "Failed to create allowance";
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final primaryBlue = const Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Create Allocation", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildDropdownSection("Duty Type", _dutyType, _dutyTypes, (val) => setState(() => _dutyType = val!), isDark),
                  const SizedBox(height: 20),
                  _buildDropdownSection("Allowance Type", _allowanceType, _allowanceTypes, (val) => setState(() => _allowanceType = val!), isDark),
                  const SizedBox(height: 20),
                  _buildTextField("General Remarks", _remarksController, isDark, maxLines: 2),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Icon(Icons.people_outline_rounded, size: 18, color: primaryBlue),
                      const SizedBox(width: 8),
                      Text("Driver Allocations", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: primaryBlue, letterSpacing: 0.5)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...widget.drivers.map((driver) => _buildDriverAllocationCard(driver, isDark, cardColor, primaryBlue)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5))],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("CONFIRM ALLOCATION", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownSection(String label, String value, List<String> items, ValueChanged<String?> onChanged, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey.shade500, letterSpacing: 0.5)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: items.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, bool isDark, {int maxLines = 1, bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey.shade500, letterSpacing: 0.5)),
          const SizedBox(height: 10),
        ],
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            hintText: "Enter $label...",
            hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.5), fontSize: 14),
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
          ),
        ),
      ],
    );
  }

  Widget _buildDriverAllocationCard(Map<String, dynamic> driver, bool isDark, Color cardColor, Color primaryBlue) {
    final id = driver['id'] as int;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryBlue.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: primaryBlue.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(Icons.person_outline_rounded, size: 20, color: primaryBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  driver['name'] ?? "Unknown Driver",
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildTextField("Amount", _amountControllers[id]!, isDark, isNumber: true),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: _buildTextField("Reason", _reasonControllers[id]!, isDark),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
