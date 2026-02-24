# -*- coding: utf-8 -*-
"""
Empathetic PHQ-9 conversational engine
(UPDATED — uses centralized ai_client)
"""

# ⭐ IMPORTANT: We now use centralized AI client
from ai_client import generate_text


# ==============================================================================
# --- CONFIGURATION ---
# ==============================================================================
MAX_MAIN_ATTEMPTS = 2
MAX_CLARIFICATION_ATTEMPTS = 2


# ==============================================================================
# --- CONSTANTS & DATA ---
# ==============================================================================
PHQ9_QUESTIONS = [
    {"key": "q1", "clinical_text": "Little interest or pleasure in doing things."},
    {"key": "q2", "clinical_text": "Feeling down, depressed, or hopeless."},
    {"key": "q3", "clinical_text": "Trouble falling or staying asleep, or sleeping too much."},
    {"key": "q4", "clinical_text": "Feeling tired or having little energy."},
    {"key": "q5", "clinical_text": "Poor appetite or overeating."},
    {"key": "q6", "clinical_text": "Feeling bad about yourself — or that you are a failure or have let yourself or your family down."},
    {"key": "q7", "clinical_text": "Trouble concentrating on things, such as reading the newspaper or watching television."},
    {"key": "q8", "clinical_text": "Moving or speaking so slowly that other people could have noticed? Or the opposite — being so fidgety or restless that you have been moving around a lot more than usual."},
    {"key": "q9", "clinical_text": "Thoughts that you would be better off dead or of hurting yourself in some way."}
]

ANSWER_CHOICES = {
    1: {"text": "Not at all", "score": 0},
    2: {"text": "Several days", "score": 1},
    3: {"text": "More than half the days", "score": 2},
    4: {"text": "Nearly every day", "score": 3}
}

SCORING_RUBRIC = {
    "Minimal depression": (1, 4),
    "Mild depression": (5, 9),
    "Moderate depression": (10, 14),
    "Moderately severe depression": (15, 19),
    "Severe depression": (20, 27)
}


# ==============================================================================
# --- AI HELPER FUNCTIONS (NOW USING ai_client) ---
# ==============================================================================

def generate_conversational_prompt(clinical_text):
    fallback = f"Over the last 2 weeks, how often have you been bothered by: {clinical_text}"

    prompt = f'''
Rephrase into a friendly conversational question.
Must include "over the last 2 weeks".
Statement: "{clinical_text}"
Question:
'''
    return generate_text(prompt, fallback)


def interpret_free_text_answer(user_text):
    prompt = f'''
Analyze the user input and classify it.

Scale:
1 Not at all
2 Several days
3 More than half the days
4 Nearly every day
5 Cannot determine

User Input: "{user_text}"
Category Number:
'''
    response_text = generate_text(prompt, "5")
    cleaned = ''.join(filter(str.isdigit, response_text))
    return int(cleaned) if cleaned else 5


def generate_clarifying_question(clinical_text, ambiguous_answer):
    fallback = "That's okay. Could you tell me a little more?"

    prompt = f'''
User gave unclear answer.

Topic: "{clinical_text}"
User answer: "{ambiguous_answer}"

Ask a short neutral follow-up question.
'''
    return generate_text(prompt, fallback)


# ==============================================================================
# --- CORE LOGIC (UNCHANGED) ---
# ==============================================================================

def ask_question(question_data):
    for main_attempt in range(MAX_MAIN_ATTEMPTS):
        if main_attempt > 0:
            print("\n   Let's try that one more time.")

        main_prompt = generate_conversational_prompt(question_data["clinical_text"])
        print("\n" + "="*50 + f"\n{main_prompt}\n" + "="*50)

        for key, value in ANSWER_CHOICES.items():
            print(f"{key}: {value['text']}")

        clarification_attempts = 0

        while clarification_attempts <= MAX_CLARIFICATION_ATTEMPTS:
            user_input = input("\nEnter number or type freely: ")

            try:
                choice = int(user_input)
                if choice in ANSWER_CHOICES:
                    print("   [Input Recorded]")
                    return ANSWER_CHOICES[choice]["score"]
            except ValueError:
                print("   [Interpreting your answer...]")
                interpreted_choice = interpret_free_text_answer(user_input)

                if interpreted_choice in ANSWER_CHOICES:
                    confirmed = ANSWER_CHOICES[interpreted_choice]["text"]
                    print(f"   Interpreted as: '{confirmed}'.")
                    return ANSWER_CHOICES[interpreted_choice]["score"]

                clarification_attempts += 1
                if clarification_attempts <= MAX_CLARIFICATION_ATTEMPTS:
                    print("   [Clarifying...]")
                    clarifying_prompt = generate_clarifying_question(
                        question_data["clinical_text"], user_input
                    )
                    print(f"\n   {clarifying_prompt}")

    print("\n   We'll skip this one.")
    return None


# ==============================================================================
# --- DISPLAY FUNCTIONS ---
# ==============================================================================

def _display_welcome_message():
    print("="*60)
    print("Welcome to PHQ-9 Bot")
    print("="*60)
    input("\nPress Enter to begin...")


def display_results(total_score, skipped_questions):
    print("\n" + "#"*50 + "\nAssessment Complete\n" + "#"*50)

    severity = "No depression indicated"
    if total_score > 0:
        for level, (min_score, max_score) in SCORING_RUBRIC.items():
            if min_score <= total_score <= max_score:
                severity = level
                break

    print(f"Total score: {total_score}")
    print(f"Severity: {severity}")

    if skipped_questions:
        print("\nSkipped:")
        for text in skipped_questions:
            print(f' - "{text}"')


def _display_goodbye_message():
    print("\nThank you for using this tool.")
    print("="*60)


# ==============================================================================
# --- MAIN ---
# ==============================================================================

def main():
    _display_welcome_message()

    total_score = 0
    skipped_questions = []

    for i, question_data in enumerate(PHQ9_QUESTIONS):
        print(f"\n--- Question {i + 1} of 9 ---")
        score = ask_question(question_data)

        if score is not None:
            total_score += score
        else:
            skipped_questions.append(question_data['clinical_text'])

    display_results(total_score, skipped_questions)
    _display_goodbye_message()


if __name__ == "__main__":
    main()
