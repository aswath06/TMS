import 'package:flutter/material.dart';

class AppBranding extends StatelessWidget {
  const AppBranding({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 60),
        Hero(
          tag: 'logo',
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withOpacity(0.1),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Image.asset(
              'assets/TripZo.png',
              width: 80,
              height: 80,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 24),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 8,
            ),
            children: [
              TextSpan(
                text: "Trip",
                style: TextStyle(color: Color(0xFF4F46E5)),
              ),
              TextSpan(
                text: "Zo",
                style: TextStyle(color: Colors.black),
              ),
            ],
          ),
        ),
        const Text(
          "TRANSPORT MANAGEMENT SYSTEM",
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

class BackgroundDecorator extends StatelessWidget {
  const BackgroundDecorator({super.key});

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    return Stack(
      children: [
        Positioned(
          top: -size.height * 0.05,
          right: -size.width * 0.1,
          child: _circle(
            size.width * 0.6,
            const Color(0xFF6366F1).withOpacity(0.04),
          ),
        ),
        Positioned(
          bottom: -size.height * 0.05,
          left: -size.width * 0.1,
          child: _circle(
            size.width * 0.4,
            const Color(0xFF4F46E5).withOpacity(0.03),
          ),
        ),
      ],
    );
  }

  Widget _circle(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}
