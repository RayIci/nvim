# Inventory service image for vale
FROM python:3.12-slim AS base

ARG APP_HOME=/app
ENV PYTHONUNBUFFERED=1 \
    MAX_ITEMS=1000

WORKDIR ${APP_HOME}
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && \
    echo "installed\n"

COPY . .
EXPOSE 8080
# TODO: run as non-root
CMD ["python", "-m", "inventory", "--port", "8080"]
