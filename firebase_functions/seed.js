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
      bio: 'Senior property consultant with over 10 years experience in Nairobi real estate. Specializing in Westlands, Kilimani and Karen.',
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
      bio: 'Passionate about helping families find their perfect home. 7 years experience covering Runda, Muthaiga and Spring Valley.',
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

// ─── Prefix array builder ────────────────────────────────────────────────────
// For each word, stores every prefix so array-contains matches partial typing.
// "kilimani" → ['k','ki','kil','kili','kilim','kilima','kiliman','kilimani']
// Typing 'k' → array-contains: 'k' → matches instantly
function buildSearchPrefixes(title, location, type, listingType, bedrooms, agentName, price) {
  const prefixes = new Set();

  // Collect all meaningful words
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

  // For each word generate every prefix from length 1 upward
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
  // ── 1. Featured luxury penthouse
  {
    title: 'Luxury Penthouse with City Views',
    searchTitle: 'luxury penthouse with city views',
    description:
      'An extraordinary penthouse offering breathtaking panoramic views of Nairobi. Features soaring ceilings, floor-to-ceiling windows, and premium finishes throughout. The open-plan living area flows to a wraparound terrace perfect for entertaining. Chef kitchen with premium appliances.',
    price: 45000000,
    currency: 'KES',
    type: 'apartment',
    status: 'active',
    listingType: 'sale',
    location: {
      latitude: -1.2680,
      longitude: 36.8120,
      address: 'Waiyaki Way',
      city: 'Nairobi',
      state: 'Nairobi County',
      country: 'Kenya',
      neighborhood: 'Westlands',
      geoPoint: new admin.firestore.GeoPoint(-1.2680, 36.8120),
    },
    bedrooms: 3,
    bathrooms: 3,
    areaSqFt: 3200,
    floors: 28,
    yearBuilt: 2022,
    amenities: ['pool', 'gym', 'parking', 'security', 'balcony', 'elevator', 'airConditioning', 'wifi'],
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

  // ── 2. Featured Karen villa
  {
    title: 'Modern Villa in Karen',
    searchTitle: 'modern villa in karen',
    description:
      'Stunning 5-bedroom villa set on a half-acre landscaped compound in the prestigious Karen suburb. Features a heated swimming pool, staff quarters, double garage, and beautifully manicured gardens. Ideal for families seeking space and privacy.',
    price: 85000000,
    currency: 'KES',
    type: 'villa',
    status: 'active',
    listingType: 'sale',
    location: {
      latitude: -1.3320,
      longitude: 36.7120,
      address: 'Karen Road',
      city: 'Nairobi',
      state: 'Nairobi County',
      country: 'Kenya',
      neighborhood: 'Karen',
      geoPoint: new admin.firestore.GeoPoint(-1.3320, 36.7120),
    },
    bedrooms: 5,
    bathrooms: 4,
    areaSqFt: 5800,
    floors: 2,
    yearBuilt: 2019,
    amenities: ['pool', 'gym', 'parking', 'security', 'garden', 'airConditioning', 'wifi', 'furnished'],
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

  // ── 3. Kilimani apartment for rent
  {
    title: '2 Bedroom Apartment in Kilimani',
    searchTitle: '2 bedroom apartment in kilimani',
    description:
      'Spacious and well-finished 2-bedroom apartment in the heart of Kilimani. Walking distance to Yaya Centre and Junction Mall. Features a modern kitchen, ample storage, and a balcony with lovely green views. Secure compound with 24-hour security.',
    price: 85000,
    currency: 'KES',
    type: 'apartment',
    status: 'active',
    listingType: 'rent',
    location: {
      latitude: -1.2921,
      longitude: 36.7870,
      address: 'Argwings Kodhek Road',
      city: 'Nairobi',
      state: 'Nairobi County',
      country: 'Kenya',
      neighborhood: 'Kilimani',
      geoPoint: new admin.firestore.GeoPoint(-1.2921, 36.7870),
    },
    bedrooms: 2,
    bathrooms: 2,
    areaSqFt: 1100,
    floors: 5,
    yearBuilt: 2018,
    amenities: ['parking', 'security', 'balcony', 'elevator', 'wifi', 'airConditioning'],
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

  // ── 4. Runda family home
  {
    title: 'Family Home in Runda Estate',
    searchTitle: 'family home in runda estate',
    description:
      'Elegant 4-bedroom family home in the serene Runda Estate. Set on a generous plot with mature trees and a private garden. The home features a spacious living room, formal dining, modern kitchen, and a separate DSQ. Close to Runda Primary and the UN complex.',
    price: 65000000,
    currency: 'KES',
    type: 'house',
    status: 'active',
    listingType: 'sale',
    location: {
      latitude: -1.2200,
      longitude: 36.8050,
      address: 'Runda Estate',
      city: 'Nairobi',
      state: 'Nairobi County',
      country: 'Kenya',
      neighborhood: 'Runda',
      geoPoint: new admin.firestore.GeoPoint(-1.2200, 36.8050),
    },
    bedrooms: 4,
    bathrooms: 3,
    areaSqFt: 3800,
    floors: 2,
    yearBuilt: 2015,
    amenities: ['parking', 'security', 'garden', 'wifi', 'airConditioning'],
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

  // ── 5. Studio for rent in Westlands
  {
    title: 'Cozy Studio Apartment — Westlands',
    searchTitle: 'cozy studio apartment westlands',
    description:
      'Fully furnished studio apartment ideal for young professionals. Located minutes from Sarit Centre and major corporate offices in Westlands. Includes high-speed WiFi, Netflix-ready TV, and a fully equipped kitchenette. All utilities included in rent.',
    price: 35000,
    currency: 'KES',
    type: 'studio',
    status: 'active',
    listingType: 'rent',
    location: {
      latitude: -1.2641,
      longitude: 36.8083,
      address: 'Mpaka Road',
      city: 'Nairobi',
      state: 'Nairobi County',
      country: 'Kenya',
      neighborhood: 'Westlands',
      geoPoint: new admin.firestore.GeoPoint(-1.2641, 36.8083),
    },
    bedrooms: 1,
    bathrooms: 1,
    areaSqFt: 450,
    floors: 3,
    yearBuilt: 2020,
    amenities: ['security', 'elevator', 'wifi', 'airConditioning', 'furnished'],
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

  // ── 6. Commercial office space CBD
  {
    title: 'Prime Office Space — Upper Hill',
    searchTitle: 'prime office space upper hill',
    description:
      'Grade A office space available in one of Upper Hill\'s most prestigious buildings. Open plan floor suitable for 20-30 workstations. Features raised floors, VRV air conditioning, backup generator, and 3 dedicated parking bays. Ideal for financial services and corporate tenants.',
    price: 250000,
    currency: 'KES',
    type: 'commercial',
    status: 'active',
    listingType: 'rent',
    location: {
      latitude: -1.2989,
      longitude: 36.8175,
      address: 'Upper Hill Road',
      city: 'Nairobi',
      state: 'Nairobi County',
      country: 'Kenya',
      neighborhood: 'Upper Hill',
      geoPoint: new admin.firestore.GeoPoint(-1.2989, 36.8175),
    },
    bedrooms: null,
    bathrooms: 2,
    areaSqFt: 2400,
    floors: 12,
    yearBuilt: 2017,
    amenities: ['parking', 'security', 'elevator', 'airConditioning', 'wifi'],
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

  // ── 7. Lavington townhouse for rent
  {
    title: '3 Bedroom Townhouse — Lavington',
    searchTitle: '3 bedroom townhouse lavington',
    description:
      'Beautiful 3-bedroom townhouse in a quiet gated community in Lavington. Freshly painted with new wooden floors throughout. Features an en-suite master bedroom, modern fitted kitchen, and a small private garden. Pet friendly. Close to Lavington Mall and international schools.',
    price: 120000,
    currency: 'KES',
    type: 'house',
    status: 'active',
    listingType: 'rent',
    location: {
      latitude: -1.2830,
      longitude: 36.7750,
      address: 'James Gichuru Road',
      city: 'Nairobi',
      state: 'Nairobi County',
      country: 'Kenya',
      neighborhood: 'Lavington',
      geoPoint: new admin.firestore.GeoPoint(-1.2830, 36.7750),
    },
    bedrooms: 3,
    bathrooms: 3,
    areaSqFt: 2100,
    floors: 2,
    yearBuilt: 2016,
    amenities: ['parking', 'security', 'garden', 'wifi', 'petFriendly'],
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

  // ── 8. Muthaiga luxury home
  {
    title: 'Exclusive Residence — Muthaiga',
    searchTitle: 'exclusive residence muthaiga',
    description:
      'One of Muthaiga\'s finest homes available for sale. This magnificent 6-bedroom residence sits on a 1-acre landscaped compound with a heated pool, tennis court, and 4-car garage. Designed by a renowned Nairobi architect with imported Italian finishes throughout.',
    price: 180000000,
    currency: 'KES',
    type: 'villa',
    status: 'active',
    listingType: 'sale',
    location: {
      latitude: -1.2480,
      longitude: 36.8330,
      address: 'Muthaiga Road',
      city: 'Nairobi',
      state: 'Nairobi County',
      country: 'Kenya',
      neighborhood: 'Muthaiga',
      geoPoint: new admin.firestore.GeoPoint(-1.2480, 36.8330),
    },
    bedrooms: 6,
    bathrooms: 6,
    areaSqFt: 8500,
    floors: 2,
    yearBuilt: 2021,
    amenities: ['pool', 'gym', 'parking', 'security', 'garden', 'balcony', 'elevator', 'airConditioning', 'wifi', 'furnished', 'waterfront'],
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
    // Build prefix array for partial typing search
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