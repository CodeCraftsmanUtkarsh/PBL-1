  const express = require("express");
  const cors = require("cors");
  const bodyParser = require("body-parser");
  const { createClient } = require("@supabase/supabase-js");
  const { ethers } = require("ethers");

  const app = express();

  app.use(cors({ origin: "*" }));
  app.use(bodyParser.json());

  /* ======================
    SUPABASE
  ====================== */
  const supabase = createClient(
    "https://sdrbzhrypzsruvekhnst.supabase.co",
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNkcmJ6aHJ5cHpzcnV2ZWtobnN0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU1MzM0OTAsImV4cCI6MjA5MTEwOTQ5MH0.a3Kj_Pva5oswKIf1hwEucslkKeOUJnnDCYxKB-gDhWg"
  );

  /* ======================
    BLOCKCHAIN
  ====================== */

  // 🔥 MUST be Ganache/Hardhat PRIVATE KEY
  const ADMIN_PRIVATE_KEY = "0x764f18ebbb2f40a56d3575e922091dacf66851f90b4e639850c75e43ce38ace5";

  const provider = new ethers.providers.JsonRpcProvider(
    "http://127.0.0.1:7545"
  );

  const adminWallet = new ethers.Wallet(ADMIN_PRIVATE_KEY, provider);

  // 🔥 your deployed contract address
  const contractAddress = "0xfc57abC11beC82d57134253f4B3c696cB965fDF6";

  const abi = [
    "function isWhitelisted(uint,bytes32) view returns(bool)",
    "function registerFromBackend(uint,address,bytes32)"
  ];

  const contract = new ethers.Contract(
    contractAddress,
    abi,
    adminWallet
  );

  /* ======================
    SEND OTP
  ====================== */
  app.post("/send-otp", async (req, res) => {
    try {
      const { aadhaar, electionId } = req.body;

      if (!aadhaar || electionId === undefined || electionId === null || electionId === "") {
        return res.json({ success: false, message: "Missing fields" });
      }

      const normalizedElectionId = Number(electionId);
      if (!Number.isInteger(normalizedElectionId) || normalizedElectionId < 0) {
        return res.json({ success: false, message: "Invalid election selection" });
      }

      const clean = String(aadhaar).trim().toLowerCase();

      const hash = ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes(clean)
      );

      // 🔥 Check whitelist from blockchain
      const allowed = await contract.isWhitelisted(normalizedElectionId, hash);

      if (!allowed) {
        return res.json({
          success: false,
          message: "Not whitelisted"
        });
      }

      // 🔥 Fetch user email from DB
      const { data } = await supabase
        .from("voters")
        .select("*")
        .eq("aadhaar_id", clean);

      if (!data || data.length === 0) {
        return res.json({
          success: false,
          message: "Aadhaar not found"
        });
      }

      const user = data[0];

      // 🔥 Send OTP
      const { error } = await supabase.auth.signInWithOtp({
        email: user.email,
        options: { shouldCreateUser: false }
      });

      if (error) {
        return res.json({
          success: false,
          message: error.message
        });
      }

      res.json({
        success: true,
        email: user.email
      });

    } catch (err) {
      console.error(err);
      res.json({ success: false, message: "Server error" });
    }
  });

  /* ======================
    VERIFY OTP + REGISTER
  ====================== */
  app.post("/verify-otp", async (req, res) => {
    try {
      const { email, token, aadhaar, wallet, electionId } = req.body;

      if (!wallet) {
        return res.json({
          success: false,
          message: "Wallet required"
        });
      }

      if (electionId === undefined || electionId === null || electionId === "") {
        return res.json({
          success: false,
          message: "Election required"
        });
      }

      const normalizedElectionId = Number(electionId);
      if (!Number.isInteger(normalizedElectionId) || normalizedElectionId < 0) {
        return res.json({
          success: false,
          message: "Invalid election selection"
        });
      }

      const clean = String(aadhaar).trim().toLowerCase();

      // 🔥 Verify OTP
      const { error } = await supabase.auth.verifyOtp({
        email,
        token,
        type: "email"
      });

      if (error) {
        return res.json({
          success: false,
          message: error.message
        });
      }

      // 🔥 Hash Aadhaar
      const hash = ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes(clean)
      );

      // 🔥 Register on blockchain (ADMIN signs this)
      const tx = await contract.registerFromBackend(
        normalizedElectionId,
        wallet,
        hash
      );

      await tx.wait();

      res.json({ success: true });

    } catch (err) {
      console.error(err);

      if (err.reason) {
        return res.json({
          success: false,
          message: err.reason
        });
      }

      res.json({
        success: false,
        message: "Server error"
      });
    }
  });

  /* ====================== */
  app.listen(3000, () => {
    console.log("🚀 Backend running on http://localhost:3000");
  });
