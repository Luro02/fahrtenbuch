import 'package:fahrtenbuch/api.dart';
import 'package:flutter/material.dart';

typedef ApiWidgetBuilder<T> = Widget Function(
    BuildContext context, T? snapshot);

typedef FutureGenerator<T> = Future<T> Function({required ApiSession session});

class ApiWidget<T> extends StatefulWidget {
  final FutureGenerator<T> future;
  final ApiWidgetBuilder<T> builder;
  final ApiSession session = ApiSession();

  ApiWidget({super.key, required this.future, required this.builder});

  @override
  State<ApiWidget<T>> createState() => _ApiWidgetState();
}

class _ApiWidgetState<T> extends State<ApiWidget<T>> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
        future: widget.future(session: widget.session),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return widget.builder(context, snapshot.data);
          } else if (snapshot.hasError) {
            // TODO: implement better error screen and allow for retry
            return Text('${snapshot.error}');
          }

          // By default, show a loading spinner.
          return const CircularProgressIndicator();
        });
  }
}
