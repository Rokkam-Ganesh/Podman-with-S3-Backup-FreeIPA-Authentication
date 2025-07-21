## Introduction

This project demonstrates how to deploy a lightweight web server using Podman inside an Amazon EC2 instance running Red Hat Enterprise Linux. The server hosts a simple static HTML page served from within a container. In addition to containerization, the project integrates cloud storage by backing up the web content to an Amazon S3 bucket.

The guide follows a beginner-friendly, step-by-step approach to set up the infrastructure, build and run the container, and configure automated backup using AWS CLI. This setup provides a practical example of combining containerization and cloud storage in a real-world deployment scenario.

By the end of this project, you will understand how to:
- Set up a Red Hat EC2 instance on AWS
- Install and use Podman to run a containerized web server
- Create a simple HTML-based website
- Backup between your EC2 instance and Amazon S3

## Phase One: Infrastructure Setup

This phase involves setting up the necessary cloud infrastructure on AWS, including an EC2 instance, IAM role for S3 access, and an S3 bucket to store backups.

---

### Step 1: Launch EC2 Instance

1. **Log in to AWS Console**
   - Go to [https://console.aws.amazon.com](https://console.aws.amazon.com)
   - Sign in with your AWS credentials

2. **Navigate to EC2 Dashboard**
   - Go to **Services** → **EC2** → **Launch Instance**

3. **Configure the Instance**
   - **Name:** `podman-webserver`
   - **AMI:** Red Hat Enterprise Linux 9 (64-bit x86)
   - **Instance Type:** `t3.medium` (2 vCPU, 4 GB RAM)
   - **Key Pair:** Create a new key pair or select an existing one

4. **Set Security Group Rules**
   - Create a new security group and allow the following:
     - **SSH (Port 22):** Source – My IP
     - **HTTP (Port 80):** Source – Anywhere (0.0.0.0/0)
     - **HTTPS (Port 443):** Source – Anywhere (0.0.0.0/0)
     - **Custom TCP (Port 8080):** Source – Anywhere (0.0.0.0/0)

5. **Configure Storage**
   - **Root Volume:** 20 GB (gp3)
   - **Additional Volume:** Add 10 GB for container data

---

### Step 2: Create IAM Role for S3 Access

**Where to Perform:** AWS Console → IAM Dashboard

1. **Create IAM Role** : This IAM Role is used by EC2 instance to access S3 Bucket for Backup
   - Navigate to **Services** → **IAM** → **Roles** → **Create Role**
   - **Trusted Entity:** EC2
   - **Permissions Policy:** Attach `AmazonS3FullAccess`
   - **Role Name:** `EC2-S3-Backup-Role`

2. **Attach IAM Role to EC2 Instance**
   - Go to **EC2 Console** → **Instances**
   - Select your instance → **Actions** → **Security** → **Modify IAM Role**
   - Attach the newly created `EC2-S3-Backup-Role`

---

### Step 3: Create S3 Bucket

**Where to Perform:** AWS Console → S3 Dashboard

1. **Create a New Bucket**
   - Navigate to **Services** → **S3** → **Create Bucket**
   - Configure the following:
     - **Bucket Name:** `podman-webserver-backup-[your-initials]-[random-number]`
     - **Region:** Same as your EC2 instance
     - **Block Public Access:** Keep all options enabled (default)
     - **Versioning:** Enable to allow future restoration of older versions

---
You can either use the above configuration or customize it according to your specific requirements.

## Phase Two: EC2 instance connection and installing necessary packages

### Step 1: Connect to EC2 Instance

Once your EC2 instance is running, connect to it via SSH using your key pair.

```bash
# Replace with your private key file and instance public IP
ssh -i your-key.pem ec2-user@your-instance-public-ip

# Update System
sudo dnf update -y
```

### Step 2: Install Required Packages

Install essential packages including Podman, AWS CLI, and a few utilities for development and monitoring.

```bash
# Install Podman
sudo dnf install -y podman podman-compose

# Install AWS CLI
sudo dnf install -y awscli

# Install additional tools
sudo dnf install -y git vim tree htop

# Check Podman version
podman --version

# Check AWS CLI
aws --version

# Configure AWS CLI (Using IAM Role)
aws s3 ls

# List your bucket
aws s3 ls s3://your-bucket-name/
```


## Phase Three: Creating Web Application Files

### Step 1: Create Project Directory Structure

To organize your project files and support containerization with backup functionality, create a clean directory structure under your home directory.

```bash
# Create the project directory and subfolders
mkdir -p ~/podman-webserver/{html,data,scripts,backups}
cd ~/podman-webserver

# Visualize the structure
tree .
```

### Directory Explanation:

- html/ - Web application files
- data/ - Application data to be backed up
- scripts/ - Backup and management scripts
- backups/ - Local backup storage

### Creating Web Apllication Files:

At Location:  ~/podman-webserver/html/

#### Create these files


```bash
# Add the code of index.html at Podman S3 Backup/Web Page Files/index.html
vim index.html

# Add the code of style.css at Podman S3 Backup/Web Page Files/style.css
vim style.css

# Add the code of script.js at Podman S3 Backup/Web Page Files/script.js
vim script.js
```

### For Applcation Data Create the Sample File

```bash
# Location: ~/podman-webserver/data/
cd ~/podman-webserver/data/

# Create sample application data
echo '{"users": [{"id": 1, "name": "John Doe", "email": "john@example.com"}]}' > users.json

echo '{"config": {"server_name": "podman-webserver", "port": 8080, "debug": false}}' > config.json

echo "$(date): Server started" > app.log
echo "$(date): Application initialized" >> app.log
echo "$(date): Ready to serve requests" >> app.log

# Create a larger sample file
for i in {1..100}; do
    echo "Log entry $i: $(date) - Sample application event" >> sample_data.log
done
```

## Phase Four: Create and Configure Podman Container

### Step 1: Create Dockerfile

```bash
# Location: ~/podman-webserver/
cd ~/podman-webserver
vim Dockerfile

# Dockerfile at Podman S3 Backup/Uitility Files/Dockerfile
FROM nginx:alpine

LABEL maintainer="your-email@example.com"
LABEL description="Podman Web Server with S3 Backup"

COPY html/ /usr/share/nginx/html/

RUN mkdir -p /app/data

COPY data/ /app/data/

RUN echo 'server { \
    listen 80; \
    server_name localhost; \
    location / { \
        root /usr/share/nginx/html; \
        index index.html; \
        try_files $uri $uri/ =404; \
    } \
    location /data { \
        alias /app/data; \
        autoindex on; \
        autoindex_exact_size off; \
        autoindex_format html; \
        autoindex_localtime on; \
    } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

```

### Step 1: Building the image and Running the container

```bash
# Location: ~/podman-webserver/

# Builds a Docker Image
podman build -t webserver-app:v1.0 .

# Create container with persistent data volume
podman run -d --name webserver-container -p 8080:80 -v ~/podman-webserver/data:/app/data:Z --restart unless-stopped webserver-app:v1.0

# Check container status
podman ps
```

## Phase Five: Create Backup System and Setting a Cron Job

### Step 1:  Creating Backup Script and Running it

```bash
# Location: ~/podman-webserver/scripts/
cd ~/podman-webserver/scripts/

# Backup.sh at Podman S3 Backup/Uitility Files/Backup.sh
vim Backup.sh

# Make it Executable
chmod +x Backup.sh
```


### Step-2: Running the Backup Script and Verifying in S3 Bucket

```bash
# Location: ~/podman-webserver/scripts/
cd ~/podman-webserver/scripts/

# Run the script
./backup-to-s3.sh

# List S3 bucket contents
aws s3 ls s3://your-bucket-name/backups/ --recursive --human-readable
```

### Step-3: Creating a cron job for automated backup schedule

```bash
# Creating a Cron Job
crontab -e

# Or for daily backup at 2 AM
0 2 * * * /home/ec2-user/your-bucket-name/scripts/backup-to-s3.sh >> /home/ec2-user/your-bucket-name/backups/backup.log 2>&1

# List cron jobs
crontab -l

# Check if cron service is running
systemctl status crond
```

## Conclusion

This project demonstrates how to containerize and manage a web server using Podman, with automated backup and restore capabilities using AWS S3. All critical components such as HTML files, scripts, and data are structured and maintained efficiently. Specifically, the `data/` folder—which holds important application data—is regularly backed up and securely stored in your designated S3 bucket for recovery and portability.
