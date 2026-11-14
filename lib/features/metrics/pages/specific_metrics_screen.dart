import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/shared_widgets/gradient_background.dart';
import 'package:scorecards_app/core/shared_widgets/top_bar_background.dart';

class MetricDataPoint {
  final DateTime date;
  final double value;
  final String? subtitle;

  MetricDataPoint({required this.date, required this.value, this.subtitle});
}

class SpecificMetricScreen extends StatefulWidget {
  final String title;
  final String playerName;
  final List<MetricDataPoint> dataPoints;
  final String unit;
  final bool isHigherBetter;
  final String scopeDisplay;
  final String gameTypeDisplay;
  final String playerDisplay;
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

class _SpecificMetricScreenState extends State<SpecificMetricScreen> {
  String _selectedRange = 'All';
  String _filterMode = 'Time';
  List<String> _timeRanges = [];
  List<String> _gameRanges = [];
  int? _scrubIndex;
  bool _showIndividualScores = false;

  @override
  void initState() {
    super.initState();
    _calculateRanges();
  }

  void _calculateRanges() {
    if (widget.dataPoints.isEmpty) {
      _timeRanges = ['All'];
      _gameRanges = ['All'];
      return;
    }

    final sorted = List<MetricDataPoint>.from(widget.dataPoints)
      ..sort((a, b) => a.date.compareTo(b.date));

    final count = sorted.length;
    final spanDays = sorted.last.date.difference(sorted.first.date).inDays;

    List<String> g = [];
    if (count >= 10) g.add('10 Games');
    if (count >= 25) g.add('25 Games');
    if (count >= 50) g.add('50 Games');
    if (count >= 100) g.add('100 Games');
    g.add('All');

    List<String> t = [];
    if (spanDays >= 7) t.add('1W');
    if (spanDays >= 30) t.add('1M');
    if (spanDays >= 90) t.add('3M');
    if (spanDays >= 180) t.add('6M');
    if (spanDays >= 365) t.add('1Y');
    t.add('All');

    _timeRanges = t;
    _gameRanges = g;
  }

  String _formatDate(DateTime date) {
    const months = [
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
    return "${months[date.month - 1]} ${date.day}, ${date.year}";
  }

  void _handleScrub(Offset localPosition, double width, int dataLength) {
    if (dataLength <= 1) return;
    const double paddingRight = 32.0;
    double stepX = (width - paddingRight) / (dataLength - 1);
    int index = (localPosition.dx / stepX).round().clamp(0, dataLength - 1);
    if (_scrubIndex != index) {
      setState(() => _scrubIndex = index);
    }
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00A2FF).withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF00A2FF) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF00A2FF) : Colors.white54,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  TableRow _buildDataRow(
    int index,
    List<MetricDataPoint> fullListData,
    List<double> lifetimeRunningAverages,
    int startIndex,
  ) {
    final data = fullListData[index];
    int origIdx = fullListData.length - 1 - index;

    bool isAllSelected = _selectedRange == 'All';
    bool isInRange = origIdx >= startIndex;

    double currentRunningAvg = lifetimeRunningAverages[origIdx];
    double previousRunningAvg = origIdx > 0
        ? lifetimeRunningAverages[origIdx - 1]
        : 0.0;
    double avgChange = origIdx > 0
        ? (currentRunningAvg - previousRunningAvg)
        : 0.0;

    bool isAvgPositive = widget.isHigherBetter
        ? avgChange >= 0
        : avgChange <= 0;
    Color avgTrendColor = isAvgPositive
        ? const Color(0xFF54A27E)
        : const Color(0xFFD26A74);

    Color rowBg;
    double textOp;
    double subTextOp;

    if (isAllSelected) {
      rowBg = Colors.transparent;
      textOp = 1.0;
      subTextOp = 0.5;
    } else if (isInRange) {
      rowBg = Colors.white.withOpacity(0.03);
      textOp = 1.0;
      subTextOp = 0.5;
    } else {
      rowBg = Colors.transparent;
      textOp = 0.3;
      subTextOp = 0.15;
    }

    return TableRow(
      decoration: BoxDecoration(
        color: rowBg,
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: 24.0,
            right: 24.0,
            top: 16.0,
            bottom: 16.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatDate(data.date),
                style: TextStyle(
                  color: Colors.white.withOpacity(textOp),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (data.subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  data.subtitle!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(subTextOp),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 24.0, top: 16.0, bottom: 16.0),
          child: Text(
            data.value.toStringAsFixed(0),
            style: TextStyle(
              color: Colors.white.withOpacity(textOp),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 24.0, top: 16.0, bottom: 16.0),
          child: Text(
            currentRunningAvg.toStringAsFixed(1),
            style: TextStyle(
              color: Colors.white.withOpacity(textOp),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (!isAllSelected)
          Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 16.0),
            child: Text(
              (origIdx > 0 && avgChange != 0)
                  ? "${avgChange > 0 ? '+' : ''}${avgChange.toStringAsFixed(1)}"
                  : "-",
              style: TextStyle(
                color: (origIdx > 0 && avgChange != 0)
                    ? avgTrendColor.withOpacity(textOp)
                    : Colors.white.withOpacity(subTextOp),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    List<MetricDataPoint> allDataSorted = List.from(widget.dataPoints)
      ..sort((a, b) => a.date.compareTo(b.date));

    List<MetricDataPoint> fullListData = allDataSorted.reversed.toList();

    DateTime now = DateTime.now();
    DateTime? cutoff;
    if (!_selectedRange.endsWith('Games')) {
      switch (_selectedRange) {
        case '1W':
          cutoff = now.subtract(const Duration(days: 7));
          break;
        case '1M':
          cutoff = DateTime(now.year, now.month - 1, now.day);
          break;
        case '3M':
          cutoff = DateTime(now.year, now.month - 3, now.day);
          break;
        case '6M':
          cutoff = DateTime(now.year, now.month - 6, now.day);
          break;
        case '1Y':
          cutoff = DateTime(now.year - 1, now.month, now.day);
          break;
        case 'All':
        default:
          cutoff = null;
          break;
      }
    }

    int startIndex = 0;
    if (_selectedRange.endsWith('Games')) {
      int numGames = int.tryParse(_selectedRange.split(' ')[0]) ?? 0;
      if (numGames > 0 && allDataSorted.length > numGames) {
        startIndex = allDataSorted.length - numGames;
      }
    } else if (cutoff != null) {
      startIndex = allDataSorted.indexWhere((d) => d.date.isAfter(cutoff!));
      if (startIndex == -1) startIndex = allDataSorted.length;
    }

    List<MetricDataPoint> filteredData = allDataSorted.sublist(startIndex);

    List<double> lifetimeRunningAverages = [];
    double sum = 0;
    for (int i = 0; i < allDataSorted.length; i++) {
      sum += allDataSorted[i].value;
      lifetimeRunningAverages.add(sum / (i + 1));
    }

    List<double> filteredRunningAverages = lifetimeRunningAverages.sublist(
      startIndex,
    );

    List<MetricDataPoint> activeData = filteredData;
    if (_scrubIndex != null && _scrubIndex! < filteredData.length) {
      activeData = filteredData.sublist(0, _scrubIndex! + 1);
    }

    double currentAverage = 0;
    double previousAverage = 0;
    double change = 0;
    double percentChange = 0;

    if (activeData.isNotEmpty) {
      currentAverage =
          activeData.fold<double>(0.0, (s, item) => s + item.value) /
          activeData.length;

      if (activeData.length > 1) {
        int midPoint = activeData.length ~/ 2;
        var firstHalf = activeData.sublist(0, midPoint);
        if (firstHalf.isNotEmpty) {
          previousAverage =
              firstHalf.fold<double>(0.0, (s, item) => s + item.value) /
              firstHalf.length;
          change = currentAverage - previousAverage;
          percentChange = previousAverage != 0
              ? (change / previousAverage) * 100
              : 0;
        }
      }
    }

    bool isPositiveTrend = widget.isHigherBetter ? change >= 0 : change <= 0;
    Color trendColor = isPositiveTrend
        ? const Color(0xFF54A27E)
        : const Color(0xFFD26A74);

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
        body: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + kToolbarHeight + 40,
          ),
          child: Column(
            children: [
              // Header Stats Area
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 16.0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _scrubIndex == null ? "Average" : "Running Avg",
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            filteredData.isEmpty
                                ? "No Data"
                                : "${currentAverage.toStringAsFixed(1)}${widget.unit.isNotEmpty ? ' ${widget.unit}' : ''}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (activeData.length > 1 && _selectedRange != 'All')
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  change >= 0
                                      ? Icons.arrow_drop_up
                                      : Icons.arrow_drop_down,
                                  color: trendColor,
                                  size: 24,
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text:
                                                "${change.abs().toStringAsFixed(1)}${widget.unit.isNotEmpty ? ' ${widget.unit}' : ''} (${percentChange.abs().toStringAsFixed(1)}%) ",
                                            style: TextStyle(
                                              color: trendColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          TextSpan(
                                            text: "for selected period",
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(
                                                0.4,
                                              ),
                                              fontWeight: FontWeight.w500,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    if (_showIndividualScores && filteredData.isNotEmpty)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Game Score",
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${filteredData[_scrubIndex ?? (filteredData.length - 1)].value.toStringAsFixed(0)}${widget.unit.isNotEmpty ? ' ${widget.unit}' : ''}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (widget.showIndividualScoresToggle)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            "Scores Graph",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Switch(
                            value: _showIndividualScores,
                            activeColor: Colors.pinkAccent,
                            activeTrackColor: Colors.pinkAccent.withOpacity(
                              0.3,
                            ),
                            inactiveThumbColor: Colors.white54,
                            inactiveTrackColor: Colors.white10,
                            onChanged: (val) =>
                                setState(() => _showIndividualScores = val),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              // Unified Charts Area with Seamless Scrubber Line
              Container(
                width: double.infinity,
                child: filteredData.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Text(
                            "Not enough data to graph",
                            style: TextStyle(color: Colors.white24),
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          double chartWidth = constraints.maxWidth;
                          int dataLength = filteredData.length;
                          double stepX = dataLength > 1
                              ? (chartWidth - 32.0) / (dataLength - 1)
                              : 0;

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onLongPressStart: (details) => _handleScrub(
                              details.localPosition,
                              chartWidth,
                              dataLength,
                            ),
                            onLongPressMoveUpdate: (details) => _handleScrub(
                              details.localPosition,
                              chartWidth,
                              dataLength,
                            ),
                            onLongPressEnd: (_) =>
                                setState(() => _scrubIndex = null),
                            onLongPressUp: () =>
                                setState(() => _scrubIndex = null),
                            onLongPressCancel: () =>
                                setState(() => _scrubIndex = null),
                            child: Stack(
                              children: [
                                // Unified seamless vertical line
                                if (_scrubIndex != null && dataLength > 0)
                                  Positioned(
                                    left: _scrubIndex! * stepX,
                                    top:
                                        40, // Aligns perfectly with the inner graph bounds
                                    bottom: 20,
                                    child: Container(
                                      width: 1,
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                  ),

                                // The Charts
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      height: 220,
                                      width: double.infinity,
                                      padding: const EdgeInsets.only(top: 20),
                                      child: CustomPaint(
                                        painter: _SleekChartPainter(
                                          data: filteredRunningAverages,
                                          lineColor: const Color(0xFF00A2FF),
                                          selectedIndex: _scrubIndex,
                                        ),
                                      ),
                                    ),
                                    if (_showIndividualScores &&
                                        filteredData.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        height: 100,
                                        width: double.infinity,
                                        child: CustomPaint(
                                          painter: _SleekChartPainter(
                                            data: filteredData
                                                .map((d) => d.value)
                                                .toList(),
                                            lineColor: Colors.pinkAccent,
                                            selectedIndex: _scrubIndex,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 24),

              // Range Selector Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    // Dynamic Filter Chips
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children:
                              (_filterMode == 'Time'
                                      ? _timeRanges
                                      : _gameRanges)
                                  .map((range) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        right: 8.0,
                                      ),
                                      child: _buildFilterChip(
                                        range,
                                        _selectedRange == range,
                                        () {
                                          setState(() {
                                            _selectedRange = range;
                                            _scrubIndex = null;
                                          });
                                        },
                                      ),
                                    );
                                  })
                                  .toList(),
                        ),
                      ),
                    ),

                    // Thematic Separator
                    Container(
                      height: 24,
                      width: 1,
                      color: Colors.white24,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                    ),

                    // Time vs Games Toggle
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildFilterChip("Time", _filterMode == 'Time', () {
                          setState(() {
                            if (_filterMode != 'Time') {
                              _filterMode = 'Time';
                              if (!_timeRanges.contains(_selectedRange)) {
                                _selectedRange = 'All';
                              }
                              _scrubIndex = null;
                            }
                          });
                        }),
                        const SizedBox(width: 6),
                        _buildFilterChip("Games", _filterMode == 'Games', () {
                          setState(() {
                            if (_filterMode != 'Games') {
                              _filterMode = 'Games';
                              if (!_gameRanges.contains(_selectedRange)) {
                                _selectedRange = 'All';
                              }
                              _scrubIndex = null;
                            }
                          });
                        }),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Divider(color: Colors.white12, height: 1),

              // Game List & Header
              Expanded(
                child: fullListData.isEmpty
                    ? Center(
                        child: Text(
                          "No games recorded.",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.only(top: 0, bottom: 40),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 0.0,
                            ),
                            child: Table(
                              columnWidths: <int, TableColumnWidth>{
                                0: const IntrinsicColumnWidth(),
                                1: const IntrinsicColumnWidth(),
                                2: const IntrinsicColumnWidth(),
                                if (_selectedRange != 'All')
                                  3: const IntrinsicColumnWidth(),
                              },
                              defaultVerticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              children: [
                                TableRow(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 24.0,
                                        right: 24.0,
                                        bottom: 16.0,
                                        top: 16.0,
                                      ),
                                      child: Text(
                                        "DATE",
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.3),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        right: 24.0,
                                        bottom: 16.0,
                                        top: 16.0,
                                      ),
                                      child: Text(
                                        "SCORE",
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.3),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        right: 24.0,
                                        bottom: 16.0,
                                        top: 16.0,
                                      ),
                                      child: Text(
                                        "AVERAGE",
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.3),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                    if (_selectedRange != 'All')
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 16.0,
                                          top: 16.0,
                                        ),
                                        child: Text(
                                          "+/-",
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.3,
                                            ),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                for (
                                  int index = 0;
                                  index < fullListData.length;
                                  index++
                                )
                                  _buildDataRow(
                                    index,
                                    fullListData,
                                    lifetimeRunningAverages,
                                    startIndex,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SleekChartPainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;
  final int? selectedIndex;

  _SleekChartPainter({
    required this.data,
    required this.lineColor,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const double verticalPadding = 20.0;
    const double paddingRight = 32.0;
    final double drawableHeight = size.height - (verticalPadding * 2);

    double maxVal = data.reduce((a, b) => a > b ? a : b);
    double minVal = data.reduce((a, b) => a < b ? a : b);
    double range = maxVal - minVal;
    if (range == 0) range = 1.0;

    Path linePath = Path();
    Path fillPath = Path();

    double stepX =
        (size.width - paddingRight) / (data.length > 1 ? data.length - 1 : 1);

    for (int i = 0; i < data.length; i++) {
      double x = i * stepX;
      double normalizedY = (data[i] - minVal) / range;
      double y = size.height - verticalPadding - (normalizedY * drawableHeight);

      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    Paint fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [lineColor.withOpacity(0.4), lineColor.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    Paint glowPaint = Paint()
      ..color = lineColor.withOpacity(0.3)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(linePath, glowPaint);

    Paint linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(linePath, linePaint);

    int dotIndex = selectedIndex ?? (data.length - 1);
    double dotX = dotIndex * stepX;
    double dotY =
        size.height -
        verticalPadding -
        (((data[dotIndex] - minVal) / range) * drawableHeight);

    if (selectedIndex != null) {
      Paint intenseGlow = Paint()
        ..color = lineColor.withOpacity(0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      canvas.drawCircle(Offset(dotX, dotY), 24, intenseGlow);
    }

    Paint dotGlow = Paint()
      ..color = lineColor.withOpacity(0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(
      Offset(dotX, dotY),
      selectedIndex != null ? 10 : 8,
      dotGlow,
    );

    Paint dotCenter = Paint()..color = Colors.white;
    canvas.drawCircle(
      Offset(dotX, dotY),
      selectedIndex != null ? 5 : 4,
      dotCenter,
    );

    if (selectedIndex != null) {
      Paint dotBorder = Paint()
        ..color = lineColor
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(dotX, dotY), 6, dotBorder);
    }
  }

  @override
  bool shouldRepaint(covariant _SleekChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}
