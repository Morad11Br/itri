import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart';
import '../../theme.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  static const _kKey = 'app_language';
  String _selected = 'ar';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _selected = prefs.getString(_kKey) ?? 'ar');
  }

  Future<void> _save(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, code);
    if (!mounted) return;
    setState(() => _selected = code);
    AtariApp.setLocale(context, Locale(code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          code == 'ar'
              ? 'تم تعيين اللغة إلى العربية'
              : 'Language set to English',
          style: arabicStyle(fontSize: 14, color: Colors.white),
        ),
        backgroundColor: kOud,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
            AppLocalizations.of(context).language,
            style: arabicStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: kEspresso),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _tile(AppLocalizations.of(context).arabic, 'ar'),
            const SizedBox(height: 8),
            _tile(AppLocalizations.of(context).english, 'en'),
          ],
        ),
      ),
    );
  }

  Widget _tile(String label, String code) {
    final active = _selected == code;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: kCardShadow,
        border: Border.all(
          color: active ? kGold : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ListTile(
        title: Text(
          label,
          style: arabicStyle(
            fontSize: 15,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        trailing: active
            ? const Icon(Icons.check_circle_rounded, color: kGold)
            : const SizedBox.shrink(),
        onTap: () => _save(code),
      ),
    );
  }
}
