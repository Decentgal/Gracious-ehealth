# Builder stage
FROM python:3.13-slim AS builder
WORKDIR /app

COPY gracy.txt .

# Install dependencies
RUN pip install --no-cache-dir --upgrade pip setuptools \
    && pip install --no-cache-dir --prefix=/install -r gracy.txt

# Runtime stage - Use the 'base' version which is cleaner for manual installs
FROM gcr.io/distroless/cc-debian12
WORKDIR /app

# 1. Copy the entire Python installation from builder
COPY --from=builder /usr/local/ /usr/local/

# 2. Copy the GLIBC and system libraries from the builder to satisfy the 2.38 requirement
COPY --from=builder /lib/x86_64-linux-gnu/ /lib/x86_64-linux-gnu/
COPY --from=builder /usr/lib/x86_64-linux-gnu/ /usr/lib/x86_64-linux-gnu/

# 3. Copy your installed app packages and code
COPY --from=builder /install /usr/local
COPY gracious_app.py .

# 4. Set paths
ENV LD_LIBRARY_PATH=/usr/local/lib:/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu
ENV PYTHONPATH=/usr/local/lib/python3.13/site-packages
USER nonroot

EXPOSE 5000

ENTRYPOINT ["/usr/local/bin/python3"]
CMD ["gracious_app.py"]