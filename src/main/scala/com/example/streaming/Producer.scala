package com.example.streaming

import com.google.cloud.pubsub.v1.Publisher
import com.google.cloud.storage.{Blob, StorageOptions}
import com.google.protobuf.ByteString
import com.google.pubsub.v1.{ProjectTopicName, PubsubMessage}
import io.github.cdimascio.dotenv.Dotenv
import java.util.UUID

object Producer {

  def main(args: Array[String]): Unit = {
    if (args.length < 1) {
      System.err.println("❌ Usage: Producer <topicId>")
      sys.exit(1)
    }

    // ✅ Charger les variables depuis .env
    val dotenv = Dotenv.load()
    val projectId  = dotenv.get("PROJECT_ID")
    val bucketName = dotenv.get("BUCKET_NAME")
    val fileName   = dotenv.get("FILE_NAME")

    val topicId = args(0)
    val topicName = ProjectTopicName.of(projectId, topicId)

    println(s"🌍 Projet actif : $projectId")
    println(s"🪣 Lecture depuis le bucket : $bucketName/$fileName")

    // ✅ Vérifier la connexion au bucket
    val storage = StorageOptions.getDefaultInstance.getService
    val bucket = storage.get(bucketName)
    if (bucket == null) {
      System.err.println(s"❌ Le bucket '$bucketName' est introuvable dans le projet '$projectId'")
      sys.exit(1)
    } else {
      println(s"✅ Bucket trouvé : ${bucket.getName} (projet : $projectId)")
    }

    val publisher = Publisher.newBuilder(topicName).build()

    try {
      // ✅ Lecture du fichier GCS
      val blob: Blob = storage.get(bucketName, fileName)
      if (blob == null) {
        System.err.println(s"❌ Impossible de trouver le fichier '$fileName' dans le bucket '$bucketName'")
        sys.exit(1)
      }

      val content = new String(blob.getContent(), "UTF-8")
      val lines = content.split("\n").toList

      // Ignorer le header si présent
      val data =
        if (lines.nonEmpty && lines.head.toLowerCase.contains("order")) lines.drop(1)
        else lines

      println(s"📦 Nombre de lignes à publier : ${data.size}")

      // ✅ Envoi dans Pub/Sub
      data.foreach { line =>
        try {
          val message = PubsubMessage.newBuilder()
            .setData(ByteString.copyFromUtf8(line))
            .putAttributes("id", UUID.randomUUID().toString)
            .build()

          publisher.publish(message)
          println(s"✅ Sent: $line")
          Thread.sleep(500) // simulation streaming
        } catch {
          case e: Exception =>
            System.err.println(s"⚠️ Erreur lors de l'envoi du message : ${e.getMessage}")
        }
      }

    } catch {
      case e: Exception =>
        System.err.println(s"❌ Erreur lors de la lecture du fichier ou de la publication : ${e.getMessage}")
        e.printStackTrace()
    } finally {
      publisher.shutdown()
      println("✅ Producer terminé.")
    }
  }
}
