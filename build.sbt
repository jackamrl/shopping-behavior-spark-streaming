ThisBuild / version := "0.1.0-SNAPSHOT"
ThisBuild / scalaVersion := "2.12.17"

lazy val root = (project in file("."))
  .settings(
    name := "spark-streaming-local",
    libraryDependencies ++= Seq(
      // Spark
      "org.apache.spark" %% "spark-core" % "3.4.1" % Provided,
      "org.apache.spark" %% "spark-sql"  % "3.4.1" % Provided,
      "org.apache.spark" %% "spark-streaming" % "3.4.1",

      // Google Cloud Pub/Sub client
      "com.google.cloud" % "google-cloud-storage" % "2.57.0",
      "com.google.cloud" % "google-cloud-pubsub" % "1.141.4",


      // (optionnel) BigQuery client, si tu veux écrire vers BigQuery en local
      "com.google.cloud" % "google-cloud-bigquery" % "2.33.1",

      // dotenv
      "io.github.cdimascio" % "dotenv-java" % "2.2.2",

      "org.scala-lang" % "scala-reflect" % "2.12.17"

    )
  )
assemblyMergeStrategy in assembly := {
  case PathList("META-INF", xs @ _*) => MergeStrategy.discard
  case PathList("arrow-git.properties") => MergeStrategy.first
  case "module-info.class" => MergeStrategy.discard
  case _ => MergeStrategy.first
}
