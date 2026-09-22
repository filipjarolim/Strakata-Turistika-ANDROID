/**
 * Fix visits where screenshot/manual km was stored but not scored into points.
 *
 * Usage:
 *   node fix_undercounted_visits.js
 *   node fix_undercounted_visits.js --apply
 */
const { MongoClient, ObjectId } = require('/private/tmp/node_modules/mongodb');
const fs = require('fs');

const APPLY = process.argv.includes('--apply');
const envPath = '/Users/filipjarolim/Developer/AndroidStudioProjects/strakataturistikaandroidapp/.env';
const uri = fs.readFileSync(envPath, 'utf8').match(/DATABASE_URL="([^"]+)"/)[1];

function toNum(v) {
  if (v == null || v === '') return null;
  if (typeof v === 'number' && Number.isFinite(v) && v > 0) return v;
  if (typeof v === 'string') {
    const n = parseFloat(v.replace(',', '.').trim());
    return Number.isFinite(n) && n > 0 ? n : null;
  }
  return null;
}

function readDistanceKm(doc) {
  for (const c of [
    doc.distanceKm,
    doc.extraData?.distanceKm,
    doc.extraData?.distance,
    doc.extraPoints?.distanceKm,
    doc.extraPoints?.distance,
  ]) {
    const n = toNum(c);
    if (n != null) return n;
  }
  const meters = toNum(doc.route?.totalDistance);
  if (meters != null && meters > 50) return meters / 1000;
  return null;
}

function placePoints(places, typeMap, fallbackMap) {
  if (!Array.isArray(places) || places.length === 0) return 0;
  let sum = 0;
  for (const p of places) {
    const t = (p?.type || '').toString();
    if (typeMap.has(t)) sum += typeMap.get(t);
    else if (fallbackMap[t] != null) sum += fallbackMap[t];
  }
  return sum;
}

const round2 = (n) => Math.round(n * 100) / 100;

async function main() {
  const client = new MongoClient(uri);
  await client.connect();
  const db = client.db();

  const scoring =
    (await db.collection('scoring_configs').findOne({ active: true })) || {};
  const pointsPerKm = toNum(scoring.pointsPerKm) ?? 1.0;
  const fallbackMap = scoring.placeTypePoints || {
    PEAK: 1,
    TOWER: 1,
    RUINS: 1,
    TREE: 1,
    CAVE: 1,
    UNUSUAL_NAME: 1,
    OTHER: 0,
  };

  const typeMap = new Map();
  for (const pt of await db.collection('place_type_configs').find({}).toArray()) {
    if (pt.name) typeMap.set(pt.name, Number(pt.points) || 0);
  }

  console.log(`pointsPerKm=${pointsPerKm} | placeTypes=${typeMap.size} | mode=${APPLY ? 'APPLY' : 'DRY-RUN'}`);
  console.log('place type points:', Object.fromEntries(typeMap));

  // Screenshot / manual path only — the known bug. Skip unfinished GPS drafts.
  const visits = await db
    .collection('visits')
    .find({
      $and: [
        {
          $or: [
            { 'extraPoints.source': 'screenshot' },
            { 'extraData.source': 'screenshot' },
            {
              $and: [
                { $or: [{ route: null }, { route: { $exists: false } }, { 'route.totalDistance': { $exists: false } }] },
                {
                  $or: [
                    { 'extraData.distance': { $exists: true } },
                    { 'extraData.distanceKm': { $exists: true } },
                    { distanceKm: { $gt: 0 } },
                  ],
                },
              ],
            },
          ],
        },
        {
          $or: [
            { seasonYear: 2026 },
            { year: 2026 },
            { visitDate: { $gte: new Date('2026-01-01') } },
            { createdAt: { $gte: new Date('2026-01-01') } },
          ],
        },
        { state: { $in: ['PENDING_REVIEW', 'APPROVED', 'REJECTED'] } },
      ],
    })
    .toArray();

  console.log(`\nCandidates loaded: ${visits.length}`);

  const toFix = [];
  for (const v of visits) {
    const km = readDistanceKm(v);
    if (km == null) continue;
    // Nonsense / typo distances (e.g. 1024) — do not auto-award huge points
    if (km > 100) {
      console.log(`SKIP outlier distance ${round2(km)} km: ${v._id} "${v.routeTitle}"`);
      continue;
    }
    const placePts = placePoints(v.places, typeMap, fallbackMap);
    const expected = round2(placePts + km * pointsPerKm);
    const current = round2(toNum(v.points) ?? 0);
    const looksLikePlaceOnly =
      Math.abs(current - placePts) < 0.35 && km * pointsPerKm >= 0.5;
    const clearlyLow = expected - current >= 0.9;
    if (!(looksLikePlaceOnly || clearlyLow)) continue;

    const source =
      v.extraPoints?.source || v.extraData?.source || 'unknown';
    // Prefer explicit screenshot; also allow missing source if place-only pattern
    if (source !== 'screenshot' && !looksLikePlaceOnly) continue;
    // Skip pure GPS tracking leftovers
    if (source === 'gps_tracking' || source === 'gpx_upload') continue;

    toFix.push({
      id: v._id.toString(),
      title: v.routeTitle || '(bez názvu)',
      state: v.state,
      user:
        v.user?.name ||
        v.displayName ||
        v.fullName ||
        v.extraPoints?.fullName ||
        v.extraData?.fullName ||
        v.extraData?.['Příjmení a jméno'] ||
        '?',
      dog: v.dogName || '',
      km: round2(km),
      placePts: round2(placePts),
      current,
      expected,
      delta: round2(expected - current),
      source,
      places: (v.places || []).map((p) => `${p.name}[${p.type}]`).join(', '),
      rejectionReason: v.rejectionReason || null,
    });
  }

  toFix.sort((a, b) => b.delta - a.delta);
  console.log(`\nWill fix: ${toFix.length}\n`);
  for (const u of toFix) {
    console.log(
      `${u.id} | ${u.state.padEnd(15)} | ${String(u.user).slice(0, 22).padEnd(22)} | "${u.title}" | ${u.km} km | ${u.current} → ${u.expected} (+${u.delta})`
    );
  }

  const oheb = toFix.find((u) => /oheb/i.test(u.title));
  if (oheb) {
    console.log('\nOheb match:', JSON.stringify(oheb, null, 2));
  }

  if (APPLY && toFix.length) {
    let updated = 0;
    for (const u of toFix) {
      // App/Prisma ukládá _id jako string (i když vypadá jako ObjectId hex).
      const filters = [{ _id: u.id }];
      if (u.id.length === 24 && /^[a-f0-9]+$/i.test(u.id)) {
        filters.push({ _id: new ObjectId(u.id) });
      }
      let done = false;
      for (const filter of filters) {
        const res = await db.collection('visits').updateOne(filter, {
          $set: {
            points: u.expected,
            distanceKm: u.km,
            'extraPoints.points': u.expected,
            'extraPoints.distanceKm': u.km,
            'extraPoints.distance': u.km,
            _pointsRecalcAt: new Date(),
            _pointsRecalcNote:
              'Fixed missing km points (screenshot/manual distance bug) 2026-09-20',
          },
        });
        if (res.matchedCount === 1) {
          updated += res.modifiedCount;
          done = true;
          break;
        }
      }
      if (!done) console.warn('No match for', u.id);
    }
    console.log(`\nUpdated ${updated}/${toFix.length}`);
  } else if (!APPLY) {
    console.log('\nDry-run. Re-run with --apply to write.');
  }

  await client.close();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
