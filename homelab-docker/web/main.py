from fastapi import FastAPI

app = FastAPI()

@app.get("/api")
def read_root():
    return {"status": "Backend is ok"}

@app.get("/healthz")
def health_check():
    return {"status": "ok"}
