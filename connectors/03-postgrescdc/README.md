# CDC with PostgreSQL using Debezium

---

## **Objectives**

1. Understand the fundamentals of CDC and why it matters.
2. Set up PostgreSQL for CDC using logical replication.
3. Configure and deploy a Debezium PostgreSQL Source Connector.
4. Stream real-time changes (inserts, updates, deletes) from PostgreSQL into Kafka.
5. Validate data changes in Kafka topics.
6. Handle schema changes.

---

## **Activities**

### **0. References**

- Debezium PostgreSQL Connector: [https://debezium.io/documentation/reference/stable/connectors/postgresql.html](https://debezium.io/documentation/reference/stable/connectors/postgresql.html)

---

### **1. Environment Setup**

**Step 1:** Start Docker environment (including PostgreSQL, Kafka, and Debezium)

```bash
sudo docker-compose up -d
```

**Step 2:** Validate running services

```bash
docker ps
```

> Ensure the following services are running:
>
> - PostgreSQL (with logical replication enabled)
> - Kafka & Kafka Connect (with Debezium connector plugin)
> - Control Center (for easy validation)

**Step 3:** Install Debezium Connector (if not pre-installed)

- Verify Postgres Connector is available in **Control Center** or via API:
```bash
curl http://localhost:8083/connector-plugins
```

- Jump into the docker container via the following command
```bash
sudo docker exec -it confluent-platform /bin/bash
```
- Install the CDC connector via 
```
confluent-hub install --no-prompt debezium/debezium-connector-postgresql:2.5.4 --component-dir /opt/connectors
```

- Verify it after the installation completed
```
ls /opt/connectors
```

- Go to the `http://localhost:9001` with username `admin` and password `admin`. You can restart the `connect` service.

- Verify the connector plugin in **Control Center** or via API:
```bash
curl http://localhost:8083/connector-plugins
```

---

### **2. PostgreSQL Configuration for CDC**

**Step 1:** Access PostgreSQL via DBeaver.
- Connect using `localhost:5432`, user `user`, password `passwd`, database `postgres`.
or
- Connect to PostgreSQL using default database `postgres`
```bash
docker exec -it postgres psql -U user -d postgres
```

**Step 2:** Set the `wal_level` with `logical`

PostgreSQL’s logical decoding feature was introduced in version 9.4. It is a mechanism that allows the extraction of the changes that were committed to the transaction log and the processing of these changes in a user-friendly manner with the help of an output plug-in.

You need to change the system config for the wal_level to `logical`
```sql
ALTER SYSTEM SET wal_level = 'logical';
```
Then, you can restart your postgres docker with
```
sudo docker restart postgres
```
Once the postgres restarted, you can validate your updates via 
```sql
SHOW wal_level;
```

**Step 3:** Create a new database and user for CDC
```sql
CREATE DATABASE cdctest;
```

**Step 4:** Connect to the `cdctest` database and create a table

```sql
CREATE TABLE customers (
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
BEFORE UPDATE ON customers
FOR EACH ROW
EXECUTE PROCEDURE update_updated_at_column();

INSERT INTO customers (name, email) VALUES
('Alice', 'alice@example.com'),
('Bob', 'bob@example.com');

SELECT * FROM customers;
```

---

### **3. Deploying Debezium PostgreSQL Source Connector**

**Step 1:** Create `cdc-postgres-source.json`

```json
{
  "name": "cdc-postgres-source",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "tasks.max": "1",
    "tasks.max.enforce": "true",
    "key.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "topic.prefix": "cdc",
    "database.hostname": "postgres",
    "database.port": "5432",
    "database.user": "user",
    "database.password": "passwd",
    "database.dbname": "cdctest",
    "plugin.name": "pgoutput",
    "slot.name": "cdctest_slot",
    "publication.autocreate.mode": "all_tables",
    "slot.drop.on.stop": "true",
    "event.processing.failure.handling.mode": "fail"
  }
}
```

**Step 2:** Deploy the connector

```bash
curl -X POST -H "Content-Type: application/json" \
--data @cdc-postgres-source.json \
http://localhost:8083/connectors
```

**Step 3:** Verify connector status

```bash
curl http://localhost:8083/connectors/cdc-postgres-source/status
```

---

### **4. Validate CDC Events**

**Step 1:** Insert new data and observe changes
```sql
INSERT INTO customers (name, email) VALUES ('Charlie', 'charlie@example.com');
```
- Check the Kafka topic `cdc.public.customers` to confirm the change.

**Step 2:** Update an existing record
```sql
UPDATE customers SET email = 'alice_new@example.com' WHERE id = 1;
```
- Validate the updated data in the Kafka topic.

**Step 3:** Delete a record
```sql
DELETE FROM customers WHERE id = 2;
```
- Confirm the delete event is captured in Kafka.

---

### **5. Handling Schema Changes**
- Add a new column to the table.
```sql
ALTER TABLE customers ADD COLUMN phone VARCHAR(20);
```
- Insert a record with the new schema.
```sql
INSERT INTO customers (name, email, phone) VALUES ('David', 'david@example.com', '123-456-7890');
```
- Validate that the schema change is reflected in the Kafka topic.

---

### **6. Offset and Replication Slot Management**
- Inspect the replication slots in PostgreSQL.
```sql
SELECT * FROM pg_replication_slots;
```
Check the `lsn` when you make changes to the database table.
https://www.postgresql.org/docs/current/datatype-pg-lsn.html

- Compare the `lsn` with your `config-offsets` topic's `lsn`.

- Delete the connector to observe re-ingestion behavior.
```bash
# Delete your connector
curl -X DELETE http://localhost:8083/connectors/cdc-postgres-source
```

- Set the offset in `config-offsets` to null for your CDC connector.

- Reprovision the CDC connector, then check the Kafka topics.

---

### **7. Additional Challenges**
1. **Multi-Table Capture:**
   - Extend the exercise by adding another table (like `orders`).
   - Are you able to exclude some tables?
2. **Data Filtering with SMT:**
   - Are you able to filter some data by SMT?
3. **Schema Changes:**
   - What would happen if you rename columns and remove columns?

---


