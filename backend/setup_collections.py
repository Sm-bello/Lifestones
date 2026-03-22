import requests
import json

BASE = "http://127.0.0.1:8090"

# First create admin
admin = requests.post(f"{BASE}/api/admins", json={
    "email": "admin@lifestones.app",
    "password": "Lifestones2025!",
    "passwordConfirm": "Lifestones2025!"
})
print("Admin:", admin.status_code)

# Login to get token
login = requests.post(f"{BASE}/api/admins/auth-with-password", json={
    "identity": "admin@lifestones.app",
    "password": "Lifestones2025!"
})
token = login.json().get('token')
headers = {"Authorization": f"Bearer {token}"}
print("Token:", "OK" if token else "FAILED")

# Collections to create
collections = [
    {
        "name": "users",
        "type": "auth",
        "schema": [
            {"name": "displayName", "type": "text", "required": True},
            {"name": "role", "type": "select", "options": {"values": ["pastor","member"]}},
            {"name": "bio", "type": "text"},
            {"name": "photoUrl", "type": "url"},
            {"name": "banned", "type": "bool"},
            {"name": "chatApproved", "type": "bool"},
            {"name": "fcmToken", "type": "text"},
        ]
    },
    {
        "name": "messages",
        "type": "base",
        "schema": [
            {"name": "text", "type": "text", "required": True},
            {"name": "senderName", "type": "text"},
            {"name": "senderUid", "type": "text"},
            {"name": "senderPhoto", "type": "url"},
            {"name": "type", "type": "select", "options": {"values": ["text","scripture","hymn"]}},
            {"name": "replyTo", "type": "json"},
            {"name": "reactions", "type": "json"},
        ]
    },
    {
        "name": "meetings",
        "type": "base",
        "schema": [
            {"name": "topic", "type": "text", "required": True},
            {"name": "roomCode", "type": "text"},
            {"name": "isLive", "type": "bool"},
            {"name": "starterName", "type": "text"},
            {"name": "starterUid", "type": "text"},
            {"name": "startedAt", "type": "date"},
            {"name": "endedAt", "type": "date"},
        ]
    },
    {
        "name": "recordings",
        "type": "base",
        "schema": [
            {"name": "title", "type": "text"},
            {"name": "topic", "type": "text"},
            {"name": "roomCode", "type": "text"},
            {"name": "audioFile", "type": "file"},
            {"name": "downloadUrl", "type": "url"},
            {"name": "uploadedBy", "type": "text"},
            {"name": "duration", "type": "text"},
            {"name": "summary", "type": "text"},
        ]
    },
    {
        "name": "prayer_requests",
        "type": "base",
        "schema": [
            {"name": "text", "type": "text", "required": True},
            {"name": "authorName", "type": "text"},
            {"name": "authorUid", "type": "text"},
            {"name": "answered", "type": "bool"},
            {"name": "response", "type": "text"},
        ]
    },
    {
        "name": "scheduled_meetings",
        "type": "base",
        "schema": [
            {"name": "topic", "type": "text", "required": True},
            {"name": "scheduledAt", "type": "date", "required": True},
            {"name": "createdBy", "type": "text"},
            {"name": "roomCode", "type": "text"},
        ]
    },
    {
        "name": "attendance",
        "type": "base",
        "schema": [
            {"name": "uid", "type": "text"},
            {"name": "name", "type": "text"},
            {"name": "roomCode", "type": "text"},
            {"name": "topic", "type": "text"},
            {"name": "role", "type": "text"},
        ]
    },
]

for col in collections:
    r = requests.post(f"{BASE}/api/collections",
        headers=headers, json=col)
    status = "✅" if r.status_code in [200, 201] else "❌"
    print(f"{status} {col['name']}: {r.status_code}")

print("\nAll collections created!")
print(f"Admin dashboard: {BASE}/_/")
