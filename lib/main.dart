import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:fl_chart/fl_chart.dart';

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

  @override
  void initState() {
    super.initState();
    _loadTheme();
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
      title: 'AI Scanner',
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
      home: const OcrScreen(),
    );
  }
}

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

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
  String _apiUrl = "https://92xqbtlk-8000.inc1.devtunnels.ms/api/ocr/";

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
      _apiUrl = prefs.getString('api_url') ?? "https://92xqbtlk-8000.inc1.devtunnels.ms/api/ocr/";
      _useDoubleLayer = prefs.getBool('use_double_layer') ?? false;
      _cityController.text = prefs.getString('user_city') ?? "";
      _stateController.text = prefs.getString('user_state') ?? "";
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      _showLocationDialog(pickedFile);
    }
  }

  Future<void> _showLocationDialog(XFile image) async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF3E2723);
    final Color primaryColor = isDark ? const Color(0xFFD4B996) : const Color(0xFF4A2E1B);
    final Color inputBgColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3EFE6);
    final Color inputHintColor = isDark ? Colors.white30 : const Color(0xFFAFA493);

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
              bool isLoadingLocation = false;
              
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
                        final response = await http.get(Uri.parse('https://get.geojs.io/v1/ip/geo.json'));
                        if (response.statusCode == 200) {
                          final data = jsonDecode(response.body);
                          if (data['city'] != null) _cityController.text = data['city'];
                          if (data['region'] != null) _stateController.text = data['region'];
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
                            isLoadingLocation ? 'Detecting...' : 'Auto-Detect Location',
                            style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  TextField(
                    controller: _cityController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'City (e.g., Mumbai)',
                      hintStyle: TextStyle(color: inputHintColor),
                      filled: true,
                      fillColor: inputBgColor,
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
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'State (e.g., Maharashtra)',
                      hintStyle: TextStyle(color: inputHintColor),
                      filled: true,
                      fillColor: inputBgColor,
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
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _cityController.clear();
                _stateController.clear();
                _startProcessing(image);
              },
              child: Text('Skip', style: TextStyle(color: textColor.withOpacity(0.6), fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _startProcessing(image);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                elevation: 0,
              ),
              child: Text(
                'Analyze',
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
    await _processImageOnBackend(image);
  }

  Future<void> _processImageOnBackend(XFile image) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_city', _cityController.text.trim());
      await prefs.setString('user_state', _stateController.text.trim());
      
      var request = http.MultipartRequest('POST', Uri.parse(_apiUrl));
      
      final bytes = await image.readAsBytes();
      String filename = image.name;
      if (filename.isEmpty) filename = 'upload.jpg';
      
      request.files.add(http.MultipartFile.fromBytes(
        'image', 
        bytes,
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
    String wsUrl = _apiUrl.replaceFirst('http', 'ws');
    wsUrl = wsUrl.replaceAll('/api/ocr/', '/ws/ocr/$requestId/');
    
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    
    _channel!.stream.listen((message) {
      final decoded = jsonDecode(message);
      
      if (decoded['status'] == 'success') {
        setState(() {
          _rawText = decoded['raw_text']?.toString() ?? '';
          if (decoded['is_structured'] == true) {
            _dashboardData = decoded['data'];
            _recognizedText = "Parsed successfully!";
          } else {
            _dashboardData = null;
            _recognizedText = decoded['data'] != null ? decoded['data'].toString() : "Success but no text returned";
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
      final fetchUrl = _apiUrl.replaceAll('ocr/', 'fetch/$reqId/');
      final response = await http.get(Uri.parse(fetchUrl));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == 'success') {
          setState(() {
            _rawText = decoded['raw_text']?.toString() ?? '';
            if (decoded['is_structured'] == true) {
              _dashboardData = decoded['data'];
              _recognizedText = '';
            } else {
              _recognizedText = decoded['data'].toString();
            }
            _isRecognizing = false;
          });
        } else {
          setState(() {
            _recognizedText = "Error: ${decoded['error']}";
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

  Widget _buildRawTextCard() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: _primaryColor,
          collapsedIconColor: _textSecondaryColor,
          title: Text('Raw OCR Text', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textColor)),
          subtitle: Text(
            _rawText.replaceAll('\n', ' '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: _textSecondaryColor),
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _inputBgColor,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
              ),
              child: SelectableText(_rawText, style: TextStyle(color: _textColor.withOpacity(0.8), height: 1.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthIndices(dynamic indices) {
    if (indices == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Health Ratings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _textColor)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHealthBadge('Baby', indices['baby']),
              _buildHealthBadge('Adult', indices['adult']),
              _buildHealthBadge('Senior', indices['senior']),
            ],
          ),
          if (indices['baby']?['reason'] != null && indices['baby']['reason'].toString().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Baby/Toddler Note: ${indices['baby']['reason']}',
                      style: const TextStyle(color: Colors.orange, fontSize: 13, height: 1.4),
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
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: badgeColor, width: 4),
            ),
            child: Center(
              child: Text(
                '$score',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _textColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              rating,
              style: TextStyle(
                fontSize: 10,
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
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF8B7355).withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF8B7355).withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.wb_sunny_outlined, color: Color(0xFF8B7355), size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ayurvedic Insight', style: TextStyle(color: Color(0xFF8B7355), fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(
                        _dashboardData!['ayurvedic_insight'].toString(),
                        style: TextStyle(color: _textColor, fontSize: 15, height: 1.4),
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
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _borderColor),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _dashboardData!['is_veg'].toString().toLowerCase() == 'veg' 
                        ? Colors.green.withOpacity(0.15) 
                        : Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _dashboardData!['is_veg'].toString().toLowerCase() == 'veg' ? Icons.eco : Icons.local_dining,
                    color: _dashboardData!['is_veg'].toString().toLowerCase() == 'veg' ? Colors.green : Colors.red,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dietary Preference', style: TextStyle(color: _textSecondaryColor, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      _dashboardData!['is_veg'].toString().toUpperCase(),
                      style: TextStyle(
                        fontSize: 18,
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
          
        if (_dashboardData!['ingredients_list'] != null && (_dashboardData!['ingredients_list'] as List).isNotEmpty)
          _buildTagList('Ingredients', _dashboardData!['ingredients_list'] as List, _textColor, Icons.science_outlined, isMuted: true),

        if (_dashboardData!['fssai_license'] != null && _dashboardData!['fssai_license'].toString().isNotEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined, color: Colors.blue),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('FSSAI License', style: TextStyle(color: Colors.blue, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(
                        _dashboardData!['fssai_license'].toString(),
                        style: TextStyle(fontWeight: FontWeight.w600, color: _textColor, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        if (_dashboardData!['visualizations'] != null)
          ...(_dashboardData!['visualizations'] as List).map((viz) => _buildChartSection(viz)),
      ],
    );
  }

  Widget _buildTagList(String title, List items, Color color, IconData icon, {bool isMuted = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: items.map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    fontSize: 13,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(dynamic viz) {
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
        height: 220,
        child: PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 50,
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
              String label = item is Map ? (item['label']?.toString() ?? 'Unknown') : 'Unknown';
              String unit = item is Map ? (item['unit']?.toString() ?? '') : '';
              return PieChartSectionData(
                value: val > 0 ? val : 1,
                title: '$val$unit',
                radius: 40,
                titleStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _isDark ? const Color(0xFF121212) : Colors.white),
                color: chartColors[idx % chartColors.length],
              );
            }).toList(),
          )
        )
      );
    } else if (type == 'bar_chart') {
      chartWidget = SizedBox(
        height: 220,
        child: BarChart(
          BarChartData(
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
                    width: 20,
                    borderRadius: BorderRadius.circular(6),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: 100,
                      color: _inputBgColor,
                    ),
                  )
                ],
              );
            }).toList(),
          )
        )
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _textColor)),
          const SizedBox(height: 24),
          chartWidget,
          const SizedBox(height: 24),
          ...data.map((item) {
            String label = item is Map ? (item['label']?.toString() ?? 'Unknown') : item.toString();
            String valStr = item is Map ? (item['value']?.toString() ?? '0') : '0';
            String unit = item is Map ? (item['unit']?.toString() ?? '') : '';
            int idx = data.indexOf(item);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _inputBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: chartColors[idx % chartColors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(label, style: TextStyle(color: _textColor.withOpacity(0.8)))),
                  Text('$valStr$unit', style: TextStyle(fontWeight: FontWeight.w600, color: _textColor)),
                ],
              ),
            );
          }),
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
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'AI Scanner',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: _textColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: _surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _borderColor),
                          ),
                          child: IconButton(
                            icon: Icon(_isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: _textColor),
                            onPressed: () => MyApp.of(context).toggleTheme(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: _surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _borderColor),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.settings_outlined, color: _textColor),
                            onPressed: _openSettings,
                          ),
                        ),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 32),
                
                // Image Display
                Container(
                  height: 280,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _surfaceColor,
                    borderRadius: BorderRadius.circular(32),
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
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: _inputBgColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.document_scanner_outlined, size: 48, color: _primaryColor),
                            ),
                            const SizedBox(height: 24),
                            Text('Scan a product label', style: TextStyle(color: _textColor, fontSize: 18, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Text('to view its insights', style: TextStyle(color: _textSecondaryColor, fontSize: 14)),
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
                        icon: Icon(Icons.camera_alt_outlined, color: _onPrimaryColor),
                        label: Text('Camera', style: TextStyle(color: _onPrimaryColor, fontWeight: FontWeight.w600, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isRecognizing ? null : () => _pickImage(ImageSource.gallery),
                        icon: Icon(Icons.photo_library_outlined, color: _textColor),
                        label: Text('Gallery', style: TextStyle(color: _textColor, fontWeight: FontWeight.w600, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _surfaceColor,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: _borderColor),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Request ID Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _surfaceColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fetch Existing Result',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textColor),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _reqIdController,
                              style: TextStyle(color: _textColor),
                              decoration: InputDecoration(
                                hintText: 'Enter Request ID',
                                hintStyle: TextStyle(color: _inputHintColor),
                                filled: true,
                                fillColor: _inputBgColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: _isRecognizing ? null : _fetchExistingResult,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              padding: const EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: Icon(Icons.search, color: _onPrimaryColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Results Section
                if (_rawText.isNotEmpty || _dashboardData != null || _isRecognizing)
                  Text(
                    'Analysis Results',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _textColor, letterSpacing: -0.5),
                  ),
                const SizedBox(height: 16),
                
                if (_isRecognizing)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: _primaryColor),
                        const SizedBox(height: 24),
                        Text(
                          _recognizedText,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _textColor.withOpacity(0.8), fontSize: 16, height: 1.5),
                        ),
                      ],
                    ),
                  )
                else if (_dashboardData != null) ...[
                  _buildResultCards(),
                  if (_rawText.isNotEmpty) _buildRawTextCard(),
                ] else if (_rawText.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Text(
                      _recognizedText,
                      style: TextStyle(color: _textColor.withOpacity(0.8), fontSize: 16, height: 1.5),
                    ),
                  ),
                  _buildRawTextCard(),
                ],
                
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _image != null || _rawText.isNotEmpty || _dashboardData != null
          ? FloatingActionButton.extended(
              onPressed: _resetState,
              backgroundColor: _primaryColor,
              icon: Icon(Icons.refresh, color: _onPrimaryColor),
              label: Text('Reset Scanner', style: TextStyle(color: _onPrimaryColor, fontWeight: FontWeight.w600)),
              elevation: 4,
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
                      hintText: 'http://192.168.1.X:8000/api/ocr/',
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
                    'For local development, use https://92xqbtlk-8000.inc1.devtunnels.ms/api/ocr/\nFor other servers, enter the full URL.',
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
