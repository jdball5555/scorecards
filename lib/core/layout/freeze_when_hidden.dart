import 'package:flutter/material.dart';

/// Keeps a page that's out of sight (a tab you're not on, or a page covered
/// by another page) from redoing its layout while the screen size changes,
/// e.g. on every frame of the website sidebar folding. It keeps the last
/// size it had while visible and catches up once it's shown again.
///
/// The widget tree is the same whether hidden or not, so nothing inside
/// loses its state when it switches.
class FreezeWhenHidden extends StatefulWidget {
  final bool hidden;
  final Widget child;

  const FreezeWhenHidden({
    super.key,
    required this.hidden,
    required this.child,
  });

  @override
  State<FreezeWhenHidden> createState() => _FreezeWhenHiddenState();
}

class _FreezeWhenHiddenState extends State<FreezeWhenHidden> {
  MediaQueryData? _kept;

  @override
  Widget build(BuildContext context) {
    final live = MediaQuery.of(context);
    if (!widget.hidden || _kept == null) _kept = live;
    final data = widget.hidden ? _kept! : live;
    final size = data.size;
    return OverflowBox(
      // Hidden: lay out at the kept size, so a changing window doesn't
      // re-lay out the page. Visible: the space it's given, as usual.
      alignment: Alignment.topLeft,
      minWidth: widget.hidden ? size.width : null,
      maxWidth: widget.hidden ? size.width : null,
      minHeight: widget.hidden ? size.height : null,
      maxHeight: widget.hidden ? size.height : null,
      // Same data as last frame -> nothing below rebuilds.
      child: MediaQuery(data: data, child: widget.child),
    );
  }
}
