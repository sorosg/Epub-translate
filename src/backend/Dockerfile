FROM python:3.10-slim
WORKDIR /app
RUN apt-get update && apt-get install -y gcc libxml2-dev libxslt-dev curl git tesseract-ocr espeak ffmpeg hunspell hunspell-hu libhunspell-dev && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 5000
CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:5000", "app:app", "--timeout", "600", "--worker-class", "eventlet"]