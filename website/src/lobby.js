// GoKart multiplayer lobby: matchmaking + WebRTC signaling relay.
// Clients open a WebSocket to /api/mp. The server only groups 2-4 players into a room and relays
// SDP offers/answers/ICE candidates between them; once the WebRTC mesh is up all racing traffic
// flows peer-to-peer and the game closes this socket.
//
// Client -> server
//   {t:"hello", name, version, course, room?, create?}  quick match (no room) or private room code
//   {t:"start"}                                          host starts early (needs >= 2 players)
//   {t:"sig", to, data}                                  relay signaling data to a room member
// Server -> client
//   {t:"room", code, you, host, players:[{id,name}], countdown}   lobby state (countdown secs or -1)
//   {t:"start", you, players, course, seed}                         race begins, build the mesh
//   {t:"sig", from, data}                                           relayed signaling data
//   {t:"left", id}                                                  member left the lobby
//   {t:"error", message}

const MAX_PLAYERS = 4;
const AUTO_START_SECS = 20; // public rooms start this long after the 2nd player joins
const SIGNAL_GRACE_MS = 90_000; // sockets of a started room are closed after this

const clean = (s, n) => String(s ?? "").replace(/[\u0000-\u001f\u007f]/g, "").trim().slice(0, n);

export class Lobby {
  constructor(state, env) {
    this.state = state;
    this.clients = new Map(); // ws -> {id, name, room}
    this.rooms = new Map(); // code -> {code, public, version, course, members: ws[], started, deadline, timer}
  }

  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname.endsWith("/status")) {
      let waiting = 0, racing = 0;
      for (const r of this.rooms.values()) (r.started ? (racing += r.members.length) : (waiting += r.members.length));
      return new Response(JSON.stringify({ waiting, racing, rooms: this.rooms.size }), {
        headers: { "content-type": "application/json", "cache-control": "no-store" },
      });
    }
    if (request.headers.get("upgrade") !== "websocket") return new Response("Expected WebSocket", { status: 426 });
    const pair = new WebSocketPair();
    const ws = pair[1];
    ws.accept();
    this.clients.set(ws, { id: 0, name: "", room: null });
    ws.addEventListener("message", (ev) => this.onMessage(ws, ev.data));
    ws.addEventListener("close", () => this.drop(ws));
    ws.addEventListener("error", () => this.drop(ws));
    return new Response(null, { status: 101, webSocket: pair[0] });
  }

  send(ws, o) {
    try { ws.send(JSON.stringify(o)); } catch { this.drop(ws); }
  }

  onMessage(ws, raw) {
    const c = this.clients.get(ws);
    if (!c) return;
    if (typeof raw !== "string" || raw.length > 16384) return;
    let m;
    try { m = JSON.parse(raw); } catch { return; }
    if (!m || typeof m !== "object") return;
    if (m.t === "hello" && !c.room) return this.hello(ws, c, m);
    const room = c.room && this.rooms.get(c.room);
    if (!room) return;
    if (m.t === "start") {
      if (!room.started && this.hostOf(room) === c.id && room.members.length >= 2) this.start(room);
    } else if (m.t === "sig") {
      const to = room.members.find((w) => this.clients.get(w)?.id === m.to);
      if (to) this.send(to, { t: "sig", from: c.id, data: m.data });
    }
  }

  hello(ws, c, m) {
    c.name = clean(m.name, 16) || "Player";
    const version = clean(m.version, 16);
    const code = clean(m.room, 8).toUpperCase().replace(/[^A-Z0-9]/g, "");
    let room = null;
    if (code) {
      room = this.rooms.get(code);
      if (!room) {
        if (!m.create) return this.send(ws, { t: "error", message: `Room ${code} not found.` });
        room = this.newRoom(code, false, version, clean(m.course, 40));
      }
      if (room.started) return this.send(ws, { t: "error", message: `Room ${code} already started.` });
      if (room.members.length >= MAX_PLAYERS) return this.send(ws, { t: "error", message: `Room ${code} is full.` });
      if (room.version !== version) return this.send(ws, { t: "error", message: `Room ${code} runs GoKart ${room.version}.` });
    } else {
      for (const r of this.rooms.values()) {
        if (r.public && !r.started && r.version === version && r.members.length < MAX_PLAYERS) { room = r; break; }
      }
      if (!room) room = this.newRoom(this.freshCode(), true, version, clean(m.course, 40));
    }
    const used = new Set(room.members.map((w) => this.clients.get(w).id));
    c.id = 1;
    while (used.has(c.id)) c.id++;
    c.room = room.code;
    room.members.push(ws);
    if (room.public && room.members.length >= 2 && !room.deadline) room.deadline = Date.now() + AUTO_START_SECS * 1000;
    if (room.members.length >= MAX_PLAYERS && room.public) return this.start(room);
    this.broadcastRoom(room);
    this.schedule(room);
  }

  newRoom(code, isPublic, version, course) {
    const room = { code, public: isPublic, version, course, members: [], started: false, deadline: 0, timer: null };
    this.rooms.set(code, room);
    return room;
  }

  freshCode() {
    const abc = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    for (;;) {
      let s = "";
      for (let i = 0; i < 4; i++) s += abc[Math.floor(Math.random() * abc.length)];
      if (!this.rooms.has(s)) return s;
    }
  }

  hostOf(room) {
    return Math.min(...room.members.map((w) => this.clients.get(w).id));
  }

  players(room) {
    return room.members.map((w) => this.clients.get(w)).map((c) => ({ id: c.id, name: c.name })).sort((a, b) => a.id - b.id);
  }

  broadcastRoom(room) {
    const countdown = room.deadline ? Math.max(0, Math.ceil((room.deadline - Date.now()) / 1000)) : -1;
    const players = this.players(room);
    const host = this.hostOf(room);
    for (const w of room.members) this.send(w, { t: "room", code: room.code, public: room.public, you: this.clients.get(w).id, host, players, countdown });
  }

  // Re-broadcast the countdown once a second and start the room when it runs out.
  schedule(room) {
    clearTimeout(room.timer);
    if (room.started || !room.deadline) return;
    room.timer = setTimeout(() => {
      if (!this.rooms.has(room.code) || room.started) return;
      if (room.members.length < 2) { room.deadline = 0; this.broadcastRoom(room); return; }
      if (Date.now() >= room.deadline) return this.start(room);
      this.broadcastRoom(room);
      this.schedule(room);
    }, 1000);
  }

  start(room) {
    clearTimeout(room.timer);
    room.started = true;
    const players = this.players(room);
    const seed = Math.floor(Math.random() * 2147483647);
    for (const w of room.members) this.send(w, { t: "start", code: room.code, you: this.clients.get(w).id, players, course: room.course, seed });
    room.timer = setTimeout(() => {
      for (const w of [...room.members]) { try { w.close(1000, "signaling done"); } catch {} this.drop(w); }
    }, SIGNAL_GRACE_MS);
  }

  drop(ws) {
    const c = this.clients.get(ws);
    if (!c) return;
    this.clients.delete(ws);
    const room = c.room && this.rooms.get(c.room);
    if (!room) return;
    room.members = room.members.filter((w) => w !== ws);
    if (room.members.length === 0) {
      clearTimeout(room.timer);
      this.rooms.delete(room.code);
      return;
    }
    // Once started, peers close this socket as soon as their mesh is up, so a close is not a
    // disconnect from the race; WebRTC reports those directly.
    if (!room.started) {
      for (const w of room.members) this.send(w, { t: "left", id: c.id });
      if (room.members.length < 2) room.deadline = 0;
      this.broadcastRoom(room);
      this.schedule(room);
    }
  }
}
