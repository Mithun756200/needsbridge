const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

initializeApp();
const db = getFirestore();

async function setAllToManagement() {
  console.log('Fetching users...');
  const snap = await db.collection('users').get();
  console.log(`Found ${snap.size} users.`);
  
  let batch = db.batch();
  let count = 0;
  
  for (const doc of snap.docs) {
    batch.update(doc.ref, { role: 'management' });
    count++;
    if (count % 400 === 0) {
      await batch.commit();
      batch = db.batch();
    }
  }
  
  if (count % 400 !== 0) {
    await batch.commit();
  }
  console.log('All users have been set to Management!');
}

setAllToManagement().catch(console.error);
