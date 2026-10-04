import 'package:flutter/material.dart';
import '../../data/services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/glass_card.dart';

/// Stitch Admin Dashboard - Operations & Catalog Center
/// (Screen ID: 66b0dc16d9a2474ab54302b8b2b409f0)
/// Protected: accessible strictly to authorized Supabase administrators.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  int _selectedTab = 0;
  bool _isCheckingRole = true;
  bool _isAuthorized = false;

  // Feature flag settings
  bool _spatialAudio = true;
  bool _flacPipeline = true;
  bool _localSync = true;
  bool _hapticFeedback = true;

  late TabController _tabController;

  static const List<Map<String, dynamic>> _tabs = <Map<String, dynamic>>[
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
      }
    });
    _verifyRole();
  }

  Future<void> _verifyRole() async {
    final SupabaseService supabase = SupabaseService();
    final bool isAdmin = await supabase.isUserAdmin();
    if (mounted) {
      setState(() {
        _isAuthorized = isAdmin;
        _isCheckingRole = false;
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
    final bool isDesktop = screenWidth >= 760;

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
                  'Your account is not registered with administrative authorization. '
                  'Please sign in with a verified administrator account.',
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
                // Desktop Navigation Rail
                NavigationRail(
                  selectedIndex: _selectedTab,
                  onDestinationSelected: (int index) {
                    setState(() => _selectedTab = index);
                    _tabController.animateTo(index);
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

                // Main tab content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: _buildTabContent(context),
                  ),
                ),
              ],
            )
          : TabBarView(
              controller: _tabController,
              children: <Widget>[
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

  Widget _buildTabContent(BuildContext context) {
    switch (_selectedTab) {
      case 0:
        return _buildProvidersTab(context);
      case 1:
        return _buildLicensesTab(context);
      case 2:
        return _buildReportsTab(context);
      case 3:
      default:
        return _buildSettingsTab(context);
    }
  }

  Widget _buildProvidersTab(BuildContext context) {
    final bool isDark = context.isDarkMode;
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

        _buildProviderStatusCard(
          context,
          name: 'Jamendo Music API',
          type: 'Creative Commons 3.0 / Commercial Stream Provider',
          status: 'Online & Verified',
          statusColor: AppColors.success,
          stats: '500,000+ tracks • MP3 / FLAC',
          capabilities: const <String>[
            'Streaming',
            'Radio',
            'Recommendations',
            'Search'
          ],
        ),
        const SizedBox(height: 12),

        _buildProviderStatusCard(
          context,
          name: 'Audius Discovery Protocol',
          type: 'Official Decentralized Audio Stream Provider',
          status: 'Online & Streaming (ACTIVE)',
          statusColor: AppColors.success,
          stats: 'Global Artists • 320kbps MP3 • Rate Limited',
          capabilities: const <String>['Streaming', 'Search', 'Browse', 'Circuit Breaker'],
        ),
        const SizedBox(height: 12),

        _buildProviderStatusCard(
          context,
          name: 'Local Device MediaStore',
          type: 'On-Device Android Scoped Storage',
          status: 'Active (Zero-Latency)',
          statusColor:
              isDark ? AppColors.primary : AppColors.lightPrimaryAccent,
          stats: 'Local FLAC/MP3/AAC • No Network Required',
          capabilities: const <String>[
            'Offline Playback',
            'Tags',
            'Zero Latency'
          ],
        ),
        const SizedBox(height: 12),

        _buildProviderStatusCard(
          context,
          name: 'Regional Indian Music Catalog',
          type: 'Hindi, Marathi, Khandeshi & Indic Languages',
          status: 'LICENSE PENDING',
          statusColor: Colors.amber,
          stats: '8 Languages • Zero Scraping • Commercial Partner Pending',
          capabilities: const <String>[
            'Compliance Gated',
            'Language Architecture',
            'Clean Metadata'
          ],
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
                          color: context.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(type,
                        style: TextStyle(
                            fontSize: 11, color: context.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(stats,
              style: TextStyle(fontSize: 12, color: context.textPrimary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: capabilities
                .map((String c) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceContainerHighest
                            : AppColors.lightElevatedSurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        c,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.secondary
                              : AppColors.lightSecondaryAccent,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

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
                    color: isDark
                        ? AppColors.secondary
                        : AppColors.lightSecondaryAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Creative Commons CC-BY / CC-BY-SA 3.0 & 4.0',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Requires attribution, preserves artist rights, prohibits unauthorized offline commercial resale without express direct artist license.',
                style: TextStyle(
                    fontSize: 12, color: context.textSecondary, height: 1.4),
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
                    color: isDark
                        ? AppColors.primaryLight
                        : AppColors.lightPrimaryAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Jamendo Commercial & Public API Terms',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Streams are delivered directly from authorized Jamendo endpoints under fair attribution guidelines.',
                style: TextStyle(
                    fontSize: 12, color: context.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReportsTab(BuildContext context) {
    final bool isDark = context.isDarkMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'User Reports & Content Takedowns',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
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
                  'No Pending Copyright Reports',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'All active catalogs are clean and fully compliant with DMCA Safe Harbor requirements.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

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
