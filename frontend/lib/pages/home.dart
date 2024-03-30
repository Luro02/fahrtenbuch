import 'package:flutter/material.dart';

import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';

import 'package:fahrtenbuch/pages/trip_form.dart';
import 'package:fahrtenbuch/pages/expense_form.dart';
import 'package:fahrtenbuch/pages/material_table.dart';
import 'package:fahrtenbuch/pages/trips_viewer.dart';
import 'package:fahrtenbuch/pages/expenses_viewer.dart';
import 'package:fahrtenbuch/utils.dart';
import 'package:fahrtenbuch/api.dart';
import 'package:fahrtenbuch/api_widget.dart';
import 'package:fahrtenbuch/month_selector.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class SummaryWidget extends StatefulWidget {
  final DateTime start;
  final DateTime end;

  const SummaryWidget({super.key, required this.start, required this.end});

  @override
  State<SummaryWidget> createState() => _SummaryWidgetState();
}

class _SummaryWidgetState extends State<SummaryWidget> {
  @override
  Widget build(BuildContext context) {
    return ApiWidget(
        future: ({required session}) =>
            session.summary(start: widget.start, end: widget.end),
        builder: (context, summary) {
          final username = ApiSession().username.capitalize();

          debugPrint("Summary: $summary");
          var balances = parseIntMap(summary!["balances"]);
          var payments = parseIntMap(summary["payments"])
              .map((key, value) => MapEntry(key, parseIntMap(value)));

          List<List<dynamic>> paymentRows = [];
          for (var entry in payments.entries) {
            for (var subentry in entry.value.entries) {
              paymentRows.add([entry.key, subentry.key, subentry.value]);
            }
          }

          return Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                textAlign: TextAlign.start,
                text: TextSpan(
                  text: 'Hallo $username,',
                  style: Theme.of(context).primaryTextTheme.headlineSmall,
                ),
              ),
              smallColDivider,
              RichText(
                textAlign: TextAlign.start,
                text: TextSpan(
                  children: [
                    const TextSpan(text: "Du bist diesen Monat "),
                    TextSpan(
                      text: summary["distance"].toString(),
                      style: Theme.of(context)
                          .primaryTextTheme
                          .bodyMedium
                          ?.copyWith(
                              color: Theme.of(context).colorScheme.primary),
                    ),
                    const TextSpan(text: " km von insgesamt "),
                    TextSpan(
                      text: summary["total_distance"].toString(),
                      style: Theme.of(context)
                          .primaryTextTheme
                          .bodyMedium
                          ?.copyWith(
                              color: Theme.of(context).colorScheme.primary),
                    ),
                    const TextSpan(text: " km gefahren."),
                  ],
                  style: Theme.of(context).primaryTextTheme.bodyMedium,
                ),
              ),
              smallColDivider,
              RichText(
                textAlign: TextAlign.start,
                text: TextSpan(
                  children: [
                    const TextSpan(text: "Von insgesamt "),
                    TextSpan(
                      text: displayMoney(summary["total_amount"]),
                      style: Theme.of(context)
                          .primaryTextTheme
                          .bodyMedium
                          ?.copyWith(
                              color: Theme.of(context).colorScheme.primary),
                    ),
                    const TextSpan(text: " hast du "),
                    TextSpan(
                      text: displayMoney(summary["prepaid"]),
                      style: Theme.of(context)
                          .primaryTextTheme
                          .bodyMedium
                          ?.copyWith(
                              color: Theme.of(context).colorScheme.primary),
                    ),
                    const TextSpan(text: " ausgelegt."),
                  ],
                  style: Theme.of(context).primaryTextTheme.bodyMedium,
                ),
              ),
              mediumColDivider,
              SizedBox(
                  height: 200,
                  child: MaterialTable(
                    future: (row) async {
                      var entry = balances.entries.elementAt(row);
                      var username =
                          await ApiSession().usernameForId(entry.key);

                      return [username, displayMoney(entry.value)];
                    },
                    columns: const ["Benutzer", "Kontostand"],
                    numberOfRows: balances.length,
                  )),
              mediumColDivider,
              RichText(
                textAlign: TextAlign.start,
                text: TextSpan(
                  text:
                      "Um die Beträge auszugleichen, müssen folgende Zahlungen getätigt werden:",
                  style: Theme.of(context).primaryTextTheme.bodyMedium,
                ),
              ),
              smallColDivider,
              SizedBox(
                  height: 200,
                  child: MaterialTable(
                    future: (row) async {
                      var currentRow = paymentRows[row];

                      return [
                        await ApiSession().usernameForId(currentRow[0]),
                        await ApiSession().usernameForId(currentRow[1]),
                        displayMoney(currentRow[2])
                      ];
                    },
                    columns: const ["Von", "An", "Betrag"],
                    numberOfRows: paymentRows.length,
                  )),
              largeColDivider,
              RichText(
                textAlign: TextAlign.start,
                text: TextSpan(
                  text: "Alle Fahrten in diesem Monat:",
                  style: Theme.of(context).primaryTextTheme.bodyMedium,
                ),
              ),
              smallColDivider,
              SizedBox(
                height: 300,
                child: TripsViewer(start: widget.start, end: widget.end),
              ),
              largeColDivider,
              RichText(
                textAlign: TextAlign.start,
                text: TextSpan(
                  text: "Alle Ausgaben in diesem Monat:",
                  style: Theme.of(context).primaryTextTheme.bodyMedium,
                ),
              ),
              smallColDivider,
              SizedBox(
                height: 300,
                child: ExpensesViewer(start: widget.start, end: widget.end),
              ),
            ],
          );
        });
  }
}

class _HomeState extends State<Home> {
  DateTime start = DateHelper.monthRange(DateTime.now()).$1;
  DateTime end = DateHelper.monthRange(DateTime.now()).$2;
  Key _key = UniqueKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fahrtenbuch'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: MonthSelector(
              onChanged: (start, end) {
                setState(() {
                  this.start = start;
                  this.end = end;
                  _key = UniqueKey();
                });
              },
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
          child: Padding(
        key: _key,
        padding: const EdgeInsets.all(32.0),
        child: SummaryWidget(
          start: start,
          end: end,
        ),
      )),
      floatingActionButtonLocation: ExpandableFab.location,
      floatingActionButton: ExpandableFab(
        distance: 75,
        openButtonBuilder:
            RotateFloatingActionButtonBuilder(child: const Icon(Icons.add)),
        closeButtonBuilder:
            DefaultFloatingActionButtonBuilder(child: const Icon(Icons.close)),
        type: ExpandableFabType.up,
        children: [
          FloatingActionButton(
            onPressed: () async {
              Navigator.push(
                  context,
                  PageRouteBuilder(
                      fullscreenDialog: true,
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                      pageBuilder: (context, animation1, animation2) =>
                          Scaffold(
                            appBar: AppBar(
                              title: const Text('Neuen Eintrag erstellen'),
                              centerTitle: false,
                              leading: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                            body: const AddTripForm(),
                          ))).then((_) => setState(() {}));
            },
            child: const Icon(Icons.add_location_alt_outlined),
          ),
          FloatingActionButton(
            onPressed: () async {
              Navigator.push(
                  context,
                  PageRouteBuilder(
                      fullscreenDialog: true,
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                      pageBuilder: (context, animation1, animation2) =>
                          Scaffold(
                            appBar: AppBar(
                              title: const Text('Neuen Betrag hinzufügen'),
                              centerTitle: false,
                              leading: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                            body: const AddExpenseForm(),
                          ))).then((_) => setState(() {}));
            },
            child: const Icon(Icons.euro_outlined),
          )
        ],
      ),
    );
  }
}
