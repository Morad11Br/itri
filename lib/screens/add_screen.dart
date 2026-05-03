import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/app_localizations.dart';
import '../l10n/hardcoded_localizations.dart';
import '../models/perfume.dart';
import '../theme.dart';
import '../widgets/bottle_icon.dart';
import '../widgets/perfume_image.dart';

class AddScreen extends StatefulWidget {
  final List<Perfume> perfumes;
  final Future<List<Perfume>> Function(String query)? onSearchPerfumes;
  final FutureOr<void> Function(Perfume perfume)? onPerfumeTap;
  final Future<void> Function(Perfume perfume)? onAddToCollection;
  final Future<void> Function({
    required String name,
    required String concentration,
    required String source,
    double? price,
    required List<String> notes,
    String? personalNotes,
  })?
  onSaveManualEntry;
  final Future<
    ({String brand, String name, String confidence, List<Perfume> matches})
  >
  Function(String base64Image)?
  onIdentifyByImage;
  final VoidCallback onClose;
  const AddScreen({
    super.key,
    required this.perfumes,
    required this.onClose,
    this.onSearchPerfumes,
    this.onPerfumeTap,
    this.onAddToCollection,
    this.onSaveManualEntry,
    this.onIdentifyByImage,
  });

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  String _tab = 'Search';
  String _concentration = 'EDP';
  String _source = 'Purchase';
  final Set<String> _selectedNotes = {};
  final _searchCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _personalNotesCtrl = TextEditingController();
  Timer? _searchDebounce;
  List<Perfume>? _remoteResults;
  bool _searching = false;
  bool _saving = false;
  String? _addingPerfumeId;
  int _searchVersion = 0;

  final _picker = ImagePicker();
  bool _aiIdentifying = false;
  String? _aiError;
  String? _aiDetectedBrand;
  String? _aiDetectedName;
  String _aiConfidence = '';
  List<Perfume> _aiMatches = [];
  final _tabs = ['Search', 'AI', 'Manual'];
  final _notes = [
    'Oud',
    'Musk',
    'Rose',
    'Citrus',
    'Vanilla',
    'Amber',
    'Woods',
    'Incense',
    'Tobacco',
    'Saffron',
  ];

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _personalNotesCtrl.dispose();
    super.dispose();
  }

  void _switchTab(String tab) {
    setState(() => _tab = tab);
  }

  Future<void> _pickImage(ImageSource source) async {
    if (widget.onIdentifyByImage == null) return;
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final base64 = base64Encode(bytes);
    final mime = picked.mimeType ?? 'image/jpeg';
    final dataUrl = 'data:$mime;base64,$base64';

    setState(() {
      _aiIdentifying = true;
      _aiError = null;
      _aiDetectedBrand = null;
      _aiDetectedName = null;
      _aiConfidence = '';
      _aiMatches = [];
    });

    try {
      final result = await widget.onIdentifyByImage!(dataUrl);
      if (!mounted) return;
      setState(() {
        _aiDetectedBrand = result.brand;
        _aiDetectedName = result.name;
        _aiConfidence = result.confidence;
        _aiMatches = result.matches;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiError = e.toString());
    } finally {
      if (mounted) setState(() => _aiIdentifying = false);
    }
  }

  void _resetAI() {
    setState(() {
      _aiError = null;
      _aiDetectedBrand = null;
      _aiDetectedName = null;
      _aiConfidence = '';
      _aiMatches = [];
    });
  }

  void _onSearchChanged(String _) {
    setState(() {});
    if (widget.onSearchPerfumes == null) return;

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_runRemoteSearch());
    });
  }

  Future<void> _runRemoteSearch() async {
    final query = _searchCtrl.text.trim();
    final version = ++_searchVersion;
    setState(() => _searching = true);
    try {
      final results = await widget.onSearchPerfumes!(query);
      if (!mounted || version != _searchVersion) return;
      setState(() => _remoteResults = results);
    } catch (_) {
      if (!mounted || version != _searchVersion) return;
      setState(() => _remoteResults = const []);
    } finally {
      if (mounted && version == _searchVersion) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _submitManual() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('Enter perfume name'),
            style: arabicStyle(fontSize: 14),
          ),
          backgroundColor: kOud,
        ),
      );
      return;
    }
    if (widget.onSaveManualEntry == null) return;
    setState(() => _saving = true);
    try {
      await widget.onSaveManualEntry!(
        name: name,
        concentration: _concentration,
        source: _source,
        price: double.tryParse(_priceCtrl.text.trim()),
        notes: _selectedNotes.toList(),
        personalNotes: _personalNotesCtrl.text.trim().isEmpty
            ? null
            : _personalNotesCtrl.text.trim(),
      );
      if (!mounted) return;
      widget.onClose();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('Something went wrong, please try again'),
            style: arabicStyle(fontSize: 14),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: Directionality.of(context),
      child: Scaffold(
        backgroundColor: kCream,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _tab == 'Search'
                      ? _buildSearchTab()
                      : _tab == 'AI'
                      ? _buildAICameraTab()
                      : _buildManualTab(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            AppLocalizations.of(context).addPerfume,
            style: arabicStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: kCardShadow,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 16,
                color: kEspresso,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: kCardShadow,
      ),
      child: Row(
        children: _tabs.map((t) {
          final active = t == _tab;
          return Expanded(
            child: GestureDetector(
              onTap: () => _switchTab(t),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: active ? kOud : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  context.t(t),
                  textAlign: TextAlign.center,
                  style: arabicStyle(
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                    color: active ? Colors.white : kWarmGray,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchTab() {
    final query = _searchCtrl.text.trim().toLowerCase();
    final results = widget.onSearchPerfumes == null || _remoteResults == null
        ? widget.perfumes
              .where((p) {
                if (query.isEmpty) return true;
                return _matchesPerfumeSearch(p, query);
              })
              .take(8)
              .toList()
        : _remoteResults!;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: kCardShadow,
            border: Border.all(
              color: _searchCtrl.text.isNotEmpty
                  ? kGold
                  : const Color(0xFFE5DDD4),
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: _searchCtrl,
            textDirection: Directionality.of(context),
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).searchHint,
              hintStyle: arabicStyle(fontSize: 14, color: kSand),
              prefixIcon: const Icon(Icons.search_rounded, color: kSand),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_searching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: kGold),
            ),
          ),
        ...results.map(
          (p) => GestureDetector(
            onTap: widget.onPerfumeTap == null
                ? null
                : () => widget.onPerfumeTap!(p),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: kCardShadow,
              ),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 70,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(
                        colors: [kGoldPale, Colors.white],
                      ),
                    ),
                    child: _buildPerfumeImage(p, 34),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.brand,
                          style: serifStyle(fontSize: 12, italic: true),
                        ),
                        Text(
                          p.name,
                          style: arabicStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap:
                        widget.onAddToCollection == null ||
                            _addingPerfumeId != null
                        ? null
                        : () async {
                            final rowId = p.id.isNotEmpty ? p.id : p.name;
                            setState(() => _addingPerfumeId = rowId);
                            try {
                              await widget.onAddToCollection!(p);
                            } finally {
                              if (mounted) {
                                setState(() => _addingPerfumeId = null);
                              }
                            }
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [kGoldLight, kGold],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child:
                          _addingPerfumeId == (p.id.isNotEmpty ? p.id : p.name)
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: kOud,
                              ),
                            )
                          : Text(
                              context.t('Add'),
                              style: arabicStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: kOud,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPerfumeImage(Perfume p, double fallbackSize) {
    final imageUrl = p.imageUrl ?? p.fallbackImageUrl;
    if (imageUrl == null) {
      return Center(
        child: BottleIcon(color: p.accent, size: fallbackSize),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(5),
      child: PerfumeImage(
        primaryUrl: imageUrl,
        fallbackUrl: p.fallbackImageUrl,
        fallbackColor: p.accent,
        fit: BoxFit.contain,
        iconSize: fallbackSize,
      ),
    );
  }

  bool _matchesPerfumeSearch(Perfume perfume, String query) {
    final tokens = query
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.length >= 2)
        .toList(growable: false);
    if (tokens.isEmpty) return true;

    final searchable = [
      perfume.name,
      perfume.brand,
      perfume.gender ?? '',
      ...perfume.accords,
      ...perfume.topNotes.map((note) => note.name),
      ...perfume.heartNotes.map((note) => note.name),
      ...perfume.baseNotes.map((note) => note.name),
    ].map((value) => value.toLowerCase()).join(' ');

    return tokens.every(searchable.contains);
  }

  Widget _buildAICameraTab() {
    final hasResult =
        _aiMatches.isNotEmpty ||
        _aiError != null ||
        (_aiDetectedBrand?.isNotEmpty ?? false) ||
        (_aiDetectedName?.isNotEmpty ?? false);
    return Column(
      children: [
        if (!hasResult && !_aiIdentifying) ...[
          const SizedBox(height: 40),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(color: kGoldPale, shape: BoxShape.circle),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 44,
              color: kGold,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.t('Identify perfume by photo'),
            style: arabicStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: kEspresso,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              context.t(
                'Take a photo of the bottle or box and AI will find it in your database.',
              ),
              textAlign: TextAlign.center,
              style: arabicStyle(fontSize: 14, color: kWarmGray),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _aiButton(
                icon: Icons.camera_alt_rounded,
                label: context.t('Camera'),
                onTap: widget.onIdentifyByImage == null
                    ? null
                    : () => _pickImage(ImageSource.camera),
              ),
              const SizedBox(width: 16),
              _aiButton(
                icon: Icons.photo_library_rounded,
                label: context.t('Gallery'),
                onTap: widget.onIdentifyByImage == null
                    ? null
                    : () => _pickImage(ImageSource.gallery),
              ),
            ],
          ),
        ],
        if (_aiIdentifying) ...[
          const SizedBox(height: 60),
          const Center(
            child: SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(strokeWidth: 3, color: kGold),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.t('Analyzing photo...'),
            textAlign: TextAlign.center,
            style: arabicStyle(fontSize: 15, color: kWarmGray),
          ),
        ],
        if (_aiError != null) ...[
          const SizedBox(height: 40),
          const Icon(Icons.error_outline, size: 40, color: kSand),
          const SizedBox(height: 12),
          Text(
            context.t('Could not identify. Try a clearer photo.'),
            textAlign: TextAlign.center,
            style: arabicStyle(fontSize: 14, color: kWarmGray),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _resetAI,
            icon: const Icon(Icons.refresh_rounded, size: 16, color: kOud),
            label: Text(
              context.t('Try again'),
              style: arabicStyle(fontSize: 13, color: kOud),
            ),
          ),
        ],
        if (_aiMatches.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: kGoldPale,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: kGold, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${context.t('Detected')}: ${_aiDetectedBrand ?? ''} – ${_aiDetectedName ?? ''}',
                    style: arabicStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kOud,
                    ),
                  ),
                ),
                if (_aiConfidence == 'high')
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      context.t('High confidence'),
                      style: arabicStyle(
                        fontSize: 10,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ..._aiMatches.map((p) => _buildAIResultCard(p)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _resetAI,
            icon: const Icon(Icons.camera_alt_rounded, size: 16, color: kOud),
            label: Text(
              context.t('Take another photo'),
              style: arabicStyle(fontSize: 13, color: kOud),
            ),
          ),
        ],
        if (_aiDetectedBrand?.isNotEmpty == true &&
            _aiMatches.isEmpty &&
            _aiError == null) ...[
          const SizedBox(height: 40),
          const Icon(Icons.search_off_rounded, size: 40, color: kSand),
          const SizedBox(height: 12),
          Text(
            context.t(
              'AI detected the brand but could not find a match in your database.',
            ),
            textAlign: TextAlign.center,
            style: arabicStyle(fontSize: 14, color: kWarmGray),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _resetAI,
            icon: const Icon(Icons.refresh_rounded, size: 16, color: kOud),
            label: Text(
              context.t('Try again'),
              style: arabicStyle(fontSize: 13, color: kOud),
            ),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _aiButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: kCardShadow,
          border: Border.all(color: const Color(0xFFE5DDD4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: kGold),
            const SizedBox(height: 8),
            Text(
              label,
              style: arabicStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIResultCard(Perfume p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: widget.onPerfumeTap == null
            ? null
            : () => widget.onPerfumeTap!(p),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: kCardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: [kGoldPale, Colors.white],
                  ),
                ),
                child: _buildPerfumeImage(p, 34),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.brand,
                      style: serifStyle(fontSize: 12, italic: true),
                    ),
                    Text(
                      p.name,
                      style: arabicStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap:
                    widget.onAddToCollection == null || _addingPerfumeId != null
                    ? null
                    : () async {
                        final rowId = p.id.isNotEmpty ? p.id : p.name;
                        setState(() => _addingPerfumeId = rowId);
                        try {
                          await widget.onAddToCollection!(p);
                          if (mounted) widget.onClose();
                        } finally {
                          if (mounted) setState(() => _addingPerfumeId = null);
                        }
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [kGoldLight, kGold]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _addingPerfumeId == (p.id.isNotEmpty ? p.id : p.name)
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: kOud,
                          ),
                        )
                      : Text(
                          context.t('Add'),
                          style: arabicStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: kOud,
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

  Widget _buildManualTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(context.t('Perfume name')),
        _textField(context.t('Example: Aventus'), controller: _nameCtrl),
        const SizedBox(height: 12),
        _fieldLabel(context.t('Concentration')),
        Wrap(
          spacing: 6,
          children: ['Parfum', 'EDP', 'EDT', 'Oil perfume'].map((c) {
            final active = c == _concentration;
            return GestureDetector(
              onTap: () => setState(() => _concentration = c),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: active ? kOud : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: active ? kOud : const Color(0xFFE5DDD4),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  context.t(c),
                  style: arabicStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                    color: active ? Colors.white : kWarmGray,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        _fieldLabel(context.t('Source')),
        Wrap(
          spacing: 6,
          children: ['Purchase', 'Gift', 'Sample', 'Alternative'].map((s) {
            final active = s == _source;
            return GestureDetector(
              onTap: () => setState(() => _source = s),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: active ? kGoldPale : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: active ? kGold : const Color(0xFFE5DDD4),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  context.t(s),
                  style: arabicStyle(
                    fontSize: 13,
                    color: active ? kOud : kWarmGray,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        _fieldLabel(context.t('Price (SAR)')),
        _textField('0', isNumber: true, controller: _priceCtrl),
        const SizedBox(height: 12),
        _fieldLabel(context.t('Notes')),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _notes.map((n) {
            final sel = _selectedNotes.contains(n);
            return GestureDetector(
              onTap: () => setState(
                () => sel ? _selectedNotes.remove(n) : _selectedNotes.add(n),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: sel ? kOud : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: sel ? kOud : const Color(0xFFE5DDD4),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  context.t(n),
                  style: arabicStyle(
                    fontSize: 12,
                    color: sel ? Colors.white : kWarmGray,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _fieldLabel(context.t('Your personal notes')),
        TextField(
          controller: _personalNotesCtrl,
          textDirection: Directionality.of(context),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: context.t('Gift from my wife on Eid 2024...'),
            hintStyle: arabicStyle(fontSize: 14, color: kSand),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE5DDD4),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE5DDD4),
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildManualSubmitButton(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildManualSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saving ? null : _submitManual,
        style: ElevatedButton.styleFrom(
          backgroundColor: kGold,
          foregroundColor: kOud,
          disabledBackgroundColor: kGold.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 6,
        ),
        child: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: kOud),
              )
            : Text(
                AppLocalizations.of(context).addToCollection,
                style: arabicStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kOud,
                ),
              ),
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(label, style: arabicStyle(fontSize: 12, color: kWarmGray)),
    );
  }

  Widget _textField(
    String hint, {
    bool isNumber = false,
    TextEditingController? controller,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: TextField(
        controller: controller,
        textDirection: Directionality.of(context),
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: arabicStyle(fontSize: 14, color: kSand),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5DDD4), width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5DDD4), width: 1.5),
          ),
          contentPadding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        ),
      ),
    );
  }
}
