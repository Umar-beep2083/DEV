# ── Stage 1: Builder ───────────────────────────────────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /build

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Stage 2: Runtime ───────────────────────────────────────────────────────────
FROM python:3.11-slim AS runtime

WORKDIR /app

COPY --from=builder /install/lib /usr/local/lib
COPY --from=builder /install/bin /usr/local/bin

RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

COPY --chown=appuser:appuser . .

EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "wsgi:app"]
