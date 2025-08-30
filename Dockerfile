# Two 3-stage Dockerfile: 1. tests 2. production 
#stage 1(base): the base for test and prod stages
FROM python:3.10-slim AS base
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .

#stage 2(test): include installing pytest for tests
FROM base AS test
RUN pip install --no-cache-dir pytest
CMD ["pytest", "-q"]

#stage 3(prod): only production
FROM base AS prod
CMD ["python", "api.py"]


