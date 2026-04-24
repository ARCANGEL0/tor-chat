#!/usr/bin/env node

//╶┬╴╭─╮╭─╮   ╭─╮╭─╴╷  ╭─╮╷ ╷   ╭─╮╭─╮╭─╮
// │ │ │├┬╯   ├┬╯├╴ │  ├─┤╰┬╯   ├─╯╭─╯├─╯
// ╵ ╰─╯╵╰╴   ╵╰╴╰─╴╰─╴╵ ╵ ╵    ╵  ╰─╴╵  
//╭─╴╭─╮╭┬╮╭┬╮╷ ╷╭╮╷╷╭─╴╭─╮╶┬╴╷╭─╮╭╮╷    
//│  │ ││││││││││ ││╰┤││  ├─┤ │ ││ ││╰┤    
//╰─╴╰─╯╵ ╵╵ ╵╰─╯╵ ╵╵╰─╴╵ ╵ ╵ ╵╰─╯╵ ╵    
// ============================================================
// TorChat - Anonymous P2P Channel via Tor Hidden Service
// ============================================================

log(`[!] S t a r t i n g  e n c r y p t e d  c h a t`, "GREEN");

const { spawn, execSync } = require("child_process");
const http = require("http");
const https = require("https");
const path = require("path");
const fs = require("fs");
const os = require("os");
const net = require("net");
const readline = require("readline");
const { createRequire } = require("module");
const SCRDIR = __dirname;
const SCRFILE = __filename;
const SCRNODES = path.join(SCRDIR, "node_modules");
const SCRCMD = `node ${path.basename(SCRFILE)}`;
const screq = createRequire(SCRFILE);

const CFG = {
  port: 1337,
  socksPort: 19050,  
  timeout: 120000,
  colors: { r: "\x1b[0m", dim: "\x1b[2m", bold: "\x1b[1m",
    green: "\x1b[32m", red: "\x1b[31m", yellow: "\x1b[33m",
    cyan: "\x1b[36m", magenta: "\x1b[35m", white: "\x1b[97m",
    blue: "\x1b[34m" }}

let ST = {
  username: null,
  color: null,
  ws: null,
  serverPass: null,
  torProc: null,
  torDataDir: null,
  torHSdir: null,
  port: CFG.port,
  socksPort: CFG.socksPort,
  inChat: false
};

let WS = null;
let WSS = null;
let SocksA = null;

const $ = (c) => CFG.colors[c] || "";
const log = (msg, c = "white") => console.log(`${$(c)}${msg}${$("r")}`);
const die = (err) => { log(err?.message || err, "red"); cleanup(); process.exit(1); };

const DEPS = ["ws", "socks-proxy-agent"];
function get_nodepath() {
  return (process.env.NODE_PATH || "")
    .split(path.delimiter)
    .map((entry) => entry.trim())
    .filter(Boolean)}

function get_nodModules() {
  const npm = process.platform === "win32" ? "npm.cmd" : "npm";
  try {
    const npmRoot = execSync(`${npm} root -g`, {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"]
    }).trim();
    return npmRoot || null;
  } catch { return null; }}

function mod_searchpaths() {
  const paths = [SCRDIR, SCRNODES, ...get_nodepath()];
  const gnm = get_nodModules();
  if (gnm) paths.push(gnm);
  return [...new Set(paths)] }

function reg_modpaths() {
  for (const p of mod_searchpaths()) {
        if (!module.paths.includes(p)) { module.paths.unshift(p)}} }

function resolveDep(dep) {
  for (const p of mod_searchpaths()) {
  try { return require.resolve(dep, { paths: [p] })   } catch {} }  return null 
}

function requireDep(dep) {
  const res = resolveDep(dep);
   if (res) return require(res);
    return screq(dep);
   }

function npm_installdeps() { execSync("npm install ws socks-proxy-agent", { stdio: "inherit" })}

// tor binaries for different os, by default they are already present when using git pull but.. just in case, it self checks and dwonloads
const TOR_BIN = {
  win32: { name: "tor.exe", url: "https://github.com/ARCANGEL0/tor-chat/raw/refs/heads/master/tor.exe" },
  linux: { name: "tor", url: "https://github.com/ARCANGEL0/tor-chat/raw/refs/heads/master/tor" },
  darwin: { name: "tor", url: "https://github.com/ARCANGEL0/tor-chat/raw/refs/heads/master/tor" }
};

function getTorInfo() {
      return TOR_BIN[process.platform] || TOR_BIN.linux }

function torPath() { return path.join(SCRDIR, getTorInfo().name)
}

function fixTorPerms(file) {
if (process.platform === "win32") return;
   try { fs.chmodSync(file, 0o755); } catch {}
 }

function torHere() {
  const file = torPath();
   if (!fs.existsSync(file)) return false;
    fixTorPerms(file);
   return true}

function grabFile(url, outFile, redirects = 5) {
  return new Promise((resolve, reject) => {
    const tmp = `${outFile}.tmp`;
    const client = url.startsWith("https:") ? https : http;
    try { fs.unlinkSync(tmp); } catch {}
    const req = client.get(url, { headers: { "User-Agent": "tor-chat/2.1" } }, (res) => {
      const code = res.statusCode || 0;
      if ([301, 302, 303, 307, 308].includes(code) && res.headers.location && redirects > 0) {
        res.resume();
        resolve(grabFile(new URL(res.headers.location, url).toString(), outFile, redirects - 1));
        return}
      if (code < 200 || code >= 300) 
        {
        res.resume();
        reject(new Error(`HTTP ${code} while fetching ${url}`));
        return;
      }



      const out = fs.createWriteStream(tmp);
      out.on("error", (e) => { try { fs.unlinkSync(tmp); } catch {} reject(e); });
      res.on("error", (e) => { try { fs.unlinkSync(tmp); } catch {} reject(e); });
      out.on("finish", () => {
        out.close(() => {
          try {
            fs.renameSync(tmp, outFile);
            fixTorPerms(outFile);
            resolve(outFile);
          } 
             catch (e) {
            try { fs.unlinkSync(tmp); } catch {}
            reject(e);
          }});
      })
          res.pipe(out);
    })

    req.on("error", (e) => { try { fs.unlinkSync(tmp); } catch {} reject(e); });
  })
    }

function load_deps() { // load dependencies precheck
  try {
    reg_modpaths();
    WS = requireDep("ws");
    WSS = WS.WebSocketServer;
    SocksA = requireDep("socks-proxy-agent").SocksProxyAgent;
    return true;
  } catch (e) {
    log(`[!] Failed to load dependencies: ${e.message}`, "red");
    return false;
  }
}

async function check_deps() { // check  dependencies or else installs it, verifies presence of nodde modules path
  const missing = [];
  reg_modpaths();
  
  for (const dep of DEPS) {
    if (!resolveDep(dep)) { missing.push(dep); }
  }
  
  if (missing.length === 0) return true;
  
  log(`::! Missing dependencies: ${missing.join(", ")}`, "yellow");
  log("[+] Running: npm install ws socks-proxy-agent", "cyan");
  try {
    npm_installdeps(); // autoinstall
    reg_modpaths();
    const unresolved = missing.filter((dep) => !resolveDep(dep));
    if (unresolved.length > 0) throw new Error(`Dependencies still unresolved after install: ${unresolved.join(", ")}`);
    log("[+] Dependencies installed!", "green");
    return true;
  } catch (e) {
    log(`[!] ${e.message}`, "red");
    log("  npm install ws socks-proxy-agent", "cyan");
    throw new Error("Dependency install failed") }
    }

function banner() {
  console.clear();
  console.log(`${$("green")}${$("bold")} 
  ████████╗ ██████╗ ██████╗     ██╗ ██████╗██╗  ██╗ █████╗ ████████╗
  ╚══██╔══╝██╔═══██╗██╔══██╗   ██╔╝██╔════╝██║  ██║██╔══██╗╚══██╔══╝
     ██║   ██║   ██║██████╔╝  ██╔╝ ██║     ███████║███████║   ██║
     ██║   ██║   ██║██╔══██╗ ██╔╝  ██║     ██╔══██║██╔══██║   ██║
     ██║   ╚██████╔╝██║  ██║██╔╝   ╚██████╗██║  ██║██║  ██║   ██║
     ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝
 ${$("r")}${$("dim")}             [ Secure P2P Chat via Tor Hidden Service ]${$("r")}\n`);
}

function usage() {
  banner();
  console.log(`
 ${$("dim")}Usage:${$("r")}
   ${SCRCMD} start       Start a new relay channel through TOR
   ${SCRCMD} connect     Connect to an onion relay

 ${$("dim")}Example:${$("r")}
   ${SCRCMD} start
   ${SCRCMD} connect ws://example.onion
 `)}

function cleanup() {
  if (ST.torProc && !ST.torProc.killed) {
    try { ST.torProc.kill("SIGTERM"); } catch {}
  }
  if (ST.torDataDir && fs.existsSync(ST.torDataDir)) {
    try { fs.rmSync(ST.torDataDir, { recursive: true, force: true }); } catch {}
  }}

function get_tor_executable() {return torPath()}

async function ensure_tor_available() {
  if (torHere()) return true
    return install_tor()
}

// check tor installation if present
async function install_tor() {
  const info = getTorInfo();
  const outFile = torPath();
  log(`[!] ${info.name} not in current dir, grabbing it...`, "yellow");

  try {
    await grabFile(info.url, outFile);
    if (!torHere()) throw new Error(`Downloaded ${info.name} but it still looks missing`);
    log(`[+] Tor ready: ${outFile}`, "green");
    return true;
  } 
    catch (e) {
    log(`[!] Auto download failed: ${e.message}`, "red");
    throw new Error(`Could not get ${info.name} for ${process.platform}`);
     }  }

     // here it starts TOR in background
async function torStart({ socksPort, hiddenServicePort = null }) {
  ST.torDataDir = path.join(os.tmpdir(), "torchat-" + Math.random().toString(36).slice(2, 9));
  ST.torHSdir = hiddenServicePort ? path.join(ST.torDataDir, "hidden_service") : null;

  fs.mkdirSync(ST.torDataDir, { recursive: true, mode: 0o700 });
  if (ST.torHSdir) { fs.mkdirSync(ST.torHSdir, { recursive: true, mode: 0o700 }); }
  // configs for torrc
  const torrcLines = [
    `DataDirectory ${ST.torDataDir}`,
    `SocksPort ${socksPort}`,
    "Log notice stdout",
    "SafeLogging 0",
    "RunAsDaemon 0",
  ];
  // default configurations for hidden service like port and IP (change accordingly if needed)
  if (hiddenServicePort) {
    torrcLines.push(`HiddenServiceDir ${ST.torHSdir}`);
    torrcLines.push(`HiddenServicePort 80 127.0.0.1:${hiddenServicePort}`);
    torrcLines.push("HiddenServiceVersion 3");
  } else { torrcLines.push("ClientOnly 1"); }
  const torrc = torrcLines.join("\n");
  const torrcPath = path.join(ST.torDataDir, "torrc");
  fs.writeFileSync(torrcPath, torrc);
  const torExe = get_tor_executable();
  // Tor running ^ 
  log(`[+] Using tor: ${torExe}`, "green");

  return new Promise((resolve, reject) => {
    ST.torProc = spawn(torExe, ["-f", torrcPath], {
      stdio: ["ignore", "pipe", "pipe"]         })

    let bootstrapped = false;
    const timeout = setTimeout(() => {
      if (!bootstrapped) reject(new Error("Tor bootstrap timeout"));
    }, CFG.timeout)

    ST.torProc.stdout.on("data", (data) => {
      const str = data.toString();
      const progress = str.match(/Bootstrapped (\d+)%/);
      if (progress) { log(`[>] Tor bootstrap ${progress[1]}%`, "dim"); }
      if (str.includes("Bootstrapped 100%")) {
        bootstrapped = true;
        clearTimeout(timeout);
        if (!hiddenServicePort) { resolve(true); return; }
        setTimeout(() => {
          const hostnameFile = path.join(ST.torHSdir, "hostname");
          if (fs.existsSync(hostnameFile)) {
            const hostname = fs.readFileSync(hostnameFile, "utf8").trim();
            if (hostname.endsWith(".onion")) { resolve(hostname); return; }
          }
          reject(new Error("Failed to get onion address"));
        }, 1500);
  } })

    ST.torProc.stderr.on("data", () => {});
    //fallback error
    ST.torProc.on("error", (e) => reject(new Error(`Tor error: ${e.message}`)));
    ST.torProc.on("exit", (c) => { if (!bootstrapped) reject(new Error(`Tor exited: ${c}`)); });
  });
}

async function start_torrc(port, socksPort) { return torStart({ socksPort, hiddenServicePort: port }); }
async function start_client_tor(socksPort) { return torStart({ socksPort }); }

function get_port(preferred) {
  return new Promise((resolve) => {
  const server = net.createServer();
     server.unref();
     server.once("error", () => resolve(get_port(0)));
    server.listen(preferred, "127.0.0.1", () => {
  const port = server.address().port;
    server.close(() => resolve(port));
    }) });
}

function make_color(idx) {
  const hue = (idx * 137.508) % 360;
  const sat = 75;
  const light = 60;
  const c = (1 - Math.abs(2 * light / 100 - 1)) * sat / 100;
  const x = c * (1 - Math.abs((hue / 60) % 2 - 1));
  const m = light / 100 - c / 2;
  let r, g, b;
  if (hue < 60) { r = c; g = x; b = 0; }
  else if (hue < 120) { r = x; g = c; b = 0; }
  else if (hue < 180) { r = 0; g = c; b = x; }
  else if (hue < 240) { r = 0; g = x; b = c; }
  else if (hue < 300) { r = x; g = 0; b = c; }
  else { r = c; g = 0; b = x; }
  r = Math.round((r + m) * 255);
  g = Math.round((g + m) * 255);
  b = Math.round((b + m) * 255);
  
  return `\x1b[38;2;${r};${g};${b}m`;
}


// util funcs
async function ask(q) {
  return new Promise((resolve) => {
  process.stdout.write(q);
  const onData = (data) => {
      const str = data.toString();
     if (str.includes('\n') || str.includes('\r')) {
      process.stdin.off('data', onData);
      const lines = str.split(/\r?\n/);
       resolve(lines[0]);
      }  }
    process.stdin.once('data', onData);  })   }

function send(msg) { if (ST.ws && ST.ws.readyState === 1) { ST.ws.send(JSON.stringify(msg))}}

function format_msg(msg) {
  const ts = `${$("cyan")}[${msg.ts}]${$("r")}`
  
  if (msg.type === "system") {
    if (msg.text.includes("connected")) { return `\n${$("green")}═══════ ${msg.text} ═══════${$("r")}\n`; } 
    else if (msg.text.includes("disconnected")) { return `\n${$("red")}═══════ ${msg.text} ═══════${$("r")}\n`; }
    return `\n${$("dim")}═══ ${msg.text} ═══${$("r")}\n`;
  }
  
  if (msg.type === "message") {
    const userColor = msg.color || $("white");
    const name = `${userColor}${$("bold")}${msg.username}${$("r")}`;
    return `${ts} ${userColor}▶${$("r")} ${name}${$("dim")}:${$("r")} ${$("white")}${msg.text}${$("r")}`;}
  
  return "";
}

function print_chat_msg(text) {
  process.stdout.write('\r\x1b[2K');
  process.stdout.write(text);
  process.stdout.write('\n');
  show_prompt();
}

function show_prompt() {
  if (!ST.username) return;
  const prompt = `${ST.color}${$("bold")}${ST.username}${$("r")}${$("dim")}>${$("r")} `;
  process.stdout.write(prompt);
}

async function chat_loop() {
  ST.inChat = true;
  show_prompt();
  process.stdin.setRawMode(true);
  process.stdin.resume();
  let input = '';
  process.stdin.on('data', (key) => {
    const char = key.toString();
    if (char === '\r' || char === '\n') {
    if (input.trim()) {
      if (input === "/quit" || input === "/exit" || input === "/q") {
      log("\nDisconnecting...", "yellow");
      cleanup();
      if (ST.ws) ST.ws.close();
      process.exit(0);
        }
        if (input.startsWith("/")) {
          process.stdout.write('\r\x1b[K');
        print_chat_msg(`${$("dim")}Commands: /quit /exit /q${$("r")}`);
        input = ''; return;
      }
      process.stdout.write('\r\x1b[K');
          send({ type: "message", text: input });
        } else { process.stdout.write('\r\x1b[K'); show_prompt(); }
        input = '';
  
      } else if (char === '\x7f' || char === '\b') {
    if (input.length > 0) { input = input.slice(0, -1); process.stdout.write('\b \b'); }
  } else if (char === '\x03') { console.log(); cleanup(); process.exit(0); }
  
  else if (char.charCodeAt(0) >= 32) { input += char; process.stdout.write(char); }  })}

function connect(url, opts = {}) {
  const agent = url.includes(".onion") 
    ? new SocksA(`socks5h://127.0.0.1:${opts.socksPort || 9050}`)
    : null;

    ST.ws = new WS(url, { agent, handshakeTimeout: 45000 });

    banner();
    log(`[>] Connecting to ${url}...`, "green");

    ST.ws.on("open", () => send({ type: "auth", password: opts.password || null }));
    
    ST.ws.on("message", (raw) => {
      const msg = JSON.parse(raw);
      if (msg.type === "prompt") {
        ask(`${$("dim")}Type your username:${$("r")} `).then((u) => send({ type: "username", username: u }));
    } 
    
    else if (msg.type === "ready") {
      ST.username = msg.username;
      ST.color = msg.color;
      log(`Connected as ${ST.color}${ST.username}${$("r")}\n`, "green");
      chat_loop();
  }
   else if (msg.type === "auth_failed") {
    print_chat_msg(`${$("red")}${msg.text || "Invalid password"}${$("r")}`);
    ask(`${$("yellow")}Password:${$("r")} `).then((pwd) => send({ type: "auth", password: pwd }));
    } else if (msg.type === "message" || msg.type === "system") {
        print_chat_msg(format_msg(msg));
      }
    } 
  )
    
  ST.ws.on("error", (e) => print_chat_msg(`\n${$("red")}Connection error: ${e.message}${$("r")}\n`));
  ST.ws.on("close", () => {
    print_chat_msg(`\n${$("red")}═══════ Disconnected ═══════${$("r")}\n`);
    ST.inChat = false;
    if (process.stdin.isTTY && typeof process.stdin.setRawMode === "function") {
      process.stdin.setRawMode(false);
    }
  }
 )
}



async function start_server() {
  banner();
  ST.serverPass = await ask(`${$("yellow")}[!] Set Relay Password ::${$("r")}${$("magenta")} [default: none]:${$("r")}`);
  ST.serverPass = ST.serverPass || null;
    try { await ensure_tor_available(); } catch { process.exit(1); }
    
    log("[+] Starting Tor in background...", "green");
    ST.port = await get_port(CFG.port);
    ST.socksPort = await get_port(CFG.socksPort);
const wss = new WSS({ host: "127.0.0.1", port: ST.port });
  const clients = new Set();
    let colorIdx = 0;
  const broadcast = (payload, filter = () => true) => {
    const data = JSON.stringify(payload);
    for (const c of clients) {
      if (filter(c) && c.socket.readyState === 1) { c.socket.send(data) }  }
  }
  const now = () => new Date().toLocaleTimeString();
  wss.on("connection", (socket) => {
    const client = { socket, authed: false, username: null, color: null };
    clients.add(client);
  socket.on("message", (data) => {
    let msg;
    try { msg = JSON.parse(data); } catch { return; }
    if (msg.type === "auth") {
        if (ST.serverPass && msg.password !== ST.serverPass) {
          socket.send(JSON.stringify({ type: "auth_failed", text: "[!] WRONG ACCESS CODE", ts: now() }));
          return;
        }
      client.authed = true;
      socket.send(JSON.stringify({ type: "prompt", step: "username" }));
      return  }
      if (!client.authed) return;
      if (msg.type === "username") {
        client.username = (msg.username || "").trim().slice(0, 32) || `anon-${Math.floor(Math.random() * 900 + 100)}`;
        client.color = make_color(colorIdx++);
        socket.send(JSON.stringify({ type: "ready", username: client.username, color: client.color, ts: now() }));
        broadcast({ type: "system", text: `${client.username} has connected!`, ts: now() }, c => c.authed && c.username && c !== client);
        return;
      }
      if (msg.type === "message" && client.username) {
        broadcast({ type: "message", username: client.username, color: client.color, text: msg.text, ts: now() }, c => c.authed && c.username);
      }
     }
    )
    socket.on("close", () => {
      clients.delete(client);
      if (client.authed && client.username) {
        broadcast({ type: "system", text: `${client.username} disconnected!`, ts: now() }, c => c.authed && c.username);
      }
    });
  })
  let onionUrl;
  try { onionUrl = await start_torrc(ST.port, ST.socksPort); } catch (e) { wss.close(); die(e); }
  console.log(`\n${$("cyan")}Server running on port ${ST.port}${$("r")}`);
  console.log(`${$("green")}[+] TOR RELAY LINK GENERATED\n -- Share this link with your team:${$("r")}`);
  console.log(`${$("magenta")}  ws://${onionUrl}${$("r")}\n`);
  await ask(`${$("yellow")}[Press Enter to join chat]${$("r")}`);
  connect(`ws://${onionUrl}`, { password: ST.serverPass, socksPort: ST.socksPort });
}

process.on("exit", cleanup);
  process.on("SIGINT", () => { console.log(); cleanup(); process.exit(0); });
  const args = process.argv.slice(2);
  const mode = args[0];
  async function main() {
    if (!mode) { usage(); process.exit(0); }

  if (!["start", "connect"].includes(mode)) { usage(); process.exit(1); }

  try {
    await check_deps();
    if (!load_deps()) { throw new Error("Dependencies could not be loaded after install"); }
  }
    catch (e) { log(`[!] ${e.message}`, "red"); process.exit(1); }
    
    if (mode === "start") { await start_server() }
  else if (mode === "connect") {
    const url = args[1];
    if (!url) { log("Usage: ./torchat connect <onion-url>", "red"); process.exit(1); }
    const pwd = await ask(`${$("yellow")}[::] Password:${$("r")} `);
    const wsUrl = url.startsWith("ws") ? url : `ws://${url}`;
    if (wsUrl.includes(".onion")) {
      try { await ensure_tor_available(); ST.socksPort = await get_port(CFG.socksPort); log("[+] Starting Tor in background...", "green"); await start_client_tor(ST.socksPort); } 
      catch (e) { die(e); }
    }
    connect(wsUrl, { password: pwd, socksPort: ST.socksPort });
  } else { usage(); }
}
main().catch(die);
