import 'dart:io';
import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://dhbwnteiahefjfpojapz.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRoYndudGVpYWhlZmpmcG9qYXB6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc2NDIwNTQsImV4cCI6MjEwMzIxODA1NH0.CnP-ogYh7FwPY9cqBRTX2oS6NqTT-mXgPsSyDDCADC8',
  );

  try {
    print('Testing storage upload');
    final file = File('test_image.jpg');
    if (!file.existsSync()) {
      file.writeAsBytesSync([255, 216, 255, 224, 0, 16, 74, 70, 73, 70, 0, 1, 1, 1, 0, 96, 0, 96, 0, 0, 255, 219, 0, 67, 0]);
    }
    await supabase.storage.from('property_images').upload('test_image.jpg', file);
    print('Upload successful');
  } catch (e) {
    print('Upload Error: $e');
  }
  exit(0);
}
