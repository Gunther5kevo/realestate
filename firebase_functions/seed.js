const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// ─── Agents ───────────────────────────────────────────────────────────────────
const agents = [
  {
    id: 'agent_001',
    data: {
      displayName: 'James Kamau',
      email: 'james.kamau@nestiq.co.ke',
      phone: '+254712345678',
      agency: 'Kamau Properties Ltd',
      bio: 'Senior property consultant with over 10 years experience in Eldoret real estate. Specializing in Elgon View, West Indies and Pioneer.',
      rating: 4.9,
      reviewCount: 128,
      totalListings: 24,
      soldCount: 18,
      isVerified: true,
      specializations: ['Luxury', 'Residential', 'Commercial'],
      avatarUrl: null,
      memberSince: admin.firestore.Timestamp.fromDate(new Date('2020-03-15')),
    },
  },
  {
    id: 'agent_002',
    data: {
      displayName: 'Amina Odhiambo',
      email: 'amina.odhiambo@nestiq.co.ke',
      phone: '+254723456789',
      agency: 'Odhiambo Realty',
      bio: 'Passionate about helping families find their perfect home. 7 years experience covering Langas, Annex and Huruma estates in Eldoret.',
      rating: 4.7,
      reviewCount: 86,
      totalListings: 16,
      soldCount: 12,
      isVerified: true,
      specializations: ['Residential', 'Family Homes', 'Rentals'],
      avatarUrl: null,
      memberSince: admin.firestore.Timestamp.fromDate(new Date('2021-06-01')),
    },
  },
];

// ─── Prefix array builder ─────────────────────────────────────────────────────
function buildSearchPrefixes(title, location, type, listingType, bedrooms, agentName, price) {
  const prefixes = new Set();
  const words = new Set();

  title.toLowerCase().split(' ').forEach(w => words.add(w));

  if (location.neighborhood) {
    location.neighborhood.toLowerCase().split(' ').forEach(w => words.add(w));
  }
  location.city.toLowerCase().split(' ').forEach(w => words.add(w));
  location.address.toLowerCase().split(' ').forEach(w => words.add(w));

  words.add(type.toLowerCase());
  words.add(listingType.toLowerCase());

  if (listingType === 'rent') {
    ['rent', 'rental', 'let'].forEach(w => words.add(w));
  } else {
    ['sale', 'buy', 'purchase'].forEach(w => words.add(w));
  }

  if (['bedsitter', 'studio'].includes(type)) {
    ['bedsitter', 'bedsit', 'studio', 'single', 'room'].forEach(w => words.add(w));
  }

  if (bedrooms) {
    words.add(`${bedrooms}bed`);
    words.add(`${bedrooms}bedroom`);
  }

  if (agentName) {
    agentName.toLowerCase().split(' ').forEach(w => words.add(w));
  }

  if (price >= 100000000) words.add('luxury');
  if (price >= 50000000) words.add('premium');
  if (listingType === 'rent' && price <= 50000) words.add('affordable');

  words.forEach(word => {
    if (word.length < 2) return;
    for (let i = 1; i <= word.length; i++) {
      prefixes.add(word.substring(0, i));
    }
  });

  return [...prefixes];
}

// ─── Properties ───────────────────────────────────────────────────────────────
const properties = [

  // ════════════════════════ BEDSITTERS ════════════════════════════════════════

  // ── 1. Budget bedsitter Langas — KES 6,500/mo
  {
    title: 'Cosy Bedsitter — Langas Estate',
    description:
      'Neat self-contained bedsitter on the 2nd floor of a well-maintained block in Langas. Tiled throughout, fitted with a modern kitchenette, and served by a shared water tank and borehole. Walking distance to Langas market and matatu stops along the Eldoret–Kisumu highway.',
    price: 6500,
    currency: 'KES',
    type: 'bedsitter',
    status: 'active',
    listingType: 'rent',
    location: {
      latitude: 0.5143,
      longitude: 35.2663,
      address: 'Langas Estate, Block A',
      city: 'Eldoret',
      state: 'Uasin Gishu County',
      country: 'Kenya',
      neighborhood: 'Langas',
      geoPoint: new admin.firestore.GeoPoint(0.5143, 35.2663),
    },
    bedrooms: null,
    bathrooms: 1,
    areaSqFt: 220,
    floors: null,
    yearBuilt: 2018,
    amenities: ['waterTank', 'borehole', 'parking'],
    agentId: 'agent_001',
    agentName: 'James Kamau',
    isFeatured: false,
    isApproved: true,
    viewCount: 54,
    savedCount: 9,
    imageUrls: [
      'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=1200',
      'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=1200',
    ],
    videoUrls: [],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-18')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-18')),
  },

  // ── 2. Budget bedsitter Huruma — KES 6,000/mo
  {
    title: 'Budget Bedsitter — Huruma Estate',
    description:
      'Clean ground-floor bedsitter ideal for a working professional or student in Huruma Estate, Eldoret. Has its own external door and shared compound with CCTV and a watchman. Water is supplied via an overhead tank topped from a borehole — reliable even during Eldoret water rationing.',
    price: 6000,
    currency: 'KES',
    type: 'bedsitter',
    status: 'active',
    listingType: 'rent',
    location: {
      latitude: 0.5198,
      longitude: 35.2701,
      address: 'Huruma Estate, Off Uganda Road',
      city: 'Eldoret',
      state: 'Uasin Gishu County',
      country: 'Kenya',
      neighborhood: 'Huruma',
      geoPoint: new admin.firestore.GeoPoint(0.5198, 35.2701),
    },
    bedrooms: null,
    bathrooms: 1,
    areaSqFt: 200,
    floors: null,
    yearBuilt: 2015,
    amenities: ['waterTank', 'borehole', 'cctv', 'guardhouse'],
    agentId: 'agent_001',
    agentName: 'James Kamau',
    isFeatured: false,
    isApproved: true,
    viewCount: 112,
    savedCount: 17,
    imageUrls: [
      'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=1200',
      'https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=1200',
    ],
    videoUrls: [],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-20')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-20')),
  },

  // ── 3. Furnished bedsitter Pioneer — KES 12,000/mo
  {
    title: 'Furnished Bedsitter — Pioneer Estate',
    description:
      'Modern furnished bedsitter in Pioneer Estate, a short drive from Eldoret CBD and Zion Mall. Comes with a bed, sofa, and small dining table. Has fibre internet provision, borehole water, CCTV, and a backup generator shared across the 24-unit block.',
    price: 12000,
    currency: 'KES',
    type: 'bedsitter',
    status: 'active',
    listingType: 'rent',
    location: {
      latitude: 0.5201,
      longitude: 35.2780,
      address: 'Pioneer Estate, Off Nandi Road',
      city: 'Eldoret',
      state: 'Uasin Gishu County',
      country: 'Kenya',
      neighborhood: 'Pioneer',
      geoPoint: new admin.firestore.GeoPoint(0.5201, 35.2780),
    },
    bedrooms: null,
    bathrooms: 1,
    areaSqFt: 250,
    floors: null,
    yearBuilt: 2020,
    amenities: ['furnished', 'fibre', 'borehole', 'waterTank', 'generator', 'cctv', 'guardhouse'],
    agentId: 'agent_001',
    agentName: 'James Kamau',
    isFeatured: true,
    isApproved: true,
    viewCount: 178,
    savedCount: 31,
    imageUrls: [
      'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=1200',
      'https://images.unsplash.com/photo-1536376072261-38c75010e6c9?w=1200',
      'https://images.unsplash.com/photo-1554995207-c18c203602cb?w=1200',
    ],
    videoUrls: [],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-16')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-16')),
  },

  // ── 4. Bedsitter Annex — KES 7,000/mo
  {
    title: 'Bedsitter — Annex Estate, Eldoret',
    description:
      'Comfortable bedsitter in the popular Annex Estate near Eldoret town centre. The compound has a reliable borehole, water tank, and a security guard. Great for single occupants or couples working within Eldoret CBD.',
    price: 7000,
    currency: 'KES',
    type: 'bedsitter',
    status: 'active',
    listingType: 'rent',
    location: {
      latitude: 0.5221,
      longitude: 35.2698,
      address: 'Annex Estate, Oloo Street',
      city: 'Eldoret',
      state: 'Uasin Gishu County',
      country: 'Kenya',
      neighborhood: 'Annex',
      geoPoint: new admin.firestore.GeoPoint(0.5221, 35.2698),
    },
    bedrooms: null,
    bathrooms: 1,
    areaSqFt: 230,
    floors: null,
    yearBuilt: 2016,
    amenities: ['borehole', 'waterTank', 'guardhouse'],
    agentId: 'agent_002',
    agentName: 'Amina Odhiambo',
    isFeatured: false,
    isApproved: true,
    viewCount: 67,
    savedCount: 10,
    imageUrls: [
      'https://images.unsplash.com/photo-1455587734955-081b22074882?w=1200',
      'https://images.unsplash.com/photo-1493246507139-91e8fad9978e?w=1200',
    ],
    videoUrls: [],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-14')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-14')),
  },

  // ════════════════════════ STUDIOS ═══════════════════════════════════════════

  // ── 5. Studio Kapsoya — KES 14,000/mo
  {
    title: 'Studio Apartment — Kapsoya Estate',
    description:
      'Open-plan studio with a well-appointed kitchenette and a walk-in shower in Kapsoya Estate. The compound has a gated entrance with a guard, parking, and a shared garden. Ideal for young professionals commuting along the Eldoret–Nakuru highway.',
    price: 14000,
    currency: 'KES',
    type: 'studio',
    status: 'active',
    listingType: 'rent',
    location: {
      latitude: 0.5068,
      longitude: 35.2912,
      address: 'Kapsoya Estate, Block C',
      city: 'Eldoret',
      state: 'Uasin Gishu County',
      country: 'Kenya',
      neighborhood: 'Kapsoya',
      geoPoint: new admin.firestore.GeoPoint(0.5068, 35.2912),
    },
    bedrooms: null,
    bathrooms: 1,
    areaSqFt: 300,
    floors: null,
    yearBuilt: 2021,
    amenities: ['guardhouse', 'parking', 'garden', 'gatedCommunity', 'waterTank'],
    agentId: 'agent_001',
    agentName: 'James Kamau',
    isFeatured: false,
    isApproved: true,
    viewCount: 89,
    savedCount: 14,
    imageUrls: [
      'https://images.unsplash.com/photo-1484154218962-a197022b5858?w=1200',
      'https://images.unsplash.com/photo-1556020685-ae41abfc9365?w=1200',
    ],
    videoUrls: [],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-13')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-13')),
  },

  // ── 6. Furnished studio West Indies — KES 35,000/mo
  {
    title: 'Cozy Studio Apartment — West Indies Estate',
    description:
      'Fully furnished studio apartment ideal for young professionals in the sought-after West Indies Estate. Located minutes from Eldoret CBD and major corporate offices along Uganda Road. Includes high-speed fibre WiFi and a fully equipped kitchenette. All utilities included in rent.',
    price: 35000,
    currency: 'KES',
    type: 'studio',
    status: 'active',
    listingType: 'rent',
    location: {
      latitude: 0.5255,
      longitude: 35.2741,
      address: 'West Indies Estate, Uganda Road',
      city: 'Eldoret',
      state: 'Uasin Gishu County',
      country: 'Kenya',
      neighborhood: 'West Indies',
      geoPoint: new admin.firestore.GeoPoint(0.5255, 35.2741),
    },
    bedrooms: null,
    bathrooms: 1,
    areaSqFt: 450,
    floors: 3,
    yearBuilt: 2020,
    amenities: ['guardhouse', 'elevator', 'fibre', 'airConditioning', 'furnished'],
    agentId: 'agent_001',
    agentName: 'James Kamau',
    isFeatured: false,
    isApproved: true,
    viewCount: 74,
    savedCount: 11,
    imageUrls: [
      'https://images.unsplash.com/photo-1536376072261-38c75010e6c9?w=1200',
      'https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=1200',
    ],
    videoUrls: [],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-05')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-05')),
  },

  // ════════════════════════ 1-BEDROOM ════════════════════════════════════════

  // ── 7. 1-bed Elgon View — KES 18,000/mo
  {
    title: '1 Bedroom Apartment — Elgon View Estate',
    description:
      'Spacious 1-bedroom apartment with a separate lounge, modern kitchen with granite worktops, and a full bathroom in the leafy Elgon View Estate. The block sits in a quiet compound with 24-hr security, a borehole, and visitor parking.',
    price: 18000,
    currency: 'KES',
    type: 'apartment',
    status: 'active',
    listingType: 'rent',
    location: {
      latitude: 0.5312,
      longitude: 35.2836,
      address: 'Elgon View Estate, Off Hospital Road',
      city: 'Eldoret',
      state: 'Uasin Gishu County',
      country: 'Kenya',
      neighborhood: 'Elgon View',
      geoPoint: new admin.firestore.GeoPoint(0.5312, 35.2836),
    },
    bedrooms: 1,
    bathrooms: 1,
    areaSqFt: 450,
    floors: 3,
    yearBuilt: 2019,
    amenities: ['guardhouse', 'cctv', 'borehole', 'waterTank', 'parking', 'visitorParking'],
    agentId: 'agent_001',
    agentName: 'James Kamau',
    isFeatured: false,
    isApproved: true,
    viewCount: 143,
    savedCount: 20,
    imageUrls: [
      'https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=1200',
      'https://images.unsplash.com/photo-1507089947368-19c1da9775ae?w=1200',
      'https://images.unsplash.com/photo-1560185893-a55cbc8c57e8?w=1200',
    ],
    videoUrls: [],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-21')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-21')),
  },

  // ── 8. 1-bed Kimumu — KES 22,000/mo
  {
    title: '1 Bedroom Apartment — Kimumu Estate',
    description:
      'Bright 1-bedroom apartment in Kimumu Estate, close to Moi Teaching & Referral Hospital and Eldoret airport road. Has a fitted kitchen, tiled lounge, balcony with hillside views, and a parking bay. The estate is gated with electric fence and CCTV.',
    price: 22000,
    currency: 'KES',
    type: 'apartment',
    status: 'active',
    listingType: 'rent',
    location: {
      latitude: 0.5389,
      longitude: 35.3021,
      address: 'Kimumu Estate, Airport Road',
      city: 'Eldoret',
      state: 'Uasin Gishu County',
      country: 'Kenya',
      neighborhood: 'Kimumu',
      geoPoint: new admin.firestore.GeoPoint(0.5389, 35.3021),
    },
    bedrooms: 1,
    bathrooms: 1,
    areaSqFt: 500,
    floors: 4,
    yearBuilt: 2022,
    amenities: ['balcony', 'parking', 'electricFence', 'cctv', 'gatedCommunity', 'waterTank', 'fibre'],
    agentId: 'agent_002',
    agentName: 'Amina Odhiambo',
    isFeatured: true,
    isApproved: true,
    viewCount: 201,
    savedCount: 35,
    imageUrls: [
      'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=1200',
      'https://images.unsplash.com/photo-1598928506311-c55ded91a20c?w=1200',
      'https://images.unsplash.com/photo-1567767292278-a4f21aa2d36e?w=1200',
    ],
    videoUrls: [],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-22')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-22')),
  },

  // ── 9. Furnished 1-bed Elgon View — KES 65,000/mo
  {
    title: 'Furnished 1 Bedroom Apartment — Elgon View',
    description:
      'Fully furnished 1-bedroom apartment in a quiet close off Hospital Road, Elgon View. High-quality furnishings, fibre internet, rooftop pool, gym, backup generator, and 24-hr concierge. Perfect for expats, NGO workers, or short-stay lets near MTRH.',
    price: 65000,
    currency: 'KES',
    type: 'apartment',
    status: 'active',
    listingType: 'rent',
    location: {
      latitude: 0.5325,
      longitude: 35.2851,
      address: 'Hospital Road, Elgon View',
      city: 'Eldoret',
      state: 'Uasin Gishu County',
      country: 'Kenya',
      neighborhood: 'Elgon View',
      geoPoint: new admin.firestore.GeoPoint(0.5325, 35.2851),
    },
    bedrooms: 1,
    bathrooms: 1,
    areaSqFt: 580,
    floors: 7,
    yearBuilt: 2021,
    amenities: ['furnished', 'fibre', 'pool', 'gym', 'generator', 'cctv', 'guardhouse', 'elevator', 'parking', 'gatedCommunity'],
    agentId: 'agent_001',
    agentName: 'James Kamau',
    isFeatured: true,
    isApproved: true,
    viewCount: 156,
    savedCount: 22,
    imageUrls: [
      'https://images.unsplash.com/photo-1617806118233-18e1de247200?w=1200',
      'https://images.unsplash.com/photo-1616594039964-ae9021a400a0?w=1200',
      'https://images.unsplash.com/photo-1618221195710-dd6b41faaea6?w=1200',
    ],
    videoUrls: [],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-19')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-19')),
  },

  // ── 10. 1-bed Chepkoilel — KES 15,000/mo
  {
    title: '1 Bedroom Apartment — Chepkoilel Township',
    description:
      'Quiet and secure 1-bedroom apartment near Chepkoilel University Campus. Has a lounge, kitchen, and bathroom. Comes with designated parking, water tank, and a garden compound. Ideal for university staff and students.',
    price: 15000,
    currency: 'KES',
    type: 'apartment',
    status: 'active',
    listingType: 'rent',
    location: {
      latitude: 0.5731,
      longitude: 35.2488,
      address: 'Chepkoilel Township, Campus Road',
      city: 'Eldoret',
      state: 'Uasin Gishu County',
      country: 'Kenya',
      neighborhood: 'Chepkoilel',
      geoPoint: new admin.firestore.GeoPoint(0.5731, 35.2488),
    },
    bedrooms: 1,
    bathrooms: 1,
    areaSqFt: 420,
    floors: 2,
    yearBuilt: 2018,
    amenities: ['parking', 'garden', 'waterTank', 'guardhouse'],
    agentId: 'agent_002',
    agentName: 'Amina Odhiambo',
    isFeatured: false,
    isApproved: true,
    viewCount: 48,
    savedCount: 7,
    imageUrls: [
      'https://images.unsplash.com/photo-1531971589569-0d9370cbe1e5?w=1200',
      'https://images.unsplash.com/photo-1555636222-cae831e670b3?w=1200',
    ],
    videoUrls: [],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-07')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-07')),
  },

  // ════════════════════════ 2-BEDROOM ════════════════════════════════════════

  // ── 11. 2-bed Elgon View — KES 85,000/mo
  {
    title: '2 Bedroom Apartment in Elgon View',
    description:
      'Spacious and well-finished 2-bedroom apartment in the prestigious Elgon View Estate. Walking distance to top schools and MTRH. Features a modern kitchen, ample storage, and a balcony with lovely green hillside views. Secure compound with 24-hour security.',
    price: 85000,
    currency: 'KES',
    type: 'apartment',
    status: 'active',
    listingType: 'rent',
    location: {
      latitude: 0.5318,
      longitude: 35.2845,
      address: 'Elgon View Drive',
      city: 'Eldoret',
      state: 'Uasin Gishu County',
      country: 'Kenya',
      neighborhood: 'Elgon View',
      geoPoint: new admin.firestore.GeoPoint(0.5318, 35.2845),
    },
    bedrooms: 2,
    bathrooms: 2,
    areaSqFt: 1100,
    floors: 5,
    yearBuilt: 2018,
    amenities: ['parking', 'guardhouse', 'balcony', 'elevator', 'fibre', 'airConditioning'],
    agentId: 'agent_001',
    agentName: 'James Kamau',
    isFeatured: true,
    isApproved: true,
    viewCount: 156,
    savedCount: 22,
    imageUrls: [
      'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=1200',
      'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=1200',
    ],
    videoUrls: [],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-10')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-10')),
  },

  // ── 12. 2-bed Langas — KES 28,000/mo
  {
    title: '2 Bedroom Apartment — Langas Estate',
    description:
      'Well-maintained 2-bedroom apartment on the 3rd floor in Langas Estate. Has a lounge and dining area, fitted kitchen, and one en-suite bedroom. The estate has borehole water, solar water heating, guarded gate, and ample parking.',
    price: 28000,
    currency: 'KES',
    type: 'apartment',
    status: 'active',
    listingType: 'rent',
    location: {
      latitude: 0.5155,
      longitude: 35.2671,
      address: 'Langas Estate, Moi Avenue Junction',
      city: 'Eldoret',
      state: 'Uasin Gishu County',
      country: 'Kenya',
      neighborhood: 'Langas',
      geoPoint: new admin.firestore.GeoPoint(0.5155, 35.2671),
    },
    bedrooms: 2,
    bathrooms: 2,
    areaSqFt: 750,
    floors: 4,
    yearBuilt: 2017,
    amenities: ['borehole', 'solar', 'guardhouse', 'parking', 'waterTank'],
    agentId: 'agent_002',
    agentName: 'Amina Odhiambo',
    isFeatured: false,
    isApproved: true,
    viewCount: 97,
    savedCount: 16,
    imageUrls: [
      'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=1200',
      'https://images.unsplash.com/photo-1600121848594-d8644e57abab?w=1200',
    ],
    videoUrls: [],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-15')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-15')),
  },

  // ── 13. 2-bed + DSQ bungalow Kapsoya — KES 32,000/mo
  {
    title: '2 Bedroom + DSQ Bungalow — Kapsoya',
    description:
      'Spacious 2-bedroom bungalow with a DSQ (domestic staff quarter) in a quiet Kapsoya compound. Has a private garden, parking for two cars, borehole water, and an electric fence perimeter. 10 minutes from Eldoret CBD.',
    price: 32000,
    currency: 'KES',
    type: 'bungalow',
    status: 'active',
    listingType: 'rent',
    location: {
      latitude: 0.5055,
      longitude: 35.2921,
      address: 'Kapsoya Estate, Nakuru Road',
      city: 'Eldoret',
      state: 'Uasin Gishu County',
      country: 'Kenya',
      neighborhood: 'Kapsoya',
      geoPoint: new admin.firestore.GeoPoint(0.5055, 35.2921),
    },
    bedrooms: 2,
    bathrooms: 2,
    areaSqFt: 1100,
    floors: 1,
    yearBuilt: 2016,
    amenities: ['dsq', 'garden', 'parking', 'borehole', 'electricFence', 'waterTank'],
    agentId: 'agent_001',
    agentName: 'James Kamau',
    isFeatured: false,
    isApproved: true,
    viewCount: 83,
    savedCount: 12,
    imageUrls: [
      'https://images.unsplash.com/photo-1572120360610-d971b9d7767c?w=1200',
      'https://images.unsplash.com/photo-1570129477492-45c003edd2be?w=1200',
      'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=1200',
    ],
    videoUrls: [],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-11')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-11')),
  },

  // ── 14. 2-bed Mandela — KES 55,000/mo
  {
    title: '2 Bedroom Apartment — Mandela Estate',
    description:
      'Light-filled 2-bedroom apartment in the central Mandela Estate, Eldoret. Has a spacious balcony, tiled throughout, with a fitted kitchen. The complex has a communal pool, gym, generator, CCTV, and secure parking. Close to Zion Mall and Eldoret CBD.',
    price: 55000,
    currency: 'KES',
    type: 'apartment',
    status: 'active',
    listingType: 'rent',
    location: {
      latitude: 0.5242,
      longitude: 35.2755,
      address: 'Mandela Estate, Off Uganda Road',
      city: 'Eldoret',
      state: 'Uasin Gishu County',
      country: 'Kenya',
      neighborhood: 'Mandela',
      geoPoint: new admin.firestore.GeoPoint(0.5242, 35.2755),
    },
    bedrooms: 2,
    bathrooms: 2,
    areaSqFt: 900,
    floors: 5,
    yearBuilt: 2019,
    amenities: ['pool', 'gym', 'generator', 'cctv', 'guardhouse', 'balcony', 'parking', 'airConditioning'],
    agentId: 'agent_002',
    agentName: 'Amina Odhiambo',
    isFeatured: true,
    isApproved: true,
    viewCount: 132,
    savedCount: 24,
    imageUrls: [
      'https://images.unsplash.com/photo-1551882547-ff40c4a49f5e?w=1200',
      'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=1200',
      'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=1200',
    ],
    videoUrls: [],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-12')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-12')),
  },

  // ════════════════════════ 3-BEDROOM ════════════════════════════════════════

  // ── 15. 3-bed townhouse Elgon View — KES 120,000/mo
  {
    title: '3 Bedroom Townhouse — Elgon View Estate',
    description:
      'Beautiful 3-bedroom townhouse in a quiet gated community in Elgon View. Freshly painted with new wooden floors throughout. Features an en-suite master bedroom, modern fitted kitchen, and a small private garden. Pet friendly. Close to international schools and MTRH.',
    price: 120000,
    currency: 'KES',
    type: 'townhouse',
    status: 'active',
    listingType: 'rent',
    location: {
      latitude: 0.5299,
      longitude: 35.2863,
      address: 'Elgon View Drive, Hospital Road',
      city: 'Eldoret',
      state: 'Uasin Gishu County',
      country: 'Kenya',
      neighborhood: 'Elgon View',
      geoPoint: new admin.firestore.GeoPoint(0.5299, 35.2863),
    },
    bedrooms: 3,
    bathrooms: 3,
    areaSqFt: 2100,
    floors: 2,
    yearBuilt: 2016,
    amenities: ['parking', 'guardhouse', 'garden', 'fibre', 'petFriendly'],
    agentId: 'agent_001',
    agentName: 'James Kamau',
    isFeatured: false,
    isApproved: true,
    viewCount: 88,
    savedCount: 13,
    imageUrls: [
      'https://images.unsplash.com/photo-1605276374104-dee2a0ed3cd6?w=1200',
      'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=1200',
    ],
    videoUrls: [],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-09-28')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-09-28')),
  },

  // ── 16. 3-bed maisonette Ngeria — KES 48,000/mo
  {
    title: '3 Bedroom Maisonette — Ngeria Estate',
    description:
      'Modern 3-bedroom maisonette in the popular Ngeria Estate on the outskirts of Eldoret. All bedrooms en-suite, open-plan kitchen and dining, private balcony off master bedroom, and a small front garden. The estate has a manned gate, CCTV, borehole, and a play area for children.',
    price: 48000,
    currency: 'KES',
    type: 'maisonette',
    status: 'active',
    listingType: 'rent',
    location: {
      latitude: 0.5481,
      longitude: 35.2594,
      address: 'Ngeria Estate, Ziwa Road',
      city: 'Eldoret',
      state: 'Uasin Gishu County',
      country: 'Kenya',
      neighborhood: 'Ngeria',
      geoPoint: new admin.firestore.GeoPoint(0.5481, 35.2594),
    },
    bedrooms: 3,
    bathrooms: 3,
    areaSqFt: 1400,
    floors: 2,
    yearBuilt: 2020,
    amenities: ['guardhouse', 'cctv', 'borehole', 'waterTank', 'balcony', 'garden', 'gatedCommunity', 'playArea', 'parking'],
    agentId: 'agent_002',
    agentName: 'Amina Odhiambo',
    isFeatured: true,
    isApproved: true,
    viewCount: 167,
    savedCount: 28,
    imageUrls: [
      'https://images.unsplash.com/photo-1600047509807-ba8f99d2cdde?w=1200',
      'https://images.unsplash.com/photo-1600047509358-9dc75507daeb?w=1200',
      'https://images.unsplash.com/photo-1600566752355-35792bedcfea?w=1200',
    ],
    videoUrls: [],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-17')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-17')),
  },

  // ── 17. 3-bed apartment for sale West Indies — KES 18.5M
  {
    title: '3 Bedroom Apartment for Sale — West Indies Estate',
    description:
      'Elegant 3-bedroom apartment on the 5th floor of a boutique 8-unit block in West Indies Estate, Eldoret. Features include a chef\'s kitchen, hardwood floors, large balcony, fibre internet, pool, rooftop garden, two parking bays, and a generator. Ideal for owner-occupiers or investment.',
    price: 18500000,
    currency: 'KES',
    type: 'apartment',
    status: 'active',
    listingType: 'sale',
    location: {
      latitude: 0.5261,
      longitude: 35.2749,
      address: 'West Indies Estate, Uganda Road',
      city: 'Eldoret',
      state: 'Uasin Gishu County',
      country: 'Kenya',
      neighborhood: 'West Indies',
      geoPoint: new admin.firestore.GeoPoint(0.5261, 35.2749),
    },
    bedrooms: 3,
    bathrooms: 3,
    areaSqFt: 1700,
    floors: 8,
    yearBuilt: 2023,
    amenities: ['fibre', 'pool', 'gym', 'generator', 'cctv', 'guardhouse', 'elevator', 'balcony', 'garden', 'parking', 'gatedCommunity'],
    agentId: 'agent_001',
    agentName: 'James Kamau',
    isFeatured: true,
    isApproved: true,
    viewCount: 204,
    savedCount: 33,
    imageUrls: [
      'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=1200',
      'https://images.unsplash.com/photo-1600210492493-0946911123ea?w=1200',
      'https://images.unsplash.com/photo-1600607687939-ce8a6f349779?w=1200',
    ],
    videoUrls: [],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-09')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-09')),
  },

  // ── 18. 3-bed + DSQ bungalow for sale Munyaka — KES 12.5M
  {
    title: '3 Bedroom + DSQ Bungalow for Sale — Munyaka',
    description:
      'Well-priced 3-bedroom bungalow with DSQ on a 0.08 acre plot in Munyaka, Eldoret. Has a solar water heater, borehole, electric fence, and a double carport. Very close to Eldoret town and Makena Shopping Centre.',
    price: 12500000,
    currency: 'KES',
    type: 'bungalow',
    status: 'active',
    listingType: 'sale',
    location: {
      latitude: 0.5178,
      longitude: 35.2812,
      address: 'Munyaka, Off Eldoret–Ziwa Road',
      city: 'Eldoret',
      state: 'Uasin Gishu County',
      country: 'Kenya',
      neighborhood: 'Munyaka',
      geoPoint: new admin.firestore.GeoPoint(0.5178, 35.2812),
    },
    bedrooms: 3,
    bathrooms: 3,
    areaSqFt: 1600,
    floors: 1,
    yearBuilt: 2017,
    amenities: ['dsq', 'solar', 'borehole', 'electricFence', 'parking', 'garden'],
    agentId: 'agent_002',
    agentName: 'Amina Odhiambo',
    isFeatured: false,
    isApproved: true,
    viewCount: 76,
    savedCount: 11,
    imageUrls: [
      'https://images.unsplash.com/photo-1576941089067-2de3c901e126?w=1200',
      'https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=1200',
      'https://images.unsplash.com/photo-1582268611958-ebfd161ef9cf?w=1200',
    ],
    videoUrls: [],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-05')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-05')),
  },

  // ════════════════════════ 4+ BEDROOM ═══════════════════════════════════════

  // ── 19. Family home Elgon View for sale — KES 65M
  {
    title: 'Family Home in Elgon View Estate',
    description:
      'Elegant 4-bedroom family home in the serene Elgon View Estate, Eldoret. Set on a generous plot with mature trees and a private garden. The home features a spacious living room, formal dining, modern kitchen, and a separate DSQ. Close to Eldoret International School and MTRH.',
    price: 65000000,
    currency: 'KES',
    type: 'house',
    status: 'active',
    listingType: 'sale',
    location: {
      latitude: 0.5338,
      longitude: 35.2871,
      address: 'Elgon View Estate, Hospital Road',
      city: 'Eldoret',
      state: 'Uasin Gishu County',
      country: 'Kenya',
      neighborhood: 'Elgon View',
      geoPoint: new admin.firestore.GeoPoint(0.5338, 35.2871),
    },
    bedrooms: 4,
    bathrooms: 3,
    areaSqFt: 3800,
    floors: 2,
    yearBuilt: 2015,
    amenities: ['parking', 'guardhouse', 'garden', 'fibre', 'airConditioning', 'dsq'],
    agentId: 'agent_002',
    agentName: 'Amina Odhiambo',
    isFeatured: false,
    isApproved: true,
    viewCount: 98,
    savedCount: 15,
    imageUrls: [
      'https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=1200',
      'https://images.unsplash.com/photo-1570129477492-45c003edd2be?w=1200',
    ],
    videoUrls: [],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-09-20')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-09-20')),
  },

  // ── 20. 4-bed townhouse for sale West Indies — KES 42M
  {
    title: '4 Bedroom Townhouse for Sale — West Indies Estate',
    description:
      'Stunning 4-bedroom townhouse in a quiet close off Uganda Road, West Indies Estate. All bedrooms en-suite, large open-plan living and dining, gourmet kitchen, double garage, DSQ, and a lush garden. The block has a gym, heated pool, generator, fibre, and 24/7 security.',
    price: 42000000,
    currency: 'KES',
    type: 'townhouse',
    status: 'active',
    listingType: 'sale',
    location: {
      latitude: 0.5269,
      longitude: 35.2736,
      address: 'West Indies Estate, Uganda Road',
      city: 'Eldoret',
      state: 'Uasin Gishu County',
      country: 'Kenya',
      neighborhood: 'West Indies',
      geoPoint: new admin.firestore.GeoPoint(0.5269, 35.2736),
    },
    bedrooms: 4,
    bathrooms: 4,
    areaSqFt: 3200,
    floors: 3,
    yearBuilt: 2022,
    amenities: ['pool', 'gym', 'generator', 'fibre', 'guardhouse', 'cctv', 'electricFence', 'dsq', 'garden', 'parking', 'gatedCommunity', 'airConditioning'],
    agentId: 'agent_001',
    agentName: 'James Kamau',
    isFeatured: true,
    isApproved: true,
    viewCount: 187,
    savedCount: 30,
    imageUrls: [
      'https://images.unsplash.com/photo-1613977257592-4871e5fcd7c4?w=1200',
      'https://images.unsplash.com/photo-1613977257363-707ba9348227?w=1200',
      'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=1200',
    ],
    videoUrls: [],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-03')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-03')),
  },

  // ════════════════════════ LUXURY ════════════════════════════════════════════

  // ── 21. Luxury penthouse Elgon View — KES 45M
  {
    title: 'Luxury Penthouse with Valley Views — Elgon View',
    description:
      'An extraordinary penthouse offering breathtaking panoramic views of the Rift Valley and Elgon hills. Features soaring ceilings, floor-to-ceiling windows, and premium finishes throughout. The open-plan living area flows to a wraparound terrace perfect for entertaining. Chef kitchen with premium appliances.',
    price: 45000000,
    currency: 'KES',
    type: 'apartment',
    status: 'active',
    listingType: 'sale',
    location: {
      latitude: 0.5344,
      longitude: 35.2877,
      address: 'Elgon View Drive',
      city: 'Eldoret',
      state: 'Uasin Gishu County',
      country: 'Kenya',
      neighborhood: 'Elgon View',
      geoPoint: new admin.firestore.GeoPoint(0.5344, 35.2877),
    },
    bedrooms: 3,
    bathrooms: 3,
    areaSqFt: 3200,
    floors: 28,
    yearBuilt: 2022,
    amenities: ['pool', 'gym', 'parking', 'guardhouse', 'balcony', 'elevator', 'airConditioning', 'fibre'],
    agentId: 'agent_001',
    agentName: 'James Kamau',
    isFeatured: true,
    isApproved: true,
    viewCount: 342,
    savedCount: 48,
    imageUrls: [
      'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=1200',
      'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=1200',
      'https://images.unsplash.com/photo-1583608205776-bfd35f0d9f83?w=1200',
    ],
    videoUrls: [],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-01')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-01')),
  },

  // ── 22. Modern villa Pembe Tatu — KES 85M
  {
    title: 'Modern Villa — Pembe Tatu, Eldoret',
    description:
      'Stunning 5-bedroom villa set on a half-acre landscaped compound in the prestigious Pembe Tatu area of Eldoret. Features a heated swimming pool, staff quarters, double garage, and beautifully manicured gardens. Ideal for families seeking space and privacy in Eldoret\'s finest suburb.',
    price: 85000000,
    currency: 'KES',
    type: 'villa',
    status: 'active',
    listingType: 'sale',
    location: {
      latitude: 0.5189,
      longitude: 35.3105,
      address: 'Pembe Tatu, Off Eldoret–Nakuru Highway',
      city: 'Eldoret',
      state: 'Uasin Gishu County',
      country: 'Kenya',
      neighborhood: 'Pembe Tatu',
      geoPoint: new admin.firestore.GeoPoint(0.5189, 35.3105),
    },
    bedrooms: 5,
    bathrooms: 4,
    areaSqFt: 5800,
    floors: 2,
    yearBuilt: 2019,
    amenities: ['pool', 'gym', 'parking', 'guardhouse', 'garden', 'airConditioning', 'fibre', 'furnished', 'dsq'],
    agentId: 'agent_002',
    agentName: 'Amina Odhiambo',
    isFeatured: true,
    isApproved: true,
    viewCount: 218,
    savedCount: 34,
    imageUrls: [
      'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=1200',
      'https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=1200',
      'https://images.unsplash.com/photo-1576941089067-2de3c901e126?w=1200',
    ],
    videoUrls: [],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-09-15')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-09-15')),
  },

  // ── 23. Exclusive residence Elgon View — KES 180M
  {
    title: 'Exclusive Residence — Elgon View',
    description:
      'One of Eldoret\'s finest homes available for sale. This magnificent 6-bedroom residence sits on a 1-acre landscaped compound in Elgon View with a heated pool, tennis court, and 4-car garage. Designed by a renowned Nairobi architect with imported Italian finishes throughout.',
    price: 180000000,
    currency: 'KES',
    type: 'villa',
    status: 'active',
    listingType: 'sale',
    location: {
      latitude: 0.5351,
      longitude: 35.2891,
      address: 'Elgon View Estate, Upper Drive',
      city: 'Eldoret',
      state: 'Uasin Gishu County',
      country: 'Kenya',
      neighborhood: 'Elgon View',
      geoPoint: new admin.firestore.GeoPoint(0.5351, 35.2891),
    },
    bedrooms: 6,
    bathrooms: 6,
    areaSqFt: 8500,
    floors: 2,
    yearBuilt: 2021,
    amenities: ['pool', 'gym', 'parking', 'guardhouse', 'garden', 'balcony', 'elevator', 'airConditioning', 'fibre', 'furnished', 'electricFence', 'cctv'],
    agentId: 'agent_002',
    agentName: 'Amina Odhiambo',
    isFeatured: true,
    isApproved: true,
    viewCount: 195,
    savedCount: 29,
    imageUrls: [
      'https://images.unsplash.com/photo-1613977257363-707ba9348227?w=1200',
      'https://images.unsplash.com/photo-1613977257592-4871e5fcd7c4?w=1200',
      'https://images.unsplash.com/photo-1600047509807-ba8f99d2cdde?w=1200',
    ],
    videoUrls: [],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-08-30')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-08-30')),
  },

  // ════════════════════════ COMMERCIAL / LAND ══════════════════════════════════

  // ── 24. Grade A office Eldoret CBD — KES 250,000/mo
  {
    title: 'Prime Office Space — Eldoret CBD',
    description:
      'Grade A office space available in one of Eldoret CBD\'s most prestigious buildings on Uganda Road. Open plan floor suitable for 20-30 workstations. Features raised floors, VRV air conditioning, backup generator, and 3 dedicated parking bays. Ideal for financial services and corporate tenants.',
    price: 250000,
    currency: 'KES',
    type: 'commercial',
    status: 'active',
    listingType: 'rent',
    location: {
      latitude: 0.5200,
      longitude: 35.2697,
      address: 'Uganda Road, Eldoret CBD',
      city: 'Eldoret',
      state: 'Uasin Gishu County',
      country: 'Kenya',
      neighborhood: 'Eldoret CBD',
      geoPoint: new admin.firestore.GeoPoint(0.5200, 35.2697),
    },
    bedrooms: null,
    bathrooms: 2,
    areaSqFt: 2400,
    floors: 12,
    yearBuilt: 2017,
    amenities: ['parking', 'guardhouse', 'elevator', 'airConditioning', 'fibre', 'generator', 'cctv'],
    agentId: 'agent_002',
    agentName: 'Amina Odhiambo',
    isFeatured: true,
    isApproved: true,
    viewCount: 62,
    savedCount: 8,
    imageUrls: [
      'https://images.unsplash.com/photo-1497366216548-37526070297c?w=1200',
      'https://images.unsplash.com/photo-1497366811353-6870744d04b2?w=1200',
    ],
    videoUrls: [],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-12')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-12')),
  },

  // ── 25. Ground-floor retail West Indies — KES 95,000/mo
  {
    title: 'Commercial Space for Rent — West Indies, Uganda Road',
    description:
      'Ground-floor commercial unit of 800 sq ft on busy Uganda Road, West Indies Estate. Open plan, tiled, with two washrooms. The building has a generator, lift, CCTV, and 2 reserved parking bays. Ideal for a salon, clinic, or office serving the West Indies community.',
    price: 95000,
    currency: 'KES',
    type: 'commercial',
    status: 'active',
    listingType: 'rent',
    location: {
      latitude: 0.5248,
      longitude: 35.2742,
      address: 'Uganda Road, West Indies Estate',
      city: 'Eldoret',
      state: 'Uasin Gishu County',
      country: 'Kenya',
      neighborhood: 'West Indies',
      geoPoint: new admin.firestore.GeoPoint(0.5248, 35.2742),
    },
    bedrooms: null,
    bathrooms: 2,
    areaSqFt: 800,
    floors: 8,
    yearBuilt: 2015,
    amenities: ['generator', 'cctv', 'elevator', 'parking', 'guardhouse'],
    agentId: 'agent_001',
    agentName: 'James Kamau',
    isFeatured: false,
    isApproved: true,
    viewCount: 44,
    savedCount: 6,
    imageUrls: [
      'https://images.unsplash.com/photo-1497366754035-f200968a6e72?w=1200',
      'https://images.unsplash.com/photo-1497366216548-37526070297c?w=1200',
    ],
    videoUrls: [],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-01')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-01')),
  },

  // ── 26. 0.125 acre plot Kapsoya — KES 2.8M
  {
    title: '0.125 Acre Plot for Sale — Kapsoya, Eldoret',
    description:
      'Clean title 0.125-acre plot (50x100 ft) in a surveyed and fenced subdivision in Kapsoya, Eldoret. Served by tarmac road, water, and electricity at the plot boundary. Ideal for residential construction close to schools and the Nakuru highway. Title ready.',
    price: 2800000,
    currency: 'KES',
    type: 'land',
    status: 'active',
    listingType: 'sale',
    location: {
      latitude: 0.5041,
      longitude: 35.2938,
      address: 'Kapsoya Estate, Nakuru Road',
      city: 'Eldoret',
      state: 'Uasin Gishu County',
      country: 'Kenya',
      neighborhood: 'Kapsoya',
      geoPoint: new admin.firestore.GeoPoint(0.5041, 35.2938),
    },
    bedrooms: null,
    bathrooms: null,
    areaSqFt: 5445,
    floors: null,
    yearBuilt: null,
    amenities: [],
    agentId: 'agent_001',
    agentName: 'James Kamau',
    isFeatured: false,
    isApproved: true,
    viewCount: 38,
    savedCount: 5,
    imageUrls: [
      'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=1200',
      'https://images.unsplash.com/photo-1464746133101-a2c3f88e0dd9?w=1200',
    ],
    videoUrls: [],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-09-28')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-09-28')),
  },
];

// ─── Seed Function ────────────────────────────────────────────────────────────
async function seed() {
  console.log('🌱 Starting NestIQ Firestore seed...\n');

  // Seed agents
  console.log('👤 Seeding agents...');
  for (const agent of agents) {
    await db.collection('agents').doc(agent.id).set(agent.data);
    console.log(`   ✅ Agent: ${agent.data.displayName}`);
  }

  // Seed properties
  console.log('\n🏠 Seeding properties...');
  for (const property of properties) {
    const searchPrefixes = buildSearchPrefixes(
      property.title,
      property.location,
      property.type,
      property.listingType,
      property.bedrooms,
      property.agentName,
      property.price
    );
    const withKeywords = {
      ...property,
      searchTitle: property.title.toLowerCase(),
      searchPrefixes,
    };
    const ref = await db.collection('properties').add(withKeywords);
    console.log(`   ✅ ${property.title} → ${ref.id}`);
  }

  console.log('\n✨ Seed complete!');
  console.log(`   ${agents.length} agents`);
  console.log(`   ${properties.length} properties`);
  console.log('\n📋 Next steps:');
  console.log('   1. Open Firebase Console → Firestore to verify the data');
  console.log('   2. Hot restart your Flutter app');
  console.log('   3. The home screen should now show real properties\n');

  process.exit(0);
}

seed().catch((err) => {
  console.error('❌ Seed failed:', err);
  process.exit(1);
});