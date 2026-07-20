FROM python:3.12-slim

RUN pip install --no-cache-dir flask urllib3

# Create a non-root user (required by OpenShift SCC)
RUN groupadd -r appuser && useradd -r -g appuser -d /app -s /sbin/nologin appuser

WORKDIR /app
COPY app.py .
RUN chown -R appuser:appuser /app && chmod -R a+r /app

USER appuser

ENV APP_PORT=8080
EXPOSE 8080

CMD ["python", "app.py"]
