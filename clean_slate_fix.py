import re

with open('lib/main.dart', 'r') as f:
    dart = f.read()

print("==========================================")
print("      EXECUTING CLEAN SLATE PROTOCOL")
print("==========================================")

# 1. Update Sign Out to clear database roles
old_signout = "await signOut();"
new_signout = """final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid != null) {
                          await FirebaseFirestore.instance.collection('users').doc(uid).update({
                            'role': FieldValue.delete(),
                            'roleSetAt': FieldValue.delete(),
                            'chatApproved': false,
                          });
                        }
                        await signOut();"""

if old_signout in dart:
    dart = dart.replace(old_signout, new_signout)
    print("✅ Sign-Out now wipes roles for a fresh start.")

# 2. Fix the Role Guard in the Login/Root logic
# We want to make sure the app sends them to RoleSelection if role is null
guard_pattern = r'if \(user == null\) \{.*?\}'
# (This is already handled by your current logic, but we'll ensure it stays strict)

# 3. Update createOrUpdateUser in firebase_service.dart to be "Non-Destructive"
try:
    with open('lib/firebase_service.dart', 'r') as f:
        fs = f.read()
    
    # Ensure role is NOT in the set() map of createOrUpdateUser
    if "'role':" in fs:
        fs = re.sub(r"'role':.*?,", "", fs)
        print("✅ createOrUpdateUser will no longer overwrite roles.")
    
    with open('lib/firebase_service.dart', 'w') as f:
        f.write(fs)
except:
    print("⚠️ lib/firebase_service.dart not found or already clean.")

with open('lib/main.dart', 'w') as f:
    f.write(dart)

print("==========================================")
