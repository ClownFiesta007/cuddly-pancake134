const { ethers } = require("ethers");
require("dotenv").config();

function getProvider() {
  return new ethers.JsonRpcProvider(process.env.RPC_URL || "http://127.0.0.1:8545");
}

function getSigner() {
  const pk = process.env.PRIVATE_KEY;
  if (!pk) throw new Error("PRIVATE_KEY not set");
  return new ethers.Wallet(pk, getProvider());
}

module.exports = { getProvider, getSigner };
