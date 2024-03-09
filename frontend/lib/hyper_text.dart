import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class HyperText extends StatelessWidget {
  final String text;
  final Function()? onTap;

  const HyperText({
    super.key,
    required this.text,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        text: text,
        style: Theme.of(context).primaryTextTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline),
        recognizer: TapGestureRecognizer()..onTap = onTap,
      ),
    );
  }
}
