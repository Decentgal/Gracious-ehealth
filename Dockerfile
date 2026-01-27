# Builder stage
FROM python:3.11-slim AS builder
WORKDIR /app

COPY gracy.txt .

# Install dependencies into a specific folder to ensure they are easy to move
RUN pip install --no-cache-dir --upgrade pip setuptools \
    && pip install --no-cache-dir --prefix=/install -r gracy.txt

# Runtime stage
FROM gcr.io/distroless/python3-debian12
WORKDIR /app

# Copy ONLY the installed packages from the /install prefix
COPY --from=builder /install /usr/local
COPY gracious_app.py .

# Ensure Python knows where to look for those packages
ENV PYTHONPATH=/usr/local/lib/python3.11/site-packages
USER nonroot

EXPOSE 5000

# Correct CMD for Distroless
CMD ["gracious_app.py"]