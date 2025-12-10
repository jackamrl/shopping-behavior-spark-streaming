package com.example.streaming

import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.functions._
import org.apache.hadoop.fs.{FileSystem, Path}
import scala.util.Try

/**
 * Consumer Batch périodique : GCS (CSV) -> BigQuery.
 * - Lecture batch des nouveaux fichiers CSV déposés dans un dossier GCS
 * - Écriture append dans BigQuery avec checkpointing simple (fichier texte)
 * - Traitement périodique toutes les 10 secondes
 */
object Consumer {

  def main(args: Array[String]): Unit = {

    val spark = SparkSession.builder()
      .appName("GcsCsvToBigQueryBatch")
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

    println(s"Lecture GCS path = $finalInputPath -> BigQuery table = $finalBigQueryTable")

    val tempBucket = finalCheckpointPath.split("/")(2)
    
    val checkpointFile = s"$finalCheckpointPath/processed_files.txt"
    val fs = FileSystem.get(spark.sparkContext.hadoopConfiguration)

    def loadProcessedFiles(): Set[String] = {
      Try {
        val path = new Path(checkpointFile)
        if (fs.exists(path)) {
          val in = fs.open(path)
          val content = scala.io.Source.fromInputStream(in).mkString
          in.close()
          content.split("\n").filter(_.nonEmpty).toSet
        } else {
          Set.empty[String]
        }
      }.getOrElse(Set.empty[String])
    }

    def saveProcessedFiles(files: Set[String]): Unit = {
      Try {
        val path = new Path(checkpointFile)
        val out = fs.create(path, true) // overwrite
        out.write((files.mkString("\n") + "\n").getBytes)
        out.close()
      }
    }

    var processedFiles = loadProcessedFiles()
    println(s"Fichiers déjà traités au démarrage : ${processedFiles.size}")

    while (true) {
      try {
        val allFiles = try {
          println(s"DEBUG: Vérification du chemin: $finalInputPath")
          
          val csvFiles = try {
            val filesRDD = spark.sparkContext.wholeTextFiles(s"$finalInputPath/*.csv", 1)
            val files = filesRDD.map(_._1).collect().filter(_.endsWith(".csv")).toSet
            files
          } catch {
            case e: Exception =>
              println(s"DEBUG: Erreur lors de wholeTextFiles: ${e.getClass.getSimpleName}: ${e.getMessage}")
              e.printStackTrace()
              // Fallback : essayer avec Hadoop FileSystem
              try {
                val path = new Path(finalInputPath)
                if (fs.exists(path)) {
                  fs.listStatus(path)
                    .filter(_.isFile)
                    .filter(_.getPath.getName.endsWith(".csv"))
                    .map(_.getPath.toString)
                    .toSet
                } else {
                  println(s"DEBUG: Le chemin n'existe pas (fallback)")
                  Set.empty[String]
                }
              } catch {
                case e2: Exception =>
                  println(s"DEBUG: Erreur lors du fallback FileSystem: ${e2.getClass.getSimpleName}: ${e2.getMessage}")
                  e2.printStackTrace()
                  Set.empty[String]
              }
          }
          
          println(s"DEBUG: Fichiers CSV trouvés: ${csvFiles.size}")
          csvFiles.foreach(f => println(s"DEBUG:   - $f"))
          
          csvFiles
        } catch {
          case e: Exception =>
            println(s"DEBUG: Erreur lors du listing des fichiers: ${e.getClass.getSimpleName}")
            println(s"DEBUG: Message d'erreur: ${e.getMessage}")
            println(s"DEBUG: Stack trace:")
            e.printStackTrace()
            Set.empty[String]
        }

        println(s"DEBUG: Total fichiers CSV détectés: ${allFiles.size}")
        println(s"DEBUG: Fichiers déjà traités: ${processedFiles.size}")

        // Identifier les nouveaux fichiers
        val newFiles = allFiles -- processedFiles

        if (newFiles.nonEmpty) {
          println(s"${newFiles.size} nouveau(x) fichier(s) détecté(s) : ${newFiles.mkString(", ")}")

          // Lire et traiter les nouveaux fichiers
          val inputDF = spark.read
            .format("csv")
            .option("header", "true")
            .option("inferSchema", "true")
            .load(newFiles.toSeq: _*)
            .withColumn("processed_time", current_timestamp())

          // Sanitize column names to match BigQuery requirements (lower_snake_case, no trailing underscores, no leading digit)
          def sanitizeCol(name: String, idx: Int): String = {
            val lower = name.toLowerCase
            val replaced = lower.replaceAll("[^a-z0-9]+", "_")
            val collapsed = replaced.replaceAll("_+", "_").stripPrefix("_").stripSuffix("_")
            val base = if (collapsed.isEmpty) s"col_$idx" else collapsed
            if (base.headOption.exists(_.isDigit)) s"col_$base" else base
          }
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

          // Recaler le schéma sur la table BQ (types attendus) et tronquer aux colonnes utiles
          def colOrNull(name: String) = if (sanitizedDF.columns.contains(name)) col(name) else lit(null)

          val bqDF = sanitizedDF.select(
            colOrNull("customer_id").cast("int").alias("customer_id"),
            colOrNull("age").cast("int").alias("age"),
            colOrNull("gender").alias("gender"),
            colOrNull("item_purchased").alias("item_purchased"),
            colOrNull("category").alias("category"),
            colOrNull("purchase_amount_usd").cast("double").alias("purchase_amount_usd"), // BQ est en FLOAT
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

          val rowCount = bqDF.count()
          println(s"Lecture de $rowCount lignes depuis ${newFiles.size} fichier(s) (schéma aligné BQ)")

          // Écrire dans BigQuery
          // Utiliser la méthode indirecte (par défaut) avec Parquet pour éviter les conflits de convertisseurs v1/v2
          bqDF.write
            .format("com.google.cloud.spark.bigquery.BigQueryRelationProvider") // forcer v1 pour éviter le conflit v1/v2
            .option("table", finalBigQueryTable)
            .option("temporaryGcsBucket", tempBucket)
            .option("intermediateFormat", "parquet") // Format intermédiaire performant
            // writeMethod="direct" désactivé pour éviter le bug TimestampNTZ avec les convertisseurs v2
            .mode("append")
            .save()

          println(s"✓ $rowCount lignes écrites dans BigQuery")

          // Mettre à jour la liste des fichiers traités
          processedFiles = processedFiles ++ newFiles
          saveProcessedFiles(processedFiles)
          println(s"Checkpoint mis à jour : ${processedFiles.size} fichier(s) traités au total")
        } else {
          println("Aucun nouveau fichier détecté")
        }

      } catch {
        case e: Exception =>
          println(s"ERREUR lors du traitement : ${e.getMessage}")
          e.printStackTrace()
      }

      // Attendre 15 secondes avant la prochaine itération
      Thread.sleep(15000)
    }
  }
}
