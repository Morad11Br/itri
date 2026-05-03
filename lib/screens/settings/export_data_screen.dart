import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/hardcoded_localizations.dart';
import '../../theme.dart';
import '../../models/perfume.dart';

class ExportDataScreen extends StatefulWidget {
  final List<Perfume> perfumes;
  final Future<Map<String, String>> Function()? loadCollection;

  const ExportDataScreen({
    super.key,
    required this.perfumes,
    this.loadCollection,
  });

  @override
  State<ExportDataScreen> createState() => _ExportDataScreenState();
}

class _ExportDataScreenState extends State<ExportDataScreen> {
  bool _loading = true;
  String _output = '';

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    if (widget.loadCollection == null) {
      setState(() {
        _output = context.t('No data to export.');
        _loading = false;
      });
      return;
    }

    try {
      final statuses = await widget.loadCollection!();
      final rows = <Map<String, Object?>>[];

      for (final entry in statuses.entries) {
        final perfume = widget.perfumes.firstWhere(
          (p) => p.id == entry.key,
          orElse: () => Perfume(name: entry.key, brand: '', rating: 0),
        );
        rows.add({
          'name': perfume.name,
          'brand': perfume.brand,
          'status': _statusLabel(entry.value),
          'rating': perfume.rating,
        });
      }

      final encoder = const JsonEncoder.withIndent('  ');
      setState(() {
        _output = rows.isEmpty
            ? context.t('No data to export.')
            : encoder.convert(rows);
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _output = context.t('Could not load data.');
        _loading = false;
      });
    }
  }

  String _statusLabel(String status) {
    return switch (status) {
      'owned' => context.t('Owned'),
      'wish' => context.t('Wishlist'),
      'tested' => context.t('Tested'),
      _ => status,
    };
  }

  void _share() {
    if (_output.isEmpty ||
        _output.startsWith('No data') ||
        _output.startsWith('Could not')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('Nothing to share'),
            style: arabicStyle(fontSize: 14),
          ),
          backgroundColor: kOud,
        ),
      );
      return;
    }
    Share.share(_output, subject: context.t('Itri Collection'));
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
            AppLocalizations.of(context).exportData,
            style: arabicStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: kEspresso),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLocalizations.of(context).exportDesc,
                style: arabicStyle(fontSize: 14, color: kWarmGray),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: kCardShadow,
                  ),
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: kGold),
                        )
                      : SingleChildScrollView(
                          child: SelectableText(
                            _output,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _share,
                  icon: const Icon(Icons.share_rounded),
                  label: Text(
                    context.t('Share data'),
                    style: arabicStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGold,
                    foregroundColor: kOud,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
