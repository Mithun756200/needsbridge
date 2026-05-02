import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../lib/firebase_options.dart';

void main() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  final volunteers = [
    // Fire Emergency Specialists
    {'name': 'Ravi Kumar', 'skills': 'Fire Safety, Rescue, First Aid, Emergency Response', 'location': 'Chennai', 'available': true, 'phone': '+91 98765 43210'},
    {'name': 'Arjun Reddy', 'skills': 'Fire Fighting, Rescue Operations, Emergency Medical', 'location': 'Coimbatore', 'available': true, 'phone': '+91 98765 43211'},
    {'name': 'Vikram Singh', 'skills': 'Fire Safety, First Aid, Evacuation Planning', 'location': 'Madurai', 'available': true, 'phone': '+91 98765 43212'},
    {'name': 'Karthik Raj', 'skills': 'Fire Response, Rescue, Emergency Coordination', 'location': 'Trichy', 'available': true, 'phone': '+91 98765 43213'},
    
    // Flood Emergency Specialists
    {'name': 'Priya Sharma', 'skills': 'Water Rescue, Swimming, Flood Response, Emergency', 'location': 'Chennai', 'available': true, 'phone': '+91 98765 43214'},
    {'name': 'Deepak Menon', 'skills': 'Flood Relief, Water Safety, Rescue Operations', 'location': 'Cuddalore', 'available': true, 'phone': '+91 98765 43215'},
    {'name': 'Anjali Nair', 'skills': 'Flood Response, Sanitation, Water Purification, Emergency', 'location': 'Thanjavur', 'available': true, 'phone': '+91 98765 43216'},
    {'name': 'Suresh Babu', 'skills': 'Water Rescue, Swimming, Flood Evacuation', 'location': 'Nagapattinam', 'available': true, 'phone': '+91 98765 43217'},
    
    // Multi-Skilled Emergency Responders
    {'name': 'Lakshmi Iyer', 'skills': 'Rescue, Fire Safety, Water Rescue, First Aid, Emergency', 'location': 'Chennai', 'available': true, 'phone': '+91 98765 43218'},
    {'name': 'Rajesh Kumar', 'skills': 'Emergency Response, Fire Fighting, Flood Relief, Medical', 'location': 'Salem', 'available': true, 'phone': '+91 98765 43219'},
    {'name': 'Meena Devi', 'skills': 'First Aid, Emergency Medical, Rescue Operations', 'location': 'Vellore', 'available': true, 'phone': '+91 98765 43220'},
    {'name': 'Arun Prakash', 'skills': 'Fire Safety, Water Rescue, Emergency Coordination', 'location': 'Tirunelveli', 'available': true, 'phone': '+91 98765 43221'},
    
    // Medical Emergency Support
    {'name': 'Dr. Kavitha Rao', 'skills': 'Medical, First Aid, Emergency Medical, Health', 'location': 'Chennai', 'available': true, 'phone': '+91 98765 43222'},
    {'name': 'Nurse Divya', 'skills': 'Medical, First Aid, Emergency Response, Health Care', 'location': 'Coimbatore', 'available': true, 'phone': '+91 98765 43223'},
    
    // Infrastructure & Support
    {'name': 'Ganesh Babu', 'skills': 'Engineering, Infrastructure Repair, Emergency Support', 'location': 'Madurai', 'available': true, 'phone': '+91 98765 43224'},
    {'name': 'Muthu Kumar', 'skills': 'Construction, Repair, Emergency Infrastructure', 'location': 'Erode', 'available': true, 'phone': '+91 98765 43225'},
  ];

  final db = FirebaseFirestore.instance;
  
  print('Adding ${volunteers.length} emergency volunteers...');
  
  for (final vol in volunteers) {
    await db.collection('staff_volunteers').add({
      ...vol,
      'createdAt': FieldValue.serverTimestamp(),
    });
    print('✅ Added: ${vol['name']} (${vol['skills']})');
  }
  
  print('\n🎉 Successfully added ${volunteers.length} volunteers!');
  print('They are now available for AI matching in the Management Dashboard.');
}
