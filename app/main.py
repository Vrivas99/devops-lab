from fastapi import FastAPI

app = FastAPI()


@app.get("/")
def root() -> dict[str, str]:
    return {"message": "DevOps lab"}


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}