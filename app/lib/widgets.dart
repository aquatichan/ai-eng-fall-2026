import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keeps a screen's data fresh: calls [reload] every [refreshEvery] while the
/// screen is on top and the app is in the foreground, and right away when the
/// app comes back to the foreground.
mixin AutoRefresh<T extends StatefulWidget> on State<T> {
  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  bool _autoReloading = false;

  Duration get refreshEvery => const Duration(seconds: 10);

  Future<void> reload();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(refreshEvery, (_) {
      if (!mounted) return;
      final foreground = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      final onTop = ModalRoute.of(context)?.isCurrent ?? true;
      if (foreground && onTop) _autoReload();
    });
    _lifecycle = AppLifecycleListener(onResume: _autoReload);
  }

  /// Skips a tick while the previous reload is still out, so a slow network
  /// doesn't pile up requests or let an old response overwrite a newer one.
  Future<void> _autoReload() async {
    if (_autoReloading) return;
    _autoReloading = true;
    try {
      await reload();
    } finally {
      _autoReloading = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }
}

/// Formats join code input as "ABC-123": uppercases, drops anything that
/// isn't a letter or digit, and inserts the hyphen after the third character.
class JoinCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var raw = newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    // Backspacing over the hyphen should delete the character before it.
    if (oldValue.text.endsWith('-') && newValue.text.length < oldValue.text.length && raw.length == 3) {
      raw = raw.substring(0, 2);
    }
    if (raw.length > 6) raw = raw.substring(0, 6);
    final text = raw.length >= 3 ? '${raw.substring(0, 3)}-${raw.substring(3)}' : raw;
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// Circle with the name's first letter, tinted by a color derived from the
/// name so each person keeps the same color everywhere.
class NameAvatar extends StatelessWidget {
  const NameAvatar(this.name, {super.key, this.radius = 20, this.square = false});

  final String name;
  final double radius;

  /// Rounded square instead of a circle, used for groups.
  final bool square;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hue = name.codeUnits.fold(0, (h, c) => (h * 31 + c) % 360).toDouble();
    final bg = HSLColor.fromAHSL(1, hue, 0.45, dark ? 0.28 : 0.86).toColor();
    final fg = HSLColor.fromAHSL(1, hue, 0.5, dark ? 0.88 : 0.28).toColor();
    final letter = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: square ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: square ? BorderRadius.circular(radius * 0.6) : null,
      ),
      child: Text(
        letter,
        style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: radius * 0.85),
      ),
    );
  }
}

/// Centered icon, title, message and optional buttons. Scrollable so it
/// still works inside a RefreshIndicator.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.actions = const []});

  final IconData icon;
  final String title;
  final String? message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer, shape: BoxShape.circle),
                      child: Icon(icon, size: 40, color: theme.colorScheme.onSecondaryContainer),
                    ),
                    const SizedBox(height: 20),
                    Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
                    if (message != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        message!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      for (final (i, a) in actions.indexed) ...[
                        if (i > 0) const SizedBox(height: 12),
                        SizedBox(width: double.infinity, child: a),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small rounded label, e.g. "You" or "Owner".
class Tag extends StatelessWidget {
  const Tag(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onPrimaryContainer),
      ),
    );
  }
}

/// Small uppercase heading above a group of content.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, letterSpacing: 1),
    );
  }
}
