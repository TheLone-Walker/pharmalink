import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';
import 'pharmacy_detail_screen.dart';

class SearchMedicationScreen extends StatefulWidget {
  final String? initialQuery;
  const SearchMedicationScreen({super.key, this.initialQuery});

  @override
  State<SearchMedicationScreen> createState() => _SearchMedicationScreenState();
}

class _SearchMedicationScreenState extends State<SearchMedicationScreen> {
  final _searchCtrl = TextEditingController();
  final _api = ApiService();

  GoogleMapController? _mapCtrl;
  final LatLng _userPos = const LatLng(3.8480, 11.5021); // Yaoundé reference
  final Set<Marker> _markers = {};

  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _suggestions = [];
  bool _loading = false;
  bool _isMapView = false;
  bool _showSuggestions = true;
  String _selectedCategory = 'All';
  Map<String, dynamic>? _selectedMapPharmacy;

  // Popular & accessible searches
  final List<Map<String, String>> _popularSearches = [
    {'name': 'Artemether 80mg', 'icon': '🦟', 'tag': 'Antimalarials'},
    {'name': 'Artemether-Lumefantrine (Coartem)', 'icon': '🦟', 'tag': 'Antimalarials'},
    {'name': 'Paracetamol 500mg', 'icon': '💊', 'tag': 'Pain Relief'},
    {'name': 'Amoxicillin 500mg', 'icon': '🦠', 'tag': 'Antibiotics'},
    {'name': 'Ibuprofen 400mg', 'icon': '💊', 'tag': 'Anti-inflammatory'},
    {'name': 'Omeprazole 20mg', 'icon': '🛡️', 'tag': 'Gastric/Ulcer'},
    {'name': 'Metformin 500mg', 'icon': '🩸', 'tag': 'Diabetes'},
    {'name': 'Cetirizine 10mg', 'icon': '🌿', 'tag': 'Allergies'},
  ];

  final List<String> _categories = [
    'All',
    'Antimalarials',
    'Pain Relief',
    'Antibiotics',
    'Anti-inflammatory',
    'Gastric',
    'Diabetes',
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _fetchSuggestions('');

    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchCtrl.text = widget.initialQuery!;
      _performSearch(widget.initialQuery!);
    } else {
      _performSearch('Artemether'); // default popular antimalarial search
    }
  }

  @override
  void dispose() {
    _mapCtrl?.dispose();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.trim();
    if (query.isNotEmpty) {
      setState(() => _showSuggestions = true);
      _fetchSuggestions(query);
    } else {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    // 1. Instant local predictive matches
    final localMatches = AppConstants.cameroonMedications
        .where((m) => m.toLowerCase().contains(query.toLowerCase()))
        .map((m) => {
              'name': m,
              'category': m.toLowerCase().contains('artemether') ? 'Antimalarials' : 'Medication',
              'icon': m.toLowerCase().contains('artemether') ? '🦟' : '💊',
            })
        .take(6)
        .toList();

    if (mounted && localMatches.isNotEmpty) {
      setState(() => _suggestions = localMatches);
    }

    // 2. Fetch server matches
    try {
      final res = await _api.get('/medications/suggestions', params: {'q': query});
      final list = (res.data['data'] as List? ?? []).cast<Map<String, dynamic>>();
      if (mounted && list.isNotEmpty) {
        final existingNames = localMatches.map((e) => (e['name'] ?? '').toString().toLowerCase()).toSet();
        final combined = [...localMatches, ...list.where((s) => !existingNames.contains((s['name'] ?? '').toString().toLowerCase()))];
        setState(() => _suggestions = combined);
      }
    } catch (_) {}
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _loading = true;
      _showSuggestions = false;
      _selectedMapPharmacy = null;
    });

    try {
      final params = <String, dynamic>{
        'q': query,
        'lat': 3.8480,
        'lng': 11.5021,
      };
      if (_selectedCategory != 'All') {
        params['category'] = _selectedCategory;
      }

      final res = await _api.get('/medications/search', params: params);
      final list = (res.data['data'] as List? ?? []).cast<Map<String, dynamic>>();

      setState(() {
        _results = list;
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectSuggestion(String name) {
    _searchCtrl.text = name;
    _performSearch(name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Search Medications & Stock'),
        actions: [
          // View Toggle: List / Map
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.list, color: !_isMapView ? Colors.white : Colors.white60),
                  tooltip: 'List View',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _isMapView = false),
                ),
                IconButton(
                  icon: Icon(Icons.map_outlined, color: _isMapView ? Colors.white : Colors.white60),
                  tooltip: 'Map View',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _isMapView = true),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchHeader(),
          if (_showSuggestions && _suggestions.isNotEmpty) _buildAutoSuggestOverlay(),
          _buildCategoryChips(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _results.isEmpty
                    ? _buildEmptyOrPopular()
                    : _isMapView
                        ? _buildInteractiveMapView()
                        : _buildResultsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            onSubmitted: _performSearch,
            decoration: InputDecoration(
              hintText: 'Type drug name (e.g. Artemether, Paracetamol, Coartem)...',
              hintStyle: const TextStyle(color: Colors.black45, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: AppColors.primary),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {
                          _showSuggestions = false;
                        });
                      },
                    )
                  : const Icon(Icons.mic_none, color: AppColors.primary),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  // ─── AUTO-SUGGEST PROPOSALS AS YOU TYPE ─────────────────────────────────────
  Widget _buildAutoSuggestOverlay() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('💡 Suggested Medications (Tap to search):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                GestureDetector(
                  onTap: () => setState(() => _showSuggestions = false),
                  child: const Icon(Icons.close, size: 16, color: Colors.grey),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, idx) {
                final s = _suggestions[idx];
                final name = s['name'] ?? '';
                final cat = s['category'] ?? 'General';
                final icon = s['icon'] ?? '💊';

                return ListTile(
                  dense: true,
                  leading: Text(icon, style: const TextStyle(fontSize: 18)),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: Text(cat, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.primary),
                  onTap: () => _selectSuggestion(name),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, idx) {
          final cat = _categories[idx];
          final isSel = _selectedCategory == cat;
          return ChoiceChip(
            label: Text(
              cat == 'Antimalarials' ? '🦟 Antimalarials (Artemether)' : cat,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                color: isSel ? Colors.white : const Color(0xFF334155),
              ),
            ),
            selected: isSel,
            selectedColor: AppColors.primary,
            backgroundColor: Colors.white,
            side: BorderSide(color: isSel ? AppColors.primary : const Color(0xFFE2E8F0)),
            onSelected: (_) {
              setState(() => _selectedCategory = cat);
              _performSearch(_searchCtrl.text.isNotEmpty ? _searchCtrl.text : (cat == 'Antimalarials' ? 'Artemether' : ''));
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyOrPopular() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Access & Popular Drugs:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _popularSearches.map((p) {
              return ActionChip(
                avatar: Text(p['icon']!, style: const TextStyle(fontSize: 14)),
                label: Text(p['name']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE2E8F0))),
                onPressed: () => _selectSuggestion(p['name']!),
              );
            }).toList(),
          ),
          const SizedBox(height: 30),
          Center(
            child: Column(
              children: const [
                Icon(Icons.medication_outlined, size: 48, color: AppColors.textGrey),
                SizedBox(height: 8),
                Text('Search any medication above to check live open pharmacy stocks and locations.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── LIST VIEW ─────────────────────────────────────────────────────────────
  Widget _buildResultsList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, idx) => _buildMedicationPharmacyCard(_results[idx]),
    );
  }

  Widget _buildMedicationPharmacyCard(Map<String, dynamic> med) {
    final pharmacy = med['pharmacy'] as Map<String, dynamic>? ?? {};
    final pName = pharmacy['pharmacyName'] ?? 'Pharmacy';
    final pAddr = pharmacy['pharmacyAddress'] ?? 'Yaoundé, Cameroon';
    final isOpen = med['isOpen'] == true || pharmacy['isOpen'] == true;
    final distance = med['distanceKm'] ?? 1.5;
    final price = med['priceFcfa'] ?? 0;
    final stock = med['stockQuantity'] ?? 0;
    final isAntimalarial = (med['name'] ?? '').toString().toLowerCase().contains('artemether') || (med['category'] ?? '').toString().toLowerCase().contains('antimalarials');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isOpen ? AppColors.primary.withOpacity(0.3) : const Color(0xFFE5E7EB), width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Medication Name & Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.lightGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(isAntimalarial ? '🦟' : '💊', style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(med['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (med['requiresPrescription'] == true) ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: (med['requiresPrescription'] == true) ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                            ),
                          ),
                          child: Text(
                            (med['requiresPrescription'] == true) ? '📄 Prescription Req.' : '✅ OTC / Free Sale',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: (med['requiresPrescription'] == true) ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$price FCFA', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.primary)),
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                    child: Text('Stock: $stock', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF166534))),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Pharmacy Location & Status
          Row(
            children: [
              const Icon(Icons.storefront_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    Text(pAddr, style: const TextStyle(fontSize: 11, color: AppColors.textGrey), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isOpen ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isOpen ? '🟢 Open Now' : '🔴 Closed',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isOpen ? const Color(0xFF166534) : const Color(0xFF991B1B)),
                    ),
                  ),
                  Text('📍 $distance km', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Action Buttons: View on Map & Order Now
          Row(
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.location_on_outlined, size: 14, color: AppColors.primary),
                label: const Text('View on Map', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                onPressed: () {
                  setState(() {
                    _isMapView = true;
                    _selectedMapPharmacy = med;
                  });
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.shopping_bag_outlined, size: 14),
                  label: const Text('Order from Pharmacy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PharmacyDetailScreen(
                          pharmacyId: pharmacy['id'] ?? med['pharmacyId'] ?? '',
                          medicationId: med['id'] ?? '',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── LIVE INTERACTIVE GOOGLE MAP VIEW ──────────────────────────────────────
  Set<Marker> _getMapMarkers() {
    final Set<Marker> markers = {};

    // 1. Patient User Location Marker (Blue)
    markers.add(
      Marker(
        markerId: const MarkerId('user_location'),
        position: _userPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: '📍 Your Location (Yaoundé)'),
      ),
    );

    // 2. Pharmacy Markers for Searched Medication (Green / Selected Rose)
    for (int i = 0; i < _results.length; i++) {
      final med = _results[i];
      final ph = med['pharmacy'] ?? {};
      final lat = (ph['lat'] as num?)?.toDouble() ?? (3.8480 + (i + 1) * 0.007 * ((i % 2 == 0) ? 1 : -1));
      final lng = (ph['lng'] as num?)?.toDouble() ?? (11.5021 + (i + 1) * 0.006 * ((i % 3 == 0) ? 1 : -1));
      final pos = LatLng(lat, lng);

      final isSelected = _selectedMapPharmacy?['id'] == med['id'];
      final pharmName = ph['pharmacyName'] ?? 'Licensed Pharmacy';
      final price = med['priceFcfa'] ?? 0;
      final stock = med['stockQuantity'] ?? 10;

      markers.add(
        Marker(
          markerId: MarkerId('pharmacy_${med['id'] ?? i}'),
          position: pos,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isSelected ? BitmapDescriptor.hueRose : BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(
            title: '🏥 $pharmName',
            snippet: '${med['name']} • FCFA $price • In Stock ($stock)',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PharmacyDetailScreen(
                    pharmacyId: ph['id'] ?? med['pharmacyId'] ?? '',
                    medicationId: med['id'] ?? '',
                  ),
                ),
              );
            },
          ),
          onTap: () {
            setState(() => _selectedMapPharmacy = med);
            _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(pos, 15));
          },
        ),
      );
    }

    return markers;
  }

  Widget _buildInteractiveMapView() {
    final selected = _selectedMapPharmacy ?? (_results.isNotEmpty ? _results.first : null);
    final markers = _getMapMarkers();

    return Stack(
      children: [
        Positioned.fill(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _userPos,
              zoom: 13.5,
            ),
            markers: markers,
            onMapCreated: (ctrl) {
              _mapCtrl = ctrl;
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
          ),
        ),

        // Map Top Legend & Count Badge
        Positioned(
          top: 12,
          left: 14,
          right: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_results.length} Pharmacies with stock',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(color: Color(0xFF0284C7), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    const Text('You', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Selected Pharmacy Floating Bottom Card
        if (selected != null)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.primary, width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 16, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.lightGreen,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.local_pharmacy_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selected['pharmacy']?['pharmacyName'] ?? 'Licensed Pharmacy',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textDark),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              selected['name'] ?? '',
                              style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${selected['priceFcfa']} FCFA',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary),
                          ),
                          Text(
                            '📍 ${selected['distanceKm'] ?? '2.4'} km away',
                            style: const TextStyle(fontSize: 11, color: AppColors.textGrey, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.directions, color: AppColors.primary, size: 16),
                          label: const Text('Locate', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
                          onPressed: () {
                            final ph = selected['pharmacy'] ?? {};
                            final lat = (ph['lat'] as num?)?.toDouble() ?? 3.8480;
                            final lng = (ph['lng'] as num?)?.toDouble() ?? 11.5021;
                            _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16));
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 18),
                          label: Text(
                            'Order Now (${selected['priceFcfa']} FCFA)',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PharmacyDetailScreen(
                                  pharmacyId: selected['pharmacy']?['id'] ?? selected['pharmacyId'] ?? '',
                                  medicationId: selected['id'] ?? '',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
