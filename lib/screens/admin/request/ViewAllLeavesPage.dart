import 'package:flutter/material.dart';
import 'package:tms/components/leave_card.dart';

class ViewAllLeavesPage extends StatefulWidget {
  final List<Map<String, dynamic>> leaves;

  const ViewAllLeavesPage({super.key, required this.leaves});

  @override
  State<ViewAllLeavesPage> createState() => _ViewAllLeavesPageState();
}

class _ViewAllLeavesPageState extends State<ViewAllLeavesPage> {
  late List<Map<String, dynamic>> _filteredLeaves;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredLeaves = widget.leaves;
  }

  void _filterLeaves(String query) {
    setState(() {
      _filteredLeaves = widget.leaves
          .where(
            (leaf) => (leaf['driver'] ?? "").toLowerCase().contains(
              query.toLowerCase(),
            ),
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: titleColor,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "All Leave Requests",
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.history_rounded, color: titleColor),
            onPressed: () {
              // Action for leave history
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterLeaves,
                style: TextStyle(color: titleColor),
                decoration: InputDecoration(
                  hintText: "Search driver name...",
                  hintStyle: TextStyle(
                    color: titleColor.withOpacity(0.4),
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: primaryBlue,
                    size: 22,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            color: titleColor.withOpacity(0.4),
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _filterLeaves("");
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),

          // Leaves List
          Expanded(
            child: _filteredLeaves.isEmpty
                ? _buildEmptyState(titleColor)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _filteredLeaves.length,
                    itemBuilder: (context, index) {
                      return LeaveCard(
                        leaf: _filteredLeaves[index],
                        isDark: isDark,
                        primaryColor: primaryBlue,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color titleColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off_rounded,
            size: 60,
            color: titleColor.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            "No leave requests found",
            style: TextStyle(
              color: titleColor.withOpacity(0.5),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
