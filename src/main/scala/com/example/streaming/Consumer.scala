package com.example.streaming

import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.functions._
import org.apache.hadoop.fs.{FileSystem, Path}
import scala.util.Try

/**
 * Consumer Streaming : GCS (CSV) -> BigQuery avec Spark Structured Streaming.
 * - Lecture streaming des nouveaux fichiers CSV déposés dans un dossier GCS
 * - Détection automatique des nouveaux fichiers (micro-batch)
 * - Écriture append dans BigQuery avec checkpointing de streaming
 * - Protection anti-doublons intégrée
 */
object Consumer {

  def main(args: Array[String]): Unit = {

    val spark = SparkSession.builder()
      .appName("GcsCsvToBigQueryStreaming")
      .getOrCreate()

    def getConfig(key: String, argIndex: Int): String = {
      if (args.length > argIndex && args(argIndex).nonEmpty) {
        args(argIndex)
      } else {
        sys.env
          .get(key)
          .orElse(spark.conf.getOption(s"spark.executorEnv.$key"))
          .orElse(spark.conf.getOption(s"spark.yarn.appMasterEnv.$key"))
          .orElse(Option(System.getProperty(key)))
          .getOrElse("")
      }
    }

    val finalProjectId     = getConfig("PROJECT_ID", 0)
    val finalInputPath     = getConfig("INPUT_PATH", 1)             // gs://bucket/path/inputs/
    val finalBigQueryTable = getConfig("BIGQUERY_TABLE", 2)
    val finalCheckpointPath= getConfig("CHECKPOINT_PATH", 3)        // gs://bucket/checkpoints/consumer

    // Debug : afficher les valeurs lues
    println(s"DEBUG - PROJECT_ID: ${if (finalProjectId.nonEmpty) "OK" else "VIDE"}")
    println(s"DEBUG - INPUT_PATH: ${if (finalInputPath.nonEmpty) "OK" else "VIDE"}")
    println(s"DEBUG - BIGQUERY_TABLE: ${if (finalBigQueryTable.nonEmpty) "OK" else "VIDE"}")
    println(s"DEBUG - CHECKPOINT_PATH: ${if (finalCheckpointPath.nonEmpty) "OK" else "VIDE"}")

    require(finalProjectId.nonEmpty, "PROJECT_ID manquant")
    require(finalInputPath.nonEmpty, "INPUT_PATH manquant")
    require(finalBigQueryTable.nonEmpty, "BIGQUERY_TABLE manquant")
    require(finalCheckpointPath.nonEmpty, "CHECKPOINT_PATH manquant")

    println(s"[INFO] Démarrage du Consumer Streaming")
    println(s"[INFO] Input: $finalInputPath")
    println(s"[INFO] Output: $finalBigQueryTable")
    println(s"[INFO] Checkpoint: $finalCheckpointPath")

    val tempBucket = finalCheckpointPath.split("/")(2)
    val streamingCheckpointPath = s"$finalCheckpointPath/streaming"
    
    println("[INFO] Configuration du streaming...")
    
    // Vérifier et créer le dossier inbox s'il n'existe pas
    // Spark readStream nécessite que le chemin existe au démarrage
    println("[INFO] Vérification du dossier inbox...")
    val fs = FileSystem.get(spark.sparkContext.hadoopConfiguration)
    val inputPath = new Path(finalInputPath)
    
    try {
      if (!fs.exists(inputPath)) {
        println(s"[INFO] Le dossier n'existe pas encore: $finalInputPath")
        println("[INFO] Création du dossier...")
        fs.mkdirs(inputPath)
        println("[INFO] Dossier créé avec succès")
      } else {
        println("[INFO] Le dossier existe déjà")
      }
    } catch {
      case e: Exception =>
        println(s"[WARN] Erreur lors de la vérification/création du dossier: ${e.getMessage}")
        println("[INFO] Le streaming tentera de démarrer quand même...")
    }
  
    def sanitizeCol(name: String, idx: Int): String = {
      val lower = name.toLowerCase
      val replaced = lower.replaceAll("[^a-z0-9]+", "_")
      val collapsed = replaced.replaceAll("_+", "_").stripPrefix("_").stripSuffix("_")
      val base = if (collapsed.isEmpty) s"col_$idx" else collapsed
      if (base.headOption.exists(_.isDigit)) s"col_$base" else base
    }

    // Fonction pour transformer le DataFrame (sanitize + cast + enrichissements)
    def transformDF(inputDF: org.apache.spark.sql.DataFrame): org.apache.spark.sql.DataFrame = {
      // Sanitize column names
      val seen = scala.collection.mutable.Set[String]()
      val renamed = inputDF.columns.zipWithIndex.map { case (c, i) =>
        var candidate = sanitizeCol(c, i)
        var suffix = 1
        while (seen.contains(candidate)) {
          suffix += 1
          candidate = s"${sanitizeCol(c, i)}_$suffix"
        }
        seen.add(candidate)
        (c, candidate)
      }
      val sanitizedDF = renamed.foldLeft(inputDF) { case (df, (orig, clean)) =>
        if (orig == clean) df else df.withColumnRenamed(orig, clean)
      }

      // Recaler le schéma sur la table BQ (types attendus)
      def colOrNull(name: String) = if (sanitizedDF.columns.contains(name)) col(name) else lit(null)

      val baseDF = sanitizedDF.select(
        colOrNull("customer_id").cast("int").alias("customer_id"),
        colOrNull("age").cast("int").alias("age"),
        colOrNull("gender").alias("gender"),
        colOrNull("item_purchased").alias("item_purchased"),
        colOrNull("category").alias("category"),
        colOrNull("purchase_amount_usd").cast("double").alias("purchase_amount_usd"),
        colOrNull("location").alias("location"),
        colOrNull("size").alias("size"),
        colOrNull("color").alias("color"),
        colOrNull("season").alias("season"),
        colOrNull("review_rating").cast("double").alias("review_rating"),
        colOrNull("subscription_status").alias("subscription_status"),
        colOrNull("shipping_type").alias("shipping_type"),
        colOrNull("discount_applied").alias("discount_applied"),
        colOrNull("promo_code_used").alias("promo_code_used"),
        colOrNull("previous_purchases").cast("int").alias("previous_purchases"),
        colOrNull("payment_method").alias("payment_method"),
        colOrNull("frequency_of_purchases").alias("frequency_of_purchases"),
        colOrNull("processed_time").cast("timestamp").alias("processed_time")
      )

      // ========== TRAITEMENTS MÉTIER ==========
      
      // 1. Calcul du montant après remise (si discount_applied = "Yes")
      val withDiscountAmount = baseDF.withColumn(
        "final_amount_usd",
        when(col("discount_applied") === "Yes", col("purchase_amount_usd") * 0.9)
          .otherwise(col("purchase_amount_usd"))
      )

      // 2. Catégorisation du montant d'achat
      val withAmountCategory = withDiscountAmount.withColumn(
        "amount_category",
        when(col("final_amount_usd") < 50, "Small")
          .when(col("final_amount_usd") < 150, "Medium")
          .when(col("final_amount_usd") < 300, "Large")
          .otherwise("Premium")
      )

      // 3. Segmentation client basée sur les achats précédents
      val withCustomerSegment = withAmountCategory.withColumn(
        "customer_segment",
        when(col("previous_purchases") >= 10, "VIP")
          .when(col("previous_purchases") >= 5, "Regular")
          .when(col("previous_purchases") >= 2, "Occasional")
          .otherwise("New")
      )

      // 4. Score de satisfaction client (basé sur review_rating)
      val withSatisfactionScore = withCustomerSegment.withColumn(
        "satisfaction_level",
        when(col("review_rating") >= 4.5, "Very Satisfied")
          .when(col("review_rating") >= 4.0, "Satisfied")
          .when(col("review_rating") >= 3.0, "Neutral")
          .when(col("review_rating") >= 2.0, "Dissatisfied")
          .otherwise("Very Dissatisfied")
      )

      // 5. Détection d'anomalies (montants anormalement élevés)
      val withAnomalyFlag = withSatisfactionScore.withColumn(
        "is_anomaly",
        when(col("final_amount_usd") > 500, true)
          .otherwise(false)
      )

      // 6. Calcul de la valeur client estimée (CLV simplifié)
      val withCustomerValue = withAnomalyFlag.withColumn(
        "estimated_clv",
        col("previous_purchases") * col("final_amount_usd") * 0.3
      )

      // 7. Catégorisation de la fréquence d'achat
      val withFrequencyCategory = withCustomerValue.withColumn(
        "frequency_category",
        when(col("frequency_of_purchases") === "Weekly", "High Frequency")
          .when(col("frequency_of_purchases") === "Monthly", "Medium Frequency")
          .when(col("frequency_of_purchases") === "Annually", "Low Frequency")
          .otherwise("Unknown")
      )

      // 8. Calcul du profit estimé (montant - coût estimé à 60%)
      val withProfit = withFrequencyCategory.withColumn(
        "estimated_profit_usd",
        col("final_amount_usd") * 0.4
      )

      // 9. Catégorisation par saison (haute/basse saison)
      val withSeasonCategory = withProfit.withColumn(
        "season_type",
        when(col("season").isin("Spring", "Summer"), "High Season")
          .otherwise("Low Season")
      )

      // 10. Score de fidélité (basé sur subscription_status et previous_purchases)
      val withLoyaltyScore = withSeasonCategory.withColumn(
        "loyalty_score",
        when(col("subscription_status") === "Yes" && col("previous_purchases") >= 5, "High")
          .when(col("subscription_status") === "Yes" || col("previous_purchases") >= 3, "Medium")
          .otherwise("Low")
      )

      withLoyaltyScore
    }

    // Fonction pour créer un hash unique d'une ligne (optimisée)
    val hashColumns = Seq(
      "customer_id", "age", "gender", "item_purchased", "category",
      "purchase_amount_usd", "location", "size", "color", "season",
      "review_rating", "subscription_status", "shipping_type",
      "discount_applied", "promo_code_used", "previous_purchases",
      "payment_method", "frequency_of_purchases"
    )
    
    def createRowHash(df: org.apache.spark.sql.DataFrame) = {
      val hashExpr = md5(concat_ws("|", hashColumns.map { colName =>
        col(colName).cast("string")
      }: _*))
      df.withColumn("row_hash", hashExpr)
    }
    
    def createHashExpr = {
      md5(concat_ws("|", hashColumns.map { colName =>
        col(colName).cast("string")
      }: _*))
    }

    // Définir le schéma attendu (basé sur le schéma BigQuery)
    import org.apache.spark.sql.types._
    val csvSchema = StructType(Array(
      StructField("Customer ID", IntegerType, true),
      StructField("Age", IntegerType, true),
      StructField("Gender", StringType, true),
      StructField("Item Purchased", StringType, true),
      StructField("Category", StringType, true),
      StructField("Purchase Amount (USD)", DoubleType, true),
      StructField("Location", StringType, true),
      StructField("Size", StringType, true),
      StructField("Color", StringType, true),
      StructField("Season", StringType, true),
      StructField("Review Rating", DoubleType, true),
      StructField("Subscription Status", StringType, true),
      StructField("Shipping Type", StringType, true),
      StructField("Discount Applied", StringType, true),
      StructField("Promo Code Used", StringType, true),
      StructField("Previous Purchases", IntegerType, true),
      StructField("Payment Method", StringType, true),
      StructField("Frequency of Purchases", StringType, true)
    ))
    
    println("[INFO] Configuration du streaming depuis GCS...")
    
    val streamDF = spark.readStream
      .format("csv")
      .option("header", "true")
      .option("inferSchema", "false") // Utiliser le schéma explicite
      .schema(csvSchema) // Schéma fixe pour éviter les erreurs
      .option("maxFilesPerTrigger", 10) // Traiter max 10 fichiers par micro-batch
      .option("latestFirst", "false") // Traiter les fichiers dans l'ordre d'arrivée
      .option("recursiveFileLookup", "false") // Ne pas chercher récursivement
      .load(finalInputPath)

    // Transformer le stream
    val transformedDF = streamDF
      .withColumn("processed_time", current_timestamp())
      .transform(transformDF)

    println("[INFO] Configuration de l'écriture vers BigQuery...")
    
    val query = transformedDF.writeStream
      .foreachBatch { (batchDF: org.apache.spark.sql.DataFrame, batchId: Long) =>
        println(s"[BATCH #$batchId] Traitement du micro-batch...")
        
        val rowCount = try {
          batchDF.count()
        } catch {
          case e: Exception =>
            println(s"[WARN] Erreur lors du comptage: ${e.getMessage}")
            0L
        }
        
        if (rowCount > 0) {
          println(s"[BATCH #$batchId] $rowCount ligne(s) reçue(s)")

          val batchDFWithHash = createRowHash(batchDF)

          println(s"[BATCH #$batchId] Vérification des doublons dans BigQuery...")
          val existingDF = try {
            spark.read
              .format("com.google.cloud.spark.bigquery.BigQueryRelationProvider")
              .option("table", finalBigQueryTable)
              .load()
              .select(createHashExpr.alias("row_hash"))
          } catch {
            case e: Exception =>
              println(s"[WARN] Impossible de lire BigQuery: ${e.getMessage}")
              spark.emptyDataFrame.select(lit("").alias("row_hash"))
          }

          val newRowsDF = batchDFWithHash
            .join(existingDF, Seq("row_hash"), "left_anti")
            .drop("row_hash")

          val newRowCount = newRowsDF.count()
          val duplicateCount = rowCount - newRowCount

          if (duplicateCount > 0) {
            println(s"[BATCH #$batchId] $duplicateCount doublon(s) détecté(s) et ignoré(s)")
          }

          if (newRowCount > 0) {
            println(s"[BATCH #$batchId] Écriture de $newRowCount nouvelle(s) ligne(s) dans BigQuery...")
            
            newRowsDF.write
              .format("com.google.cloud.spark.bigquery.BigQueryRelationProvider")
              .option("table", finalBigQueryTable)
              .option("temporaryGcsBucket", tempBucket)
              .option("intermediateFormat", "parquet")
              .option("allowFieldAddition", "true") // Permettre l'ajout automatique de nouvelles colonnes
              .option("allowSchemaEvolution", "true") // Permettre l'évolution du schéma
              .mode("append")
              .save()

            println(s"[BATCH #$batchId] $newRowCount ligne(s) écrite(s) avec succès")
          } else {
            println(s"[BATCH #$batchId] Toutes les lignes existent déjà, aucune écriture")
          }
        } else {
          println(s"[BATCH #$batchId] Batch vide, aucun traitement")
        }
      }
      .option("checkpointLocation", streamingCheckpointPath)
      .trigger(org.apache.spark.sql.streaming.Trigger.ProcessingTime("15 seconds"))
      .start()

    println("[INFO] Streaming démarré. En attente de nouveaux fichiers...")
    println("[INFO] Appuyez sur Ctrl+C pour arrêter")

    // Attendre la fin du streaming
    query.awaitTermination()
  }
}
