import 'dart:async';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import 'l10n/app_localizations.dart';
export 'l10n/app_localizations.dart';
import 'l10n/hardcoded_localizations.dart';

import 'data/community_repository.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import 'services/notification_service.dart';
import 'services/subscription_service.dart';
import 'services/free_usage_service.dart';
import 'screens/paywall_screen.dart';
import 'data/deals_repository.dart';
import 'data/fragdb_repository.dart';
import 'data/supabase_fragrance_repository.dart';
import 'data/user_collection_repository.dart';
import 'models/ai_recommendation.dart';
import 'models/deal.dart';
import 'theme.dart';
import 'models/perfume.dart';
import 'screens/auth_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/detail_screen.dart';
import 'screens/collection_screen.dart';
import 'screens/add_screen.dart';
import 'screens/occasion_screen.dart';
import 'screens/price_tracker_screen.dart';
import 'screens/profile_screen.dart';
import 'widgets/paywall_sheet.dart';
import 'screens/scent_finder_screen.dart';

bool kSupabaseReady = false;

/// Request App Tracking Transparency permission on iOS before any SDK that
/// reads the IDFA (e.g. RevenueCat) is initialised.
Future<void> _requestTrackingPermission() async {
  if (!Platform.isIOS && !Platform.isMacOS) return;
  try {
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.notDetermined) {
      await AppTrackingTransparency.requestTrackingAuthorization();
    }
  } catch (e) {
    if (kDebugMode) debugPrint('ATT request failed: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    kSupabaseReady = true;
  }

  await _requestTrackingPermission();
  await SubscriptionService.instance.configure();
  await FreeUsageService.instance.load();
  await NotificationService.instance.initialize();

  runApp(const AtariApp());
}

class AtariApp extends StatefulWidget {
  const AtariApp({super.key});

  static void setLocale(BuildContext context, Locale locale) {
    final state = context.findAncestorStateOfType<_AtariAppState>()!;
    state._setLocale(locale);
  }

  @override
  State<AtariApp> createState() => _AtariAppState();
}

class _AtariAppState extends State<AtariApp> {
  Locale _locale = const Locale('ar');
  bool _splashDone = false;
  bool _onboardingCompleted = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadLocale());
  }

  Future<void> _onSplashComplete() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool('onboarding_completed') ?? false;
    if (!mounted) return;
    setState(() {
      _splashDone = true;
      _onboardingCompleted = completed;
    });
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('app_language') ?? 'ar';
    if (!mounted) return;
    _setLocale(Locale(code));
  }

  void _setLocale(Locale locale) {
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = _locale.languageCode == 'ar';
    return MaterialApp(
      title: 'عطري',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: _locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: child!,
      ),
      home: _splashDone
          ? (_onboardingCompleted
              ? const AuthGate()
              : OnboardingScreen(
                  onDone: () => setState(() => _onboardingCompleted = true),
                ))
          : SplashScreen(onComplete: _onSplashComplete),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    if (!kSupabaseReady) return;

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      event,
    ) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kSupabaseReady) return const AppShell();
    return AppShell(user: Supabase.instance.client.auth.currentUser);
  }
}

class AppShell extends StatefulWidget {
  final User? user;

  const AppShell({super.key, this.user});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final bool _useSupabase = kSupabaseReady;
  late final SupabaseFragranceRepository? _supabaseRepository = _useSupabase
      ? SupabaseFragranceRepository()
      : null;
  late final UserCollectionRepository? _userCollectionRepository = _useSupabase
      ? UserCollectionRepository()
      : null;
  late final CommunityRepository? _communityRepository = _useSupabase
      ? CommunityRepository()
      : null;
  late final DealsRepository? _dealsRepository = _useSupabase
      ? DealsRepository()
      : null;
  late final Future<List<Perfume>> _perfumesFuture = _loadInitialPerfumes();
  int _navIndex = 0;
  Perfume? _selectedPerfume;
  String? _selectedCollectionStatus;
  bool _selectedIsFavorite = false;
  UserReview? _selectedUserReview;
  bool _showAdd = false;
  String? _addInitialTab;
  Perfume? _finderInitialReference;
  int _collectionVersion = 0;
  bool _showAuth = false;
  bool _showPaywall = false;
  Future<void> Function()? _pendingAuthAction;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    if (_useSupabase && user != null) {
      _communityRepository?.ensureUserProfile(
        userId: user.id,
        email: user.email,
        name: user.userMetadata?['name']?.toString(),
      );
      unawaited(SubscriptionService.instance.logIn(user.id));
    }
  }

  void _openPaywall() {
    if (mounted) setState(() => _showPaywall = true);
  }

  Future<void> _requireAuth(Future<void> Function() onAuthed) async {
    if (widget.user != null) {
      await onAuthed();
      return;
    }
    setState(() {
      _pendingAuthAction = onAuthed;
      _showAuth = true;
    });
  }

  void _showLogin() {
    setState(() {
      _pendingAuthAction = null;
      _showAuth = true;
    });
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    // User just signed in.
    if (oldWidget.user == null && widget.user != null) {
      unawaited(SubscriptionService.instance.logIn(widget.user!.id));
      if (_showAuth) {
        setState(() => _showAuth = false);
        final pending = _pendingAuthAction;
        _pendingAuthAction = null;
        if (pending != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (mounted) await pending();
          });
        }
      }
    }

    // User just signed out.
    if (oldWidget.user != null && widget.user == null) {
      unawaited(SubscriptionService.instance.logOut());
    }
  }

  Future<List<Perfume>> _loadInitialPerfumes() async {
    try {
      if (_useSupabase) {
        final remotePerfumes = await _supabaseRepository!.loadTrendingPerfumes(
          limit: 10,
        );
        if (remotePerfumes.isNotEmpty) return remotePerfumes;
      }
    } catch (error) {
      if (kDebugMode) debugPrint('Supabase fragrance load failed: $error');
    }
    return FragDbRepository().loadPerfumes();
  }

  Future<List<Perfume>> _loadPerfumeRange(int offset, int limit) {
    return _supabaseRepository!.loadPerfumeRange(offset: offset, limit: limit);
  }

  Future<List<Perfume>> _searchPerfumes(String query) {
    return _supabaseRepository!.searchPerfumes(query);
  }

  Future<
    ({String brand, String name, String confidence, List<Perfume> matches})
  >
  _identifyByImage(String base64Image) {
    return _supabaseRepository!.identifyByImage(base64Image);
  }

  Future<List<Deal>> _loadDeals() => _dealsRepository!.loadActiveDeals();

  Future<List<Perfume>> _loadHomePerfumes({
    String? accord,
    required int offset,
    required int limit,
  }) {
    if (accord == null) {
      return _supabaseRepository!.loadPerfumeRange(
        offset: offset,
        limit: limit,
      );
    }
    return _supabaseRepository!.loadPerfumesByAccord(
      accord,
      limit: limit,
      offset: offset,
    );
  }

  Future<List<AiRecommendation>> _findByAi({
    required String occasion,
    required String style,
    required String gender,
    required String season,
    required String intensity,
  }) => _supabaseRepository!.findByAi(
    occasion: occasion,
    style: style,
    gender: gender,
    season: season,
    intensity: intensity,
  );

  Future<List<Perfume>> _findOccasionPerfumes({
    required List<String> occasionAccords,
    required List<String> styleAccords,
    required List<String> seasonAccords,
    String? gender,
    int limit = 10,
    String? priceTier,
    List<String>? tierBrands,
  }) {
    return _supabaseRepository!.findPerfumesForOccasion(
      occasionAccords: occasionAccords,
      styleAccords: styleAccords,
      seasonAccords: seasonAccords,
      gender: gender,
      limit: limit,
      priceTier: priceTier,
      tierBrands: tierBrands,
    );
  }

  Future<ProfileStats> _loadProfileStats() {
    return _communityRepository!.loadProfileStats(widget.user!.id);
  }

  Future<void> _deleteAccount() async {
    try {
      final client = Supabase.instance.client;
      await client.functions.invoke('delete-account');
      await client.auth.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Your account has been deleted.',
              style: arabicStyle(fontSize: 14, color: Colors.white),
            ),
            backgroundColor: kOud,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Delete failed: $e',
              style: arabicStyle(fontSize: 14, color: Colors.white),
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _onPerfumeTap(Perfume p) async {
    var perfume = p;
    String? collectionStatus;
    var isFavorite = false;
    UserReview? userReview;
    if (_useSupabase && p.id.isNotEmpty) {
      try {
        perfume = await _supabaseRepository!.loadPerfumeDetails(p.id);
      } catch (error) {
        if (kDebugMode) debugPrint('Supabase fragrance detail load failed: $error');
      }
      final userId = widget.user?.id;
      if (userId != null) {
        try {
          collectionStatus = await _userCollectionRepository!.loadStatus(
            userId: userId,
            perfumeId: p.id,
          );
        } catch (error) {
          if (kDebugMode) debugPrint('Supabase collection status load failed: $error');
        }
        try {
          isFavorite = await _userCollectionRepository!.loadFavorite(
            userId: userId,
            perfumeId: p.id,
          );
        } catch (error) {
          if (kDebugMode) debugPrint('Supabase favorite load failed: $error');
        }
        try {
          userReview = await _userCollectionRepository!.loadUserReview(
            userId: userId,
            perfumeId: p.id,
          );
        } catch (error) {
          if (kDebugMode) debugPrint('Supabase review load failed: $error');
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _selectedPerfume = perfume;
      _selectedCollectionStatus = collectionStatus;
      _selectedIsFavorite = isFavorite;
      _selectedUserReview = userReview;
    });
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DetailScreen(
        perfume: _selectedPerfume!,
        collectionStatus: _selectedCollectionStatus,
        isFavorite: _selectedIsFavorite,
        initialReview: _selectedUserReview,
        onCollectionStatusChanged: _useSupabase
            ? (status) async => _requireAuth(() => _saveCollectionStatus(status))
            : null,
        onFavoriteChanged: _useSupabase
            ? (isFav) async => _requireAuth(() => _toggleFavorite(isFav))
            : null,
        onSaveReview: _useSupabase && widget.user != null
            ? (rating, body) => _requireAuth(() => _saveReview(rating, body))
            : null,
        onRequireUpgrade: _openPaywall,
        onLoadPerfumeReviews: _useSupabase &&
                _selectedPerfume != null &&
                _selectedPerfume!.id.isNotEmpty
            ? () => _userCollectionRepository!.loadPerfumeReviews(
                  perfumeId: _selectedPerfume!.id,
                )
            : null,
        onFindAlternatives: _useSupabase && _selectedPerfume != null
            ? () => _onFindAlternatives(_selectedPerfume!)
            : null,
        onBack: () => Navigator.of(context).pop(),
      ),
    ));
  }

  Future<void> _toggleFavorite(bool isFavorite) async {
    final perfumeId = _selectedPerfume?.id;
    final userId = widget.user?.id;
    if (!_useSupabase ||
        perfumeId == null ||
        perfumeId.isEmpty ||
        userId == null) {
      return;
    }
    setState(() => _selectedIsFavorite = isFavorite);
    await _userCollectionRepository!.saveFavorite(
      userId: userId,
      perfumeId: perfumeId,
      isFavorite: isFavorite,
    );
    unawaited(HapticFeedback.selectionClick());
  }

  Future<Set<String>> _loadAllFavorites() async {
    final userId = widget.user?.id;
    if (userId == null) return {};
    return _userCollectionRepository!.loadAllFavorites(userId: userId);
  }

  Future<void> _toggleHomeFavorite(Perfume p, bool isFavorite) async {
    final userId = widget.user?.id;
    if (!_useSupabase || p.id.isEmpty || userId == null) return;
    await _userCollectionRepository!.saveFavorite(
      userId: userId,
      perfumeId: p.id,
      isFavorite: isFavorite,
    );
    unawaited(HapticFeedback.selectionClick());
  }

  Future<void> _saveReview(int rating, String? body) async {
    final perfumeId = _selectedPerfume?.id;
    final userId = widget.user?.id;
    if (!_useSupabase ||
        perfumeId == null ||
        perfumeId.isEmpty ||
        userId == null) {
      return;
    }
    await _userCollectionRepository!.saveReview(
      userId: userId,
      perfumeId: perfumeId,
      rating: rating,
      body: body,
    );
  }

  Future<void> _saveCollectionStatus(String status) async {
    final perfumeId = _selectedPerfume?.id;
    final userId = widget.user?.id;
    if (!_useSupabase ||
        perfumeId == null ||
        perfumeId.isEmpty ||
        userId == null) {
      return;
    }

    await _userCollectionRepository!.saveStatus(
      userId: userId,
      perfumeId: perfumeId,
      status: status,
    );
    unawaited(HapticFeedback.mediumImpact());
    if (mounted) setState(() => _collectionVersion++);
  }

  Future<Map<String, String>> _loadUserCollection() async {
    return _userCollectionRepository!.loadAllStatuses(userId: widget.user!.id);
  }

  Future<CollectionStats> _loadCollectionStats() async {
    return _userCollectionRepository!.loadCollectionStats(
      userId: widget.user!.id,
    );
  }

  Future<void> _addSearchResultToCollection(Perfume p) async {
    final userId = widget.user?.id;
    if (!_useSupabase || p.id.isEmpty || userId == null) return;
    final paywallMsg = context.t(
      'You reached the free limit 🔓 Activate Premium to track your full collection',
    );
    if (!SubscriptionService.instance.isPro.value) {
      final stats = await _userCollectionRepository!.loadCollectionStats(
        userId: userId,
      );
      if (stats.count >= 5) {
        if (mounted) {
          // ignore: use_build_context_synchronously
          await PaywallBottomSheet.show(context, message: paywallMsg);
        }
        return;
      }
    }
    await _userCollectionRepository!.saveStatus(
      userId: userId,
      perfumeId: p.id,
      status: 'owned',
    );
    unawaited(HapticFeedback.mediumImpact());
    if (mounted) {
      setState(() {
        _collectionVersion++;
        _showAdd = false;
      });
    }
  }

  Future<void> _saveManualEntry({
    required String name,
    required String concentration,
    required String source,
    double? price,
    required List<String> notes,
    String? personalNotes,
  }) async {
    final userId = widget.user?.id;
    if (userId == null) return;
    final paywallMsg = context.t(
      'You reached the free limit 🔓 Activate Premium to track your full collection',
    );
    if (!SubscriptionService.instance.isPro.value) {
      final stats = await _userCollectionRepository!.loadCollectionStats(
        userId: userId,
      );
      if (stats.count >= 5) {
        if (mounted) {
          // ignore: use_build_context_synchronously
          await PaywallBottomSheet.show(context, message: paywallMsg);
        }
        return;
      }
    }
    await _userCollectionRepository!.saveManualEntry(
      userId: userId,
      name: name,
      concentration: concentration,
      acquisitionSource: source,
      pricePaid: price,
      customAccords: notes,
      personalNotes: personalNotes,
    );
    unawaited(HapticFeedback.mediumImpact());
    if (mounted) setState(() => _collectionVersion++);
  }

  Future<void> _deleteFromCollection(Perfume p) async {
    final userId = widget.user?.id;
    if (!_useSupabase || p.id.isEmpty || userId == null) return;
    await _userCollectionRepository!.deleteStatus(
      userId: userId,
      perfumeId: p.id,
    );
    unawaited(HapticFeedback.mediumImpact());
    if (mounted) setState(() => _collectionVersion++);
  }

  void _onAddTap() => setState(() {
        _showAdd = true;
        _addInitialTab = null;
      });

  void _onAiScanTap() => setState(() {
        _showAdd = true;
        _addInitialTab = 'AI';
      });

  void _onFindAlternatives(Perfume perfume) {
    Navigator.of(context).pop();
    setState(() {
      _navIndex = 3;
      _finderInitialReference = perfume;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _finderInitialReference = null);
    });
  }

  void _requireAuthForAdd() {
    unawaited(_requireAuth(() async => _onAddTap()));
  }

  @override
  Widget build(BuildContext context) {
    if (_showAuth && widget.user == null) {
      return AuthScreen(
        onBack: () {
          setState(() {
            _showAuth = false;
            _pendingAuthAction = null;
          });
        },
      );
    }

    if (_showPaywall) {
      return PaywallScreen(
        onClose: () => setState(() => _showPaywall = false),
      );
    }


    return FutureBuilder<List<Perfume>>(
      future: _perfumesFuture,
      builder: (context, snapshot) {
        final perfumes = snapshot.data ?? kTrendingPerfumes;
        if (_showAdd) {
          return AddScreen(
            perfumes: perfumes,
            onSearchPerfumes: _useSupabase ? _searchPerfumes : null,
            onPerfumeTap: (p) async {
              setState(() => _showAdd = false);
              await _onPerfumeTap(p);
            },
            onAddToCollection: _useSupabase
                ? (p) async =>
                      _requireAuth(() => _addSearchResultToCollection(p))
                : null,
            onSaveManualEntry: _useSupabase
                ? ({
                    required String name,
                    required String concentration,
                    required String source,
                    double? price,
                    required List<String> notes,
                    String? personalNotes,
                  }) async => _requireAuth(
                    () => _saveManualEntry(
                      name: name,
                      concentration: concentration,
                      source: source,
                      price: price,
                      notes: notes,
                      personalNotes: personalNotes,
                    ),
                  )
                : null,
            onIdentifyByImage: _useSupabase ? _identifyByImage : null,
            initialTab: _addInitialTab,
            onClose: () => setState(() {
              _showAdd = false;
              _addInitialTab = null;
            }),
          );
        }
        return Scaffold(
          backgroundColor: kCream,
          body: IndexedStack(
            index: _navIndex,
            children: [
              HomeScreen(
                perfumes: perfumes,
                onPerfumeTap: _onPerfumeTap,
                displayName:
                    widget.user?.userMetadata?['name']?.toString() ??
                    widget.user?.email?.split('@').first,
                onLoadPage: _useSupabase
                    ? ({accord, required offset, required limit}) =>
                          _loadHomePerfumes(
                            accord: accord,
                            offset: offset,
                            limit: limit,
                          )
                    : null,
                onAddToCollection: _useSupabase && widget.user != null
                    ? (p) async =>
                          _requireAuth(() => _addSearchResultToCollection(p))
                    : null,
                onLoadCollectionStatuses: _useSupabase && widget.user != null
                    ? _loadUserCollection
                    : null,
                collectionVersion: _collectionVersion,
                loadDeals: _useSupabase ? _loadDeals : null,
                onLoadFavorites: _useSupabase && widget.user != null
                    ? _loadAllFavorites
                    : null,
                onToggleFavorite: _useSupabase && widget.user != null
                    ? (p, fav) async =>
                          _requireAuth(() => _toggleHomeFavorite(p, fav))
                    : null,
                onRequireAuth: _useSupabase && widget.user == null
                    ? _showLogin
                    : null,
                onSearchTap: _onAddTap,
                onAiScanTap: _useSupabase ? _onAiScanTap : null,
              ),
              CollectionScreen(
                perfumes: perfumes,
                onPerfumeTap: _onPerfumeTap,
                onAddTap: _useSupabase && widget.user == null
                    ? _requireAuthForAdd
                    : _onAddTap,
                onLoadMore: _useSupabase ? _loadPerfumeRange : null,
                requiresAuth: _useSupabase && widget.user == null,
                loadCollection: _useSupabase && widget.user != null
                    ? _loadUserCollection
                    : null,
                loadStats: _useSupabase && widget.user != null
                    ? _loadCollectionStats
                    : null,
                collectionVersion: _collectionVersion,
                onDeleteFromCollection: _useSupabase && widget.user != null
                    ? (p) async => _requireAuth(() => _deleteFromCollection(p))
                    : null,
                lookupPerfumesByIds: _useSupabase
                    ? (ids) => _supabaseRepository!.loadPerfumesByIds(ids)
                    : null,
                onRequireUpgrade: _openPaywall,
              ),
              OccasionScreen(
                perfumes: perfumes,
                onFindPerfumes: _useSupabase ? _findOccasionPerfumes : null,
                onFindByAi: _useSupabase ? _findByAi : null,
                onPerfumeTap: _onPerfumeTap,
                onRequireUpgrade: _openPaywall,
              ),
              ScentFinderScreen(
                onSearchPerfumes: _useSupabase ? _searchPerfumes : null,
                onLoadDetails: _useSupabase
                    ? (id) => _supabaseRepository!.loadPerfumeDetails(id)
                    : null,
                onFindSimilar: _useSupabase ? _findOccasionPerfumes : null,
                onFindDupesByAi: _useSupabase
                    ? (ref, price) => _supabaseRepository!.findDupesByAi(
                        ref,
                        referencePriceSar: price,
                      )
                    : null,
                onPerfumeTap: _onPerfumeTap,
                onRequireUpgrade: _openPaywall,
                initialReference: _finderInitialReference,
              ),
              widget.user != null
                  ? ProfileScreen(
                      email: widget.user?.email,
                      name: widget.user?.userMetadata?['name']?.toString(),
                      loadProfileStats: _useSupabase ? _loadProfileStats : null,
                      onSignOut: _useSupabase
                          ? () => Supabase.instance.client.auth.signOut()
                          : null,
                      onDeleteAccount: _useSupabase ? _deleteAccount : null,
                      perfumes: perfumes,
                      loadUserCollection: _useSupabase
                          ? _loadUserCollection
                          : null,
                      onUpgradeTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PaywallScreen(),
                          fullscreenDialog: true,
                        ),
                      ),
                      onOpenCustomerCenter: () =>
                          RevenueCatUI.presentCustomerCenter(),
                      onEditProfile: _useSupabase
                          ? (newName) async {
                              await Supabase.instance.client.auth.updateUser(
                                UserAttributes(data: {'name': newName}),
                              );
                            }
                          : null,
                    )
                  : AuthScreen(onBack: () => setState(() => _navIndex = 0)),
            ],
          ),
          bottomNavigationBar: _buildBottomNav(),
        );
      },
    );
  }

  Widget _buildBottomNav() {
    final l10n = AppLocalizations.of(context);
    final tabs = [
      _NavTab(
        label: l10n.homeTab,
        icon: Icons.home_rounded,
        activeIcon: Icons.home_rounded,
      ),
      _NavTab(
        label: l10n.collectionTab,
        icon: Icons.grid_view_rounded,
        activeIcon: Icons.grid_view_rounded,
      ),
      _NavTab(
        label: l10n.occasionTab,
        icon: Icons.celebration_rounded,
        activeIcon: Icons.celebration_rounded,
      ),
      _NavTab(
        label: l10n.finderTab,
        icon: Icons.auto_awesome_rounded,
        activeIcon: Icons.auto_awesome_rounded,
      ),
      _NavTab(
        label: l10n.profileTab,
        icon: Icons.person_rounded,
        activeIcon: Icons.person_rounded,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xF5FAF6F0),
        border: Border(
          top: BorderSide(color: kGold.withValues(alpha: 0.15), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: kEspresso.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: tabs.asMap().entries.map((e) {
              final i = e.key;
              final tab = e.value;
              final active = i == _navIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _navIndex = i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        active ? tab.activeIcon : tab.icon,
                        size: 22,
                        color: active ? kGold : kSand,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tab.label,
                        style: arabicStyle(
                          fontSize: 10,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: active ? kGold : kSand,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavTab {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _NavTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

// Also expose PriceTrackerScreen for routing from community/profile if needed
// ignore: unused_element
Widget _priceTrackerScreen() => const PriceTrackerScreen();
