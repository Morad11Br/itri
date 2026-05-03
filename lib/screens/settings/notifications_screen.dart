import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/hardcoded_localizations.dart';
import '../../services/notification_service.dart';
import '../../theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _kGeneral = 'notify_general';
  static const _kDeals = 'notify_deals';
  static const _kCollection = 'notify_collection';

  bool _general = false;
  bool _deals = false;
  bool _collection = false;
  bool _permissionGranted = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final granted = await NotificationService.instance.isPermissionGranted();
    if (!mounted) return;
    setState(() {
      _permissionGranted = granted;
      _general = granted && (prefs.getBool(_kGeneral) ?? true);
      _deals = granted && (prefs.getBool(_kDeals) ?? true);
      _collection = granted && (prefs.getBool(_kCollection) ?? true);
      _loading = false;
    });
  }

  Future<void> _toggle(String key, bool value, void Function(bool) setter) async {
    if (value && !_permissionGranted) {
      final granted = await NotificationService.instance.requestPermission();
      if (!mounted) return;
      if (!granted) return; // user denied — leave toggle off
      setState(() => _permissionGranted = true);
    }
    setter(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: Directionality.of(context),
      child: Scaffold(
        backgroundColor: kCream,
        appBar: AppBar(
          backgroundColor: kCream,
          elevation: 0,
          centerTitle: true,
          title: Text(
            AppLocalizations.of(context).notifications,
            style: arabicStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: kEspresso),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: _loading
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (!_permissionGranted) _buildPermissionBanner(),
                  if (!_permissionGranted) const SizedBox(height: 16),
                  _switchTile(
                    AppLocalizations.of(context).generalNotifications,
                    context.t('Alerts about perfumes and new content'),
                    _general,
                    (v) => setState(() {
                      _toggle(_kGeneral, v, (val) => _general = val);
                    }),
                  ),
                  const SizedBox(height: 10),
                  _switchTile(
                    AppLocalizations.of(context).promotions,
                    context.t('Alerts about available deals'),
                    _deals,
                    (v) => setState(() {
                      _toggle(_kDeals, v, (val) => _deals = val);
                    }),
                  ),
                  const SizedBox(height: 10),
                  _switchTile(
                    context.t('Collection updates'),
                    context.t('Alerts about your additions and ratings'),
                    _collection,
                    (v) => setState(() {
                      _toggle(_kCollection, v, (val) => _collection = val);
                    }),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPermissionBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kGold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_off_outlined, color: kGold, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.t('Enable a toggle below to allow notifications'),
              style: arabicStyle(fontSize: 13, color: kEspresso),
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: kCardShadow,
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: arabicStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: arabicStyle(fontSize: 12, color: kWarmGray),
        ),
        value: value,
        activeTrackColor: kGold,
        onChanged: onChanged,
      ),
    );
  }
}
