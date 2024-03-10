import 'package:flutter/material.dart';

import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

import 'package:fahrtenbuch/api.dart';
import 'package:fahrtenbuch/api_widget.dart';
import 'package:fahrtenbuch/utils.dart';

class ComponentGroupDecoration extends StatelessWidget {
  const ComponentGroupDecoration(
      {super.key, this.label, required this.children});

  final String? label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    List<Widget> header = [];
    if (label != null) {
      header.add(Text(label!, style: Theme.of(context).textTheme.titleLarge));
      header.add(smallColDivider);
    }

    // Fully traverse this component group before moving on
    return FocusTraversalGroup(
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Center(
              child: Column(
                children: [...header, ...children],
              ),
            )),
      ),
    );
  }
}

class AddTripForm extends StatelessWidget {
  const AddTripForm({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComponentGroupDecoration(
      //label: 'Reise hinzufügen',
      children: [TripForm()],
    );
  }
}

class SelectDriver extends StatefulWidget {
  const SelectDriver({super.key});

  @override
  State<SelectDriver> createState() => SelectDriverState();
}

class SelectDriverState extends State<SelectDriver> {
  List<UserId> selectedItems = [ApiSession().userId];

  @override
  Widget build(BuildContext context) {
    return ApiWidget(
        future: ({required session}) => session.listUsers(),
        builder: (context, data) {
          Map<UserId, String> users = data!;

          return DropdownButtonFormField2<int>(
            menuItemStyleData: const MenuItemStyleData(
              padding: EdgeInsets.zero,
            ),
            dropdownStyleData: const DropdownStyleData(
              maxHeight: 200,
            ),
            items: users.entries.map((entry) {
              String label = entry.value;
              int value = entry.key;
              return DropdownMenuItem(
                  value: value,
                  //disable default onTap to avoid closing menu when selecting an item
                  enabled: false,
                  child: StatefulBuilder(builder: (context, menuSetState) {
                    final isSelected = selectedItems.contains(value);

                    return CheckboxListTile(
                      tristate: false,
                      value: isSelected,
                      title: Text(label),
                      onChanged: (shouldEnable) {
                        isSelected
                            ? selectedItems.remove(value)
                            : selectedItems.add(value);
                        //This rebuilds the StatefulWidget to update the button's text
                        setState(() {});
                        //This rebuilds the dropdownMenu Widget to update the check mark
                        menuSetState(() {});
                      },
                    );
                  }));
            }).toList(),
            //Use last selected item as the current value so if we've limited menu height, it scroll to last item.
            value: selectedItems.isEmpty ? null : selectedItems.last,
            // this needs to be added, otherwise the dropdown is disabled
            onChanged: (value) {},
            selectedItemBuilder: (context) {
              return users.entries
                  .map(
                    (item) => Text(
                      selectedItems.map((id) => users[id]).join(', '),
                      style: Theme.of(context).inputDecorationTheme.hintStyle,
                      maxLines: 1,
                      textAlign: TextAlign.end,
                    ),
                  )
                  .toList();
            },
            decoration: const InputDecoration(
              labelText: 'Beteiligte',
              border: OutlineInputBorder(),
            ),
          );
        });
  }
}

class TripForm extends StatefulWidget {
  const TripForm({super.key});

  @override
  State<TripForm> createState() => _TripFormState();
}

class _TripFormState extends State<TripForm> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _driverKey = GlobalKey<SelectDriverState>();

  @override
  Widget build(BuildContext context) {
    return FormBuilder(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // TODO: think of good navigation emojis, the arrow |-> for start and <-| was very good as well
          // For start it was called "Icons.start"
          ApiWidget(
              future: ({required session}) => session.lastTrip(),
              builder: (context, lastTrip) {
                return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: largeSpacing),
                    child: FormBuilderTextField(
                      name: 'start',
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.house),
                        labelText: 'Kilometerstand Vorher',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: lastTrip?['end']?.toString() ?? '0',
                      keyboardType: TextInputType.number,
                      enabled: false,
                      validator: FormBuilderValidators.compose([
                        FormBuilderValidators.numeric(),
                      ]),
                    ));
              }),
          smallColDivider,
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: largeSpacing),
              child: FormBuilderTextField(
                name: 'end',
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.pin_drop),
                  labelText: 'Kilometerstand Nachher',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(),
                  FormBuilderValidators.numeric(),
                ]),
              )),
          smallColDivider,
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: largeSpacing),
              child: FormBuilderTextField(
                name: 'description',
                decoration: const InputDecoration(
                  labelText: 'Zweck der Fahrt',
                  border: OutlineInputBorder(),
                ),
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.minLength(3, allowEmpty: true),
                ]),
              )),
          smallColDivider,
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: largeSpacing),
              child: SelectDriver(key: _driverKey)),
          smallColDivider,
          FilledButton.tonal(
            onPressed: () async {
              // check that the form data is valid:
              if (!(_formKey.currentState?.saveAndValidate() ?? false)) {
                // not valid, so we can't submit the form
                return;
              }

              if (_driverKey.currentState == null ||
                  _driverKey.currentState!.selectedItems.isEmpty) {
                _formKey.currentState?.fields['description']?.invalidate(
                    "Es muss mindestens eine Person ausgewählt werden!");
                return;
              }

              debugPrint(
                  "Selected users: ${_driverKey.currentState!.selectedItems}");

              // if it is, we can access the form data:
              Map<String, dynamic> data = _formKey.currentState!.value;

              await ApiSession()
                  .addTrip(
                      start: int.parse(data["start"]),
                      end: int.parse(data["end"]),
                      description: data["description"],
                      users: _driverKey.currentState!.selectedItems)
                  .then((value) async {
                // close the dialog
                Navigator.pop(context);
              }, onError: (error) {
                _formKey.currentState?.fields['description']?.invalidate(error);
              });
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }
}
