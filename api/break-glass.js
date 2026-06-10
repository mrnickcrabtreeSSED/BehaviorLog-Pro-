// Founder "break glass" — mints a real session for a target user so a SureStep
// founder can log in AS them for troubleshooting. Server-only: needs the Supabase
// service_role key (god-mode), which must NEVER reach the client. Verifies the
// caller is a founder, audits every use (scoped to the target's district), and
// returns the target's session tokens. Target is given by email (preferred).
const https = require('https');

const SUPABASE_HOST = (process.env.SUPABASE_URL || 'https://jroporggvvmgrczdhnme.supabase.co')
  .replace(/^https?:\/\//, '').replace(/\/$/, '');
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

function api(method, path, headers, body) {
  return new Promise((resolve, reject) => {
    const data = body != null ? JSON.stringify(body) : null;
    const opts = { hostname: SUPABASE_HOST, path: path, method: method,
      headers: Object.assign({ 'Content-Type': 'application/json' }, headers || {}) };
    if (data) opts.headers['Content-Length'] = Buffer.byteLength(data);
    const r = https.request(opts, function (res) {
      const chunks = [];
      res.on('data', function (c) { chunks.push(c); });
      res.on('end', function () {
        const txt = Buffer.concat(chunks).toString();
        let json = null; try { json = txt ? JSON.parse(txt) : null; } catch (e) {}
        resolve({ status: res.statusCode, json: json, txt: txt });
      });
    });
    r.on('error', reject);
    if (data) r.write(data);
    r.end();
  });
}

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'POST only' });
  if (!SERVICE_KEY) return res.status(500).json({ error: 'SUPABASE_SERVICE_ROLE_KEY not configured' });

  const authz = req.headers['authorization'] || req.headers['Authorization'] || '';
  const token = authz.replace(/^Bearer\s+/i, '');
  if (!token) return res.status(401).json({ error: 'Missing bearer token' });

  const emailIn = (req.body && req.body.target_email || '').toLowerCase().trim();
  const idIn = req.body && (req.body.target_user_id || req.body.targetId);
  if (!emailIn && !idIn) return res.status(400).json({ error: 'target_email or target_user_id required' });

  const svc = { 'apikey': SERVICE_KEY, 'Authorization': 'Bearer ' + SERVICE_KEY };
  try {
    // 1. Identify the caller from their access token.
    const me = await api('GET', '/auth/v1/user', { 'Authorization': 'Bearer ' + token, 'apikey': SERVICE_KEY });
    if (me.status !== 200 || !me.json || !me.json.id) return res.status(401).json({ error: 'Invalid session' });
    const callerId = me.json.id, callerEmail = (me.json.email || '').toLowerCase();

    // 2. Caller MUST be a founder (checked against the DB, never trusting the client).
    const roleRes = await api('GET', '/rest/v1/user_roles?select=role&user_id=eq.' + callerId, svc);
    const callerRole = roleRes.json && roleRes.json[0] && roleRes.json[0].role;
    if (callerRole !== 'founder') return res.status(403).json({ error: 'Founder access required' });

    // 3. Resolve the target email (look it up from id if only an id was given).
    let targetEmail = emailIn;
    if (!targetEmail && idIn) {
      const tu = await api('GET', '/auth/v1/admin/users/' + idIn, svc);
      if (tu.status !== 200 || !tu.json || !tu.json.email) return res.status(404).json({ error: 'Target user not found' });
      targetEmail = (tu.json.email || '').toLowerCase();
    }
    if (targetEmail === callerEmail) return res.status(400).json({ error: 'Cannot break-glass into your own account' });

    // 4. Mint a session for the target: admin generate_link (magiclink OTP) -> verify.
    const link = await api('POST', '/auth/v1/admin/generate_link', svc, { type: 'magiclink', email: targetEmail });
    if (link.status >= 400) return res.status(404).json({ error: 'No such user in this system', detail: link.json || link.txt });
    const props = (link.json && link.json.properties) || link.json || {};
    const otp = props.email_otp;
    const targetId = (link.json && link.json.id) || idIn || null;
    if (!otp) return res.status(500).json({ error: 'Could not generate login link', detail: link.json || link.txt });
    const verify = await api('POST', '/auth/v1/verify', { 'apikey': SERVICE_KEY },
      { type: 'magiclink', email: targetEmail, token: otp });
    if (verify.status !== 200 || !verify.json || !verify.json.access_token) {
      return res.status(500).json({ error: 'Could not mint target session', detail: verify.json || verify.txt });
    }

    // 5. Resolve the target's district so the audit row is scoped to that district.
    let districtId = null;
    if (targetId) {
      const dr = await api('GET', '/rest/v1/user_roles?select=district_id&user_id=eq.' + targetId, svc);
      districtId = (dr.json && dr.json[0] && dr.json[0].district_id) || null;
    }

    // 6. Audit (scoped to the target's district).
    await api('POST', '/rest/v1/audit_log', Object.assign({ 'Prefer': 'return=minimal' }, svc),
      { actor_id: callerId, actor_email: callerEmail, action: 'break_glass',
        target_user_id: targetId, target_email: targetEmail, district_id: districtId, detail: { via: 'founder_console' } });

    // 7. Hand the target's session back to the founder's browser.
    return res.status(200).json({
      access_token: verify.json.access_token,
      refresh_token: verify.json.refresh_token,
      target: { id: targetId, email: targetEmail }
    });
  } catch (e) {
    return res.status(500).json({ error: e.message || 'break-glass failed' });
  }
};
