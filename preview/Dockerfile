FROM python@sha256:79e7a9b9ff1cbceff819f856fb374477792a5967759d94df266de7b7b4120e6f
RUN apk add --no-cache ffmpeg
WORKDIR /app
COPY --chmod=644 server.py test_server.py ./
USER 65532:65532
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PREVIEW_BIND=0.0.0.0
CMD ["python", "/app/server.py"]
