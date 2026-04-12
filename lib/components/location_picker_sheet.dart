import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripzo/utils/api_constants.dart';

const String kFrequentLocationsKey = 'frequent_locations';
const int kMaxFrequentLocations = 10;

class LocationPickerSheet extends StatefulWidget {
  final String label;
  final Color accentColor;
  final Color cardColor;
  final Color titleColor;
  final String userAgent;

  const LocationPickerSheet({
    super.key,
    required this.label,
    required this.accentColor,
    required this.cardColor,
    required this.titleColor,
    required this.userAgent,
  });

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _frequent = [];
  bool _isLoading = false;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _loadFrequent();
    // Auto-focus after sheet animation
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── SharedPreferences: frequent locations ─────────────────
  Future<void> _loadFrequent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(kFrequentLocationsKey) ?? [];
    setState(() {
      _frequent = raw.map((e) => json.decode(e) as Map<String, dynamic>).toList();
    });
  }

  Future<void> _saveFrequent(Map<String, dynamic> loc) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(kFrequentLocationsKey) ?? [];

    // Remove duplicate if it already exists
    final updated = raw.where((e) {
      final decoded = json.decode(e) as Map<String, dynamic>;
      return decoded['display_name'] != loc['display_name'];
    }).toList();

    // Insert at front (most recent first)
    updated.insert(0, json.encode(loc));

    // Keep only top N
    if (updated.length > kMaxFrequentLocations) updated.removeRange(kMaxFrequentLocations, updated.length);

    await prefs.setStringList(kFrequentLocationsKey, updated);
  }

  // ── Nominatim search ──────────────────────────────────────
  Future<void> _search(String query) async {
    if (query.trim().length < 3) {
      setState(() { _results = []; _searched = false; });
      return;
    }
    if (!mounted) return;
    setState(() { _isLoading = true; _searched = true; });

    final url =
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=8&countrycodes=in';

    try {
      final res = await http.get(Uri.parse(url), headers: {'User-Agent': widget.userAgent, 'Accept-Language': 'en'});
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        if (!mounted) return;
        setState(() {
          _results = data
              .map((e) => {
                    'display_name': e['display_name'].toString(),
                    'lat': double.parse(e['lat'].toString()),
                    'lon': double.parse(e['lon'].toString()),
                  })
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Location search error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _pick(Map<String, dynamic> location) {
    _saveFrequent(location);
    Navigator.pop(context, location);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final divColor = isDark ? Colors.white10 : Colors.black.withOpacity(0.06);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 30, offset: const Offset(0, -4))],
          ),
          child: Column(
            children: [
              // ── Drag handle ──────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),

              // ── Header row ───────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: widget.accentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        (widget.label == 'Start Location' || widget.label == 'சம்பவம் நடந்த இடம்') ? Icons.trip_origin : Icons.location_on_rounded,
                        color: widget.accentColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Close',
                        style: TextStyle(
                          color: widget.accentColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Search bar ───────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.07) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: widget.accentColor.withOpacity(0.25), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Icon(Icons.search_rounded, color: widget.accentColor.withOpacity(0.7), size: 22),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          focusNode: _focusNode,
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search location…',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontWeight: FontWeight.normal,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          onChanged: (v) => _search(v),
                        ),
                      ),
                      if (_searchCtrl.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() { _results = []; _searched = false; });
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Icon(Icons.close_rounded, size: 18, color: Colors.grey.shade400),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              Divider(height: 24, indent: 16, endIndent: 16, color: divColor),

              // ── Results / Frequent list ───────────────────
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: widget.accentColor, strokeWidth: 2.5))
                    : _buildResultList(isDark, scrollCtrl),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResultList(bool isDark, ScrollController ctrl) {
    // Institution Locations (Always visible at the top)
    final bitLoc = ApiConstants.bitLocation;
    
    // Show search results
    if (_searched && _results.isNotEmpty) {
      return ListView.separated(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _results.length + 1,
        separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
        itemBuilder: (_, i) {
          if (i == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(Icons.school_rounded, 'INSTITUTION'),
                _resultTile(bitLoc, isDark, isFrequent: false, isInstitution: true),
                const SizedBox(height: 16),
                _sectionHeader(Icons.search_rounded, 'SEARCH RESULTS'),
              ],
            );
          }
          return _resultTile(_results[i - 1], isDark, isFrequent: false);
        },
      );
    }

    // No results from search
    if (_searched && _results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No locations found', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Try a different search term', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ],
        ),
      );
    }

    // Frequent locations (default view)
    if (_frequent.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No recent locations', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Search above to find a location', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView(
      controller: ctrl,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        _sectionHeader(Icons.school_rounded, 'INSTITUTION'),
        _resultTile(bitLoc, isDark, isFrequent: false, isInstitution: true),
        const SizedBox(height: 24),
        _sectionHeader(Icons.history_rounded, 'FREQUENT LOCATIONS'),
        ...List.generate(
          _frequent.length,
          (i) => Column(
            children: [
              _resultTile(_frequent[i], isDark, isFrequent: true),
              if (i < _frequent.length - 1)
                Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 15, color: Colors.grey.shade400),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _resultTile(Map<String, dynamic> loc, bool isDark, {bool isFrequent = false, bool isInstitution = false}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _pick(loc),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isInstitution 
                    ? widget.accentColor.withOpacity(0.15)
                    : (isFrequent
                        ? Colors.orange.withOpacity(0.1)
                        : widget.accentColor.withOpacity(0.08)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isInstitution 
                    ? Icons.account_balance_rounded 
                    : (isFrequent ? Icons.history_rounded : Icons.location_on_rounded),
                color: isInstitution ? widget.accentColor : (isFrequent ? Colors.orange : widget.accentColor),
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                loc['display_name'] ?? '',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
