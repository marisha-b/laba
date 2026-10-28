import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const WeatherApp());

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Погода',
        theme: ThemeData.dark(useMaterial3: true),
        home: const WeatherPage(),
      );
}

class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});
  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  bool loading = true;
  String? error;
  String city = '';
  bool isMyLocation = true;
  double? _lat, _lon;
  Map<String, dynamic>? data;

  @override
  void initState() {
    super.initState();
    _loadMyLocation();
  }

  // ---------- Данные ----------

  Future<Position> _getPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw 'Включите геолокацию на телефоне';
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      throw 'Доступ к местоположению не разрешён';
    }
    if (perm == LocationPermission.deniedForever) {
      throw 'Доступ запрещён навсегда. Разрешите его в настройках телефона';
    }
    return Geolocator.getCurrentPosition();
  }

  String _clean(String s) {
    var r = s
        .replaceAll(RegExp(r'[«»"]'), '')
        .replaceAll(RegExp(r'[Гг]ородской округ'), '')
        .trim();
    r = r.replaceAll(RegExp(r'^([Гг]ород|г\.)\s+'), '').trim();
    return r;
  }

  Future<String> _reverseName(double lat, double lon) async {
    try {
      final res = await http.get(Uri.parse(
          'https://api.bigdatacloud.net/data/reverse-geocode-client'
          '?latitude=$lat&longitude=$lon&localityLanguage=ru'));
      final geo = jsonDecode(res.body);
      final candidates = [geo['city'], geo['locality'], geo['principalSubdivision']]
          .where((e) => e != null)
          .map((e) => _clean(e.toString()))
          .where((e) => e.isNotEmpty)
          .toList();
      for (final c in candidates) {
        final low = c.toLowerCase();
        if (!low.contains('район') && !low.contains('округ') && !low.contains('область')) {
          return c;
        }
      }
      if (candidates.isNotEmpty) return candidates.first;
    } catch (_) {}
    return 'Моё местоположение';
  }

  Future<Map<String, dynamic>> _fetchWeather(double lat, double lon) async {
    final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
        '&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code'
        '&hourly=temperature_2m,weather_code'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max'
        '&timezone=auto&forecast_days=10');
    final res = await http.get(url);
    return jsonDecode(res.body);
  }

  Future<void> _loadMyLocation() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final pos = await _getPosition();
      final results = await Future.wait([
        _fetchWeather(pos.latitude, pos.longitude),
        _reverseName(pos.latitude, pos.longitude),
      ]);
      data = results[0] as Map<String, dynamic>;
      city = results[1] as String;
      _lat = pos.latitude;
      _lon = pos.longitude;
      isMyLocation = true;
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _loadCity(double lat, double lon, String name) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      data = await _fetchWeather(lat, lon);
      city = name;
      _lat = lat;
      _lon = lon;
      isMyLocation = false;
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _refresh() {
    if (isMyLocation || _lat == null) return _loadMyLocation();
    return _loadCity(_lat!, _lon!, city);
  }

  Future<void> _openSearch() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CitySearch(),
    );
    if (picked != null) {
      _loadCity(
        (picked['latitude'] as num).toDouble(),
        (picked['longitude'] as num).toDouble(),
        picked['name'].toString(),
      );
    }
  }

  // ---------- Оформление ----------

  IconData _icon(int code) {
    if (code == 0) return Icons.wb_sunny;
    if (code <= 3) return Icons.cloud;
    if (code == 45 || code == 48) return Icons.foggy;
    if (code >= 71 && code <= 77) return Icons.ac_unit;
    if (code >= 85 && code <= 86) return Icons.ac_unit;
    if (code >= 95) return Icons.thunderstorm;
    return Icons.water_drop;
  }

  Color _iconColor(int code) =>
      code == 0 ? Colors.amber : (code <= 3 ? Colors.white : Colors.lightBlueAccent);

  static const _days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  static const _months = ['янв.', 'фев.', 'мар.', 'апр.', 'мая', 'июн.', 'июл.', 'авг.', 'сен.', 'окт.', 'ноя.', 'дек.'];

  Widget _card({required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B1B3A), Color(0xFF3B2F5C), Color(0xFF1B1B3A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _loadMyLocation,
                      icon: Icon(isMyLocation ? Icons.my_location : Icons.location_searching),
                      label: const Text('Моё местоположение'),
                    ),
                    TextButton.icon(
                      onPressed: _openSearch,
                      icon: const Icon(Icons.search),
                      label: const Text('Поиск города'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Text(error!, textAlign: TextAlign.center),
                                const SizedBox(height: 16),
                                FilledButton(onPressed: _refresh, child: const Text('Повторить')),
                              ]),
                            ),
                          )
                        : RefreshIndicator(onRefresh: _refresh, child: _content()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content() {
    final cur = data!['current'];
    final hourly = data!['hourly'];
    final daily = data!['daily'];

    final times = (hourly['time'] as List).cast<String>();
    var start = times.indexWhere((t) => t.compareTo(cur['time']) >= 0);
    if (start < 0) start = 0;
    final hourIdx = [for (var i = start; i < times.length && i < start + 21; i += 3) i];

    final dTimes = (daily['time'] as List).cast<String>();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        Center(
          child: Text(city,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w500)),
        ),
        Center(
          child: Text('${(cur['temperature_2m'] as num).round()}°',
              style: const TextStyle(fontSize: 96, fontWeight: FontWeight.w200)),
        ),
        Center(
          child: Text(
            'Макс. ${(daily['temperature_2m_max'][0] as num).round()}°  '
            'Мин. ${(daily['temperature_2m_min'][0] as num).round()}°',
            style: const TextStyle(fontSize: 18),
          ),
        ),
        const SizedBox(height: 24),
        _card(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ПОЧАСОВОЙ ПРОГНОЗ', style: TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final i in hourIdx)
                    Padding(
                      padding: const EdgeInsets.only(right: 24),
                      child: Column(children: [
                        Text('${DateTime.parse(times[i]).hour} ч'),
                        const SizedBox(height: 8),
                        Icon(_icon(hourly['weather_code'][i]),
                            color: _iconColor(hourly['weather_code'][i])),
                        const SizedBox(height: 8),
                        Text('${(hourly['temperature_2m'][i] as num).round()}°',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ]),
                    ),
                ],
              ),
            ),
          ]),
        ),
        _card(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('10-ДНЕВНЫЙ ПРОГНОЗ', style: TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 8),
            for (var i = 0; i < dTimes.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  SizedBox(
                    width: 70,
                    child: Builder(builder: (_) {
                      final d = DateTime.parse(dTimes[i]);
                      return Text(
                        '${i == 0 ? 'Сег' : _days[d.weekday - 1]}\n${d.day} ${_months[d.month - 1]}',
                        style: const TextStyle(fontSize: 14),
                      );
                    }),
                  ),
                  Icon(_icon(daily['weather_code'][i]), color: _iconColor(daily['weather_code'][i])),
                  const SizedBox(width: 8),
                  Text('${daily['precipitation_probability_max'][i] ?? 0} %',
                      style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  const Spacer(),
                  Text('${(daily['temperature_2m_min'][i] as num).round()}°',
                      style: const TextStyle(color: Colors.white70)),
                  const SizedBox(width: 12),
                  Text('${(daily['temperature_2m_max'][i] as num).round()}°',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
              ),
          ]),
        ),
        Row(children: [
          Expanded(
            child: _card(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('ВЛАЖНОСТЬ', style: TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 8),
                Text('${cur['relative_humidity_2m']} %', style: const TextStyle(fontSize: 36)),
              ]),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _card(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('ОЩУЩАЕТСЯ', style: TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 8),
                Text('${(cur['apparent_temperature'] as num).round()}°',
                    style: const TextStyle(fontSize: 36)),
              ]),
            ),
          ),
        ]),
      ],
    );
  }
}

// ---------- Поиск города ----------

class _CitySearch extends StatefulWidget {
  const _CitySearch();
  @override
  State<_CitySearch> createState() => _CitySearchState();
}

class _CitySearchState extends State<_CitySearch> {
  List<Map<String, dynamic>> results = [];
  bool searching = false;
  String? message;
  int _counter = 0;

  Future<void> _search(String q) async {
    q = q.trim();
    final my = ++_counter;
    if (q.length < 2) {
      setState(() {
        results = [];
        message = null;
      });
      return;
    }
    setState(() => searching = true);
    try {
      final res = await http.get(Uri.parse(
          'https://geocoding-api.open-meteo.com/v1/search'
          '?name=${Uri.encodeComponent(q)}&count=8&language=ru&format=json'));
      if (my != _counter) return; // пришёл устаревший ответ
      final json = jsonDecode(res.body);
      final list = (json['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      setState(() {
        results = list;
        message = list.isEmpty ? 'Ничего не найдено' : null;
      });
    } catch (e) {
      if (my != _counter) return;
      setState(() {
        results = [];
        message = 'Не удалось выполнить поиск. Проверьте интернет';
      });
    }
    if (mounted && my == _counter) setState(() => searching = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Введите название города',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            if (message != null)
              Padding(padding: const EdgeInsets.all(16), child: Text(message!)),
            Expanded(
              child: ListView.builder(
                itemCount: results.length,
                itemBuilder: (_, i) {
                  final r = results[i];
                  final sub = [r['admin1'], r['country']]
                      .where((e) => e != null && e.toString().isNotEmpty)
                      .join(', ');
                  return ListTile(
                    leading: const Icon(Icons.location_city),
                    title: Text(r['name'].toString()),
                    subtitle: Text(sub),
                    onTap: () => Navigator.pop(context, r),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}