FROM public.ecr.aws/docker/library/python:3.13
WORKDIR /app

# Install uv
RUN pip install uv

COPY source/requirements.txt .
RUN $HOME/.local/bin/uv pip install --system -r requirements.txt

COPY source/ .
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]