require("dotenv").config();

const express = require("express");
const cors = require("cors");
const bodyParser = require("body-parser");
const { createClient } = require("@supabase/supabase-js");
const { ethers } = require("ethers");

const app = express();
app.use(cors());
app.use(bodyParser.json());

// ======================
// SUPABASE CONFIG
// ======================
const SUPABASE_URL = "https://sdrbzhrypzsruvekhnst.supabase.co";
const SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNkcmJ6aHJ5cHpzcnV2ZWtobnN0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU1MzM0OTAsImV4cCI6MjA5MTEwOTQ5MH0.a3Kj_Pva5oswKIf1hwEucslkKeOUJnnDCYxKB-gDhWg";

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

// ======================
// BLOCKCHAIN CONFIG
// ======================
const RPC_URL = "http://127.0.0.1:8545"; // or your network
const provider = new ethers.JsonRpcProvider(RPC_URL);

const contractAddress = "YOUR_CONTRACT_ADDRESS";

const abi = [
  "function isWhitelisted(uint,bytes32) view returns(bool)"
];

const contract = new ethers.Contract(contractAddress, abi, provider);

// ======================
// SEND OTP
// ======================
app.post("/send-otp", async (req, res) => {
  try {
    let { aadhaar, electionId } = req.body;

    if (!aadhaar || electionId === undefined) {
      return res.json({ success: false, message: "Missing fields" });
    }

    const cleanAadhaar = String(aadhaar).trim().toLowerCase();

    // ======================
    // 🔥 HASH Aadhaar
    // ======================
    const hashed = ethers.keccak256(
      ethers.toUtf8Bytes(cleanAadhaar)
    );

    // ======================
    // 🔥 CHECK WHITELIST
    // ======================
    const isAllowed = await contract.isWhitelisted(electionId, hashed);

    if (!isAllowed) {
      return res.json({
        success: false,
        message: "You are not whitelisted for this election"
      });
    }

    // ======================
    // DB CHECK
    // ======================
    const { data, error } = await supabase
      .from("voters")
      .select("*")
      .eq("aadhaar_id", cleanAadhaar);

    if (error) {
      console.error(error);
      return res.json({ success: false, message: "Database error" });
    }

    if (!data || data.length === 0) {
      return res.json({ success: false, message: "Aadhaar not found" });
    }

    const user = data[0];

    // ======================
    // OTP COOLDOWN (30s)
    // ======================
    if (user.otp_created_at) {
      const last = new Date(user.otp_created_at).getTime();

      if (Date.now() - last < 30000) {
        const remaining = Math.ceil(
          (30000 - (Date.now() - last)) / 1000
        );

        return res.json({
          success: false,
          message: `For security purposes, you can only request this after ${remaining} seconds.`
        });
      }
    }

    // ======================
    // SEND OTP
    // ======================
    const { error: otpError } = await supabase.auth.signInWithOtp({
      email: user.email,
      options: {
        shouldCreateUser: false
      }
    });

    if (otpError) {
      console.error(otpError);
      return res.json({ success: false, message: otpError.message });
    }

    // ======================
    // STORE TIMESTAMP
    // ======================
    await supabase
      .from("voters")
      .update({
        otp_created_at: new Date().toISOString()
      })
      .eq("aadhaar_id", cleanAadhaar);

    res.json({
      success: true,
      email: user.email
    });

  } catch (err) {
    console.error("Send OTP error:", err);
    res.json({ success: false, message: "Server error" });
  }
});

// ======================
// VERIFY OTP
// ======================
app.post("/verify-otp", async (req, res) => {
  try {
    let { email, token, aadhaar, wallet } = req.body;

    if (!wallet) {
      return res.json({ success: false, message: "Wallet required" });
    }

    const cleanAadhaar = String(aadhaar).trim().toLowerCase();

    const { data, error } = await supabase
      .from("voters")
      .select("*")
      .eq("aadhaar_id", cleanAadhaar);

    if (error) {
      console.error(error);
      return res.json({ success: false, message: "Database error" });
    }

    if (!data || data.length === 0) {
      return res.json({ success: false, message: "User not found" });
    }

    // ======================
    // VERIFY OTP
    // ======================
    const { error: verifyError } = await supabase.auth.verifyOtp({
      email,
      token,
      type: "email"
    });

    if (verifyError) {
      console.error(verifyError);
      return res.json({
        success: false,
        message: verifyError.message
      });
    }

    // ======================
    // UPDATE USER
    // ======================
    await supabase
      .from("voters")
      .update({
        wallet_address: wallet,
        is_registered: true,
        otp_created_at: null
      })
      .eq("aadhaar_id", cleanAadhaar);

    res.json({ success: true });

  } catch (err) {
    console.error("Verify OTP error:", err);
    res.json({ success: false, message: "Server error" });
  }
});

// ======================
app.listen(3000, () => {
  console.log("🚀 Backend running on http://localhost:3000");
});