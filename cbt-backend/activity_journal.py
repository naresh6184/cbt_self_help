# -*- coding: utf-8 -*-
"""
An AI-powered conversational engine for enriching a user's daily activity log.

"""

from ai_client import generate_text
import json

# ==============================================================================
# --- CONFIGURATION ---
# ==============================================================================
MAX_USER_REPLIES = 4


# ==============================================================================
# --- AI HELPER FUNCTIONS (NOW CENTRALIZED) ---
# ==============================================================================

def generate_unfolding_question(transcript_text):
    """Generates a subtle, non-direct question based on story arc."""

    fallback = "What happened next?"

    prompt = f'''
You are an empathetic, patient, and subtle journaling assistant.
Your only goal is to help the user tell the "story" of their activity by
asking one gentle, natural follow-up question.

**Your Mental Model: The Story Arc of an Activity**
Think about an activity in three parts:
1. Beginning
2. Middle
3. End

**ABSOLUTE RULES:**
- BE SUBTLE, NOT DIRECT.
- NO LEADING QUESTIONS.
- NO REPETITION.
- BE BRIEF & DEFERENTIAL (under 12 words).

User's Log:
---
{transcript_text}
---

Your Question:
'''

    return generate_text(prompt, fallback).replace('"', '').replace('*', '')


# ==============================================================================
# --- CORE CONVERSATIONAL LOGIC ---
# ==============================================================================

def _get_mood_rating():
    """Prompts the user for a mood rating from 1 to 5."""
    while True:
        try:
            rating_input = input(
                "Bot: Finally, how would you rate your mood during that activity from 1 (very low) to 5 (very high)? "
            )
            rating_num = int(rating_input)

            if 1 <= rating_num <= 5:
                return rating_num
            else:
                print("  Please enter a number between 1 and 5.")

        except ValueError:
            print("  That doesn't look like a valid number. Please try again.")


def enrich_activity_log(initial_entry):
    """Main conversation loop."""
    if not initial_entry:
        return None

    transcript = [{"speaker": "user", "message": initial_entry}]

    for i in range(MAX_USER_REPLIES):

        transcript_text = "\n".join(
            [f"{item['speaker'].title()}: {item['message']}" for item in transcript]
        )

        bot_question = generate_unfolding_question(transcript_text)
        print(f"Bot: {bot_question}")

        transcript.append({"speaker": "bot", "message": bot_question})

        user_reply = input("You: ")
        transcript.append({"speaker": "user", "message": user_reply})

    print("\nBot: Thanks for sharing, I've got that.")
    mood_score = _get_mood_rating()

    final_log = {
        "transcript": transcript,
        "mood_score": mood_score
    }

    return final_log


# ==============================================================================
# --- SIMULATION ---
# ==============================================================================

def main():

    print("\n--- AI-Powered Journaling Assistant ---")
    print("Let's log an activity. I'll ask up to 4 brief questions.")
    print("-" * 50)

    initial_activity = input("What activity would you like to log?\nYou: ")

    final_log_data = enrich_activity_log(initial_activity)

    if final_log_data:
        print("\n" + "=" * 60)
        print("SUCCESS: Structured log created.")
        print("=" * 60)
        print(json.dumps(final_log_data, indent=2))
        print("\nThis JSON object would be sent to the database.")
        print("=" * 60)
    else:
        print("\n" + "=" * 60)
        print("INFO: No activity entered. Session ended.")
        print("=" * 60)


if __name__ == "__main__":
    main()
