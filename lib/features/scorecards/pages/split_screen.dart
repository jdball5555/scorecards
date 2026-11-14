import 'package:flutter/material.dart';

class SplitScreen extends StatefulWidget {
  final Widget mainPane;
  final Widget secondaryPane;
  final bool swapPanes;

  const SplitScreen({
    super.key,
    required this.mainPane,
    required this.secondaryPane,
    this.swapPanes = false,
  });

  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> {
  late double _splitRatio;

  @override
  void initState() {
    super.initState();
    _splitRatio = widget.swapPanes ? 0.71 : 0.29;
  }

  @override
  void didUpdateWidget(SplitScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Automatically invert the ratio so the big side stays the big side when swapping!
    if (widget.swapPanes != oldWidget.swapPanes) {
      _splitRatio = 1.0 - _splitRatio;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isHorizontal =
            MediaQuery.of(context).orientation == Orientation.landscape;

        // Dynamically calculate the clamp constraints based on pane positions.
        // Metrics minimum = 0.20, Scorecard minimum = 0.35.
        double minRatio = widget.swapPanes ? 0.35 : 0.20;
        double maxRatio = widget.swapPanes ? 0.80 : 0.65;

        // Resolve which widget goes where based on swapPanes
        Widget leftPane = widget.swapPanes
            ? widget.mainPane
            : widget.secondaryPane;
        Widget rightPane = widget.swapPanes
            ? widget.secondaryPane
            : widget.mainPane;

        Widget topPane = widget.swapPanes
            ? widget.secondaryPane
            : widget.mainPane;
        Widget bottomPane = widget.swapPanes
            ? widget.mainPane
            : widget.secondaryPane;

        if (isHorizontal) {
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left pane — clipped so nothing bleeds across the divider
                SizedBox(
                  width: constraints.maxWidth * _splitRatio,
                  child: ClipRect(child: leftPane),
                ),
                // Draggable divider
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanUpdate: (details) {
                    if (constraints.maxWidth > 0) {
                      setState(() {
                        _splitRatio += details.delta.dx / constraints.maxWidth;
                        _splitRatio = _splitRatio.clamp(minRatio, maxRatio);
                      });
                    }
                  },
                  child: Container(
                    width: 12,
                    color: Colors.black87,
                    child: const Center(
                      child: Icon(
                        Icons.drag_indicator,
                        color: Colors.white54,
                        size: 16,
                      ),
                    ),
                  ),
                ),
                // Right pane — clipped so nothing bleeds across the divider
                Expanded(child: ClipRect(child: rightPane)),
              ],
            ),
          );
        } else {
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top pane — clipped so nothing bleeds through the divider
                SizedBox(
                  height: constraints.maxHeight * _splitRatio,
                  child: ClipRect(child: topPane),
                ),
                // Draggable divider
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanUpdate: (details) {
                    if (constraints.maxHeight > 0) {
                      setState(() {
                        _splitRatio += details.delta.dy / constraints.maxHeight;
                        _splitRatio = _splitRatio.clamp(minRatio, maxRatio);
                      });
                    }
                  },
                  child: Container(
                    height: 12,
                    color: Colors.black87,
                    child: const Center(
                      child: Icon(
                        Icons.drag_handle,
                        color: Colors.white54,
                        size: 16,
                      ),
                    ),
                  ),
                ),
                // Bottom pane — top system padding removed (it starts below the divider,
                // not at the top of the screen) and clipped to its own bounds
                Expanded(
                  child: ClipRect(
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      child: bottomPane,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }
}
