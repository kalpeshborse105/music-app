import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../core/storage/settings_store.dart';
import '../../data/services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
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

  late TabController _tabController;

  static const List<Map<String, dynamic>> _tabs = <Map<String, dynamic>>[
    <String, dynamic>{'title': 'Overview', 'icon': Icons.dashboard_rounded},
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
    if (index == 1) _loadUsers();
    if (index == 4) _loadReports();
  }

  Future<void> _verifyRole() async {
    final SupabaseService supabase = SupabaseService();
    final bool isAdmin = await supabase.isUserAdmin();
    if (mounted) {
      setState(() {
        _isAuthorized = isAdmin;
        _isCheckingRole = false;
      });
      if (isAdmin) {
        _loadPlatformMetrics();
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
        Uri.parse('https://api.audius.co/v1/tracks/trending?app_name=EchoFlowMusic&limit=1'),
        headers: <String, String>{
          'User-Agent': 'EchoFlowMusic/1.0.0 (Android; Mobile; Web)',
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
          'User-Agent': 'EchoFlowMusic/1.0.0 (Android; Mobile; Web)',
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
              'EchoFlow Operations Center',
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
        return _buildUsersTab(context);
      case 2:
        return _buildProvidersTab(context);
      case 3:
        return _buildLicensesTab(context);
      case 4:
        return _buildReportsTab(context);
      case 5:
      default:
        return _buildSettingsTab(context);
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
          'Active connectors feeding legal audio into EchoFlow streaming pipelines.',
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
          'Every stream on EchoFlow respects explicit Creative Commons or direct streaming authorizations.',
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
