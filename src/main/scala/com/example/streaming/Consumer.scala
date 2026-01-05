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

    println(s"🚀 Démarrage du Consumer Streaming")
    println(s"   Input: $finalInputPath")
    println(s"   Output: $finalBigQueryTable")
    println(s"   Checkpoint: $finalCheckpointPath")

    val tempBucket = finalCheckpointPath.split("/")(2)
    val streamingCheckpointPath = s"$finalCheckpointPath/streaming"
    
    // Le Consumer attend simplement que le Producer crée le dossier et les fichiers
    // Spark Structured Streaming gère automatiquement l'attente des nouveaux fichiers
    println("🔍 Configuration du streaming...")
    println(s"   ℹ️  Le Consumer attendra que le Producer crée le dossier inbox et les fichiers")
    println(s"   ℹ️  Aucune action nécessaire, le streaming démarrera automatiquement")

    // Fonction pour sanitizer les noms de colonnes
    def sanitizeCol(name: String, idx: Int): String = {
      val lower = name.toLowerCase
      val replaced = lower.replaceAll("[^a-z0-9]+", "_")
      val collapsed = replaced.replaceAll("_+", "_").stripPrefix("_").stripSuffix("_")
      val base = if (collapsed.isEmpty) s"col_$idx" else collapsed
      if (base.headOption.exists(_.isDigit)) s"col_$base" else base
    }

    // Fonction pour transformer le DataFrame (sanitize + cast)
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

      sanitizedDF.select(
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
    }

    // Fonction pour créer un hash unique d'une ligne
    def createRowHash(df: org.apache.spark.sql.DataFrame) = {
      df.withColumn(
        "row_hash",
        md5(concat_ws("|",
          col("customer_id").cast("string"),
          col("age").cast("string"),
          col("gender"),
          col("item_purchased"),
          col("category"),
          col("purchase_amount_usd").cast("string"),
          col("location"),
          col("size"),
          col("color"),
          col("season"),
          col("review_rating").cast("string"),
          col("subscription_status"),
          col("shipping_type"),
          col("discount_applied"),
          col("promo_code_used"),
          col("previous_purchases").cast("string"),
          col("payment_method"),
          col("frequency_of_purchases")
        ))
      )
    }

    // Lire le stream depuis GCS
    println("📡 Configuration du streaming depuis GCS...")
    
    // Définir le schéma attendu (basé sur le schéma BigQuery)
    // Cela évite d'avoir besoin d'un fichier existant pour inférer le schéma
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
    
    // Configuration du streaming avec gestion des dossiers vides
    println("📡 Configuration du streaming depuis GCS...")
    println("   ℹ️  Le streaming attendra automatiquement les nouveaux fichiers même si le dossier est vide")
    
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

    // Écrire dans BigQuery avec foreachBatch pour gérer les doublons
    println("✍️  Configuration de l'écriture vers BigQuery...")
    
    val query = transformedDF.writeStream
      .foreachBatch { (batchDF: org.apache.spark.sql.DataFrame, batchId: Long) =>
        println(s"\n🔄 Micro-batch #$batchId")
        
        val rowCount = try {
          batchDF.count()
        } catch {
          case e: Exception =>
            println(s"   ⚠️  Erreur lors du comptage (dossier peut-être vide) : ${e.getMessage}")
            0L
        }
        
        if (rowCount > 0) {
          println(s"   📊 $rowCount ligne(s) reçue(s) dans ce batch")

          // Créer le hash pour chaque ligne du batch
          val batchDFWithHash = createRowHash(batchDF)

          // Lire les données existantes de BigQuery pour vérifier les doublons
          println("   🔍 Vérification des doublons dans BigQuery...")
          val existingDF = try {
            spark.read
              .format("com.google.cloud.spark.bigquery.BigQueryRelationProvider")
              .option("table", finalBigQueryTable)
              .load()
              .select(
                md5(concat_ws("|",
                  col("customer_id").cast("string"),
                  col("age").cast("string"),
                  col("gender"),
                  col("item_purchased"),
                  col("category"),
                  col("purchase_amount_usd").cast("string"),
                  col("location"),
                  col("size"),
                  col("color"),
                  col("season"),
                  col("review_rating").cast("string"),
                  col("subscription_status"),
                  col("shipping_type"),
                  col("discount_applied"),
                  col("promo_code_used"),
                  col("previous_purchases").cast("string"),
                  col("payment_method"),
                  col("frequency_of_purchases")
                )).alias("row_hash")
              )
          } catch {
            case e: Exception =>
              println(s"   ⚠️  Impossible de lire BigQuery (peut-être vide) : ${e.getMessage}")
              spark.emptyDataFrame.select(lit("").alias("row_hash"))
          }

          // Filtrer les doublons
          val newRowsDF = batchDFWithHash
            .join(existingDF, Seq("row_hash"), "left_anti")
            .drop("row_hash")

          val newRowCount = newRowsDF.count()
          val duplicateCount = rowCount - newRowCount

          if (duplicateCount > 0) {
            println(s"   ⚠️  $duplicateCount doublon(s) détecté(s) et ignoré(s)")
          }

          if (newRowCount > 0) {
            println(s"   📝 Écriture de $newRowCount nouvelle(s) ligne(s) dans BigQuery...")
            
            newRowsDF.write
              .format("com.google.cloud.spark.bigquery.BigQueryRelationProvider")
              .option("table", finalBigQueryTable)
              .option("temporaryGcsBucket", tempBucket)
              .option("intermediateFormat", "parquet")
              .mode("append")
              .save()

            println(s"   ✅ $newRowCount ligne(s) écrite(s) avec succès")
          } else {
            println("   ℹ️  Toutes les lignes existent déjà, aucune écriture")
          }
        } else {
          println("   ℹ️  Batch vide, aucun traitement")
        }
      }
      .option("checkpointLocation", streamingCheckpointPath)
      .trigger(org.apache.spark.sql.streaming.Trigger.ProcessingTime("15 seconds")) // Traiter toutes les 15 secondes
      .start()

    println("✅ Streaming démarré ! En attente de nouveaux fichiers...")
    println("   (Appuyez sur Ctrl+C pour arrêter)")

    // Attendre la fin du streaming
    query.awaitTermination()
  }
}
