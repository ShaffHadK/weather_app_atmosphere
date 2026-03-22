import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';
import 'dart:html' as html;


// --- CONFIGURATION ---

const String baseUrl = 'http://localhost:8080';

void main() {
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Atmosphere',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: const LandingScreen(),
    );
  }
}


// --- DATA MODELS ---

class WeatherHistory {
  final int id;
  final String city;
  final String startDate;
  final String endDate;
  final List<dynamic> dates;
  final List<dynamic> maxTemps;
  final List<dynamic> minTemps;
  final List<dynamic> codes;
  final List<dynamic> precip;

  WeatherHistory({
    required this.id, required this.city, required this.startDate, required this.endDate,
    required this.dates, required this.maxTemps, required this.minTemps, required this.codes, required this.precip
  });

  factory WeatherHistory.fromJson(Map<String, dynamic> json) {
    return WeatherHistory(
      id: json['id'],
      city: json['city_name'],
      startDate: json['start_date'],
      endDate: json['end_date'],
      dates: json['dates'] ?? [],
      maxTemps: json['temperatures_max'] ?? [],
      minTemps: json['temperatures_min'] ?? [],
      codes: json['weather_codes'] ?? [],
      precip: json['precipitation_sum'] ?? [],
    );
  }
}


// --- UTILS & HELPERS ---

class NotificationHelper {
  static void show(BuildContext context, String message, {bool isSuccess = true}) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 20,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Row(
                  children: [
                    Icon(isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                        color: isSuccess ? Colors.greenAccent : Colors.redAccent, size: 28),
                    const SizedBox(width: 15),
                    Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 3), () => overlayEntry.remove());
  }
}

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;

  const GlassContainer({
    Key? key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(20.0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: -5,
              )
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}


// --- LANDING SCREEN ---

class LandingScreen extends StatefulWidget {
  const LandingScreen({Key? key}) : super(key: key);

  @override
  _LandingScreenState createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<WeatherHistory> history = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/weather/'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          history = data.map((e) => WeatherHistory.fromJson(e)).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _navigateToMain(String query) async {
    if (query.isNotEmpty) {
      await Navigator.push(context, MaterialPageRoute(builder: (context) => MainWeatherScreen(city: query)));
      _fetchHistory();
    }
  }

  Future<void> _viewSavedGraph(WeatherHistory item) async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => SavedForecastScreen(record: item)));
    _fetchHistory();
  }

  Future<void> _deleteRecord(int id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/weather/$id'));
      if (response.statusCode == 200) {
        _fetchHistory();
        NotificationHelper.show(context, "Record deleted successfully!");
      }
    } catch (e) {
      NotificationHelper.show(context, "Failed to delete record.", isSuccess: false);
    }
  }

  Future<void> _editRecord(WeatherHistory item) async {
    TextEditingController cityController = TextEditingController(text: item.city);
    DateTime start = DateTime.parse(item.startDate);
    DateTime end = DateTime.parse(item.endDate);

    await showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: "Dismiss",
        pageBuilder: (context, anim1, anim2) {
          return Center(
            child: Material(
              color: Colors.transparent,
              child: StatefulBuilder(builder: (context, setDialogState) {
                return GlassContainer(
                  width: 320,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Update Record", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      TextField(
                        controller: cityController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: "City Name or Postal Code",
                          labelStyle: TextStyle(color: Colors.white70),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                        ),
                      ),
                      const SizedBox(height: 25),
                      InkWell(
                        onTap: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            initialDateRange: DateTimeRange(start: start, end: end),
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 14)),
                          );
                          if (picked != null) {
                            if (picked.duration.inDays > 14) {
                              NotificationHelper.show(context, "Please select 14 days or less.", isSuccess: false);
                            } else {
                              setDialogState(() { start = picked.start; end = picked.end; });
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                          decoration: BoxDecoration(border: Border.all(color: Colors.white38), borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.date_range, color: Colors.blueAccent),
                              const SizedBox(width: 10),
                              Text("${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d').format(end)}", style: const TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white70))),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            onPressed: () async {
                              Navigator.pop(context);
                              try {
                                final response = await http.put(
                                  Uri.parse('$baseUrl/weather/${item.id}'),
                                  headers: {'Content-Type': 'application/json'},
                                  body: json.encode({
                                    "city": cityController.text, "start_date": start.toIso8601String().split('T')[0],
                                    "end_date": end.toIso8601String().split('T')[0], "notes": "Updated via Flutter Web"
                                  }),
                                );
                                if (response.statusCode == 200) {
                                  _fetchHistory();
                                  NotificationHelper.show(context, "Record updated successfully!");
                                }
                              } catch (e) {
                                NotificationHelper.show(context, "Failed to update record.", isSuccess: false);
                              }
                            },
                            child: const Text("Save", style: TextStyle(color: Colors.white)),
                          )
                        ],
                      )
                    ],
                  ),
                );
              }),
            ),
          );
        }
    );
  }

  Future<void> _exportFullDatabase() async {
    final Uri url = Uri.parse('$baseUrl/weather/export/csv');
    if (!await launchUrl(url)) {
      NotificationHelper.show(context, "Could not reach export server.", isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset("assets/landing_scrn.jpg", fit: BoxFit.cover, color: Colors.black.withOpacity(0.6), colorBlendMode: BlendMode.darken),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      Text("Atmosphere", style: GoogleFonts.poppins(fontSize: 48, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.5)),
                      Text("Your personal weather intelligence.", style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8))),
                      const SizedBox(height: 40),

                      Hero(
                        tag: 'search_bar',
                        child: GlassContainer(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: Colors.white, fontSize: 18),
                            decoration: InputDecoration(
                              hintText: "City name or Postal Code...",
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                              border: InputBorder.none,
                              icon: const Icon(Icons.search, color: Colors.white, size: 28),
                            ),
                            onSubmitted: _navigateToMain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Recent Intel", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white)),
                          IconButton(icon: const Icon(Icons.download, color: Colors.white70), tooltip: "Export Full Database (CSV)", onPressed: _exportFullDatabase)
                        ],
                      ),
                      const SizedBox(height: 10),

                      Expanded(
                        child: isLoading
                            ? const Center(child: CircularProgressIndicator(color: Colors.white))
                            : history.isEmpty
                            ? Text("No recent searches. Enter a city to begin.", style: TextStyle(color: Colors.white.withOpacity(0.6)))
                            : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: history.length,
                          itemBuilder: (context, index) {
                            final item = history[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: InkWell(
                                onTap: () => _viewSavedGraph(item),
                                borderRadius: BorderRadius.circular(24),
                                child: GlassContainer(
                                  padding: const EdgeInsets.only(left: 20, top: 10, bottom: 10, right: 10),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(item.city.toUpperCase(), style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w600)),
                                            const SizedBox(height: 4),
                                            Text("${item.startDate} to ${item.endDate}", style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                              icon: const Icon(Icons.file_download, color: Colors.greenAccent, size: 22),
                                              tooltip: "Export Record",
                                              onPressed: () async {
                                                final Map<String, dynamic> dataMap = {
                                                  'time': item.dates,
                                                  'temperature_2m_max': item.maxTemps,
                                                  'temperature_2m_min': item.minTemps,
                                                  'weather_code': item.codes,
                                                  'precipitation_sum': item.precip,
                                                };
                                                await GraphBuilder.exportToCsv(context, item.city, dataMap);
                                              }
                                          ),
                                          IconButton(icon: const Icon(Icons.edit, color: Colors.lightBlueAccent, size: 22), onPressed: () => _editRecord(item)),
                                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22), onPressed: () => _deleteRecord(item.id)),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // --- NEW: PM Accelerator Info Card ---
                      const SizedBox(height: 20),
                      GlassContainer(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info_outline, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                const Text("About the Developer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text("Developed by Mohd Shaff Had Khan", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 8),
                            Text("For PM Accelerator", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 15, height: 1.4)),
                            const SizedBox(height: 8),
                            Text("Product Manager Accelerator is a premier program designed to help professionals transition into and excel in product management roles. We provide community, mentorship, and resources to build real-world AI products.", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, height: 1.4)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// --- MAIN WEATHER SCREEN ---

class MainWeatherScreen extends StatefulWidget {
  final String city;
  const MainWeatherScreen({Key? key, required this.city}) : super(key: key);

  @override
  _MainWeatherScreenState createState() => _MainWeatherScreenState();
}

class _MainWeatherScreenState extends State<MainWeatherScreen> {
  Map<String, dynamic>? weatherData;
  bool isLoading = true;
  final ScrollController _forecastScrollController = ScrollController();
  final ScrollController _24forecastScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchLiveWeather();
  }

  @override
  void dispose() {
    _forecastScrollController.dispose();
    _24forecastScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveWeather() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/weather/live?city=${widget.city}'));
      if (response.statusCode == 200) {
        setState(() {
          weatherData = json.decode(response.body);
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        NotificationHelper.show(context, "Location not found.", isSuccess: false);
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => isLoading = false);
      NotificationHelper.show(context, "Server connection failed.", isSuccess: false);
      Navigator.pop(context);
    }
  }

  String _getWeatherImage(int code) {
    if (code <= 3) return "assets/sunny.jpg";
    if (code >= 45 && code <= 48) return "assets/foggy.jpg";
    if (code >= 51 && code <= 67) return "assets/rainy.jpg";
    if (code >= 71 && code <= 77) return "assets/snow.jpg";
    if (code >= 95) return "assets/thunderstorm.jpg";
    return "assets/sunny.jpg";
  }

  IconData _getWeatherIcon(int code) {
    if (code == 0) return Icons.wb_sunny;
    if (code <= 3) return Icons.cloud;
    if (code >= 45 && code <= 48) return Icons.foggy;
    if (code >= 51 && code <= 67) return Icons.water_drop;
    if (code >= 71 && code <= 77) return Icons.ac_unit;
    if (code >= 95) return Icons.flash_on;
    return Icons.cloud;
  }

  String _getWeatherDescription(int code) {
    if (code == 0) return "Clear Sky";
    if (code == 1 || code == 2 || code == 3) return "Partly Cloudy";
    if (code >= 45 && code <= 48) return "Foggy & Misty";
    if (code >= 51 && code <= 57) return "Drizzle";
    if (code >= 61 && code <= 67) return "Rainy";
    if (code >= 71 && code <= 77) return "Snowy";
    if (code >= 80 && code <= 82) return "Rain Showers";
    if (code >= 95) return "Thunderstorms";
    return "Cloudy";
  }

  String _formatDate(String dateString) {
    DateTime date = DateTime.parse(dateString);
    return DateFormat('EEE, d').format(date);
  }

  String _formatTime(String dateString) {
    DateTime date = DateTime.parse(dateString);
    return DateFormat('h a').format(date); // Formats as '2 PM'
  }

  Future<void> _selectCustomDates() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 14)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(primary: Colors.white, onPrimary: Colors.black, surface: Color(0xFF1E1E2C), onSurface: Colors.white),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (picked.duration.inDays > 14) {
        NotificationHelper.show(context, "Please select a range of 14 days or less.", isSuccess: false);
        return;
      }
      await Navigator.push(context, MaterialPageRoute(
          builder: (context) => CustomForecastScreen(city: weatherData!['city_name'], start: picked.start, end: picked.end)
      ));
    }
  }

  Future<void> _openYouTube() async {
    final String city = weatherData!['city_name'].toString().replaceAll(' ', '+');
    final Uri url = Uri.parse('https://www.youtube.com/results?search_query=$city+city+tour+weather');
    if (!await launchUrl(url)) {
      NotificationHelper.show(context, "Could not launch YouTube", isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.white)));

    final current = weatherData!['current'];
    final forecast = weatherData!['forecast_5_day'];
    final hourly = weatherData!['hourly_forecast'];
    final int weatherCode = current['weather_code'];
    final double lat = weatherData!['latitude'];
    final double lng = weatherData!['longitude'];

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(_getWeatherImage(weatherCode), fit: BoxFit.cover, color: Colors.black.withOpacity(0.4), colorBlendMode: BlendMode.darken),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 28), onPressed: () => Navigator.pop(context)),
                          Expanded(child: Text(weatherData!['city_name'].toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 2.0))),
                          IconButton(icon: const Icon(Icons.calendar_month, color: Colors.white, size: 28), onPressed: _selectCustomDates),
                        ],
                      ),
                      const SizedBox(height: 40),

                      Center(
                        child: Column(
                          children: [
                            Icon(_getWeatherIcon(weatherCode), size: 100, color: Colors.white),
                            Text("${current['temperature']}°C", style: GoogleFonts.poppins(fontSize: 100, fontWeight: FontWeight.w200, color: Colors.white, height: 1.0)),

                            Text(
                                _getWeatherDescription(weatherCode).toUpperCase(),
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white70, letterSpacing: 2.0)
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 50),

                      GlassContainer(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatColumn(Icons.air, "AQI", current['aqi']?.toString() ?? "--"),
                            _buildStatColumn(Icons.water_drop, "PRECIP", "${current['precipitation']} mm"),
                            _buildStatColumn(Icons.speed, "GUSTS", "${current['wind_gusts']} km/h"),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      const Text("5-DAY FORECAST", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1.5)),
                      const SizedBox(height: 15),

                      SizedBox(
                        height: 180,
                        child: RawScrollbar(
                          controller: _forecastScrollController, thumbVisibility: true, thumbColor: Colors.white54, radius: const Radius.circular(10), thickness: 4,
                          child: ListView.builder(
                            controller: _forecastScrollController, scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), itemCount: forecast['dates'].length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 16.0, bottom: 15.0),
                                child: GlassContainer(
                                  width: 120, padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_formatDate(forecast['dates'][index]), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                      Icon(_getWeatherIcon(forecast['weather_code'][index]), color: Colors.white, size: 36),
                                      Text("${forecast['max_temp'][index]}° / ${forecast['min_temp'][index]}°", style: const TextStyle(color: Colors.white, fontSize: 14)),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.umbrella, size: 14, color: Colors.lightBlueAccent),
                                          const SizedBox(width: 4),
                                          Text("${forecast['precipitation_prob'][index]}%", style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 14, fontWeight: FontWeight.w600)),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),

                      const Text("24-HOUR FORECAST", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1.5)),
                      const SizedBox(height: 15),

                      SizedBox(
                        height: 160,
                        child: RawScrollbar(
                          controller:_24forecastScrollController,  thumbVisibility: true, thumbColor: Colors.white54, radius: const Radius.circular(10), thickness: 4,
                          child: ListView.builder(
                            controller: _24forecastScrollController, scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), itemCount: hourly['times'].length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 16.0, bottom: 15.0),
                                child: GlassContainer(
                                  width: 90, padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_formatTime(hourly['times'][index]), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                      Icon(_getWeatherIcon(hourly['weather_code'][index]), color: Colors.white, size: 28),
                                      Text("${hourly['temperatures'][index]}°", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.water_drop, size: 12, color: Colors.lightBlueAccent),
                                          const SizedBox(width: 4),
                                          Text("${hourly['precipitation_prob'][index]}%", style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),

                      const Text("AREA OVERVIEW", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1.5)),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: GlassContainer(
                              height: 180,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text("Wind", style: TextStyle(color: Colors.white70, fontSize: 16)),
                                  const SizedBox(height: 10),
                                  Transform.rotate(angle: current['wind_direction'] * 3.14159 / 180, child: const Icon(Icons.navigation, color: Colors.white, size: 40)),
                                  const SizedBox(height: 10),
                                  Text("${current['wind_direction']}°", style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Container(
                              height: 180,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24.0), border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15)],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24.0),
                                child: FlutterMap(
                                  options: MapOptions(center: LatLng(lat, lng), zoom: 11.0, interactiveFlags: InteractiveFlag.drag | InteractiveFlag.pinchZoom),
                                  children: [
                                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.weatherapp'),
                                    MarkerLayer(markers: [Marker(point: LatLng(lat, lng), width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.redAccent, size: 40))])
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),

                      const Text("MEDIA", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1.5)),
                      const SizedBox(height: 15),
                      GlassContainer(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
                                  child: Image.asset("assets/yt_thumbnail.jpg", height: 160, width: double.infinity, fit: BoxFit.cover, color: Colors.black45, colorBlendMode: BlendMode.darken),
                                ),
                                InkWell(
                                  child: Container(
                                    decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.9), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)]),
                                    child: const Icon(Icons.play_arrow, size: 60, color: Colors.white),
                                  ),
                                  onTap: _openYouTube,
                                )
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("City Tours & Weather", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text("YouTube Media Supported", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                                    ],
                                  ),
                                  ElevatedButton(
                                    onPressed: _openYouTube,
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                    child: const Text("See More", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  )
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 30),
        const SizedBox(height: 10),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70, letterSpacing: 1.2)),
      ],
    );
  }
}


// --- CUSTOM FORECAST PREVIEW SCREEN ---

class CustomForecastScreen extends StatefulWidget {
  final String city;
  final DateTime start;
  final DateTime end;

  const CustomForecastScreen({Key? key, required this.city, required this.start, required this.end}) : super(key: key);

  @override
  _CustomForecastScreenState createState() => _CustomForecastScreenState();
}

class _CustomForecastScreenState extends State<CustomForecastScreen> {
  bool isLoading = true;
  Map<String, dynamic>? previewData;

  @override
  void initState() {
    super.initState();
    _fetchPreviewData();
  }

  Future<void> _fetchPreviewData() async {
    try {
      final geoRes = await http.get(Uri.parse("https://geocoding-api.open-meteo.com/v1/search?name=${widget.city}&count=1&format=json"));
      final geoData = json.decode(geoRes.body)['results'][0];

      final startStr = widget.start.toIso8601String().split('T')[0];
      final endStr = widget.end.toIso8601String().split('T')[0];
      final weatherRes = await http.get(Uri.parse(
          "https://api.open-meteo.com/v1/forecast?latitude=${geoData['latitude']}&longitude=${geoData['longitude']}&start_date=$startStr&end_date=$endStr&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum&timezone=auto"
      ));

      setState(() {
        previewData = json.decode(weatherRes.body)['daily'];
        isLoading = false;
      });
    } catch (e) {
      NotificationHelper.show(context, "Error generating preview.", isSuccess: false);
      Navigator.pop(context);
    }
  }

  Future<void> _saveRecord() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/weather/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({"city": widget.city, "start_date": widget.start.toIso8601String().split('T')[0], "end_date": widget.end.toIso8601String().split('T')[0], "notes": "Custom flutter search"}),
      );
      if (response.statusCode == 200) {
        NotificationHelper.show(context, "Saved Successfully!");
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      NotificationHelper.show(context, "Database Network Error.", isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0, centerTitle: true, title: const Text("FORECAST PREVIEW", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
      ),
      floatingActionButton: isLoading ? null : FloatingActionButton.extended(
        onPressed: _saveRecord, backgroundColor: Colors.blueAccent,
        icon: const Icon(Icons.save, color: Colors.white), label: const Text("Save Record", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: isLoading ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.city.toUpperCase(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
              Text("${DateFormat('MMM d, yyyy').format(widget.start)} - ${DateFormat('MMM d, yyyy').format(widget.end)}", style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 40),
              Expanded(
                child: GlassContainer(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: SingleChildScrollView(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), child: GraphBuilder.build(previewData!)),
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}


// --- SAVED GRAPH HISTORY SCREEN ---

class SavedForecastScreen extends StatelessWidget {
  final WeatherHistory record;
  const SavedForecastScreen({Key? key, required this.record}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> dataMap = {
      'time': record.dates,
      'temperature_2m_max': record.maxTemps,
      'temperature_2m_min': record.minTemps,
      'weather_code': record.codes,
      'precipitation_sum': record.precip,
    };

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0, centerTitle: true, title: const Text("HISTORICAL RECORD", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: "Direct Export Record",
            onPressed: () async => await GraphBuilder.exportToCsv(context, record.city, dataMap),
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(record.city.toUpperCase(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
              Text("${record.startDate} to ${record.endDate}", style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 40),
              Expanded(
                child: GlassContainer(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: SingleChildScrollView(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), child: GraphBuilder.build(dataMap)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}


// --- SHARED GRAPH BUILDER UTILITY ---

class GraphBuilder {
  static IconData _getWeatherIcon(int code) {
    if (code == 0) return Icons.wb_sunny;
    if (code <= 3) return Icons.cloud;
    if (code >= 45 && code <= 48) return Icons.foggy;
    if (code >= 51 && code <= 67) return Icons.water_drop;
    if (code >= 71 && code <= 77) return Icons.ac_unit;
    if (code >= 95) return Icons.flash_on;
    return Icons.cloud;
  }

  static Future<void> exportToCsv(BuildContext context, String city, Map<String, dynamic> data) async {
    try {
      final List<dynamic> dates = data['time'];
      final List<double> maxTemps = (data['temperature_2m_max'] as List).map((e) => (e as num?)?.toDouble() ?? 0.0).toList();
      final List<double> minTemps = (data['temperature_2m_min'] as List).map((e) => (e as num?)?.toDouble() ?? 0.0).toList();
      final List<int> codes = (data['weather_code'] as List).map((e) => (e as num?)?.toInt() ?? 0).toList();
      final List<double> precip = (data['precipitation_sum'] as List).map((e) => (e as num?)?.toDouble() ?? 0.0).toList();

      StringBuffer csvData = StringBuffer();
      csvData.writeln("City,Date,Max Temp (C),Min Temp (C),Precipitation (mm),Weather Code");

      for (int i = 0; i < dates.length; i++) {
        DateTime parsedDate = DateTime.parse(dates[i]);
        String formattedDate = DateFormat('MMMM d, yyyy').format(parsedDate);
        csvData.writeln("$city,\"$formattedDate\",${maxTemps[i]},${minTemps[i]},${precip[i]},${codes[i]}");
      }

      final bytes = utf8.encode(csvData.toString());
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);

      final fileName = "${city.replaceAll(' ', '_')}_forecast_${DateTime.now().millisecondsSinceEpoch}.csv";

      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();

      html.Url.revokeObjectUrl(url);

      NotificationHelper.show(context, "Export downloaded successfully!");

    } catch (e) {
      NotificationHelper.show(context, "Export Error: ${e.toString().split('\n')[0]}", isSuccess: false);
    }
  }

  static Widget build(Map<String, dynamic> data) {
    final List<dynamic> dates = data['time'];
    final List<double> maxTemps = (data['temperature_2m_max'] as List).map((e) => (e as num?)?.toDouble() ?? 0.0).toList();
    final List<int> codes = (data['weather_code'] as List).map((e) => (e as num?)?.toInt() ?? 0).toList();
    final List<double> precip = (data['precipitation_sum'] as List).map((e) => (e as num?)?.toDouble() ?? 0.0).toList();
    final double columnWidth = 90.0;

    return SizedBox(
      width: dates.length * columnWidth,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: TempGraphPainter(temps: maxTemps, columnWidth: columnWidth))),
          Row(
            children: List.generate(dates.length, (i) {
              DateTime date = DateTime.parse(dates[i]);
              return SizedBox(
                width: columnWidth,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        Text(DateFormat('EEE').format(date), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                        Text(DateFormat('d').format(date), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        const SizedBox(height: 10),
                        Icon(_getWeatherIcon(codes[i]), color: Colors.white, size: 30),
                      ],
                    ),
                    Padding(padding: const EdgeInsets.only(bottom: 20.0), child: Text("${maxTemps[i]}°", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
                    Column(
                      children: [
                        const Icon(Icons.water_drop, size: 14, color: Colors.lightBlueAccent),
                        Text("${precip[i]}mm", style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              );
            }),
          )
        ],
      ),
    );
  }
}

class TempGraphPainter extends CustomPainter {
  final List<double> temps;
  final double columnWidth;
  TempGraphPainter({required this.temps, required this.columnWidth});

  @override
  void paint(Canvas canvas, Size size) {
    if (temps.isEmpty) return;
    double maxTemp = temps.reduce((curr, next) => curr > next ? curr : next);
    double minTemp = temps.reduce((curr, next) => curr < next ? curr : next);
    double range = maxTemp - minTemp;
    if (range == 0) range = 10;

    double graphHeight = size.height * 0.4;
    double topOffset = size.height * 0.4;

    Offset getPoint(int index) {
      double x = (index * columnWidth) + (columnWidth / 2);
      double normalizedY = 1 - ((temps[index] - minTemp) / range);
      return Offset(x, topOffset + (normalizedY * graphHeight));
    }

    Path linePath = Path()..moveTo(getPoint(0).dx, getPoint(0).dy);
    for (int i = 1; i < temps.length; i++) linePath.lineTo(getPoint(i).dx, getPoint(i).dy);

    Path fillPath = Path.from(linePath)..lineTo(getPoint(temps.length - 1).dx, size.height)..lineTo(getPoint(0).dx, size.height)..close();

    Paint fillPaint = Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white.withOpacity(0.3), Colors.white.withOpacity(0.0)]).createShader(Rect.fromLTRB(0, topOffset, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    Paint linePaint = Paint()..color = Colors.white..strokeWidth = 3.0..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    Paint dotPaint = Paint()..color = Colors.white;
    Paint dotShadow = Paint()..color = Colors.blueAccent.withOpacity(0.5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    for (int i = 0; i < temps.length; i++) {
      canvas.drawCircle(getPoint(i), 6, dotShadow);
      canvas.drawCircle(getPoint(i), 4, dotPaint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
