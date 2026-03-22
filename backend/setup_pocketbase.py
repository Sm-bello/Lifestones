import requests
import json
import sys

BASE = "http://127.0.0.1:8090"

print("="*55)
print("LIFESTONES POCKETBASE SETUP")
print("="*55)

# ── STEP 1: LOGIN ─────────────────────────────────────
print("\n1. Authenticating...")
login = requests.post(f"{BASE}/api/admins/auth-with-password", json={
    "identity": "admin@lifestones.app",
    "password": "Lifestones2025!"
})
if login.status_code != 200:
    print("Creating admin first...")
    requests.post(f"{BASE}/api/admins", json={
        "email": "admin@lifestones.app",
        "password": "Lifestones2025!",
        "passwordConfirm": "Lifestones2025!"
    })
    login = requests.post(f"{BASE}/api/admins/auth-with-password", json={
        "identity": "admin@lifestones.app",
        "password": "Lifestones2025!"
    })

token = login.json().get('token')
if not token:
    print("❌ Auth failed:", login.text)
    sys.exit(1)
print("✅ Authenticated!")
headers = {"Authorization": f"Bearer {token}",
           "Content-Type": "application/json"}

def create_collection(data):
    name = data['name']
    r = requests.post(f"{BASE}/api/collections",
        headers=headers, json=data)
    if r.status_code in [200, 201]:
        print(f"  ✅ {name}")
    elif 'already exists' in r.text:
        print(f"  ⚠️  {name} (already exists)")
    else:
        print(f"  ❌ {name}: {r.text[:80]}")

# ── STEP 2: COLLECTIONS ────────────────────────────────
print("\n2. Creating collections...")

# USERS (auth type - handles login)
create_collection({
    "name": "users",
    "type": "auth",
    "schema": [
        {"name": "displayName", "type": "text", "required": True},
        {"name": "role", "type": "select",
         "options": {"maxSelect": 1, "values": ["pastor", "member"]}},
        {"name": "bio", "type": "text"},
        {"name": "photoUrl", "type": "url"},
        {"name": "phone", "type": "text"},
        {"name": "banned", "type": "bool"},
        {"name": "chatApproved", "type": "bool"},
        {"name": "fcmToken", "type": "text"},
        {"name": "roleSetAt", "type": "date"},
        {"name": "classesAttended", "type": "number"},
        {"name": "lastSeenChat", "type": "date"},
    ],
    "options": {
        "allowEmailAuth": True,
        "allowOAuth2Auth": True,
        "allowUsernameAuth": False,
        "requireEmail": True,
    }
})

# MESSAGES
create_collection({
    "name": "messages",
    "type": "base",
    "schema": [
        {"name": "text", "type": "text", "required": True},
        {"name": "senderName", "type": "text"},
        {"name": "senderUid", "type": "text"},
        {"name": "senderPhoto", "type": "url"},
        {"name": "sentAt", "type": "date"},
        {"name": "type", "type": "select",
         "options": {"maxSelect": 1, "values": ["text","scripture","hymn"]}},
        {"name": "replyTo", "type": "json"},
        {"name": "reactions", "type": "json"},
    ]
})

# MEETINGS
create_collection({
    "name": "meetings",
    "type": "base",
    "schema": [
        {"name": "topic", "type": "text", "required": True},
        {"name": "roomCode", "type": "text"},
        {"name": "isLive", "type": "bool"},
        {"name": "starterName", "type": "text"},
        {"name": "starterUid", "type": "text"},
        {"name": "starterRole", "type": "text"},
        {"name": "participants", "type": "json"},
        {"name": "startedAt", "type": "date"},
        {"name": "endedAt", "type": "date"},
    ]
})

# RECORDINGS
create_collection({
    "name": "recordings",
    "type": "base",
    "schema": [
        {"name": "title", "type": "text"},
        {"name": "topic", "type": "text"},
        {"name": "roomCode", "type": "text"},
        {"name": "audioFile", "type": "file",
         "options": {"maxSelect": 1, "maxSize": 104857600}},
        {"name": "downloadUrl", "type": "url"},
        {"name": "uploadedBy", "type": "text"},
        {"name": "uploadedAt", "type": "date"},
        {"name": "endedAt", "type": "date"},
        {"name": "summary", "type": "text"},
    ]
})

# ATTENDANCE
create_collection({
    "name": "attendance",
    "type": "base",
    "schema": [
        {"name": "uid", "type": "text"},
        {"name": "name", "type": "text"},
        {"name": "roomCode", "type": "text"},
        {"name": "topic", "type": "text"},
        {"name": "role", "type": "text"},
        {"name": "joinedAt", "type": "date"},
    ]
})

# PRAYER REQUESTS
create_collection({
    "name": "prayer_requests",
    "type": "base",
    "schema": [
        {"name": "text", "type": "text", "required": True},
        {"name": "uid", "type": "text"},
        {"name": "name", "type": "text"},
        {"name": "photo", "type": "url"},
        {"name": "answered", "type": "bool"},
        {"name": "response", "type": "text"},
        {"name": "createdAt", "type": "date"},
    ]
})

# SCHEDULED MEETINGS
create_collection({
    "name": "scheduled_meetings",
    "type": "base",
    "schema": [
        {"name": "topic", "type": "text", "required": True},
        {"name": "scheduledAt", "type": "date", "required": True},
        {"name": "createdBy", "type": "text"},
        {"name": "roomCode", "type": "text"},
        {"name": "createdAt", "type": "date"},
    ]
})

# CHAT REQUESTS (approval system)
create_collection({
    "name": "chat_requests",
    "type": "base",
    "schema": [
        {"name": "uid", "type": "text"},
        {"name": "name", "type": "text"},
        {"name": "photo", "type": "url"},
        {"name": "status", "type": "select",
         "options": {"maxSelect": 1,
           "values": ["pending","approved","rejected"]}},
        {"name": "requestedAt", "type": "date"},
    ]
})

# TYPING INDICATORS
create_collection({
    "name": "typing",
    "type": "base",
    "schema": [
        {"name": "uid", "type": "text"},
        {"name": "name", "type": "text"},
        {"name": "isTyping", "type": "bool"},
        {"name": "updatedAt", "type": "date"},
    ]
})

# NOTIFICATIONS
create_collection({
    "name": "notifications",
    "type": "base",
    "schema": [
        {"name": "token", "type": "text"},
        {"name": "title", "type": "text"},
        {"name": "body", "type": "text"},
        {"name": "type", "type": "text"},
        {"name": "createdAt", "type": "date"},
    ]
})

# SETTINGS (replaces app_config)
create_collection({
    "name": "settings",
    "type": "base",
    "schema": [
        {"name": "key", "type": "text", "required": True},
        {"name": "value", "type": "text"},
    ]
})

# ── STEP 3: DEFAULT SETTINGS ───────────────────────────
print("\n3. Adding default settings...")
r = requests.post(f"{BASE}/api/collections/settings/records",
    headers=headers,
    json={"key": "pastor_pin", "value": "7749"})
print(f"  {'✅' if r.status_code in [200,201] else '❌'} pastor_pin: 7749")

# ── STEP 4: VERIFY ─────────────────────────────────────
print("\n4. Verifying...")
r = requests.get(f"{BASE}/api/collections", headers=headers)
if r.status_code == 200:
    cols = r.json().get('items', [])
    print(f"  ✅ {len(cols)} collections created")
    for c in cols:
        print(f"    - {c['name']} ({c['type']})")

print("\n" + "="*55)
print("✅ POCKETBASE SETUP COMPLETE!")
print(f"Admin dashboard: {BASE}/_/")
print("="*55)
