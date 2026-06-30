from fastapi import FastAPI
from pydantic import BaseModel, Field


class BatchSignal(BaseModel):
    user_id: str = Field(..., min_length=1)
    period: str
    signal_type: str
    confidence: float = Field(..., ge=0, le=1)


app = FastAPI(title="Orb ML Worker")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "orb-ml-worker"}


@app.post("/signals/preview")
def preview_signal(signal: BatchSignal) -> dict[str, object]:
    return {
        "accepted": True,
        "signal": signal.model_dump(),
        "boundary": "ML batch only; Rails deterministic engine owns energy and action choices.",
    }
