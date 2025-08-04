import 'dart:ui';
import 'package:flutter/material.dart';

class AnimatedDiffuseGradientBackground extends StatefulWidget {
  final Widget? child;
  final List<List<Color>> colorSets;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;
  final double blurAmount;
  final double opacity;
  final Duration duration;

  const AnimatedDiffuseGradientBackground({
    super.key,
    this.child,
    this.colorSets = const [
      [Color(0xFF6E45E2), Color(0xFF89D4CF)],
      [Color(0xFFB06AB3), Color(0xFF4568DC)],
      [Color(0xFFFF7E5F), Color(0xFFFEB47B)],
    ],
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
    this.blurAmount = 10.0,
    this.opacity = 1.0,
    this.duration = const Duration(seconds: 8),
  });

  @override
  State<AnimatedDiffuseGradientBackground> createState() =>
      _AnimatedDiffuseGradientBackgroundState();
}

class _AnimatedDiffuseGradientBackgroundState
    extends State<AnimatedDiffuseGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _currentColorSet = 0;
  int _nextColorSet = 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_controller.status == AnimationStatus.completed) {
          _currentColorSet = _nextColorSet;
          _nextColorSet = (_nextColorSet + 1) % widget.colorSets.length;
          _controller.reset();
          _controller.forward();
        }

        return Stack(
          children: [
            // 背景渐变层
            AnimatedContainer(
              duration: widget.duration,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.colorSets[_currentColorSet],
                  begin: widget.begin,
                  end: widget.end,
                  stops: const [0.1, 0.9],
                  tileMode: TileMode.mirror,
                ),
              ),
            ),
            // 模糊效果层
            BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: widget.blurAmount,
                sigmaY: widget.blurAmount,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.0),
                ),
              ),
            ),
            // 内容层
            Opacity(
              opacity: widget.opacity,
              child: widget.child,
            ),
          ],
        );
      },
    );
  }
}