# Docker Compose Setup

This repository provides a **Docker Compose** setup for running a **Confluent Platform** (Kafka-based streaming platform), an **HTTP Request Log Service**, and a **PostgreSQL database**. This setup is ideal for development and testing.

## 📌 Services

### 1️⃣ Confluent Platform
- Provides a **single-broker** Kafka setup with essential components like **Zookeeper, Kafka Broker, Schema Registry, Kafka Connect, ksqlDB, and Control Center**.
- **Supervisor Web UI** available on port **9001**.
- **Image:** [shinzhang124/cp-all-in-one](https://hub.docker.com/r/shinzhang124/cp-all-in-one)

### 2️⃣ HTTP Request Log Service
- Logs incoming HTTP requests and allows you to inspect request details via a web UI or API.
- **Web UI:** Accessible on **http://localhost:3000**.
- **API Docs:** Available at **http://localhost:3000/api/v1/docs**.
- **Image:** [shinzhang124/http-request-log-service](https://hub.docker.com/r/shinzhang124/http-request-log-service)

### 3️⃣ PostgreSQL Database
- Stores application data.
- Default credentials:
  - **User:** `user`
  - **Password:** `passwd`
  - **Database:** `testdb`
- Accessible on **port 5432**.

## 🛠 Install Docker & Docker Compose on Ubuntu
Before running the setup, install **Docker** and **Docker Compose Plugin** on your Ubuntu system:

### 🔹 Install Docker
```sh
sudo apt update
sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc > /dev/null
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io
```

### 🔹 Install Docker Compose Plugin
```sh
sudo apt install -y docker-compose-plugin
```

### 🔹 Verify Installation
```sh
docker --version
docker compose version
```

## 🚀 How to Run

1. **Clone this repository:**
   ```sh
   git clone <your-repo-url>
   cd <your-repo-folder>
   ```

2. **Start all services:**
   ```sh
   docker compose up -d
   ```

3. **Verify running containers:**
   ```sh
   docker ps
   ```

4. **Access the services:**
   - **Confluent Control Center:** [http://localhost:9021](http://localhost:9021)
   - **HTTP Request Log Service:** [http://localhost:3000](http://localhost:3000)
   - **PostgreSQL:** Connect via `postgres://user:passwd@localhost:5432/testdb`

## 📡 Connecting Services

### 🔹 Kafka → PostgreSQL
- Use Kafka Connect to stream data into PostgreSQL.
- PostgreSQL is reachable from Kafka Connect at **`postgres:5432`**.
- Example JDBC connection string:
  ```sh
  jdbc:postgresql://postgres:5432/testdb
  ```

### 🔹 Kafka → HTTP Request Log Service
- The HTTP service is reachable within the network as **`http-request-log-service:3000`**.
- Example request from inside a container:
  ```sh
  curl http://http-request-log-service:3000
  ```

## 🛑 Stopping Services
To stop and remove all containers:
```sh
docker compose down
```

## 📌 Useful Commands
- **View logs for a service:**
  ```sh
  docker compose logs -f <service_name>
  ```
- **Restart a specific service:**
  ```sh
  docker compose restart <service_name>
  ```
- **Enter a running container:**
  ```sh
  docker exec -it <container_name> /bin/sh
  ```

## 🔗 Additional Resources
- **Confluent Platform Documentation:** [docs.confluent.io](https://docs.confluent.io/platform/current/)
- **HTTP Request Log Service:** [shinzhang124/http-request-log-service](https://hub.docker.com/r/shinzhang124/http-request-log-service)
- **Confluent Platform:** [shinzhang124/cp-all-in-one](https://hub.docker.com/r/shinzhang124/cp-all-in-one)

