import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:fl_chart/fl_chart.dart';

import 'auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static _MyAppState of(BuildContext context) => 
      context.findAncestorStateOfType<_MyAppState>()!;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _isLoadingAuth = true;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final user = await AuthService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
        _isLoadingAuth = false;
      });
    }
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('theme_mode');
    if (savedTheme != null) {
      setState(() {
        if (savedTheme == 'light') _themeMode = ThemeMode.light;
        else if (savedTheme == 'dark') _themeMode = ThemeMode.dark;
        else _themeMode = ThemeMode.system;
      });
    }
  }

  Future<void> toggleTheme(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_themeMode == ThemeMode.system) {
        bool isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
        _themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
      } else {
        _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
      }
    });
    await prefs.setString('theme_mode', _themeMode == ThemeMode.light ? 'light' : 'dark');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutriLens AI',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF9F6F0),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF4A2E1B),
          secondary: Color(0xFF4A2E1B),
          surface: Colors.white,
          background: Color(0xFFF9F6F0),
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD4B996),
          secondary: Color(0xFFD4B996),
          surface: Color(0xFF1E1E1E),
          background: Color(0xFF121212),
        ),
        useMaterial3: true,
      ),
      home: _isLoadingAuth
          ? const Scaffold(
              backgroundColor: Color(0xFFF9F6F0),
              body: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF4A2E1B),
                ),
              ),
            )
          : (_currentUser == null
              ? LoginScreen(
                  onLoginSuccess: _checkAuth,
                )
              : OcrScreen(
                  user: _currentUser,
                  onLogout: () {
                    setState(() {
                      _currentUser = null;
                    });
                  },
                  onProfileUpdated: _checkAuth,
                )),
    );
  }
}

class OcrScreen extends StatefulWidget {
  final UserModel? user;
  final VoidCallback onLogout;
  final VoidCallback onProfileUpdated;

  const OcrScreen({
    super.key,
    this.user,
    required this.onLogout,
    required this.onProfileUpdated,
  });

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  XFile? _image;
  Uint8List? _imageBytes;
  String _recognizedText = "No text recognized yet.";
  String _rawText = "";
  Map<String, dynamic>? _dashboardData;
  bool _isRecognizing = false;
  String _apiUrl = "https://web-production-d4a30.up.railway.app/mob-backend/api/ocr/";

  final ImagePicker _picker = ImagePicker();
  final TextEditingController _reqIdController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  WebSocketChannel? _channel;

  bool _useDoubleLayer = false;

  @override
  void dispose() {
    _channel?.sink.close();
    _reqIdController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiUrl = prefs.getString('api_url') ?? "https://web-production-d4a30.up.railway.app/mob-backend/api/ocr/";
      _useDoubleLayer = prefs.getBool('use_double_layer') ?? false;
      _cityController.text = prefs.getString('user_city') ?? "";
      _stateController.text = prefs.getString('user_state') ?? "";
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      final prefs = await SharedPreferences.getInstance();
      final savedCity = prefs.getString('user_city') ?? _cityController.text.trim();
      final hasAsked = prefs.getBool('location_dialog_asked') ?? false;

      // Ek baar pooch liya ya city already saved hai toh direct process karo
      if (savedCity.isNotEmpty || hasAsked) {
        _startProcessing(pickedFile);
      } else {
        _showLocationDialog(pickedFile);
      }
    }
  }

  Future<void> _showLocationDialog([XFile? image]) async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF3E2723);
    final Color primaryColor = isDark ? const Color(0xFFD4B996) : const Color(0xFF4A2E1B);
    final Color inputBgColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3EFE6);
    final Color inputHintColor = isDark ? Colors.white30 : const Color(0xFFAFA493);

    // Moved outside builder so it persists across rebuilds
    bool isLoadingLocation = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: bgColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Enhance your insights',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 20),
            textAlign: TextAlign.center,
          ),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setStateDialog) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Enter your location to get personalized Ayurvedic and climate-synced health warnings.',
                    style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  // Auto-detect button
                  InkWell(
                    onTap: () async {
                      setStateDialog(() { isLoadingLocation = true; });
                      try {
                        var response = await http.get(Uri.parse('https://get.geojs.io/v1/ip/geo.json')).timeout(const Duration(seconds: 4));
                        if (response.statusCode == 200) {
                          final data = jsonDecode(response.body);
                          if (data['city'] != null) _cityController.text = data['city'];
                          if (data['region'] != null) _stateController.text = data['region'];
                        } else {
                          // Fallback provider
                          response = await http.get(Uri.parse('https://ipapi.co/json/')).timeout(const Duration(seconds: 4));
                          if (response.statusCode == 200) {
                            final data = jsonDecode(response.body);
                            if (data['city'] != null) _cityController.text = data['city'];
                            if (data['region'] != null) _stateController.text = data['region'];
                          }
                        }
                      } catch (e) {
                        // Ignore errors and let user type manually
                      }
                      setStateDialog(() { isLoadingLocation = false; });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: primaryColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isLoadingLocation)
                            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor))
                          else
                            Icon(Icons.my_location, color: primaryColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            isLoadingLocation ? 'Detecting via IP...' : 'Auto-Detect Location',
                            style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '💡 Auto-detect uses your network IP. If incorrect, type your exact city below.',
                    style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _cityController,
                    onChanged: (_) => setStateDialog(() {}),
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'City (e.g., Mumbai, Nagpur, Pune)',
                      hintStyle: TextStyle(color: inputHintColor),
                      filled: true,
                      fillColor: inputBgColor,
                      prefixIcon: Icon(Icons.location_city_outlined, color: primaryColor, size: 20),
                      suffixIcon: _cityController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: textColor.withOpacity(0.5), size: 18),
                              onPressed: () {
                                _cityController.clear();
                                setStateDialog(() {});
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _stateController,
                    onChanged: (_) => setStateDialog(() {}),
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'State (e.g., Maharashtra)',
                      hintStyle: TextStyle(color: inputHintColor),
                      filled: true,
                      fillColor: inputBgColor,
                      prefixIcon: Icon(Icons.map_outlined, color: primaryColor, size: 20),
                      suffixIcon: _stateController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: textColor.withOpacity(0.5), size: 18),
                              onPressed: () {
                                _stateController.clear();
                                setStateDialog(() {});
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ],
              );
            }
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('location_dialog_asked', true);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                if (image != null) _startProcessing(image);
              },
              child: Text('Skip', style: TextStyle(color: textColor.withOpacity(0.6), fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('location_dialog_asked', true);
                await prefs.setString('user_city', _cityController.text.trim());
                await prefs.setString('user_state', _stateController.text.trim());
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                if (image != null) {
                  _startProcessing(image);
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_cityController.text.trim().isNotEmpty
                          ? 'Location set to ${_cityController.text.trim()}!'
                          : 'Location preference saved!'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                elevation: 0,
              ),
              child: Text(
                image != null ? 'Analyze' : 'Save',
                style: TextStyle(
                  color: isDark ? const Color(0xFF121212) : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startProcessing(XFile image) async {
    final bytes = await image.readAsBytes();
    setState(() {
      _image = image;
      _imageBytes = bytes;
      _recognizedText = "Uploading and processing image...\nThis may take a few seconds.";
      _rawText = "";
      _isRecognizing = true;
    });
    AuthService.incrementScanCount();
    widget.onProfileUpdated();
    await _processImageOnBackend(image, bytes);
  }

  Future<void> _processImageOnBackend(XFile image, Uint8List imageBytes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_city', _cityController.text.trim());
      await prefs.setString('user_state', _stateController.text.trim());
      
      var request = http.MultipartRequest('POST', Uri.parse(_apiUrl));
      
      String filename = image.name;
      if (filename.isEmpty) filename = 'upload.jpg';
      
      request.files.add(http.MultipartFile.fromBytes(
        'image', 
        imageBytes,
        filename: filename,
      ));
      
      request.fields['use_double_layer'] = _useDoubleLayer ? 'true' : 'false';
      request.fields['city'] = _cityController.text.trim();
      request.fields['state'] = _stateController.text.trim();
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        String requestId = jsonResponse['request_id'];
        
        setState(() {
          _dashboardData = null;
          _recognizedText = "Image submitted. Connecting to WebSocket...";
        });
        
        _connectWebSocket(requestId);
      } else {
        setState(() {
            _recognizedText = "Error from server: ${response.statusCode}\n${response.body}";
            _isRecognizing = false;
        });
      }
    } catch (e) {
      setState(() {
        _recognizedText = "Network error: $e\n\nMake sure the Django server is running and accessible at $_apiUrl";
        _isRecognizing = false;
      });
    }
  }

  void _connectWebSocket(String requestId) {
    String wsUrl = _apiUrl.replaceFirst('https', 'wss').replaceFirst('http', 'ws');
    wsUrl = wsUrl.replaceAll('/api/ocr/', '/ws/ocr/$requestId/');
    
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    // Timeout: if no result in 2 minutes, stop waiting
    Future.delayed(const Duration(minutes: 2), () {
      if (_isRecognizing && mounted) {
        setState(() {
          _recognizedText = "Request timed out. You can try fetching the result later using the Request ID.";
          _isRecognizing = false;
        });
        _channel?.sink.close();
      }
    });
    
    _channel!.stream.listen((message) {
      final decoded = jsonDecode(message);
      
      if (decoded['status'] == 'success' || decoded['status'] == 'partial') {
        setState(() {
          _rawText = decoded['raw_text']?.toString() ?? '';
          if (decoded['is_structured'] == true) {
            _dashboardData = decoded['data'];
            _recognizedText = "Parsed successfully!";
          } else {
            _dashboardData = null;
            _recognizedText = decoded['data'] != null ? decoded['data'].toString() : "Success but no text returned";
            if (decoded['error_detail'] != null) {
              _recognizedText += "\n\nNote: ${decoded['error_detail']}";
            }
          }
          _isRecognizing = false;
        });
        _channel?.sink.close();
      } else if (decoded['error'] != null) {
        setState(() {
          _recognizedText = "Error: ${decoded['error']}";
          _isRecognizing = false;
        });
        _channel?.sink.close();
      } else {
        setState(() {
          _recognizedText = "Status: ${decoded['status']}\n${decoded['message']}";
        });
      }
    }, onError: (error) {
      setState(() {
        _recognizedText = "WebSocket Error: $error";
        _isRecognizing = false;
      });
    }, onDone: () {
      if (_isRecognizing) {
        setState(() {
          _recognizedText += "\n\nConnection closed.";
          _isRecognizing = false;
        });
      }
    });
  }

  Future<void> _fetchExistingResult() async {
    final reqId = _reqIdController.text.trim();
    if (reqId.isEmpty) return;

    setState(() {
      _isRecognizing = true;
      _recognizedText = "Fetching from server...";
      _rawText = "";
      _dashboardData = null;
    });

    try {
      String fetchUrl = _apiUrl.replaceAll('ocr/', 'fetch/$reqId/');
      final city = _cityController.text.trim();
      final state = _stateController.text.trim();
      if (city.isNotEmpty || state.isNotEmpty) {
        fetchUrl += '?city=${Uri.encodeComponent(city)}&state=${Uri.encodeComponent(state)}';
      }
      final response = await http.get(Uri.parse(fetchUrl));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == 'success' || decoded['status'] == 'partial') {
          setState(() {
            _rawText = decoded['raw_text']?.toString() ?? '';
            if (decoded['is_structured'] == true) {
              _dashboardData = decoded['data'];
              _recognizedText = '';
            } else {
              _dashboardData = null;
              _recognizedText = decoded['data'] != null ? decoded['data'].toString() : "Success but no text returned";
              if (decoded['error_detail'] != null) {
                _recognizedText += "\n\nNote: ${decoded['error_detail']}";
              }
            }
            _isRecognizing = false;
          });
        } else {
          setState(() {
            _recognizedText = "Error: ${decoded['error'] ?? decoded['message'] ?? 'Unknown error'}";
            _isRecognizing = false;
          });
        }
      } else {
        setState(() {
          _recognizedText = "Server Error: ${response.body}";
          _isRecognizing = false;
        });
      }
    } catch (e) {
      setState(() {
        _recognizedText = "Network Error: $e";
        _isRecognizing = false;
      });
    }
  }

  void _resetState() {
    setState(() {
      _image = null;
      _imageBytes = null;
      _rawText = "";
      _dashboardData = null;
      _recognizedText = "No text recognized yet.";
      _reqIdController.clear();
      _isRecognizing = false;
    });
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          currentUrl: _apiUrl,
          useDoubleLayer: _useDoubleLayer,
          onSettingsChanged: (newUrl, newUseDoubleLayer) {
            setState(() {
              _apiUrl = newUrl;
              _useDoubleLayer = newUseDoubleLayer;
            });
          },
        ),
      ),
    );
  }

  void _openProfile() {
    if (widget.user != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(
            user: widget.user!,
            onLogout: widget.onLogout,
            onProfileUpdated: widget.onProfileUpdated,
          ),
        ),
      );
    }
  }

  void _openNutritionShutter() {
    _openChartShutter();
  }

  void _openChartShutter([dynamic viz]) {
    if (_dashboardData == null) return;
    final List allViz = (_dashboardData!['visualizations'] as List?) ?? [];
    if (viz == null && allViz.isEmpty) return;

    final targetViz = viz ?? allViz.first;
    final String title = viz != null 
        ? (viz['title']?.toString() ?? 'Nutrition Details')
        : 'All Nutrition Charts & Details';
    final List<dynamic> data = (viz != null ? viz['data'] : targetViz['data']) ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (BuildContext sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: _borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(_isDark ? 0.7 : 0.2),
                    blurRadius: 30,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Shutter Handle Bar
                  const SizedBox(height: 12),
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _textSecondaryColor.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Shutter Header
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: _hPad),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(_isCompact ? 8 : 10),
                                decoration: BoxDecoration(
                                  color: _primaryColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(Icons.bar_chart_rounded, color: _primaryColor, size: _iconSm),
                              ),
                              SizedBox(width: _isCompact ? 10 : 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: TextStyle(
                                        fontSize: _titleFs,
                                        fontWeight: FontWeight.bold,
                                        color: _textColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      viz != null
                                          ? 'Complete Data & Graph (${data.length} items)'
                                          : '${allViz.length} Charts & Full Breakdown',
                                      style: TextStyle(fontSize: _smallFs, color: _textSecondaryColor),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: _inputBgColor,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(Icons.close_rounded, color: _textColor, size: _iconSm),
                            onPressed: () => Navigator.pop(sheetContext),
                            tooltip: 'Close Shutter',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: _borderColor),

                  // Scrollable Body inside Shutter
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.symmetric(horizontal: _hPad, vertical: _isCompact ? 10.0 : 16.0),
                      children: [
                        if (viz != null)
                          _buildChartSection(viz, isInsideSheet: true)
                        else
                          ...allViz.map((v) => _buildChartSection(v, isInsideSheet: true)),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Helper variables for colors
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bgColor => _isDark ? const Color(0xFF121212) : const Color(0xFFF9F6F0);
  Color get _surfaceColor => _isDark ? const Color(0xFF1E1E1E) : Colors.white;
  Color get _primaryColor => _isDark ? const Color(0xFFD4B996) : const Color(0xFF4A2E1B);
  Color get _onPrimaryColor => _isDark ? const Color(0xFF121212) : Colors.white;
  Color get _textColor => _isDark ? Colors.white : const Color(0xFF3E2723);
  Color get _textSecondaryColor => _isDark ? Colors.white54 : const Color(0xFF8D7B68);
  Color get _borderColor => _isDark ? Colors.white10 : const Color(0xFFEBE3D5);
  Color get _inputBgColor => _isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3EFE6);
  Color get _inputHintColor => _isDark ? Colors.white30 : const Color(0xFFAFA493);

  // ── Responsive sizing helpers ──
  double get _sw => MediaQuery.of(context).size.width;
  bool get _isCompact => _sw < 360;
  bool get _isWide => _sw > 500;
  double get _hPad => _isCompact ? 14 : (_isWide ? 28 : 20);  // horizontal page padding
  double get _cardPad => _isCompact ? 14 : (_isWide ? 24 : 18);  // card internal padding
  double get _cardMargin => _isCompact ? 10 : 14;  // gap between cards
  double get _cardRadius => _isCompact ? 18 : 24;  // border radius
  double get _titleFs => _isCompact ? 15 : (_isWide ? 20 : 17);  // section title font size
  double get _bodyFs => _isCompact ? 13 : (_isWide ? 16 : 14);  // body text font size
  double get _smallFs => _isCompact ? 10 : (_isWide ? 13 : 11);  // small/label font size
  double get _iconSm => _isCompact ? 18 : 22;  // small icons
  double get _iconMd => _isCompact ? 24 : 28;  // medium icons
  double get _chipPadH => _isCompact ? 8 : 12;  // chip horizontal padding
  double get _chipPadV => _isCompact ? 6 : 8;   // chip vertical padding
  double get _chartH => _isCompact ? 180 : (_isWide ? 260 : 200);  // chart height
  double get _healthBadgeSize => _isCompact ? 48 : (_isWide ? 68 : 56);  // health badge circle

  Widget _buildRawTextCard() {
    return Container(
      margin: EdgeInsets.only(top: _cardMargin),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: _borderColor),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: _primaryColor,
          collapsedIconColor: _textSecondaryColor,
          title: Text('Raw OCR Text', style: TextStyle(fontSize: _bodyFs + 1, fontWeight: FontWeight.w600, color: _textColor)),
          subtitle: Text(
            _rawText.replaceAll('\n', ' '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: _textSecondaryColor, fontSize: _smallFs),
          ),
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(_cardPad),
              decoration: BoxDecoration(
                color: _inputBgColor,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(_cardRadius), bottomRight: Radius.circular(_cardRadius)),
              ),
              child: SelectableText(_rawText, style: TextStyle(color: _textColor.withOpacity(0.8), height: 1.5, fontSize: _bodyFs)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthIndices(dynamic indices) {
    if (indices == null) return const SizedBox.shrink();
    
    return Container(
      padding: EdgeInsets.all(_cardPad),
      margin: EdgeInsets.only(bottom: _cardMargin),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Health Ratings', style: TextStyle(fontSize: _titleFs, fontWeight: FontWeight.w600, color: _textColor)),
          SizedBox(height: _isCompact ? 16 : 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHealthBadge('Baby', indices['baby']),
              _buildHealthBadge('Adult', indices['adult']),
              _buildHealthBadge('Senior', indices['senior']),
            ],
          ),
          if (indices['baby']?['reason'] != null && indices['baby']['reason'].toString().isNotEmpty) ...[
            SizedBox(height: _isCompact ? 10 : 16),
            Container(
              padding: EdgeInsets.all(_isCompact ? 8 : 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: _iconSm),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Baby/Toddler Note: ${indices['baby']['reason']}',
                      style: TextStyle(color: Colors.orange, fontSize: _smallFs + 1, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildHealthBadge(String title, dynamic data) {
    if (data == null) return const SizedBox.shrink();
    
    final int score = data['score'] ?? 0;
    final String rating = data['rating'] ?? 'Unknown';
    
    Color badgeColor;
    if (score >= 8) badgeColor = Colors.green;
    else if (score >= 6) badgeColor = Colors.blue;
    else if (score >= 4) badgeColor = Colors.orange;
    else badgeColor = Colors.red;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: _healthBadgeSize,
            height: _healthBadgeSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: badgeColor, width: _isCompact ? 3 : 4),
            ),
            child: Center(
              child: Text(
                '$score',
                style: TextStyle(
                  fontSize: _isCompact ? 17 : (_isWide ? 24 : 20),
                  fontWeight: FontWeight.w800,
                  color: _textColor,
                ),
              ),
            ),
          ),
          SizedBox(height: _isCompact ? 8 : 12),
          Text(
            title,
            style: TextStyle(
              fontSize: _bodyFs,
              fontWeight: FontWeight.w700,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: EdgeInsets.symmetric(horizontal: _chipPadH, vertical: _chipPadV - 2),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              rating,
              style: TextStyle(
                fontSize: _smallFs,
                fontWeight: FontWeight.w700,
                color: badgeColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_dashboardData!['ayurvedic_insight'] != null && _dashboardData!['ayurvedic_insight'].toString().isNotEmpty)
          Container(
            padding: EdgeInsets.all(_cardPad),
            margin: EdgeInsets.only(bottom: _cardMargin),
            decoration: BoxDecoration(
              color: const Color(0xFF8B7355).withOpacity(0.1),
              borderRadius: BorderRadius.circular(_cardRadius),
              border: Border.all(color: const Color(0xFF8B7355).withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.wb_sunny_outlined, color: const Color(0xFF8B7355), size: _iconMd),
                SizedBox(width: _isCompact ? 10 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Ayurvedic Insight', style: TextStyle(color: const Color(0xFF8B7355), fontSize: _smallFs + 1, fontWeight: FontWeight.bold)),
                          if (_dashboardData!['climate_info'] != null && _dashboardData!['climate_info']['temperature'] != null)
                            GestureDetector(
                              onTap: () => _showLocationDialog(),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: _chipPadH, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B7355).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.thermostat_outlined, size: _smallFs + 2, color: const Color(0xFF8B7355)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_dashboardData!['climate_info']['city'] != '' ? "${_dashboardData!['climate_info']['city']} • " : ""}${_dashboardData!['climate_info']['temperature']}°C',
                                      style: TextStyle(color: const Color(0xFF8B7355), fontSize: _smallFs, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.edit_outlined, size: _smallFs, color: const Color(0xFF8B7355)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: _isCompact ? 4 : 6),
                      Text(
                        _dashboardData!['ayurvedic_insight'].toString(),
                        style: TextStyle(color: _textColor, fontSize: _bodyFs, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
        if (_dashboardData!['health_indices'] != null)
          _buildHealthIndices(_dashboardData!['health_indices']),
        if (_dashboardData!['is_veg'] != null && _dashboardData!['is_veg'] != 'Unknown')
          Container(
            padding: EdgeInsets.symmetric(horizontal: _cardPad, vertical: _isCompact ? 12 : 16),
            margin: EdgeInsets.only(bottom: _cardMargin),
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(_cardRadius),
              border: Border.all(color: _borderColor),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(_isCompact ? 8 : 12),
                  decoration: BoxDecoration(
                    color: _dashboardData!['is_veg'].toString().toLowerCase() == 'veg' 
                        ? Colors.green.withOpacity(0.15) 
                        : Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(_isCompact ? 12 : 16),
                  ),
                  child: Icon(
                    _dashboardData!['is_veg'].toString().toLowerCase() == 'veg' ? Icons.eco : Icons.local_dining,
                    color: _dashboardData!['is_veg'].toString().toLowerCase() == 'veg' ? Colors.green : Colors.red,
                    size: _iconMd,
                  ),
                ),
                SizedBox(width: _isCompact ? 10 : 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dietary Preference', style: TextStyle(color: _textSecondaryColor, fontSize: _smallFs + 1)),
                    const SizedBox(height: 4),
                    Text(
                      _dashboardData!['is_veg'].toString().toUpperCase(),
                      style: TextStyle(
                        fontSize: _titleFs,
                        fontWeight: FontWeight.w600,
                        color: _dashboardData!['is_veg'].toString().toLowerCase() == 'veg' ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
        if (_dashboardData!['allergens'] != null && (_dashboardData!['allergens'] as List).isNotEmpty)
          _buildTagList('Allergens Warning', _dashboardData!['allergens'] as List, Colors.orange, Icons.warning_amber_rounded),
          
        if (_dashboardData!['health_warnings'] != null && (_dashboardData!['health_warnings'] as List).isNotEmpty)
          _buildTagList('Health Alerts', _dashboardData!['health_warnings'] as List, Colors.red, Icons.error_outline),
          
        // Charts displayed directly on the screen (showing top 3 items, with shutter for >3 items)
        if (_dashboardData!['visualizations'] != null)
          ...(_dashboardData!['visualizations'] as List).map((viz) => _buildChartSection(viz)),

        if (_dashboardData!['ingredients_list'] != null && (_dashboardData!['ingredients_list'] as List).isNotEmpty)
          _buildTagList('Ingredients', _dashboardData!['ingredients_list'] as List, _textColor, Icons.science_outlined, isMuted: true),

        if (_dashboardData!['fssai_license'] != null && _dashboardData!['fssai_license'].toString().isNotEmpty)
          Container(
            padding: EdgeInsets.all(_cardPad),
            margin: EdgeInsets.only(bottom: _cardMargin),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(_cardRadius),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_user_outlined, color: Colors.blue, size: _iconMd),
                SizedBox(width: _isCompact ? 10 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FSSAI License', style: TextStyle(color: Colors.blue, fontSize: _smallFs + 1)),
                      const SizedBox(height: 4),
                      Text(
                        _dashboardData!['fssai_license'].toString(),
                        style: TextStyle(fontWeight: FontWeight.w600, color: _textColor, fontSize: _bodyFs),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTagList(String title, List items, Color color, IconData icon, {bool isMuted = false}) {
    return Container(
      padding: EdgeInsets.all(_cardPad),
      margin: EdgeInsets.only(bottom: _cardMargin),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: _iconSm),
              SizedBox(width: _isCompact ? 6 : 10),
              Expanded(child: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: _titleFs - 1))),
            ],
          ),
          SizedBox(height: _isCompact ? 10 : 16),
          Wrap(
            spacing: _isCompact ? 6.0 : 8.0,
            runSpacing: _isCompact ? 6.0 : 8.0,
            children: items.map((item) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: _chipPadH, vertical: _chipPadV),
                decoration: BoxDecoration(
                  color: isMuted ? _inputBgColor : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isMuted ? Colors.transparent : color.withOpacity(0.2)),
                ),
                child: Text(
                  item.toString(),
                  style: TextStyle(
                    color: isMuted ? _textColor.withOpacity(0.8) : color,
                    fontWeight: isMuted ? FontWeight.normal : FontWeight.w600,
                    fontSize: _smallFs + 1,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(dynamic viz, {bool isInsideSheet = false}) {
    final String type = viz['chart_type']?.toString() ?? '';
    final String title = viz['title']?.toString() ?? 'Chart';
    final List<dynamic> data = viz['data'] ?? [];

    if (data.isEmpty) return const SizedBox.shrink();

    Widget chartWidget = const SizedBox.shrink();
    
    // Adjusted chart colors to work in both light and dark, coffee-inspired
    final List<Color> chartColors = [
      _primaryColor,
      const Color(0xFF8B7355),
      const Color(0xFFA58B6E),
      const Color(0xFFD4B996),
      const Color(0xFFE8D5C4),
      const Color(0xFFC0A68D),
    ];

    if (type == 'pie_chart') {
      chartWidget = SizedBox(
        height: _chartH,
        child: PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: _isCompact ? 35 : (_isWide ? 55 : 45),
            sections: data.asMap().entries.map((entry) {
              int idx = entry.key;
              var item = entry.value;
              double val = 0.0;
              if (item is Map && item['value'] != null) {
                if (item['value'] is num) {
                  val = (item['value'] as num).toDouble();
                } else {
                  val = double.tryParse(item['value'].toString()) ?? 0.0;
                }
              }
              String unit = item is Map ? (item['unit']?.toString() ?? '') : '';
              return PieChartSectionData(
                value: val > 0 ? val : 1,
                title: '$val$unit',
                radius: _isCompact ? 30 : 40,
                titleStyle: TextStyle(fontSize: _smallFs, fontWeight: FontWeight.w600, color: _isDark ? const Color(0xFF121212) : Colors.white),
                color: chartColors[idx % chartColors.length],
              );
            }).toList(),
          )
        )
      );
    } else if (type == 'bar_chart') {
      double maxDataVal = 0.0;
      for (var item in data) {
        if (item is Map && item['value'] != null) {
          double v = item['value'] is num
              ? (item['value'] as num).toDouble()
              : (double.tryParse(item['value'].toString()) ?? 0.0);
          if (v > maxDataVal) maxDataVal = v;
        }
      }
      final double computedMaxY = maxDataVal > 0 ? (maxDataVal * 1.2) : 100.0;

      final barChartWidget = BarChart(
        BarChartData(
          maxY: computedMaxY,
          alignment: BarChartAlignment.spaceAround,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, 
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: TextStyle(color: _textSecondaryColor, fontSize: 10)),
            )),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true, 
                reservedSize: 60,
                getTitlesWidget: (double value, TitleMeta meta) {
                  if (value.toInt() >= 0 && value.toInt() < data.length) {
                    String label = data[value.toInt()]['label']?.toString() ?? '';
                    if (label.length > 10) label = '${label.substring(0, 8)}..';
                    return Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Transform.rotate(
                        angle: -0.5,
                        child: Text(
                          label, 
                          style: TextStyle(fontSize: 10, color: _textColor.withOpacity(0.8)),
                          textAlign: TextAlign.center,
                        )
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(color: _borderColor, strokeWidth: 1),
          ),
          barGroups: data.asMap().entries.map((entry) {
            int idx = entry.key;
            var item = entry.value;
            double val = 0.0;
            if (item is Map && item['value'] != null) {
              if (item['value'] is num) {
                val = (item['value'] as num).toDouble();
              } else {
                val = double.tryParse(item['value'].toString()) ?? 0.0;
              }
            }
            return BarChartGroupData(
              x: idx,
              barRods: [
                BarChartRodData(
                  toY: val,
                  color: chartColors[idx % chartColors.length],
                  width: data.length > 5 ? 16 : 20,
                  borderRadius: BorderRadius.circular(6),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: computedMaxY,
                    color: _inputBgColor,
                  ),
                )
              ],
            );
          }).toList(),
        ),
      );

      if (data.length > 5) {
        chartWidget = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: SizedBox(
            height: 220,
            width: data.length * 56.0 + 30.0,
            child: barChartWidget,
          ),
        );
      } else {
        chartWidget = SizedBox(
          height: 220,
          child: barChartWidget,
        );
      }
    }

    final bool hasMoreThan3 = data.length > 3;
    final List<dynamic> displayItems = (!isInsideSheet && hasMoreThan3)
        ? data.take(3).toList()
        : data;

    return Container(
      padding: EdgeInsets.all(isInsideSheet ? (_isCompact ? 12 : 16) : _cardPad),
      margin: EdgeInsets.only(bottom: isInsideSheet ? (_isCompact ? 8 : 12) : _cardMargin),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: _titleFs, fontWeight: FontWeight.w600, color: _textColor)),
                    if (!isInsideSheet && hasMoreThan3)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          'Showing 3 of ${data.length} items',
                          style: TextStyle(fontSize: _smallFs, color: _textSecondaryColor),
                        ),
                      ),
                  ],
                ),
              ),
              if (!isInsideSheet && hasMoreThan3)
                GestureDetector(
                  onTap: () => _openChartShutter(viz),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _primaryColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.keyboard_arrow_up_rounded, size: 16, color: _primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          'Shutter (${data.length})',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          chartWidget,
          const SizedBox(height: 24),
          ...displayItems.asMap().entries.map((entry) {
            final int idx = entry.key;
            final item = entry.value;
            String label = item is Map ? (item['label']?.toString() ?? 'Unknown') : item.toString();
            String valStr = item is Map ? (item['value']?.toString() ?? '0') : '0';
            String unit = item is Map ? (item['unit']?.toString() ?? '') : '';
            return Container(
              margin: EdgeInsets.only(bottom: _isCompact ? 6 : 8),
              padding: EdgeInsets.symmetric(horizontal: _isCompact ? 10 : 16, vertical: _isCompact ? 10 : 12),
              decoration: BoxDecoration(
                color: _inputBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: _isCompact ? 10 : 12,
                    height: _isCompact ? 10 : 12,
                    decoration: BoxDecoration(
                      color: chartColors[idx % chartColors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: _isCompact ? 8 : 12),
                  Expanded(child: Text(label, style: TextStyle(color: _textColor.withOpacity(0.8), fontSize: _bodyFs))),
                  Text('$valStr$unit', style: TextStyle(fontWeight: FontWeight.w600, color: _textColor, fontSize: _bodyFs)),
                ],
              ),
            );
          }),
          if (!isInsideSheet && hasMoreThan3) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _openChartShutter(viz),
              borderRadius: BorderRadius.circular(_isCompact ? 12 : 16),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: _isCompact ? 12 : 16, vertical: _isCompact ? 10 : 14),
                decoration: BoxDecoration(
                  color: _isDark ? const Color(0xFF282016) : const Color(0xFFF3ECE1),
                  borderRadius: BorderRadius.circular(_isCompact ? 12 : 16),
                  border: Border.all(color: _primaryColor.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(_isCompact ? 6 : 8),
                      decoration: BoxDecoration(
                        color: _primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.keyboard_arrow_up_rounded, color: _onPrimaryColor, size: _isCompact ? 16 : 18),
                    ),
                    SizedBox(width: _isCompact ? 10 : 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'View all ${data.length} items & graph in Shutter',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: _smallFs + 2,
                              color: _textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '+${data.length - 3} more items hidden • Slide up for full list',
                            style: TextStyle(
                              fontSize: _smallFs,
                              color: _textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: _smallFs + 2, color: _primaryColor),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: _hPad, vertical: _isCompact ? 10.0 : 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Professional Header with User Greeting and Profile Avatar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Hello, ${widget.user?.fullName.split(" ").first ?? widget.user?.username ?? 'Friend'}',
                                  style: TextStyle(
                                    fontSize: _isCompact ? 18 : (_isWide ? 24 : 20),
                                    fontWeight: FontWeight.w800,
                                    color: _textColor,
                                    letterSpacing: -0.4,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text('👋', style: TextStyle(fontSize: _isCompact ? 14 : 18)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: _isCompact ? 6 : 8,
                                height: _isCompact ? 6 : 8,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'NutriLens AI • ${widget.user?.dietaryPreference ?? 'Veg'} Mode',
                                style: TextStyle(
                                  fontSize: _smallFs,
                                  fontWeight: FontWeight.w500,
                                  color: _textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        // Theme Toggle
                        Container(
                          width: _isCompact ? 36 : 42,
                          height: _isCompact ? 36 : 42,
                          decoration: BoxDecoration(
                            color: _surfaceColor,
                            borderRadius: BorderRadius.circular(_isCompact ? 10 : 14),
                            border: Border.all(color: _borderColor),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(_isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: _textColor, size: _isCompact ? 18 : 20),
                            onPressed: () => MyApp.of(context).toggleTheme(context),
                            tooltip: 'Toggle Theme',
                          ),
                        ),
                        SizedBox(width: _isCompact ? 6 : 8),
                        // Settings Button
                        Container(
                          width: _isCompact ? 36 : 42,
                          height: _isCompact ? 36 : 42,
                          decoration: BoxDecoration(
                            color: _surfaceColor,
                            borderRadius: BorderRadius.circular(_isCompact ? 10 : 14),
                            border: Border.all(color: _borderColor),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(Icons.tune_rounded, color: _textColor, size: _isCompact ? 18 : 20),
                            onPressed: _openSettings,
                            tooltip: 'API Settings',
                          ),
                        ),
                        SizedBox(width: _isCompact ? 6 : 8),
                        // Profile Avatar Button
                        GestureDetector(
                          onTap: _openProfile,
                          child: Container(
                            width: _isCompact ? 36 : 44,
                            height: _isCompact ? 36 : 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _isDark
                                    ? [const Color(0xFFD4B996), const Color(0xFFA68B67)]
                                    : [const Color(0xFF4A2E1B), const Color(0xFF6B452B)],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(color: _borderColor, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: _primaryColor.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                (widget.user?.fullName.isNotEmpty == true
                                        ? widget.user!.fullName.trim()[0]
                                        : widget.user?.username.isNotEmpty == true
                                            ? widget.user!.username[0]
                                            : 'U')
                                    .toUpperCase(),
                                style: TextStyle(
                                  color: _onPrimaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: _isCompact ? 14 : 17,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (widget.user?.isGuest == true) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.amber, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Using Guest Mode. Tap profile avatar anytime to sign out or register.',
                            style: TextStyle(fontSize: 12, color: _textColor.withOpacity(0.9)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                
                // Image Display
                Container(
                  height: _isCompact ? 200 : (_isWide ? 340 : 260),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _surfaceColor,
                    borderRadius: BorderRadius.circular(_cardRadius + 4),
                    border: Border.all(color: _borderColor),
                    image: _imageBytes != null
                        ? DecorationImage(
                            image: MemoryImage(_imageBytes!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ]
                  ),
                  child: _image == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(_isCompact ? 14 : 20),
                              decoration: BoxDecoration(
                                color: _inputBgColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.document_scanner_outlined, size: _isCompact ? 36 : 48, color: _primaryColor),
                            ),
                            SizedBox(height: _isCompact ? 16 : 24),
                            Text('Scan a product label', style: TextStyle(color: _textColor, fontSize: _titleFs, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Text('to view its insights', style: TextStyle(color: _textSecondaryColor, fontSize: _bodyFs)),
                          ],
                        )
                      : null,
                ),
                const SizedBox(height: 24),
                
                // Scan Actions
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isRecognizing ? null : () => _pickImage(ImageSource.camera),
                        icon: Icon(Icons.camera_alt_outlined, color: _onPrimaryColor, size: _iconSm),
                        label: Text('Camera', style: TextStyle(color: _onPrimaryColor, fontWeight: FontWeight.w600, fontSize: _bodyFs)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          padding: EdgeInsets.symmetric(vertical: _isCompact ? 14 : 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_isCompact ? 12 : 16)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    SizedBox(width: _isCompact ? 10 : 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isRecognizing ? null : () => _pickImage(ImageSource.gallery),
                        icon: Icon(Icons.photo_library_outlined, color: _textColor, size: _iconSm),
                        label: Text('Gallery', style: TextStyle(color: _textColor, fontWeight: FontWeight.w600, fontSize: _bodyFs)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _surfaceColor,
                          padding: EdgeInsets.symmetric(vertical: _isCompact ? 14 : 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_isCompact ? 12 : 16),
                            side: BorderSide(color: _borderColor),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: _isCompact ? 18 : 28),
                
                // Request ID Section
                Container(
                  padding: EdgeInsets.all(_cardPad),
                  decoration: BoxDecoration(
                    color: _surfaceColor,
                    borderRadius: BorderRadius.circular(_cardRadius),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fetch Existing Result',
                        style: TextStyle(fontSize: _titleFs, fontWeight: FontWeight.w600, color: _textColor),
                      ),
                      SizedBox(height: _isCompact ? 10 : 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _reqIdController,
                              style: TextStyle(color: _textColor, fontSize: _bodyFs),
                              decoration: InputDecoration(
                                hintText: 'Enter Request ID',
                                hintStyle: TextStyle(color: _inputHintColor, fontSize: _bodyFs),
                                filled: true,
                                fillColor: _inputBgColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(_isCompact ? 12 : 16),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: EdgeInsets.symmetric(horizontal: _isCompact ? 12 : 16, vertical: _isCompact ? 12 : 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: _isRecognizing ? null : _fetchExistingResult,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              padding: EdgeInsets.all(_isCompact ? 12 : 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_isCompact ? 12 : 16)),
                              elevation: 0,
                            ),
                            child: Icon(Icons.search, color: _onPrimaryColor, size: _iconSm),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: _isCompact ? 20 : 28),
                
                // Results Section
                if (_rawText.isNotEmpty || _dashboardData != null || _isRecognizing)
                  Text(
                    'Analysis Results',
                    style: TextStyle(fontSize: _titleFs + 3, fontWeight: FontWeight.w700, color: _textColor, letterSpacing: -0.5),
                  ),
                SizedBox(height: _isCompact ? 10 : 16),
                
                if (_isRecognizing)
                  Container(
                    padding: EdgeInsets.all(_cardPad * 1.3),
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(_cardRadius),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: _primaryColor),
                        SizedBox(height: _isCompact ? 16 : 24),
                        Text(
                          _recognizedText,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _textColor.withOpacity(0.8), fontSize: _bodyFs, height: 1.5),
                        ),
                      ],
                    ),
                  )
                else if (_dashboardData != null) ...[
                  _buildResultCards(),
                  if (_rawText.isNotEmpty) _buildRawTextCard(),
                ] else if (_rawText.isNotEmpty) ...[
                  Container(
                    padding: EdgeInsets.all(_cardPad),
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(_cardRadius),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Text(
                      _recognizedText,
                      style: TextStyle(color: _textColor.withOpacity(0.8), fontSize: _bodyFs, height: 1.5),
                    ),
                  ),
                  _buildRawTextCard(),
                ],
                
                SizedBox(height: _isCompact ? 80 : 110),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _image != null || _rawText.isNotEmpty || _dashboardData != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_dashboardData != null) ...[
                  FloatingActionButton.extended(
                    heroTag: 'shutter_fab',
                    onPressed: _openNutritionShutter,
                    backgroundColor: _primaryColor,
                    icon: Icon(Icons.keyboard_arrow_up_rounded, color: _onPrimaryColor, size: 22),
                    label: Text(
                      'Open Shutter',
                      style: TextStyle(color: _onPrimaryColor, fontWeight: FontWeight.bold),
                    ),
                    elevation: 4,
                  ),
                  const SizedBox(width: 10),
                ],
                FloatingActionButton(
                  heroTag: 'reset_fab',
                  onPressed: _resetState,
                  backgroundColor: _surfaceColor,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: _borderColor),
                  ),
                  tooltip: 'Reset Scanner',
                  child: Icon(Icons.refresh_rounded, color: _textColor),
                ),
              ],
            )
          : null,
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final String currentUrl;
  final bool useDoubleLayer;
  final Function(String, bool) onSettingsChanged;

  const SettingsScreen({
    super.key,
    required this.currentUrl,
    required this.useDoubleLayer,
    required this.onSettingsChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlController;
  late bool _useDoubleLayer;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.currentUrl);
    _useDoubleLayer = widget.useDoubleLayer;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final newUrl = _urlController.text.trim();
    await prefs.setString('api_url', newUrl);
    await prefs.setBool('use_double_layer', _useDoubleLayer);
    widget.onSettingsChanged(newUrl, _useDoubleLayer);
    
    if (mounted) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final primaryColor = isDark ? const Color(0xFFD4B996) : const Color(0xFF4A2E1B);
      final onPrimaryColor = isDark ? const Color(0xFF121212) : Colors.white;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Settings saved successfully', style: TextStyle(color: onPrimaryColor, fontWeight: FontWeight.w600)),
          backgroundColor: primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF9F6F0);
    final Color surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color primaryColor = isDark ? const Color(0xFFD4B996) : const Color(0xFF4A2E1B);
    final Color onPrimaryColor = isDark ? const Color(0xFF121212) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF3E2723);
    final Color textSecondaryColor = isDark ? Colors.white54 : const Color(0xFF8D7B68);
    final Color borderColor = isDark ? Colors.white10 : const Color(0xFFEBE3D5);
    final Color inputBgColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3EFE6);
    final Color inputHintColor = isDark ? Colors.white30 : const Color(0xFFAFA493);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(fontWeight: FontWeight.w700, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Backend API URL',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _urlController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'https://web-production-d4a30.up.railway.app/mob-backend/api/ocr/',
                      hintStyle: TextStyle(color: inputHintColor),
                      filled: true,
                      fillColor: inputBgColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Production URL: https://web-production-d4a30.up.railway.app/mob-backend/api/ocr/\nFor local dev, use http://10.0.2.2:8000/mob-backend/api/ocr/ (Android) or http://127.0.0.1:8000/mob-backend/api/ocr/',
                    style: TextStyle(color: textSecondaryColor, fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: primaryColor,
                title: Text('Double Layer AI Analysis', style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
                subtitle: Text('Enable highly consistent charts by asking AI to map out the charts before extracting the data.', style: TextStyle(color: textSecondaryColor, fontSize: 13, height: 1.3)),
                value: _useDoubleLayer,
                onChanged: (bool value) {
                  setState(() {
                    _useDoubleLayer = value;
                  });
                },
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text('Save Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: onPrimaryColor)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
