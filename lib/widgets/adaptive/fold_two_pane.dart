import 'package:flutter/material.dart';
import 'fold_info.dart';

/// Dvoupanelové rozložení pro rozevřený fold telefon: pevně široký levý
/// panel (typicky seznam), oddělovač v místě závěsu a pravý panel, který
/// vyplní zbytek šířky (typicky detail). Čistě layout, bez byznys logiky.
class FoldTwoPane extends StatelessWidget {
  final Widget primary;
  final Widget secondary;
  final double primaryWidth;

  const FoldTwoPane({
    super.key,
    required this.primary,
    required this.secondary,
    this.primaryWidth = kFoldPrimaryPaneWidth,
  });

  @override
  Widget build(BuildContext context) {
    final hinge = FoldInfo.of(context).hingeBounds;
    final gutterWidth = hinge?.width ?? 24.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: primaryWidth, child: primary),
        SizedBox(
          width: gutterWidth,
          child: const Center(child: VerticalDivider(width: 1)),
        ),
        Expanded(child: secondary),
      ],
    );
  }
}

const double kFoldPrimaryPaneWidth = 420.0;
