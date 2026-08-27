import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_theme.dart';

/// A lightweight, reusable coach/tooltip overlay for first-time guidance per screen.
class CoachStep {
  final GlobalKey targetKey;
  final String title;
  final String body;

  CoachStep({
    required this.targetKey,
    required this.title,
    required this.body,
  });
}

class Coach {
  /// Show coach marks for a screen.
  /// - storageKey: unique key per screen for persistence.
  /// - force: when true, ignore stored flag (used by Help/ ? button).
  static Future<void> show(
    BuildContext context, {
    required String storageKey,
    required List<CoachStep> steps,
    bool force = false,
  }) async {
    if (steps.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    if (!context.mounted) return;
    final seen = prefs.getBool(storageKey) ?? false;
    if (!force && seen) return;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null || !context.mounted) return;

    int index = 0;
    OverlayEntry? entry;

    void complete() {
      entry?.remove();
      entry = null;
      prefs.setBool(storageKey, true);
    }

    /// Safe when the target widget was disposed (user navigated away) or not laid out yet.
    Rect? targetRect(GlobalKey key) {
      final ctx = key.currentContext;
      if (ctx == null || !ctx.mounted) return null;
      try {
        final ro = ctx.findRenderObject();
        if (ro is! RenderBox || !ro.hasSize) return null;
        final pos = ro.localToGlobal(Offset.zero);
        return Rect.fromLTWH(pos.dx, pos.dy, ro.size.width, ro.size.height);
      } catch (_) {
        return null;
      }
    }

    entry = OverlayEntry(
      builder: (overlayContext) {
        final step = steps[index];
        final rect = targetRect(step.targetKey);
        final topInset = MediaQuery.of(overlayContext).padding.top;

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () {},
                child: Container(color: Colors.black.withValues(alpha: 0.45)),
              ),
            ),
            if (rect != null)
              Positioned(
                left: rect.left - 8,
                top: (rect.top - 36).clamp(0.0, double.infinity),
                child: IgnorePointer(
                  child: Container(
                    width: rect.width + 16,
                    height: rect.height + 26,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 2),
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: topInset + 8,
              right: 12,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: complete,
              ),
            ),
            Positioned.fill(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Spacer(),
                      LayoutBuilder(
                        builder: (layoutContext, constraints) {
                          final cardWidth =
                              constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0;
                          return SizedBox(
                            width: cardWidth,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 600),
                              child: Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 6,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        step.title,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        step.body,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          TextButton(
                                            onPressed: complete,
                                            child: const Text('Skip'),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.primary,
                                              minimumSize: const Size(96, 44),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                            onPressed: () {
                                              if (index == steps.length - 1) {
                                                complete();
                                              } else {
                                                index++;
                                                entry?.markNeedsBuild();
                                              }
                                            },
                                            child: Text(
                                              index == steps.length - 1 ? 'Got it' : 'Next',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted || entry == null) return;
      overlay.insert(entry!);
    });
  }
}
