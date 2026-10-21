# Rental App - Agent Documentation

## Application Overview
This is a Flutter rental property app with deep linking support, voice search, property listings, and real-time updates.

## Key Architecture Patterns

### Deep Link Handling
- **Service**: `lib/core/services/deep_link_service.dart`
- **Configuration**: Android deep links configured in `android/app/src/main/AndroidManifest.xml`
- **Link Formats Supported**:
  - `https://rental.arkio.in/?propertyId=xxx`
  - `https://rental.arkio.in/property/xxx`
  - `rental://property/xxx`
  - `arkio://rental/property/xxx`

### Deep Link Flow (Optimized)
1. **main.dart** checks for initial deep link with 100ms timeout before UI launch
2. If deep link found, `onGenerateRoute` routes directly to `PropertyLoaderScreen` or `PropertyDetailsScreen` (if cached)
3. If not deep link, routes to `HomeScreen`
4. `DeepLinkService` marks initial link as handled to prevent duplicate navigation
5. `DeepLinkService` only handles incoming links when app is already running

### Property Loading Strategy
- **Fast Path 1**: Check in-memory cached properties (0ms)
- **Fast Path 2**: Check web preloaded property (Web only, 0ms)
- **Fast Path 3**: Check SharedPreferences cache
- **Fallback**: Fetch from Supabase with 6-second timeout
- **PropertyLoaderScreen**: Shows skeleton loading UI while fetching

### Home Screen
- Loads cached properties immediately on init
- Starts GPS stream and fresh data fetch in background
- Has location detection and manual location override
- Real-time property updates via Supabase subscriptions

## Recent Fixes

### Blank Screen on Deep Link Navigation (Fixed)
**Problem**: When clicking a deep link, the app showed a blank/black screen for 5+ seconds before reaching the property detail page.

**Root Cause**:
1. `main.dart` was waiting for multiple async operations (SharedPreferences, Supabase, deep link check) before launching UI
2. This caused a delay before the app could route to the property screen
3. HomeScreen was also handling deep links, causing duplicate navigation attempts
4. Android launch background was black (#000000), which appeared as a black screen during startup
5. **CRITICAL**: The deep link check had a timeout (150-500ms), which was too short for Android to pass the intent from browser/email, causing deep links to be missed
6. When deep link was missed, app launched to HomeScreen, then DeepLinkService tried to navigate later, causing the blank screen delay

**Solution**:
1. **Removed timeout from deep link check** - Now waits indefinitely for the link. If no link exists, returns null quickly anyway. This ensures we never miss a deep link.
2. Moved deep link check to happen before UI launch (no timeout)
3. If deep link found, route directly to property screen via `onGenerateRoute`
4. If no deep link, route to HomeScreen
5. Removed duplicate deep link handling from HomeScreen
6. Added flag in `DeepLinkService` to prevent duplicate navigation when main.dart already handled the link
7. Moved SharedPreferences initialization before deep link check (needed for cache lookup) but kept it separate from Supabase and ThemeController to avoid delays
8. Changed Android launch background from drawable to pure white/black color directly in styles.xml
9. Added debug logging to track deep link navigation flow

**Files Modified**:
- `lib/main.dart`: Removed timeout from deep link check, moved SharedPreferences before deep link check, added debug logging
- `lib/core/services/deep_link_service.dart`: Added `markInitialLinkHandled()` to prevent duplicate navigation
- `lib/features/home/presentation/pages/home_screen.dart`: Removed duplicate deep link handling
- `lib/features/property_details/presentation/pages/property_loader_screen.dart`: Added debug logging
- `android/app/src/main/res/values/styles.xml`: Changed windowBackground to pure white
- `android/app/src/main/res/values-night/styles.xml`: Changed windowBackground to pure black

## Build and Test Commands
```bash
# Run the app
flutter run

# Build for Android
flutter build apk

# Build for iOS
flutter build ios

# Run tests
flutter test
```

## Important Notes
- The app uses `singleTop` launch mode in Android to handle deep links properly
- Flutter deep linking is disabled in AndroidManifest to give full control to DeepLinkService
- Property caching uses version guard (currently version 3) to handle schema changes
- Image cache is set to 1000 images / 250MB for instant photo rendering
