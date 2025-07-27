## Introduction

This project provides a **detailed, step-by-step guide** to deploying a **centralized user authentication system using FreeIPA**, integrated with **AWS Route 53 DNS**, hosted on a **Red Hat Enterprise Linux (RHEL) EC2 instance**. FreeIPA offers identity management capabilities similar to Active Directory, making it suitable for managing users, groups, and policies in a Linux-based network.

The guide is tailored for beginners and walks through EC2 instance setup, DNS configuration with Route 53, FreeIPA installation, and user management using both command-line and web interfaces. The configuration ensures that the FreeIPA server is accessible using a custom domain and provides consistent name resolution and identity authentication.

By the end of this project, you will understand how to:
- Launch and configure an EC2 instance for FreeIPA
- Set up DNS resolution using Route 53 for your FreeIPA domain
- Install and configure a FreeIPA server with internal DNS
- Add and manage users using FreeIPA's tools
- Access and verify the FreeIPA web UI for centralized identity management
# Phase One: EC2 Instance Setup & DNS Configuration

## 1. EC2 RHEL Instance Preparation

### 1.1 Launch EC2 Instance

- **AMI**: Red Hat Enterprise Linux 8 or 9 (HVM)
- **Instance Type**: `t2.medium` or higher
- **Storage**: At least 20 GB (General Purpose SSD recommended)

### 1.2 Configure Security Group

Ensure the following inbound ports are allowed in the security group:

| **Port** | **Protocol** | **Purpose**                      |
|----------|--------------|----------------------------------|
| 22       | TCP          | SSH access                       |
| 80       | TCP          | HTTP                             |
| 443      | TCP          | HTTPS                            |
| 389      | TCP/UDP      | LDAP                             |
| 636      | TCP/UDP      | LDAPS                            |
| 88       | TCP/UDP      | Kerberos                         |
| 464      | TCP/UDP      | Kerberos password change         |
| 123      | UDP          | NTP (Time Synchronization)       |
| 7389     | TCP          | FreeIPA LDAP Replication         |
| 9443     | TCP          | FreeIPA Web UI Port              |
| 9444     | TCP          | Dogtag CA REST API               |
| 9445     | TCP          | Dogtag Secure Agent Port         |

### 1.3 Elastic IP

- Allocate an Elastic IP from AWS.
- Associate it with your EC2 instance for a static public IP.

### 1.4 Connect via SSH

```bash
ssh -i your-key.pem ec2-user@<Elastic-IP>
```

## 2. Hostname & DNS Setup

This step configures your EC2 instance to use a **Fully Qualified Domain Name (FQDN)** and integrates it with **Route 53** for external DNS resolution.

---

### 2.1 Set the Hostname

Set the hostname of your EC2 instance:

```bash
sudo hostnamectl set-hostname ipa.internal.my-project-domain.com
```

### 2.2 Update /etc/hosts
Open the hosts file using:

``` bash
sudo vi /etc/hosts
```
Add the following line (replace <PRIVATE_IP> with your EC2 instance's private IP address):
``` bash
<PRIVATE_IP> ipa.internal.my-project-domain.com ipa
```

### 2.3 Configure Route 53 DNS

To ensure your FreeIPA server is accessible via a domain name, configure DNS using AWS Route 53:

1. Go to **AWS Console → Route 53 → Hosted Zones**
2. Select your hosted zone: `my-project-domain.com`
3. Click **"Create record"**
4. Fill in the details:
   - **Name**: `ipa.internal`
   - **Type**: `A`
   - **Value**: *Your EC2 Elastic IP address*

This creates a DNS record so `ipa.internal.my-project-domain.com` resolves to your EC2 instance.

## Step 3: Install FreeIPA Server

### 3.1 Install Required FreeIPA Packages

Install the FreeIPA server, DNS integration components, and related dependencies:

```bash
sudo dnf install -y ipa-server ipa-server-dns bind-dyndb-ldap
```
## Step 4: Configure FreeIPA Server

This step initializes and configures the FreeIPA server with integrated DNS support.

### 4.1 Run the IPA Server Installer

Execute the following command to begin FreeIPA setup:

```bash
sudo ipa-server-install --setup-dns --domain=internal.my-project-domain.com --realm=INTERNAL.MY-PROJECT-DOMAIN.COM --hostname=ipa.internal.my-project-domain.com --ip-address=<PRIVATE_IP> --no-forwarders --no-ntp
```
During the installation, you will be prompted to:

- Set the Directory Manager password

- Set the IPA admin password

Once completed, confirm with "yes"

### 4.2 Allow Services in Firewall
```bash
sudo firewall-cmd --add-service=freeipa-ldap --permanent
sudo firewall-cmd --add-service=freeipa-ldaps --permanent
sudo firewall-cmd --add-service=http --permanent
sudo firewall-cmd --add-service=https --permanent
sudo firewall-cmd --add-service=ntp --permanent
sudo firewall-cmd --reload
```

## Step 5: Verify IPA Web UI

After successful installation, verify the FreeIPA web interface to ensure it's accessible and functioning properly.

### Access Web Interface

Open your browser & Navigate to:
```bash
https://ipa.internal.my-project-domain.com
 ```
Handle SSL Certificate Warning:
- You'll see a security warning about self-signed certificate
- Click "Advanced" or "Show Details"
- Click "Proceed to ipa.example.com (unsafe)" or similar option

Login to FreeIPA as Admin:
- Username: admin
- Password: [IPA admin password you set during installation]

## Step 6: Verifying and Creating Users & Groups

### 6.1 Verify System Information

- Navigate to **IPA Server → Configuration**
- Confirm that:
  - Server name is correct
  - Domain is set as expected
  - Realm matches your configuration

### 6.2 Check DNS Configuration

- Navigate to **Network Services → DNS → DNS Zones**
- Ensure the following are present:
  - A forward DNS zone (e.g., `my-project-domain.com.`)
  - A reverse DNS zone (based on your private IP subnet)



### 6.3: Create User Groups

**Location:** FreeIPA Web Interface → Identity → Groups

1. Navigate to **Identity → Groups**
2. Click **Add**
3. Enter the following group details:

   - **Group name:** `developers`
   - **Description:** `Development Team`

4. Click **Add**
5. Repeat the same steps to create the following groups:

   - **Group name:** `sysadmins`  
     **Description:** `System Administrators`
   
   - **Group name:** `users`  
     **Description:** `General Users`

---

### 6.4: Create Test Users via Web Interface

**Location:** FreeIPA Web Interface → Identity → Users

1. Navigate to **Identity → Users**
2. Click **Add**
3. Enter the following details for each user:

   **User 1:**
   - **User login:** `jdoe`
   - **First name:** `John`
   - **Last name:** `Doe`
   - **Email:** `john.doe@example.com`

   **User 2:**
   - **User login:** `asmith`
   - **First name:** `Alice`
   - **Last name:** `Smith`
   - **Email:** `alice.smith@example.com`

4. Click **Add** after entering each user
5. After user creation, click on the username
6. Navigate to **Actions → Reset Password**
7. Set a temporary password
8. Repeat the process for each user

---

### 6.5: Assign Users to Groups via Web Interface

**Location:** FreeIPA Web Interface → Identity → Groups

1. Navigate to **Identity → Groups**
2. Click on the group name (e.g., `developers`)
3. In the **Members** section, click **Add**
4. From the available users list, select the appropriate user (e.g., `jdoe`)
5. Click the arrow (`>`) to move the user to the selected list
6. Click **Add**
7. Repeat the process to assign users to other groups

## Step 7: ## User Login Demonstration

1. **Log out** from the current admin session on the FreeIPA Web Interface.

2. Open a web browser and navigate to:

```bash
https://ipa.internal.my-project-domain.com
```

3. **Log in** using the credentials of a regular user (e.g., `jdoe` or `asmith`).

4. Upon successful login, you will be redirected to the user dashboard.

5. As a regular user, your **permissions and privileges** will be limited, ensuring you only have access to functionalities assigned to your role or group.
## Conclusion

This FreeIPA server setup provides a powerful and centralized identity and access management (IAM) solution for Linux-based infrastructures. By deploying FreeIPA on an EC2 instance and integrating it with AWS Route 53 for DNS, administrators can easily manage users, groups, and authentication from a unified web interface.

The project is especially useful in enterprise environments where consistent user access control, policy enforcement, and secure authentication are essential. It simplifies user onboarding, improves security, and provides a scalable foundation for managing resources in hybrid or cloud-native systems.

