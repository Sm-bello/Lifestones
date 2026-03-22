const { AccessToken } = require('livekit-server-sdk');
const http = require('http');
const url = require('url');

require('dotenv').config({ path: '../.env' });

const API_KEY = process.env.LIVEKIT_API_KEY;
const API_SECRET = process.env.LIVEKIT_API_SECRET;

const server = http.createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');

  const { pathname, query } = url.parse(req.url, true);

  if (pathname === '/token') {
    const roomName = query.room || 'sanctuary';
    const participantName = query.name || 'Member';
    const role = query.role || 'member';

    const at = new AccessToken(API_KEY, API_SECRET, {
      identity: participantName,
    });

    at.addGrant({
      roomJoin: true,
      room: roomName,
      canPublish: true,      // everyone can speak
      canSubscribe: true,
      canPublishData: true,
    });

    const token = await at.toJwt();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ token, url: process.env.LIVEKIT_URL }));

  } else if (pathname === '/health') {
    res.writeHead(200);
    res.end('OK');
  } else {
    res.writeHead(404);
    res.end('Not found');
  }
});

server.listen(3000, () => {
  console.log('Token server running on port 3000');
});
