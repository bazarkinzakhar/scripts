from fastapi import FastAPI

app = FastAPI()

@app.get("/api")
async def root():
    return {"message": "python backend is working via traefik", "status": "success"}

@app.get("/")
async def home():
    return {"message": "this is home"}