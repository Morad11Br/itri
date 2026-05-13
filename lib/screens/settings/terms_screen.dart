import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/hardcoded_localizations.dart';
import '../../theme.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

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
            AppLocalizations.of(context).termsOfUse,
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
                AppLocalizations.of(context).termsOfUse,
                style: arabicStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: kOud,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${context.t('Last updated')}: May 2025',
                style: arabicStyle(fontSize: 12, color: kWarmGray),
              ),
              const SizedBox(height: 20),
              _section(context.t('1. Subscriptions')),
              _body(
                context.t(
                  'Itri Pro is an auto-renewable subscription. Payment will be charged to your Apple ID account at confirmation of purchase. The subscription automatically renews unless cancelled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel your subscription in your Account Settings on the App Store.',
                ),
              ),
              const SizedBox(height: 16),
              _section(context.t('2. Free Trials')),
              _body(
                context.t(
                  'If offered, any unused portion of a free trial period will be forfeited when you purchase a subscription.',
                ),
              ),
              const SizedBox(height: 16),
              _section(context.t('3. Refunds')),
              _body(
                context.t(
                  'Refunds are handled by Apple according to the App Store policies. To request a refund, visit reportaproblem.apple.com or contact Apple Support.',
                ),
              ),
              const SizedBox(height: 16),
              _section(context.t('4. Data & Privacy')),
              _body(
                context.t(
                  'We collect only the data necessary to operate the app. Please review our Privacy Policy for full details.',
                ),
              ),
              const SizedBox(height: 16),
              _section(context.t('5. Account Termination')),
              _body(
                context.t(
                  'You may delete your account at any time. This will permanently remove your collection, reviews, and posts.',
                ),
              ),
              const SizedBox(height: 16),
              _section(context.t('6. Contact')),
              _body(
                '${context.t('For questions about these terms, contact us at')} support@novaparfum.com',
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
