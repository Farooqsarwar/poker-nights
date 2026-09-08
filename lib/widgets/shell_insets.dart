import 'package:flutter/widgets.dart';

/// How much chrome sits to the left of the page content on this route.
///
/// Dialogs are pushed onto the ROOT navigator, so they are laid out against
/// the whole window and centre themselves in it. On a desktop shell route the
/// sidebar occupies the first 265 logical pixels, so a window-centred dialog
/// lands about 130px to the left of the content it belongs to — enough to read
/// as "the popup is off to the left", which is exactly how it was reported.
///
/// Centring on the window is not wrong in general; it is wrong when a
/// persistent side nav means the window centre is not the visual centre. The
/// shell publishes its own inset here and [showAppModal] reads it from the
/// CALLING context, which is inside the shell even though the dialog is not.
/// Routes with no shell — the guest flow, TV mode, sign-in — report nothing
/// and their dialogs stay centred on the window, which is correct for them.
class ShellInsets extends InheritedWidget {
  const ShellInsets({super.key, required this.left, required super.child});

  /// Width of the chrome to the left of the content area, in logical pixels.
  final double left;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellInsets>()?.left ?? 0;

  /// Non-subscribing read, for one-off use such as building a dialog's
  /// inset padding at the moment it is shown.
  static double read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ShellInsets>()?.left ?? 0;

  @override
  bool updateShouldNotify(ShellInsets oldWidget) => oldWidget.left != left;
}
