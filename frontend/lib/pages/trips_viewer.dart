import 'package:flutter/material.dart';

import 'package:fahrtenbuch/pages/material_table.dart';
import 'package:fahrtenbuch/utils.dart';
import 'package:fahrtenbuch/api.dart';
import 'package:fahrtenbuch/api_widget.dart';

class TripsViewer extends StatelessWidget {
  final DateTime start;
  final DateTime end;

  const TripsViewer({super.key, required this.start, required this.end});

  @override
  Widget build(BuildContext context) {
    return ApiWidget(
      future: ({required session}) => session.listTrips(start: start, end: end),
      builder: (context, data) {
        debugPrint('data: $data');

        return MaterialTable(
          columnWidth: (column) =>
              [96.0, 64.0, 64.0, 48.0, 64.0, 128.0, 64.0][column],
          minColumnWidth: (column) =>
              [96.0, 64.0, 64.0, 48.0, 64.0, 128.0, 64.0][column],
          future: (row) async {
            var currentRow = data[row];
            var userMapping = await ApiSession().listUsers();

            return [
              DateHelper.display(DateTime.parse(currentRow["created_at"])),
              currentRow["start"],
              currentRow["end"],
              currentRow["end"] - currentRow["start"],
              displayMoney(currentRow["price"]),
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
            "Kosten",
            "Beschreibung",
            "Nutzer"
          ],
          numberOfRows: data!.length,
        );
      },
    );
  }
}
