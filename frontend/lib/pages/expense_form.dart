import 'package:fahrtenbuch/api.dart';
import 'package:fahrtenbuch/pages/trip_form.dart'
    show ComponentGroupDecoration, SelectDriver, SelectDriverState;

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

const rowDivider = SizedBox(width: 20);
const colDivider = SizedBox(height: 10);
const tinySpacing = 3.0;
const smallSpacing = 10.0;
const largeSpacing = 40.0;
const double cardWidth = 115;
const double widthConstraint = 450;

class AddExpenseForm extends StatelessWidget {
  const AddExpenseForm({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComponentGroupDecoration(
      children: [ExpenseForm()],
    );
  }
}

class ExpenseForm extends StatefulWidget {
  const ExpenseForm({super.key});

  @override
  State<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<ExpenseForm> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _driverKey = GlobalKey<SelectDriverState>();

  String? moneyValidator<T>(T? value) {
    num? numValue = num.tryParse(value?.toString() ?? "");

    if (numValue == null) {
      return "Bitte geben Sie eine ganze Zahl ein!";
    }

    if (numValue <= 0.0) {
      return "Der Betrag muss größer als 0 sein!";
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FormBuilder(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: largeSpacing),
              child: FormBuilderTextField(
                name: 'amount',
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.euro_sharp),
                  labelText: 'Betrag',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(),
                  moneyValidator,
                ]),
              )),
          colDivider,
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: largeSpacing),
              child: FormBuilderTextField(
                name: 'description',
                decoration: const InputDecoration(
                  labelText: 'Beschreibung',
                  border: OutlineInputBorder(),
                ),
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.minLength(3, allowEmpty: true),
                ]),
              )),
          colDivider,
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: largeSpacing),
              child: SelectDriver(key: _driverKey)),
          colDivider,
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
                  .addExpense(
                      amount: double.parse(data["amount"]),
                      description: data["description"],
                      users: _driverKey.currentState!.selectedItems)
                  .then((value) async {
                // close the dialog?
                // TODO: maybe keep it open for adding multiple trips?
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
