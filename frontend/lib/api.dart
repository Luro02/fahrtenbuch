import 'dart:convert';

import 'package:fahrtenbuch/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:memory_cache/memory_cache.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

typedef UserId = int;

extension on MemoryCache {
  T getOrInsertWith<T>(String key, T Function() f, {Duration? expiry}) {
    if (!contains(key)) {
      create(key, f(), expiry: expiry);
    }

    return read(key)!;
  }
}

class ApiSession {
  static final ApiSession _instance = ApiSession._internal();

  final session = Dio();
  final cookieJar = PersistCookieJar();
  final MemoryCache cache = MemoryCache();

  UserId _userId = -1;
  String _username = "";

  factory ApiSession() {
    return _instance;
  }

  String get username => _username;
  UserId get userId => _userId;

  ApiSession._internal() {
    debugPrint("Base URL: $_baseUrl");
    session.interceptors.add(RetryInterceptor(
      dio: session,
      logPrint: debugPrint, // specify log function (optional)
      retries: 3, // retry count (optional)
      retryDelays: const [
        // set delays between retries (optional)
        Duration(seconds: 1), // wait 1 sec before first retry
        Duration(seconds: 2), // wait 2 sec before second retry
        Duration(seconds: 3), // wait 3 sec before third retry
      ],
    ));

    if (!kIsWeb) {
      session.interceptors.add(CookieManager(cookieJar));
    }

    session.options.followRedirects = true;
    session.options.extra["withCredentials"] = true;
  }

  String get _baseUrl => const String.fromEnvironment('API_URL',
      defaultValue: 'https://fahrtenbuch.altenau.eu/api');

  String? deserializeDateTime(DateTime? dateTime) {
    return dateTime != null ? "${dateTime.toIso8601String()}Z" : null;
  }

  Future<bool> get isLoggedIn async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? username = prefs.getString("username");
    String? password = prefs.getString("password");

    if (username != null && password != null) {
      await login(username: username, password: password);
    }

    return _userId != -1;
  }

  Future<dynamic> _request(Future<Response<dynamic>> Function(Dio) f) async {
    try {
      var result = await f(session);
      if (result.data["success"] == false) {
        return Future.error(result.data["message"]);
      }

      return Future.value(result.data["data"]);
    } on DioException catch (e) {
      debugPrint("Request failed: ${e.message}");
      return Future.error(e.message ?? "An error occurred");
    }
  }

  Future<dynamic> _get(String path, {Map<String, dynamic>? json}) {
    json?.removeWhere((key, value) => value == null);
    debugPrint("GET: $_baseUrl/$path");

    return _request(
        (session) => session.get("$_baseUrl/$path", queryParameters: json));
  }

  Future<dynamic> _post(String path, {Map<String, dynamic>? json}) {
    json?.removeWhere((key, value) => value == null);
    debugPrint("POST: $_baseUrl/$path");

    return _request(
        (session) => session.post("$_baseUrl/$path", data: jsonEncode(json)));
  }

  Future<void> _postLogin(
      {required String username, required String password}) async {
    _username = username;
    var userList = await listUsers();
    _userId = userList.keys.firstWhere(
        (element) => userList[element]?.toLowerCase() == username,
        orElse: () => -1);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("username", username);
    await prefs.setString("password", password);
  }

  Future<void> register(
      {required String username, required String password}) async {
    await _post("register", json: {
      "username": username,
      "password": password,
    });

    await _postLogin(username: username, password: password);
  }

  Future<void> login(
      {required String username, required String password}) async {
    await _post("login", json: {
      "username": username,
      "password": password,
    });

    await _postLogin(username: username, password: password);
  }

  Future<void> logout() async {
    await _get("logout");

    _username = "";
    _userId = -1;
  }

  Future<Map<UserId, String>> listUsers() async {
    // the listUsers endpoint is called very often, so we cache the result to reduce the number of requests to the server
    return cache.getOrInsertWith("list_users", () async {
      List<dynamic> r = await _get("list_users");

      return {for (var v in r) v[0]: v[1]};
    }, expiry: const Duration(minutes: 30));
  }

  Future<String> usernameForId(UserId id) async {
    return (await listUsers())[id]!;
  }

  Future<List<Map<String, dynamic>>> listTrips(
      {DateTime? start, DateTime? end, List<UserId> users = const []}) async {
    debugPrint("Listing trips: $start, $end, $users");
    List<dynamic> r = await _get("list_trips", json: {
      "start": deserializeDateTime(start),
      "end": deserializeDateTime(end),
      "users": users,
    });

    debugPrint("List trips: $r");

    return Future.value(r.map((v) => Map<String, dynamic>.from(v)).toList());
  }

  // NOTE: we can not return null, because then the FutureBuilder waits forever for the data.
  //       Therefore we use an empty map as a default value.
  Future<Map<String, dynamic>> lastTrip() async {
    debugPrint("Finding last trip");

    Map<String, dynamic>? lastTrip;
    for (var date in DateHelper.displayDates().values) {
      List<Map<String, dynamic>> trips = await listTrips(
        start: DateHelper.firstDayOfMonth(date),
        end: DateHelper.lastDayOfMonth(date),
      );

      for (var trip in trips) {
        if (lastTrip == null || trip["end"] > lastTrip["end"]) {
          lastTrip = trip;
        }
      }

      if (trips.isNotEmpty) {
        break;
      }
    }

    debugPrint("Returning last trip: $lastTrip");

    return Future.value(lastTrip ?? {});
  }

  Future<List<Map<String, dynamic>>> listExpenses(
      {DateTime? start, DateTime? end, List<UserId> users = const []}) async {
    debugPrint(
        "Listing expenses: ${start?.toIso8601String()}, ${end?.toIso8601String()}, $users");
    var r = await _get("list_expenses", json: {
      "start": deserializeDateTime(start),
      "end": deserializeDateTime(end),
      "users": users,
    });

    debugPrint("List expenses: $r");

    return Future.value(
        (r as List).map((v) => Map<String, dynamic>.from(v)).toList());
  }

  Future<void> addExpense(
      {required double amount,
      String? description,
      required List<UserId> users}) async {
    debugPrint("Adding expense: $amount, $description, $users");
    await _post("add_expense", json: {
      // conver to cents
      "amount": (amount * 100).round(),
      "description": description,
      "users": users,
    });
  }

  Future<void> addTrip(
      {required int start,
      required int end,
      String? description,
      required List<UserId> users}) async {
    debugPrint("Adding trip: $start, $end, $description, $users");
    await _post("add_trip", json: {
      "start": start,
      "end": end,
      "description": description,
      "users": users,
    });
  }

  Future<Map<String, dynamic>> summary(
      {int? userId, DateTime? start, DateTime? end}) async {
    var r = await _get("summary", json: {
      "user": userId ?? _userId,
      "start": deserializeDateTime(start),
      "end": deserializeDateTime(end),
    });

    return Future.value(r);
  }
}
