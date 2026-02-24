import uvicorn
import logging
from datetime import datetime
from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse,StreamingResponse
from pydantic import BaseModel
from export_report import generate_excel_report
from io import BytesIO

import questionnaire as qn
import activity_journal as aj

# ------------------------------------------------------------------
# LOGGING
# ------------------------------------------------------------------
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ------------------------------------------------------------------
# APP INIT
# ------------------------------------------------------------------
app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ------------------------------------------------------------------
# HEALTH / MISC
# ------------------------------------------------------------------
@app.get("/health")
def health():
    return {"status": "OK"}

@app.get("/favicon.ico")
async def favicon():
    return FileResponse("favicon.ico")

# ------------------------------------------------------------------
# IN-MEMORY SESSIONS (PHQ-9 + WEEKLY ACTIVITY ONLY)
# ------------------------------------------------------------------
sessions = {}
activity_sessions = {}

# ==================================================================
# PHQ-9 ENDPOINTS (UNCHANGED)
# ==================================================================
@app.post("/start")
async def start():
    session_id = "user123"
    sessions[session_id] = {
        "index": 0,
        "score": 0,
        "skipped": [],
        "done": False,
        "final_difficulty": None
    }

    qtext = qn.generate_conversational_prompt(
        qn.PHQ9_QUESTIONS[0]["clinical_text"]
    )

    return {
        "session_id": session_id,
        "question_number": 1,
        "question": f"Question 1: {qtext}",
        "choices": qn.ANSWER_CHOICES
    }


@app.post("/message")
async def message(req: Request):
    data = await req.json()
    session_id = data["session_id"]
    user_input = data["user_input"]

    state = sessions.get(session_id)
    if not state:
        raise HTTPException(status_code=404, detail="Session not found")

    if state["done"]:
        return {
            "done": True,
            "total_score": state["score"],
            "skipped": state["skipped"],
            "difficulty": state["final_difficulty"],
        }

    # Final functional difficulty question
    if state["index"] >= 9 and state["final_difficulty"] is None:
        try:
            ans = int(user_input)
            if ans in [1, 2, 3, 4]:
                state["final_difficulty"] = ans
        except:
            pass

        state["done"] = True

        severity = "No depression indicated"
        if state["score"] > 0:
            for level, (low, high) in qn.SCORING_RUBRIC.items():
                if low <= state["score"] <= high:
                    severity = level
                    break

        return {
            "done": True,
            "total_score": state["score"],
            "severity": severity,
            "skipped": state["skipped"],
            "difficulty": state["final_difficulty"]
        }

    try:
        ans = int(user_input)
    except:
        ans = qn.interpret_free_text_answer(user_input)

    if ans in qn.ANSWER_CHOICES:
        state["score"] += qn.ANSWER_CHOICES[ans]["score"]
    else:
        state["skipped"].append(
            qn.PHQ9_QUESTIONS[state["index"]]["clinical_text"]
        )

    state["index"] += 1

    if state["index"] < 9:
        qtext = qn.generate_conversational_prompt(
            qn.PHQ9_QUESTIONS[state["index"]]["clinical_text"]
        )
        return {
            "done": False,
            "question_number": state["index"] + 1,
            "question": f"Question {state['index']+1}: {qtext}",
            "choices": qn.ANSWER_CHOICES
        }
    else:
        return {
            "done": False,
            "question_number": 10,
            "question": (
                "Final Question: How difficult have these problems made it for you "
                "to do your work, take care of things at home, or get along with others?"
            ),
            "choices": {
                1: "Not difficult at all",
                2: "Somewhat difficult",
                3: "Very difficult",
                4: "Extremely difficult"
            }
        }

# ==================================================================
# WEEKLY ACTIVITY JOURNAL (UNCHANGED)
# ==================================================================
@app.post("/weekly-activity/start")
async def start_activity_journal(req: Request):
    data = await req.json()
    session_id = data.get("session_id", "user123")
    initial_entry = data.get("initial_entry")

    if not initial_entry:
        raise HTTPException(status_code=400, detail="Initial entry is required")

    activity_sessions[session_id] = {
        "transcript": [{"speaker": "user", "message": initial_entry}],
        "reply_count": 0,
        "done": False
    }

    transcript_text = f"User: {initial_entry}"
    bot_question = aj.generate_unfolding_question(transcript_text)

    activity_sessions[session_id]["transcript"].append(
        {"speaker": "bot", "message": bot_question}
    )

    return {
        "session_id": session_id,
        "question": bot_question,
        "done": False
    }


@app.post("/weekly-activity/message")
async def process_activity_message(req: Request):
    data = await req.json()
    session_id = data.get("session_id")
    user_input = data.get("user_input")

    state = activity_sessions.get(session_id)
    if not state:
        raise HTTPException(status_code=404, detail="Session not found")

    state["transcript"].append({"speaker": "user", "message": user_input})
    state["reply_count"] += 1

    if state["reply_count"] >= aj.MAX_USER_REPLIES:
        state["done"] = True
        return {
            "done": True,
            "log": {
                "transcript": state["transcript"],
                "mood_score": None
            },
            "message": "Thanks for sharing, I've got that."
        }

    transcript_text = "\n".join(
        f"{i['speaker'].title()}: {i['message']}" for i in state["transcript"]
    )

    bot_question = aj.generate_unfolding_question(transcript_text)
    state["transcript"].append({"speaker": "bot", "message": bot_question})

    return {"done": False, "question": bot_question}

# ==================================================================
# ✅ THOUGHT RECORD (QUIZ-BASED — NEW)
# ==================================================================
THOUGHT_RECORD_QUESTIONS = [
    {
        "key": "trigger",
        "text": "What happened?",
        "helper": "Briefly describe the situation or event.",
        "required": True
    },
    {
        "key": "feeling",
        "text": "How did it make you feel?",
        "helper": "You can mention one or more emotions.",
        "required": True
    },
    {
        "key": "negative_thought",
        "text": "What negative thoughts did you have?",
        "helper": "What went through your mind at that moment?",
        "required": True
    },
    {
        "key": "new_thought",
        "text": "Is there a more balanced or helpful thought?",
        "helper": "If nothing comes to mind, you can leave this blank.",
        "required": False
    },
    {
        "key": "outcome",
        "text": "What happened afterward?",
        "helper": "Describe what happened next, if anything.",
        "required": False
    }
]

class ThoughtRecordSubmit(BaseModel):
    answers: dict

@app.get("/thought-record/questions")
async def get_thought_record_questions():
    return {"questions": THOUGHT_RECORD_QUESTIONS}

@app.post("/thought-record/submit")
async def submit_thought_record(payload: ThoughtRecordSubmit):
    answers = payload.answers

    for q in THOUGHT_RECORD_QUESTIONS:
        if q["required"]:
            key = q["key"]
            if key not in answers or not str(answers[key]).strip():
                raise HTTPException(
                    status_code=400,
                    detail=f"Missing required field: {key}"
                )

    record = {
        "trigger": answers.get("trigger", ""),
        "feeling": answers.get("feeling", ""),
        "negative_thought": answers.get("negative_thought", ""),
        "new_thought": answers.get("new_thought", ""),
        "outcome": answers.get("outcome", ""),
        "timestamp": datetime.utcnow().isoformat()
    }

    logger.info(f"Thought Record saved: {record}")

    return {
        "status": "success",
        "message": "Thought record saved successfully",
        "record": record
    }
    
    
# EXPORT Reports

@app.post("/reports/excel")
async def generate_excel(data: dict):
    try:
        excel_bytes = generate_excel_report(data)

        return StreamingResponse(
            BytesIO(excel_bytes),
            media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            headers={
                "Content-Disposition": "attachment; filename=cbt_report.xlsx"
            },
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ------------------------------------------------------------------
# RUN
# ------------------------------------------------------------------
if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
