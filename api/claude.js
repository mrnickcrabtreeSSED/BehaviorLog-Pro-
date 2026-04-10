const https = require('https');

module.exports = function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'POST only' });

  var API_KEY = process.env.ANTHROPIC_API_KEY;
  if (!API_KEY) return res.status(500).json({ error: 'ANTHROPIC_API_KEY not configured' });

  var postData = JSON.stringify(req.body);

  var options = {
    hostname: 'api.anthropic.com',
    path: '/v1/messages',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': API_KEY,
      'anthropic-version': '2023-06-01',
      'Content-Length': Buffer.byteLength(postData)
    }
  };

  var apiReq = https.request(options, function(apiRes) {
    var chunks = [];
    apiRes.on('data', function(chunk) { chunks.push(chunk); });
    apiRes.on('end', function() {
      try {
        var data = JSON.parse(Buffer.concat(chunks).toString());
        res.status(apiRes.statusCode).json(data);
      } catch(e) {
        res.status(500).json({ error: 'Invalid response from API' });
      }
    });
  });

  apiReq.on('error', function(err) {
    res.status(500).json({ error: err.message });
  });

  apiReq.write(postData);
  apiReq.end();
};
