import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_table_view/default_animated_switcher_transition_builder.dart';
import 'package:material_table_view/material_table_view.dart';
import 'package:material_table_view/shimmer_placeholder_shade.dart';
import 'package:material_table_view/table_view_typedefs.dart';

class StylingController with ChangeNotifier {
  final verticalDividerWigglesPerRow = ValueNotifier<int>(1);
  final verticalDividerWiggleOffset = ValueNotifier<double>(16.0);
  final lineDividerEnabled = ValueNotifier<bool>(false);
  final useRTL = ValueNotifier<bool>(false);

  StylingController() {
    verticalDividerWigglesPerRow.addListener(notifyListeners);
    verticalDividerWiggleOffset.addListener(notifyListeners);
    lineDividerEnabled.addListener(notifyListeners);
    useRTL.addListener(notifyListeners);
  }

  TableViewStyle get tableViewStyle => TableViewStyle(
        dividers: TableViewDividersStyle(
          vertical: TableViewVerticalDividersStyle.symmetric(
            TableViewVerticalDividerStyle(
              wiggleOffset: verticalDividerWiggleOffset.value,
              wigglesPerRow: verticalDividerWigglesPerRow.value,
            ),
          ),
        ),
      );

  @override
  void dispose() {
    verticalDividerWigglesPerRow.removeListener(notifyListeners);
    verticalDividerWiggleOffset.removeListener(notifyListeners);
    lineDividerEnabled.removeListener(notifyListeners);
    super.dispose();
  }
}

class MaterialTable extends StatefulWidget {
  final double Function(int)? columnWidth;
  final double Function(int)? minColumnWidth;
  final List<String> columns;
  final Future<List<Object?>> Function(int row) future;
  final int numberOfRows;

  const MaterialTable(
      {super.key,
      this.columnWidth,
      this.minColumnWidth,
      required this.future,
      required this.columns,
      required this.numberOfRows});

  @override
  State<MaterialTable> createState() => _MaterialTableState();
}

class _MaterialTableState extends State<MaterialTable>
    with SingleTickerProviderStateMixin<MaterialTable> {
  late TabController tabController;

  final stylingController = StylingController();

  final verticalSliverExampleScrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    tabController = TabController(length: 2, vsync: this);

    stylingController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    verticalSliverExampleScrollController.dispose();
    tabController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const shimmerBaseColor = Color(0x20808080);
    const shimmerHighlightColor = Color(0x40FFFFFF);

    return Directionality(
      textDirection: stylingController.useRTL.value
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        body: ShimmerPlaceholderShadeProvider(
          loopDuration: const Duration(seconds: 30),
          colors: const [
            shimmerBaseColor,
            shimmerHighlightColor,
            shimmerBaseColor,
            shimmerHighlightColor,
            shimmerBaseColor
          ],
          stops: const [.0, .45, .5, .95, 1],
          builder: (context, placeholderShade) => LayoutBuilder(
            builder: (context, constraints) {
              return _buildBoxExample(
                context,
                placeholderShade,
              );
            },
          ),
        ),
      ),
    );
  }

  /// Builds a regular [TableView].
  Widget _buildBoxExample(
    BuildContext context,
    TablePlaceholderShade placeholderShade,
  ) =>
      TableView.builder(
        columns: widget.columns.indexed.map((element) {
          return TableColumn(
              width: widget.columnWidth?.call(element.$1) ?? 64.0,
              minResizeWidth: widget.minColumnWidth?.call(element.$1) ?? 64.0,
              flex: 1,
              // this will make the column expand to fill remaining width
              freezePriority: 0);
        }).toList(),
        style: TableViewStyle(
          dividers: TableViewDividersStyle(
            vertical: TableViewVerticalDividersStyle.symmetric(
              TableViewVerticalDividerStyle(
                  wigglesPerRow:
                      stylingController.verticalDividerWigglesPerRow.value,
                  wiggleOffset:
                      stylingController.verticalDividerWiggleOffset.value),
            ),
          ),
        ),
        rowHeight: 48.0 + 1 * Theme.of(context).visualDensity.vertical,
        rowCount: widget.numberOfRows,
        rowBuilder: _rowBuilder,
        placeholderBuilder: _placeholderBuilder,
        placeholderShade: placeholderShade,
        headerBuilder: _headerBuilder,
      );

  Widget _headerBuilder(
    BuildContext context,
    TableRowContentBuilder contentBuilder,
  ) =>
      contentBuilder(
        context,
        (context, column) => Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: stylingController.useRTL.value
                ? const EdgeInsets.only(right: 8.0)
                : const EdgeInsets.only(left: 8.0),
            child: Align(
              alignment: stylingController.useRTL.value
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Text(widget.columns[column]),
            ),
          ),
        ),
      );

  /// This is used to wrap both regular and placeholder rows to achieve fade
  /// transition between them and to insert optional row divider.
  Widget _wrapRow(Widget child) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: stylingController.lineDividerEnabled.value
              ? Border(bottom: Divider.createBorderSide(context))
              : null,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: tableRowDefaultAnimatedSwitcherTransitionBuilder,
          child: child,
        ),
      );

  final Map<int, List<Object?>> _rows = {};
  final Set<int> _pendingRows = {};

  Widget? _rowBuilder(
    BuildContext context,
    int row,
    TableRowContentBuilder contentBuilder,
  ) {
    var textStyle = Theme.of(context).textTheme.bodyMedium;

    if (!_pendingRows.contains(row)) {
      _pendingRows.add(row);
      widget.future(row).then((value) {
        _rows[row] = value;
        setState(() {});
      }, onError: (error) {
        _rows[row] = List.filled(widget.columns.length, error);
        setState(() {});
      });
    }

    // the row is not completed yet, return shimmer
    if (_rows[row] == null) {
      return null;
    }

    return _wrapRow(
      Material(
        type: MaterialType.transparency,
        child: contentBuilder(
          context,
          (context, column) => Padding(
            padding: stylingController.useRTL.value
                ? const EdgeInsets.only(right: 8.0)
                : const EdgeInsets.only(left: 8.0),
            child: Align(
              // fit: BoxFit.none,
              alignment: stylingController.useRTL.value
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Text(
                '${_rows[row]![column]}',
                style: textStyle,
                overflow: TextOverflow.clip,
                maxLines: 2,
                softWrap: true,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholderBuilder(
    BuildContext context,
    TableRowContentBuilder contentBuilder,
  ) =>
      // TODO: this defines the placeholder!
      _wrapRow(
        contentBuilder(
          context,
          (context, column) => const Padding(
            padding: EdgeInsets.all(8.0),
            child: DecoratedBox(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(16)))),
          ),
        ),
      );
}
