import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/hardcoded_localizations.dart';
import '../../theme.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

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
            AppLocalizations.of(context).privacy,
            style: arabicStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: kEspresso),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).privacyPolicy,
                style: arabicStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: kOud,
                ),
              ),
              const SizedBox(height: 16),
              _section(AppLocalizations.of(context).dataCollection),
              _body(
                context.t(
                  'We collect only the data needed to run the app, including your email address, perfume names in your collection, and your ratings. We do not sell your data to third parties.',
                ),
              ),
              const SizedBox(height: 16),
              _section(AppLocalizations.of(context).security),
              _body(
                context.t(
                  'Your data is stored in a secure database with Row Level Security. Only you can access your personal data.',
                ),
              ),
              const SizedBox(height: 16),
              _section(context.t('Files and photos')),
              _body(
                context.t(
                  'The app only requests camera or photo access if you choose to upload a profile picture. All other images are loaded from public links.',
                ),
              ),
              const SizedBox(height: 16),
              _section(context.t('Delete account')),
              _body(
                context.t(
                  'You can delete your account and all your data at any time by contacting us by email.',
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String text) {
    return Text(
      text,
      style: arabicStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: kEspresso,
      ),
    );
  }

  Widget _body(String text) {
    return Text(
      text,
      style: arabicStyle(fontSize: 14, color: kWarmGray, height: 1.6),
    );
  }
}
