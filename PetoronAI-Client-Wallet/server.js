/*
Copyright (c) Ivan Alekseev

Licensed under the PetoronAI Community License (PCL)
or a valid PetoronAI Commercial License.
*/

const express = require("express");
const { ethers } = require("ethers");
const path = require("path");

const app = express();

app.use(express.json());
app.use(express.static(path.join(__dirname, "public")));

const VAULT_ADDRESS = "0x6BD1A8237b1620D11acB4520b3B2EeF13d7e6516";

const VAULT_ABI = [
  "function deposit(bytes32 commitment) external payable",
  "function commitmentInfo(bytes32 commitment) external view returns (bool exists,address payer,uint256 amount,uint256 depositedAtBlock)",
  "function vaultBalance() external view returns (uint256)",
  "event Deposit(address indexed payer, bytes32 indexed commitment, uint256 amount, uint256 indexed depositId)"
];

let session = {
  rpc: "",
  privateKey: ""
};

function provider() {
  if (!session.rpc) throw new Error("RPC URL is missing");
  return new ethers.providers.JsonRpcProvider(session.rpc);
}

function wallet() {
  if (!session.privateKey) throw new Error("Private key is missing");
  return new ethers.Wallet(session.privateKey, provider());
}

function vault(signer) {
  return new ethers.Contract(VAULT_ADDRESS, VAULT_ABI, signer || provider());
}

app.post("/api/session", async (req, res) => {
  try {
    session.rpc = req.body.rpc || "";
    session.privateKey = req.body.privateKey || "";

    const w = wallet();

    res.json({
      ok: true,
      wallet: w.address,
      balanceEth: ethers.utils.formatEther(await provider().getBalance(w.address)),
      vault: VAULT_ADDRESS
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get("/api/status", async (req, res) => {
  try {
    const p = provider();
    const w = wallet();

    res.json({
      wallet: w.address,
      walletBalanceEth: ethers.utils.formatEther(await p.getBalance(w.address)),
      vault: VAULT_ADDRESS,
      vaultBalanceEth: ethers.utils.formatEther(await p.getBalance(VAULT_ADDRESS)),
      currentBlock: await p.getBlockNumber()
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post("/api/deposit", async (req, res) => {
  try {
    const commitment = req.body.commitment;
    const amount = req.body.amount;

    if (!ethers.utils.isHexString(commitment, 32)) {
      throw new Error("Commitment must be bytes32: 0x + 64 hex characters");
    }

    const tx = await vault(wallet()).deposit(commitment, {
      value: ethers.utils.parseEther(amount)
    });

    const rc = await tx.wait();

    res.json({
      ok: true,
      tx: tx.hash,
      status: rc.status,
      block: rc.blockNumber,
      vault: VAULT_ADDRESS,
      commitment,
      amountEth: amount
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post("/api/commitment", async (req, res) => {
  try {
    const commitment = req.body.commitment;

    if (!ethers.utils.isHexString(commitment, 32)) {
      throw new Error("Commitment must be bytes32: 0x + 64 hex characters");
    }

    const v = vault();
    const info = await v.commitmentInfo(commitment);

    res.json({
      commitment,
      exists: info.exists,
      payer: info.payer,
      amountEth: ethers.utils.formatEther(info.amount),
      depositedAtBlock: info.depositedAtBlock.toString()
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.listen(8788, "127.0.0.1", () => {
  console.log("PetoronAI Client Wallet: http://127.0.0.1:8788");
});
