import 'package:flutter/material.dart';

import 'package:fahrtenbuch/pages/material_table.dart';
import 'package:fahrtenbuch/utils.dart';
import 'package:fahrtenbuch/api.dart';
import 'package:fahrtenbuch/api_widget.dart';

class ExpensesViewer extends StatelessWidget {
  final DateTime start;
  final DateTime end;

  const ExpensesViewer({super.key, required this.start, required this.end});

  @override
  Widget build(BuildContext context) {
    return ApiWidget(
      future: ({required session}) =>
          session.listExpenses(start: start, end: end),
      builder: (context, data) {
        debugPrint('data: $data');
        return MaterialTable(
          future: (row) async {
            var currentRow = data[row];
            var userMapping = await ApiSession().listUsers();

            return [
              DateHelper.display(DateTime.parse(currentRow["created_at"])),
              displayMoney(currentRow["amount"]),
              currentRow["description"] ?? "",
              currentRow["users"]
                  .map((userId) => userMapping[userId])
                  .join(", ")
            ];
          },
          columns: const ["Datum", "Betrag", "Beschreibung", "Nutzer"],
          numberOfRows: data!.length,
        );
      },
    );
  }
}
