# JDBC Sink and Source Connector

---

## Objectives
By the end of this workshop, participants will be able to:
1. Understand the **JDBC Source and Sink connectors**.
2. Set up a PostgreSQL database and insert sample data.
3. Configure and deploy a JDBC Source Connector in different modes (timestamp, incrementing).
4. Apply Single Message Transforms (SMTs) to modify data and topic names.
5. Configure a JDBC Sink Connector for upserting data back into PostgreSQL.
6. Validate data flows, troubleshoot issues, and understand offset management.

---

## Activities

### **0. References**
- JDBC Source Connector: https://docs.confluent.io/kafka-connect-jdbc/current/source-connector/index.html
- JDBC Sink Connector: https://docs.confluent.io/kafka-connect-jdbc/current/sink-connector/index.html
- InsertField SMT: https://docs.confluent.io/kafka-connectors/transforms/current/insertfield.html

---

### **1. Environment Setup**

**Step 1:** Start Docker environment:
```bash
sudo docker-compose up -d
```

**Step 2:** Validate running services:
```bash
sudo docker ps
```

> **Key Services:**
> - **Confluent Platform** (Kafka, Connect, Schema Registry)
> - **PostgreSQL Database** (on port `5432`)

**Step 3:** Access PostgreSQL via DBeaver.
- Connect using `localhost:5432`, user `user`, password `passwd`, database `postgres`.
- Create a database named `jdbctest`.
```sql
create database jdbctest;
```
- Then disconnect from the session.
- Reconnect using `localhost:5432`, user `user`, password `passwd`, database `jdbctest`.


**Step 4:** Create initial table and insert data in `jdbctest` database:
```sql
-- Drop table
-- DROP TABLE userprofiles;

-- Create the userprofiles table with created_at and updated_at fields
CREATE TABLE userprofiles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50),
    email VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP not NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP not NULL
);

-- Create the trigger function to auto-update the updated_at field
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = NOW();
   RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

-- Create the trigger to invoke the function on updates
CREATE TRIGGER update_users_updated_at
BEFORE UPDATE ON userprofiles
FOR EACH ROW
EXECUTE PROCEDURE update_updated_at_column();

-- Insert initial data
INSERT INTO userprofiles (name, email) 
VALUES 
('Alice', 'alice@example.com'), 
('Bob', 'bob@example.com');

-- Select data to verify insertion
SELECT * FROM userprofiles;

```

This trigger allows the `updated_at` uses the latest timestamp when there is a change being made. 

```sql
UPDATE userprofiles SET name = 'Alice1' WHERE id =1;

-- Validate the changes
SELECT * FROM userprofiles;
```
Now, you should see different timestamps for `Alice` on `created_at` and `updated_at`.

---

### **2. Configuring the JDBC Source Connector (Incrementing + Timestamp Mode)**

**Step 1:** Create `jdbc-source.json`:
```json
{
  "name": "jdbc-source",
  "config": {
    "connector.class": "io.confluent.connect.jdbc.JdbcSourceConnector",
    "connection.url": "jdbc:postgresql://postgres:5432/jdbctest",
    "connection.user": "user",
    "connection.password": "passwd",
    "table.whitelist": "userprofiles",
    "topic.prefix": "",
    "mode": "incrementing",
    "incrementing.column.name": "id",
    "transforms": "addSuffix",
    "transforms.addSuffix.type": "org.apache.kafka.connect.transforms.RegexRouter",
    "transforms.addSuffix.regex": "(.*)",
    "transforms.addSuffix.replacement": "$1-raw"
  }
}
```
Please read the documentation to understand what the configurations are
https://docs.confluent.io/kafka-connect-jdbc/current/source-connector/index.html
https://docs.confluent.io/kafka-connectors/transforms/current/regexrouter.html


**Step 2:** Deploy the connector:
```bash
curl -X POST -H "Content-Type: application/json" \
--data @jdbc-source.json \
http://localhost:8083/connectors
```

**Step 3:** Check connector status:
```bash
curl http://localhost:8083/connectors/jdbc-source/status
```

**Step 4:** Validate data in Kafka via Control Center (`userprofiles-raw` topic).

**Step 5:** Insert additional data and observe changes:
```sql
INSERT INTO userprofiles (name, email) VALUES ('Charlie', 'charlie@example.com');
```
- Confirm that the new record appears in Kafka.
- Check the `connect-offsets` topic to see how offsets are managed.

**Step 6:** What if you modify one of the record?
```
update userprofiles u set name = 'Alice' where id =1;
```

**Step 7:** What if you delete one of the existing record?
```
delete from userprofiles where id = 1;
```
---

### **3. Deleting the Connector**
```bash
curl -X DELETE http://localhost:8083/connectors/jdbc-source
```

---

### **4. Creating a New Source Connector with Additional SMT**

**Step 1:** Create `jdbc-source-smt.json`:
```json
{
  "name": "jdbc-source-smt",
  "config": {
    "connector.class": "io.confluent.connect.jdbc.JdbcSourceConnector",
    "connection.url": "jdbc:postgresql://postgres:5432/jdbctest",
    "connection.user": "user",
    "connection.password": "passwd",
    "table.whitelist": "userprofiles",
    "topic.prefix": "",
    "mode": "timestamp+incrementing",
    "timestamp.column.name": "updated_at",
    "incrementing.column.name": "id",
    "transforms": "addSuffix,addField",
    "transforms.addSuffix.type": "org.apache.kafka.connect.transforms.RegexRouter",
    "transforms.addSuffix.regex": "(.*)",
    "transforms.addSuffix.replacement": "$1-smt",
    "transforms.addField.type": "org.apache.kafka.connect.transforms.InsertField$Value",
    "transforms.addField.static.field": "source",
    "transforms.addField.static.value": "jdbc"
  }
}
```

**Step 2:** Deploy the connector:
```bash
curl -X POST -H "Content-Type: application/json" \
--data @jdbc-source-smt.json \
http://localhost:8083/connectors
```

**Step 3:** Validate data in the `userprofiles-smt` topic and check the inserted `source` field.

---

### **5. Creating the JDBC Sink Connector**

**Step 1:** Create `jdbc-sink.json`:
```json
{
  "name": "jdbc-sink",
  "config": {
    "connector.class": "io.confluent.connect.jdbc.JdbcSinkConnector",
    "connection.url": "jdbc:postgresql://postgres:5432/jdbctest",
    "connection.user": "user",
    "connection.password": "passwd",
    "topics": "userprofiles-smt",
    "insert.mode": "upsert",
    "pk.mode": "record_value",
    "pk.fields": "id",
    "auto.create": "true",
    "auto.evolve": "true",
    "table.name.format": "users_sink"
  }
}
```

**Step 3:** Deploy the sink connector:
```bash
curl -X POST -H "Content-Type: application/json" \
--data @jdbc-sink.json \
http://localhost:8083/connectors
```

**Step 4:** Validate the data in the `users_sink` table from database.
```sql
select * from users_sink;
```

---

### **6. Additional Challenges**

1. **Schema Evolution:**
    - Add a new column to the `userprofiles` table (e.g., `age`), insert data, and observe how the connector handles it.
    - `ALTER TABLE userprofiles ADD email varchar(255);`
2. **Connector Failure:**
    - What if you restart the `postgres` container?
    - `sudo docker restart postgres`
3. **Custom SMT Challenge:**
    - Implement an SMT to dynamically rename topics with a timestamp suffix.
    - https://docs.confluent.io/kafka-connectors/transforms/current/overview.html
4. **Test timestamp only mode and incremental only mode**
    - Compare the differences between the different modes.

