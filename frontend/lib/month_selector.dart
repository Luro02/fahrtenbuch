import 'package:flutter/material.dart';

import 'package:dropdown_button2/dropdown_button2.dart';

import 'package:fahrtenbuch/utils.dart';

class MonthSelector extends StatefulWidget {
  final void Function(DateTime, DateTime) onChanged;

  const MonthSelector({super.key, required this.onChanged});

  @override
  State<MonthSelector> createState() => _MonthSelectorState();
}

class _MonthSelectorState extends State<MonthSelector> {
  DateTime? currentMonth;

  @override
  Widget build(BuildContext context) {
    return DropdownButton2<DateTime>(
      dropdownStyleData: const DropdownStyleData(
        maxHeight: 200,
      ),
      menuItemStyleData: const MenuItemStyleData(
        padding: EdgeInsets.zero,
      ),
      items: DateHelper.displayDates().entries.map((entry) {
        String label = entry.key;
        DateTime value = entry.value;
        return DropdownMenuItem(
          value: value,
          onTap: () {
            debugPrint("Tapped on $value");
            var range = DateHelper.monthRange(value);
            setState(() {
              currentMonth = range.$1;
            });
            widget.onChanged(range.$1, range.$2);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(label),
          ),
        );
      }).toList(),
      value: currentMonth ?? DateHelper.displayDates().values.first,
      // this needs to be added, otherwise the dropdown is disabled
      onChanged: (value) {},
    );
  }
}
