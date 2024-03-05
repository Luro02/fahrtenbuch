import 'package:flutter/material.dart';

Widget loadFuture<T>(
    {required Future<T> future,
    required Widget Function(BuildContext context, T?) builder}) {
  return FutureBuilder<T>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return builder(context, snapshot.data);
      } else if (snapshot.hasError) {
        return Text('${snapshot.error}');
      }

      return const Center(child: CircularProgressIndicator());
    },
  );
}
