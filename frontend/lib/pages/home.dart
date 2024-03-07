import 'package:fahrtenbuch/api.dart';
import 'package:fahrtenbuch/api_widget.dart';
import 'package:fahrtenbuch/pages/material_table.dart';
import 'package:fahrtenbuch/pages/trip_form.dart';
import 'package:fahrtenbuch/pages/expense_form.dart';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';

const colDivider = SizedBox(height: 10);
const largeColDivider = SizedBox(height: 30);
const mediumPadding = 10.0;
const largePadding = 0.0;

class MonthlyCard extends StatefulWidget {
  final Widget Function(DateTime, DateTime) child;

  const MonthlyCard({super.key, required this.child});

  @override
  State<MonthlyCard> createState() => _MonthlyCardState();
}

class DateUtils {
  static DateTime lastDayOfMonth(DateTime dateTime) {
    return nextMonth(DateTime(dateTime.year, dateTime.month, 1))
        .subtract(const Duration(seconds: 1));
  }

  static DateTime firstDayOfMonth(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, 1);
  }

  static DateTime nextMonth(DateTime now) {
    if (now.month == 12) {
      return DateTime(now.year + 1, 1, now.day);
    }

    return DateTime(now.year, now.month + 1, now.day);
  }

  static DateTime previousMonth(DateTime now) {
    if (now.month == 1) {
      return DateTime(now.year - 1, 12, now.day);
    }

    return DateTime(now.year, now.month - 1, now.day);
  }

  static (DateTime, DateTime) monthRange(DateTime dateTime) {
    var start = firstDayOfMonth(dateTime);
    var end = lastDayOfMonth(start);

    return (start, end);
  }

  static Map<String, DateTime> displayDates() {
    var now = firstDayOfMonth(DateTime.now());

    Map<String, DateTime> result = {};
    for (int i = 0; i < 12; i++) {
      result['${now.month.toString().padLeft(2, '0')}/${now.year}'] = now;

      now = previousMonth(now);
    }

    return result;
  }
}

class _MonthlyCardState extends State<MonthlyCard> {
  DateTime currentMonth = DateUtils.displayDates().values.first;

  @override
  Widget build(BuildContext context) {
    var range = DateUtils.monthRange(currentMonth);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: mediumPadding),
      child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            colDivider,
            DropdownButtonFormField2<DateTime>(
              dropdownStyleData: const DropdownStyleData(
                maxHeight: 200,
              ),
              menuItemStyleData: const MenuItemStyleData(
                padding: EdgeInsets.zero,
              ),
              items: DateUtils.displayDates().entries.map((entry) {
                String label = entry.key;
                DateTime value = entry.value;
                return DropdownMenuItem(
                  value: value,
                  onTap: () {
                    currentMonth = value;
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(label),
                  ),
                );
              }).toList(),
              value: currentMonth,
              // this needs to be added, otherwise the dropdown is disabled
              onChanged: (value) {},
              decoration: const InputDecoration(
                labelText: 'Monat',
                border: OutlineInputBorder(),
              ),
            ),
            colDivider,
            Expanded(
              flex: 1,
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: largePadding),
                  child: widget.child(range.$1, range.$2)),
            ),
          ]),
    );
  }
}

class TripsViewer extends StatelessWidget {
  const TripsViewer({super.key});

  @override
  Widget build(BuildContext context) {
    return MonthlyCard(
        child: (start, end) => ApiWidget(
              future: ({required session}) =>
                  session.listTrips(start: start, end: end),
              builder: (context, data) {
                debugPrint('data: $data');

                int offset = 0;
                return MaterialTable(
                  future: (row) async {
                    debugPrint("Fetching row $row");
                    await Future.delayed(Duration(seconds: 1 + offset++));
                    var currentRow = data[row];
                    var userMapping = await ApiSession().listUsers();

                    return [
                      currentRow["created_at"],
                      currentRow["start"],
                      currentRow["end"],
                      currentRow["end"] - currentRow["start"],
                      currentRow["description"] ?? "",
                      currentRow["users"]
                          .map((userId) => userMapping[userId])
                          .join(", ")
                    ];
                  },
                  columns: const [
                    "Datum",
                    "Start",
                    "Ende",
                    "Kilometer",
                    "Beschreibung",
                    "Nutzer"
                  ],
                  numberOfRows: data!.length,
                );
              },
            ));
  }
}

class ExpensesViewer extends StatelessWidget {
  const ExpensesViewer({super.key});

  @override
  Widget build(BuildContext context) {
    return MonthlyCard(
        child: (start, end) => ApiWidget(
              future: ({required session}) =>
                  session.listExpenses(start: start, end: end),
              builder: (context, data) {
                debugPrint('data: $data');

                int offset = 0;
                return MaterialTable(
                  future: (row) async {
                    debugPrint("Fetching row $row");
                    await Future.delayed(Duration(seconds: 1 + offset++));
                    var currentRow = data[row];
                    var userMapping = await ApiSession().listUsers();

                    return [
                      currentRow["id"],
                      currentRow["created_at"],
                      currentRow["amount"],
                      currentRow["description"] ?? "",
                      currentRow["users"]
                          .map((userId) => userMapping[userId])
                          .join(", ")
                    ];
                  },
                  columns: const [
                    "Id",
                    "Datum",
                    "Betrag",
                    "Beschreibung",
                    "Nutzer"
                  ],
                  numberOfRows: data!.length,
                );
              },
            ));
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fahrtenbuch'),
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            ApiWidget(
                future: ({required session}) => session.summary(),
                builder: (context, data) {
                  var summary = data!;

                  int distance = summary["distance"];
                  int amount = summary["prepaid"];
                  return ComponentDecoration(
                    label: "Übersicht",
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: <Widget>[
                          Text("Gefahrene Kilometer: $distance"),
                          Text("Ausgelegtes Geld: ${amount / 100.0}€"),
                          // TODO: hier eine Liste mit Menschen von denen man noch Geld bekommt?
                        ],
                      ),
                    ),
                  );
                }),
            largeColDivider,
            // Card(child: const Text('Hallo Welt!')),
            // colDivider,
            const SizedBox(
              height: 300.0,
              child: TripsViewer(),
            ),
            largeColDivider,
            const SizedBox(
              height: 300.0,
              child: ExpensesViewer(),
            ),
          ],
        ),
      ),
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
