import 'package:flutter/material.dart';
import '../utils/constants.dart';

class CameroonLocationData {
  static const List<Map<String, String>> locations = [
    // ─── YAOUNDÉ ─────────────────────────────────────────────────────────────
    {
      'name': 'Quartier Bastos',
      'city': 'Yaoundé',
      'landmark': 'Ambassades, Mini-Ferme, Carrefour Bastos',
      'fullAddress': 'Quartier Bastos, Yaoundé, Cameroon',
      'category': 'Residential / Diplomatic',
      'type': 'residential',
    },
    {
      'name': 'Carrefour Warda',
      'city': 'Yaoundé',
      'landmark': 'Centre-ville, Boulevard du 20 Mai, Warda',
      'fullAddress': 'Carrefour Warda, Centre-ville, Yaoundé, Cameroon',
      'category': 'Downtown / Commercial',
      'type': 'commercial',
    },
    {
      'name': 'Marché Mokolo',
      'city': 'Yaoundé',
      'landmark': 'Grand Marché Mokolo, Sapeurs-Pompiers',
      'fullAddress': 'Marché Mokolo, Yaoundé, Cameroon',
      'category': 'Market / Commercial',
      'type': 'market',
    },
    {
      'name': 'Melen / CHU',
      'city': 'Yaoundé',
      'landmark': 'Centre Hospitalier Universitaire (CHU), Melen',
      'fullAddress': 'Melen, Proche CHU, Yaoundé, Cameroon',
      'category': 'Hospital / Medical Hub',
      'type': 'hospital',
    },
    {
      'name': 'Omnisports / Ahmadou Ahidjo',
      'city': 'Yaoundé',
      'landmark': 'Stade Ahmadou Ahidjo, Carrefour Mobil Omnisports',
      'fullAddress': 'Quartier Omnisports, Yaoundé, Cameroon',
      'category': 'Sports Hub / Quarter',
      'type': 'landmark',
    },
    {
      'name': 'Quartier Essos',
      'city': 'Yaoundé',
      'landmark': 'Carrefour Essos, Hôpital Jamot, Coron',
      'fullAddress': 'Quartier Essos, Yaoundé, Cameroon',
      'category': 'Quarter',
      'type': 'residential',
    },
    {
      'name': 'Emana',
      'city': 'Yaoundé',
      'landmark': 'Tradex Emana, Borne 10 Emana',
      'fullAddress': 'Quartier Emana, Yaoundé, Cameroon',
      'category': 'Quarter',
      'type': 'residential',
    },
    {
      'name': 'Rond-Point Nlongkak',
      'city': 'Yaoundé',
      'landmark': 'Pharmacie Nlongkak, Carrefour Nlongkak',
      'fullAddress': 'Rond-Point Nlongkak, Yaoundé, Cameroon',
      'category': 'Central Hub',
      'type': 'landmark',
    },
    {
      'name': 'Biyem-Assi',
      'city': 'Yaoundé',
      'landmark': 'Rond-Point Express, Carrefour Acacias, Super Supérette',
      'fullAddress': 'Biyem-Assi, Rond-Point Express, Yaoundé, Cameroon',
      'category': 'Quarter',
      'type': 'residential',
    },
    {
      'name': 'Mendong',
      'city': 'Yaoundé',
      'landmark': 'Camp SIC Mendong, Gendarmerie Mendong',
      'fullAddress': 'Mendong, Yaoundé, Cameroon',
      'category': 'Quarter',
      'type': 'residential',
    },
    {
      'name': 'Ngousso / Hôpital Général',
      'city': 'Yaoundé',
      'landmark': 'Hôpital Général de Yaoundé, Carrefour Ngousso',
      'fullAddress': 'Ngousso, Hôpital Général, Yaoundé, Cameroon',
      'category': 'Hospital / Medical Hub',
      'type': 'hospital',
    },
    {
      'name': 'Odza',
      'city': 'Yaoundé',
      'landmark': 'Carrefour Borne 10, Koweit City, Odza',
      'fullAddress': 'Odza, Yaoundé, Cameroon',
      'category': 'Quarter',
      'type': 'residential',
    },
    {
      'name': 'Mvan',
      'city': 'Yaoundé',
      'landmark': 'Gare Routière de Mvan, Agences de Voyages',
      'fullAddress': 'Mvan, Yaoundé, Cameroon',
      'category': 'Transport Hub',
      'type': 'transport',
    },
    {
      'name': 'Ahala',
      'city': 'Yaoundé',
      'landmark': 'Barrière Ahala, Sortie Sud',
      'fullAddress': 'Ahala, Yaoundé, Cameroon',
      'category': 'Quarter',
      'type': 'residential',
    },
    {
      'name': 'Simbock',
      'city': 'Yaoundé',
      'landmark': 'Carrefour Simbock, Vers Mendong',
      'fullAddress': 'Simbock, Yaoundé, Cameroon',
      'category': 'Quarter',
      'type': 'residential',
    },
    {
      'name': 'Obobogo',
      'city': 'Yaoundé',
      'landmark': 'Obobogo Rails, Carrefour Obobogo',
      'fullAddress': 'Obobogo, Yaoundé, Cameroon',
      'category': 'Quarter',
      'type': 'residential',
    },
    {
      'name': 'Tsinga',
      'city': 'Yaoundé',
      'landmark': 'Grande Mosquée de Tsinga, FECAFOOT',
      'fullAddress': 'Tsinga, Yaoundé, Cameroon',
      'category': 'Quarter',
      'type': 'residential',
    },
    {
      'name': 'Madagascar',
      'city': 'Yaoundé',
      'landmark': 'Marché Madagascar, Yaoundé',
      'fullAddress': 'Madagascar, Yaoundé, Cameroon',
      'category': 'Market / Quarter',
      'type': 'market',
    },
    {
      'name': 'Camp Sic Messa',
      'city': 'Yaoundé',
      'landmark': 'Hôpital Central de Yaoundé, Camp SIC',
      'fullAddress': 'Messa, Yaoundé, Cameroon',
      'category': 'Hospital / Quarter',
      'type': 'hospital',
    },
    {
      'name': 'Nsam',
      'city': 'Yaoundé',
      'landmark': 'Brasseries du Cameroun, Nsam Escale',
      'fullAddress': 'Nsam, Yaoundé, Cameroon',
      'category': 'Quarter',
      'type': 'residential',
    },
    {
      'name': 'Etoudi',
      'city': 'Yaoundé',
      'landmark': 'Palais de l’Unité, Carrefour Présidence',
      'fullAddress': 'Etoudi, Yaoundé, Cameroon',
      'category': 'Administrative',
      'type': 'landmark',
    },
    {
      'name': 'Santa Barbara',
      'city': 'Yaoundé',
      'landmark': 'Santa Barbara, Proche Bastos',
      'fullAddress': 'Santa Barbara, Yaoundé, Cameroon',
      'category': 'Quarter',
      'type': 'residential',
    },
    {
      'name': 'Soa',
      'city': 'Yaoundé / Soa',
      'landmark': 'Université de Yaoundé II Soa, Campus',
      'fullAddress': 'Soa, Université de Yaoundé II, Cameroon',
      'category': 'University Hub',
      'type': 'university',
    },
    {
      'name': 'Obili',
      'city': 'Yaoundé',
      'landmark': 'Carrefour Obili, Proche Ngoa-Ekellé',
      'fullAddress': 'Obili, Yaoundé, Cameroon',
      'category': 'Student Hub',
      'type': 'university',
    },
    {
      'name': 'Ngoa-Ekellé',
      'city': 'Yaoundé',
      'landmark': 'Université de Yaoundé I, Château Ngoa-Ekellé',
      'fullAddress': 'Ngoa-Ekellé, Yaoundé, Cameroon',
      'category': 'University Hub',
      'type': 'university',
    },
    {
      'name': 'Kondengui',
      'city': 'Yaoundé',
      'landmark': 'Marché Kondengui, Carrefour Marché',
      'fullAddress': 'Kondengui, Yaoundé, Cameroon',
      'category': 'Quarter',
      'type': 'residential',
    },
    {
      'name': 'Cité Verte',
      'city': 'Yaoundé',
      'landmark': 'Grand Ensemble Cité Verte',
      'fullAddress': 'Cité Verte, Yaoundé, Cameroon',
      'category': 'Quarter',
      'type': 'residential',
    },
    {
      'name': 'Olembe',
      'city': 'Yaoundé',
      'landmark': 'Complexe Sportif Paul Biya d’Olembe',
      'fullAddress': 'Olembe, Yaoundé, Cameroon',
      'category': 'Sports / Quarter',
      'type': 'landmark',
    },

    // ─── DOUALA ──────────────────────────────────────────────────────────────
    {
      'name': 'Akwa',
      'city': 'Douala',
      'landmark': 'Boulevard de la Liberté, Salle des Fêtes Akwa',
      'fullAddress': 'Akwa, Douala, Cameroon',
      'category': 'Commercial & Downtown',
      'type': 'commercial',
    },
    {
      'name': 'Bonanjo',
      'city': 'Douala',
      'landmark': 'Place du Gouvernement, Banques, Quartier Administratif',
      'fullAddress': 'Bonanjo, Douala, Cameroon',
      'category': 'Administrative & Business',
      'type': 'landmark',
    },
    {
      'name': 'Bonapriso',
      'city': 'Douala',
      'landmark': 'Rue des Palmiers, Hydrocarbures, Bonapriso',
      'fullAddress': 'Bonapriso, Douala, Cameroon',
      'category': 'Residential / Upscale',
      'type': 'residential',
    },
    {
      'name': 'Bali',
      'city': 'Douala',
      'landmark': 'Rue Manga Bell, Marché Bali',
      'fullAddress': 'Quartier Bali, Douala, Cameroon',
      'category': 'Quarter',
      'type': 'residential',
    },
    {
      'name': 'Rond-Point Deido',
      'city': 'Douala',
      'landmark': 'Rond-Point Deido, Grand Moulin',
      'fullAddress': 'Deido, Douala, Cameroon',
      'category': 'Central Hub',
      'type': 'landmark',
    },
    {
      'name': 'Makepe',
      'city': 'Douala',
      'landmark': 'Carrefour Rhône-Poulenc, Makepe Missoke',
      'fullAddress': 'Makepe, Douala, Cameroon',
      'category': 'Quarter',
      'type': 'residential',
    },
    {
      'name': 'Logpom',
      'city': 'Douala',
      'landmark': 'Carrefour Bassong, Logpom',
      'fullAddress': 'Logpom, Douala, Cameroon',
      'category': 'Quarter',
      'type': 'residential',
    },
    {
      'name': 'Bonamoussadi',
      'city': 'Douala',
      'landmark': 'Carrefour Denver, Rond-Point Maetur',
      'fullAddress': 'Bonamoussadi, Douala, Cameroon',
      'category': 'Quarter',
      'type': 'residential',
    },
    {
      'name': 'Kotto',
      'city': 'Douala',
      'landmark': 'Kotto Blocs, Carrefour Antenne Kotto',
      'fullAddress': 'Kotto, Douala, Cameroon',
      'category': 'Quarter',
      'type': 'residential',
    },
    {
      'name': 'Ndokoti',
      'city': 'Douala',
      'landmark': 'Carrefour Ndokoti, Bassa',
      'fullAddress': 'Carrefour Ndokoti, Douala, Cameroon',
      'category': 'Commercial / Hub',
      'type': 'commercial',
    },
    {
      'name': 'PK14',
      'city': 'Douala',
      'landmark': 'Campus Universitaire PK14 Douala',
      'fullAddress': 'PK14, Douala, Cameroon',
      'category': 'University Hub',
      'type': 'university',
    },
    {
      'name': 'Bépanda',
      'city': 'Douala',
      'landmark': 'Stade de la Réunification Bépanda',
      'fullAddress': 'Bépanda, Douala, Cameroon',
      'category': 'Quarter',
      'type': 'residential',
    },
    {
      'name': 'New-Bell',
      'city': 'Douala',
      'landmark': 'Marché Central New-Bell, Carrefour Shell',
      'fullAddress': 'New-Bell, Douala, Cameroon',
      'category': 'Market / Quarter',
      'type': 'market',
    },
    {
      'name': 'Bonabéri',
      'city': 'Douala',
      'landmark': 'Gare Routière Bonabéri, Ancienne Route',
      'fullAddress': 'Bonabéri, Douala, Cameroon',
      'category': 'Transport / Quarter',
      'type': 'transport',
    },
    {
      'name': 'Yassa / Japoma',
      'city': 'Douala',
      'landmark': 'Stade de Japoma, Entrée Est Douala',
      'fullAddress': 'Yassa - Japoma, Douala, Cameroon',
      'category': 'Quarter',
      'type': 'residential',
    },

    // ─── BUEA & LIMBE ─────────────────────────────────────────────────────────
    {
      'name': 'Molyko',
      'city': 'Buea',
      'landmark': 'University of Buea (UB) Junction, Checkpoint Molyko',
      'fullAddress': 'Molyko, Buea, South West Region, Cameroon',
      'category': 'University Hub',
      'type': 'university',
    },
    {
      'name': 'Buea Town / Checkpoint',
      'city': 'Buea',
      'landmark': 'Clerks Quarters, Mount Camel, Buea Town',
      'fullAddress': 'Buea Town, South West Region, Cameroon',
      'category': 'Quarter',
      'type': 'residential',
    },
    {
      'name': 'Mile 17 Motor Park',
      'city': 'Buea',
      'landmark': 'Mile 17 Roundabout & Bus Station',
      'fullAddress': 'Mile 17, Buea, South West Region, Cameroon',
      'category': 'Transport Hub',
      'type': 'transport',
    },
    {
      'name': 'Down Beach & Half Mile',
      'city': 'Limbe',
      'landmark': 'Down Beach, Limbe Botanical Garden',
      'fullAddress': 'Down Beach, Limbe, South West Region, Cameroon',
      'category': 'Coastal Hub',
      'type': 'landmark',
    },
    {
      'name': 'Mile 4 Limbe',
      'city': 'Limbe',
      'landmark': 'Mile 4 Junction, Limbe',
      'fullAddress': 'Mile 4, Limbe, South West Region, Cameroon',
      'category': 'Quarter',
      'type': 'residential',
    },

    // ─── OTHER REGIONS ───────────────────────────────────────────────────────
    {
      'name': 'Carrefour Total Bafoussam',
      'city': 'Bafoussam',
      'landmark': 'Marché B, Carrefour Total, Djeleng',
      'fullAddress': 'Carrefour Total, Bafoussam, West Region, Cameroon',
      'category': 'Central Hub',
      'type': 'landmark',
    },
    {
      'name': 'Commercial Avenue Bamenda',
      'city': 'Bamenda',
      'landmark': 'Commercial Avenue, Food Market, Up Station',
      'fullAddress': 'Commercial Avenue, Bamenda, North West Region, Cameroon',
      'category': 'Commercial Hub',
      'type': 'commercial',
    },
    {
      'name': 'Dschang Centre',
      'city': 'Dschang',
      'landmark': 'Université de Dschang, Foréké-Dschang',
      'fullAddress': 'Centre-Ville, Dschang, West Region, Cameroon',
      'category': 'University Hub',
      'type': 'university',
    },
    {
      'name': 'Plateau Garoua',
      'city': 'Garoua',
      'landmark': 'Grand Marché Garoua, Poumpouré',
      'fullAddress': 'Plateau, Garoua, North Region, Cameroon',
      'category': 'City Centre',
      'type': 'landmark',
    },
    {
      'name': 'Domayo Maroua',
      'city': 'Maroua',
      'landmark': 'Pont Vert, Domayo, Pitoaré',
      'fullAddress': 'Domayo, Maroua, Far North Region, Cameroon',
      'category': 'City Centre',
      'type': 'landmark',
    },
    {
      'name': 'Baladji Ngaoundéré',
      'city': 'Ngaoundéré',
      'landmark': 'Grand Marché, Bois des Singes',
      'fullAddress': 'Baladji, Ngaoundéré, Adamawa, Cameroon',
      'category': 'City Centre',
      'type': 'landmark',
    },
    {
      'name': 'Grand Batanga & Plage',
      'city': 'Kribi',
      'landmark': 'Mboamanga, Plage de Kribi, Port de Kribi',
      'fullAddress': 'Kribi Centre & Plage, South Region, Cameroon',
      'category': 'Coastal Hub',
      'type': 'landmark',
    },
  ];
}

class LocationAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final ValueChanged<String>? onLocationSelected;
  final bool showQuickChips;

  const LocationAutocompleteField({
    super.key,
    required this.controller,
    this.label = 'Delivery Dropoff Address',
    this.hint = 'Start typing quarter, street or landmark (e.g. Bastos, Warda, Akwa)...',
    this.onLocationSelected,
    this.showQuickChips = true,
  });

  @override
  State<LocationAutocompleteField> createState() => _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState extends State<LocationAutocompleteField> {
  final FocusNode _focusNode = FocusNode();
  List<Map<String, String>> _filteredLocations = [];
  bool _showSuggestions = false;
  String? _selectedSuggestionName;

  // Top quick picks across Cameroon
  final List<Map<String, String>> _quickPicks = [
    {'name': 'Bastos', 'full': 'Quartier Bastos, Yaoundé, Cameroon', 'city': 'Yaoundé'},
    {'name': 'Carrefour Warda', 'full': 'Carrefour Warda, Centre-ville, Yaoundé, Cameroon', 'city': 'Yaoundé'},
    {'name': 'Marché Mokolo', 'full': 'Marché Mokolo, Yaoundé, Cameroon', 'city': 'Yaoundé'},
    {'name': 'Akwa', 'full': 'Akwa, Douala, Cameroon', 'city': 'Douala'},
    {'name': 'Bonanjo', 'full': 'Bonanjo, Douala, Cameroon', 'city': 'Douala'},
    {'name': 'Bonapriso', 'full': 'Bonapriso, Douala, Cameroon', 'city': 'Douala'},
    {'name': 'Molyko', 'full': 'Molyko, Buea, South West Region, Cameroon', 'city': 'Buea'},
    {'name': 'Melen / CHU', 'full': 'Melen, Proche CHU, Yaoundé, Cameroon', 'city': 'Yaoundé'},
    {'name': 'Omnisports', 'full': 'Quartier Omnisports, Yaoundé, Cameroon', 'city': 'Yaoundé'},
    {'name': 'Biyem-Assi', 'full': 'Biyem-Assi, Rond-Point Express, Yaoundé, Cameroon', 'city': 'Yaoundé'},
  ];

  @override
  void initState() {
    super.initState();
    _filterLocations(widget.controller.text);

    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _filterLocations(widget.controller.text);
        setState(() => _showSuggestions = true);
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _filterLocations(widget.controller.text);
  }

  void _filterLocations(String query) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) {
      setState(() {
        _filteredLocations = CameroonLocationData.locations.take(8).toList();
      });
      return;
    }

    final matches = CameroonLocationData.locations.where((loc) {
      final name = (loc['name'] ?? '').toLowerCase();
      final city = (loc['city'] ?? '').toLowerCase();
      final landmark = (loc['landmark'] ?? '').toLowerCase();
      final full = (loc['fullAddress'] ?? '').toLowerCase();
      final cat = (loc['category'] ?? '').toLowerCase();

      return name.contains(cleanQuery) ||
          city.contains(cleanQuery) ||
          landmark.contains(cleanQuery) ||
          full.contains(cleanQuery) ||
          cat.contains(cleanQuery);
    }).toList();

    setState(() {
      _filteredLocations = matches;
      if (matches.isNotEmpty && !_showSuggestions && _focusNode.hasFocus) {
        _showSuggestions = true;
      }
    });
  }

  void _selectLocation(Map<String, String> loc) {
    final full = loc['fullAddress'] ?? loc['name'] ?? '';
    widget.controller.text = full;
    widget.controller.selection = TextSelection.fromPosition(TextPosition(offset: full.length));
    setState(() {
      _selectedSuggestionName = loc['name'];
      _showSuggestions = false;
    });
    _focusNode.unfocus();
    if (widget.onLocationSelected != null) {
      widget.onLocationSelected!(full);
    }
  }

  void _useCurrentGpsLocation() {
    const gpsLocation = 'Quartier Bastos (GPS Pinpoint), Yaoundé, Cameroon';
    widget.controller.text = gpsLocation;
    widget.controller.selection = TextSelection.fromPosition(const TextPosition(offset: gpsLocation.length));
    setState(() {
      _selectedSuggestionName = 'GPS Bastos';
      _showSuggestions = false;
    });
    _focusNode.unfocus();
    if (widget.onLocationSelected != null) {
      widget.onLocationSelected!(gpsLocation);
    }
  }

  IconData _getCategoryIcon(String? type) {
    switch (type) {
      case 'hospital':
        return Icons.local_hospital;
      case 'market':
        return Icons.shopping_basket;
      case 'commercial':
        return Icons.storefront;
      case 'university':
        return Icons.school;
      case 'transport':
        return Icons.directions_bus;
      case 'landmark':
        return Icons.flag;
      default:
        return Icons.location_city;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Quick Location Chips for 1-tap autocomplete
        if (widget.showQuickChips) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '⚡ Quick Quarters & Hubs (Tap to fill):',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
              InkWell(
                onTap: _useCurrentGpsLocation,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: const [
                      Icon(Icons.my_location, size: 12, color: Color(0xFF2563EB)),
                      SizedBox(width: 3),
                      Text('GPS Current', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _quickPicks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (ctx, idx) {
                final p = _quickPicks[idx];
                final isSelected = widget.controller.text == p['full'];
                return ActionChip(
                  backgroundColor: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                  avatar: Icon(
                    Icons.location_on,
                    size: 14,
                    color: isSelected ? Colors.white : AppColors.primary,
                  ),
                  label: Text(
                    '${p['name']} (${p['city']})',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : AppColors.textDark,
                    ),
                  ),
                  onPressed: () {
                    final target = CameroonLocationData.locations.firstWhere(
                      (l) => l['fullAddress'] == p['full'] || l['name'] == p['name'],
                      orElse: () => {'fullAddress': p['full']!, 'name': p['name']!, 'city': p['city']!},
                    );
                    _selectLocation(target);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Input Field
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          onTap: () {
            setState(() => _showSuggestions = true);
          },
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
            prefixIcon: const Icon(Icons.location_on_outlined, color: Colors.blue),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.controller.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                    onPressed: () {
                      widget.controller.clear();
                      _filterLocations('');
                      setState(() => _showSuggestions = true);
                    },
                  ),
                IconButton(
                  icon: Icon(
                    _showSuggestions ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.primary,
                  ),
                  onPressed: () {
                    setState(() => _showSuggestions = !_showSuggestions);
                  },
                ),
              ],
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),

        // Live Auto-suggest Dropdown Overlay / Proposals List
        if (_showSuggestions && _filteredLocations.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 230),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.35), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.lightGreen.withOpacity(0.5),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.travel_explore, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Proposals (${_filteredLocations.length} locations found)',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                          ),
                        ],
                      ),
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
                    padding: EdgeInsets.zero,
                    itemCount: _filteredLocations.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (ctx, idx) {
                      final loc = _filteredLocations[idx];
                      final name = loc['name'] ?? '';
                      final city = loc['city'] ?? '';
                      final landmark = loc['landmark'] ?? '';
                      final category = loc['category'] ?? '';
                      final icon = _getCategoryIcon(loc['type']);

                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.lightGreen,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, size: 18, color: AppColors.primary),
                        ),
                        title: Row(
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Text(
                                city,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          landmark.isNotEmpty ? landmark : category,
                          style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Select', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                        ),
                        onTap: () => _selectLocation(loc),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],

        if (_selectedSuggestionName != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.check_circle, size: 14, color: AppColors.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Selected: ${widget.controller.text}',
                  style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
