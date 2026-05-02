// functions/index.js — Firebase Cloud Functions for NeedsBridge
// Deploy: firebase deploy --only functions  (requires Blaze plan)

const functions = require('firebase-functions');
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { initializeApp }    = require('firebase-admin/app');
const { getFirestore }      = require('firebase-admin/firestore');
const { getMessaging }      = require('firebase-admin/messaging');
const fetch = require('node-fetch');
const xml2js = require('xml2js');

initializeApp();
const db  = getFirestore();
const fcm = getMessaging();

const GEMINI_API_KEY = functions.config().gemini.key; // Use Firebase Functions Config
const GOOGLE_NEWS_RSS = 'https://news.google.com/rss/search?q=fire+OR+flood+OR+emergency+OR+accident+OR+disaster+Tamil+Nadu&hl=en-IN&gl=IN&ceid=IN:en';

// ── Helper: send to all users with a given role ────────────────────────────────
async function notifyRole(role, payload) {
  const snap = await db.collection('users').where('role', '==', role).get();
  const tokens = [];
  for (const userDoc of snap.docs) {
    const tokenSnap = await userDoc.ref.collection('fcmTokens').get();
    tokenSnap.forEach(t => { if (t.data().token) tokens.push(t.data().token); });
  }
  if (tokens.length === 0) return;
  await fcm.sendEachForMulticast({ tokens, notification: payload });
}

// ── Helper: send to a specific user by UID ────────────────────────────────────
async function notifyUser(uid, payload) {
  const tokenSnap = await db.collection('users').doc(uid)
      .collection('fcmTokens').get();
  const tokens = tokenSnap.docs.map(d => d.data().token).filter(Boolean);
  if (tokens.length === 0) return;
  await fcm.sendEachForMulticast({ tokens, notification: payload });
}

// ── Helper: Parse news headline with Gemini AI ────────────────────────────────
async function parseNewsHeadline(headline) {
  try {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{
            parts: [{
              text: `You are parsing news headlines into NGO emergency tickets.\nHeadline: "${headline}"\nRETURN EXACTLY: {"title": "<short description>", "location": "<extracted location or Unknown>", "priority": <1, 2 or 3>, "volunteersNeeded": <int>, "category": "<Fire|Flood|Medical|Infrastructure|Other>"}\nPriority: 1=HIGH (life risk, disaster, fire, flood, collapse, injury), 2=MEDIUM (infrastructure, power, water), 3=LOW (routine)`
            }]
          }],
          generationConfig: { response_mime_type: 'application/json' }
        })
      }
    );
    const json = await response.json();
    const text = json.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!text) return null;
    const cleaned = text.replace(/```json/gi, '').replace(/```/g, '').trim();
    return JSON.parse(cleaned);
  } catch (e) {
    console.error('Gemini parse error:', e);
    return null;
  }
}

// ── Helper: Check if headline already exists in Firestore ─────────────────────
async function isDuplicateHeadline(headline) {
  const normalized = headline.toLowerCase().trim();
  const recentSnap = await db.collection('news_headlines')
    .where('normalized', '==', normalized)
    .limit(1)
    .get();
  return !recentSnap.empty;
}

// ── Scheduled Function: Monitor Google News RSS every 10 minutes ──────────────
exports.monitorNewsFeeds = onSchedule('every 10 minutes', async (event) => {
  console.log('🔍 Fetching Google News RSS for Tamil Nadu emergencies...');
  
  try {
    const response = await fetch(GOOGLE_NEWS_RSS);
    const xmlText = await response.text();
    const parser = new xml2js.Parser();
    const result = await parser.parseStringPromise(xmlText);
    
    const items = result.rss?.channel?.[0]?.item || [];
    console.log(`Found ${items.length} news items`);
    
    let newTickets = 0;
    
    for (const item of items.slice(0, 5)) { // Process top 5 only
      const headline = item.title?.[0] || '';
      const link = item.link?.[0] || '';
      const pubDate = item.pubDate?.[0] || '';
      
      if (!headline) continue;
      
      // Skip if already processed
      if (await isDuplicateHeadline(headline)) {
        console.log(`⏭️  Skipping duplicate: ${headline.substring(0, 50)}...`);
        continue;
      }
      
      console.log(`📰 Processing: ${headline}`);
      
      // Parse with Gemini AI
      const parsed = await parseNewsHeadline(headline);
      if (!parsed) {
        console.log('❌ Failed to parse headline');
        continue;
      }
      
      // Create ticket in Firestore
      const docRef = await db.collection('needs').add({
        title: parsed.title || headline.substring(0, 100),
        location: parsed.location === 'Unknown' ? 'Tamil Nadu' : parsed.location,
        priority: parsed.priority || 2,
        volunteersNeeded: parsed.volunteersNeeded || 5,
        category: parsed.category || 'Other',
        status: 'Response',
        reportCount: 1,
        source: 'news_auto',
        newsUrl: link,
        newsHeadline: headline,
        aiPending: false,
        createdAt: new Date(),
      });
      
      // Store headline to prevent duplicates
      await db.collection('news_headlines').add({
        headline: headline,
        normalized: headline.toLowerCase().trim(),
        processedAt: new Date(),
        ticketId: docRef.id,
      });
      
      // Log audit
      await db.collection('needs').doc(docRef.id).collection('history').add({
        action: `Auto-created from news: ${headline}`,
        by: 'System (News Monitor)',
        at: new Date(),
      });
      
      newTickets++;
      console.log(`✅ Created ticket: ${docRef.id}`);
    }
    
    console.log(`✨ News monitoring complete. Created ${newTickets} new tickets.`);
    
    // Notify management if new tickets were created
    if (newTickets > 0) {
      await notifyRole('management', {
        title: '📰 News Alert',
        body: `${newTickets} new emergency ${newTickets === 1 ? 'issue' : 'issues'} detected from news sources`,
      });
    }
    
  } catch (error) {
    console.error('❌ News monitoring error:', error);
  }
});

// ── 1. New public issue → notify management ───────────────────────────────────
exports.onNeedCreated = onDocumentCreated('needs/{docId}', async (event) => {
  const data = event.data?.data();
  if (!data) return;
  await notifyRole('management', {
    title: '🆕 New Issue Reported',
    body: data.title || 'A new community issue needs assignment.',
  });
});

// ── 2. Status changes → notify the right people ───────────────────────────────
exports.onNeedStatusChanged = onDocumentUpdated('needs/{docId}', async (event) => {
  const before = event.data?.before?.data();
  const after  = event.data?.after?.data();
  if (!before || !after || before.status === after.status) return;

  const title  = after.title || 'Issue Update';

  // Verification Assigned → notify assigned field staff (by name lookup)
  if (after.status === 'Verification Assigned' && after.assignedFieldStaff) {
    const staffSnap = await db.collection('users')
        .where('displayName', '==', after.assignedFieldStaff).limit(1).get();
    if (!staffSnap.empty) {
      await notifyUser(staffSnap.docs[0].id, {
        title: '📋 Verification Assigned to You',
        body: `Please verify: ${title}`,
      });
    }
  }

  // Assigned (to volunteers) → notify management of completion ready
  if (after.status === 'Assigned') {
    await notifyRole('management', {
      title: '✅ Volunteers Assigned',
      body: `"${title}" has been assigned to ${after.assignedTo || 'volunteers'}.`,
    });
  }

  // Completed → notify executive
  if (after.status === 'Completed') {
    await notifyRole('executive', {
      title: '🎉 Issue Resolved',
      body: `"${title}" has been marked as completed.`,
    });
  }
});

// ── 3. History entry added → notify relevant roles ────────────────────────────
exports.onHistoryEntryCreated = onDocumentCreated('needs/{needId}/history/{historyId}', async (event) => {
  const historyData = event.data?.data();
  if (!historyData) {
    console.log('No data found for new history entry.');
    return;
  }

  const needId = event.params.needId;
  const needSnap = await db.collection('needs').doc(needId).get();
  const needData = needSnap.data();

  if (!needData) {
    console.error(`Need document ${needId} not found for history entry.`);
    return;
  }

  const title = needData.title || 'Issue Update';
  const reportAction = historyData.action || 'A new report was added.';
  const reportedBy = historyData.by || 'Unknown Staff';

  // Notify management and executive about the new report
  const notificationBody = `By ${reportedBy}: ${reportAction.substring(0, 100)}${reportAction.length > 100 ? '...' : ''}`;
  await notifyRole('management', {
    title: `📝 New Report for: ${title}`,
    body: notificationBody,
  });
  await notifyRole('executive', {
    title: `📝 New Report for: ${title}`,
    body: notificationBody,
  });

  console.log(`Notification sent for new report on need ${needId}`);
});
