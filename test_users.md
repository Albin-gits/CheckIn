// Test admin user creation script
// Run this in Firebase Console or through a separate script

// Admin user credentials for testing:
// Email: admin@checkin.com
// Password: admin123
//
// After creating the user in Firebase Authentication,
// add this document to Firestore users collection:
/_
{
"email": "admin@checkin.com",
"name": "System Administrator",
"role": "admin",
"isActive": true,
"createdAt": new Date()
}
_/

// Teacher test user:
// Email: teacher@checkin.com
// Password: teacher123
// Role: teacher
// classId: "BBA-1A"

// Student test user:
// Email: student@checkin.com  
// Password: student123
// Role: student
// classId: "BBA-1A"
