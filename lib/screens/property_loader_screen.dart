import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/property_model.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import 'property_details_screen.dart';

class PropertyLoaderScreen extends StatefulWidget {
  final String propertyId;

  const PropertyLoaderScreen({super.key, required this.propertyId});

  @override
  State<PropertyLoaderScreen> createState() => _PropertyLoaderScreenState();
}

class _PropertyLoaderScreenState extends State<PropertyLoaderScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchPropertyAndNavigate();
  }

  Future<void> _fetchPropertyAndNavigate() async {
    try {
      final res = await Supabase.instance.client
          .from('properties')
          .select()
          .eq('id', widget.propertyId)
          .maybeSingle();

      if (res != null && mounted) {
        final property = PropertyModel.fromJson(res);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PropertyDetailsScreen(property: property),
          ),
        );
        return;
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Property listing not found or no longer active.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load property. Please check your connection.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffold : AppTheme.lightScaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isLoading
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                    const SizedBox(height: 20),
                    Text(
                      'Opening Property...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage ?? 'Property unavailable',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.maybePop(context),
                      child: const Text('Back', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
