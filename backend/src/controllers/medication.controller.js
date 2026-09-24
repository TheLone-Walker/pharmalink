const prisma = require('../config/db');

// Helper to check if pharmacy is open
function isPharmacyOpen(openingHours) {
  if (!openingHours) return true;
  const str = openingHours.toLowerCase().trim();
  if (str.includes('24/7') || str.includes('24h') || str.includes('always open')) return true;

  const now = new Date();
  const currentHour = now.getHours();
  const currentMinute = now.getMinutes();
  const currentTimeVal = currentHour * 60 + currentMinute;

  if (str.includes('8:00 am - 8:00 pm') || str.includes('08:00 - 20:00')) {
    return currentTimeVal >= 8 * 60 && currentTimeVal <= 20 * 60;
  }
  if (str.includes('07:30 - 21:00') || str.includes('7:30 am - 9:00 pm')) {
    return currentTimeVal >= 7 * 60 + 30 && currentTimeVal <= 21 * 60;
  }

  return currentHour >= 7 && currentHour <= 22;
}

// Distance helper in km
function calculateDistance(lat1, lon1, lat2, lon2) {
  if (!lat1 || !lon1 || !lat2 || !lon2) return 1.5;
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;
  const distance = R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return parseFloat(distance.toFixed(1));
}

// Search medications with open pharmacy status and stock
const search = async (req, res, next) => {
  try {
    const { q, lat = 3.8480, lng = 11.5021, category } = req.query;

    const whereClause = {
      stockQuantity: { gt: 0 },
    };

    if (q && q.trim().length > 0) {
      whereClause.name = { contains: q.trim(), mode: 'insensitive' };
    }

    if (category && category.trim().length > 0 && category !== 'All') {
      whereClause.category = { contains: category.trim(), mode: 'insensitive' };
    }

    const medications = await prisma.medication.findMany({
      where: whereClause,
      include: {
        pharmacy: {
          include: {
            user: { select: { name: true, phone: true, email: true } },
          },
        },
      },
      orderBy: { priceFcfa: 'asc' },
    });

    const enriched = medications.map((med) => {
      const pLat = med.pharmacy?.lat || (3.8480 + (Math.random() - 0.5) * 0.04);
      const pLng = med.pharmacy?.lng || (11.5021 + (Math.random() - 0.5) * 0.04);
      const userLat = parseFloat(lat) || 3.8480;
      const userLng = parseFloat(lng) || 11.5021;
      const distance = calculateDistance(userLat, userLng, pLat, pLng);
      const isOpen = isPharmacyOpen(med.pharmacy?.openingHours);

      return {
        id: med.id,
        name: med.name,
        description: med.description,
        priceFcfa: parseFloat(med.priceFcfa),
        stockQuantity: med.stockQuantity,
        category: med.category || 'General',
        requiresPrescription: med.requiresPrescription,
        imageUrl: med.imageUrl,
        distanceKm: distance,
        isOpen,
        pharmacyId: med.pharmacyId,
        pharmacy: {
          id: med.pharmacy?.id,
          pharmacyName: med.pharmacy?.pharmacyName || 'Pharmacy',
          pharmacyAddress: med.pharmacy?.pharmacyAddress || 'Yaoundé, Cameroon',
          openingHours: med.pharmacy?.openingHours || '08:00 - 20:00',
          isOpen,
          lat: pLat,
          lng: pLng,
          pharmacistName: med.pharmacy?.user?.name || 'Pharmacist',
          pharmacistPhone: med.pharmacy?.user?.phone || '+237 6xx xxx xxx',
        },
      };
    });

    // Sort: (1) Open now first, (2) Nearest distance, (3) Lowest price
    enriched.sort((a, b) => {
      if (b.isOpen !== a.isOpen) return (b.isOpen ? 1 : 0) - (a.isOpen ? 1 : 0);
      if (a.distanceKm !== b.distanceKm) return a.distanceKm - b.distanceKm;
      return a.priceFcfa - b.priceFcfa;
    });

    res.json({ success: true, data: enriched });
  } catch (err) {
    next(err);
  }
};

// Smart predictive autocomplete suggestions as you type
const suggestions = async (req, res, next) => {
  try {
    const { q = '' } = req.query;
    const query = q.trim().toLowerCase();

    // Built-in common drugs dictionary for instant matching even with 1-2 letters
    const commonDrugDictionary = [
      { name: 'Artemether 80mg', category: 'Antimalarials', icon: '🦟' },
      { name: 'Artemether-Lumefantrine 20/120mg (Coartem)', category: 'Antimalarials', icon: '🦟' },
      { name: 'Artemether 80/480mg Forte', category: 'Antimalarials', icon: '🦟' },
      { name: 'Artemether Injection 80mg/ml', category: 'Antimalarials', icon: '💉' },
      { name: 'Artesunate 50mg / Amodiaquine 153mg', category: 'Antimalarials', icon: '🦟' },
      { name: 'Paracetamol 500mg', category: 'Pain Relief & Fever', icon: '💊' },
      { name: 'Paracetamol 1000mg (1g)', category: 'Pain Relief & Fever', icon: '💊' },
      { name: 'Paracetamol Syrup 120mg/5ml', category: 'Pediatrics', icon: '🧴' },
      { name: 'Amoxicillin 500mg', category: 'Antibiotics', icon: '🦠' },
      { name: 'Amoxicillin-Clavulanic Acid 1g (Augmentin)', category: 'Antibiotics', icon: '🦠' },
      { name: 'Ciprofloxacin 500mg', category: 'Antibiotics', icon: '🦠' },
      { name: 'Azithromycin 500mg', category: 'Antibiotics', icon: '🦠' },
      { name: 'Ibuprofen 400mg', category: 'Anti-inflammatory', icon: '💊' },
      { name: 'Omeprazole 20mg', category: 'Gastric & Ulcer', icon: '🛡️' },
      { name: 'Cetirizine 10mg', category: 'Allergy & Antihistamine', icon: '🌿' },
      { name: 'Metformin 500mg', category: 'Diabetes', icon: '🩸' },
      { name: 'Amlodipine 5mg', category: 'Cardiovascular', icon: '❤️' },
      { name: 'Diclofenac 50mg', category: 'Pain Relief', icon: '💊' },
      { name: 'Salbutamol Inhaler 100mcg', category: 'Respiratory', icon: '🫁' },
      { name: 'Vitamin C 1000mg Effervescent', category: 'Vitamins', icon: '🍊' },
    ];

    // Find in DB
    const dbMeds = await prisma.medication.findMany({
      where: query.length > 0 ? {
        name: { contains: query, mode: 'insensitive' },
      } : {},
      select: { name: true, category: true, priceFcfa: true },
      distinct: ['name'],
      take: 15,
    });

    const suggestionsMap = new Map();

    // Add matching from dictionary
    for (const item of commonDrugDictionary) {
      if (query.length === 0 || item.name.toLowerCase().includes(query) || item.category.toLowerCase().includes(query)) {
        suggestionsMap.set(item.name, {
          name: item.name,
          category: item.category,
          icon: item.icon,
          isCommon: true,
        });
      }
    }

    // Add matching from DB
    for (const item of dbMeds) {
      if (!suggestionsMap.has(item.name)) {
        suggestionsMap.set(item.name, {
          name: item.name,
          category: item.category || 'General',
          icon: '💊',
          priceFcfa: item.priceFcfa,
          isCommon: false,
        });
      }
    }

    const list = Array.from(suggestionsMap.values()).slice(0, 12);
    res.json({ success: true, data: list });
  } catch (err) {
    next(err);
  }
};

const getById = async (req, res, next) => {
  try {
    const med = await prisma.medication.findUnique({
      where: { id: req.params.id },
      include: { pharmacy: true },
    });
    if (!med) throw { status: 404, message: 'Medication not found' };
    res.json({ success: true, data: med });
  } catch (err) {
    next(err);
  }
};

module.exports = { search, suggestions, getById };
