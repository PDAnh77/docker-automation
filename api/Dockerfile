FROM python:3.13-slim-bookworm

WORKDIR /app

# Copy the requirements file
COPY ./requirements.txt .

# Install Python deps
RUN pip install --no-cache-dir -r requirements.txt

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

COPY . .

RUN find / -perm /6000 -type f -exec chmod a-s {} \; || true

RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app

USER appuser

# Expose the port uvicorn will listen on
EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl --fail http://localhost:4000/health || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "4000"]