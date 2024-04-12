import os
from pyspark import SparkConf
from pyspark import SparkContext
from pyspark.sql import SparkSession
from pyspark.sql.functions import split, col


if __name__ == "__main__":
    spark = SparkSession.builder.getOrCreate()

    spark.sparkContext.setLogLevel("ERROR")

    raw = spark.read.text("s3a://agartha-raw/people.txt")
    
    split_by_whitespace = split(col("value"), " ")

    # We split the singular 'value' column that holds the whole text line into the correct schema and drop the original placeholder
    structured = raw.withColumn("first_name", split_by_whitespace.getItem(0)) \
                    .withColumn("last_name", split_by_whitespace.getItem(1)) \
                    .withColumn("age", split_by_whitespace.getItem(2).cast('int')) \
                    .drop("value")

    # The next will be cleaning it from values that don't satisfy the requirements
    create_name_filter_condition = lambda column_name: col(column_name).rlike("^[a-zA-Z]*$")
    age_filter_condition = col("age").between(1, 150)

    cleaned = structured.filter(create_name_filter_condition("first_name") & create_name_filter_condition("last_name") & age_filter_condition)

    # Now that we have the data in a proper structure and cleaned up we want to persist it as a Parquet file and create the Iceberg metadata for the table
    cleaned.writeTo("agartha.people").create()

    spark.stop()