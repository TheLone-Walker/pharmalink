const router = require('express').Router();
const prisma = require('../config/db');
const { authenticate } = require('../middleware/auth.middleware');

// Helper to check if a pharmacy is open based on opening hours
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
  const dLat = (lat2 - lat1) * (Math.PI / 180);
  const dLon = (lon2 - lon1) * (Math.PI / 180);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * (Math.PI / 180)) *
      Math.cos(lat2 * (Math.PI / 180)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return parseFloat((R * c).toFixed(1));
}

// Drug synonym mappings for popular brand/generic equivalents
const DRUG_SYNONYMS = {
  coartem: ['artemether', 'lumefantrine'],
  augmentin: ['amoxicillin', 'clavulanate', 'clavulanic'],
  flagyl: ['metronidazole'],
  panadol: ['paracetamol', 'acetaminophen'],
  doliprane: ['paracetamol'],
  efferalgan: ['paracetamol'],
  voltaren: ['diclofenac'],
  zantac: ['ranitidine'],
  losec: ['omeprazole'],
  glucophage: ['metformin'],
  norvasc: ['amlodipine'],
  zithromax: ['azithromycin'],
  cipro: ['ciprofloxacin'],
};

// Robust keyword extractor that strips numbers and dosage units
function extractDrugKeywords(name) {
  if (!name) return [];
  const clean = name
    .toLowerCase()
    .replace(/\b\d+(\.\d+)?\s*(mg|g|ml|mcg|iu|%|cpm|bpm|tab|tabs|tablet|tablets|capsule|capsules|syrup|drop|drops|injection|ampoule|powder|cream|ointment|gel|inhaler)\b/gi, ' ')
    .replace(/\b\d+\b/g, ' ')
    .replace(/[^a-z\s]/gi, ' ')
    .trim();

  const words = clean.split(/\s+/).filter(w => w.length >= 3 && !['and', 'for', 'with', 'the', 'oral', 'forte'].includes(w));
  
  // Expand synonyms
  const expanded = new Set(words);
  for (const w of words) {
    if (DRUG_SYNONYMS[w]) {
      for (const syn of DRUG_SYNONYMS[w]) {
        expanded.add(syn);
      }
    }
  }

  return Array.from(expanded);
}

// Match check between prescribed drug and inventory item
function isDrugMatch(prescribedName, inventoryName) {
  if (!prescribedName || !inventoryName) return false;
  
  const normPrescribed = prescribedName.toLowerCase().trim();
  const normInv = inventoryName.toLowerCase().trim();

  // 1. Direct sub-string match
  if (normInv.includes(normPrescribed) || normPrescribed.includes(normInv)) return true;

  // 2. Keyword / active ingredient match
  const reqKeywords = extractDrugKeywords(prescribedName);
  const invKeywords = extractDrugKeywords(inventoryName);

  if (reqKeywords.length === 0 || invKeywords.length === 0) return false;

  // Check if any significant active ingredient keyword matches
  return reqKeywords.some(rk => invKeywords.some(ik => ik.includes(rk) || rk.includes(ik)));
}

// GET all pharmacies
router.get('/', authenticate, async (req, res, next) => {
  try {
    const pharmacies = await prisma.pharmacistProfile.findMany({
      include: {
        user: { select: { id: true, name: true, phone: true, email: true, profilePhotoUrl: true } },
        _count: { select: { medications: true, orders: true } },
      },
      orderBy: { pharmacyName: 'asc' },
    });
    res.json({ success: true, data: pharmacies });
  } catch (err) { next(err); }
});

// POST Check pharmacy availability, stock matching, open hours, and map locations
router.post('/check-availability', authenticate, async (req, res, next) => {
  try {
    const { prescriptionId, items: rawItems, userLat = 3.8480, userLng = 11.5021 } = req.body;

    let searchItems = [];
    if (prescriptionId) {
      const p = await prisma.prescription.findUnique({
        where: { id: prescriptionId },
        include: { items: true },
      });
      if (p && p.items) {
        searchItems = p.items.map(i => i.medicationName);
      }
    } else if (Array.isArray(rawItems)) {
      searchItems = rawItems.map(i => typeof i === 'string' ? i : (i.medicationName || i.name || ''));
    }

    // Filter out empty strings
    searchItems = searchItems.filter(Boolean);

    // Fetch all pharmacies with their active inventory
    const pharmacies = await prisma.pharmacistProfile.findMany({
      include: {
        user: { select: { id: true, name: true, phone: true, email: true, profilePhotoUrl: true } },
        medications: {
          where: { stockQuantity: { gt: 0 } },
          select: { id: true, name: true, priceFcfa: true, stockQuantity: true, category: true, imageUrl: true },
        },
      },
      orderBy: { pharmacyName: 'asc' },
    });

    const results = pharmacies.map(ph => {
      const isOpen = isPharmacyOpen(ph.openingHours);
      const lat = ph.lat || (3.8480 + (Math.random() - 0.5) * 0.05);
      const lng = ph.lng || (11.5021 + (Math.random() - 0.5) * 0.05);
      const distanceKm = calculateDistance(userLat, userLng, lat, lng);

      // Match inventory
      const matchedItems = [];
      const missingItems = [];
      let estimatedTotalFcfa = 0;

      for (const requiredName of searchItems) {
        const found = ph.medications.find(invMed => isDrugMatch(requiredName, invMed.name));

        if (found) {
          const price = parseFloat(found.priceFcfa || 0);
          matchedItems.push({
            prescribedDrug: requiredName,
            inventoryDrugId: found.id,
            matchedName: found.name,
            priceFcfa: price,
            stockQuantity: found.stockQuantity,
          });
          estimatedTotalFcfa += price;
        } else {
          missingItems.push(requiredName);
        }
      }

      const totalRequired = searchItems.length;
      const matchedCount = matchedItems.length;
      let stockStatus = 'OUT_OF_STOCK';
      if (totalRequired === 0 || matchedCount === totalRequired) {
        stockStatus = 'FULL_STOCK';
      } else if (matchedCount > 0) {
        stockStatus = 'PARTIAL_STOCK';
      }

      return {
        id: ph.id,
        userId: ph.userId,
        pharmacyName: ph.pharmacyName || 'Pharmacy',
        pharmacyAddress: ph.pharmacyAddress || 'Yaoundé, Cameroon',
        openingHours: ph.openingHours || '08:00 - 20:00',
        isOpen,
        lat,
        lng,
        distanceKm,
        pharmacistName: ph.user?.name || 'Pharmacist',
        pharmacistPhone: ph.user?.phone || '+237 6xx xxx xxx',
        stockStatus, // 'FULL_STOCK' | 'PARTIAL_STOCK' | 'OUT_OF_STOCK'
        matchedCount,
        totalRequired,
        matchPercentage: totalRequired > 0 ? Math.round((matchedCount / totalRequired) * 100) : 100,
        matchedItems,
        missingItems,
        estimatedTotalFcfa,
        totalInventoryCount: ph.medications.length,
      };
    });

    // Sort: Full Stock first, then Open Now, then Nearest
    results.sort((a, b) => {
      // 1. Stock match count desc
      if (b.matchedCount !== a.matchedCount) return b.matchedCount - a.matchedCount;
      // 2. Open now desc
      if (b.isOpen !== a.isOpen) return (b.isOpen ? 1 : 0) - (a.isOpen ? 1 : 0);
      // 3. Distance asc
      return a.distanceKm - b.distanceKm;
    });

    res.json({
      success: true,
      data: {
        totalPharmacies: results.length,
        prescribedDrugs: searchItems,
        userLocation: { lat: userLat, lng: userLng },
        pharmacies: results,
      },
    });
  } catch (err) {
    next(err);
  }
});

// GET nearest pharmacies
router.get('/nearest', authenticate, async (req, res, next) => {
  try {
    const pharmacies = await prisma.pharmacistProfile.findMany({
      include: {
        user: { select: { id: true, name: true, phone: true, email: true, profilePhotoUrl: true } },
        medications: { select: { id: true, name: true, priceFcfa: true, stockQuantity: true } },
      },
      orderBy: { pharmacyName: 'asc' },
    });
    res.json({ success: true, data: pharmacies });
  } catch (err) { next(err); }
});

// GET pharmacy by ID
router.get('/:id', authenticate, async (req, res, next) => {
  try {
    const pharmacy = await prisma.pharmacistProfile.findUnique({
      where: { id: req.params.id },
      include: {
        user: { select: { id: true, name: true, phone: true, email: true, profilePhotoUrl: true } },
        medications: true,
      },
    });
    if (!pharmacy) throw { status: 404, message: 'Pharmacy not found' };
    res.json({ success: true, data: pharmacy });
  } catch (err) { next(err); }
});

module.exports = router;
