import 'dart:async';
import 'package:flutter/material.dart';

/// Un widget que muestra texto en 1 línea. Si el texto cabe en el espacio
/// disponible, se muestra estático. Si no cabe, se desplaza lateralmente
/// de un extremo al otro de forma suave (efecto marquesina / ticker).
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration pauseDuration;
  final double pixelsPerSecond;

  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.pauseDuration = const Duration(seconds: 2),
    this.pixelsPerSecond = 32.0,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  late final ScrollController _scrollController;
  bool _isDisposed = false;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startLoopIfNeeded());
  }

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _startLoopIfNeeded());
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startLoopIfNeeded() async {
    if (_isDisposed || !mounted || !_scrollController.hasClients || _isScrolling) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    _isScrolling = true;
    while (!_isDisposed && mounted && _scrollController.hasClients) {
      await Future.delayed(widget.pauseDuration);
      if (_isDisposed || !mounted || !_scrollController.hasClients) break;

      final currentMax = _scrollController.position.maxScrollExtent;
      if (currentMax <= 0) break;

      final durationMs = ((currentMax / widget.pixelsPerSecond) * 1000).toInt().clamp(500, 15000);
      final scrollDuration = Duration(milliseconds: durationMs);

      // Scroll to end
      try {
        await _scrollController.animateTo(
          currentMax,
          duration: scrollDuration,
          curve: Curves.easeInOut,
        );
      } catch (_) {
        break;
      }
      if (_isDisposed || !mounted || !_scrollController.hasClients) break;

      await Future.delayed(widget.pauseDuration);
      if (_isDisposed || !mounted || !_scrollController.hasClients) break;

      // Scroll back
      try {
        await _scrollController.animateTo(
          0,
          duration: scrollDuration,
          curve: Curves.easeInOut,
        );
      } catch (_) {
        break;
      }
      if (_isDisposed || !mounted || !_scrollController.hasClients) break;
    }
    _isScrolling = false;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = widget.style ?? DefaultTextStyle.of(context).style;

    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: effectiveStyle),
          maxLines: 1,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: double.infinity);

        final textWidth = textPainter.width;
        final availableWidth = constraints.maxWidth;

        if (textWidth <= availableWidth) {
          return Text(
            widget.text,
            style: effectiveStyle,
            maxLines: 1,
          );
        }

        // Trigger loop if not running
        WidgetsBinding.instance.addPostFrameCallback((_) => _startLoopIfNeeded());

        return ClipRect(
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Text(
              widget.text,
              style: effectiveStyle,
              maxLines: 1,
              softWrap: false,
            ),
          ),
        );
      },
    );
  }
}
