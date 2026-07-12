import os

file_path = '/Users/aswath/Documents/Tripzo/TMS/lib/screens/admin/request/daily_routines_page.dart'

with open(file_path, 'r') as f:
    content = f.read()

# 1. Add _isListView state
old_state = """  String _selectedFilter = 'ALL';
  String _selectedDateFilter = 'ALL';
  
  bool _isLoading = false;"""

new_state = """  String _selectedFilter = 'ALL';
  String _selectedDateFilter = 'ALL';
  bool _isListView = false;
  
  bool _isLoading = false;"""

content = content.replace(old_state, new_state)

# 2. Add _buildViewToggleButton
old_filter_btn = """  Widget _buildFilterButton(Color p, Color t, bool d) {"""

new_view_toggle = """  Widget _buildViewToggleButton(Color p, Color t, bool d) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isListView = !_isListView;
        });
      },
      child: Container(
        height: 54,
        width: 54,
        decoration: BoxDecoration(
          color: d ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: d ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Icon(_isListView ? Icons.view_agenda_rounded : Icons.view_list_rounded, color: p, size: 24),
      ),
    );
  }

  Widget _buildFilterButton(Color p, Color t, bool d) {"""

content = content.replace(old_filter_btn, new_view_toggle)

# 3. Add to Row
old_row = """                  Row(
                    children: [
                      Expanded(child: _buildSearchBar(isDark, primaryBlue, subColor)),
                      const SizedBox(width: 12),
                      _buildFilterButton(primaryBlue, titleColor, isDark),
                    ],
                  ),"""

new_row = """                  Row(
                    children: [
                      Expanded(child: _buildSearchBar(isDark, primaryBlue, subColor)),
                      const SizedBox(width: 12),
                      _buildViewToggleButton(primaryBlue, titleColor, isDark),
                      const SizedBox(width: 12),
                      _buildFilterButton(primaryBlue, titleColor, isDark),
                    ],
                  ),"""

content = content.replace(old_row, new_row)

with open(file_path, 'w') as f:
    f.write(content)

print("Done")
