from pyflink.table import StreamTableEnvironment
from pyflink.datastream import StreamExecutionEnvironment

env = StreamExecutionEnvironment.get_execution_environment()

table_env = StreamTableEnvironment.create(env)

# 'io-impl'='org.apache.iceberg.aws.s3.S3FileIO',

table_env.execute_sql(
        """CREATE CATALOG agartha WITH (
        'type'='iceberg',
        'catalog-impl'='org.apache.iceberg.nessie.NessieCatalog',
        'uri'='http://nessie.agartha-catalog.svc.cluster.local:19120/api/v1',
        'ref'='main',
        's3.access-key-id'='agartha',
        's3.secret-access-key'='superpass',
        's3.endpoint'='http://minio.agartha.minikubehost.com',
        'client.region'='us-east-1',
        'warehouse'='s3a://agartha-warehouse/')"""
    )

# table_env.execute_sql("CREATE DATABASE agartha.flink_test")

table_env.execute_sql(
        """CREATE TABLE agartha.flink_test.flink_table (
            id BIGINT COMMENT 'unique id',
            data STRING)"""
    )

table_env.execute_sql("INSERT INTO agartha.flink_test.flink_table VALUES (1, 'a')")
