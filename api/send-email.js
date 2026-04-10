const https = require('https');

module.exports = function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'POST only' });

  var RESEND_KEY = process.env.RESEND_API_KEY;
  if (!RESEND_KEY) return res.status(500).json({ error: 'RESEND_API_KEY not configured' });

  var body = req.body;
  if (!body.to || !body.subject || !body.html) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  var postData = JSON.stringify({
    from: 'BehaviorLog Pro <onboarding@resend.dev>',
    to: body.to,
    subject: body.subject,
    html: body.html
  });

  var options = {
    hostname: 'api.resend.com',
    path: '/emails',
    method: 'POST',
    headers: {
      'Authorization': 'Bearer ' + RESEND_KEY,
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(postData)
    }
  };

  var apiReq = https.request(options, function(apiRes) {
    var chunks = [];
    apiRes.on('data', function(chunk) { chunks.push(chunk); });
    apiRes.on('end', function() {
      try {
        var data = JSON.parse(Buffer.concat(chunks).toString());
        if (apiRes.statusCode >= 200 && apiRes.statusCode < 300) {
          res.status(200).json({ success: true, id: data.id });
        } else {
          res.status(apiRes.statusCode).json({ error: data.message || 'Send failed' });
        }
      } catch(e) {
        res.status(500).json({ error: 'Invalid response from email service' });
      }
    });
  });

  apiReq.on('error', function(err) {
    res.status(500).json({ error: err.message });
  });

  apiReq.write(postData);
  apiReq.end();
};
