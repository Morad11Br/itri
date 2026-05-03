import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../data/community_repository.dart';
import '../l10n/app_localizations.dart';
import '../l10n/hardcoded_localizations.dart';
import '../models/perfume.dart';
import '../services/subscription_service.dart';
import 'paywall_screen.dart';
import '../theme.dart';
import 'settings/language_screen.dart';
import 'settings/notifications_screen.dart';
import 'settings/privacy_screen.dart';
import 'settings/help_screen.dart';
import 'settings/export_data_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? email;
  final String? name;
  final Future<ProfileStats> Function()? loadProfileStats;
  final Future<void> Function()? onSignOut;
  final Future<void> Function()? onDeleteAccount;
  final List<Perfume> perfumes;
  final Future<Map<String, String>> Function()? loadUserCollection;
  final Future<void> Function()? onUpgradeTap;
  final Future<void> Function()? onOpenCustomerCenter;
  final Future<void> Function(String newName)? onEditProfile;

  const ProfileScreen({
    super.key,
    this.email,
    this.name,
    this.loadProfileStats,
    this.onSignOut,
    this.onDeleteAccount,
    this.perfumes = const [],
    this.loadUserCollection,
    this.onUpgradeTap,
    this.onOpenCustomerCenter,
    this.onEditProfile,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _localName; // optimistic update — set immediately on save

  void _showEditNameSheet() {
    final controller = TextEditingController(text: _localName ?? widget.name ?? '');
    bool saving = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Directionality(
              textDirection: Directionality.of(context),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5DDD4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.t('Edit name'),
                      style: arabicStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: context.t('Your name'),
                        filled: true,
                        fillColor: kCream,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      style: arabicStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                final newName = controller.text.trim();
                                if (newName.isEmpty) return;
                                setSheetState(() => saving = true);
                                await widget.onEditProfile?.call(newName);
                                if (!mounted) return;
                                setState(() => _localName = newName);
                                if (ctx.mounted) Navigator.of(ctx).pop();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kGold,
                          foregroundColor: kOud,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: kOud),
                              )
                            : Text(
                                context.t('Save'),
                                style: arabicStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kOud),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Map<String, Object>> _stats(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      {'label': l10n.value, 'value': '34,500', 'sub': l10n.sar},
      {'label': l10n.collection, 'value': '47', 'sub': l10n.perfumes},
      {'label': l10n.reviews, 'value': '123', 'sub': l10n.reviews},
      {'label': l10n.followers, 'value': '289', 'sub': l10n.followers},
    ];
  }

  static const _notes = [
    {'n': 'Oud', 'p': 35, 'color': 0xFF3D2314},
    {'n': 'Musk', 'p': 22, 'color': 0xFFD4A5A5},
    {'n': 'Rose', 'p': 18, 'color': 0xFFC9A227},
    {'n': 'Amber', 'p': 13, 'color': 0xFF8FBC8F},
    {'n': 'Other', 'p': 12, 'color': 0xFFA8A29E},
  ];

  List<Map<String, Object>> _settings(BuildContext context, {required bool isPro}) {
    final l10n = AppLocalizations.of(context);
    final languageName = Localizations.localeOf(context).languageCode == 'ar'
        ? l10n.arabic
        : l10n.english;
    return [
      {
        'icon': '🌐',
        'label': l10n.language,
        'sub': languageName,
        'accent': false,
      },
      {
        'icon': '🔔',
        'label': l10n.notifications,
        'sub': context.t('Enabled'),
        'accent': false,
      },
      {'icon': '🔒', 'label': l10n.privacy, 'sub': '', 'accent': false},
      {'icon': '📤', 'label': l10n.exportData, 'sub': '', 'accent': false},
      {
        'icon': '🎁',
        'label': l10n.inviteFriend,
        'sub': context.t('Free month'),
        'accent': true,
      },
      {'icon': '❓', 'label': l10n.help, 'sub': '', 'accent': false},
      if (isPro)
        {
          'icon': '💎',
          'label': context.t('Manage Subscription'),
          'sub': context.t('Itri Pro'),
          'accent': false,
        },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: Directionality.of(context),
      child: Scaffold(
        backgroundColor: kCream,
        body: widget.loadProfileStats == null
            ? _buildContent(context, null)
            : FutureBuilder<ProfileStats>(
                future: widget.loadProfileStats!(),
                builder: (context, snapshot) =>
                    _buildContent(context, snapshot.data),
              ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ProfileStats? stats) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHero(context, stats),
          const SizedBox(height: 16),
          _buildPremiumCard(context),
          const SizedBox(height: 14),
          _buildNotesPie(context, stats),
          const SizedBox(height: 14),
          _buildSettingsList(context),
          if (widget.onSignOut != null) ...[
            const SizedBox(height: 14),
            _buildSignOutButton(context),
          ],
          if (widget.onDeleteAccount != null) ...[
            const SizedBox(height: 10),
            _buildDeleteAccountButton(context),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, ProfileStats? stats) {
    final profileName = _localName ?? stats?.user?.displayName;
    final displayName = (profileName?.trim().isNotEmpty ?? false)
        ? profileName!.trim()
        : (widget.name?.trim().isNotEmpty ?? false)
        ? widget.name!.trim()
        : context.t('Itri User');
    final subtitle = widget.email ?? AppLocalizations.of(context).profile;
    final initials =
        stats?.user?.initials ??
        (displayName.length <= 2 ? displayName : displayName.substring(0, 2));
    final profileStats = _statsFor(context, stats);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kOud, Color(0xFF6B3A1F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [kGold, kGoldLight]),
                  boxShadow: [
                    BoxShadow(
                      color: kGold.withValues(alpha: 0.3),
                      blurRadius: 0,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: arabicStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: kOud,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: arabicStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: Directionality.of(context),
                      style: arabicStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: widget.onEditProfile != null ? _showEditNameSheet : null,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: profileStats.asMap().entries.map((e) {
              final i = e.key;
              final s = e.value;
              return Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    border: Border(
                      right: i > 0
                          ? const BorderSide(color: Colors.white24, width: 1)
                          : BorderSide.none,
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      children: [
                        Text(
                          s['value'] as String,
                          style: arabicStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: kGold,
                          ),
                        ),
                        Text(
                          s['sub'] as String,
                          style: arabicStyle(
                            fontSize: 9,
                            color: Colors.white60,
                          ),
                        ),
                        Text(
                          s['label'] as String,
                          style: arabicStyle(
                            fontSize: 9,
                            color: Colors.white38,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumCard(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SubscriptionService.instance.isPro,
      builder: (context, isPro, _) {
        if (isPro) {
          return _buildActiveProCard(context);
        }
        return _buildUpgradeCard(context);
      },
    );
  }

  Widget _buildUpgradeCard(BuildContext context) {
    return GestureDetector(
      onTap: widget.onUpgradeTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A0A04), kOud],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kGold.withValues(alpha: 0.27)),
          boxShadow: kGoldShadow,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✨ ${AppLocalizations.of(context).premium}',
                    style: arabicStyle(
                      fontSize: 11,
                      color: kGold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    context.t('Upgrade to Itri Pro'),
                    style: arabicStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context).premiumDesc,
                    style: arabicStyle(fontSize: 11, color: Colors.white60),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kGoldLight, kGold]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                AppLocalizations.of(context).upgrade,
                style: arabicStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kOud,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveProCard(BuildContext context) {
    return GestureDetector(
      onTap: widget.onOpenCustomerCenter,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A0A04), kOud],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kGold.withValues(alpha: 0.5)),
          boxShadow: kGoldShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [kGoldLight, kGold]),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: kOud,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('Itri Pro — Active'),
                    style: arabicStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: kGold,
                    ),
                  ),
                  Text(
                    context.t('Manage your subscription'),
                    style: arabicStyle(fontSize: 11, color: Colors.white60),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: kGold,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesPie(BuildContext context, ProfileStats? stats) {
    final notes = _notesFor(stats);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).favoriteNotes,
            style: arabicStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: CustomPaint(painter: _PieChartPainter(notes: notes)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: notes.map((n) {
                    final color = Color(n['color'] as int);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              context.t(n['n'] as String),
                              style: arabicStyle(fontSize: 12),
                            ),
                          ),
                          Text(
                            '${n['p']}%',
                            style: arabicStyle(
                              fontSize: 12,
                              color: kWarmGray,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsList(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SubscriptionService.instance.isPro,
      builder: (context, isPro, _) => _buildSettingsListContent(context, isPro: isPro),
    );
  }

  Widget _buildSettingsListContent(BuildContext context, {required bool isPro}) {
    final settings = _settings(context, isPro: isPro);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: kCardShadow,
      ),
      child: Column(
        children: settings.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          final isGold = item['accent'] as bool;
          return Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: i < settings.length - 1
                    ? const BorderSide(color: Color(0xFFF5F0EB))
                    : BorderSide.none,
              ),
            ),
            child: ListTile(
              leading: Text(
                item['icon'] as String,
                style: const TextStyle(fontSize: 18),
              ),
              title: Text(
                item['label'] as String,
                style: arabicStyle(
                  fontSize: 14,
                  color: isGold ? kGold : kEspresso,
                  fontWeight: isGold ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
              subtitle: (item['sub'] as String).isNotEmpty
                  ? Text(
                      item['sub'] as String,
                      style: arabicStyle(fontSize: 11, color: kSand),
                    )
                  : null,
              trailing: const Icon(Icons.chevron_left_rounded, color: kSand),
              onTap: () => _onSettingTap(context, item['label'] as String),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _onSettingTap(BuildContext context, String label) {
    final l10n = AppLocalizations.of(context);
    if (label == l10n.language) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const LanguageScreen()));
    } else if (label == l10n.notifications) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    } else if (label == l10n.privacy) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const PrivacyScreen()));
    } else if (label == l10n.exportData) {
      if (!SubscriptionService.instance.isPro.value) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const PaywallScreen(),
            fullscreenDialog: true,
          ),
        );
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ExportDataScreen(
            perfumes: widget.perfumes,
            loadCollection: widget.loadUserCollection,
          ),
        ),
      );
    } else if (label == l10n.inviteFriend) {
      Share.share('${l10n.shareApp}\nhttps://itri.app', subject: l10n.appTitle);
    } else if (label == l10n.help) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const HelpScreen()));
    } else if (label == context.t('Manage Subscription')) {
      widget.onOpenCustomerCenter?.call();
    }
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: Directionality.of(context),
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            context.t('Delete account'),
            style: arabicStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.red.shade700),
            textAlign: TextAlign.center,
          ),
          content: Text(
            context.t('This will permanently delete your account, collection, reviews, and posts. This action cannot be undone.'),
            style: arabicStyle(fontSize: 14, color: kWarmGray, height: 1.5),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                context.t('Cancel'),
                style: arabicStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kWarmGray),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await widget.onDeleteAccount?.call();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                context.t('Delete'),
                style: arabicStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignOutButton(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OutlinedButton.icon(
        onPressed: widget.onSignOut,
        icon: const Icon(Icons.logout_rounded, size: 18, color: kOud),
        label: Text(
          l10n.signout,
          style: arabicStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: kOud,
          ),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFE5DDD4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteAccountButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OutlinedButton.icon(
        onPressed: () => _showDeleteAccountDialog(context),
        icon: Icon(Icons.delete_forever_rounded, size: 18, color: Colors.red.shade400),
        label: Text(
          context.t('Delete account'),
          style: arabicStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.red.shade400,
          ),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: Colors.white,
          side: BorderSide(color: Colors.red.shade100),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  List<Map<String, Object>> _statsFor(
    BuildContext context,
    ProfileStats? stats,
  ) {
    if (stats == null) return _stats(context);
    final l10n = AppLocalizations.of(context);
    return [
      {
        'label': l10n.collection,
        'value': _arabicNumber(stats.collectionCount),
        'sub': l10n.perfumes,
      },
      {
        'label': l10n.reviews,
        'value': _arabicNumber(stats.reviewsCount),
        'sub': l10n.reviews,
      },
      {
        'label': l10n.posts,
        'value': _arabicNumber(stats.postsCount),
        'sub': l10n.posts,
      },
      {
        'label': l10n.followers,
        'value': _arabicNumber(stats.followersCount),
        'sub': l10n.followers,
      },
    ];
  }

  List<Map<String, Object>> _notesFor(ProfileStats? stats) {
    final notes = stats?.notes ?? const <ProfileNoteStat>[];
    if (notes.isEmpty) return _notes;
    return notes
        .map(
          (note) => {
            'n': note.name,
            'p': note.percent,
            'color': note.color.toARGB32(),
          },
        )
        .toList(growable: false);
  }

  String _arabicNumber(int value) => value.toString();
}

class _PieChartPainter extends CustomPainter {
  final List<Map<String, Object>> notes;
  const _PieChartPainter({required this.notes});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 18.0;
    final paintRadius = radius - strokeWidth / 2;

    double startAngle = -1.5708; // -π/2 (start at top)

    for (final n in notes) {
      final pct = (n['p'] as int) / 100;
      final sweep = pct * 2 * 3.14159265;
      final color = Color(n['color'] as int);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: paintRadius),
        startAngle,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt,
      );
      startAngle += sweep;
    }

    // Center circle fill
    canvas.drawCircle(center, radius - strokeWidth, Paint()..color = kCream);

    // Center text
    final tp = TextPainter(
      text: TextSpan(
        text: 'Itri',
        style: arabicStyle(fontSize: 9, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(_PieChartPainter old) => false;
}
