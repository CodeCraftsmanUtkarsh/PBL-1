const express = require("express");
const cors = require("cors");
const bodyParser = require("body-parser");
const { createClient } = require("@supabase/supabase-js");

const app = express();
app.use(cors());
app.use(bodyParser.json());

// ======================
// SUPABASE
// ======================
const SUPABASE_URL = "https://sdrbzhrypzsruvekhnst.supabase.co";
const SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNkcmJ6aHJ5cHpzcnV2ZWtobnN0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU1MzM0OTAsImV4cCI6MjA5MTEwOTQ5MH0.a3Kj_Pva5oswKIf1hwEucslkKeOUJnnDCYxKB-gDhWg";

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

// ======================
// SEND OTP
// ======================
app.post("/send-otp", async (req, res) => {
  try {
    let { aadhaar } = req.body;

    if (!aadhaar) {
      return res.json({ success: false, message: "Aadhaar required" });
    }

    // 🔥 CLEAN INPUT
    const cleanAadhaar = String(aadhaar).trim();

    // 🔥 DEBUG LOG
    console.log("Searching Aadhaar:", cleanAadhaar);

    // 🔥 FIXED QUERY (NO .single())
    const { data, error } = await supabase
      .from("voters")
      .select("*")
      .eq("aadhaar_id", cleanAadhaar);

    console.log("DB RESULT:", data, error);

    if (error) {
      console.error("Supabase error:", error);
      return res.json({ success: false, message: "DB error" });
    }

    if (!data || data.length === 0) {
      return res.json({ success: false, message: "Aadhaar not found" });
    }

    const user = data[0];

    // 🔥 OTP cooldown (30 sec)
    if (user.otp_created_at) {
      const last = new Date(user.otp_created_at).getTime();
      if (Date.now() - last < 30000) {
        return res.json({
          success: false,
          message: "Wait before requesting OTP again"
        });
      }
    }

    // 🔹 Update OTP timestamp
    await supabase
      .from("voters")
      .update({
        otp_created_at: new Date().toISOString()
      })
      .eq("aadhaar_id", cleanAadhaar);

    // 🔹 Send OTP
   const { error: otpError } = await supabase.auth.signInWithOtp({
  email: user.email,
  options: {
    shouldCreateUser: false
  }
});

if (otpError) {
  console.error("OTP ERROR:", otpError.message);
  return res.json({ success: false, message: otpError.message });
}

    if (otpError) {
      console.error("OTP error:", otpError);
      return res.json({ success: false, message: "OTP failed" });
    }

    res.json({ success: true, email: user.email });

  } catch (err) {
    console.error("Server error:", err);
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

    const cleanAadhaar = String(aadhaar).trim();

    // 🔥 Fetch user
    const { data } = await supabase
      .from("voters")
      .select("*")
      .eq("aadhaar_id", cleanAadhaar);

    if (!data || data.length === 0) {
      return res.json({ success: false, message: "User not found" });
    }

    const user = data[0];

    // 🔥 OTP expiry (30 sec)
    if (!user.otp_created_at) {
      return res.json({ success: false, message: "OTP expired" });
    }

    const created = new Date(user.otp_created_at).getTime();

    if (Date.now() - created > 30000) {
      return res.json({ success: false, message: "OTP expired (30s)" });
    }

    // 🔹 Verify OTP
    const { error } = await supabase.auth.verifyOtp({
      email,
      token,
      type: "email"
    });

    if (error) {
      return res.json({ success: false, message: "Invalid OTP" });
    }

    // 🔹 Update DB
    await supabase
      .from("voters")
      .update({
        wallet_address: wallet,
        is_registered: true
      })
      .eq("aadhaar_id", cleanAadhaar);

    res.json({ success: true });

  } catch (err) {
    console.error("Verify error:", err);
    res.json({ success: false, message: "Server error" });
  }
});

// ======================
app.listen(3000, () => {
  console.log("🚀 Backend running on port 3000");
});