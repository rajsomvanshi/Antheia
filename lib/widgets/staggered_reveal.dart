import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StaggeredReveal extends StatefulWidget {
  final int index;
  final Widget child;
  final int staggerMs;
  final double yOffset;

  const StaggeredReveal({
    super.key,
    required this.index,
    required this.child,
    this.staggerMs = 40,
    this.yOffset = 6.0,
  });

  @override
  State<StaggeredReveal> createState() => _StaggeredRevealState();
}

class _StaggeredRevealState extends State<StaggeredReveal> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(begin: Offset(0, widget.yOffset), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _startAnimation();
  }

  void _startAnimation() async {
    final scale = AnimationScale.of(context).durationScale;
    if (scale == 0.0) {
      if (mounted) {
        setState(() {
          _started = true;
        });
      }
      return;
    }

    final delay = Duration(milliseconds: (widget.index * widget.staggerMs * scale).round());
    await Future.delayed(delay);
    if (mounted) {
      setState(() {
        _started = true;
      });
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = AnimationScale.of(context).durationScale;
    if (scale == 0.0) {
      return widget.child;
    }

    if (!_started) {
      return Opacity(
        opacity: 0.0,
        child: Transform.translate(
          offset: Offset(0, widget.yOffset),
          child: widget.child,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: _slide.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
