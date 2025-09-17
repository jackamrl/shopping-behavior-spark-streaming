package com.example.streaming

import com.google.cloud.ServiceOptions
import com.google.cloud.pubsub.v1.Publisher
import com.google.cloud.storage.{Blob, StorageOptions}
import com.google.protobuf.ByteString
import com.google.pubsub.v1.{ProjectTopicName, PubsubMessage}
import io.github.cdimascio.dotenv.Dotenv

import java.util.UUID

object Producer {
  def main(args: Array[String]): Unit = {
    if (args.length < 1) {
      System.err.println("Usage: Producer <topicId>")
      sys.exit(1)
    }

    // ✅ Charger les variables depuis .env
    val dotenv     = Dotenv.load()
    val bucketName = dotenv.get("BUCKET_NAME")
    val fileName   = dotenv.get("FILE_NAME")

    val projectId = ServiceOptions.getDefaultProjectId()
    val topicId   = args(0)

    val topicName = ProjectTopicName.of(projectId, topicId)
    val publisher = Publisher.newBuilder(topicName).build()

    try {
      // ✅ Connexion à GCS
      val storage = StorageOptions.getDefaultInstance.getService
      val blob: Blob = storage.get(bucketName, fileName)

      if (blob == null) {
        System.err.println(s"❌ Impossible de trouver le fichier $fileName dans le bucket $bucketName")
        sys.exit(1)
      }

      // ✅ Lecture du fichier
      val content = new String(blob.getContent(), "UTF-8")
      val lines   = content.split("\n").toList

      // Ignorer le header si présent
      val data =
        if (lines.nonEmpty && lines.head.toLowerCase.contains("order")) lines.drop(1)
        else lines

      // ✅ Envoi dans Pub/Sub
      data.foreach { line =>
        val message = PubsubMessage.newBuilder()
          .setData(ByteString.copyFromUtf8(line))
          .putAttributes("id", UUID.randomUUID().toString)
          .build()

        publisher.publish(message)
        println(s"✅ Sent: $line")
        Thread.sleep(500) // simulation streaming
      }
    } finally {
      publisher.shutdown()
      println("Producer terminé ✅")
    }
  }
}
