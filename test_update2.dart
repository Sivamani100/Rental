import 'dart:io';
import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://dhbwnteiahefjfpojapz.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRoYndudGVpYWhlZmpmcG9qYXB6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc2NDIwNTQsImV4cCI6MjEwMzIxODA1NH0.CnP-ogYh7FwPY9cqBRTX2oS6NqTT-mXgPsSyDDCADC8',
  );

  try {
    final res = await supabase.from('properties').select().limit(1);
    if (res.isEmpty) {
      print('No properties found');
      exit(0);
    }
    final id = res[0]['id'];
    
    print('Testing update on property id: $id');
    await supabase.from('properties').update({'suggested_photos': []}).eq('id', id);
    print('Update successful');
  } catch (e) {
    print('Error: $e');
  }
  exit(0);
}
