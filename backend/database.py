import sqlite3
import json
from pathlib import Path

DB_PATH = Path(__file__).parent / "gmail_ai.db"

def get_conn():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_conn()
    c = conn.cursor()

    c.execute("""
        CREATE TABLE IF NOT EXISTS tokens (
            id INTEGER PRIMARY KEY,
            access_token TEXT,
            refresh_token TEXT,
            token_expiry TEXT,
            email TEXT
        )
    """)

    c.execute("""
        CREATE TABLE IF NOT EXISTS style_profile (
            id INTEGER PRIMARY KEY,
            profile_json TEXT,
            sample_count INTEGER,
            created_at TEXT DEFAULT (datetime('now'))
        )
    """)

    c.execute("""
        CREATE TABLE IF NOT EXISTS email_replies (
            id INTEGER PRIMARY KEY,
            gmail_message_id TEXT UNIQUE,
            thread_id TEXT,
            subject TEXT,
            sender TEXT,
            body_snippet TEXT,
            generated_reply TEXT,
            status TEXT DEFAULT 'pending',  -- pending | approved | sent | rejected
            created_at TEXT DEFAULT (datetime('now')),
            sent_at TEXT
        )
    """)

    c.execute("""
        CREATE TABLE IF NOT EXISTS email_samples (
            id INTEGER PRIMARY KEY,
            subject TEXT,
            body TEXT,
            created_at TEXT DEFAULT (datetime('now'))
        )
    """)

    conn.commit()
    conn.close()

def save_tokens(access_token, refresh_token, expiry, email):
    conn = get_conn()
    conn.execute("DELETE FROM tokens")
    conn.execute(
        "INSERT INTO tokens (access_token, refresh_token, token_expiry, email) VALUES (?,?,?,?)",
        (access_token, refresh_token, expiry, email)
    )
    conn.commit()
    conn.close()

def get_tokens():
    conn = get_conn()
    row = conn.execute("SELECT * FROM tokens LIMIT 1").fetchone()
    conn.close()
    return dict(row) if row else None

def save_style_profile(profile: dict, sample_count: int):
    conn = get_conn()
    conn.execute("DELETE FROM style_profile")
    conn.execute(
        "INSERT INTO style_profile (profile_json, sample_count) VALUES (?,?)",
        (json.dumps(profile), sample_count)
    )
    conn.commit()
    conn.close()

def get_style_profile():
    conn = get_conn()
    row = conn.execute("SELECT * FROM style_profile LIMIT 1").fetchone()
    conn.close()
    if row:
        d = dict(row)
        d["profile"] = json.loads(d["profile_json"])
        return d
    return None

def save_email_reply(gmail_id, thread_id, subject, sender, snippet, reply):
    conn = get_conn()
    conn.execute("""
        INSERT OR REPLACE INTO email_replies
        (gmail_message_id, thread_id, subject, sender, body_snippet, generated_reply, status)
        VALUES (?,?,?,?,?,?,?)
    """, (gmail_id, thread_id, subject, sender, snippet, reply, "pending"))
    conn.commit()
    conn.close()

def update_reply_status(gmail_id, status, edited_reply=None):
    conn = get_conn()
    if edited_reply is not None:
        conn.execute(
            "UPDATE email_replies SET status=?, generated_reply=?, sent_at=datetime('now') WHERE gmail_message_id=?",
            (status, edited_reply, gmail_id)
        )
    else:
        conn.execute(
            "UPDATE email_replies SET status=?, sent_at=datetime('now') WHERE gmail_message_id=?",
            (status, gmail_id)
        )
    conn.commit()
    conn.close()

def get_all_replies():
    conn = get_conn()
    rows = conn.execute("SELECT * FROM email_replies ORDER BY created_at DESC").fetchall()
    conn.close()
    return [dict(r) for r in rows]

def save_samples(samples: list):
    conn = get_conn()
    conn.execute("DELETE FROM email_samples")
    conn.executemany(
        "INSERT INTO email_samples (subject, body) VALUES (?,?)",
        [(s.get("subject",""), s.get("body","")) for s in samples]
    )
    conn.commit()
    conn.close()

def get_samples():
    conn = get_conn()
    rows = conn.execute("SELECT * FROM email_samples").fetchall()
    conn.close()
    return [dict(r) for r in rows]
