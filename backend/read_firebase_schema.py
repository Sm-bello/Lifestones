import json
import os

# Read firebase_service.dart to extract all collection names and fields
with open('lib/firebase_service.dart', 'r') as f:
    fs = f.read()

with open('lib/main.dart', 'r') as f:
    dart = f.read()

print("="*60)
print("FIREBASE SCHEMA ANALYSIS")
print("="*60)

import re

# Find all collection names
collections = set(re.findall(r"collection\('(\w+)'\)", fs + dart))
print(f"\n📦 COLLECTIONS FOUND ({len(collections)}):")
for c in sorted(collections):
    print(f"  - {c}")

# Find all fields being written to each collection
print("\n📋 FIELDS PER COLLECTION:")
for col in sorted(collections):
    # Find all .add({ and .set({ calls for this collection
    pattern = rf"collection\('{col}'\).*?\.(?:add|set)\({{(.*?)}}\)"
    matches = re.findall(pattern, fs + dart, re.DOTALL)
    
    fields = set()
    for match in matches:
        # Extract field names
        field_names = re.findall(r"'(\w+)':", match)
        fields.update(field_names)
    
    if fields:
        print(f"\n  {col}:")
        for f in sorted(fields):
            print(f"    - {f}")

# Find all queries (filters)
print("\n🔍 QUERIES USED:")
queries = re.findall(r"\.where\('(\w+)',\s*isEqualTo:\s*([^)]+)\)", fs + dart)
for field, val in queries:
    print(f"  - where({field} == {val.strip()})")

queries2 = re.findall(r"\.orderBy\('(\w+)'", fs + dart)
for field in set(queries2):
    print(f"  - orderBy({field})")

# Find all Firebase Storage paths
print("\n📁 STORAGE PATHS:")
storage = re.findall(r"ref\('([^']+)'\)", fs + dart)
for s in set(storage):
    print(f"  - {s}")

# Check auth methods used
print("\n🔐 AUTH METHODS:")
auth_methods = []
if 'signInWithGoogle' in dart: auth_methods.append('Google Sign-In')
if 'createUserWithEmailAndPassword' in dart: auth_methods.append('Email/Password signup')
if 'signInWithEmailAndPassword' in dart: auth_methods.append('Email/Password login')
if 'signOut' in dart: auth_methods.append('Sign out')
if 'currentUser' in dart: auth_methods.append('Current user check')
for m in auth_methods:
    print(f"  - {m}")

print("\n" + "="*60)
print("POCKETBASE MAPPING:")
print("="*60)
print("""
Firebase Collection → PocketBase Collection
─────────────────────────────────────────────
users               → users (auth type)
messages            → messages (base type)  
meetings            → meetings (base type)
recordings          → recordings (base type)
attendance          → attendance (base type)
prayer_requests     → prayer_requests (base type)
scheduled_meetings  → scheduled_meetings (base type)
notifications       → notifications (base type)
app_config          → settings (base type)

Firebase Auth       → PocketBase Auth
─────────────────────────────────────────────
Google Sign-In      → OAuth2 (Google provider)
currentUser.uid     → record.id
currentUser.email   → record.email
currentUser.displayName → record.name

Firebase Storage    → PocketBase Files
─────────────────────────────────────────────
profiles/{uid}.jpg  → users collection avatar field
recordings/{room}   → recordings collection audioFile field
""")
