# ksqlDB Hands-On Workshop

---

## Objectives
By the end of this workshop, participants will be able to:
1. Set up Kafka topics using Datagen connectors.
2. Create streams and tables from existing Kafka topics using ksqlDB.
3. Perform tumbling window aggregations and filter results.
4. Identify and filter high-activity users based on windowed aggregations.
5. Perform stream-to-table joins for enriched data processing.
6. Validate and manage data transformations using interactive queries.

---

## Activities

### **0. Prerequisites**
- **ksqlDB** is up and running.
    - You can validate it in the Control Center or via Supervisor at http://localhost:9001.

- ***Step 1: Create users data gen connector***
```bash
tee users-gen-config.json > /dev/null <<EOF
{
    "connector.class": "io.confluent.kafka.connect.datagen.DatagenConnector",
    "kafka.topic": "users",
    "quickstart": "users",
    "max.interval": 10000,
    "tasks.max": "1"
}
EOF

curl -X PUT -H "Content-Type: application/json" \
--data @users-gen-config.json \
http://localhost:8083/connectors/users-gen/config
```

- ***Step 2: Create pageviews data gen connector***
```bash
tee pageviews-gen-config.json > /dev/null <<EOF
{
    "connector.class": "io.confluent.kafka.connect.datagen.DatagenConnector",
    "kafka.topic": "pageviews",
    "quickstart": "pageviews",
    "max.interval": 2000,
    "tasks.max": "1"
}
EOF

curl -X PUT -H "Content-Type: application/json" \
--data @pageviews-gen-config.json \
http://localhost:8083/connectors/pageviews-gen/config
```

---

### **1. Examine the Data**

- Go to the `Control Center` - `ksqlDB` console in your browser.
- Run the following SQL to list existing topics:
```sql
show topics;
```
- Print the contents of the topics:
```sql
print 'users' from beginning;
print 'pageviews' from beginning;
```

---

### **2. Create Stream from Existing Topic**
> **Goal:** Define ksqlDB streams for existing Kafka topics.

```sql
-- Create stream for pageviews
CREATE STREAM pageviews_stream (
    viewtime BIGINT,
    userid VARCHAR,
    pageid VARCHAR
) WITH (
    KAFKA_TOPIC='pageviews',
    KEY_FORMAT='AVRO',
    VALUE_FORMAT='AVRO'
);

-- Create table for users
CREATE TABLE users_table (
    registertime BIGINT,
    userid VARCHAR PRIMARY KEY,
    regionid VARCHAR,
    gender VARCHAR
) WITH (
    KAFKA_TOPIC = 'users',
    KEY_FORMAT = 'AVRO',
    VALUE_FORMAT = 'AVRO'
);

-- Create stream for users
CREATE STREAM users_stream (
    registertime BIGINT,
    userid VARCHAR,
    regionid VARCHAR,
    gender VARCHAR
) WITH (
    KAFKA_TOPIC='users',
    KEY_FORMAT='AVRO',
    VALUE_FORMAT='AVRO'
);
```

> **Validation**
```sql
SELECT * FROM pageviews_stream EMIT CHANGES LIMIT 5;
SELECT * FROM users_table EMIT CHANGES;
```
- Reflect on how many records you see in `users_table`.
- Discuss the differences between `users_table` and `users_stream`.

---

### **3. Tumbling Window Aggregation - Count Records**
> **Goal:** Count pageviews per user within 1-minute tumbling windows.

```sql
CREATE TABLE pageviews_tumbling_count WITH ( 
    KAFKA_TOPIC = 'pageviews_tumbling_count',
    KEY_FORMAT = 'AVRO',
    VALUE_FORMAT = 'AVRO', 
    PARTITIONS = 3
) AS
SELECT
    userid,
    COUNT(*) AS view_count,
    WINDOWSTART AS window_start,
    WINDOWEND AS window_end
FROM pageviews_stream
WINDOW TUMBLING (SIZE 1 MINUTE)
GROUP BY userid
EMIT CHANGES;

-- You can drop this table with:
-- DROP TABLE pageviews_tumbling_count DELETE TOPIC;
```

> ✅ **Validation**
```sql
SELECT * FROM pageviews_tumbling_count EMIT CHANGES;
```

---

### **4. Find High Activity Users**
> **Goal:** Identify users with more than 5 pageviews in a window.

```sql
CREATE STREAM pageviews_tumbling_stream (
    userid VARCHAR KEY,
    view_count BIGINT,
    window_start BIGINT,
    window_end BIGINT
) WITH (
    KAFKA_TOPIC = 'pageviews_tumbling_count',
    PARTITIONS = 3,
    KEY_FORMAT = 'AVRO',
    VALUE_FORMAT = 'AVRO'
);
```

> **Validate the Captured Windows**
```sql
SELECT * FROM pageviews_tumbling_stream EMIT CHANGES;
```

```sql
CREATE STREAM high_activity_users WITH ( 
    KAFKA_TOPIC = 'high_activity_users', 
    KEY_FORMAT = 'AVRO',
    VALUE_FORMAT = 'AVRO', 
    PARTITIONS = 3
) AS
SELECT
    userid,
    view_count,
    window_start,
    window_end
FROM pageviews_tumbling_stream
WHERE view_count > 5
EMIT CHANGES;
```

> ✅ **Validation**
```sql
SELECT * FROM high_activity_users EMIT CHANGES;
```

- Discuss the differences between `high_activity_users` and `pageviews_tumbling_stream`.
- Validate the data using Kafka topics directly.

---

### **5. Stream-to-Table Join**
> **Goal:** Enrich pageviews with cumulative total views per user.

```sql
CREATE STREAM enriched_pageviews_stream WITH (
    KAFKA_TOPIC = 'enriched_pageviews',
    KEY_FORMAT = 'AVRO',
    VALUE_FORMAT = 'AVRO',
    PARTITIONS = 3
) AS
SELECT 
    p.userid,
    p.pageid,
    p.viewtime,
    u.registertime,
    u.regionid,
    u.gender
FROM pageviews_stream p
LEFT JOIN users_table u
ON p.userid = u.userid
EMIT CHANGES;
```

> ✅ **Validation**
```sql
SELECT * FROM enriched_pageviews_stream EMIT CHANGES;
```

Learn more about stream-to-table joins: [ksqlDB Join Documentation](https://docs.confluent.io/platform/current/ksqldb/developer-guide/joins/join-streams-and-tables.html#semantics-of-stream-table-joins)

