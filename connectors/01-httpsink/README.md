
# Data Gen and HTTP Sink Connector  

---

## Objectives  
By the end of this workshop, participants will be able to:  
1. Understand Kafka Connect's architecture and common use cases.  
2. Set up a **Datagen Source Connector** to generate synthetic data.  
3. Configure and deploy an **HTTP Sink Connector** to stream data to a downstream service.  
4. Manage Connector's life cycle.
5. Inspect and validate data through a web UI.  

---

## Activities

### **0. Reference**  

- HTTP Sink Connector on Confluent Hub
https://www.confluent.io/hub/confluentinc/kafka-connect-http
- HTTP Sink Connector Documentation 
https://docs.confluent.io/kafka-connectors/http/current/overview.html
- HTTP Request Log Service to simulate downstream server
https://hub.docker.com/r/shinzhang124/http-request-log-service
- Confluent Platform all in one
https://hub.docker.com/r/shinzhang124/cp-all-in-one


---

### **1. Environment Setup**  

**Step 1:** Start the Docker environment:  
```bash
sudo docker-compose up -d
```  

**Step 2:** Validate running services:  
```bash
sudo docker ps
```  

> **Key Services:**  
> - **Confluent Platform** (Kafka, Connect, Schema Registry)  
> - **HTTP Request Log Service** (on port `3000`)  

- Review the Control Center on port 9021
- Examine the Connectors from the Control Center

---

### **2. Creating the Datagen Source Connector**  
> **Goal:** Generate synthetic data into a Kafka topic.  

**Step 1:** Create `datagen-source.json`:  
```json
{
  "name": "datagen-source",
  "config": {
    "connector.class": "io.confluent.kafka.connect.datagen.DatagenConnector",
    "kafka.topic": "users-topic",
    "quickstart": "users",
    "max.interval": 10000,
    "tasks.max": "1"
  }
}
```  

**Step 2:** Deploy the connector:  
```bash
curl -X POST -H "Content-Type: application/json" \
--data @datagen-source.json \
http://localhost:8083/connectors
```  

**Step 3:** Check connector status:  
```bash
curl http://localhost:8083/connectors/datagen-source/status
```

Then you can validate the connector in the Control Center UI.

**Step 4:** Validate data in Kafka via the Control Center. You need to check the schema and messages in the `users-topic`.


---

### **3. Configuring the HTTP Sink Connector**  
> **Goal:** Stream data to the downstream HTTP service and handle errors.  

**Step 1:** Create `http-sink.json`:  
```json
{
  "name": "http-sink",
  "config": {
    "connector.class": "io.confluent.connect.http.HttpSinkConnector",
    "tasks.max": "1",
    "topics": "users-topic",
    "http.api.url": "http://http-request-log-service:3000/api/v1/endpoint",
    "request.method": "post",
    "request.body.format": "json",
    "reporter.bootstrap.servers": "localhost:9092",
    "reporter.result.topic.name": "http-sink-success",
    "reporter.result.topic.replication.factor": "1",
    "reporter.error.topic.name":"http-sink-error",
    "reporter.error.topic.replication.factor":"1"
  }
}

```  

**Step 2:** Deploy the connector:  
```bash
curl -X POST -H "Content-Type: application/json" \
--data @http-sink.json \
http://localhost:8083/connectors
```  

**Step 3:** Verify connector status:  
```bash
curl http://localhost:8083/connectors/http-sink/status
```  

---

### 4. Validating the Results 

- **Access the Web UI:**  
```
http://localhost:3000
```  

- Inspect logged requests to confirm data arrival.  

- **Check success and error topics:**  
Login into the Control Center to examine the topic `http-sink-success` and `http-sink-error`

---

### 5. No Body Payload for JSON messages

Have you noticed the body section were empty on the `request logs` service?

Can you figure out why and fix it?

You can check the configurations: https://docs.confluent.io/kafka-connectors/http/current/connector_config.html

---

### **6. Modify the status code and check the errors**

- Modify the downstream HTTP status code from `20X` to `500` 
```
curl http://localhost:3000/statuscode?value=500
```

- Check your connector status
```bash
curl http://localhost:8083/connectors/http-sink/status
```  

- Examine the `http-sink-error` topic on Control Center


### **7. Patch your connector to fix it**
- create file `http-sink-config.json`
```bash
tee http-sink-config.json > /dev/null <<EOF
{
    "connector.class": "io.confluent.connect.http.HttpSinkConnector",
    "tasks.max": "1",
    "topics": "users-topic",
    "behavior.on.error": "log",
    "http.api.url": "http://http-request-log-service:3000/api/v1/endpoint",
    "request.method": "post",
    "request.body.format": "json",
    "reporter.bootstrap.servers": "localhost:9092",
    "reporter.result.topic.name": "http-sink-success",
    "reporter.result.topic.replication.factor": "1",
    "reporter.error.topic.name":"http-sink-error",
    "reporter.error.topic.replication.factor":"1"
}
EOF

curl -X PUT -H "Content-Type: application/json" \
--data @http-sink-config.json \
http://localhost:8083/connectors/http-sink/config
```

What is happened to your sink connector? and what is in your `http-sink-error` topic?


### **7. Challenges**  

Please reference the HTTP Sink documentations to complete the following activities:

1. Custom URL Templating. Could you send the information via the Query parameters? E.g: `/api/v1/endpoint?userId=User1`
2. Can you add a basic authentication to the request? Could you validate the `Authorization` headers in the downstream service?
3. Can you test the retry mechanism on the connector with the help of the `requests-log-service`?
4. Can you use the REST API to manage connector's lifecycle?
    - create, delete, and update a connector.
    - https://docs.confluent.io/platform/current/connect/references/restapi.html

https://docs.confluent.io/kafka-connectors/http/current/overview.html

