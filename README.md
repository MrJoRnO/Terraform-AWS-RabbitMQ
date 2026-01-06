# High-Availability RabbitMQ Cluster on AWS

A production-ready, automated deployment of a 3-node RabbitMQ Cluster on AWS using Terraform. This project demonstrates Infrastructure as Code (IaC) principles, secure networking, and high-availability message brokering.

## 🏗️ Architecture Overview

The infrastructure is designed with a focus on security and resilience:

* **Networking:** A custom VPC with Public and Private subnets across multiple Availability Zones.
* **Security:** * RabbitMQ nodes are isolated in **Private Subnets**.
    * Internet access for updates is provided via a **NAT Gateway**.
    * Management access is restricted to an **Application Load Balancer (ALB)**.
    * SSH access is managed through a **Bastion Host**.
* **Clustering:** 3 EC2 instances running Ubuntu 24.04, automatically joined into a RabbitMQ cluster during the bootstrap process (User Data).
* **Load Balancing:** An Application Load Balancer (ALB) distributes traffic to the RabbitMQ Management UI and provides a single entry point for applications.



## 🛠️ Tech Stack

* **Cloud Provider:** AWS (EC2, VPC, ALB, NAT Gateway)
* **Infrastructure as Code:** Terraform
* **Message Broker:** RabbitMQ
* **OS:** Ubuntu 24.04 LTS
* **Language:** Bash (for User Data scripting)

## 🚀 Deployment Features

1.  **Automated Clustering:** Nodes automatically synchronize using a shared Erlang Cookie and join the cluster on startup.
2.  **Self-Healing Networking:** Security Groups are configured using the principle of least privilege, allowing internal cluster communication while blocking external threats.
3.  **Persistence:** RabbitMQ is configured to handle node failures without message loss (High Availability).
4.  **Static Master Node:** The first node is assigned a static private IP to ensure reliable cluster formation.

## 📂 Project Structure

├── main.tf                 # Root configuration
├── variables.tf            # Global variables
├── outputs.tf              # Connection URLs and IDs
├── modules/
│   ├── vpc-network/        # VPC, Subnets, NAT, ALB
│   └── ec2-RabbitMQ/       # EC2 Instances, Security Groups, User Data

## 💻 How to Use

### Prerequisites
* **Terraform installed** (v1.0.0+)
* **AWS CLI** configured with appropriate IAM permissions.
* **A pre-existing SSH Key Pair** in your target AWS region.

### Steps
1. **Clone the repo:** `git clone https://github.com/MrJoRnO/Terraform-AWS-RabbitMQ.git`
2. **Initialize Terraform:** `terraform init`
3. **Review the plan:** `terraform plan`
4. **Apply changes:** `terraform apply`

### Accessing the Cluster
Once the deployment is complete, Terraform will output the ALB DNS name.
* **Management UI:** `http://<ALB_DNS_NAME>:15672`
* **Default Credentials:** * **User:** `admin`
    * **Password:** `admin123`

---

## 🛡️ Security Implementation

* **Internal Communication:** Ports `4369` (EPMD) and `25672` (Inter-node) are open **only** within the cluster's Security Group to allow synchronization while preventing external interference.
* **External Access:** Only port `15672` is exposed via the **Application Load Balancer (ALB)** for management purposes. 
* **Traffic Isolation:** The RabbitMQ instances are located in **Private Subnets**, meaning they have no direct public IP addresses and cannot be reached directly from the internet.
