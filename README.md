**AN e-HEALTH CI/CD PIPELINE COMPLIANT TO HIPAA, GDPR, OWASP Top 10, ISO 27001 & NIST standards.**

This repository implements a zero-trust architecture with a security-first CI/CD pipeline for a Python-based eHealth application. The pipeline is designed to protect patient data by enforcing security controls at build time and runtime using DevSecOps tools. Every code push is automatically scanned, tested, and validated before being approved for deployment to Production.


**Application Overview**

The application is a world-class secure healthcare environment with a focus on Zero-Trust architecture and automated security scanning. I moved away from static credentials toward the modern authentication best practice: **Identity Federation**.

This application is a lightweight Flask API that exposes a health status endpoint while enforcing strong HTTP security headers to mitigate common web vulnerabilities.

Endpoint

GET /

Response

{
  "status": "Green",
  "security": "Welcome to Gracious e-Health Application"
}



**TECHNOLOGY STACKS USED**

(a). **The core Application** 
- Infrastructure-as-Code: Terraform
- Cloud Provider: AWS (us-east-1)
- Linux (Ubuntu for Runners, Python-slim for Docker)
- Infrastructure provisioned: KMS, Secrets Manager, IAM OIDC Provider, VPC, ALB, WAF, Lambda Function, CloudWatch.
- Identity: OpenID Connect (OIDC)
- Web Server: Gunicorn (used for production-grade serving of the Flask app).
- Cloud SDK: Boto3 (the AWS SDK for Python used to securely fetch database secrets and KMS keys).
- Data Security: Encryption was enforced using AWS KMS and secret rotation using Secrets Manager
- Language: Python 3.13.12
- Framework: Flask


(b). **Cloud Infrastructure**
- Compute: AWS Lambda (for secret rotation) and EC2 Instance (for running the app)
- Networking: Amazon VPC, with public/private subnets, Internet Gateway, and Route Tables.
- Load Balancing: Application Load Balancer (ALB), handling traffic distribution and SSL/TLS.
- Database Security: AWS Secrets Manager, used to store and rotate sensitive database credentials
- Encryption: AWS KMS (Key Management Service), providing the master keys for encrypting PHI (Protected Health Information) data at rest.


(c). **Security**
- WAF: AWS WAFv2, protected your app against SQL injection and XSS attacks using Managed Rule Sets.
- Logging: VPC Flow Logs (for network traffic) and S3 Access Logs (for ALB traffic audit).
- Identity: OIDC (OpenID Connect), used for the secure, passwordless handshake between GitHub Actions and AWS.


(d). **DevSecOps & GitOps Pipeline**
- Infrastructure as Code (IaC): Terraform (defined every AWS resource as code for consistency)
- CI/CD Platform: GitHub Actions (the workflow automating the entire build-test-deploy/SDLC lifecycle)
- Containerization: Docker (packaged the app into a portable, secure image using a multi-stage, Distroless runtime)
- Scanner I: Checkov (The IaC scanner to check for any misconfigurations in the Terraform codes e.g., S3 buckets)
- Scanner II: Trivy (Performed SAST/Static Analysis on the Dockerfiles and container images).
- Scanner III: OWASP ZAP (Performed DAST/Dynamic Analysis to find vulnerabilities in the running web app)
- Version Control: Git & GitHub


**INDUSTRY COMPLIANCE**

- **HIPAA:** I ensured PHI is encrypted at rest and in transit using KMS and Secrets Manager.
- **ISO 27001:** Adheres to Access Control (A.9) and Cryptographic Controls (A.10).
- **NIST 800-207:** I implemented Zero-Trust principles by assuming roles using OIDC rather than using keys.
- **OWASP Top 10:** I integrated OWASP ZAP to scan for runtime vulnerabilities (XSS, SQLi).
- **GDPR Article 32(1)(d):** I implemented a process for regularly testing, assessing, and evaluating the effectiveness of technical and organizational measures using Checkov, WAF, Trivy and OWASP ZAP.



**Local setup & testing**

1. Clone this repo: `git clone https://github.com/Decentgal/Gracious-ehealth.git`
2. Initialize Terraform: `terraform init`
3. Build: `docker build -t ehealth-app`
4. Run: `docker run -d --name ehealth-test -p 8080:5000 ehealth-app`


**Project structure               and their contents**

├── gracious_app.py        Flask application with security headers

├── gracy.txt              Dependency pinning & security fixes

├──terraform/              IaC

|   └── iam.tf             Defines IAM resources (role & policy)

|   └── oidc.tf            Defines the GitHub OIDC trust setup

|   └── provider.tf        Defines how Terraform connects to AWS

|   └── main.tf            Core infrastructure resources (KMS, Secrets Manager)

├── Dockerfile             Multi-stage hardened container build

├── .github/workflows/

│   └── deploy.yml         CI/CD security pipeline

│   └── gitops.yml         GitOps pipeline

├── .gitignore             Credentials

├── README.md              Technical documentation



**SECURITY CONTROLS IMPLEMENTED**

1. **Application-level hardening:** I enforced multiple HTTP security headers, including:

- X-Content-Type-Options
- X-Frame-Options
- Content-Security-Policy
- X-XSS-Protection
- Permissions-Policy
- Cross-Origin-Opener-Policy
- Cross-Origin-Embedder-Policy
- Cache-Control
- Server version leakage is explicitly disabled to prevent fingerprinting


2. **Dependency security**: Dependencies are explicitly pinned in gracy.txt to prevent:

- Dependency confusion attacks
- Introduction of known vulnerable versions
- Additional packages are included to address Trivy-detected security issues


3. **Hardened Container Image:** This application uses a multi-stage Docker build
- **Builder Stage:** Installs dependencies in an isolated environment
- **Runtime Stage:** Uses a Distroless Python image, removing shells and package managers


4. **Security benefits:**

- Minimal attack surface
- No root access (USER nonroot)
- Reduced container size


5. **CI/CD Security Pipeline:** The GitHub Actions pipeline automatically runs on every push using the following pipeline stages:

Code Push
   ↓
Checkout Repository
   ↓
Trivy Config Scan (Dockerfile)
   ↓
Docker Image Build
   ↓
IaC Scanning (Checkov)
   ↓
Trivy Image Scan (SAST)
   ↓
Deploy Container (Isolated)
   ↓
OWASP ZAP Scan (DAST)
   ↓
Security Report Upload
   ↓
Deployment Approval



6. **Infrastructure-as-Code scanning:** The tool used here is **Checkov* and it scans and audits my high-availability:

- VPC configurations are audited for security best practices before the application tests begin.
- Application Load Balancer (ALB) configurations for security best practices before the application tests begin.
- Web Application Firewall (WAF) configurations for security best practices before the application tests begin.


7. **Static Application Security Testing (SAST):** The tool used here is **Trivy* and it scans:

- Scans Dockerfile configurations
- Scans OS packages and Python dependencies
- Blocks builds on CRITICAL and HIGH vulnerabilities


8. **Dynamic Application Security Testing (DAST):** The tool I used here is OWASP ZAP for baseline scan. It does the following:

- Application is deployed in a temporary container
- ZAP performs automated security testing
- Findings are reported 
- Security reports are uploaded as pipeline artifacts:

**HTML*
**Markdown*
**JSON*


9. **Prerequisites you need to run locally:**

- Python 3.13.12
- Docker
- Git
- Terraform
- Trivy (optional for local scans)

**You can run this application locally without Docker*
- pip install -r gracy.txt
- python gracious_app.py

**On your browser, visit: 'http://localhost:5000' OR 'http://127.0.0.0:5000'

**You can build and run with Docker:*
- docker build -t ehealth-app .
- docker run -p 5000:5000 ehealth-app


**You can also run Trivy locally (optional)**
trivy image ehealth-app



10. **Security Outcome:** Only code that successfully:

- Passes Checkov configuration scans
- Passes Trivy image vulnerability scans
- Successfully runs OWASP ZAP security tests is allowed to proceed toward deployment.


This application is 100% reproducible by anyone. It is hosted on AWS within a hardened VPC featuring public/private subnets, an Application Load Balancer (ALB), and a WAFv2 protected by AWS Managed Rule Sets to block SQLi and XSS attacks. Security is integrated at every stage of the CI/CD lifecycle: Checkov scans the IaC for misconfigurations, Trivy performs SAST on Docker images, and OWASP ZAP executes DAST on the running container.


To enforce Zero Trust, I implemented passwordless OIDC authentication between GitHub and AWS, utilized AWS KMS for data encryption, and configured Secrets Manager with automated rotation via Lambda. The final result is a production-ready, compliant infrastructure.


**In the end, this pipeline ensures a secure, reliable, and privacy-focused experience for every user, patients, and healthcare system.*