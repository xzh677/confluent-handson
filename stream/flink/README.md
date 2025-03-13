# Flink SQL Hands-On Workshop

---

## Objectives
By the end of this workshop, participants will be able to:
1. Deploy Flink SQL applications using MinIO and CMF.
2. Perform stream-to-stream joins using Flink SQL.
3. Aggregate and count data using Flink SQL.
4. Validate data processing through Kafka topics.
5. Manage and delete Flink SQL jobs.

---

## Activities

### **0. Prerequisites**
- **Flink SQL** environment is set up.
- Access to MinIO and CMF environments.
- Kafka topics are configured and running.


---

### **1. Deploy Flink SQL Job**

> **Steps:**
1. **Prepare Flink SQL File**
    - Write your Flink SQL queries in a `.sql` file, separating each query with `-----`. The `-----` is because of the sql runner that we used.

2. **Upload SQL File to MinIO**
    - Navigate to [MinIO Console](http://minio.eks.shin.ps.confluent.io:9001/browser/flink/).
    - Use credentials:
        - Username: `minioadmin`
        - Password: `minioadmin`
    - Upload your `.sql` file (e.g., `<your-name>.sql`).

3. **Create the Flink Application**
```bash
CMF_URL=http://cmf.eks.shin.ps.confluent.io
FLINK_ENV=flinkenv
MINIO_SQL_NAME=<your-name>.sql
FLINK_APP=<your-name>

tee flinkapp.json > /dev/null <<EOF
{
  "apiVersion": "cmf.confluent.io/v1alpha1",
  "kind": "FlinkApplication",
  "metadata": {
    "name": "$FLINK_APP"
  },
  "spec": {
    "image": "shinzhang124/cp-flink:1.19.1-cp2",
    "flinkVersion": "v1_19",
    "serviceAccount": "flink",
    "podTemplate": {
        "spec": {
          "containers": [
            {
              "name": "flink-main-container",
              "volumeMounts": [
                {
                  "mountPath": "/opt/flink/downloads",
                  "name": "downloads"
                }
              ]
            }
          ],
          "volumes": [
            {
              "name": "downloads",
              "emptyDir": {}
            }
          ]
        }
      },
    "jobManager": {
      "podTemplate": {
        "spec": {
            "initContainers": [
    {
      "name": "mc",
      "image": "minio/mc",
      "volumeMounts": [
        {
          "mountPath": "/opt/flink/downloads",
          "name": "downloads"
        }
      ],
      "command": [
        "/bin/sh",
        "-c",
        "mc alias set dev-minio http://minio.confluent.svc.cluster.local:9000 minioadmin minioadmin && mc cp dev-minio/flink/flink-sql-executor-1.0.jar /opt/flink/downloads/flink-sql-executor-1.0.jar && mc cp dev-minio/flink/$MINIO_SQL_NAME /opt/flink/downloads/queries.sql"
      ]
    }
  ]
        }
      },
      "resource": {
        "memory": "1024m",
        "cpu": 1
      }
    },
    "taskManager": {
      "resource": {
        "memory": "1024m",
        "cpu": 1
      }
    },
    "job": {
      "jarURI": "local:///opt/flink/downloads/flink-sql-executor-1.0.jar",
      "args": ["/opt/flink/downloads/queries.sql"],
      "state": "running",
      "parallelism": 1,
      "upgradeMode": "stateless"
    }
  },
  "status": null
}
EOF

curl -X POST "$CMF_URL/cmf/api/v1/environments/$FLINK_ENV/applications" \
--header 'Content-Type: application/json' \
--data @flinkapp.json
```

4. **Verify the Data**
    - Access [Kafka Control Center](http://controlcenter.eks.shin.ps.confluent.io/) to verify the data in the respective topics.

5. **Delete the Flink Application**
```bash
curl -X DELETE "$CMF_URL/cmf/api/v1/environments/$FLINK_ENV/applications/$FLINK_APP"
```

---

### **2. Stream-to-Stream Join**
> **Goal:** Enrich pageviews with user information.

Read the SQL before you create the sql file. You need to change TOPIC `enriched_pageviews` to `<your-name>_enriched_pageviews`. And you have to create this topic in control center first.

```sql
CREATE TABLE users (
    registertime BIGINT,
    userid STRING,
    regionid STRING,
    gender STRING
) WITH (
    'connector' = 'kafka',
    'topic' = 'users',
    'properties.bootstrap.servers' = 'kafka.confluent.svc.cluster.local:9071',
    'format' = 'json',
    'scan.startup.mode' = 'earliest-offset'
);
-----
CREATE TABLE pageviews (
    viewtime BIGINT,
    userid STRING,
    pageid STRING
) WITH (
    'connector' = 'kafka',
    'topic' = 'pageviews',
    'properties.bootstrap.servers' = 'kafka.confluent.svc.cluster.local:9071',
    'format' = 'json',
    'scan.startup.mode' = 'earliest-offset'
);
-----
CREATE TABLE enriched_pageviews (
    userid STRING,
    registertime BIGINT,
    regionid STRING,
    gender STRING,
    viewtime BIGINT,
    pageid STRING
) WITH (
    'connector' = 'kafka',
    'topic' = 'enriched_pageviews',
    'properties.bootstrap.servers' = 'kafka.confluent.svc.cluster.local:9071',
    'format' = 'json'
);
-----
INSERT INTO enriched_pageviews
SELECT
    u.userid,
    u.registertime,
    u.regionid,
    u.gender,
    p.viewtime,
    p.pageid
FROM
    users AS u
JOIN
    pageviews AS p
ON
    u.userid = p.userid;
```

---

### **3. Aggregation and Counting**
> **Goal:** Count the number of pageviews per page.

Read the SQL before you create the sql file. You need to change TOPIC `pageviews_count` to `<your-name>_pageviews_count`. And you have to create this topic in control center first.

```sql
-----
CREATE TABLE pageviews (
    viewtime BIGINT,
    userid STRING,
    pageid STRING
) WITH (
    'connector' = 'kafka',
    'topic' = 'pageviews',
    'properties.bootstrap.servers' = 'kafka.confluent.svc.cluster.local:9071',
    'format' = 'json',
    'scan.startup.mode' = 'earliest-offset'
);
-----
CREATE TABLE pageviews_count (
  pageid STRING,
  viewcount BIGINT,
  PRIMARY KEY (pageid) NOT ENFORCED
) WITH (
  'connector' = 'upsert-kafka',
  'topic' = 'pageviews_count',
  'properties.bootstrap.servers' = 'kafka.confluent.svc.cluster.local:9071',
  'key.format' = 'json',
  'value.format' = 'json'
);
-----
INSERT INTO pageviews_count
SELECT
  pageid,
  COUNT(*) AS viewcount
FROM pageviews
GROUP BY pageid;
```
---

