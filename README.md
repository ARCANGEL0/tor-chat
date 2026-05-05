# TorChat 🧅

###  **Anonymous P2P Chat via Tor Hidden Service**

TorChat is a simple, encrypted peer-to-peer chat that runs over the Tor network. It creates a hidden service so you can chat anonymously through the TOR network, perfect for private conversations, IRC groupchats or related.

## ✰ Features

- ✅ **Anonymous** - Runs as a Tor hidden service with an  `.onion` address
- ✅ **P2P** - Direct connections between users, designed to be 1v1 conversation but can be used as a chat, while one user acts as a server to host the hidden service.
- ✅ **Automatic installer** - Includes Tor binary on repo for both UNIX and Windows, and if not available it autoinstalls based on OS, and also installs npm packages automatically `(only ws and socks-proxy-agent though)`, made to be easy for usage even with non-tech people. 
- ✅ **Server customization** - Set passwords for additional security besides the .onion address, making a second authentication required, also it is possible to be running multiple TOR services for the chat, this way you can have multiple torchats running if desired.

## λ Modus Operanti

1. Starts a Tor process in the background
2. Creates a hidden service (`.onion` address)
3. Sets up a WebSocket server on port 1337 (can be customizable)
4. Connects to Tor's SOCKS proxy (port 19050 by default, customizable too)
5. Generates and prints the service `.onion` URL to share with others. 
6. Tell your friends to clone the repo aswell, and use the node file to connect to your onion address provided.

## ⨠ Quick Start

```bash
# Clone the repo
git clone https://github.com/ARCANGEL0/tor-chat.git
cd tor-chat

# Run it as a server
node chat.js start
```

The script will:
- Check for Tor binary (if you clone the repo, it'll already come with TOR binaries)
- Install required npm packages (ws, socks-proxy-agent basically.)
- Start Tor and create hidden service
- Give you your `.onion` address to share

After this, tell them to clone the repo aswell and use it to connect to your address.

```bash
git clone https://github.com/ARCANGEL0/tor-chat.git
cd tor-chat
node chat.js connect ws://torhiddenservicelink.onion
```

After connecting, the user will be prompted the chat password you've defined, and then to select an username and then
<strong>start chatting through TOR encryption!</strong>

## 𒀖 Requirements

- Node.js (v14+ recommended)
- npm (for auto-installing dependencies)

<div align="center">

### ❤️ Support

[![Star on GitHub](https://img.shields.io/github/stars/ARCANGEL0/tor-chat?style=social)](https://github.com/ARCANGEL0/tor-chat)
[![Follow on GitHub](https://img.shields.io/github/followers/ARCANGEL0?style=social)](https://github.com/ARCANGEL0)
<br>

<a href='https://ko-fi.com/J3J7WTYV7' target='_blank'><img height='36' style='border:0px;height:36px;' src='https://storage.ko-fi.com/cdn/kofi3.png?v=6' border='0' alt='Buy Me a Coffee at ko-fi.com' /></a>
<br>
<strong>Hack the world. Byte by Byte.</strong> ⛛ <br>
𝝺𝗿𝗰𝗮𝗻𝗴𝗲𝗹𝗼 @ 2025

**[[ꋧ]](#-𝗔𝗯𝗼𝘂𝘁-𝗡𝗘𝗞𝗢))**

</div>
