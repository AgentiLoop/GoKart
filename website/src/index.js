import { EmailMessage } from "cloudflare:email";
export { Lobby } from "./lobby.js";

const json = (o, status = 200) =>
  new Response(JSON.stringify(o), { status, headers: { "content-type": "application/json", "cache-control": "no-store" } });

const clean = (s, n) => String(s ?? "").replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g, "").trim().slice(0, n);
const oneLine = (s, n) => clean(s, n).replace(/[\r\n]+/g, " ");

function rawEmail(from, to, subject, replyTo, body) {
  const enc = (s) => /^[\x20-\x7e]*$/.test(s) ? s : "=?UTF-8?B?" + btoa(String.fromCharCode(...new TextEncoder().encode(s))) + "?=";
  const bytes = new TextEncoder().encode(body.replace(/\r?\n/g, "\r\n"));
  let bin = ""; for (const b of bytes) bin += String.fromCharCode(b);
  const b64 = btoa(bin).replace(/(.{76})/g, "$1\r\n");
  const lines = [
    `From: GoKart Feedback <${from}>`,
    `To: ${to}`,
    `Subject: ${enc(subject)}`,
    replyTo ? `Reply-To: ${replyTo}` : null,
    `Message-ID: <${crypto.randomUUID()}@gokart.games>`,
    `Date: ${new Date().toUTCString()}`,
    "MIME-Version: 1.0",
    'Content-Type: text/plain; charset="UTF-8"',
    "Content-Transfer-Encoding: base64",
    "",
    b64,
  ].filter((l) => l !== null);
  return lines.join("\r\n");
}

async function feedback(request, env, ctx) {
  if (request.headers.get("content-type")?.split(";")[0] !== "application/json") return json({ error: "Bad request." }, 415);
  let d;
  try { d = await request.json(); } catch { return json({ error: "Bad request." }, 400); }
  if (clean(d.website, 50)) return json({ ok: true }); // honeypot: pretend success
  const message = clean(d.message, 4000);
  if (message.length < 3) return json({ error: "Please write a message first." }, 400);
  const email = oneLine(d.email, 120);
  if (email && !/^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$/.test(email)) return json({ error: "That email address does not look right." }, 400);

  // Rate limit: 5 per hour per IP (best effort, KV is eventually consistent).
  const ip = request.headers.get("cf-connecting-ip") || "unknown";
  const rlKey = `rl:${ip}:${Math.floor(Date.now() / 3600000)}`;
  const used = parseInt((await env.FEEDBACK.get(rlKey)) || "0", 10);
  if (used >= 5) return json({ error: "Too many messages from your network. Please try again later." }, 429);
  await env.FEEDBACK.put(rlKey, String(used + 1), { expirationTtl: 7200 });

  const entry = {
    at: new Date().toISOString(),
    name: oneLine(d.name, 80),
    email,
    type: oneLine(d.type, 30),
    platform: oneLine(d.platform, 30),
    message,
    country: request.cf?.country || "",
  };
  const id = `fb:${entry.at}:${crypto.randomUUID().slice(0, 8)}`;
  await env.FEEDBACK.put(id, JSON.stringify(entry));

  const subject = `[GoKart] ${entry.type || "Feedback"}${entry.platform ? " (" + entry.platform + ")" : ""}`;
  const body = `${entry.type} from ${entry.name || "anonymous"} <${entry.email || "no email given"}>\nPlatform: ${entry.platform}\nCountry: ${entry.country}\nTime: ${entry.at}\n\n${entry.message}\n`;
  try {
    const msg = new EmailMessage(env.FROM, env.TO, rawEmail(env.FROM, env.TO, subject, entry.email, body));
    await env.EMAIL.send(msg);
  } catch (e) {
    console.log("email send failed:", e && e.message); // stored in KV regardless
  }
  return json({ ok: true });
}

const HSTS = "max-age=31536000; includeSubDomains";
const CSP = "default-src 'self'; script-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; connect-src 'self' wss:; object-src 'none'; base-uri 'self'; frame-ancestors 'self'";

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (url.protocol === "http:") { url.protocol = "https:"; return Response.redirect(url.toString(), 301); }
    if (url.pathname === "/api/feedback") {
      if (request.method !== "POST") return json({ error: "POST only." }, 405);
      return feedback(request, env, ctx);
    }
    if (url.pathname === "/api/mp" || url.pathname === "/api/mp/status") {
      return env.LOBBY.get(env.LOBBY.idFromName("global")).fetch(request);
    }
    if (url.hostname === "www.gokart.games") { url.hostname = "gokart.games"; return Response.redirect(url.toString(), 301); }
    const res = await env.ASSETS.fetch(request);
    const h = new Headers(res.headers);
    h.set("x-content-type-options", "nosniff");
    h.set("referrer-policy", "strict-origin-when-cross-origin");
    h.set("strict-transport-security", HSTS);
    h.set("content-security-policy", CSP);
    h.set("x-frame-options", "SAMEORIGIN");
    return new Response(res.body, { status: res.status, statusText: res.statusText, headers: h });
  },
};
