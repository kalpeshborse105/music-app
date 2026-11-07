import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_config.dart';
import '../../core/storage/settings_store.dart';
import '../../data/music_repository.dart';
import '../../data/services/supabase_service.dart';
import '../../domain/models/advertisement.dart';
import '../../domain/models/catalog_section.dart';
import '../../domain/models/radio_station.dart';
import '../../domain/models/track.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/ad_popup_dialog.dart';
import '../widgets/glass_card.dart';
import 'home_screen.dart';

/// Full Production Admin Dashboard — Operations, Real Database Metrics,
/// User Management, Live Provider Testing, Legal Attribution, and Reports Resolution.
///
/// Protected: strictly accessible only to users with `profiles.role == 'admin'`.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  int _selectedTab = 0;
  bool _isCheckingRole = true;
  bool _isAuthorized = false;

  // Real Database Metrics State
  bool _isLoadingMetrics = true;
  Map<String, dynamic> _metrics = <String, dynamic>{};

  // Ads Management State
  bool _isLoadingAds = false;
  List<Advertisement> _ads = <Advertisement>[];

  // User Management State
  bool _isLoadingUsers = false;
  List<Map<String, dynamic>> _users = <Map<String, dynamic>>[];
  String _userSearchQuery = '';
  String _userRoleFilter = 'all';
  String _userSort = 'newest';

  // Reports State
  bool _isLoadingReports = false;
  List<Map<String, dynamic>> _reports = <Map<String, dynamic>>[];
  String _reportStatusFilter = 'all';
  String _reportSort = 'newest';

  // Ads filters
  String _adPlacementFilter = 'all';
  String _adStatusFilter = 'all';
  String _adSort = 'newest';

  // Notify filters
  String _notifyTargetFilter = 'all';
  String _notifySort = 'newest';
  int _fcmTokenCount = 0;

  // Provider Live Test States
  String? _audiusTestResult;
  bool _isTestingAudius = false;
  String? _jamendoTestResult;
  bool _isTestingJamendo = false;

  // System & Feature Flags

  // Catalogue Management State (Local-first)
  bool _isLoadingCatalog = false;
  List<CatalogSection> _catalogSections = <CatalogSection>[];
  CatalogSection? _editingSection;
  final TextEditingController _catalogUrlController = TextEditingController();
  final TextEditingController _catalogTitleController = TextEditingController();
  final TextEditingController _catalogSubtitleController = TextEditingController();
  final TextEditingController _catalogGroupController = TextEditingController();
  final TextEditingController _catalogPositionController = TextEditingController(text: '1');
  final TextEditingController _catalogArtworkController = TextEditingController();
  String _catalogLanguage = 'all';
  String _catalogGroupFilter = 'all';
  String _catalogStatusFilter = 'all'; // all | live | mock | disabled | banners | mixes
  final TextEditingController _catalogSearchController = TextEditingController();
  final Set<String> _refreshingSectionKeys = <String>{};
  bool _catalogIsEnabled = true;
  bool _catalogIsBanner = false;
  DateTime? _campaignStart;
  DateTime? _campaignEnd;
  bool _isPreviewingCatalog = false;
  bool _isSavingCatalog = false;
  String? _previewError;
  String? _detectedSourceType;
  String? _detectedSourceId;
  String? _previewProviderStatus;
  bool _previewIsMock = false;
  List<Track> _previewItems = <Track>[];
  final Set<String> _excludedTrackIds = <String>{};
  final TextEditingController _addTrackUrlController = TextEditingController();
  bool _isResolvingCustomTrack = false;

  // Radio Management State
  bool _isLoadingRadio = false;
  List<RadioStation> _adminRadioStations = <RadioStation>[];

  // Library Categories Management State
  bool _isLoadingLibraryCats = false;
  List<Map<String, dynamic>> _adminLibraryCats = <Map<String, dynamic>>[];

  late TabController _tabController;

  // Real ops only — every tab maps to live catalogue / Supabase / ads / FCM tools.
  static const List<Map<String, dynamic>> _tabs = <Map<String, dynamic>>[
    <String, dynamic>{'title': 'Overview', 'icon': Icons.dashboard_rounded},
    <String, dynamic>{'title': 'Catalogue', 'icon': Icons.queue_music_rounded},
    <String, dynamic>{'title': 'Radio', 'icon': Icons.radio_rounded},
    <String, dynamic>{'title': 'Library', 'icon': Icons.category_rounded},
    <String, dynamic>{'title': 'Ads', 'icon': Icons.campaign_rounded},
    <String, dynamic>{'title': 'Notify', 'icon': Icons.notifications_active_rounded},
    <String, dynamic>{'title': 'Users', 'icon': Icons.people_alt_rounded},
    <String, dynamic>{'title': 'Reports', 'icon': Icons.report_problem_rounded},
    <String, dynamic>{'title': 'Providers', 'icon': Icons.hub_rounded},
    <String, dynamic>{'title': 'Settings', 'icon': Icons.tune_rounded},
  ];

  bool _isLoadingNotifications = false;
  List<Map<String, dynamic>> _adminNotifications = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedTab = _tabController.index);
        _onTabSelected(_tabController.index);
      }
    });
    _verifyRole();
  }

  void _onTabSelected(int index) {
    if (index == 0) _loadPlatformMetrics();
    if (index == 1) _loadCatalogSections();
    if (index == 2) _loadRadioStations();
    if (index == 3) _loadLibraryCategories();
    if (index == 4) _loadAds();
    if (index == 5) _loadAdminNotifications();
    if (index == 6) _loadUsers();
    if (index == 7) _loadReports();
  }

  Future<void> _loadAdminNotifications() async {
    setState(() => _isLoadingNotifications = true);
    try {
      final MusicRepository repo = context.read<MusicRepository>();
      final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
        repo.fetchNotifications(limit: 100),
        repo.fetchFcmTokens(),
      ]);
      if (!mounted) return;
      setState(() {
        _adminNotifications = results[0] as List<Map<String, dynamic>>;
        _fcmTokenCount = (results[1] as List<Map<String, dynamic>>).length;
        _isLoadingNotifications = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingNotifications = false);
    }
  }

  void _goToTab(int index) {
    if (index < 0 || index >= _tabs.length) return;
    setState(() => _selectedTab = index);
    _tabController.animateTo(index);
    _onTabSelected(index);
  }

  Future<void> _loadAds() async {
    setState(() => _isLoadingAds = true);
    final List<Advertisement> list = await SupabaseService().fetchAdvertisements();
    if (mounted) {
      setState(() {
        _ads = list;
        _isLoadingAds = false;
      });
    }
  }

  Future<void> _verifyRole() async {
    final SupabaseService supabase = SupabaseService();
    // Allow local development without requiring production Supabase credentials
    final bool isAdmin = kDebugMode || await supabase.isUserAdmin();
    if (mounted) {
      setState(() {
        _isAuthorized = isAdmin;
        _isCheckingRole = false;
      });
      if (isAdmin) {
        _loadPlatformMetrics();
        _loadCatalogSections();
      }
    }
  }

  Future<void> _loadPlatformMetrics() async {
    setState(() => _isLoadingMetrics = true);
    final Map<String, dynamic> data =
        await SupabaseService().fetchAdminPlatformMetrics();
    // Warm radio list so Overview never shows "—" for Live Radio.
    if (_adminRadioStations.isEmpty) {
      try {
        await _loadRadioStations();
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _metrics = data;
        _isLoadingMetrics = false;
      });
    }
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoadingUsers = true);
    final List<Map<String, dynamic>> data =
        await SupabaseService().fetchAdminUsers();
    if (mounted) {
      setState(() {
        _users = data;
        _isLoadingUsers = false;
      });
    }
  }

  Future<void> _loadReports() async {
    setState(() => _isLoadingReports = true);
    final List<Map<String, dynamic>> data =
        await SupabaseService().fetchAdminReports();
    if (mounted) {
      setState(() {
        _reports = data;
        _isLoadingReports = false;
      });
    }
  }

  Future<void> _testAudiusConnectivity() async {
    setState(() {
      _isTestingAudius = true;
      _audiusTestResult = 'Pinging official Audius Discovery host...';
    });

    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      final http.Response res = await http.get(
        Uri.parse('https://api.audius.co/v1/tracks/trending?app_name=KalpkrutBeats&limit=1'),
        headers: <String, String>{
          'User-Agent': 'KalpkrutBeats/1.0.1 (Android; Mobile; Web)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      stopwatch.stop();
      if (res.statusCode == 200) {
        final dynamic body = jsonDecode(res.body);
        final int trackCount = (body['data'] as List?)?.length ?? 0;
        setState(() {
          _audiusTestResult =
              'SUCCESS 200 OK (${stopwatch.elapsedMilliseconds}ms)\nTracks received: $trackCount\nMetadata & stream routes functional.';
          _isTestingAudius = false;
        });
      } else {
        setState(() {
          _audiusTestResult =
              'HTTP ${res.statusCode}: ${res.reasonPhrase} (${stopwatch.elapsedMilliseconds}ms)';
          _isTestingAudius = false;
        });
      }
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _audiusTestResult = 'Connection check failed (${stopwatch.elapsedMilliseconds}ms): $e';
        _isTestingAudius = false;
      });
    }
  }

  Future<void> _testJamendoConnectivity() async {
    setState(() {
      _isTestingJamendo = true;
      _jamendoTestResult = 'Pinging Jamendo API v3.0...';
    });

    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      final http.Response res = await http.get(
        Uri.parse('https://api.jamendo.com/v3.0/tracks/?client_id=56d30c95&format=json&limit=1'),
        headers: <String, String>{
          'User-Agent': 'KalpkrutBeats/1.0.1 (Android; Mobile; Web)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      stopwatch.stop();
      if (res.statusCode == 200) {
        final dynamic body = jsonDecode(res.body);
        final int trackCount = (body['results'] as List?)?.length ?? 0;
        setState(() {
          _jamendoTestResult =
              'SUCCESS 200 OK (${stopwatch.elapsedMilliseconds}ms)\nTracks received: $trackCount\nCommercial stream pipeline online.';
          _isTestingJamendo = false;
        });
      } else {
        setState(() {
          _jamendoTestResult =
              'HTTP ${res.statusCode}: ${res.reasonPhrase} (${stopwatch.elapsedMilliseconds}ms)';
          _isTestingJamendo = false;
        });
      }
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _jamendoTestResult = 'Connection check failed (${stopwatch.elapsedMilliseconds}ms): $e';
        _isTestingJamendo = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _catalogUrlController.dispose();
    _catalogTitleController.dispose();
    _catalogSubtitleController.dispose();
    _catalogGroupController.dispose();
    _catalogPositionController.dispose();
    _catalogArtworkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = context.isDarkMode;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 800;

    if (_isCheckingRole) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightNavSurface,
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Verifying administrator credentials...'),
            ],
          ),
        ),
      );
    }

    if (!_isAuthorized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Operations Portal'),
          backgroundColor: (isDark ? AppColors.darkBg : AppColors.lightNavSurface)
              .withValues(alpha: 0.94),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.gavel_rounded, color: AppColors.error, size: 56),
                const SizedBox(height: 16),
                Text(
                  'Unauthorized Access',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your account is not registered with administrator privileges. '
                  'Access to operations and database inspection is strictly restricted.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textSecondary, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Return to Profile'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        elevation: 0,
        backgroundColor: (isDark ? AppColors.darkBg : AppColors.lightNavSurface)
            .withValues(alpha: 0.94),
        title: Row(
          children: <Widget>[
            if (!isDesktop) ...<Widget>[
              Icon(
                Icons.admin_panel_settings_rounded,
                color: isDark ? AppColors.secondary : AppColors.lightSecondaryAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              isDesktop
                  ? 'Operations Console  ›  ${_tabs[_selectedTab]['title']}'
                  : 'Admin Console',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.check_circle_rounded, size: 11, color: AppColors.success),
                  SizedBox(width: 4),
                  Text(
                    'Supabase Live',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.success),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh Metrics',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: () {
              _loadPlatformMetrics();
              _onTabSelected(_selectedTab);
            },
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Exit', style: TextStyle(fontSize: 12)),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
        ],
        bottom: !isDesktop
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: isDark ? AppColors.secondary : AppColors.lightSecondaryAccent,
                  labelColor: isDark ? AppColors.secondary : AppColors.lightSecondaryAccent,
                  unselectedLabelColor: context.textSecondary,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                  tabs: _tabs.map((Map<String, dynamic> t) {
                    return Tab(
                      height: 44,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(t['icon'] as IconData, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            t['title'] as String,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              )
            : null,
      ),
      body: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildModernAdminSidebar(context, isDark),
                Expanded(
                  child: LayoutBuilder(
                    builder: (BuildContext ctx, BoxConstraints constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - AppSpacing.lg * 2,
                            minWidth: constraints.maxWidth,
                          ),
                          child: _buildSelectedTabContent(context),
                        ),
                      );
                    },
                  ),
                ),
              ],
            )
          : TabBarView(
              controller: _tabController,
              children: <Widget>[
                SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _buildOverviewTab(context),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _buildCatalogueTab(context),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _buildRadioTab(context),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _buildLibraryTab(context),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _buildAdsTab(context),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _buildNotificationsTab(context),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _buildUsersTab(context),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _buildReportsTab(context),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _buildProvidersTab(context),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _buildSettingsTab(context),
                ),
              ],
            ),
    );
  }

  Widget _buildSelectedTabContent(BuildContext context) {
    switch (_selectedTab) {
      case 0:
        return _buildOverviewTab(context);
      case 1:
        return _buildCatalogueTab(context);
      case 2:
        return _buildRadioTab(context);
      case 3:
        return _buildLibraryTab(context);
      case 4:
        return _buildAdsTab(context);
      case 5:
        return _buildNotificationsTab(context);
      case 6:
        return _buildUsersTab(context);
      case 7:
        return _buildReportsTab(context);
      case 8:
        return _buildProvidersTab(context);
      case 9:
      default:
        return _buildSettingsTab(context);
    }
  }

  Widget _buildNotificationsTab(BuildContext context) {
    final bool isDark = context.isDarkMode;
    List<Map<String, dynamic>> list = List<Map<String, dynamic>>.from(_adminNotifications);
    if (_notifyTargetFilter != 'all') {
      list = list
          .where((Map<String, dynamic> n) =>
              '${n['target_type'] ?? 'none'}' == _notifyTargetFilter)
          .toList();
    }
    list.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
      final int ta = (a['created_at'] as num?)?.toInt() ?? 0;
      final int tb = (b['created_at'] as num?)?.toInt() ?? 0;
      return _notifySort == 'oldest' ? ta.compareTo(tb) : tb.compareTo(ta);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        EchoGlassCard(
          padding: const EdgeInsets.all(14),
          borderRadius: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.phone_android_rounded,
                      color: isDark ? AppColors.secondary : AppColors.lightSecondaryAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mobile FCM Push',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_fcmTokenCount devices',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Send OS notification to user phones with song / album preview. '
                'Uses FCM HTTP v1 (Firebase service-account JSON on API).',
                style: TextStyle(fontSize: 12, color: context.textSecondary, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Broadcast Notifications',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
            ),
            IconButton(
              onPressed: _loadAdminNotifications,
              tooltip: 'Refresh',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: const Icon(Icons.refresh_rounded, size: 22),
            ),
            FilledButton.icon(
              onPressed: _showCreateNotificationDialog,
              icon: const Icon(Icons.campaign_rounded, size: 18),
              label: const Text('Send'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'All users or selected accounts. Tap on device opens song / album / playlist.',
          style: TextStyle(fontSize: 13, color: context.textSecondary),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                initialValue: _notifyTargetFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Target',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'all', child: Text('All types')),
                  DropdownMenuItem(value: 'song', child: Text('Song')),
                  DropdownMenuItem(value: 'album', child: Text('Album')),
                  DropdownMenuItem(value: 'playlist', child: Text('Playlist')),
                  DropdownMenuItem(value: 'artist', child: Text('Artist')),
                  DropdownMenuItem(value: 'none', child: Text('None')),
                ],
                onChanged: (String? v) =>
                    setState(() => _notifyTargetFilter = v ?? 'all'),
              ),
            ),
            SizedBox(
              width: 140,
              child: DropdownButtonFormField<String>(
                initialValue: _notifySort,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Sort',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'newest', child: Text('Newest')),
                  DropdownMenuItem(value: 'oldest', child: Text('Oldest')),
                ],
                onChanged: (String? v) =>
                    setState(() => _notifySort = v ?? 'newest'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoadingNotifications)
          const Center(child: CircularProgressIndicator())
        else if (list.isEmpty)
          Text('No notifications yet.', style: TextStyle(color: context.textMuted))
        else
          ...list.map((Map<String, dynamic> n) {
            final String audience = '${n['audience'] ?? 'all'}';
            final List<dynamic> ids = (n['target_user_ids'] as List<dynamic>?) ?? <dynamic>[];
            final String image = '${n['image_url'] ?? ''}';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: EchoGlassCard(
                padding: const EdgeInsets.all(12),
                borderRadius: 14,
                child: Row(
                  children: <Widget>[
                    if (image.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          image,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.notifications_active_rounded,
                            color: AppColors.secondary,
                          ),
                        ),
                      )
                    else
                      const Icon(Icons.notifications_active_rounded,
                          color: AppColors.secondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${n['title'] ?? ''}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${n['body'] ?? ''}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: context.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${n['target_type'] ?? 'none'} → ${n['target_id'] ?? '-'} · '
                            '${audience == 'selected' ? '${ids.length} users' : 'all users'}'
                            '${n['fcm'] is Map ? ' · FCM ${(n['fcm'] as Map)['mode']}' : ''}',
                            style: TextStyle(fontSize: 11, color: context.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_rounded, size: 20),
                      onPressed: () => _showCreateNotificationDialog(existing: n),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Colors.redAccent),
                      onPressed: () async {
                        final MusicRepository repo =
                            context.read<MusicRepository>();
                        await repo.deleteNotification('${n['id']}');
                        _loadAdminNotifications();
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Future<void> _showCreateNotificationDialog({Map<String, dynamic>? existing}) async {
    if (_users.isEmpty) {
      await _loadUsers();
      if (!mounted) return;
    }
    final bool isEdit = existing != null;
    final TextEditingController titleCtrl =
        TextEditingController(text: '${existing?['title'] ?? ''}');
    final TextEditingController bodyCtrl =
        TextEditingController(text: '${existing?['body'] ?? ''}');
    final TextEditingController targetCtrl =
        TextEditingController(text: '${existing?['target_id'] ?? ''}');
    final TextEditingController imageCtrl =
        TextEditingController(text: '${existing?['image_url'] ?? ''}');
    final TextEditingController userSearchCtrl = TextEditingController();
    const List<String> allowedTargets = <String>[
      'song', 'album', 'playlist', 'artist', 'catalog', 'radio', 'none',
    ];
    String targetType = '${existing?['target_type'] ?? 'song'}'.toLowerCase().trim();
    if (!allowedTargets.contains(targetType)) targetType = 'song';
    String audience = '${existing?['audience'] ?? 'all'}';
    if (audience != 'selected') audience = 'all';
    final Set<String> selectedUserIds = <String>{
      for (final dynamic id in (existing?['target_user_ids'] as List<dynamic>? ?? <dynamic>[]))
        '$id',
    };
    String userQuery = '';
    // Always default ON — same as previous Broadcast FCM behavior (create + edit).
    bool sendFcm = true;

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setLocal) {
            final List<Map<String, dynamic>> visibleUsers = _users.where((Map<String, dynamic> u) {
              if (userQuery.isEmpty) return true;
              final String name = (u['display_name'] ?? '').toString().toLowerCase();
              final String email = (u['email'] ?? '').toString().toLowerCase();
              final String q = userQuery.toLowerCase();
              return name.contains(q) || email.contains(q);
            }).toList();

            return AlertDialog(
              title: Text(isEdit ? 'Edit notification' : 'Send notification'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(labelText: 'Title'),
                      ),
                      TextField(
                        controller: bodyCtrl,
                        decoration: const InputDecoration(labelText: 'Message'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: targetType,
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(value: 'song', child: Text('Song')),
                          DropdownMenuItem(value: 'album', child: Text('Album')),
                          DropdownMenuItem(value: 'playlist', child: Text('Playlist')),
                          DropdownMenuItem(value: 'artist', child: Text('Artist')),
                          DropdownMenuItem(value: 'catalog', child: Text('Catalog section')),
                          DropdownMenuItem(value: 'radio', child: Text('Radio')),
                          DropdownMenuItem(value: 'none', child: Text('None')),
                        ],
                        onChanged: (String? v) =>
                            setLocal(() => targetType = v ?? 'song'),
                        decoration: const InputDecoration(labelText: 'Open target'),
                      ),
                      TextField(
                        controller: targetCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Target ID / URL',
                          hintText: 'song id, album id, playlist id…',
                        ),
                      ),
                      TextField(
                        controller: imageCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Preview image URL (optional)',
                          hintText: 'Cover art for rich notification',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Audience',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                        ),
                      ),
                      // ignore: deprecated_member_use
                      RadioListTile<String>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('All users'),
                        value: 'all',
                        // ignore: deprecated_member_use
                        groupValue: audience,
                        // ignore: deprecated_member_use
                        onChanged: (String? v) =>
                            setLocal(() => audience = v ?? 'all'),
                      ),
                      // ignore: deprecated_member_use
                      RadioListTile<String>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Selected users (${selectedUserIds.length})',
                        ),
                        value: 'selected',
                        // ignore: deprecated_member_use
                        groupValue: audience,
                        // ignore: deprecated_member_use
                        onChanged: (String? v) =>
                            setLocal(() => audience = v ?? 'selected'),
                      ),
                      if (audience == 'selected') ...<Widget>[
                        Row(
                          children: <Widget>[
                            TextButton(
                              onPressed: () {
                                setLocal(() {
                                  selectedUserIds
                                    ..clear()
                                    ..addAll(visibleUsers
                                        .map((Map<String, dynamic> u) => '${u['id']}'));
                                });
                              },
                              child: const Text('Select all'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  setLocal(() => selectedUserIds.clear()),
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                        TextField(
                          controller: userSearchCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Filter users',
                            prefixIcon: Icon(Icons.search_rounded, size: 18),
                            isDense: true,
                          ),
                          onChanged: (String v) =>
                              setLocal(() => userQuery = v.trim()),
                        ),
                        const SizedBox(height: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: visibleUsers.isEmpty
                              ? Text(
                                  'No users loaded. Open Users tab once, then retry.',
                                  style: TextStyle(color: context.textMuted, fontSize: 12),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: visibleUsers.length,
                                  itemBuilder: (_, int i) {
                                    final Map<String, dynamic> u = visibleUsers[i];
                                    final String id = '${u['id']}';
                                    final String name =
                                        (u['display_name'] as String?)?.trim().isNotEmpty ==
                                                true
                                            ? u['display_name'] as String
                                            : 'Listener';
                                    final String email = '${u['email'] ?? ''}';
                                    final bool checked = selectedUserIds.contains(id);
                                    return CheckboxListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      value: checked,
                                      title: Text(name, style: const TextStyle(fontSize: 13)),
                                      subtitle: Text(email, style: const TextStyle(fontSize: 11)),
                                      onChanged: (bool? v) {
                                        setLocal(() {
                                          if (v == true) {
                                            selectedUserIds.add(id);
                                          } else {
                                            selectedUserIds.remove(id);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Also send OS push (FCM)'),
                        subtitle: Text(
                          '$_fcmTokenCount registered devices',
                          style: TextStyle(fontSize: 11, color: context.textMuted),
                        ),
                        value: sendFcm,
                        onChanged: (bool v) => setLocal(() => sendFcm = v),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (audience == 'selected' && selectedUserIds.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Select at least one user')),
                      );
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: Text(isEdit ? 'Save' : 'Broadcast'),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok != true || !mounted) return;
    try {
      final MusicRepository repo = context.read<MusicRepository>();
      final Map<String, dynamic> payload = <String, dynamic>{
        'title': titleCtrl.text.trim(),
        'body': bodyCtrl.text.trim(),
        'target_type': targetType,
        'target_id': targetCtrl.text.trim(),
        'image_url': imageCtrl.text.trim(),
        'audience': audience,
        'target_user_ids': selectedUserIds.toList(),
        'send_fcm': sendFcm,
      };
      final Map<String, dynamic> result = isEdit
          ? await repo.updateNotification('${existing['id']}', payload)
          : await repo.createNotification(payload);
      _loadAdminNotifications();
      if (!mounted) return;
      final dynamic fcm = result['fcm'];
      final String fcmHint = fcm is Map
          ? ' · FCM ${fcm['sent'] ?? 0}/${fcm['recipients'] ?? 0} (${fcm['mode']})'
          : (sendFcm ? ' · FCM pending' : '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? 'Notification updated$fcmHint'
                : 'Notification sent$fcmHint',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  // ==========================================
  // TAB: MUSIC CATALOGUE ORCHESTRATION (LOCAL-FIRST)
  // ==========================================

  Future<void> _loadCatalogSections() async {
    setState(() => _isLoadingCatalog = true);
    try {
      final MusicRepository repo = context.read<MusicRepository>();
      final List<CatalogSection> list =
          await repo.getCatalogSections(includeDisabled: true);
      if (mounted) {
        setState(() {
          _catalogSections = list;
          _isLoadingCatalog = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCatalog = false);
        debugPrint('[AdminScreen] _loadCatalogSections error: $e');
      }
    }
  }

  String _inferSourceType(String url) {
    final String lower = url.toLowerCase();
    if (lower.contains('/artist/')) return 'artist';
    if (lower.contains('/mix/') || lower.contains('/s/mix/')) return 'mix';
    if (lower.contains('/featured/') || lower.contains('/playlist/')) return 'playlist';
    if (lower.contains('/album/')) return 'album';
    if (lower.contains('/new-releases')) return 'new_releases';
    if (lower.contains('/charts')) return 'charts';
    if (lower.contains('/top-artists')) return 'top_artists';
    if (lower.contains('/radio')) return 'radio';
    if (lower.contains('api.php') || lower.contains('pid=') || lower.contains('/song/')) return 'song';
    return 'playlist';
  }

  Future<void> _previewCatalogUrl() async {
    final String url = _catalogUrlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a JioSaavn URL to preview')),
      );
      return;
    }
    setState(() {
      _isPreviewingCatalog = true;
      _previewError = null;
      _detectedSourceType ??= _inferSourceType(url);
    });

    try {
      final MusicRepository repo = context.read<MusicRepository>();
      final Map<String, dynamic> preview = await repo.previewCatalogUrl(url);

      if (mounted) {
        final List<Track> tracks = <Track>[];
        final dynamic rawItems = preview['items'] ?? preview['preview_items'];
        if (rawItems is List) {
          for (final dynamic item in rawItems) {
            if (item is Map) {
              try {
                tracks.add(Track.fromJson(Map<String, dynamic>.from(item)));
              } catch (_) {
                // Ignore parsing errors for individual items
              }
            }
          }
        }

        final String? defaultTitle = (preview['default_title'] ?? preview['detected_title']) as String?;
        final String detectedType = (preview['source_type'] as String?) ?? _inferSourceType(url);
        final String? detectedArt = (preview['custom_artwork_url'] ?? preview['detected_artwork']) as String?;
        final bool isMock = preview['is_mock'] == true;

        setState(() {
          _detectedSourceType = detectedType;
          _detectedSourceId = preview['source_id'] as String?;
          _previewProviderStatus = isMock ? 'OK [MOCK]' : 'OK [LIVE]';
          _previewIsMock = isMock;
          _previewItems = tracks;
          _isPreviewingCatalog = false;
          _previewError = null;

          if (_catalogTitleController.text.trim().isEmpty && defaultTitle != null) {
            _catalogTitleController.text = defaultTitle;
          }
          if (_catalogArtworkController.text.trim().isEmpty && detectedArt != null) {
            _catalogArtworkController.text = detectedArt;
          }
          if (_catalogGroupController.text.trim().isEmpty) {
            if (detectedType == 'artist') {
              _catalogGroupController.text = 'Featured Artists';
            } else if (detectedType == 'mix') {
              _catalogGroupController.text = 'Personalized Mixes';
            } else if (detectedType == 'playlist') {
              _catalogGroupController.text = 'Top Charts';
            } else if (detectedType == 'album') {
              final String lowerUrl = url.toLowerCase();
              _catalogGroupController.text = (lowerUrl.contains('navratri') ||
                      lowerUrl.contains('diwali') ||
                      lowerUrl.contains('special') ||
                      lowerUrl.contains('bhajan'))
                  ? 'Festival Specials'
                  : 'Featured Albums';
            } else if (detectedType == 'new_releases') {
              _catalogGroupController.text = 'New Releases';
            } else if (detectedType == 'radio') {
              _catalogGroupController.text = 'Live Radio';
            } else if (detectedType == 'song') {
              _catalogGroupController.text = 'Spotlight Tracks';
            } else {
              _catalogGroupController.text = 'Collections';
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPreviewingCatalog = false;
          _previewError = 'Preview note: ${e.toString().replaceFirst("Exception: ", "")}. You can still save this section!';
          _detectedSourceType ??= _inferSourceType(url);
          _previewIsMock = false;
          _previewItems = <Track>[];
        });
      }
    }
  }

  Future<void> _pickCampaignDateTime(bool isStart) async {
    final DateTime now = DateTime.now();
    final DateTime initial = (isStart ? _campaignStart : _campaignEnd) ?? now;
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (date == null || !mounted) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    setState(() {
      final DateTime dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (isStart) {
        _campaignStart = dt;
      } else {
        _campaignEnd = dt;
      }
    });
  }

  Future<void> _saveCatalogSection() async {
    final String url = _catalogUrlController.text.trim();
    final String title = _catalogTitleController.text.trim();
    final String subtitle = _catalogSubtitleController.text.trim();
    final String group = _catalogGroupController.text.trim();
    final String customArt = _catalogArtworkController.text.trim();
    final int pos = int.tryParse(_catalogPositionController.text.trim()) ?? 1;
    final int? campStart = _campaignStart != null ? (_campaignStart!.millisecondsSinceEpoch ~/ 1000) : null;
    final int? campEnd = _campaignEnd != null ? (_campaignEnd!.millisecondsSinceEpoch ~/ 1000) : null;

    if (url.isEmpty || title.isEmpty || group.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields (URL, Title, Group)')),
      );
      return;
    }

    if (_campaignStart != null && _campaignEnd != null && _campaignEnd!.isBefore(_campaignStart!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Campaign end time cannot be earlier than start time.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Guard: Block saving live sections when parsing fails, returns mock data, or has no resolved items
    if (_catalogIsEnabled && (_previewItems.isEmpty || _previewIsMock || _previewError != null)) {
      final bool? proceedAsDraft = await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: Row(
            children: const <Widget>[
              Icon(Icons.warning_amber_rounded, color: AppColors.secondary),
              SizedBox(width: 8),
              Text('Unverified Source Content'),
            ],
          ),
          content: Text(
            _previewItems.isEmpty
                ? 'This section returned 0 playable tracks from JioSaavn.\n\nActive catalogue sections must have live resolved tracks. Would you like to save it as a DISABLED DRAFT instead?'
                : (_previewIsMock
                    ? 'This section resolved using MOCK fallback tracks.\n\nTo prevent mock data on production, would you like to save it as a DISABLED DRAFT instead?'
                    : 'This section encountered preview errors.\n\nSave as a DISABLED DRAFT instead?'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save as Disabled Draft'),
            ),
          ],
        ),
      );
      if (proceedAsDraft != true) {
        return;
      }
      _catalogIsEnabled = false;
    }

    if (!mounted) return;
    setState(() => _isSavingCatalog = true);
    final MusicRepository repo = context.read<MusicRepository>();

    try {
      if (_editingSection != null) {
        await repo.updateCatalogSection(
          _editingSection!.sectionKey,
          displayTitle: title,
          displayGroup: group,
          subtitle: subtitle.isNotEmpty ? subtitle : null,
          language: _catalogLanguage,
          position: pos,
          isEnabled: _catalogIsEnabled,
          customArtworkUrl: customArt.isNotEmpty ? customArt : null,
          isBanner: _catalogIsBanner,
          campaignStart: campStart,
          campaignEnd: campEnd,
          sourceUrl: url,
          excludedTrackIds: _excludedTrackIds.toList(),
        );
      } else {
        // Omit position — API inserts new shelf first inside this display group
        // without moving other Home groups.
        await repo.createCatalogSection(
          sourceUrl: url,
          displayTitle: title,
          displayGroup: group,
          subtitle: subtitle.isNotEmpty ? subtitle : null,
          language: _catalogLanguage,
          isEnabled: _catalogIsEnabled,
          customArtworkUrl: customArt.isNotEmpty ? customArt : null,
          isBanner: _catalogIsBanner,
          campaignStart: campStart,
          campaignEnd: campEnd,
          excludedTrackIds: _excludedTrackIds.toList(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editingSection != null
                ? 'Section "$title" updated successfully'
                : 'Section "$title" created successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        _cancelCatalogEdit();
        await repo.getCatalogSections(forceRefresh: true);
        await _loadCatalogSections();
        HomeScreen.silentRefreshLatest();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save section: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingCatalog = false);
      }
    }
  }

  Future<void> _addCustomTrack() async {
    final String input = _addTrackUrlController.text.trim();
    if (input.isEmpty) return;
    setState(() => _isResolvingCustomTrack = true);
    try {
      final MusicRepository repo = context.read<MusicRepository>();
      final Track? track = await repo.resolveTrack(input);
      if (track != null) {
        setState(() {
          _previewItems.insert(0, track);
          _excludedTrackIds.remove(track.id);
          _addTrackUrlController.clear();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added track: "${track.title}"'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not resolve song from URL/ID'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding track: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResolvingCustomTrack = false);
    }
  }

  void _startEditSection(CatalogSection s) {
    setState(() {
      _editingSection = s;
      _catalogUrlController.text = s.sourceUrl;
      _catalogTitleController.text = s.displayTitle;
      _catalogSubtitleController.text = s.subtitle ?? '';
      _catalogGroupController.text = s.displayGroup;
      _catalogArtworkController.text = s.customArtworkUrl ?? '';
      _catalogLanguage = s.language;
      _catalogPositionController.text = s.position.toString();
      _catalogIsEnabled = s.isEnabled;
      _catalogIsBanner = s.isBanner;
      _campaignStart = s.campaignStart != null
          ? DateTime.fromMillisecondsSinceEpoch(s.campaignStart! * 1000)
          : null;
      _campaignEnd = s.campaignEnd != null
          ? DateTime.fromMillisecondsSinceEpoch(s.campaignEnd! * 1000)
          : null;
      _detectedSourceType = s.sourceType;
      _detectedSourceId = s.sourceId;
      _previewProviderStatus = s.providerStatus;
      _previewIsMock = s.isMock;
      _previewItems = List<Track>.from(s.items);
      _excludedTrackIds.clear();
      _excludedTrackIds.addAll(s.excludedTrackIds);
      _previewError = null;
    });
  }

  void _cancelCatalogEdit() {
    setState(() {
      _editingSection = null;
      _catalogUrlController.clear();
      _catalogTitleController.clear();
      _catalogSubtitleController.clear();
      _catalogGroupController.clear();
      _catalogArtworkController.clear();
      _catalogPositionController.text = (_catalogSections.length + 1).toString();
      _catalogLanguage = 'all';
      _catalogIsEnabled = true;
      _catalogIsBanner = false;
      _campaignStart = null;
      _campaignEnd = null;
      _detectedSourceType = null;
      _detectedSourceId = null;
      _previewProviderStatus = null;
      _previewIsMock = false;
      _previewItems = <Track>[];
      _excludedTrackIds.clear();
      _addTrackUrlController.clear();
      _previewError = null;
    });
  }

  Future<void> _toggleCatalogSection(CatalogSection s) async {
    final MusicRepository repo = context.read<MusicRepository>();
    try {
      await repo.toggleCatalogSection(s.sectionKey, !s.isEnabled);
      await repo.getCatalogSections(forceRefresh: true);
      await _loadCatalogSections();
      HomeScreen.silentRefreshLatest();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle status: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteCatalogSection(CatalogSection s) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete Catalogue Section?'),
        content: Text('Are you sure you want to remove "${s.displayTitle}" from the catalogue?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      try {
        final MusicRepository repo = context.read<MusicRepository>();
        await repo.deleteCatalogSection(s.key);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted "${s.displayTitle}"'), backgroundColor: AppColors.success),
          );
          await repo.getCatalogSections(forceRefresh: true);
          await _loadCatalogSections();
          HomeScreen.silentRefreshLatest();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Future<void> _persistCatalogOrder(List<CatalogSection> updated) async {
    // Assign unique 1..N positions locally so Home never sees duplicate ranks.
    final List<CatalogSection> renumbered = <CatalogSection>[
      for (int i = 0; i < updated.length; i++)
        updated[i].copyWith(position: i + 1),
    ];
    final List<String> orderedKeys =
        renumbered.map((CatalogSection s) => s.sectionKey).toList();
    setState(() => _catalogSections = renumbered);
    try {
      final MusicRepository repo = context.read<MusicRepository>();
      final bool ok = await repo.reorderCatalogSections(orderedKeys);
      if (ok) {
        // Force-pull so disk/API cache matches the new Home order
        await repo.getCatalogSections(includeDisabled: true, forceRefresh: true);
        await repo.getCatalogSections(forceRefresh: true);
        HomeScreen.silentRefreshLatest();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order saved — Home will show this sequence'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reorder: $e'),
            backgroundColor: AppColors.error,
          ),
        );
        await _loadCatalogSections();
      }
    }
  }

  /// Move a shelf up/down **inside its group** (1st in group stays #1 there).
  Future<void> _moveCatalogSectionInGroup(
    List<CatalogSection> groupSections,
    int fromGroupIndex,
    int toGroupIndex,
  ) async {
    if (fromGroupIndex == toGroupIndex) return;
    if (toGroupIndex < 0 || toGroupIndex >= groupSections.length) return;

    final List<CatalogSection> reorderedGroup =
        List<CatalogSection>.from(groupSections);
    final CatalogSection moved = reorderedGroup.removeAt(fromGroupIndex);
    reorderedGroup.insert(toGroupIndex, moved);

    final Set<String> groupKeys =
        groupSections.map((CatalogSection s) => s.sectionKey).toSet();
    final List<CatalogSection> queue =
        List<CatalogSection>.from(reorderedGroup);
    final List<CatalogSection> updated = <CatalogSection>[];
    for (final CatalogSection s in _catalogSections) {
      if (groupKeys.contains(s.sectionKey)) {
        updated.add(queue.removeAt(0));
      } else {
        updated.add(s);
      }
    }
    await _persistCatalogOrder(updated);
  }

  /// Move an entire display group up/down — Home shows groups in this order.
  Future<void> _moveCatalogGroup(
    List<String> orderedGroups,
    int fromIndex,
    int toIndex,
  ) async {
    if (toIndex < 0 || toIndex >= orderedGroups.length) return;
    if (fromIndex == toIndex) return;

    // Always reorder against the full catalogue so filters can't orphan groups.
    String groupOf(CatalogSection s) =>
        s.displayGroup.isNotEmpty ? s.displayGroup : 'other';

    final Map<String, List<CatalogSection>> byGroup =
        <String, List<CatalogSection>>{};
    for (final CatalogSection s in _catalogSections) {
      byGroup.putIfAbsent(groupOf(s), () => <CatalogSection>[]).add(s);
    }
    for (final List<CatalogSection> list in byGroup.values) {
      list.sort(
        (CatalogSection a, CatalogSection b) =>
            a.position.compareTo(b.position),
      );
    }

    int minGroupPos(String g) {
      final List<CatalogSection>? list = byGroup[g];
      if (list == null || list.isEmpty) return 1 << 30;
      return list.first.position;
    }

    // Full group list sorted like Home, then apply the visible ↑↓ move.
    final List<String> groups = byGroup.keys.toList()
      ..sort((String a, String b) => minGroupPos(a).compareTo(minGroupPos(b)));
    final String movedName = orderedGroups[fromIndex];
    final int fullFrom = groups.indexOf(movedName);
    if (fullFrom < 0) return;
    final int delta = toIndex - fromIndex;
    final int fullTo = (fullFrom + delta).clamp(0, groups.length - 1);
    if (fullTo == fullFrom) return;
    final String moved = groups.removeAt(fullFrom);
    groups.insert(fullTo, moved);

    final List<CatalogSection> updated = <CatalogSection>[];
    for (final String g in groups) {
      updated.addAll(byGroup[g] ?? const <CatalogSection>[]);
    }
    await _persistCatalogOrder(updated);
  }

  Future<void> _refreshCatalogSection(CatalogSection section) async {
    final String key = section.sectionKey;
    if (_refreshingSectionKeys.contains(key)) return;
    setState(() => _refreshingSectionKeys.add(key));
    try {
      final MusicRepository repo = context.read<MusicRepository>();
      final CatalogSection? updated = await repo.refreshCatalogSection(key);
      if (mounted && updated != null) {
        setState(() {
          final int idx = _catalogSections.indexWhere((CatalogSection s) => s.key == key || s.id == updated.id);
          if (idx != -1) {
            _catalogSections[idx] = updated;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refreshed "${section.displayTitle}" (${updated.items.length} tracks, ${updated.providerStatus.toUpperCase()})'),
            backgroundColor: updated.isMock ? AppColors.secondary : AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh section: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _refreshingSectionKeys.remove(key));
      }
    }
  }

  Future<void> _refreshAllCatalogSections() async {
    setState(() => _isLoadingCatalog = true);
    final MusicRepository repo = context.read<MusicRepository>();
    try {
      // Always pull full catalogue so every enabled shelf is refreshed from JioSaavn
      List<CatalogSection> list = await repo.getCatalogSections(
        includeDisabled: true,
        forceRefresh: true,
      );

      int ok = 0;
      int failed = 0;
      // Refresh every enabled shelf (skip disabled drafts)
      final List<CatalogSection> targets = list
          .where((CatalogSection s) => s.isEnabled)
          .toList();
      for (final CatalogSection section in targets) {
        if (!mounted) return;
        setState(() => _refreshingSectionKeys.add(section.sectionKey));
        try {
          final CatalogSection? updated =
              await repo.refreshCatalogSection(section.sectionKey);
          if (updated != null) {
            ok++;
            final int idx = list.indexWhere(
              (CatalogSection s) => s.sectionKey == section.sectionKey,
            );
            if (idx >= 0) list[idx] = updated;
          } else {
            failed++;
          }
        } catch (_) {
          failed++;
        } finally {
          if (mounted) {
            setState(() => _refreshingSectionKeys.remove(section.sectionKey));
          }
        }
      }

      list = await repo.getCatalogSections(
        includeDisabled: true,
        forceRefresh: true,
      );
      await repo.getCatalogSections(forceRefresh: true);
      HomeScreen.silentRefreshLatest();
      if (!mounted) return;
      setState(() {
        _catalogSections = list;
        _isLoadingCatalog = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failed == 0
                ? 'Refreshed $ok catalogue shelves from live sources'
                : 'Refreshed $ok shelves ($failed failed)',
          ),
          backgroundColor: failed == 0 ? AppColors.success : AppColors.secondary,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCatalog = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refresh all failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _formatLastRefresh(int ts) {
    if (ts <= 0) return 'Never';
    final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final int diff = now - ts;
    if (diff < 60) return 'Just now';
    if (diff < 3600) return '${diff ~/ 60}m ago';
    if (diff < 86400) return '${diff ~/ 3600}h ago';
    return '${diff ~/ 86400}d ago';
  }

  Widget _buildQuickUrlChip(String label, String url) {
    return ActionChip(
      avatar: const Icon(Icons.bolt_rounded, size: 14, color: AppColors.secondary),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: () {
        setState(() {
          _catalogUrlController.text = url;
          _previewError = null;
        });
        _previewCatalogUrl();
      },
    );
  }

  Widget _buildCatalogSectionCard(
    BuildContext context,
    CatalogSection section, {
    required int displayNumber,
    required bool canMoveUp,
    required bool canMoveDown,
    required VoidCallback onMoveUp,
    required VoidCallback onMoveDown,
  }) {
    final bool isDark = context.isDarkMode;
    final bool isRefreshing = _refreshingSectionKeys.contains(section.sectionKey);
    final bool isMix = section.sourceType == 'mix' || section.sourceType == 'jiosaavn_mix';

    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints constraints) {
        final bool isNarrow = constraints.maxWidth < 640;

        if (isNarrow) {
          // Phone stacked layout
          return EchoGlassCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            borderRadius: 14,
            backgroundColor: isDark ? null : AppColors.lightSurface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Top row: artwork, title and enabled switch
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (section.effectiveArtworkUrl != null && section.effectiveArtworkUrl!.isNotEmpty) ...<Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          section.effectiveArtworkUrl!,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 44,
                            height: 44,
                            color: isDark ? AppColors.surfaceContainerHigh : AppColors.lightInputBackground,
                            child: const Icon(Icons.music_note_rounded, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            section.displayTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: section.isEnabled ? context.textPrimary : context.textMuted,
                              decoration: section.isEnabled ? null : TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            section.sourceUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 11,
                              color: context.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: section.isEnabled,
                      onChanged: (_) => _toggleCatalogSection(section),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Second row: Badges using Wrap
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isMix ? AppColors.electricViolet : AppColors.secondary).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        section.sourceType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: isMix ? AppColors.electricViolet : AppColors.secondary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceContainerHigh : AppColors.lightElevatedSurface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        section.displayGroup,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: context.textSecondary,
                        ),
                      ),
                    ),
                    if (section.isBanner)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.primary, width: 0.8),
                        ),
                        child: const Text(
                          'BANNER',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (section.isMock
                                ? AppColors.secondary
                                : (section.providerStatus == 'stale'
                                    ? Colors.orange
                                    : AppColors.success))
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        section.isMock
                            ? 'MOCK'
                            : (section.providerStatus == 'stale' ? 'STALE' : 'LIVE'),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: section.isMock
                              ? AppColors.secondary
                              : (section.providerStatus == 'stale'
                                  ? Colors.orange
                                  : AppColors.success),
                        ),
                      ),
                    ),
                    if (section.lastError != null && section.lastError!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'ERR: ${section.lastError}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    if (section.campaignStart != null || section.campaignEnd != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (section.isCampaignActive ? AppColors.success : AppColors.error).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          section.isCampaignActive ? 'CAMPAIGN ACTIVE' : 'CAMPAIGN INACTIVE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: section.isCampaignActive ? AppColors.success : AppColors.error,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),

                // Metadata row
                Text(
                  '${section.items.length} tracks • Lang: ${section.language.toUpperCase()} • Refreshed: ${_formatLastRefresh(section.lastRefresh)}',
                  style: TextStyle(fontSize: 10.5, color: context.textMuted),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 6),

                // Bottom row: Reorder controls & action buttons with readable touch targets
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#$displayNumber',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryLight,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                      tooltip: 'Move Up in section',
                      onPressed: canMoveUp ? onMoveUp : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                      tooltip: 'Move Down in section',
                      onPressed: canMoveDown ? onMoveDown : null,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: isRefreshing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded, size: 18),
                      tooltip: 'Refresh Section from Provider',
                      onPressed: isRefreshing ? null : () => _refreshCatalogSection(section),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Edit'),
                      onPressed: () => _startEditSection(section),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
                      tooltip: 'Delete Section',
                      onPressed: () => _deleteCatalogSection(section),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        // Desktop / Tablet horizontal layout (>= 640px)
        return EchoGlassCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          borderRadius: 14,
          backgroundColor: isDark ? null : AppColors.lightSurface,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Section-wise position (#1 = first in this group) + reorder
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  InkWell(
                    onTap: canMoveUp ? onMoveUp : null,
                    borderRadius: BorderRadius.circular(4),
                    child: Icon(
                      Icons.arrow_drop_up_rounded,
                      size: 24,
                      color: canMoveUp
                          ? context.textPrimary
                          : context.textMuted.withValues(alpha: 0.3),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#$displayNumber',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: canMoveDown ? onMoveDown : null,
                    borderRadius: BorderRadius.circular(4),
                    child: Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 24,
                      color: canMoveDown
                          ? context.textPrimary
                          : context.textMuted.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Artwork Thumbnail if available
              if (section.effectiveArtworkUrl != null && section.effectiveArtworkUrl!.isNotEmpty) ...<Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    section.effectiveArtworkUrl!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 44,
                      height: 44,
                      color: isDark ? AppColors.surfaceContainerHigh : AppColors.lightInputBackground,
                      child: const Icon(Icons.music_note_rounded, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],

              // Main Section Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            section.displayTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: section.isEnabled ? context.textPrimary : context.textMuted,
                              decoration: section.isEnabled ? null : TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isMix ? AppColors.electricViolet : AppColors.secondary).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            section.sourceType.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: isMix ? AppColors.electricViolet : AppColors.secondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceContainerHigh : AppColors.lightElevatedSurface,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            section.displayGroup,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: context.textSecondary,
                            ),
                          ),
                        ),
                        if (section.isBanner) ...<Widget>[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.primary, width: 0.8),
                            ),
                            child: const Text(
                              'BANNER',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primaryLight,
                              ),
                            ),
                          ),
                        ],
                        if (section.lastError != null && section.lastError!.isNotEmpty) ...<Widget>[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'ERR: ${section.lastError}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      section.sourceUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 11,
                        color: context.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (section.isMock
                                    ? AppColors.secondary
                                    : (section.providerStatus == 'stale'
                                        ? Colors.orange
                                        : AppColors.success))
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            section.isMock
                                ? 'MOCK'
                                : (section.providerStatus == 'stale' ? 'STALE' : 'LIVE'),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: section.isMock
                                  ? AppColors.secondary
                                  : (section.providerStatus == 'stale'
                                      ? Colors.orange
                                      : AppColors.success),
                            ),
                          ),
                        ),
                        if (section.campaignStart != null || section.campaignEnd != null) ...<Widget>[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (section.isCampaignActive ? AppColors.success : AppColors.error).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              section.isCampaignActive ? 'CAMPAIGN ACTIVE' : 'CAMPAIGN INACTIVE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: section.isCampaignActive ? AppColors.success : AppColors.error,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Text(
                          '${section.items.length} tracks • Lang: ${section.language.toUpperCase()} • Refreshed: ${_formatLastRefresh(section.lastRefresh)}',
                          style: TextStyle(fontSize: 10.5, color: context.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Actions: Refresh Now, Enabled Switch, Edit, Delete
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    icon: isRefreshing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: 'Refresh Section Now',
                    onPressed: isRefreshing ? null : () => _refreshCatalogSection(section),
                  ),
                  Switch(
                    value: section.isEnabled,
                    onChanged: (_) => _toggleCatalogSection(section),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 20),
                    tooltip: 'Edit Section',
                    onPressed: () => _startEditSection(section),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
                    tooltip: 'Delete Section',
                    onPressed: () => _deleteCatalogSection(section),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCatalogueTab(BuildContext context) {
    final bool isDark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Title & Description
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Catalogue Orchestration',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Admin-managed catalogue sections for App & Web. Local-first configuration.',
                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                ),
              ],
            ),
            Row(
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: _isLoadingCatalog ? null : _refreshAllCatalogSections,
                  icon: _isLoadingCatalog
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded, size: 18),
                  label: const Text('Refresh All', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Reload Sections List',
                  onPressed: _loadCatalogSections,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Live Gateway Status Alert Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.cloud_done_rounded, color: AppColors.success, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'LIVE CATALOGUE GATEWAY ACTIVE: Connected to live music backend. Configure dynamic playlists, seasonal festival takeovers, top charts, and artist highlights directly for App & Web.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Form Card: Add or Edit Catalogue Section
        EchoGlassCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          borderRadius: 16,
          backgroundColor: isDark ? null : AppColors.lightSurface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    _editingSection != null
                        ? 'Edit Catalogue Section'
                        : 'Add New Catalogue Section',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ),
                  if (_editingSection != null)
                    TextButton.icon(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Cancel Edit'),
                      onPressed: _cancelCatalogEdit,
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Quick-fill chips for local testing
              Text(
                'Quick-Fill Supported Test URLs:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: <Widget>[
                  _buildQuickUrlChip(
                    'Hindi Releases',
                    'https://www.jiosaavn.com/new-releases/hindi',
                  ),
                  _buildQuickUrlChip(
                    'All New Releases',
                    'http://jiosaavn.com/new-releases/',
                  ),
                  _buildQuickUrlChip(
                    'Live Radio',
                    'https://www.jiosaavn.com/radio',
                  ),
                  _buildQuickUrlChip(
                    'Network Song PID',
                    'https://www.jiosaavn.com/api.php?__call=song.generateAuthToken&pid=w6i2r54Z',
                  ),
                  _buildQuickUrlChip(
                    'Hindi Top 50',
                    'https://www.jiosaavn.com/featured/hindi-india-superhits-top-50/zlJfJYVuyjpxWb5,FqsjKg__',
                  ),
                  _buildQuickUrlChip(
                    'Daily Mix 2',
                    'https://www.jiosaavn.com/s/mix/daily_mix_2/gqr026sjjg5EycPt65hWSv9qnJHMxyN4MeBKaZmPvCCAFfS7n,cswwZHpEuo2hRsPnpS-,sujNQ4ntm,PDU0YLdZVNQiypBe',
                  ),
                  _buildQuickUrlChip(
                    'Kishore Kumar',
                    'https://www.jiosaavn.com/artist/kishore-kumar-songs/yMoPyl3ZzyY_',
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Source URL Input
              TextField(
                controller: _catalogUrlController,
                decoration: InputDecoration(
                  labelText: 'JioSaavn Source URL *',
                  hintText: 'https://www.jiosaavn.com/...',
                  prefixIcon: const Icon(Icons.link_rounded),
                  suffixIcon: IconButton(
                    icon: _isPreviewingCatalog
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.manage_search_rounded),
                    tooltip: 'Detect URL & Preview',
                    onPressed: _isPreviewingCatalog ? null : _previewCatalogUrl,
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: isDark ? AppColors.surfaceContainerHigh : AppColors.lightInputBackground,
                ),
                onSubmitted: (_) => _previewCatalogUrl(),
              ),
              const SizedBox(height: 10),

              // Preview Action Button
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: _isPreviewingCatalog ? null : _previewCatalogUrl,
                  icon: _isPreviewingCatalog
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.travel_explore_rounded, size: 18),
                  label: const Text('Detect Type & Preview'),
                ),
              ),

              // Validation Error Banner
              if (_previewError != null) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _previewError!,
                          style: const TextStyle(color: AppColors.error, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Detected Details Status Badge (Visible if detected or editing)
              if (_detectedSourceType != null) ...<Widget>[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceContainerLow : AppColors.lightElevatedSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? AppColors.borderSubtle : AppColors.lightBorder),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary),
                        ),
                        child: Text(
                          'TYPE: ${_detectedSourceType!.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_detectedSourceId != null)
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.secondary),
                            ),
                            child: Text(
                              'ID: $_detectedSourceId',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                        ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (_previewIsMock ? AppColors.secondary : AppColors.success).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _previewProviderStatus ?? (_previewIsMock ? 'OK [MOCK]' : 'OK [LIVE]'),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: _previewIsMock ? AppColors.secondary : AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Form Inputs (Unconditionally Visible)
              LayoutBuilder(
                builder: (BuildContext ctx, BoxConstraints constraints) {
                  final bool isWide = constraints.maxWidth >= 600;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (isWide)
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: TextField(
                                controller: _catalogTitleController,
                                decoration: InputDecoration(
                                  labelText: 'Display Title Override *',
                                  hintText: 'e.g. Hindi Superhits Top 50, Navratri Specials',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  filled: true,
                                  fillColor: isDark ? AppColors.surfaceContainerHigh : AppColors.lightInputBackground,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _catalogGroupController,
                                decoration: InputDecoration(
                                  labelText: 'Display Group *',
                                  hintText: 'e.g. Top Charts, Festival Specials, Featured',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  filled: true,
                                  fillColor: isDark ? AppColors.surfaceContainerHigh : AppColors.lightInputBackground,
                                ),
                              ),
                            ),
                          ],
                        )
                      else ...<Widget>[
                        TextField(
                          controller: _catalogTitleController,
                          decoration: InputDecoration(
                            labelText: 'Display Title Override *',
                            hintText: 'e.g. Hindi Superhits Top 50, Navratri Specials',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: isDark ? AppColors.surfaceContainerHigh : AppColors.lightInputBackground,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _catalogGroupController,
                          decoration: InputDecoration(
                            labelText: 'Display Group *',
                            hintText: 'e.g. Top Charts, Festival Specials, Featured',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: isDark ? AppColors.surfaceContainerHigh : AppColors.lightInputBackground,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),

                      // Quick Category Chips — presets + groups already used in catalogue
                      Builder(
                        builder: (BuildContext chipCtx) {
                          const List<String> presets = <String>[
                            'All Time Great',
                            'Top Charts',
                            'Featured Playlists',
                            'Festival Specials',
                            'Trending Now',
                            'Devotional & Bhakti',
                            'Featured Artists',
                            'Fresh Drops',
                            'New Releases',
                          ];
                          final Set<String> seen = <String>{};
                          final List<String> chips = <String>[];
                          for (final String g in presets) {
                            if (seen.add(g.toLowerCase())) chips.add(g);
                          }
                          for (final CatalogSection s in _catalogSections) {
                            final String g = s.displayGroup.trim();
                            if (g.isEmpty) continue;
                            if (seen.add(g.toLowerCase())) chips.add(g);
                          }
                          return Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: chips.map((String grp) {
                              final bool selected =
                                  _catalogGroupController.text.trim().toLowerCase() ==
                                  grp.toLowerCase();
                              return ActionChip(
                                visualDensity: VisualDensity.compact,
                                backgroundColor: selected
                                    ? AppColors.primary.withValues(alpha: 0.25)
                                    : null,
                                label: Text(
                                  grp,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _catalogGroupController.text = grp;
                                  });
                                },
                              );
                            }).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 14),

                      // Subtitle / Campaign Tagline (Optional)
                      TextField(
                        controller: _catalogSubtitleController,
                        decoration: InputDecoration(
                          labelText: 'Subtitle / Campaign Tagline (Optional)',
                          hintText: 'e.g. Celebrate Navratri & Diwali with sacred devotional beats',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: isDark ? AppColors.surfaceContainerHigh : AppColors.lightInputBackground,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Custom Cover Artwork URL (with live preview)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: _catalogArtworkController,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: 'Cover Artwork URL (Optional override)',
                                hintText: 'https://c.saavncdn.com/... (leave blank for default)',
                                prefixIcon: const Icon(Icons.image_outlined),
                                suffixIcon: _catalogArtworkController.text.trim().isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded, size: 20),
                                        tooltip: 'Clear override (use source artwork)',
                                        onPressed: () {
                                          setState(() {
                                            _catalogArtworkController.clear();
                                          });
                                        },
                                      )
                                    : null,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                filled: true,
                                fillColor: isDark ? AppColors.surfaceContainerHigh : AppColors.lightInputBackground,
                              ),
                            ),
                          ),
                          if (_catalogArtworkController.text.trim().isNotEmpty) ...<Widget>[
                            const SizedBox(width: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _catalogArtworkController.text.trim(),
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 50,
                                  height: 50,
                                  color: Colors.grey.shade800,
                                  child: const Icon(Icons.broken_image_rounded, size: 22, color: Colors.white54),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Language Preference & Position
                      Row(
                        children: <Widget>[
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: _catalogLanguage,
                              decoration: InputDecoration(
                                labelText: 'Language Preference',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                filled: true,
                                fillColor: isDark ? AppColors.surfaceContainerHigh : AppColors.lightInputBackground,
                              ),
                              items: const <String>[
                                'all',
                                'hindi',
                                'punjabi',
                                'marathi',
                                'gujarati',
                                'bhojpuri',
                                'haryanvi',
                                'tamil',
                                'telugu',
                                'english'
                              ].map((String lang) {
                                return DropdownMenuItem<String>(
                                  value: lang,
                                  child: Text(lang.toUpperCase()),
                                );
                              }).toList(),
                              onChanged: (String? val) {
                                if (val != null) setState(() => _catalogLanguage = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: _catalogPositionController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Position',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                filled: true,
                                fillColor: isDark ? AppColors.surfaceContainerHigh : AppColors.lightInputBackground,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Switches Row: Feature as Banner & Enabled
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.surfaceContainerLow : AppColors.lightElevatedSurface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDark ? AppColors.borderSubtle : AppColors.lightBorder),
                              ),
                              child: Row(
                                children: <Widget>[
                                  const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryLight, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          'Top Festival / Hero Banner',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.5,
                                            color: context.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          'Showcase prominently on home header',
                                          style: TextStyle(fontSize: 10.5, color: context.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _catalogIsBanner,
                                    onChanged: (bool v) => setState(() => _catalogIsBanner = v),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.surfaceContainerLow : AppColors.lightElevatedSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isDark ? AppColors.borderSubtle : AppColors.lightBorder),
                            ),
                            child: Row(
                              children: <Widget>[
                                Text(
                                  'Enabled',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: context.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Switch(
                                  value: _catalogIsEnabled,
                                  onChanged: (bool v) => setState(() => _catalogIsEnabled = v),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Festival & Seasonal Campaign Scheduling Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceContainerLow : AppColors.lightElevatedSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (_campaignStart != null || _campaignEnd != null)
                                ? AppColors.primary
                                : (isDark ? AppColors.borderSubtle : AppColors.lightBorder),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                const Icon(Icons.event_available_rounded, size: 18, color: AppColors.primaryLight),
                                const SizedBox(width: 8),
                                Text(
                                  'Campaign / Festival Schedule (Optional)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                    color: context.textPrimary,
                                  ),
                                ),
                                const Spacer(),
                                if (_campaignStart != null || _campaignEnd != null)
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () => setState(() {
                                      _campaignStart = null;
                                      _campaignEnd = null;
                                    }),
                                    child: const Text('Clear Schedule', style: TextStyle(fontSize: 11)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _pickCampaignDateTime(true),
                                    icon: const Icon(Icons.access_time_rounded, size: 16),
                                    label: Text(
                                      _campaignStart != null
                                          ? 'Start: ${_campaignStart!.day}/${_campaignStart!.month}/${_campaignStart!.year} ${_campaignStart!.hour.toString().padLeft(2, "0")}:${_campaignStart!.minute.toString().padLeft(2, "0")}'
                                          : 'Start: Immediate',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _pickCampaignDateTime(false),
                                    icon: const Icon(Icons.timer_off_rounded, size: 16),
                                    label: Text(
                                      _campaignEnd != null
                                          ? 'End: ${_campaignEnd!.day}/${_campaignEnd!.month}/${_campaignEnd!.year} ${_campaignEnd!.hour.toString().padLeft(2, "0")}:${_campaignEnd!.minute.toString().padLeft(2, "0")}'
                                          : 'End: No Expiry',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),

              // Add Song via JioSaavn URL or ID (Direct Custom Track Integration)
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _addTrackUrlController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Add Song to Section by JioSaavn URL or ID',
                        hintText: 'https://www.jiosaavn.com/song/... or song token',
                        hintStyle: TextStyle(fontSize: 11.5, color: context.textMuted),
                        prefixIcon: const Icon(Icons.music_note_rounded, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onSubmitted: (_) => _addCustomTrack(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onPressed: _isResolvingCustomTrack ? null : _addCustomTrack,
                    icon: _isResolvingCustomTrack
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Track', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),

              // Resolved Preview Tracks List
              if (_previewItems.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Resolved Items Preview (${_previewItems.length - _excludedTrackIds.length} active, ${_excludedTrackIds.length} excluded / ${_previewItems.length} total):',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.textSecondary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (_previewIsMock ? AppColors.secondary : AppColors.success).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _previewIsMock ? '[MOCK DATA]' : '[LIVE DATA]',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _previewIsMock ? AppColors.secondary : AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 140,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceContainerLowest : AppColors.lightElevatedSurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(8),
                    itemCount: _previewItems.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (BuildContext ctx, int i) {
                      final Track track = _previewItems[i];
                      final bool isExcluded = _excludedTrackIds.contains(track.id);

                      return Opacity(
                        opacity: isExcluded ? 0.42 : 1.0,
                        child: Container(
                          width: 175,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceContainerHigh : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isExcluded
                                  ? Colors.redAccent.withValues(alpha: 0.5)
                                  : (isDark ? AppColors.borderSubtle : AppColors.lightBorder),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      track.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11.5,
                                        decoration: isExcluded ? TextDecoration.lineThrough : null,
                                        color: isExcluded ? context.textMuted : null,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: Icon(
                                      isExcluded
                                          ? Icons.add_circle_outline_rounded
                                          : Icons.remove_circle_outline_rounded,
                                      color: isExcluded ? AppColors.success : Colors.redAccent,
                                      size: 19,
                                    ),
                                    tooltip: isExcluded
                                        ? 'Restore / Include song in section'
                                        : 'Exclude song (will not be added)',
                                    onPressed: () {
                                      setState(() {
                                        if (isExcluded) {
                                          _excludedTrackIds.remove(track.id);
                                        } else {
                                          _excludedTrackIds.add(track.id);
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                track.artistNames,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: context.textSecondary, fontSize: 10),
                              ),
                              const Spacer(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  if (isExcluded)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'EXCLUDED',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    )
                                  else
                                    Text(
                                      track.duration.inSeconds > 0
                                          ? '${track.duration.inMinutes}:${(track.duration.inSeconds % 60).toString().padLeft(2, "0")}'
                                          : '--:--',
                                      style: TextStyle(color: context.textMuted, fontSize: 9.5),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 16),
              // Save Button
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  if (_editingSection != null)
                    OutlinedButton(
                      onPressed: _cancelCatalogEdit,
                      child: const Text('Cancel'),
                    ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: _isSavingCatalog ? null : _saveCatalogSection,
                    icon: _isSavingCatalog
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_rounded, size: 18),
                    label: Text(_editingSection != null ? 'Update Section' : 'Save Section'),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // List of configured sections
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'Configured Sections (${_catalogSections.length})',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
            if (_isLoadingCatalog)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 14),

        _buildConfiguredSectionsArea(context, isDark),
      ],
    );
  }

  Widget _buildConfiguredSectionsArea(BuildContext context, bool isDark) {
    if (_catalogSections.isEmpty && !_isLoadingCatalog) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36),
          child: Text(
            'No catalogue sections configured yet. Add your first section above.',
            style: TextStyle(color: context.textMuted),
          ),
        ),
      );
    }

    final int totalSections = _catalogSections.length;
    final int artistCount = _catalogSections.where((CatalogSection s) => s.sourceType == 'artist').length;
    final int playlistCount = _catalogSections.where((CatalogSection s) => s.sourceType == 'playlist').length;
    final int mixCount = _catalogSections.where((CatalogSection s) => s.sourceType == 'mix' || s.sourceType == 'jiosaavn_mix').length;
    final int albumCount = _catalogSections.where((CatalogSection s) => s.sourceType == 'album').length;
    final int liveActiveCount = _catalogSections.where((CatalogSection s) => s.isEnabled && !s.isMock && s.providerStatus != 'stale').length;
    final int mockCount = _catalogSections.where((CatalogSection s) => s.isMock).length;
    final int disabledCount = _catalogSections.where((CatalogSection s) => !s.isEnabled).length;
    final int bannerCount = _catalogSections.where((CatalogSection s) => s.isBanner).length;

    // Filter by search query & status filter
    final String query = _catalogSearchController.text.trim().toLowerCase();
    final List<CatalogSection> filteredSections = _catalogSections.where((CatalogSection s) {
      if (query.isNotEmpty) {
        final bool matchesTitle = s.displayTitle.toLowerCase().contains(query);
        final bool matchesUrl = s.sourceUrl.toLowerCase().contains(query);
        final bool matchesGroup = s.displayGroup.toLowerCase().contains(query);
        final bool matchesKey = s.key.toLowerCase().contains(query);
        final bool matchesId = s.sourceId.toLowerCase().contains(query);
        if (!matchesTitle && !matchesUrl && !matchesGroup && !matchesKey && !matchesId) {
          return false;
        }
      }
      switch (_catalogStatusFilter) {
        case 'live':
          return s.isEnabled && !s.isMock && s.providerStatus != 'stale';
        case 'mock':
          return s.isMock;
        case 'disabled':
          return !s.isEnabled;
        case 'banners':
          return s.isBanner;
        case 'mixes':
          return s.sourceType == 'mix' || s.sourceType == 'jiosaavn_mix';
        case 'all':
        default:
          return true;
      }
    }).toList();

    // Distinct display groups — order matches Home (min position in group)
    final Set<String> groupKeys = <String>{};
    for (final CatalogSection s in filteredSections) {
      groupKeys.add(s.displayGroup.isNotEmpty ? s.displayGroup : 'other');
    }
    int minGroupPos(String g) {
      int min = 1 << 30;
      for (final CatalogSection s in filteredSections) {
        final String key =
            s.displayGroup.isNotEmpty ? s.displayGroup : 'other';
        if (key == g && s.position < min) min = s.position;
      }
      return min;
    }
    final List<String> sortedGroups = groupKeys.toList()
      ..sort((String a, String b) => minGroupPos(a).compareTo(minGroupPos(b)));

    String formatGroupTitle(String g) {
      switch (g.toLowerCase()) {
        case 'featured_artists':
        case 'artists':
          return 'Featured Artists';
        case 'top_charts':
          return 'Top Charts';
        case 'featured_albums':
        case 'albums':
          return 'Featured Albums';
        case 'personalized_mixes':
        case 'mixes':
          return 'Personalized Mixes';
        case 'trending_now':
          return 'Trending Now';
        case 'festival_specials':
          return 'Festival Specials';
        case 'hero_banners':
          return 'Hero Banners';
        default:
          return g.split('_').map((String word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '').join(' ');
      }
    }

    IconData getGroupIcon(String g) {
      switch (g.toLowerCase()) {
        case 'featured_artists':
        case 'artists':
          return Icons.mic_external_on_rounded;
        case 'top_charts':
          return Icons.leaderboard_rounded;
        case 'featured_albums':
        case 'albums':
          return Icons.album_rounded;
        case 'personalized_mixes':
        case 'mixes':
          return Icons.auto_awesome_rounded;
        case 'trending_now':
          return Icons.local_fire_department_rounded;
        case 'festival_specials':
          return Icons.celebration_rounded;
        case 'hero_banners':
          return Icons.view_carousel_rounded;
        default:
          return Icons.category_rounded;
      }
    }

    final List<String> activeFilterGroups = _catalogGroupFilter == 'all'
        ? sortedGroups
        : <String>[_catalogGroupFilter];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Metric Counters Row
        LayoutBuilder(
          builder: (BuildContext ctx, BoxConstraints constraints) {
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _buildCatalogMetricChip(
                  icon: Icons.layers_rounded,
                  label: 'Total Sections',
                  value: '$totalSections',
                  color: AppColors.primary,
                  isDark: isDark,
                ),
                _buildCatalogMetricChip(
                  icon: Icons.check_circle_rounded,
                  label: 'Live Verified',
                  value: '$liveActiveCount / $totalSections',
                  color: AppColors.success,
                  isDark: isDark,
                ),
                _buildCatalogMetricChip(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Mixes & Daily',
                  value: '$mixCount',
                  color: AppColors.electricViolet,
                  isDark: isDark,
                ),
                _buildCatalogMetricChip(
                  icon: Icons.queue_music_rounded,
                  label: 'Playlists',
                  value: '$playlistCount',
                  color: Colors.tealAccent,
                  isDark: isDark,
                ),
                _buildCatalogMetricChip(
                  icon: Icons.album_rounded,
                  label: 'Albums',
                  value: '$albumCount',
                  color: Colors.amberAccent,
                  isDark: isDark,
                ),
                _buildCatalogMetricChip(
                  icon: Icons.mic_rounded,
                  label: 'Artists',
                  value: '$artistCount',
                  color: AppColors.secondary,
                  isDark: isDark,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),

        // Search Bar for Sections
        TextField(
          controller: _catalogSearchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search configured sections by title, group, URL, or ID...',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: _catalogSearchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _catalogSearchController.clear();
                      setState(() {});
                    },
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: isDark ? AppColors.surfaceContainerHigh : AppColors.lightInputBackground,
          ),
        ),
        const SizedBox(height: 12),

        // Status Control Chips (All, Live, Mixes, Mock, Disabled Drafts, Banners)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              ChoiceChip(
                selected: _catalogStatusFilter == 'all',
                label: Text('All (${_catalogSections.length})'),
                onSelected: (bool selected) {
                  if (selected) setState(() => _catalogStatusFilter = 'all');
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                selected: _catalogStatusFilter == 'live',
                avatar: const Icon(Icons.verified_rounded, size: 16, color: AppColors.success),
                label: Text('Live Verified ($liveActiveCount)'),
                onSelected: (bool selected) {
                  if (selected) setState(() => _catalogStatusFilter = 'live');
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                selected: _catalogStatusFilter == 'mixes',
                avatar: const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.electricViolet),
                label: Text('Mixes & Daily ($mixCount)'),
                onSelected: (bool selected) {
                  if (selected) setState(() => _catalogStatusFilter = 'mixes');
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                selected: _catalogStatusFilter == 'mock',
                avatar: const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.secondary),
                label: Text('Mock Data ($mockCount)'),
                onSelected: (bool selected) {
                  if (selected) setState(() => _catalogStatusFilter = 'mock');
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                selected: _catalogStatusFilter == 'disabled',
                avatar: const Icon(Icons.pause_circle_outline_rounded, size: 16),
                label: Text('Disabled Drafts ($disabledCount)'),
                onSelected: (bool selected) {
                  if (selected) setState(() => _catalogStatusFilter = 'disabled');
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                selected: _catalogStatusFilter == 'banners',
                avatar: const Icon(Icons.view_carousel_rounded, size: 16),
                label: Text('Banners ($bannerCount)'),
                onSelected: (bool selected) {
                  if (selected) setState(() => _catalogStatusFilter = 'banners');
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Section / Group Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              ChoiceChip(
                selected: _catalogGroupFilter == 'all',
                label: Text('All Groups (${filteredSections.length})'),
                onSelected: (bool selected) {
                  if (selected) setState(() => _catalogGroupFilter = 'all');
                },
              ),
              const SizedBox(width: 8),
              for (final String group in sortedGroups) ...<Widget>[
                Builder(
                  builder: (BuildContext context) {
                    final int count = filteredSections
                        .where((CatalogSection s) => (s.displayGroup.isNotEmpty ? s.displayGroup : 'other') == group)
                        .length;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: _catalogGroupFilter == group,
                        avatar: Icon(getGroupIcon(group), size: 16),
                        label: Text('${formatGroupTitle(group)} ($count)'),
                        onSelected: (bool selected) {
                          if (selected) setState(() => _catalogGroupFilter = group);
                        },
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),

        if (filteredSections.isEmpty && !_isLoadingCatalog)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Column(
                children: <Widget>[
                  const Icon(Icons.search_off_rounded, size: 40, color: AppColors.secondary),
                  const SizedBox(height: 8),
                  Text(
                    'No sections match the current search or status filter.',
                    style: TextStyle(color: context.textMuted),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.clear_all_rounded, size: 16),
                    label: const Text('Reset Filters'),
                    onPressed: () {
                      _catalogSearchController.clear();
                      setState(() {
                        _catalogStatusFilter = 'all';
                        _catalogGroupFilter = 'all';
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

        // Render each Group neatly
        for (final String group in activeFilterGroups) ...<Widget>[
          Builder(
            builder: (BuildContext context) {
              final List<CatalogSection> groupSections = filteredSections
                  .where((CatalogSection s) => (s.displayGroup.isNotEmpty ? s.displayGroup : 'other') == group)
                  .toList();
              if (groupSections.isEmpty) return const SizedBox.shrink();

              final String groupTitle = formatGroupTitle(group);
              final IconData groupIcon = getGroupIcon(group);

              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isDark
                      ? AppColors.surfaceContainerLowest.withValues(alpha: 0.5)
                      : AppColors.lightElevatedSurface.withValues(alpha: 0.7),
                  border: Border.all(
                    color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
                  ),
                ),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Group Header Bar
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(groupIcon, size: 20, color: isDark ? AppColors.secondary : AppColors.lightSecondaryAccent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                groupTitle,
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: context.textPrimary,
                                ),
                              ),
                              Text(
                                'Frontend Group: "$group" • ${groupSections.length} ${groupSections.length == 1 ? "item" : "items"}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: context.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Builder(
                          builder: (BuildContext ctx) {
                            final int groupOrderIndex =
                                activeFilterGroups.indexOf(group);
                            final bool canGroupUp = groupOrderIndex > 0;
                            final bool canGroupDown =
                                groupOrderIndex >= 0 &&
                                groupOrderIndex <
                                    activeFilterGroups.length - 1;
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                IconButton(
                                  tooltip: 'Move group up (Home order)',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: canGroupUp
                                      ? () => _moveCatalogGroup(
                                          activeFilterGroups,
                                          groupOrderIndex,
                                          groupOrderIndex - 1,
                                        )
                                      : null,
                                  icon: Icon(
                                    Icons.keyboard_arrow_up_rounded,
                                    color: canGroupUp
                                        ? context.textPrimary
                                        : context.textMuted
                                            .withValues(alpha: 0.3),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Move group down (Home order)',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: canGroupDown
                                      ? () => _moveCatalogGroup(
                                          activeFilterGroups,
                                          groupOrderIndex,
                                          groupOrderIndex + 1,
                                        )
                                      : null,
                                  icon: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: canGroupDown
                                        ? context.textPrimary
                                        : context.textMuted
                                            .withValues(alpha: 0.3),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.surfaceContainerHigh
                                        : AppColors.lightSurface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark
                                          ? AppColors.borderSubtle
                                          : AppColors.lightBorder,
                                    ),
                                  ),
                                  child: Text(
                                    '${groupSections.length} items',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    // Items in this group — numbers are 1..N within the section/group
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: groupSections.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (BuildContext ctx, int index) {
                        final CatalogSection sec = groupSections[index];
                        return _buildCatalogSectionCard(
                          ctx,
                          sec,
                          displayNumber: index + 1,
                          canMoveUp: index > 0,
                          canMoveDown: index < groupSections.length - 1,
                          onMoveUp: () => _moveCatalogSectionInGroup(
                            groupSections,
                            index,
                            index - 1,
                          ),
                          onMoveDown: () => _moveCatalogSectionInGroup(
                            groupSections,
                            index,
                            index + 1,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildCatalogMetricChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceContainerHigh : AppColors.lightElevatedSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.outline,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB: ADVERTISEMENTS & ANNOUNCEMENTS
  // ==========================================

  Widget _buildAdsTab(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? <Color>[
                      const Color(0xFF2A2010),
                      const Color(0xFF14121A),
                    ]
                  : <Color>[
                      const Color(0xFFFFF7ED),
                      const Color(0xFFFBF8F5),
                    ],
            ),
            border: Border.all(
              color: Colors.amber.withValues(alpha: isDark ? 0.35 : 0.4),
              width: 1.2,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.campaign_rounded,
                  color: Colors.amber,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'In-App Ads & Announcements',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Popup or inline placements (home / library / playlist). Inactive ads hide with no empty gap.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white70 : Colors.black54,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _showAdEditorDialog(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Create Ad'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: _adPlacementFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Placement',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: <DropdownMenuItem<String>>[
                  const DropdownMenuItem(value: 'all', child: Text('All placements')),
                  ...Advertisement.placementOptions.map(
                    (Map<String, String> o) => DropdownMenuItem<String>(
                      value: o['value'],
                      child: Text(o['label'] ?? o['value'] ?? '', overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (String? v) =>
                    setState(() => _adPlacementFilter = v ?? 'all'),
              ),
            ),
            SizedBox(
              width: 140,
              child: DropdownButtonFormField<String>(
                initialValue: _adStatusFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                ],
                onChanged: (String? v) =>
                    setState(() => _adStatusFilter = v ?? 'all'),
              ),
            ),
            SizedBox(
              width: 140,
              child: DropdownButtonFormField<String>(
                initialValue: _adSort,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Sort',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'newest', child: Text('Newest')),
                  DropdownMenuItem(value: 'title', child: Text('Title A–Z')),
                ],
                onChanged: (String? v) => setState(() => _adSort = v ?? 'newest'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Builder(
          builder: (BuildContext ctx) {
            List<Advertisement> filtered = _ads.where((Advertisement ad) {
              if (_adPlacementFilter != 'all' && ad.placement != _adPlacementFilter) {
                return false;
              }
              if (_adStatusFilter == 'active' && !ad.isActive) return false;
              if (_adStatusFilter == 'inactive' && ad.isActive) return false;
              return true;
            }).toList();
            filtered.sort((Advertisement a, Advertisement b) {
              if (_adSort == 'title') {
                return a.title.toLowerCase().compareTo(b.title.toLowerCase());
              }
              final DateTime da = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final DateTime db = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              return db.compareTo(da);
            });

            if (_isLoadingAds) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (_ads.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.campaign_outlined,
                        size: 56,
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No Ads Configured Yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Create your first announcement or promo banner using the button above.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (filtered.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No ads match this filter.',
                    style: TextStyle(color: context.textMuted)),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (BuildContext c, int index) {
                return _buildAdItemCard(context, filtered[index]);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildAdItemCard(BuildContext context, Advertisement ad) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    String closeBadgeText;
    switch (ad.closeButtonType) {
      case 'text_and_cross':
        closeBadgeText = 'Close: "Close ✕" Button';
        break;
      case 'text_only':
        closeBadgeText = 'Close: "Skip" Text Only';
        break;
      case 'icon':
      default:
        closeBadgeText = 'Close: ✕ Icon Only';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceContainerLow : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ad.isActive
              ? Colors.amber.withValues(alpha: isDark ? 0.35 : 0.5)
              : (isDark ? AppColors.borderSubtle : AppColors.lightBorder),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ad.isActive
                      ? Colors.green.withValues(alpha: 0.18)
                      : Colors.grey.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: ad.isActive ? Colors.green : Colors.grey,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      ad.isActive ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
                      size: 13,
                      color: ad.isActive ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      ad.isActive ? 'ACTIVE & LIVE' : 'INACTIVE',
                      style: TextStyle(
                        color: ad.isActive ? Colors.green : Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.4), width: 0.8),
                  ),
                  child: Text(
                    closeBadgeText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    ad.placement.replaceAll('_', ' '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.purpleAccent,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: ad.isActive,
                  activeTrackColor: Colors.amber,
                  onChanged: (bool val) async {
                    await SupabaseService().toggleAdvertisementActive(ad.id, val);
                    _loadAds();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (ad.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _buildAdImageWidget(
                    ad.imageUrl,
                    width: 90,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                ),
              if (ad.imageUrl.isNotEmpty) const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      ad.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (ad.subtitle != null && ad.subtitle!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        ad.subtitle!,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (ad.targetUrl != null && ad.targetUrl!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Row(
                        children: <Widget>[
                          const Icon(Icons.link_rounded, size: 14, color: Colors.blueAccent),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              ad.targetUrl!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.blueAccent,
                                decoration: TextDecoration.underline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () => AdPopupDialog.preview(context, ad),
                icon: const Icon(Icons.visibility_rounded, size: 16),
                label: const Text('Live Preview'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _showAdEditorDialog(context, ad: ad),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Edit'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _confirmDeleteAd(context, ad),
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                tooltip: 'Delete Ad',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdImageWidget(
    String url, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) {
    if (url.startsWith('data:image')) {
      try {
        final int commaIdx = url.indexOf(',');
        if (commaIdx != -1) {
          final Uint8List bytes = base64Decode(url.substring(commaIdx + 1));
          return Image.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
          );
        }
      } catch (_) {}
    }
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => Container(
        width: width,
        height: height,
        color: Colors.grey.withValues(alpha: 0.2),
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported_rounded, size: 24),
      ),
    );
  }

  Future<void> _showAdEditorDialog(BuildContext context, {Advertisement? ad}) async {
    final bool isEditing = ad != null;
    final TextEditingController titleCtrl =
        TextEditingController(text: ad?.title ?? '');
    final TextEditingController subtitleCtrl =
        TextEditingController(text: ad?.subtitle ?? '');
    final TextEditingController imageCtrl =
        TextEditingController(text: ad?.imageUrl ?? '');
    final TextEditingController targetCtrl =
        TextEditingController(text: ad?.targetUrl ?? '');

    String closeButtonType = ad?.closeButtonType ?? 'icon';
    String placement = ad?.placement ?? Advertisement.placementPopup;
    bool isActive = ad?.isActive ?? true;
    bool isUploadingPoster = false;
    bool showManualUrlInput = false;

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setDialogState) {
            final bool isDark = Theme.of(dialogContext).brightness == Brightness.dark;

            Future<void> pickAndUploadPoster() async {
              try {
                final ImagePicker picker = ImagePicker();
                final XFile? file = await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 1920,
                  imageQuality: 92,
                );
                if (file != null) {
                  setDialogState(() => isUploadingPoster = true);
                  final Uint8List bytes = await file.readAsBytes();
                  final String? uploadedUrl = await SupabaseService().uploadAdBanner(
                    bytes: bytes,
                    fileName: file.name,
                  );
                  if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
                    imageCtrl.text = uploadedUrl;
                  }
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Failed to upload image: $e')),
                  );
                }
              } finally {
                setDialogState(() => isUploadingPoster = false);
              }
            }

            final bool hasPoster = imageCtrl.text.trim().isNotEmpty;

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: <Widget>[
                  Icon(
                    isEditing ? Icons.edit_rounded : Icons.campaign_rounded,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEditing ? 'Edit Advertisement' : 'Create In-App Ad',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // DIRECT POSTER UPLOAD SECTION (Primary)
                      const Text(
                        'Ad Poster Image *',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (hasPoster)
                        Stack(
                          children: <Widget>[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                constraints: const BoxConstraints(maxHeight: 240),
                                width: double.infinity,
                                color: Colors.black26,
                                alignment: Alignment.center,
                                child: _buildAdImageWidget(
                                  imageCtrl.text.trim(),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  FilledButton.tonalIcon(
                                    onPressed: isUploadingPoster ? null : pickAndUploadPoster,
                                    icon: const Icon(Icons.photo_library_rounded, size: 16),
                                    label: const Text('Change', style: TextStyle(fontSize: 12)),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.black.withValues(alpha: 0.75),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton.filled(
                                    onPressed: () => setDialogState(() => imageCtrl.clear()),
                                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                    tooltip: 'Remove Poster',
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.redAccent.withValues(alpha: 0.85),
                                      foregroundColor: Colors.white,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      else
                        InkWell(
                          onTap: isUploadingPoster ? null : pickAndUploadPoster,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF262638) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.6),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                if (isUploadingPoster) ...<Widget>[
                                  const SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: CircularProgressIndicator(strokeWidth: 3, color: Colors.amber),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Uploading poster...',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                ] else ...<Widget>[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.cloud_upload_rounded,
                                      color: Colors.amber,
                                      size: 36,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Upload Poster Image',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap to select poster from gallery or device files',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white70 : Colors.black54,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 6),
                      // URL option fallback toggle
                      InkWell(
                        onTap: () => setDialogState(() => showManualUrlInput = !showManualUrlInput),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                showManualUrlInput ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
                                size: 18,
                                color: Colors.amber,
                              ),
                              Text(
                                showManualUrlInput ? 'Hide Image URL input' : 'Or enter Image URL manually',
                                style: const TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (showManualUrlInput) ...<Widget>[
                        const SizedBox(height: 6),
                        TextField(
                          controller: imageCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Direct Image URL',
                            hintText: 'https://... or data:image/...',
                            prefixIcon: Icon(Icons.link_rounded),
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ],

                      const SizedBox(height: 14),
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Title / Reference (Optional)',
                          hintText: 'e.g. Festival Special / New Track Promo',
                          prefixIcon: Icon(Icons.title_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: targetCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Redirect URL on Tap (Optional)',
                          hintText: 'https://kalpkrut.com or promotional link',
                          prefixIcon: Icon(Icons.open_in_new_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Close Button Display Option (Admin Controlled):',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: closeButtonType,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.close_fullscreen_rounded),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem<String>(
                            value: 'icon',
                            child: Text('✕ Circular Cross Icon Only'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'text_and_cross',
                            child: Text('Close ✕ (Text with Cross Icon)'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'text_only',
                            child: Text('Skip / Close (Text Only Button)'),
                          ),
                        ],
                        onChanged: (String? val) {
                          if (val != null) {
                            setDialogState(() => closeButtonType = val);
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: placement,
                        decoration: const InputDecoration(
                          labelText: 'Placement (where it appears)',
                          border: OutlineInputBorder(),
                        ),
                        items: Advertisement.placementOptions
                            .map(
                              (Map<String, String> o) => DropdownMenuItem<String>(
                                value: o['value'],
                                child: Text(
                                  o['label'] ?? o['value']!,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (String? val) {
                          if (val != null) {
                            setDialogState(() => placement = val);
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active / Published Live', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(
                          placement == Advertisement.placementPopup
                              ? 'Popup on app open'
                              : 'Inline card — auto-hides when off (no layout gap)',
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: isActive,
                        activeTrackColor: Colors.amber,
                        onChanged: (bool val) => setDialogState(() => isActive = val),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final String image = imageCtrl.text.trim();
                    if (image.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please upload a poster image')),
                      );
                      return;
                    }

                    final String enteredTitle = titleCtrl.text.trim();
                    final String title = enteredTitle.isNotEmpty ? enteredTitle : 'Advertisement';

                    final Advertisement toSave = Advertisement(
                      id: ad?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                      title: title,
                      subtitle: subtitleCtrl.text.trim().isNotEmpty ? subtitleCtrl.text.trim() : null,
                      imageUrl: image,
                      targetUrl: targetCtrl.text.trim().isNotEmpty ? targetCtrl.text.trim() : null,
                      closeButtonType: closeButtonType,
                      isActive: isActive,
                      placement: placement,
                      createdAt: ad?.createdAt ?? DateTime.now(),
                    );

                    await SupabaseService().saveAdvertisement(toSave);
                    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                    _loadAds();
                  },
                  style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade700, foregroundColor: Colors.black),
                  child: Text(isEditing ? 'Save Changes' : 'Publish Ad'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteAd(BuildContext context, Advertisement ad) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete Advertisement?'),
        content: Text('Are you sure you want to permanently delete "${ad.title}"?'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SupabaseService().deleteAdvertisement(ad.id);
      _loadAds();
    }
  }

  // ==========================================
  // TAB 1: OVERVIEW & REAL DATABASE METRICS
  // ==========================================


  Widget _buildModernAdminSidebar(BuildContext context, bool isDark) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceContainerLowest : AppColors.lightElevatedSurface,
        border: Border(
          right: BorderSide(
            color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: <Widget>[
          // Brand Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Row(
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'Kalpkrut Beats',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Row(
                        children: <Widget>[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Console v1.0.12',
                            style: TextStyle(fontSize: 10, color: Colors.white60, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
          ),

          // Scrollable Sidebar — only real tabs (matches TabController length)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              children: <Widget>[
                _buildSidebarSectionLabel('ANALYTICS & CORE'),
                _buildSidebarItem(
                  0,
                  'Overview',
                  Icons.dashboard_rounded,
                  isDark,
                ),

                const SizedBox(height: 12),
                _buildSidebarSectionLabel('CONTENT & STREAMING'),
                _buildSidebarItem(
                  1,
                  'Catalogue',
                  Icons.queue_music_rounded,
                  isDark,
                  badgeText: '${_metrics['catalog_sections_count'] ?? _catalogSections.length}',
                ),
                _buildSidebarItem(
                  2,
                  'Live Radio',
                  Icons.radio_rounded,
                  isDark,
                  badgeText: _adminRadioStations.isEmpty
                      ? null
                      : '${_adminRadioStations.length}',
                ),
                _buildSidebarItem(
                  3,
                  'Library Categories',
                  Icons.category_rounded,
                  isDark,
                  badgeText: _adminLibraryCats.isEmpty
                      ? null
                      : '${_adminLibraryCats.length}',
                ),

                const SizedBox(height: 12),
                _buildSidebarSectionLabel('GROWTH & ADS'),
                _buildSidebarItem(
                  4,
                  'Advertisements',
                  Icons.campaign_rounded,
                  isDark,
                  badgeText: '${_metrics['ads_count'] ?? ''}'.isEmpty ||
                          '${_metrics['ads_count']}' == '0'
                      ? null
                      : '${_metrics['ads_count']}',
                ),
                _buildSidebarItem(
                  5,
                  'Push Notify',
                  Icons.notifications_active_rounded,
                  isDark,
                ),

                const SizedBox(height: 12),
                _buildSidebarSectionLabel('MANAGEMENT'),
                _buildSidebarItem(
                  6,
                  'Users',
                  Icons.people_alt_rounded,
                  isDark,
                  badgeText: '${_metrics['users_count'] ?? ''}'.isEmpty ||
                          '${_metrics['users_count']}' == '0'
                      ? null
                      : '${_metrics['users_count']}',
                ),
                _buildSidebarItem(
                  7,
                  'Reports',
                  Icons.report_problem_rounded,
                  isDark,
                  badgeText: '${_metrics['reports_count'] ?? ''}'.isEmpty ||
                          '${_metrics['reports_count']}' == '0'
                      ? null
                      : '${_metrics['reports_count']}',
                ),

                const SizedBox(height: 12),
                _buildSidebarSectionLabel('SYSTEM'),
                _buildSidebarItem(
                  8,
                  'Audio Providers',
                  Icons.hub_rounded,
                  isDark,
                ),
                _buildSidebarItem(
                  9,
                  'Settings',
                  Icons.tune_rounded,
                  isDark,
                ),
              ],
            ),
          ),

          // Admin Footer Card
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceContainerLowest : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
              ),
            ),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 15,
                  backgroundColor: AppColors.secondary.withValues(alpha: 0.2),
                  child: const Icon(Icons.shield_rounded, size: 15, color: AppColors.secondary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text(
                        'Admin Session',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Super Administrator',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, size: 17),
                  tooltip: 'Exit Console',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: context.textSecondary.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildSidebarItem(
    int index,
    String title,
    IconData icon,
    bool isDark, {
    String? badgeText,
  }) {
    final bool isSelected = _selectedTab == index;
    final Color activeColor = isDark ? AppColors.secondary : AppColors.lightSecondaryAccent;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: () {
          setState(() => _selectedTab = index);
          _tabController.animateTo(index);
          _onTabSelected(index);
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: isDark ? 0.16 : 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: activeColor.withValues(alpha: 0.35), width: 1)
                : null,
          ),
          child: Row(
            children: <Widget>[
              Icon(
                icon,
                size: 17,
                color: isSelected
                    ? activeColor
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? Colors.white : context.textPrimary)
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.error,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final bool isDark = context.isDarkMode;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceContainerLowest : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context) {
    final bool isDark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Dashboard Overview',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Real-time operations, database telemetry & streaming command center.',
                    style: TextStyle(fontSize: 13, color: context.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 22),
              tooltip: 'Refresh Metrics',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onPressed: _loadPlatformMetrics,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isLoadingCatalog
                ? null
                : () async {
                    await _loadCatalogSections();
                    await _refreshAllCatalogSections();
                    await _loadPlatformMetrics();
                  },
            icon: _isLoadingCatalog
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync_rounded),
            label: Text(
              _isLoadingCatalog
                  ? 'Refreshing all catalogues…'
                  : 'Refresh All Catalogues',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppColors.electricViolet,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Quick actions — only real admin tabs with live counts
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _buildOverviewQuickAction(
              context,
              icon: Icons.queue_music_rounded,
              label:
                  'Catalogue (${_metrics['catalog_sections_count'] ?? _catalogSections.length})',
              color: isDark ? AppColors.secondary : AppColors.lightSecondaryAccent,
              onTap: () => _goToTab(1),
            ),
            _buildOverviewQuickAction(
              context,
              icon: Icons.radio_rounded,
              label:
                  'Live Radio (${_adminRadioStations.isNotEmpty ? _adminRadioStations.length : RadioStation.stations.length})',
              color: AppColors.success,
              onTap: () => _goToTab(2),
            ),
            _buildOverviewQuickAction(
              context,
              icon: Icons.category_rounded,
              label:
                  'Library (${_adminLibraryCats.isNotEmpty ? _adminLibraryCats.length : (_metrics['groups_count'] ?? 0)})',
              color: Colors.teal,
              onTap: () => _goToTab(3),
            ),
            _buildOverviewQuickAction(
              context,
              icon: Icons.campaign_rounded,
              label: 'Ads (${_metrics['ads_count'] ?? 0})',
              color: Colors.amber,
              onTap: () => _goToTab(4),
            ),
            _buildOverviewQuickAction(
              context,
              icon: Icons.notifications_active_rounded,
              label: 'Push Notify',
              color: isDark ? AppColors.primaryLight : AppColors.lightPrimaryAccent,
              onTap: () => _goToTab(5),
            ),
            _buildOverviewQuickAction(
              context,
              icon: Icons.people_alt_rounded,
              label: 'Users (${_metrics['users_count'] ?? 0})',
              color: Colors.indigo,
              onTap: () => _goToTab(6),
            ),
            _buildOverviewQuickAction(
              context,
              icon: Icons.report_problem_rounded,
              label: 'Reports (${_metrics['reports_count'] ?? 0})',
              color: Colors.deepOrange,
              onTap: () => _goToTab(7),
            ),
            _buildOverviewQuickAction(
              context,
              icon: Icons.hub_rounded,
              label: 'Providers',
              color: Colors.blueGrey,
              onTap: () => _goToTab(8),
            ),
            _buildOverviewQuickAction(
              context,
              icon: Icons.tune_rounded,
              label: 'Settings',
              color: Colors.grey,
              onTap: () => _goToTab(9),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_isLoadingMetrics)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...<Widget>[
          // System Health Header Card
          EchoGlassCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 16,
            backgroundColor: isDark ? null : AppColors.lightSurface,
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success.withValues(alpha: 0.15),
                  ),
                  child: const Icon(Icons.dns_rounded, color: AppColors.success, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text.rich(
                        TextSpan(
                          children: <InlineSpan>[
                            TextSpan(
                              text: 'Supabase: ',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: context.textPrimary,
                              ),
                            ),
                            TextSpan(
                              text: _metrics['database_status'] ?? 'Online',
                              style: const TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Last Sync: ${_metrics['last_sync'] != null ? DateTime.tryParse(_metrics['last_sync'])?.toLocal().toString().split('.').first : "Just now"}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: context.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Real Metric Grid (tap opens the related section — no duplicate chip map)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _buildMetricCard(
                context,
                title: 'Total Users',
                value: _metrics['users_count'] ?? '0',
                icon: Icons.people_outline_rounded,
                color: isDark ? AppColors.secondary : AppColors.lightSecondaryAccent,
                onTap: () => _goToTab(6),
              ),
              _buildMetricCard(
                context,
                title: 'Catalogue Sections',
                value: _metrics['catalog_sections_count'] ?? '0',
                icon: Icons.queue_music_rounded,
                color: isDark ? AppColors.primaryLight : AppColors.lightPrimaryAccent,
                onTap: () => _goToTab(1),
              ),
              _buildMetricCard(
                context,
                title: 'Album Shelves',
                value: _metrics['albums_count'] ??
                    '${_catalogSections.where((CatalogSection s) => s.sourceType == 'album').length}',
                icon: Icons.album_rounded,
                color: isDark ? AppColors.tertiaryLight : AppColors.lightTertiaryAccent,
                onTap: () => _goToTab(1),
              ),
              _buildMetricCard(
                context,
                title: 'Artist Shelves',
                value: _metrics['artists_count'] ??
                    '${_catalogSections.where((CatalogSection s) => s.sourceType == 'artist').length}',
                icon: Icons.mic_external_on_rounded,
                color: isDark ? AppColors.tertiaryLight : AppColors.lightTertiaryAccent,
                onTap: () => _goToTab(1),
              ),
              _buildMetricCard(
                context,
                title: 'Playlist Shelves',
                value: _metrics['playlists_count'] ??
                    '${_catalogSections.where((CatalogSection s) => s.sourceType == 'playlist').length}',
                icon: Icons.library_music_rounded,
                color: Colors.amber,
                onTap: () => _goToTab(1),
              ),
              _buildMetricCard(
                context,
                title: 'Mix Shelves',
                value: _metrics['mixes_count'] ??
                    '${_catalogSections.where((CatalogSection s) => s.sourceType == 'mix' || s.sourceType == 'jiosaavn_mix').length}',
                icon: Icons.auto_awesome_rounded,
                color: AppColors.electricViolet,
                onTap: () => _goToTab(1),
              ),
              _buildMetricCard(
                context,
                title: 'Home Groups',
                value: _metrics['groups_count'] ??
                    '${_catalogSections.map((CatalogSection s) => s.displayGroup).where((String g) => g.isNotEmpty).toSet().length}',
                icon: Icons.view_agenda_rounded,
                color: Colors.cyan,
                onTap: () => _goToTab(1),
              ),
              _buildMetricCard(
                context,
                title: 'Active Ads',
                value: _metrics['ads_count'] ?? '0',
                icon: Icons.campaign_rounded,
                color: AppColors.secondary,
                onTap: () => _goToTab(4),
              ),
              _buildMetricCard(
                context,
                title: 'Radio Stations',
                value:
                    '${_adminRadioStations.isNotEmpty ? _adminRadioStations.length : RadioStation.stations.length}',
                icon: Icons.radio_rounded,
                color: AppColors.success,
                onTap: () => _goToTab(2),
              ),
              _buildMetricCard(
                context,
                title: 'Favorites',
                value: _metrics['favorites_count'] ?? '0',
                icon: Icons.favorite_border_rounded,
                color: AppColors.tertiary,
                onTap: () => _goToTab(6),
              ),
              _buildMetricCard(
                context,
                title: 'Play Events',
                value: _metrics['recently_played_count'] ?? '0',
                icon: Icons.play_arrow_rounded,
                color: AppColors.success,
              ),
              _buildMetricCard(
                context,
                title: 'Reports',
                value: _metrics['reports_count'] ?? '0',
                icon: Icons.flag_outlined,
                color: AppColors.error,
                onTap: () => _goToTab(7),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    final bool isDark = context.isDarkMode;
    final double screenW = MediaQuery.of(context).size.width;
    final bool wide = screenW >= 900;
    // Desktop: 3–4 cards per row filling the content pane; phone: 2-up.
    final double cardWidth = wide
        ? ((screenW - 220) / 3).clamp(200.0, 320.0)
        : ((screenW - 48) / 2).clamp(150.0, 240.0);

    return SizedBox(
      width: cardWidth,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: EchoGlassCard(
          padding: const EdgeInsets.all(18),
          borderRadius: 16,
          backgroundColor: isDark ? null : AppColors.lightSurface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.textSecondary,
                      ),
                    ),
                  ),
                  Icon(icon, color: color, size: 22),
                ],
              ),
              const SizedBox(height: 14),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: wide ? 26 : 22,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: USER MANAGEMENT
  // ==========================================

  Widget _buildUsersTab(BuildContext context) {
    final bool isDark = context.isDarkMode;

    final List<Map<String, dynamic>> filteredUsers = _users.where((Map<String, dynamic> u) {
      if (_userRoleFilter != 'all' && '${u['role'] ?? 'user'}' != _userRoleFilter) {
        return false;
      }
      if (_userSearchQuery.isEmpty) return true;
      final String name = (u['display_name'] ?? '').toString().toLowerCase();
      final String email = (u['email'] ?? '').toString().toLowerCase();
      final String query = _userSearchQuery.toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList()
      ..sort((Map<String, dynamic> a, Map<String, dynamic> b) {
        if (_userSort == 'name') {
          final String na = (a['display_name'] ?? a['email'] ?? '').toString().toLowerCase();
          final String nb = (b['display_name'] ?? b['email'] ?? '').toString().toLowerCase();
          return na.compareTo(nb);
        }
        final DateTime da = DateTime.tryParse('${a['created_at'] ?? ''}') ?? DateTime(1970);
        final DateTime db = DateTime.tryParse('${b['created_at'] ?? ''}') ?? DateTime(1970);
        return _userSort == 'oldest' ? da.compareTo(db) : db.compareTo(da);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'User Management',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Inspect verified accounts, roles, and registration dates.',
                  style: TextStyle(fontSize: 13, color: context.textSecondary),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh Users',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onPressed: _loadUsers,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Search Field
        TextField(
          onChanged: (String v) => setState(() => _userSearchQuery = v.trim()),
          decoration: InputDecoration(
            hintText: 'Search by display name or email...',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: isDark ? AppColors.surfaceContainerLowest : AppColors.lightElevatedSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            SizedBox(
              width: 140,
              child: DropdownButtonFormField<String>(
                initialValue: _userRoleFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'all', child: Text('All roles')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'user', child: Text('User')),
                ],
                onChanged: (String? v) =>
                    setState(() => _userRoleFilter = v ?? 'all'),
              ),
            ),
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                initialValue: _userSort,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Sort',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'newest', child: Text('Newest')),
                  DropdownMenuItem(value: 'oldest', child: Text('Oldest')),
                  DropdownMenuItem(value: 'name', child: Text('Name A–Z')),
                ],
                onChanged: (String? v) => setState(() => _userSort = v ?? 'newest'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_isLoadingUsers)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (filteredUsers.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: <Widget>[
                  Icon(Icons.person_search_rounded, size: 48, color: context.textMuted),
                  const SizedBox(height: 12),
                  Text('No registered users found.', style: TextStyle(color: context.textSecondary)),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredUsers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (BuildContext ctx, int i) {
              final Map<String, dynamic> u = filteredUsers[i];
              final String name = (u['display_name'] as String?)?.trim().isNotEmpty == true
                  ? u['display_name'] as String
                  : 'Listener';
              final String email = (u['email'] as String?) ?? 'No email';
              final String role = (u['role'] as String?) ?? 'user';
              final String created = u['created_at'] != null
                  ? (DateTime.tryParse(u['created_at'].toString())?.toLocal().toString().split(' ').first ?? '')
                  : '';

              return EchoGlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                borderRadius: 14,
                backgroundColor: isDark ? null : AppColors.lightSurface,
                child: Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: role == 'admin'
                          ? (isDark ? AppColors.secondary.withValues(alpha: 0.2) : AppColors.lightSecondaryAccent.withValues(alpha: 0.15))
                          : (isDark ? AppColors.surfaceContainerHigh : AppColors.lightElevatedSurface),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: role == 'admin'
                              ? (isDark ? AppColors.secondary : AppColors.lightSecondaryAccent)
                              : context.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  name,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: role == 'admin'
                                      ? AppColors.secondary.withValues(alpha: 0.15)
                                      : Colors.grey.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  role.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: role == 'admin'
                                        ? (isDark ? AppColors.secondary : AppColors.lightSecondaryAccent)
                                        : context.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: TextStyle(fontSize: 12, color: context.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (created.isNotEmpty)
                      Text(
                        created,
                        style: TextStyle(fontSize: 11, color: context.textMuted),
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // ==========================================
  // TAB 3: PROVIDER ECOSYSTEM & LIVE TESTING
  // ==========================================

  Widget _buildProvidersTab(BuildContext context) {
    final bool isDark = context.isDarkMode;
    final SettingsStore settings = context.watch<SettingsStore>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Provider Ecosystem & Health',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Active connectors feeding legal audio into Kalpkrut Beats streaming pipelines.',
          style: TextStyle(fontSize: 13, color: context.textSecondary),
        ),
        const SizedBox(height: 16),

        // Audius Provider Card with Live Test & Toggle
        EchoGlassCard(
          padding: const EdgeInsets.all(16),
          borderRadius: 16,
          backgroundColor: isDark ? null : AppColors.lightSurface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Audius Discovery Protocol',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Official Decentralized Audio Stream Provider',
                          style: TextStyle(fontSize: 11, color: context.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: settings.audiusEnabled
                              ? AppColors.success.withValues(alpha: 0.15)
                              : Colors.grey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: settings.audiusEnabled
                                ? AppColors.success.withValues(alpha: 0.3)
                                : Colors.grey.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          settings.audiusEnabled ? 'ENABLED' : 'DISABLED',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: settings.audiusEnabled ? AppColors.success : Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch.adaptive(
                        value: settings.audiusEnabled,
                        activeTrackColor: AppColors.secondary,
                        onChanged: (bool val) => settings.setAudiusEnabled(val),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Global Artists • 320kbps MP3 • Read-Only Unauthenticated Mode Active',
                style: TextStyle(fontSize: 12, color: context.textPrimary),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isTestingAudius ? null : _testAudiusConnectivity,
                icon: _isTestingAudius
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.network_check_rounded, size: 16),
                label: const Text('Test Audius Connectivity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              if (_audiusTestResult != null) ...<Widget>[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceContainerLowest : AppColors.lightElevatedSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Text(
                    _audiusTestResult!,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Jamendo Provider Card with Live Test & Toggle
        EchoGlassCard(
          padding: const EdgeInsets.all(16),
          borderRadius: 16,
          backgroundColor: isDark ? null : AppColors.lightSurface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Jamendo Music API',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          settings.jamendoEnabled
                              ? 'Creative Commons 3.0 / Commercial Stream Provider (ACTIVE)'
                              : 'DEFAULT OFF — Excluded from user catalog, discovery feeds & search',
                          style: TextStyle(
                            fontSize: 11,
                            color: settings.jamendoEnabled ? context.textSecondary : Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: settings.jamendoEnabled
                              ? AppColors.success.withValues(alpha: 0.15)
                              : Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: settings.jamendoEnabled
                                ? AppColors.success.withValues(alpha: 0.3)
                                : Colors.amber.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          settings.jamendoEnabled ? 'ENABLED' : 'OFF (DISABLED)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: settings.jamendoEnabled ? AppColors.success : Colors.amber,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch.adaptive(
                        value: settings.jamendoEnabled,
                        activeTrackColor: AppColors.secondary,
                        onChanged: (bool val) => settings.setJamendoEnabled(val),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                settings.jamendoEnabled
                    ? '500,000+ tracks • MP3 / FLAC • Full Metadata & License Verification'
                    : 'Jamendo English catalog is excluded per final production requirements.',
                style: TextStyle(fontSize: 12, color: context.textPrimary),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isTestingJamendo ? null : _testJamendoConnectivity,
                icon: _isTestingJamendo
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.network_check_rounded, size: 16),
                label: const Text('Test Jamendo Connectivity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              if (_jamendoTestResult != null) ...<Widget>[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceContainerLowest : AppColors.lightElevatedSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Text(
                    _jamendoTestResult!,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Internet Archive Provider Card
        _buildProviderStatusCard(
          context,
          name: 'Internet Archive (Live Music)',
          type: 'Live Concerts, Public Domain & Creative Commons Streams',
          status: settings.archiveEnabled ? 'ACTIVE (ONLINE)' : 'DISABLED (OFF)',
          statusColor: settings.archiveEnabled ? AppColors.success : Colors.grey,
          stats: 'Public Audio Archive • Stream & Download Supported • Full Attribution',
          capabilities: const <String>['Live Concerts', 'Lossless/MP3', 'Open Access'],
          enabled: settings.archiveEnabled,
          onToggle: (bool v) => settings.setArchiveEnabled(v),
        ),
        const SizedBox(height: 12),

        // Local Device MediaStore
        _buildProviderStatusCard(
          context,
          name: 'Local Device MediaStore',
          type: 'On-Device Android Scoped Storage',
          status: settings.localEnabled ? 'ACTIVE (ZERO-LATENCY)' : 'DISABLED (OFF)',
          statusColor: settings.localEnabled
              ? (isDark ? AppColors.primary : AppColors.lightPrimaryAccent)
              : Colors.grey,
          stats: 'Local FLAC/MP3/AAC • No Network Required • User-Owned Audio',
          capabilities: const <String>['Offline Playback', 'Tags', 'Zero Latency'],
          enabled: settings.localEnabled,
          onToggle: (bool v) => settings.setLocalEnabled(v),
        ),
        const SizedBox(height: 12),

        // Regional Indian Catalog
        _buildProviderStatusCard(
          context,
          name: 'Regional Indian Music Catalog',
          type: 'Hindi, Marathi, Khandeshi & Indic Languages',
          status: settings.regionalEnabled ? 'ACTIVE (BETA)' : 'LICENSE PENDING',
          statusColor: settings.regionalEnabled ? AppColors.secondary : Colors.amber,
          stats: '11 Languages • Zero Scraping • Commercial Partner Agreement Architecture',
          capabilities: const <String>['Compliance Gated', 'Language Architecture', 'Clean Metadata'],
          enabled: settings.regionalEnabled,
          onToggle: (bool v) => settings.setRegionalEnabled(v),
        ),
        const SizedBox(height: 12),

        // Custom Python / Node Cloud Audio Gateway
        _buildProviderStatusCard(
          context,
          name: 'Cloud Audio Gateway (Self-Hosted Python API)',
          type: 'Cached yt-dlp Microservice (Direct Lossless Stream & Search)',
          status: settings.customApiEnabled ? 'ACTIVE (CONNECTED)' : 'DISABLED (OFF)',
          statusColor: settings.customApiEnabled ? AppColors.secondary : Colors.grey,
          stats: 'Endpoint: ${AppConfig.customApiUrl} • Dual-Tier In-Memory Cache • Lossless m4a',
          capabilities: const <String>['High Concurrency', 'Fast Search', 'Stream Cache', '4h TTL'],
          enabled: settings.customApiEnabled,
          onToggle: (bool v) => settings.setCustomApiEnabled(v),
        ),
      ],
    );
  }

  Widget _buildProviderStatusCard(
    BuildContext context, {
    required String name,
    required String type,
    required String status,
    required Color statusColor,
    required String stats,
    required List<String> capabilities,
    bool? enabled,
    ValueChanged<bool>? onToggle,
  }) {
    final bool isDark = context.isDarkMode;
    return EchoGlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      backgroundColor: isDark ? null : AppColors.lightSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(type, style: TextStyle(fontSize: 11, color: context.textSecondary)),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                    ),
                  ),
                  if (enabled != null && onToggle != null) ...<Widget>[
                    const SizedBox(width: 8),
                    Switch.adaptive(
                      value: enabled,
                      activeTrackColor: AppColors.secondary,
                      onChanged: onToggle,
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(stats, style: TextStyle(fontSize: 12, color: context.textPrimary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: capabilities
                .map((String c) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceContainerHighest : AppColors.lightElevatedSurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        c,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.secondary : AppColors.lightSecondaryAccent,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 5: REPORTS & CONTENT RESOLUTION
  // ==========================================

  Widget _buildReportsTab(BuildContext context) {
    final bool isDark = context.isDarkMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'User Reports & Moderation',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Community moderation tickets and copyright issues.',
                  style: TextStyle(fontSize: 13, color: context.textSecondary),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh Reports',
              onPressed: _loadReports,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                initialValue: _reportStatusFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                  DropdownMenuItem(value: 'dismissed', child: Text('Dismissed')),
                ],
                onChanged: (String? v) =>
                    setState(() => _reportStatusFilter = v ?? 'all'),
              ),
            ),
            SizedBox(
              width: 140,
              child: DropdownButtonFormField<String>(
                initialValue: _reportSort,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Sort',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'newest', child: Text('Newest')),
                  DropdownMenuItem(value: 'oldest', child: Text('Oldest')),
                ],
                onChanged: (String? v) =>
                    setState(() => _reportSort = v ?? 'newest'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Builder(builder: (BuildContext _) {
          List<Map<String, dynamic>> reports = _reports.where((Map<String, dynamic> r) {
            if (_reportStatusFilter == 'all') return true;
            return '${r['status'] ?? 'pending'}'.toLowerCase() == _reportStatusFilter;
          }).toList()
            ..sort((Map<String, dynamic> a, Map<String, dynamic> b) {
              final DateTime da =
                  DateTime.tryParse('${a['created_at'] ?? ''}') ?? DateTime(1970);
              final DateTime db =
                  DateTime.tryParse('${b['created_at'] ?? ''}') ?? DateTime(1970);
              return _reportSort == 'oldest' ? da.compareTo(db) : db.compareTo(da);
            });

          if (_isLoadingReports) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (_reports.isEmpty) {
            return EchoGlassCard(
              padding: const EdgeInsets.all(24),
              borderRadius: 16,
              backgroundColor: isDark ? null : AppColors.lightSurface,
              child: Center(
                child: Column(
                  children: <Widget>[
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: isDark ? AppColors.secondary : AppColors.lightSecondaryAccent,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No Pending Reports',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'All active tracks and community playlists are clean.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }
          if (reports.isEmpty) {
            return Text('No reports match this filter.',
                style: TextStyle(color: context.textMuted));
          }
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (BuildContext ctx, int i) {
              final Map<String, dynamic> r = reports[i];
              final String id = r['id']?.toString() ?? '';
              final String reason = r['reason']?.toString() ?? 'Content Report';
              final String status = r['status']?.toString() ?? 'pending';

              return EchoGlassCard(
                padding: const EdgeInsets.all(14),
                borderRadius: 14,
                backgroundColor: isDark ? null : AppColors.lightSurface,
                child: Row(
                  children: <Widget>[
                    Icon(
                      status == 'resolved' ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                      color: status == 'resolved' ? AppColors.success : Colors.amber,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(reason, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          Text('Status: ${status.toUpperCase()}', style: TextStyle(fontSize: 11, color: context.textSecondary)),
                        ],
                      ),
                    ),
                    if (status != 'resolved')
                      TextButton(
                        onPressed: () async {
                          final bool ok = await SupabaseService().updateReportStatus(id, 'resolved');
                          if (ok) _loadReports();
                        },
                        child: const Text('Resolve'),
                      ),
                  ],
                ),
              );
            },
          );
        }),
      ],
    );
  }

  // ==========================================
  // TAB 6: SETTINGS & FEATURE FLAGS
  // ==========================================

  Widget _buildSettingsTab(BuildContext context) {
    final bool isDark = context.isDarkMode;
    final MusicRepository repo = context.read<MusicRepository>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Ops Settings',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Live API endpoint and shortcuts to real catalogue tools. Fake feature flags removed.',
          style: TextStyle(fontSize: 13, color: context.textSecondary),
        ),
        const SizedBox(height: 16),
        EchoGlassCard(
          padding: const EdgeInsets.all(16),
          borderRadius: 16,
          backgroundColor: isDark ? null : AppColors.lightSurface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Music API base URL',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              SelectableText(
                AppConfig.customApiUrl,
                style: TextStyle(fontSize: 12, color: context.textSecondary),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: () => _goToTab(1),
                    icon: const Icon(Icons.queue_music_rounded, size: 16),
                    label: const Text('Open Catalogue'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await repo.getCatalogSections(forceRefresh: true);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Catalogue refresh started')),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Refresh failed: $e')),
                        );
                      }
                    },
                    icon: const Icon(Icons.cloud_sync_rounded, size: 16),
                    label: const Text('Force API refresh'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _goToTab(8),
                    icon: const Icon(Icons.hub_rounded, size: 16),
                    label: const Text('Providers'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        EchoGlassCard(
          padding: EdgeInsets.zero,
          borderRadius: 16,
          backgroundColor: isDark ? null : AppColors.lightSurface,
          child: Column(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy Policy'),
                subtitle: const Text('kalpkrutinfotech.com/privacy'),
                onTap: () {
                  launchUrl(
                    Uri.parse('https://kalpkrutinfotech.com/privacy'),
                    mode: LaunchMode.externalApplication,
                  );
                },
                trailing: const Icon(Icons.open_in_new, size: 16),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.campaign_outlined),
                title: const Text('Ads manager'),
                onTap: () => _goToTab(4),
                trailing: const Icon(Icons.chevron_right),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('Push notifications'),
                onTap: () => _goToTab(5),
                trailing: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB: RADIO STATIONS MANAGEMENT
  // ==========================================

  Future<void> _loadRadioStations() async {
    setState(() => _isLoadingRadio = true);
    try {
      final MusicRepository repo = context.read<MusicRepository>();
      final List<Map<String, dynamic>> raw = await repo.fetchRadioStations();
      if (mounted) {
        setState(() {
          _adminRadioStations = raw.map((Map<String, dynamic> m) => RadioStation.fromJson(m)).toList();
          _isLoadingRadio = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _adminRadioStations = RadioStation.stations;
          _isLoadingRadio = false;
        });
      }
    }
  }

  Future<void> _showAddEditRadioStationDialog({RadioStation? existing}) async {
    final TextEditingController nameCtrl = TextEditingController(text: existing?.name ?? '');
    final TextEditingController taglineCtrl = TextEditingController(text: existing?.tagline ?? '');
    final TextEditingController freqCtrl = TextEditingController(text: existing?.frequency ?? '102.8 FM');
    final TextEditingController stateCtrl = TextEditingController(text: existing?.state ?? 'National');
    final TextEditingController streamCtrl = TextEditingController(text: existing?.streamUrl ?? '');
    final TextEditingController artCtrl = TextEditingController(text: existing?.artworkUrl ?? '');
    final TextEditingController catCtrl = TextEditingController(text: existing?.category ?? 'AIR National');
    bool isLive = existing?.isLive ?? true;

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext dCtx, StateSetter setModalState) {
            return AlertDialog(
              title: Text(existing == null ? 'Add Radio Station' : 'Edit Radio Station'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Station Name *', hintText: 'e.g. AIR Vividh Bharati'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: freqCtrl,
                      decoration: const InputDecoration(labelText: 'Frequency / Dial *', hintText: 'e.g. 102.8 FM'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: stateCtrl,
                      decoration: const InputDecoration(labelText: 'State / Region', hintText: 'e.g. Mumbai / Maharashtra'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: catCtrl,
                      decoration: const InputDecoration(labelText: 'Category', hintText: 'e.g. AIR National, Retro, Regional'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: streamCtrl,
                      decoration: const InputDecoration(labelText: 'Stream URL (m3u8 / mp3) *', hintText: 'https://...'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: artCtrl,
                      decoration: const InputDecoration(labelText: 'Cover Artwork URL', hintText: 'https://...'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: taglineCtrl,
                      decoration: const InputDecoration(labelText: 'Tagline / Description', hintText: 'Short description'),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Is Live Broadcasting', style: TextStyle(fontSize: 13)),
                      value: isLive,
                      onChanged: (bool v) => setModalState(() => isLive = v),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty || streamCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Name and Stream URL are required')),
                      );
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Save Station'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      final Map<String, dynamic> data = <String, dynamic>{
        'name': nameCtrl.text.trim(),
        'tagline': taglineCtrl.text.trim(),
        'frequency': freqCtrl.text.trim(),
        'state': stateCtrl.text.trim(),
        'stream_url': streamCtrl.text.trim(),
        'artwork_url': artCtrl.text.trim().isNotEmpty
            ? artCtrl.text.trim()
            : 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
        'category': catCtrl.text.trim(),
        'is_live': isLive,
      };

      if (!mounted) return;
      try {
        final MusicRepository repo = context.read<MusicRepository>();
        if (existing == null) {
          await repo.createRadioStation(data);
        } else {
          await repo.updateRadioStation(existing.id, data);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Radio station saved successfully!'), backgroundColor: AppColors.success),
          );
          await _loadRadioStations();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save radio station: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Future<void> _deleteRadioStation(RadioStation station) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete Station'),
        content: Text('Are you sure you want to delete "${station.name}"?'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      try {
        final MusicRepository repo = context.read<MusicRepository>();
        await repo.deleteRadioStation(station.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Station "${station.name}" deleted'), backgroundColor: AppColors.success),
          );
          await _loadRadioStations();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete station: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Widget _buildRadioTab(BuildContext context) {
    final bool isDark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Radio Stations Manager',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Manage Akashvani and live Indian FM stations (${_adminRadioStations.length} active)',
                  style: TextStyle(fontSize: 12.5, color: context.textSecondary),
                ),
              ],
            ),
            Row(
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _loadRadioStations,
                  tooltip: 'Reload',
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark ? AppColors.secondary : AppColors.lightSecondaryAccent,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () => _showAddEditRadioStationDialog(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Station', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoadingRadio)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_adminRadioStations.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No radio stations registered.')),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _adminRadioStations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (BuildContext ctx, int i) {
              final RadioStation s = _adminRadioStations[i];
              return EchoGlassCard(
                padding: const EdgeInsets.all(12),
                borderRadius: 14,
                backgroundColor: isDark ? null : AppColors.lightSurface,
                child: Row(
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        s.artworkUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 48,
                          height: 48,
                          color: isDark ? AppColors.surfaceContainerHigh : AppColors.lightInputBackground,
                          child: const Icon(Icons.radio_rounded, size: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  s.name,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  s.frequency,
                                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.secondary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${s.state} • ${s.category}',
                            style: TextStyle(fontSize: 11.5, color: context.textSecondary),
                          ),
                          Text(
                            s.streamUrl,
                            style: TextStyle(fontSize: 10, color: context.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      tooltip: 'Edit Station',
                      onPressed: () => _showAddEditRadioStationDialog(existing: s),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                      tooltip: 'Delete Station',
                      onPressed: () => _deleteRadioStation(s),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // ==========================================
  // TAB: LIBRARY CATEGORIES MANAGEMENT
  // ==========================================

  Future<void> _loadLibraryCategories() async {
    setState(() => _isLoadingLibraryCats = true);
    try {
      final MusicRepository repo = context.read<MusicRepository>();
      final List<Map<String, dynamic>> raw = await repo.fetchLibraryCategories();
      if (mounted) {
        setState(() {
          _adminLibraryCats = raw;
          _isLoadingLibraryCats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLibraryCats = false);
      }
    }
  }

  Future<void> _showAddEditLibraryCategoryDialog({Map<String, dynamic>? existing}) async {
    final TextEditingController titleCtrl = TextEditingController(text: existing?['title']?.toString() ?? '');
    final TextEditingController subtitleCtrl = TextEditingController(text: existing?['subtitle']?.toString() ?? '');
    final TextEditingController queryCtrl = TextEditingController(text: existing?['query']?.toString() ?? '');
    final TextEditingController sourceUrlCtrl = TextEditingController(
      text: (existing?['source_url'] ?? existing?['url'])?.toString() ?? '',
    );
    final TextEditingController typeCtrl = TextEditingController(text: existing?['category_type']?.toString() ?? 'mood');
    final TextEditingController emojiCtrl = TextEditingController(text: existing?['emoji']?.toString() ?? '🎶');
    final TextEditingController startColorCtrl = TextEditingController(text: existing?['gradient_start']?.toString() ?? '#1E3A8A');
    final TextEditingController endColorCtrl = TextEditingController(text: existing?['gradient_end']?.toString() ?? '#2563EB');
    final TextEditingController artCtrl = TextEditingController(text: existing?['artwork_url']?.toString() ?? '');
    bool isActive = existing?['is_active'] != false;

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext dCtx, StateSetter setModalState) {
            return AlertDialog(
              title: Text(existing == null ? 'Add Library Category' : 'Edit Library Category'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Category Title *', hintText: 'e.g. Bollywood Hits'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: subtitleCtrl,
                      decoration: const InputDecoration(labelText: 'Subtitle', hintText: 'e.g. Top Hindi Cinema Chartbusters'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: queryCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Search / Mood Query *',
                        hintText: 'e.g. Bollywood Hits',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: sourceUrlCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Playlist / Source URL (optional)',
                        hintText: 'https://www.jiosaavn.com/featured/...',
                        helperText: 'Same as Catalogue — paste JioSaavn playlist/album URL to load exact songs',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emojiCtrl,
                      decoration: const InputDecoration(labelText: 'Emoji Icon', hintText: 'e.g. 🎬, 🕉️, 🥁, 💖'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: typeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Type (mood | search | playlist)',
                        hintText: 'playlist if using Source URL',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: startColorCtrl,
                            decoration: const InputDecoration(labelText: 'Gradient Start Hex', hintText: '#E11D48'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: endColorCtrl,
                            decoration: const InputDecoration(labelText: 'Gradient End Hex', hintText: '#B45309'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: artCtrl,
                      decoration: const InputDecoration(labelText: 'Cover Artwork URL (Optional)', hintText: 'https://...'),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Is Active in Library Discovery', style: TextStyle(fontSize: 13)),
                      value: isActive,
                      onChanged: (bool v) => setModalState(() => isActive = v),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (titleCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Title is required')),
                      );
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Save Category'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      final String sourceUrl = sourceUrlCtrl.text.trim();
      String query = queryCtrl.text.trim().isNotEmpty
          ? queryCtrl.text.trim()
          : titleCtrl.text.trim();
      String categoryType = typeCtrl.text.trim().isNotEmpty
          ? typeCtrl.text.trim()
          : 'mood';
      if (sourceUrl.isNotEmpty && categoryType == 'mood') {
        categoryType = 'playlist';
      }
      final Map<String, dynamic> data = <String, dynamic>{
        'title': titleCtrl.text.trim(),
        'subtitle': subtitleCtrl.text.trim(),
        'query': query,
        'source_url': sourceUrl,
        'category_type': categoryType,
        'emoji': emojiCtrl.text.trim().isNotEmpty ? emojiCtrl.text.trim() : '🎶',
        'gradient_start': startColorCtrl.text.trim().isNotEmpty ? startColorCtrl.text.trim() : '#1E3A8A',
        'gradient_end': endColorCtrl.text.trim().isNotEmpty ? endColorCtrl.text.trim() : '#2563EB',
        'artwork_url': artCtrl.text.trim(),
        'is_active': isActive,
      };

      if (!mounted) return;
      try {
        final MusicRepository repo = context.read<MusicRepository>();
        if (existing == null) {
          await repo.createLibraryCategory(data);
        } else {
          final String catId = existing['id']?.toString() ?? '';
          await repo.updateLibraryCategory(catId, data);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Category saved successfully!'), backgroundColor: AppColors.success),
          );
          await _loadLibraryCategories();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save category: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Future<void> _deleteLibraryCategory(Map<String, dynamic> cat) async {
    final String catId = cat['id']?.toString() ?? '';
    final String title = cat['title']?.toString() ?? 'Category';

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      try {
        final MusicRepository repo = context.read<MusicRepository>();
        await repo.deleteLibraryCategory(catId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Category "$title" deleted'), backgroundColor: AppColors.success),
          );
          await _loadLibraryCategories();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete category: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Widget _buildLibraryTab(BuildContext context) {
    final bool isDark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Library Categories Manager',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Control categories, query links and tags shown in the Library Discovery screen',
                  style: TextStyle(fontSize: 12.5, color: context.textSecondary),
                ),
              ],
            ),
            Row(
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _loadLibraryCategories,
                  tooltip: 'Reload',
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark ? AppColors.secondary : AppColors.lightSecondaryAccent,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () => _showAddEditLibraryCategoryDialog(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Category', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoadingLibraryCats)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_adminLibraryCats.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No categories configured.')),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _adminLibraryCats.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (BuildContext ctx, int i) {
              final Map<String, dynamic> c = _adminLibraryCats[i];
              final String title = c['title']?.toString() ?? '';
              final String subtitle = c['subtitle']?.toString() ?? '';
              final String emoji = c['emoji']?.toString() ?? '🎶';
              final String query = c['query']?.toString() ?? '';
              final String sourceUrl = (c['source_url'] ?? c['url'])?.toString() ?? '';
              final bool active = c['is_active'] != false;

              return EchoGlassCard(
                padding: const EdgeInsets.all(12),
                borderRadius: 14,
                backgroundColor: isDark ? null : AppColors.lightSurface,
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            Color(int.tryParse(c['gradient_start']?.toString().replaceFirst('#', '0xFF') ?? '') ?? 0xFF1E3A8A),
                            Color(int.tryParse(c['gradient_end']?.toString().replaceFirst('#', '0xFF') ?? '') ?? 0xFF2563EB),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(emoji, style: const TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5,
                                    decoration: active ? null : TextDecoration.lineThrough,
                                    color: active ? context.textPrimary : context.textMuted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (!active)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('HIDDEN', style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle.isNotEmpty ? subtitle : 'Query: $query',
                            style: TextStyle(fontSize: 11.5, color: context.textSecondary),
                          ),
                          Text(
                            sourceUrl.isNotEmpty
                                ? 'URL: $sourceUrl'
                                : 'Query: $query (${c["category_type"] ?? "mood"})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10, color: context.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      tooltip: 'Edit Category',
                      onPressed: () => _showAddEditLibraryCategoryDialog(existing: c),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                      tooltip: 'Delete Category',
                      onPressed: () => _deleteLibraryCategory(c),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
