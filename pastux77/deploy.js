const { ethers } = require("ethers");
const fs = require("fs");
const path = require("path");
require("dotenv").config();

async function main() {
  const token = process.env.TOKEN_ADDRESS;
  const beneficiary = process.env.BENEFICIARY;
  if (!token || !beneficiary) {
    throw new Error("Set TOKEN_ADDRESS and BENEFICIARY in .env");
  }
  const signer = new ethers.Wallet(process.env.PRIVATE_KEY, new ethers.JsonRpcProvider(process.env.RPC_URL));
  const artifact = JSON.parse(
    fs.readFileSync(path.join(__dirname, "artifacts", "contracts", "TokenPuller.sol", "TokenPuller.json"), "utf8")
  );
  const factory = new ethers.ContractFactory(artifact.abi, artifact.bytecode, signer);
  const puller = await factory.deploy(token, beneficiary);
  await puller.waitForDeployment();
  console.log("TokenPuller deployed at:", await puller.getAddress());
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
