object Main {
  def main(args: Array[String]): Unit = {
    println("Hello world!")
  }
}

import org.apache.spark.sql.SparkSession import org.apache.spark.sql.functions._ import org.apache.spark.sql.types._

val spark = SparkSession.builder
  .appName("PaymentAggregator")
  .getOrCreate()

import spark.implicits._

// Schéma JSON
val paymentSchema = new StructType()
  .add("user_id", "string")
  .add("timestamp", "string")
  .add("amount", "double")
  // ➤ A COMPLETER

  // Lecture depuis Kafka val rawStream = spark.readStream
  .format("kafka")
  .option("kafka.bootstrap.servers", "localhost:9092")
  .option("subscribe", "payments")
  .option("startingOffsets", "latest")
  .load()
val parsedStream = rawStream.selectExpr("CAST(value AS STRING)")   .select(from_json($"value", paymentSchema).as("data"))
  .selectExpr("data.user_id", "data.timestamp", "data.amount")

val paymentsWithEventTime = parsedStream
  .withColumn("event_time", to_timestamp($"timestamp"))
// ➤ Indication : ajoutez un fenêtrage par tranches de 60 secondes avec 2 min de tolérance
val windowedAggregates = paymentsWithEventTime
  .withWatermark("event_time", "2 minutes")
  .groupBy(
    window($"event_time", "60 seconds", "2 minutes"),
    $"user_id"

  )
// ➤ A COMPLETER



// Écriture console
val query = windowedAggregates.writeStream
  .outputMode("update")
  .format("console")
  .option("truncate", false)
  .trigger(processingTime = "20 seconds")
  .start()
query.awaitTermination()
