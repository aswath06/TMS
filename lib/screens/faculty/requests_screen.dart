import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/providers.dart';
import 'package:tripzo/screens/faculty/request/new_request_screen.dart';
import 'package:tripzo/store/request_store.dart';
import 'package:tripzo/components/request_card.dart';

class RequestsScreen extends ConsumerStatefulWidget {
  const RequestsScreen({super.key});

  @override
  ConsumerState<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends ConsumerState<RequestsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(requestStoreProvider).fetchRequests(isRefresh: true);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(requestStoreProvider).fetchNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final double horizontalPadding = size.width * 0.06;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final store = ref.watch(requestStoreProvider);

    // Theme Colors
    final Color bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final Color primaryIndigo = const Color(0xFF6366F1);
    final List<Map<String, dynamic>> filteredRequests = store.requests.where((req) {
      final String s = (req['status'] ?? "").toString().toUpperCase();
      final int rs = req['rawStatus'] ?? 0;
      final bool isStarted = s == 'STARTED' || s == 'ONGOING' || rs == 7;
      return !isStarted;
    }).toList();

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          _buildBackgroundDecor(isDark, size),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- HEADER ---
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    20,
                    horizontalPadding,
                    10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              "Requests",
                              style: TextStyle(
                                fontSize: size.width > 400 ? 32 : 28,
                                fontWeight: FontWeight.w900,
                                color: titleColor,
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                          _buildQuickStatBadge(
                            "${filteredRequests.length} Total",
                            primaryIndigo,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Manage your transport requests",
                        style: TextStyle(
                          color: subColor,
                          fontSize: size.width > 400 ? 15 : 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // --- CONTENT ---
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => store.fetchRequests(isRefresh: true),
                    child: _buildMainContent(
                      store,
                      isDark,
                      primaryIndigo,
                      horizontalPadding,
                      titleColor,
                      size,
                      filteredRequests,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // --- FAB IN BOTTOM RIGHT ---
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 90, right: 8),
        child: FloatingActionButton.extended(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const NewRequestScreen(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return SlideTransition(
                        position: animation.drive(
                          Tween(
                            begin: const Offset(0, 1),
                            end: Offset.zero,
                          ).chain(CurveTween(curve: Curves.easeOutQuart)),
                        ),
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
              ),
            );
            
            if (result == true) {
              if (!mounted) return;
              ref.read(requestStoreProvider).fetchRequests();
            }
          },
          elevation: 6,
          backgroundColor: primaryIndigo,
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          label: const Text(
            "NEW",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              fontSize: 13,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(
    RequestStore store,
    bool isDark,
    Color primaryIndigo,
    double horizontalPadding,
    Color titleColor,
    Size size,
    List<Map<String, dynamic>> filteredRequests,
  ) {
    if (store.isLoading && store.requests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (store.errorMessage != null && store.requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              store.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            TextButton(
              onPressed: () => store.fetchRequests(),
              child: const Text("Retry"),
            ),
          ],
        ),
      );
    }


    if (filteredRequests.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          SizedBox(height: size.height * 0.2),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.notes_rounded,
                  size: 64,
                  color: Colors.grey.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  "No requests found",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 20,
      ),
      itemCount: filteredRequests.length + (store.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == filteredRequests.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final req = filteredRequests[index];
        return RequestCard(
          req: req,
          isDark: isDark,
          accentColor: primaryIndigo,
        );
      },
    );
  }

  // UI Helpers (Titles, Badges, Background)
  Widget _buildQuickStatBadge(String text, Color blue) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: blue,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildBackgroundDecor(bool isDark, Size size) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -size.height * 0.08,
            right: -size.width * 0.15,
            child: CircleAvatar(
              radius: size.width * 0.35,
              backgroundColor: const Color(
                0xFF6366F1,
              ).withValues(alpha: isDark ? 0.06 : 0.04),
            ),
          ),
          Positioned(
            bottom: size.height * 0.1,
            left: -size.width * 0.1,
            child: CircleAvatar(
              radius: size.width * 0.2,
              backgroundColor: const Color(
                0xFFA855F7,
              ).withValues(alpha: isDark ? 0.04 : 0.02),
            ),
          ),
        ],
      ),
    );
  }
}
