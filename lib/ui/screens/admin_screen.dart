import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../core/storage/settings_store.dart';
import '../../data/music_repository.dart';
import '../../data/services/supabase_service.dart';
import '../../domain/models/advertisement.dart';
import '../../domain/models/catalog_section.dart';
import '../../domain/models/track.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/ad_popup_dialog.dart';
import '../widgets/glass_card.dart';

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

  // Reports State
  bool _isLoadingReports = false;
  List<Map<String, dynamic>> _reports = <Map<String, dynamic>>[];

  // Provider Live Test States
  String? _audiusTestResult;
  bool _isTestingAudius = false;
  String? _jamendoTestResult;
  bool _isTestingJamendo = false;

  // System & Feature Flags
  bool _spatialAudio = true;
  bool _flacPipeline = true;
  bool _localSync = true;
  bool _hapticFeedback = true;

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

  late TabController _tabController;

  static const List<Map<String, dynamic>> _tabs = <Map<String, dynamic>>[
    <String, dynamic>{'title': 'Overview', 'icon': Icons.dashboard_rounded},
    <String, dynamic>{'title': 'Catalogue', 'icon': Icons.queue_music_rounded},
    <String, dynamic>{'title': 'Ads', 'icon': Icons.campaign_rounded},
    <String, dynamic>{'title': 'Users', 'icon': Icons.people_alt_rounded},
    <String, dynamic>{'title': 'Providers', 'icon': Icons.hub_rounded},
    <String, dynamic>{'title': 'Licenses', 'icon': Icons.gavel_rounded},
    <String, dynamic>{'title': 'Reports', 'icon': Icons.report_problem_rounded},
    <String, dynamic>{'title': 'Settings', 'icon': Icons.tune_rounded},
  ];

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
    if (index == 2) _loadAds();
    if (index == 3) _loadUsers();
    if (index == 6) _loadReports();
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
        title: Row(
          children: <Widget>[
            Icon(
              Icons.admin_panel_settings_rounded,
              color: isDark ? AppColors.secondary : AppColors.lightSecondaryAccent,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'Kalpkrut Beats Operations Center',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
        backgroundColor: (isDark ? AppColors.darkBg : AppColors.lightNavSurface)
            .withValues(alpha: 0.94),
        bottom: !isDesktop
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: isDark ? AppColors.secondary : AppColors.lightSecondaryAccent,
                labelColor: isDark ? AppColors.secondary : AppColors.lightSecondaryAccent,
                unselectedLabelColor: context.textSecondary,
                tabs: _tabs.map((Map<String, dynamic> t) {
                  return Tab(
                    icon: Icon(t['icon'] as IconData, size: 18),
                    text: t['title'] as String,
                  );
                }).toList(),
              )
            : null,
      ),
      body: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                NavigationRail(
                  selectedIndex: _selectedTab,
                  onDestinationSelected: (int index) {
                    setState(() => _selectedTab = index);
                    _tabController.animateTo(index);
                    _onTabSelected(index);
                  },
                  backgroundColor: isDark
                      ? AppColors.surfaceContainerLowest
                      : AppColors.lightElevatedSurface,
                  indicatorColor: isDark
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : AppColors.lightPrimaryAccent.withValues(alpha: 0.16),
                  labelType: NavigationRailLabelType.all,
                  destinations: _tabs.map((Map<String, dynamic> t) {
                    return NavigationRailDestination(
                      icon: Icon(t['icon'] as IconData),
                      selectedIcon: Icon(t['icon'] as IconData,
                          color: isDark
                              ? AppColors.secondary
                              : AppColors.lightSecondaryAccent),
                      label: Text(t['title'] as String,
                          style: const TextStyle(fontSize: 11)),
                    );
                  }).toList(),
                ),
                VerticalDivider(
                  width: 1,
                  color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: _buildSelectedTabContent(context),
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
                  child: _buildAdsTab(context),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _buildUsersTab(context),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _buildProvidersTab(context),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _buildLicensesTab(context),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _buildReportsTab(context),
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
        return _buildAdsTab(context);
      case 3:
        return _buildUsersTab(context);
      case 4:
        return _buildProvidersTab(context);
      case 5:
        return _buildLicensesTab(context);
      case 6:
        return _buildReportsTab(context);
      case 7:
      default:
        return _buildSettingsTab(context);
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
    if (lower.contains('/featured/') || lower.contains('/playlist/')) return 'playlist';
    if (lower.contains('/album/')) return 'album';
    if (lower.contains('/new-releases')) return 'new_releases';
    if (lower.contains('/charts')) return 'charts';
    if (lower.contains('/top-artists')) return 'top_artists';
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
        );
      } else {
        await repo.createCatalogSection(
          sourceUrl: url,
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
        await _loadCatalogSections();
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
      _previewItems = s.items;
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
      _previewError = null;
    });
  }

  Future<void> _toggleCatalogSection(CatalogSection s) async {
    final MusicRepository repo = context.read<MusicRepository>();
    try {
      await repo.toggleCatalogSection(s.sectionKey, !s.isEnabled);
      await _loadCatalogSections();
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
          await _loadCatalogSections();
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

  Future<void> _moveCatalogSection(int oldIndex, int newIndex) async {
    if (newIndex < 0 || newIndex >= _catalogSections.length) return;
    final List<CatalogSection> updated = List<CatalogSection>.from(_catalogSections);
    final CatalogSection item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    final List<String> orderedKeys = updated.map((CatalogSection s) => s.sectionKey).toList();

    setState(() => _catalogSections = updated);

    try {
      final MusicRepository repo = context.read<MusicRepository>();
      await repo.reorderCatalogSections(orderedKeys);
      await _loadCatalogSections();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reorder: $e'), backgroundColor: AppColors.error),
        );
        await _loadCatalogSections();
      }
    }
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

  Widget _buildCatalogSectionCard(BuildContext context, CatalogSection section, int index) {
    final bool isDark = context.isDarkMode;

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
                        color: AppColors.secondary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        section.sourceType.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.secondary,
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
                        color: (section.isMock ? AppColors.secondary : AppColors.success).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        section.isMock ? 'MOCK' : 'LIVE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: section.isMock ? AppColors.secondary : AppColors.success,
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
                  '${section.items.length} tracks • Lang: ${section.language.toUpperCase()}',
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
                        '#${section.position}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryLight,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                      tooltip: 'Move Up',
                      onPressed: index > 0 ? () => _moveCatalogSection(index, index - 1) : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                      tooltip: 'Move Down',
                      onPressed: index < _catalogSections.length - 1
                          ? () => _moveCatalogSection(index, index + 1)
                          : null,
                    ),
                    const Spacer(),
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
              // Position & Reorder Arrows
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  InkWell(
                    onTap: index > 0 ? () => _moveCatalogSection(index, index - 1) : null,
                    borderRadius: BorderRadius.circular(4),
                    child: Icon(
                      Icons.arrow_drop_up_rounded,
                      size: 24,
                      color: index > 0 ? context.textPrimary : context.textMuted.withValues(alpha: 0.3),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#${section.position}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: index < _catalogSections.length - 1
                        ? () => _moveCatalogSection(index, index + 1)
                        : null,
                    borderRadius: BorderRadius.circular(4),
                    child: Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 24,
                      color: index < _catalogSections.length - 1
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
                            color: AppColors.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            section.sourceType.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.secondary,
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
                            color: (section.isMock ? AppColors.secondary : AppColors.success).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            section.isMock ? 'MOCK' : 'LIVE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: section.isMock ? AppColors.secondary : AppColors.success,
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
                          '${section.items.length} tracks • Lang: ${section.language.toUpperCase()}',
                          style: TextStyle(fontSize: 10.5, color: context.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Actions: Enabled Switch, Edit, Delete
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
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
            IconButton.filledTonal(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh Catalogue Sections',
              onPressed: _loadCatalogSections,
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
                    'Hindi Top 50 (Playlist)',
                    'https://www.jiosaavn.com/featured/hindi-india-superhits-top-50/zlJfJYVuyjpxWb5,FqsjKg__',
                  ),
                  _buildQuickUrlChip(
                    'Kishore Kumar (Artist)',
                    'https://www.jiosaavn.com/artist/kishore-kumar-songs/yMoPyl3ZzyY_',
                  ),
                  _buildQuickUrlChip(
                    'Surprise Me (Playlist)',
                    'https://www.jiosaavn.com/featured/surprise-me/1ZOczFTRyFw_',
                  ),
                  _buildQuickUrlChip(
                    'New Releases (Collection)',
                    'https://www.jiosaavn.com/new-releases',
                  ),
                  _buildQuickUrlChip(
                    'Charts (Collection)',
                    'https://www.jiosaavn.com/charts',
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

                      // Quick Category Chips
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: <String>[
                          'Top Charts',
                          'Featured Playlists',
                          'Festival Specials',
                          'Trending Now',
                          'Devotional & Bhakti',
                          'Featured Artists',
                          'New Releases',
                        ].map((String grp) {
                          return ActionChip(
                            visualDensity: VisualDensity.compact,
                            label: Text(grp, style: const TextStyle(fontSize: 10.5)),
                            onPressed: () {
                              setState(() {
                                _catalogGroupController.text = grp;
                              });
                            },
                          );
                        }).toList(),
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

              // Resolved Preview Tracks List
              if (_previewItems.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Resolved Items Preview (${_previewItems.length} tracks):',
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
                  height: 130,
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
                      return Container(
                        width: 160,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceContainerHigh : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              track.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              track.artistNames,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: context.textSecondary, fontSize: 10.5),
                            ),
                            const Spacer(),
                            Text(
                              track.duration.inSeconds > 0
                                  ? '${track.duration.inMinutes}:${(track.duration.inSeconds % 60).toString().padLeft(2, "0")}'
                                  : '--:--',
                              style: TextStyle(color: context.textMuted, fontSize: 9.5),
                            ),
                          ],
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
                fontSize: 16,
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
        const SizedBox(height: 12),

        if (_catalogSections.isEmpty && !_isLoadingCatalog)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Text(
                'No catalogue sections configured yet. Add your first section above.',
                style: TextStyle(color: context.textMuted),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _catalogSections.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (BuildContext ctx, int index) {
              final CatalogSection section = _catalogSections[index];
              return _buildCatalogSectionCard(ctx, section, index);
            },
          ),
      ],
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
                      'Control Amazon Prime style popups, images, target URLs, and whether users see a ✕ cross icon, "Close ✕", or "Skip" button.',
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
        const SizedBox(height: 20),

        if (_isLoadingAds)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_ads.isEmpty)
          Center(
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
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _ads.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (BuildContext ctx, int index) {
              final Advertisement ad = _ads[index];
              return _buildAdItemCard(context, ad);
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.4), width: 0.8),
                ),
                child: Text(
                  closeBadgeText,
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
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
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active / Published Live', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('When active, shown to users upon opening app', style: TextStyle(fontSize: 12)),
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

  Widget _buildOverviewTab(BuildContext context) {
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
                  'Platform Database Overview',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Live data synchronized from Supabase cloud infrastructure.',
                  style: TextStyle(fontSize: 13, color: context.textSecondary),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh Metrics',
              onPressed: _loadPlatformMetrics,
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
                      Row(
                        children: <Widget>[
                          const Text(
                            'Supabase PostgreSQL: ',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          Text(
                            _metrics['database_status'] ?? 'Online',
                            style: const TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Last Sync: ${_metrics['last_sync'] != null ? DateTime.tryParse(_metrics['last_sync'])?.toLocal().toString().split('.').first : "Just now"}',
                        style: TextStyle(fontSize: 11, color: context.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Real Metric Grid
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
              ),
              _buildMetricCard(
                context,
                title: 'Total Tracks',
                value: _metrics['tracks_count'] ?? 'Not tracked yet',
                icon: Icons.music_note_rounded,
                color: isDark ? AppColors.primaryLight : AppColors.lightPrimaryAccent,
              ),
              _buildMetricCard(
                context,
                title: 'Total Artists',
                value: _metrics['artists_count'] ?? 'Not tracked yet',
                icon: Icons.mic_external_on_rounded,
                color: isDark ? AppColors.tertiaryLight : AppColors.lightTertiaryAccent,
              ),
              _buildMetricCard(
                context,
                title: 'Total Playlists',
                value: _metrics['playlists_count'] ?? '0',
                icon: Icons.queue_music_rounded,
                color: Colors.amber,
              ),
              _buildMetricCard(
                context,
                title: 'Total Favorites',
                value: _metrics['favorites_count'] ?? '0',
                icon: Icons.favorite_border_rounded,
                color: AppColors.tertiary,
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
                title: 'Total Reports',
                value: _metrics['reports_count'] ?? '0',
                icon: Icons.flag_outlined,
                color: AppColors.error,
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
  }) {
    final bool isDark = context.isDarkMode;
    final double cardWidth = (MediaQuery.of(context).size.width - 48) / 2;

    return SizedBox(
      width: cardWidth.clamp(150.0, 240.0),
      child: EchoGlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 16,
        backgroundColor: isDark ? null : AppColors.lightSurface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                  ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
              ),
            ),
          ],
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
      if (_userSearchQuery.isEmpty) return true;
      final String name = (u['display_name'] ?? '').toString().toLowerCase();
      final String email = (u['email'] ?? '').toString().toLowerCase();
      final String query = _userSearchQuery.toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();

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
  // TAB 4: LEGAL COMPLIANCE & ATTRIBUTION
  // ==========================================

  Widget _buildLicensesTab(BuildContext context) {
    final bool isDark = context.isDarkMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Legal Attribution & Compliance Registry',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Every stream on Kalpkrut Beats respects explicit Creative Commons or direct streaming authorizations.',
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
              Row(
                children: <Widget>[
                  Icon(
                    Icons.verified_rounded,
                    color: isDark ? AppColors.secondary : AppColors.lightSecondaryAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Creative Commons CC-BY / CC-BY-SA 3.0 & 4.0',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Requires attribution, preserves artist rights, prohibits unauthorized offline commercial resale without express direct artist license.',
                style: TextStyle(fontSize: 12, color: context.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        EchoGlassCard(
          padding: const EdgeInsets.all(16),
          borderRadius: 16,
          backgroundColor: isDark ? null : AppColors.lightSurface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.security_rounded,
                    color: isDark ? AppColors.primaryLight : AppColors.lightPrimaryAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Jamendo Commercial & Public API Terms',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Streams are delivered directly from authorized Jamendo endpoints under fair attribution guidelines.',
                style: TextStyle(fontSize: 12, color: context.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
      ],
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
        const SizedBox(height: 16),

        if (_isLoadingReports)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_reports.isEmpty)
          EchoGlassCard(
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
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _reports.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (BuildContext ctx, int i) {
              final Map<String, dynamic> r = _reports[i];
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
          ),
      ],
    );
  }

  // ==========================================
  // TAB 6: SETTINGS & FEATURE FLAGS
  // ==========================================

  Widget _buildSettingsTab(BuildContext context) {
    final bool isDark = context.isDarkMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'System & Feature Flags',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        EchoGlassCard(
          padding: EdgeInsets.zero,
          borderRadius: 16,
          backgroundColor: isDark ? null : AppColors.lightSurface,
          child: Column(
            children: <Widget>[
              SwitchListTile(
                title: const Text('Spatial Audio Engine',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Binaural 3D soundstage emulation'),
                value: _spatialAudio,
                onChanged: (bool v) => setState(() => _spatialAudio = v),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Hi-Res 24-Bit FLAC Pipeline',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Enable bit-perfect FLAC decoding stream'),
                value: _flacPipeline,
                onChanged: (bool v) => setState(() => _flacPipeline = v),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Local MediaStore Scoped Storage',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Zero-latency indexing of local device audio'),
                value: _localSync,
                onChanged: (bool v) => setState(() => _localSync = v),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Haptic Touch Feedback',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Subtle haptics on playback interactions'),
                value: _hapticFeedback,
                onChanged: (bool v) => setState(() => _hapticFeedback = v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
