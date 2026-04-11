from fastapi import FastAPI, Request
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles

app = FastAPI()
app.mount("/static", StaticFiles(directory="static"), name='static')
templates = Jinja2Templates(directory="templates")

@app.get("/", include_in_schema=False)
def root(request: Request):
    return templates.TemplateResponse(
        request,
        "home.html"
    )