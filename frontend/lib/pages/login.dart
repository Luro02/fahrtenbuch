import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import 'package:fahrtenbuch/utils.dart';

import 'trip_form.dart';
import '../api.dart';

class LoginPage extends StatefulWidget {
  final Widget Function(BuildContext context) onLoginSuccess;

  const LoginPage({super.key, required this.onLoginSuccess});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _usernameFieldKey = GlobalKey<FormBuilderFieldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: loadFuture(
        future: ApiSession().isLoggedIn,
        builder: (context, data) {
          // skip login if already logged in
          if (data ?? false == true) {
            return widget.onLoginSuccess(context);
          }

          return FormBuilder(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: largeSpacing),
                    child: FormBuilderTextField(
                      key: _usernameFieldKey,
                      name: 'username',
                      decoration: const InputDecoration(
                        labelText: 'Benutzername',
                        border: OutlineInputBorder(),
                      ),
                      validator: FormBuilderValidators.compose([
                        FormBuilderValidators.required(),
                        FormBuilderValidators.minLength(5),
                      ]),
                    )),
                colDivider,
                Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: largeSpacing),
                    child: FormBuilderTextField(
                      name: 'password',
                      decoration: const InputDecoration(
                        labelText: 'Passwort',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: FormBuilderValidators.compose([
                        FormBuilderValidators.required(),
                        FormBuilderValidators.minLength(5),
                      ]),
                    )),
                colDivider,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    FilledButton.tonal(
                      onPressed: () async {
                        // check that the form data is valid:
                        if (!(_formKey.currentState?.saveAndValidate() ??
                            false)) {
                          // not valid, so we can't submit the form
                          return;
                        }

                        // if it is, we can access the form data:
                        Map<String, dynamic> data =
                            _formKey.currentState!.value;

                        await ApiSession()
                            .login(
                                username: data["username"],
                                password: data["password"])
                            .then((value) async {
                          await Navigator.pushReplacement<void, void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: widget.onLoginSuccess,
                            ),
                          );
                        }, onError: (error) {
                          _formKey.currentState?.fields['username']
                              ?.invalidate(error);
                        });
                      },
                      child: const Text('Anmelden'),
                    ),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        text: 'Registrieren',
                        style: Theme.of(context)
                            .primaryTextTheme
                            .labelSmall
                            ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                decoration: TextDecoration.underline),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () async {
                            // check that the form data is valid:
                            if (!(_formKey.currentState?.saveAndValidate() ??
                                false)) {
                              // not valid, so we can't submit the form
                              return;
                            }

                            // if it is, we can access the form data:
                            Map<String, dynamic> data =
                                _formKey.currentState!.value;

                            await ApiSession()
                                .register(
                                    username: data["username"],
                                    password: data["password"])
                                .then((value) async {
                              await Navigator.pushReplacement<void, void>(
                                context,
                                MaterialPageRoute<void>(
                                  builder: widget.onLoginSuccess,
                                ),
                              );
                            }, onError: (error) {
                              _formKey.currentState?.fields['username']
                                  ?.invalidate(error);
                            });
                          },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
