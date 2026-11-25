import { Router } from 'express';
import {
  config,
  googleOAuthEnabled,
  createUserToken,
  verifyUserToken,
  createOAuthState,
  verifyOAuthState
} from './config.js';
import { asyncHandler, strictAuthRateLimit, adminRateLimit, requireAdminAuth } from './middleware.js';
import { HttpError } from './lib/http.js';
import { upsertUserProfile, getUserById, updateUserLibrary, getUserStats } from './lib/user-store.js';

function resolveBaseUrl(req) {
  if (config.publicBaseUrl) return config.publicBaseUrl;
  const rawProto = req.get('x-forwarded-proto')?.split(',')[0]?.trim() || req.protocol || 'https';
  const proto = rawProto === 'http' ? 'http' : 'https';
  const rawHost = String(req.get('x-forwarded-host')?.split(',')[0]?.trim() || req.get('host') || 'localhost:3000');
  const host = rawHost.replace(/[^a-zA-Z0-9.:_-]/g, '');
  return `${proto}://${host}`;
}

function escapeHtml(text) {
  return String(text || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function requireUserAuth(req) {
  const raw = req.get('x-user-token')
    || (req.get('authorization')?.startsWith('Bearer ') ? req.get('authorization').slice(7).trim() : null);
  const claims = verifyUserToken(raw);
  if (!claims || !claims.sub) {
    throw new HttpError('valid user session token required', 401);
  }
  return claims;
}

const router = Router();

router.get('/auth/status', strictAuthRateLimit, (req, res) => {
  res.json({
    success: true,
    googleOAuthConfigured: googleOAuthEnabled()
  });
});

router.get('/auth/google/start', strictAuthRateLimit, (req, res) => {
  if (!googleOAuthEnabled()) {
    return res.status(503).json({
      success: false,
      error: 'sign-in currently unavailable'
    });
  }

  const platform = req.query.platform === 'web' ? 'web' : 'flutter';
  const baseUrl = resolveBaseUrl(req);
  const redirectUri = `${baseUrl}/api/auth/google/callback`;
  const state = createOAuthState({ platform });

  const params = new URLSearchParams({
    client_id: config.googleClientId,
    redirect_uri: redirectUri,
    response_type: 'code',
    scope: 'openid email profile',
    access_type: 'online',
    prompt: 'select_account',
    state
  });

  res.redirect(`https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`);
});

router.get(['/auth/google/callback', '/auth/google/callback/'], asyncHandler(async (req, res) => {
  const { code, state, error: oauthErr } = req.query;
  const parsedState = verifyOAuthState(String(state || ''));
  if (!parsedState) {
    return res.status(400).send('<h2>Invalid or expired login state. Please try again from Lunarellys.</h2>');
  }

  const platform = parsedState.platform === 'web' ? 'web' : 'flutter';
  if (oauthErr) {
    if (platform === 'flutter') {
      return res.redirect(`lunarellys://auth?error=${encodeURIComponent(String(oauthErr))}`);
    }
    return res.status(400).send(`<h2>Google sign-in cancelled: ${escapeHtml(oauthErr)}</h2>`);
  }

  if (!code || !googleOAuthEnabled()) {
    return res.status(400).send('<h2>Missing authorization code or server OAuth configuration.</h2>');
  }

  const baseUrl = resolveBaseUrl(req);
  const redirectUri = `${baseUrl}/api/auth/google/callback`;

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      code: String(code),
      client_id: config.googleClientId,
      client_secret: config.googleClientSecret,
      redirect_uri: redirectUri,
      grant_type: 'authorization_code'
    })
  });

  const tokenJson = await tokenRes.json().catch(() => ({}));
  if (!tokenRes.ok || !tokenJson.access_token) {
    const msg = tokenJson.error_description || tokenJson.error || 'token exchange failed';
    if (platform === 'flutter') {
      return res.redirect(`lunarellys://auth?error=${encodeURIComponent(msg)}`);
    }
    return res.status(400).send(`<h2>Login failed: ${escapeHtml(msg)}</h2>`);
  }

  const userRes = await fetch('https://www.googleapis.com/oauth2/v3/userinfo', {
    headers: { Authorization: `Bearer ${tokenJson.access_token}` }
  });
  const profile = await userRes.json().catch(() => ({}));
  if (!userRes.ok || !profile.sub) {
    return res.status(502).send('<h2>Failed to retrieve Google account profile.</h2>');
  }

  const user = upsertUserProfile({
    id: `google:${profile.sub}`,
    email: profile.email || '',
    name: profile.name || profile.given_name || 'Google User',
    picture: profile.picture || ''
  });
  const sessionToken = createUserToken(user);

  if (platform === 'flutter') {
    const qs = new URLSearchParams({
      token: sessionToken,
      name: user.name,
      email: user.email,
      picture: user.picture
    });
    const deepLink = `lunarellys://auth?${qs.toString()}`;
    return res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Signed in to Lunarellys</title>
  <style>
    body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;background:#121212;color:#fff;font-family:system-ui,-apple-system,sans-serif;text-align:center;padding:24px;}
    .card{max-width:360px;background:#181818;border:1px solid #2a2a2a;border-radius:16px;padding:28px;}
    .btn{display:inline-block;margin-top:18px;padding:12px 24px;border-radius:999px;background:#1DB954;color:#000;font-weight:700;text-decoration:none;}
    p{color:#b3b3b3;font-size:14px;line-height:1.5;}
  </style>
</head>
<body>
  <div class="card">
    <h2>Welcome, ${escapeHtml(user.name)}</h2>
    <p>Returning to Lunarellys app...</p>
    <a class="btn" href="${escapeHtml(deepLink)}">Open Lunarellys</a>
  </div>
  <script>window.location.replace(${JSON.stringify(deepLink)});</script>
</body>
</html>`);
  }

  const webUser = JSON.stringify({
    token: sessionToken,
    user: { id: user.id, name: user.name, email: user.email, picture: user.picture }
  });
  return res.send(`<!DOCTYPE html><html><body style="background:#121212;color:#fff;font-family:sans-serif;text-align:center;padding:40px"><script>
    if (window.opener) {
      window.opener.postMessage({ type: 'LUNARELLYS_AUTH_SUCCESS', payload: ${webUser} }, '*');
      window.close();
    } else {
      window.location.href = '/';
    }
  </script><p>Signed in as ${escapeHtml(user.name)}. You can close this window.</p></body></html>`);
}));

router.get('/auth/me', (req, res) => {
  const claims = requireUserAuth(req);
  const user = getUserById(claims.sub) || {
    id: claims.sub,
    email: claims.email,
    name: claims.name,
    picture: ''
  };
  res.json({
    success: true,
    user: {
      id: user.id,
      name: user.name,
      email: user.email,
      picture: user.picture,
      lastLoginAt: user.lastLoginAt || null
    }
  });
});

router.get('/user/sync', (req, res) => {
  const claims = requireUserAuth(req);
  const user = getUserById(claims.sub);
  res.json({
    success: true,
    library: user?.library || {
      likedSongs: [],
      playlists: [],
      followedArtists: [],
      savedAlbums: [],
      savedPlaylists: [],
      recentlyPlayed: [],
      updatedAt: null
    }
  });
});

router.put('/user/sync', (req, res) => {
  const claims = requireUserAuth(req);
  if (!req.body || typeof req.body !== 'object' || Array.isArray(req.body)) {
    throw new HttpError('valid JSON library object required', 400);
  }
  let user = getUserById(claims.sub);
  if (!user) {
    user = upsertUserProfile({
      id: claims.sub,
      email: claims.email,
      name: claims.name,
      picture: ''
    });
  }
  const library = updateUserLibrary(claims.sub, req.body);
  res.json({ success: true, library });
});

router.post('/admin/verify', adminRateLimit, requireAdminAuth, (req, res) => {
  res.json({ success: true, admin: true });
});

router.get('/admin/stats', adminRateLimit, requireAdminAuth, (req, res) => {
  const baseUrl = resolveBaseUrl(req);
  res.json({
    success: true,
    uptime: Math.floor(process.uptime()),
    memoryMb: Number((process.memoryUsage().heapUsed / 1048576).toFixed(1)),
    node: process.version,
    googleOAuthConfigured: googleOAuthEnabled(),
    callbackUrl: `${baseUrl}/api/auth/google/callback`,
    users: getUserStats()
  });
});

export default router;
