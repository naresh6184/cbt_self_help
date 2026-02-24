# ai_client.py
"""
Centralized AI Client
ALL Gemini / Groq / Future AI calls go through here.
"""

import os
from dotenv import load_dotenv

# ================= LOAD ENV =================
load_dotenv()

# ================= CONFIG =================
PROVIDER = os.getenv("AI_PROVIDER", "gemini")   # gemini / groq / auto

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
GROQ_API_KEY = os.getenv("GROQ_API_KEY")

GEMINI_MODEL = "gemini-2.5-flash-lite"
GROQ_MODEL = os.getenv("GROQ_MODEL", "llama-3.1-8b-instant")


gemini_client = None
groq_client = None

# ================= INIT GEMINI =================
try:
    if GEMINI_API_KEY:
        from google import genai
        gemini_client = genai.Client(api_key=GEMINI_API_KEY)
        print("[AI CLIENT] Gemini initialized")
except Exception as e:
    print("[AI CLIENT] Gemini init failed:", e)

# ================= INIT GROQ =================
try:
    if GROQ_API_KEY:
        from groq import Groq
        groq_client = Groq(api_key=GROQ_API_KEY)
        print("[AI CLIENT] Groq initialized")
except Exception as e:
    print("[AI CLIENT] Groq init failed:", e)


# ======================================================
# ================= UNIVERSAL GENERATOR =================
# ======================================================

def generate_text(prompt, fallback="Could you tell me more?"):
    """
    Universal AI generator.

    Priority:
    1️⃣ Gemini
    2️⃣ Groq fallback (if Gemini quota ends or fails)
    """

    # ==================================================
    # TRY GEMINI FIRST
    # ==================================================
    if PROVIDER in ["gemini", "auto"] and gemini_client:
        try:
            response = gemini_client.models.generate_content(
                model=GEMINI_MODEL,
                contents=prompt
            )

            if hasattr(response, "text") and response.text:
                return response.text.strip()

        except Exception as e:
            print("[AI CLIENT] Gemini failed → switching to Groq:", e)

    # ==================================================
    # GROQ FALLBACK
    # ==================================================
    if PROVIDER in ["groq", "auto"] and groq_client:
        try:
            completion = groq_client.chat.completions.create(
                model=GROQ_MODEL,
                messages=[
                    {"role": "user", "content": prompt}
                ],
            )

            return completion.choices[0].message.content.strip()

        except Exception as e:
            print("[AI CLIENT] Groq failed:", e)

    # ==================================================
    # FINAL FALLBACK
    # ==================================================
    return fallback
