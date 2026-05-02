import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({Key? key}) : super(key: key);

  @override
  _LanguageSelectionScreenState createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  List<dynamic> _languages = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  int? _selectedLanguageId;

  @override
  void initState() {
    debugPrint('--- initState: LanguageSelectionScreen is opening ---');
    super.initState();
    _fetchLanguages();
  }

  Future<void> _fetchLanguages() async {
    // Note: use 10.0.2.2 for Android emulators to hit localhost Spring Boot
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final url = Uri.parse('http://10.0.2.2:8080/api/v1/gita/languages');
    try {
      final response = await http.get(url);
      debugPrint(
        '--- _fetchLanguages: Got response ${response.statusCode} ---',
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          debugPrint('--- _fetchLanguages: Updating state with languages ---');
          _languages = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load languages. Server error.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Failed to connect to the server. Please check your connection.';
      });
    }
  }

  Future<void> _saveUser() async {
    if (_selectedLanguageId == null) return;

    setState(() {
      _isSaving = true;
    });

    final url = Uri.parse('http://10.0.2.2:8080/api/v1/user-profiles');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'preferredLanguageId': _selectedLanguageId,
          'name': 'New User',
          'deviceId':
              'AndroidDevice123', // Use device_info_plus library if you need a real unique ID
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;

        final responseData = json.decode(response.body);
        final prefs = await SharedPreferences.getInstance();

        // Save state locally so we skip this screen on next launch
        await prefs.setBool('isFirstLaunch', false);
        if (responseData['id'] != null) {
          await prefs.setInt('userId', responseData['id']);
        }

        // TODO: Navigate to Home Screen
        // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else {
        if (!mounted) return;
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save preferences.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      '--- build: LanguageSelectionScreen UI is building/reloading ---',
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Select Preferred Language')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchLanguages,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _languages.length,
                    itemBuilder: (context, index) {
                      final lang = _languages[index];
                      return RadioListTile<int>(
                        title: Text(lang['languageName'] ?? 'Unknown'),
                        subtitle: Text(lang['languageText'] ?? ''),
                        value: lang['id'],
                        groupValue: _selectedLanguageId,
                        onChanged: (value) =>
                            setState(() => _selectedLanguageId = value),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    onPressed: (_selectedLanguageId == null || _isSaving)
                        ? null
                        : _saveUser,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Continue'),
                  ),
                ),
              ],
            ),
    );
  }
}
