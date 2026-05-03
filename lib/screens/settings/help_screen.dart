import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/hardcoded_localizations.dart';
import '../../theme.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  final _faqs = const [
    {
      'q': 'How do I add a perfume to my collection?',
      'a':
          'Tap the + button on the "My Collection" screen, then search by perfume name or enter it manually.',
    },
    {
      'q': 'Can I track perfume prices?',
      'a':
          'Yes. You can view Today\x27s Deals on the home screen. Detailed price tracking is coming soon.',
    },
    {
      'q': 'How do I use the perfume finder?',
      'a':
          'Go to "Occasions" and choose the occasion, budget, and style. We will suggest the best perfumes.',
    },
    {
      'q': 'Is my data protected?',
      'a':
          'Yes. Your data is protected with encryption, and no other user can access your personal collection.',
    },
    {
      'q': 'How do I delete my account?',
      'a':
          'Contact us by email to request permanent account and data deletion.',
    },
  ];

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
            AppLocalizations.of(context).help,
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: kCardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).faq,
                    style: arabicStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: kOud,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._faqs.map(
                    (item) => ExpansionTile(
                      title: Text(
                        context.t(item['q']!),
                        style: arabicStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Text(
                            context.t(item['a']!),
                            style: arabicStyle(
                              fontSize: 13,
                              color: kWarmGray,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: kCardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).contact,
                    style: arabicStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: kOud,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.email_outlined, color: kGold),
                    title: Text(
                      'support@itri.app',
                      style: arabicStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
