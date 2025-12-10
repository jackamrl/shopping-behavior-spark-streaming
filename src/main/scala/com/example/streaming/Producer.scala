package com.example.streaming

import com.google.cloud.storage.{BlobId, BlobInfo, StorageOptions}
import io.github.cdimascio.dotenv.Dotenv
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Producer Batch : Lit un CSV source depuis GCS et le divise en petits fichiers
 * qu'il dépose progressivement dans le dossier inbox pour simuler un flux.
 * Style fonctionnel avec .map et transformations immutables.
 */
object Producer {

  def main(args: Array[String]): Unit = {
    val dotenv = Dotenv.load()
    val sourceBucket   = dotenv.get("BUCKET_NAME")
    val sourceFileName = dotenv.get("FILE_NAME")
    val inboxPath      = dotenv.get("INPUT_PATH", "gs://shopping_behavior_v2/inbox/")

    println(" ===================== CONFIGURATION =====================")
    println(s" Source GCS      : gs://$sourceBucket/$sourceFileName")
    println(s" Inbox GCS       : $inboxPath")
    println("============================================================")

    val storage = StorageOptions.getDefaultInstance.getService

    // Lecture du fichier source depuis GCS
    val sourceBlob = storage.get(sourceBucket, sourceFileName)
    if (sourceBlob == null) {
      System.err.println(s"Fichier introuvable : gs://$sourceBucket/$sourceFileName")
      sys.exit(1)
    }

    val content = new String(sourceBlob.getContent())
    val lines = content.split("\n").toList
    val header = lines.headOption.getOrElse("")
    val data   = lines.drop(1)

    println(s"Nombre total de lignes : ${data.size}")
    println(s"En-tête : $header")

    // Configuration
    val linesPerFile = 25
    val delaySeconds = 5

    // Extraire bucket et prefix de l'inbox
    val inboxParts  = inboxPath.replace("gs://", "").split("/", 2)
    val inboxBucket = inboxParts(0)
    val inboxPrefix = if (inboxParts.length > 1) inboxParts(1).stripSuffix("/") else ""

    // Diviser en batches de manière fonctionnelle
    val batches = data
      .zipWithIndex
      .map { case (line, idx) => (idx / linesPerFile, line) }
      .groupBy(_._1)
      .toList
      .sortBy(_._1)
      .map { case (batchIdx, linesWithIdx) => (batchIdx.toInt, linesWithIdx.map(_._2)) }

    println(s"Création de ${batches.size} fichier(s) de ~$linesPerFile lignes chacun")

    val timestampFormatter = DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss")

    // Traiter chaque batch de manière fonctionnelle
    val results = batches.zipWithIndex.map { case ((batchIdx, batchLines), index) =>
      val timestamp = LocalDateTime.now().format(timestampFormatter)
      val fileName  = s"orders_batch_${batchIdx + 1}_$timestamp.csv"
      val fullPath  = if (inboxPrefix.isEmpty) fileName else s"$inboxPrefix/$fileName"

      val fileContent = (header :: batchLines).mkString("\n")
      val blobId      = BlobId.of(inboxBucket, fullPath)
      val blobInfo    = BlobInfo.newBuilder(blobId).setContentType("text/csv").build()

      val result = try {
        storage.create(blobInfo, fileContent.getBytes("UTF-8"))
        println(s"✓ Fichier $fileName créé avec ${batchLines.size} lignes (${index + 1}/${batches.size})")
        Right(1)
      } catch {
        case e: Exception =>
          System.err.println(s"✗ Erreur batch ${batchIdx + 1}: ${e.getMessage}")
          e.printStackTrace()
          Left(1)
      }

      // Délai entre fichiers (sauf pour le dernier)
      if (index < batches.size - 1) Thread.sleep(delaySeconds * 1000)

      result
    }

    // Compter succès et erreurs de manière fonctionnelle
    val (successCount, errorCount) = results.foldLeft((0, 0)) {
      case ((ok, ko), Right(_)) => (ok + 1, ko)
      case ((ok, ko), Left(_))  => (ok, ko + 1)
    }

    println("\n ===================== RÉSUMÉ =====================")
    println(s" Fichiers créés avec succès : $successCount")
    println(s" Erreurs                    : $errorCount")
    println(s" Total de lignes traitées   : ${data.size}")
    println("==================================================")
    println("Producer terminé. Les fichiers sont dans l'inbox et seront traités par le Consumer.")
  }
}
