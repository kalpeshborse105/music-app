FROM python:3.10-slim

WORKDIR /app

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8080

RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY server.py .
COPY data/ ./data/
COPY app-ads.txt* .
COPY robots.txt* .
COPY .well-known/ ./.well-known/

EXPOSE 8080

CMD ["gunicorn", "-b", "0.0.0.0:8080", "--workers", "2", "--threads", "8", "--timeout", "120", "server:app"]
