import 'package:flutter/material.dart';

import '../layout/responsive.dart';

/// Shows [builder] as a bottom sheet on phones and as a centred dialog on
/// wide screens, where a sheet stretched across a desktop window looks lost.
///
/// Content can call [AdaptiveModal.isDialog] to drop sheet-only chrome such
/// as drag handles or a [DraggableScrollableSheet].
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool showDragHandle = false,
  Color? backgroundColor,
  double dialogMaxWidth = 560,
}) {
  if (!Breakpoints.hasTopNav(context)) {
    return showModalBottomSheet<T>(
      context: context,
      // Tabs have their own navigators; the sheet must cover the bottom bar.
      useRootNavigator: true,
      isScrollControlled: isScrollControlled,
      showDragHandle: showDragHandle,
      backgroundColor: backgroundColor,
      builder: builder,
    );
  }

  return showDialog<T>(
    context: context,
    builder: (dialogContext) {
      final maxHeight = MediaQuery.sizeOf(dialogContext).height * 0.85;
      return Dialog(
        insetPadding: const EdgeInsets.all(24),
        clipBehavior: Clip.antiAlias,
        backgroundColor: backgroundColor == Colors.transparent
            ? Colors.transparent
            : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: dialogMaxWidth,
            maxHeight: maxHeight,
          ),
          child: AdaptiveModal(
            child: Padding(
              padding: EdgeInsets.only(top: showDragHandle ? 12 : 0),
              child: Builder(builder: builder),
            ),
          ),
        ),
      );
    },
  );
}

/// Marks content shown by [showAdaptiveSheet] in its dialog form.
class AdaptiveModal extends InheritedWidget {
  const AdaptiveModal({super.key, required super.child});

  /// Whether [context] sits inside the dialog form of [showAdaptiveSheet].
  static bool isDialog(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdaptiveModal>() != null;

  @override
  bool updateShouldNotify(AdaptiveModal oldWidget) => false;
}
