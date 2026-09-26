import 'package:flutter/material.dart';
import 'package:rental/models/property_model.dart';
import 'package:rental/theme/app_theme.dart';
import 'package:rental/services/saved_properties_service.dart';
import 'package:rental/screens/home_screen.dart'; // To reuse GridPropertyCard
import 'package:rental/screens/property_details_screen.dart';
import 'package:rental/services/transport_service.dart';
import 'package:flutter/cupertino.dart';

class SavedPropertiesScreen extends StatefulWidget {
  final List<PropertyModel> allProperties;

  const SavedPropertiesScreen({super.key, required this.allProperties});

  @override
  State<SavedPropertiesScreen> createState() => _SavedPropertiesScreenState();
}

class _SavedPropertiesScreenState extends State<SavedPropertiesScreen> {
  @override
  void initState() {
    super.initState();
    SavedPropertiesService.instance.addListener(_onSavedChanged);
  }

  @override
  void dispose() {
    SavedPropertiesService.instance.removeListener(_onSavedChanged);
    super.dispose();
  }

  void _onSavedChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final savedProps = widget.allProperties.where(
      (p) => SavedPropertiesService.instance.isSaved(p.id ?? '')
    ).toList();

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffold : const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkScaffold : Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Text(
          'Saved Properties',
          style: TextStyle(
            fontFamily: 'ProximaNova',
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: savedProps.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.swiggyOrange.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.heart, size: 50, color: AppTheme.swiggyOrange),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No saved properties yet',
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the heart icon on properties\nto save them for later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'ProximaNova',
                      color: isDark ? Colors.white54 : Colors.black54,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: savedProps.length,
              itemBuilder: (context, index) {
                final prop = savedProps[index];
                return GridPropertyCard(
                  property: prop,
                  distanceInMeters: null, // Since we don't calculate here for simplicity
                  onTap: () {
                    final transportFuture = TransportService.getNearby(
                      prop.latitude,
                      prop.longitude,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PropertyDetailsScreen(
                          property: prop,
                          preloadedTransportFuture: transportFuture,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

