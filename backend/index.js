import express from "express";
import cors from "cors";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import mysql from "mysql2/promise";
import dotenv from "dotenv";

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

const dbConfig = {
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASS,
  database: process.env.DB_NAME,
};

const authenticate = (req, res, next) => {
  const auth = req.headers.authorization || "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7) : null;
  if (!token) return res.status(401).json({ message: "Missing token" });
  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET);
    next();
  } catch {
    return res.status(401).json({ message: "Invalid token" });
  }
};

app.get("/api/health", (_req, res) => {
  res.json({ ok: true });
});

app.post("/api/signup", async (req, res) => {
  try {
    const { fullName, email, password } = req.body;
    if (!fullName || !email || !password)
      return res.status(400).json({ message: "Missing fields" });

    const conn = await mysql.createConnection(dbConfig);
    const [existing] = await conn.execute(
      "SELECT id FROM users WHERE email = ?",
      [email]
    );
    if (existing.length > 0) {
      await conn.end();
      return res.status(409).json({ message: "Email already used" });
    }

    const hash = await bcrypt.hash(password, 10);
    await conn.execute(
      "INSERT INTO users (full_name, email, password_hash) VALUES (?, ?, ?)",
      [fullName, email, hash]
    );
    await conn.end();
    return res.json({ message: "Signup successful" });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: "Server error" });
  }
});

app.post("/api/login", async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password)
      return res.status(400).json({ message: "Missing fields" });

    const conn = await mysql.createConnection(dbConfig);
    const [rows] = await conn.execute(
      "SELECT id, full_name, password_hash FROM users WHERE email = ?",
      [email]
    );
    await conn.end();

    if (rows.length === 0)
      return res.status(401).json({ message: "Invalid credentials" });

    const valid = await bcrypt.compare(password, rows[0].password_hash);
    if (!valid)
      return res.status(401).json({ message: "Invalid credentials" });

    const token = jwt.sign({ userId: rows[0].id }, process.env.JWT_SECRET, {
      expiresIn: "7d",
    });
    return res.json({ token, fullName: rows[0].full_name });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: "Server error" });
  }
});

app.post("/api/reset-password", async (req, res) => {
  try {
    const { email, newPassword } = req.body;
    if (!email || !newPassword)
      return res.status(400).json({ message: "Missing fields" });

    const conn = await mysql.createConnection(dbConfig);
    const [rows] = await conn.execute(
      "SELECT id FROM users WHERE email = ?",
      [email]
    );
    if (rows.length === 0) {
      await conn.end();
      return res.status(404).json({ message: "Email not found" });
    }

    const hash = await bcrypt.hash(newPassword, 10);
    await conn.execute(
      "UPDATE users SET password_hash = ? WHERE email = ?",
      [hash, email]
    );
    await conn.end();
    return res.json({ message: "Password updated" });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: "Server error" });
  }
});

// Return amounts as numbers (MySQL2 returns DECIMAL as strings by default)
app.get("/api/transactions", authenticate, async (req, res) => {
  try {
    const conn = await mysql.createConnection(dbConfig);
    const [rows] = await conn.execute(
      `SELECT id, title, category, amount, type, source_card_id, source_name
       FROM transactions WHERE user_id = ? ORDER BY created_at DESC LIMIT 50`,
      [req.user.userId]
    );
    await conn.end();
    res.json({
      transactions: rows.map((r) => ({ ...r, amount: parseFloat(r.amount) })),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

app.post("/api/transactions", authenticate, async (req, res) => {
  try {
    const { title, type, source_card_id, source_name } = req.body;
    const amount = parseFloat(req.body.amount);
    // category required for expenses, optional for income
    const category = req.body.category || (type === "income" ? "Income" : null);

    if (!title || !category || isNaN(amount) || amount <= 0 || !type)
      return res.status(400).json({ message: "Missing or invalid fields" });
    if (!["income", "expense"].includes(type))
      return res.status(400).json({ message: "Invalid type" });
    if (amount > 9999999.99)
      return res.status(400).json({ message: "Amount too large" });

    const conn = await mysql.createConnection(dbConfig);

    // Validate card ownership if source provided
    if (source_card_id) {
      const [cards] = await conn.execute(
        "SELECT id, card_type FROM cards WHERE id = ? AND user_id = ?",
        [source_card_id, req.user.userId]
      );
      if (cards.length === 0) {
        await conn.end();
        return res.status(403).json({ message: "Card not found" });
      }
      const cardType = cards[0].card_type;
      // Block income from credit cards
      if (type === "income" && cardType === "credit") {
        await conn.end();
        return res.status(400).json({ message: "Cannot add income to a credit card" });
      }
    }

    await conn.execute(
      `INSERT INTO transactions
        (user_id, title, category, amount, type, source_card_id, source_name)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [req.user.userId, title, category, amount, type,
       source_card_id || null, source_name || null]
    );
    await conn.end();
    res.json({ message: "Transaction created" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

app.put("/api/transactions/:id", authenticate, async (req, res) => {
  try {
    const txId = parseInt(req.params.id, 10);
    const conn = await mysql.createConnection(dbConfig);

    // Verify ownership
    const [rows] = await conn.execute(
      "SELECT id, type FROM transactions WHERE id = ? AND user_id = ?",
      [txId, req.user.userId]
    );
    if (rows.length === 0) {
      await conn.end();
      return res.status(404).json({ message: "Transaction not found" });
    }

    const txType = rows[0].type;
    const { title, source_card_id, source_name } = req.body;
    const amount = parseFloat(req.body.amount);
    const category = req.body.category || (txType === "income" ? "Income" : null);

    if (!title || isNaN(amount) || amount <= 0)
      return res.status(400).json({ message: "Missing or invalid fields" });
    if (amount > 9999999.99)
      return res.status(400).json({ message: "Amount too large" });

    // Validate card ownership if provided
    if (source_card_id) {
      const [cards] = await conn.execute(
        "SELECT id, card_type FROM cards WHERE id = ? AND user_id = ?",
        [source_card_id, req.user.userId]
      );
      if (cards.length === 0) {
        await conn.end();
        return res.status(403).json({ message: "Card not found" });
      }
      if (txType === "income" && cards[0].card_type === "credit") {
        await conn.end();
        return res.status(400).json({ message: "Cannot set income source to a credit card" });
      }
    }

    await conn.execute(
      `UPDATE transactions
         SET title = ?, category = ?, amount = ?, source_card_id = ?, source_name = ?
       WHERE id = ? AND user_id = ?`,
      [title, category, amount, source_card_id || null, source_name || null,
       txId, req.user.userId]
    );
    await conn.end();
    res.json({ message: "Transaction updated" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

app.delete("/api/transactions/:id", authenticate, async (req, res) => {
  try {
    const txId = parseInt(req.params.id, 10);
    const conn = await mysql.createConnection(dbConfig);
    const [result] = await conn.execute(
      "DELETE FROM transactions WHERE id = ? AND user_id = ?",
      [txId, req.user.userId]
    );
    await conn.end();
    if (result.affectedRows === 0)
      return res.status(404).json({ message: "Transaction not found" });
    res.json({ message: "Transaction deleted" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

// Balance = income - expense from transactions, minus all credit card debt
app.get("/api/balance", authenticate, async (req, res) => {
  try {
    const conn = await mysql.createConnection(dbConfig);
    const [[txRow]] = await conn.execute(
      `SELECT
         COALESCE(SUM(CASE WHEN type = 'income'  THEN amount ELSE 0 END), 0) -
         COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS tx_balance
       FROM transactions WHERE user_id = ?`,
      [req.user.userId]
    );
    const [[creditRow]] = await conn.execute(
      `SELECT COALESCE(SUM(debt_amount), 0) AS total_debt
       FROM cards WHERE user_id = ? AND card_type = 'credit'`,
      [req.user.userId]
    );
    await conn.end();
    const total = parseFloat(txRow.tx_balance) - parseFloat(creditRow.total_debt);
    res.json({ total });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

app.get("/api/accounts", authenticate, async (req, res) => {
  try {
    const conn = await mysql.createConnection(dbConfig);
    const [rows] = await conn.execute(
      "SELECT id, name, balance FROM accounts WHERE user_id = ? ORDER BY created_at DESC",
      [req.user.userId]
    );
    await conn.end();
    res.json({ accounts: rows });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

// ── Cards ──────────────────────────────────────────────────
app.get("/api/cards", authenticate, async (req, res) => {
  try {
    const conn = await mysql.createConnection(dbConfig);
    const [rows] = await conn.execute(
      `SELECT id, card_name, card_type, bank_name, last4,
              balance, credit_limit, debt_amount, monthly_charge
       FROM cards WHERE user_id = ? ORDER BY created_at DESC`,
      [req.user.userId]
    );
    await conn.end();
    res.json({
      cards: rows.map((r) => ({
        ...r,
        balance:        parseFloat(r.balance),
        credit_limit:   parseFloat(r.credit_limit),
        debt_amount:    parseFloat(r.debt_amount),
        monthly_charge: parseFloat(r.monthly_charge),
      })),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

app.post("/api/cards", authenticate, async (req, res) => {
  try {
    const { card_name, card_type, bank_name, last4 } = req.body;
    const balance        = parseFloat(req.body.balance        ?? 0);
    const credit_limit   = parseFloat(req.body.credit_limit   ?? 0);
    const debt_amount    = parseFloat(req.body.debt_amount    ?? 0);
    const monthly_charge = parseFloat(req.body.monthly_charge ?? 0);

    if (!card_name || !card_type)
      return res.status(400).json({ message: "Missing card_name or card_type" });
    if (!["debit", "credit", "cash"].includes(card_type))
      return res.status(400).json({ message: "Invalid card_type" });

    const conn = await mysql.createConnection(dbConfig);
    const [result] = await conn.execute(
      `INSERT INTO cards
         (user_id, card_name, card_type, bank_name, last4,
          balance, credit_limit, debt_amount, monthly_charge)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [req.user.userId, card_name, card_type, bank_name || "",
       last4 || "0000", balance, credit_limit, debt_amount, monthly_charge]
    );
    await conn.end();
    res.json({ message: "Card created", id: result.insertId });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

app.put("/api/cards/:id", authenticate, async (req, res) => {
  try {
    const cardId = parseInt(req.params.id);
    const { card_name, bank_name, last4 } = req.body;
    const balance        = parseFloat(req.body.balance        ?? 0);
    const credit_limit   = parseFloat(req.body.credit_limit   ?? 0);
    const debt_amount    = parseFloat(req.body.debt_amount    ?? 0);
    const monthly_charge = parseFloat(req.body.monthly_charge ?? 0);

    const conn = await mysql.createConnection(dbConfig);
    await conn.execute(
      `UPDATE cards SET
         card_name = ?, bank_name = ?, last4 = ?,
         balance = ?, credit_limit = ?, debt_amount = ?, monthly_charge = ?
       WHERE id = ? AND user_id = ?`,
      [card_name, bank_name || "", last4 || "0000",
       balance, credit_limit, debt_amount, monthly_charge,
       cardId, req.user.userId]
    );
    await conn.end();
    res.json({ message: "Card updated" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

app.delete("/api/cards/:id", authenticate, async (req, res) => {
  try {
    const cardId = parseInt(req.params.id);
    const conn = await mysql.createConnection(dbConfig);
    await conn.execute(
      "DELETE FROM cards WHERE id = ? AND user_id = ?",
      [cardId, req.user.userId]
    );
    await conn.end();
    res.json({ message: "Card deleted" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

// Expenses summary: total from transactions + sum of credit monthly charges
app.get("/api/expenses/summary", authenticate, async (req, res) => {
  try {
    const conn = await mysql.createConnection(dbConfig);
    const [[txRow]] = await conn.execute(
      `SELECT COALESCE(SUM(amount), 0) AS total
       FROM transactions WHERE user_id = ? AND type = 'expense'`,
      [req.user.userId]
    );
    const [[creditRow]] = await conn.execute(
      `SELECT COALESCE(SUM(monthly_charge), 0) AS monthly_charges
       FROM cards WHERE user_id = ? AND card_type = 'credit'`,
      [req.user.userId]
    );
    await conn.end();
    res.json({
      total:           parseFloat(txRow.total),
      monthly_charges: parseFloat(creditRow.monthly_charges),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

app.post("/api/profile/name", authenticate, async (req, res) => {
  try {
    const { fullName } = req.body;
    if (!fullName) return res.status(400).json({ message: "Missing name" });

    const conn = await mysql.createConnection(dbConfig);
    await conn.execute("UPDATE users SET full_name = ? WHERE id = ?", [
      fullName,
      req.user.userId,
    ]);
    await conn.end();
    res.json({ message: "Name updated" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

app.post("/api/profile/password", authenticate, async (req, res) => {
  try {
    const { newPassword } = req.body;
    if (!newPassword)
      return res.status(400).json({ message: "Missing password" });

    const hash = await bcrypt.hash(newPassword, 10);
    const conn = await mysql.createConnection(dbConfig);
    await conn.execute("UPDATE users SET password_hash = ? WHERE id = ?", [
      hash,
      req.user.userId,
    ]);
    await conn.end();
    res.json({ message: "Password updated" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

app.delete("/api/profile", authenticate, async (req, res) => {
  try {
    const conn = await mysql.createConnection(dbConfig);
    await conn.execute("DELETE FROM users WHERE id = ?", [req.user.userId]);
    await conn.end();
    res.json({ message: "Account deleted" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

// Reset all financial data (transactions + budget + cards) without deleting the account
app.delete("/api/data/reset", authenticate, async (req, res) => {
  try {
    const conn = await mysql.createConnection(dbConfig);
    await conn.execute("DELETE FROM transactions WHERE user_id = ?", [req.user.userId]);
    await conn.execute("DELETE FROM budgets WHERE user_id = ?", [req.user.userId]);
    await conn.execute("DELETE FROM cards WHERE user_id = ?", [req.user.userId]);
    await conn.end();
    res.json({ message: "Data reset" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

app.get("/api/budget", authenticate, async (req, res) => {
  try {
    const conn = await mysql.createConnection(dbConfig);
    const [rows] = await conn.execute(
      "SELECT monthly_amount FROM budgets WHERE user_id = ?",
      [req.user.userId]
    );
    await conn.end();
    res.json({
      monthly_amount:
        rows.length > 0 ? parseFloat(rows[0].monthly_amount) : 0,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

app.post("/api/budget", authenticate, async (req, res) => {
  try {
    const monthly_amount = parseFloat(req.body.monthly_amount);
    if (isNaN(monthly_amount) || monthly_amount <= 0)
      return res.status(400).json({ message: "Invalid monthly_amount" });

    const conn = await mysql.createConnection(dbConfig);
    await conn.execute(
      "INSERT INTO budgets (user_id, monthly_amount) VALUES (?, ?) ON DUPLICATE KEY UPDATE monthly_amount = VALUES(monthly_amount)",
      [req.user.userId, monthly_amount]
    );
    await conn.end();
    res.json({ message: "Budget saved" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

app.listen(process.env.PORT || 20215, "0.0.0.0", () => {
  console.log("API running");
});
