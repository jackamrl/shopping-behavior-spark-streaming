package com.example.streaming

import org.apache.spark.sql.{SparkSession, DataFrame}
import org.apache.spark.sql.functions._
import io.github.cdimascio.dotenv.Dotenv
import java.util.UUID

object Consumer {

  def main(args: Array[String]): Unit = {

    val projectId = sys.env.getOrElse("PROJECT_ID", "default-project")
    val subscription = sys.env.getOrElse("PUBSUB_SUBSCRIPTION", "default-subscription")
    val bqTable = sys.env.getOrElse("BIGQUERY_TABLE", "default.table")
    val checkpointPath = sys.env.getOrElse("CHECKPOINT_PATH", "gs://default-bucket/checkpoints")


    println(s"🚀 Consumer démarré pour le projet: $projectId")
    println(s"📬 Lecture depuis la subscription: $subscription")
    println(s"📊 Écriture vers la table: $bqTable")

    // ✅ Création de la session Spark
    val spark = SparkSession.builder
      .appName("ShoppingBehaviorConsumer")
      .getOrCreate()

    import spark.implicits._

    // ✅ Lecture continue depuis Pub/Sub
    val rawStream = spark.readStream
      .format("pubsub")
      .option("projectId", projectId)
      .option("subscription", subscription)
      .load()

    // ✅ Transformation : décodage du message
    val parsedStream = rawStream
      .selectExpr("CAST(data AS STRING)", "messageId", "publishTime")
      .as[(String, String, String)]
      .map { case (line, msgId, pubTime) =>
        val parts = line.split(",").map(_.trim)
        (
          parts(0), // customer_id
          parts(1).toInt,
          parts(2),
          parts(3),
          parts(4),
          parts(5).toDouble,
          parts(6),
          parts(7),
          parts(8),
          parts(9),
          parts(10).toDouble,
          parts(11),
          parts(12),
          parts(13),
          parts(14),
          parts(15).toInt,
          parts(16),
          parts(17),
          msgId,
          pubTime,
          UUID.randomUUID().toString,
          java.time.Instant.now().toString
        )
      }.toDF(
        "customer_id", "age", "gender", "item_purchased", "category",
        "purchase_amount_usd", "location", "size", "color", "season",
        "review_rating", "subscription_status", "shipping_type",
        "discount_applied", "promo_code_used", "previous_purchases",
        "payment_method", "frequency_of_purchases",
        "messageId", "publishTime", "record_id", "processed_time"
      )

    // ✅ Écriture dans BigQuery avec checkpoint
    val query = parsedStream.writeStream
      .format("bigquery")
      .option("table", bqTable)
      .option("checkpointLocation", checkpointPath)
      .outputMode("append")
      .start()

    query.awaitTermination()
  }
}
