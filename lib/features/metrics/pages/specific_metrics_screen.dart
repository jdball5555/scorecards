import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/layout/responsive.dart';
import '../../../core/shared_widgets/gradient_background.dart';
import 'package:scorecards_app/core/shared_widgets/top_bar_background.dart';

class MetricDataPoint {
  final DateTime date;
  final double value;
  final String? subtitle;

  MetricDataPoint({required this.date, required this.value, this.subtitle});
}

const _kAccent = Color(0xFF00A2FF);
const _kGood = Color(0xFF54A27E);
const _kBad = Color(0xFFD26A74);
const _kCard = Color(0x1AFFFFFF);
const _kCardEdge = Color(0x14FFFFFF);
const _kMuted = Color(0x8CFFFFFF);
const _kFaint = Color(0x4DFFFFFF);

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// One metric for one player over time (e.g. Yahtzee average score, Spades
/// win rate): headline numbers, a chart of every game with a rolling
/// average, how the scores spread out, and the games themselves.
class SpecificMetricScreen extends StatefulWidget {
  final String title;
  final String playerName;
  final List<MetricDataPoint> dataPoints;
  final String unit;
  final bool isHigherBetter;
  final String scopeDisplay;
  final String gameTypeDisplay;
  final String playerDisplay;

  /// Kept for the callers; scores and the average now share one chart.
  final bool showIndividualScoresToggle;

  const SpecificMetricScreen({
    super.key,
    required this.title,
    required this.playerName,
    required this.dataPoints,
    this.unit = "",
    this.isHigherBetter = true,
    required this.scopeDisplay,
    required this.gameTypeDisplay,
    required this.playerDisplay,
    this.showIndividualScoresToggle = true,
  });

  @override
  State<SpecificMetricScreen> createState() => _SpecificMetricScreenState();
}

/// A range the user can pick: the last N games, or the last stretch of time.
class _Range {
  final String label;
  final int? games;
  final Duration? span;
  const _Range(this.label, {this.games, this.span});
  bool get isAll => games == null && span == null;
}

class _SpecificMetricScreenState extends State<SpecificMetricScreen> {
  late final List<MetricDataPoint> _all; // oldest first
  late final List<_Range> _ranges;
  late _Range _range;

  /// Win/loss style data (every value 0 or 100): shown as a win rate.
  late final bool _isWinLoss;

  // The games list starts closed and opens a page at a time.
  static const _gamesPage = 10;
  bool _gamesOpen = false;
  int _gamesShown = _gamesPage;

  @override
  void initState() {
    super.initState();
    _all = List.of(widget.dataPoints)..sort((a, b) => a.date.compareTo(b.date));
    _isWinLoss =
        _all.isNotEmpty && _all.every((d) => d.value == 0 || d.value == 100);

    final n = _all.length;
    final spanDays = n < 2
        ? 0
        : _all.last.date.difference(_all.first.date).inDays;
    _ranges = [
      for (final g in const [10, 25, 50, 100])
        if (n > g) _Range('Last $g', games: g),
      for (final (label, days) in const [
        ('1W', 7),
        ('1M', 30),
        ('3M', 91),
        ('6M', 182),
        ('1Y', 365),
      ])
        if (spanDays > days) _Range(label, span: Duration(days: days)),
      const _Range('All'),
    ];
    _range = _ranges.last;
  }

  /// Index into [_all] where [range] starts.
  int _startOf(_Range range) {
    if (range.games != null) return math.max(0, _all.length - range.games!);
    if (range.span != null) {
      final cutoff = DateTime.now().subtract(range.span!);
      final i = _all.indexWhere((d) => d.date.isAfter(cutoff));
      return i == -1 ? _all.length : i;
    }
    return 0;
  }

  String _fmt(double v) {
    if (_isWinLoss) return '${v.toStringAsFixed(0)}%';
    final s = v == v.roundToDouble()
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(1);
    return widget.unit.isEmpty ? s : '$s ${widget.unit}';
  }

  String _date(DateTime d, {bool year = true}) => year
      ? '${_months[d.month - 1]} ${d.day}, ${d.year}'
      : '${_months[d.month - 1]} ${d.day}';

  double _avg(Iterable<MetricDataPoint> xs) =>
      xs.isEmpty ? 0 : xs.fold<double>(0, (s, d) => s + d.value) / xs.length;

  @override
  Widget build(BuildContext context) {
    final start = _startOf(_range);
    final shown = _all.sublist(start);
    final avg = _avg(shown);

    // Compared with the same number of games right before this range.
    double? previousAvg;
    if (!_range.isAll && start > 0 && shown.isNotEmpty) {
      final from = math.max(0, start - shown.length);
      previousAvg = _avg(_all.sublist(from, start));
    }

    final side = readableSide(context, maxWidth: 920);
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 24,
              letterSpacing: 1.2,
            ),
          ),
          centerTitle: false,
          flexibleSpace: const TopBarBackground(),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(40),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                "${widget.scopeDisplay}  •  ${widget.gameTypeDisplay}  •  ${widget.playerDisplay}",
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
        body: _all.isEmpty
            ? const Center(
                child: Text(
                  "No games recorded yet.",
                  style: TextStyle(color: _kMuted),
                ),
              )
            : ListView(
                padding: EdgeInsets.fromLTRB(
                  side,
                  MediaQuery.paddingOf(context).top + kToolbarHeight + 40 + 16,
                  side,
                  40,
                ),
                children: [
                  _RangePicker(
                    ranges: _ranges,
                    selected: _range,
                    onSelected: (r) => setState(() {
                      _range = r;
                      _gamesShown = _gamesPage;
                    }),
                  ),
                  const SizedBox(height: 16),
                  if (shown.isEmpty)
                    const _Card(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            "No games in this range.",
                            style: TextStyle(color: _kMuted),
                          ),
                        ),
                      ),
                    )
                  else ...[
                    _buildStats(shown, avg, previousAvg),
                    const SizedBox(height: 16),
                    _Card(
                      title: _isWinLoss ? 'Results by game' : 'Score by game',
                      trailing: _Legend(
                        windowLabel: 'Last ${_window(shown.length)} avg',
                        averageLabel: 'Avg ${_fmt(avg)}',
                        isWinLoss: _isWinLoss,
                      ),
                      child: _TrendChart(
                        points: shown,
                        average: avg,
                        window: _window(shown.length),
                        isWinLoss: _isWinLoss,
                        isHigherBetter: widget.isHigherBetter,
                        format: _fmt,
                        date: _date,
                      ),
                    ),
                    if (!_isWinLoss && shown.length >= 5) ...[
                      const SizedBox(height: 16),
                      _Card(
                        title: 'How your scores spread',
                        child: _SpreadChart(
                          points: shown,
                          average: avg,
                          averageLabel: _fmt(avg),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildGames(shown, avg),
                  ],
                ],
              ),
      ),
    );
  }

  /// Rolling-average window: smooths noise without hiding the trend.
  int _window(int n) => n <= 12 ? 3 : (n <= 40 ? 5 : 10);

  Widget _buildStats(
    List<MetricDataPoint> shown,
    double avg,
    double? previousAvg,
  ) {
    Widget? trend;
    if (previousAvg != null) {
      final diff = avg - previousAvg;
      final good = widget.isHigherBetter ? diff >= 0 : diff <= 0;
      final color = diff == 0 ? _kMuted : (good ? _kGood : _kBad);
      final what = _range.games != null
          ? 'the ${shown.length} games before'
          : 'the ${_range.label} before';
      trend = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            diff > 0
                ? Icons.trending_up
                : (diff < 0 ? Icons.trending_down : Icons.trending_flat),
            size: 16,
            color: color,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              diff == 0
                  ? 'Same as $what'
                  : '${diff > 0 ? '+' : '−'}${_fmt(diff.abs())} vs $what',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }

    final List<_Stat> stats;
    if (_isWinLoss) {
      final wins = shown.where((d) => d.value == 100).length;
      stats = [
        _Stat('Win rate', _fmt(avg), big: true, footer: trend),
        _Stat('Wins', '$wins'),
        _Stat('Losses', '${shown.length - wins}'),
        _Stat('Games', '${shown.length}'),
      ];
    } else {
      final best = shown.reduce(
        (a, b) =>
            (widget.isHigherBetter ? b.value > a.value : b.value < a.value)
            ? b
            : a,
      );
      final worst = shown.reduce(
        (a, b) =>
            (widget.isHigherBetter ? b.value < a.value : b.value > a.value)
            ? b
            : a,
      );
      stats = [
        _Stat('Average', _fmt(avg), big: true, footer: trend),
        _Stat('Best', _fmt(best.value), sub: _date(best.date)),
        _Stat(
          widget.isHigherBetter ? 'Lowest' : 'Highest',
          _fmt(worst.value),
          sub: _date(worst.date),
        ),
        _Stat('Games', '${shown.length}'),
      ];
    }

    return LayoutBuilder(
      builder: (context, box) {
        // Four across when there's room; otherwise the average on its own
        // row and the rest beneath it.
        if (box.maxWidth >= 640) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < stats.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(flex: i == 0 ? 2 : 1, child: stats[i]),
                ],
              ],
            ),
          );
        }
        return Column(
          children: [
            SizedBox(width: double.infinity, child: stats.first),
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 1; i < stats.length; i++) ...[
                    if (i > 1) const SizedBox(width: 12),
                    Expanded(child: stats[i]),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGames(List<MetricDataPoint> shown, double avg) {
    final newestFirst = shown.reversed.toList();
    MetricDataPoint? best;
    if (!_isWinLoss && shown.length > 1) {
      best = shown.reduce(
        (a, b) =>
            (widget.isHigherBetter ? b.value > a.value : b.value < a.value)
            ? b
            : a,
      );
    }
    final visible = math.min(_gamesShown, newestFirst.length);
    final left = newestFirst.length - visible;

    Widget row(int i) {
      final p = newestFirst[i];
      final diff = p.value - avg;
      return _GameRow(
        point: p,
        date: _date(p.date),
        value: _isWinLoss ? (p.value == 100 ? 'Win' : 'Loss') : _fmt(p.value),
        delta: _isWinLoss ? null : diff,
        deltaText: _isWinLoss
            ? null
            : diff.abs() < 0.05
            ? 'avg'
            : '${diff > 0 ? '+' : '−'}${diff.abs().toStringAsFixed(1)}',
        isHigherBetter: widget.isHigherBetter,
        isWin: _isWinLoss ? p.value == 100 : null,
        isBest: identical(p, best),
        last: i == visible - 1 && left == 0,
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _kCard.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kCardEdge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: tap to open or close the list.
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() {
                _gamesOpen = !_gamesOpen;
                _gamesShown = _gamesPage;
              }),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(
                  children: [
                    const Text(
                      'GAMES',
                      style: TextStyle(
                        color: _kMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${newestFirst.length}',
                        style: const TextStyle(
                          color: _kMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _gamesOpen ? 'Hide' : 'Show',
                      style: const TextStyle(
                        color: _kAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    AnimatedRotation(
                      turns: _gamesOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.keyboard_arrow_down,
                        color: _kAccent,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !_gamesOpen
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                      for (int i = 0; i < visible; i++) row(i),
                      if (left > 0)
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: _kAccent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: const RoundedRectangleBorder(),
                          ),
                          onPressed: () =>
                              setState(() => _gamesShown += _gamesPage),
                          child: Text(
                            'Load ${math.min(_gamesPage, left)} more  ·  $left left',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

class _Card extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding = const EdgeInsets.all(16);

  const _Card({this.title, this.trailing, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _kCard.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kCardEdge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                padding.left == 0 ? 16 : 0,
                0,
                padding.right == 0 ? 16 : 0,
                12,
              ),
              child: LayoutBuilder(
                builder: (context, box) {
                  final heading = Text(
                    title!.toUpperCase(),
                    style: const TextStyle(
                      color: _kMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.3,
                    ),
                  );
                  if (trailing == null) return heading;
                  // Narrow: the legend goes under the title. Wide: beside it.
                  if (box.maxWidth < 520) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [heading, const SizedBox(height: 8), trailing!],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      heading,
                      const SizedBox(width: 12),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topRight,
                          child: trailing,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Widget? footer;
  final bool big;

  const _Stat(
    this.label,
    this.value, {
    this.sub,
    this.footer,
    this.big = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: big
            ? _kAccent.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: big ? _kAccent.withValues(alpha: 0.35) : _kCardEdge,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _kMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: big ? 34 : 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(
              sub!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _kFaint, fontSize: 11),
            ),
          ],
          if (footer != null) ...[const SizedBox(height: 6), footer!],
        ],
      ),
    );
  }
}

class _RangePicker extends StatelessWidget {
  final List<_Range> ranges;
  final _Range selected;
  final ValueChanged<_Range> onSelected;

  const _RangePicker({
    required this.ranges,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kCardEdge),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in ranges)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Material(
                  color: identical(r, selected)
                      ? _kAccent.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onSelected(r),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Text(
                        r.label,
                        style: TextStyle(
                          color: identical(r, selected) ? _kAccent : _kMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final String windowLabel;
  final String averageLabel;
  final bool isWinLoss;
  const _Legend({
    required this.windowLabel,
    required this.averageLabel,
    required this.isWinLoss,
  });

  @override
  Widget build(BuildContext context) {
    Widget item(Widget mark, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(color: _kMuted, fontSize: 11)),
      ],
    );
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      alignment: WrapAlignment.end,
      children: [
        item(
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isWinLoss ? _kGood : Colors.white70,
              shape: BoxShape.circle,
            ),
          ),
          isWinLoss ? 'Game' : 'Game score',
        ),
        item(Container(width: 14, height: 3, color: _kAccent), windowLabel),
        item(
          const SizedBox(
            width: 14,
            height: 3,
            child: CustomPaint(painter: _DashPainter()),
          ),
          averageLabel,
        ),
      ],
    );
  }
}

/// Every game as a dot, a rolling average through them, and the range's
/// average as a dashed line. Tap or hover a game for its details. Like
/// Optimizer's charts, the line is brightest at the game you're on (the
/// latest one otherwise) and fades away from it.
class _TrendChart extends StatefulWidget {
  final List<MetricDataPoint> points; // oldest first
  final double average;
  final int window;
  final bool isWinLoss;
  final bool isHigherBetter;
  final String Function(double) format;
  final String Function(DateTime, {bool year}) date;

  const _TrendChart({
    required this.points,
    required this.average,
    required this.window,
    required this.isWinLoss,
    required this.isHigherBetter,
    required this.format,
    required this.date,
  });

  @override
  State<_TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<_TrendChart> {
  int? _focus;

  @override
  void didUpdateWidget(_TrendChart old) {
    super.didUpdateWidget(old);
    if (old.points.length != widget.points.length) _focus = null;
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final window = widget.window;
    final isWinLoss = widget.isWinLoss;
    final average = widget.average;
    final format = widget.format;
    final date = widget.date;
    final n = points.length;
    final rolling = <double>[];
    for (int i = 0; i < n; i++) {
      final from = math.max(0, i - window + 1);
      final slice = points.sublist(from, i + 1);
      rolling.add(slice.fold<double>(0, (s, d) => s + d.value) / slice.length);
    }

    final values = points.map((d) => d.value);
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    double minY = isWinLoss ? -8 : lo;
    double maxY = isWinLoss ? 108 : hi;
    final step = isWinLoss ? 25.0 : _niceStep((hi - lo) / 4);
    if (!isWinLoss) {
      // A little headroom so dots at the top and bottom show whole.
      final pad = math.max((hi - lo) * 0.06, step * 0.1);
      minY = ((lo - pad) / step).floorToDouble() * step;
      maxY = ((hi + pad) / step).ceilToDouble() * step;
      if (lo >= 0 && minY < 0) minY = 0;
      if (maxY <= minY) maxY = minY + step;
    }

    // Where the line is brightest: the game being looked at, else the latest.
    final f = (_focus ?? n - 1).clamp(0, n - 1);
    final fx = n == 1 ? 0.5 : (f + 0.5) / n;
    double at(double d) => (fx + d).clamp(0.0, 1.0);

    final spansYears = points.first.date.year != points.last.date.year;
    final labelEvery = math.max(1, (n / 4).ceil());
    final dotRadius = n > 60 ? 2.5 : (n > 25 ? 3.2 : 4.0);

    return SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
          // Half a game of room each side, so the end dots show whole while
          // everything stays clipped to the chart (no spilling out of the
          // card while it animates to a new range).
          minX: n == 1 ? -1 : -0.5,
          maxX: n == 1 ? 1 : n - 0.5,
          minY: minY,
          maxY: maxY,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: step,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.white.withValues(alpha: 0.07),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: step,
                getTitlesWidget: (v, meta) {
                  if (isWinLoss && (v < 0 || v > 100)) return const SizedBox();
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      isWinLoss ? '${v.toInt()}%' : _compact(v),
                      style: const TextStyle(color: _kFaint, fontSize: 11),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: 1,
                getTitlesWidget: (v, meta) {
                  final i = v.round();
                  if (v != i || i < 0 || i >= n) return const SizedBox();
                  if (i % labelEvery != 0 && i != n - 1)
                    return const SizedBox();
                  // Skip a label that would crowd the last one.
                  if (i != n - 1 && n - 1 - i < labelEvery / 2)
                    return const SizedBox();
                  final d = points[i].date;
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      spansYears
                          ? "${_months[d.month - 1]} '${d.year % 100}"
                          : date(d, year: false),
                      style: const TextStyle(color: _kFaint, fontSize: 11),
                    ),
                  );
                },
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: average,
                color: Colors.white.withValues(alpha: 0.35),
                strokeWidth: 1,
                dashArray: [4, 4],
                // Its value is in the legend above the chart.
              ),
            ],
          ),
          lineBarsData: [
            // The games (dots only).
            LineChartBarData(
              spots: [
                for (int i = 0; i < n; i++)
                  FlSpot(i.toDouble(), points[i].value),
              ],
              color: Colors.transparent,
              barWidth: 0,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, _, _) {
                  final Color c;
                  if (isWinLoss) {
                    c = spot.y == 100 ? _kGood : _kBad;
                  } else {
                    c = Colors.white.withValues(alpha: 0.7);
                  }
                  return FlDotCirclePainter(
                    radius: dotRadius,
                    color: c,
                    strokeWidth: 0,
                  );
                },
              ),
            ),
            // The rolling average.
            LineChartBarData(
              spots: [
                for (int i = 0; i < n; i++) FlSpot(i.toDouble(), rolling[i]),
              ],
              isCurved: true,
              curveSmoothness: 0.25,
              preventCurveOverShooting: true,
              barWidth: 3,
              isStrokeCapRound: true,
              // Bright where you're looking, fading away from it.
              gradient: LinearGradient(
                colors: [
                  _kAccent.withValues(alpha: 0.25),
                  _kAccent.withValues(alpha: 0.6),
                  _kAccent,
                  _kAccent.withValues(alpha: 0.6),
                  _kAccent.withValues(alpha: 0.25),
                ],
                stops: [at(-0.5), at(-0.15), fx, at(0.15), at(0.5)],
              ),
              // A glowing dot on the line at that game.
              dotData: FlDotData(
                show: true,
                checkToShowDot: (spot, _) => spot.x.round() == f,
                getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                  radius: 4.5,
                  color: Colors.white,
                  strokeWidth: 5,
                  strokeColor: _kAccent.withValues(alpha: 0.35),
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchCallback: (event, response) {
              final spots = response?.lineBarSpots;
              final next =
                  (!event.isInterestedForInteractions ||
                      spots == null ||
                      spots.isEmpty)
                  ? null
                  : spots.first.spotIndex;
              if (next != _focus) setState(() => _focus = next);
            },
            getTouchedSpotIndicator: (bar, indexes) => [
              for (final _ in indexes)
                TouchedSpotIndicatorData(
                  FlLine(
                    color: Colors.white.withValues(alpha: 0.25),
                    strokeWidth: 1,
                  ),
                  FlDotData(
                    getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                      radius: 5,
                      color: Colors.white,
                      strokeColor: _kAccent,
                      strokeWidth: 2,
                    ),
                  ),
                ),
            ],
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xF0151A26),
              tooltipBorder: const BorderSide(color: Color(0x33FFFFFF)),
              tooltipBorderRadius: BorderRadius.circular(10),
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              maxContentWidth: 170,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  // One tooltip per game: attach it to the game's dot only.
                  if (s.barIndex != 0)
                    null
                  else
                    LineTooltipItem(
                      '${date(points[s.spotIndex].date)}\n',
                      const TextStyle(color: _kMuted, fontSize: 11),
                      children: [
                        TextSpan(
                          text: isWinLoss
                              ? (points[s.spotIndex].value == 100
                                    ? 'Win'
                                    : 'Loss')
                              : format(points[s.spotIndex].value),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        TextSpan(
                          text:
                              '\nLast $window avg ${format(rolling[s.spotIndex])}',
                          style: const TextStyle(
                            color: _kAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (points[s.spotIndex].subtitle != null)
                          TextSpan(
                            text: '\n${points[s.spotIndex].subtitle}',
                            style: const TextStyle(
                              color: _kMuted,
                              fontSize: 11,
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
  }
}

/// How often scores land in each band: the count sits right on top of
/// each bar, and the band holding your average is highlighted.
class _SpreadChart extends StatelessWidget {
  final List<MetricDataPoint> points;
  final double average;
  final String averageLabel;
  const _SpreadChart({
    required this.points,
    required this.average,
    required this.averageLabel,
  });

  @override
  Widget build(BuildContext context) {
    final values = points.map((d) => d.value).toList();
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    var width = _niceStep((hi - lo) / 6);
    if (width <= 0) width = 1;
    final start = (lo / width).floorToDouble() * width;
    final bins = math.max(1, ((hi - start) / width).floor() + 1);
    final counts = List<int>.filled(bins, 0);
    for (final v in values) {
      counts[math.min(bins - 1, ((v - start) / width).floor())]++;
    }
    final avgBin = math.min(
      bins - 1,
      math.max(0, ((average - start) / width).floor()),
    );
    final maxCount = counts.reduce(math.max);
    const barArea = 120.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: barArea + 44, // bar + the count above it
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int i = 0; i < bins; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${counts[i]}',
                          style: TextStyle(
                            color: counts[i] == 0
                                ? _kFaint
                                : (i == avgBin ? _kAccent : Colors.white),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          height: counts[i] == 0
                              ? 2
                              : math.max(6, barArea * counts[i] / maxCount),
                          constraints: const BoxConstraints(maxWidth: 56),
                          decoration: BoxDecoration(
                            color: i == avgBin
                                ? _kAccent
                                : Colors.white.withValues(alpha: 0.2),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (int i = 0; i < bins; i++)
              Expanded(
                child: Text(
                  '${_compact(start + i * width)}–${_compact(start + (i + 1) * width)}',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    color: i == avgBin ? _kAccent : _kFaint,
                    fontSize: 11,
                    fontWeight: i == avgBin ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _kAccent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Games per score range. Your average ($averageLabel) is in the highlighted one.',
                style: const TextStyle(color: _kMuted, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A short dashed line, for the legend's "average" entry.
class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 1.5;
    for (double x = 0; x < size.width; x += 6) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(math.min(x + 3, size.width), size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => false;
}

class _GameRow extends StatelessWidget {
  final MetricDataPoint point;
  final String date;
  final String value;
  final double? delta;
  final String? deltaText;
  final bool isHigherBetter;
  final bool? isWin;
  final bool isBest;
  final bool last;

  const _GameRow({
    required this.point,
    required this.date,
    required this.value,
    required this.delta,
    required this.deltaText,
    required this.isHigherBetter,
    required this.isWin,
    required this.isBest,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    Color? chip;
    if (isWin != null) {
      chip = isWin! ? _kGood : _kBad;
    } else if (delta != null && delta!.abs() >= 0.05) {
      final good = isHigherBetter ? delta! > 0 : delta! < 0;
      chip = good ? _kGood : _kBad;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        date,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isBest) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.star, size: 15, color: _kAccent),
                    ],
                  ],
                ),
                if (point.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    point.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _kFaint, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (deltaText != null) ...[
            const SizedBox(width: 10),
            Container(
              constraints: const BoxConstraints(minWidth: 54),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (chip ?? Colors.white).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                deltaText!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: chip ?? _kMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A round step for axis labels (1, 2, 2.5, 5 × 10^n).
double _niceStep(double raw) {
  if (raw <= 0 || raw.isNaN) return 1;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final f = raw / mag;
  final nice = f <= 1 ? 1 : (f <= 2 ? 2 : (f <= 2.5 ? 2.5 : (f <= 5 ? 5 : 10)));
  return nice * mag;
}

String _compact(double v) {
  if (v.abs() >= 1000) {
    final k = v / 1000;
    return '${k == k.roundToDouble() ? k.toStringAsFixed(0) : k.toStringAsFixed(1)}k';
  }
  return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
