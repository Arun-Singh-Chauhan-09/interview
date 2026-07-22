FROM python:3.12-slim
WORKDIR /app
COPY main.py .

ARG VERSION=dev
ENV APP_VERSION=${VERSION}

RUN useradd --create-home --uid 10001 appuser
USER appuser

EXPOSE 8080
ENTRYPOINT ["python", "main.py"]
