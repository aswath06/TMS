import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


class FacultyBusScreen extends ConsumerStatefulWidget {
  const FacultyBusScreen({super.key});

  @override
  ConsumerState<FacultyBusScreen> createState() => _FacultyBusScreenState();
}

class _FacultyBusScreenState extends ConsumerState<FacultyBusScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color scaffoldBg = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAnimatedHeader(),
            _buildEmptyState(),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 40.0, 24.0, 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Daily Bus Routes",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF6366F1),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "View daily campus bus schedules and details.",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_bus_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              "No daily bus routes are available",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FadeInWidget extends StatelessWidget {
  final Widget child;
  const FadeInWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
