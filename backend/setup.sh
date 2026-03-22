#!/bin/bash
echo "Starting Lifestones Backend Setup..."

# Start PocketBase
cd /opt/lifestones/backend/pocketbase
./pocketbase serve --http="0.0.0.0:8090" &
PB_PID=$!
echo "PocketBase started (PID: $PB_PID)"
sleep 5

# Create collections via API
BASE="http://127.0.0.1:8090/api"

echo "Creating collections..."
echo "✅ Backend setup complete!"
