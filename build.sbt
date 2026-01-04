ThisBuild / version := "0.1.0-SNAPSHOT"
ThisBuild / scalaVersion := "2.12.18" // aligné avec les connecteurs 2.12 pour Dataproc

// Sous-projet pour créer un JAR avec uniquement les dépendances Google Cloud
lazy val deps = (project in file("deps"))
  .settings(
    name := "spark-streaming-deps",
    libraryDependencies ++= Seq(
      "com.google.cloud" % "google-cloud-pubsub" % "1.141.4",
      "com.google.cloud.spark" %% "spark-bigquery-with-dependencies" % "0.32.2",
      "io.grpc" % "grpc-netty-shaded" % "1.61.0"
    ),
    assembly / assemblyJarName := "spark-streaming-deps.jar",
    assembly / assemblyMergeStrategy := {
      case PathList("META-INF", "services", xs @ _*) => MergeStrategy.filterDistinctLines
      case PathList("META-INF", "MANIFEST.MF") => MergeStrategy.discard
      case PathList("META-INF", xs @ _*) => MergeStrategy.first
      case "module-info.class" => MergeStrategy.discard
      case _ => MergeStrategy.first
    }
  )

lazy val root = (project in file("."))
  .settings(
    name := "spark-streaming-local",
    libraryDependencies ++= Seq(
      // Spark (pour compilation locale ; sur Dataproc, ils sont fournis)
      "org.apache.spark" %% "spark-sql" % "3.5.0" % Provided,
      "org.apache.spark" %% "spark-streaming" % "3.5.0" % Provided,

      // Google Cloud SDK pour dev local / utilitaires
      "com.google.cloud.bigdataoss" % "gcs-connector" % "hadoop3-2.2.21" % Provided,
      "com.google.cloud" % "google-cloud-storage" % "2.57.0",
      "com.google.cloud" % "google-cloud-pubsub" % "1.141.4",
      
      // Connecteur Spark pour BigQuery (inclus dans l'assembly - inclut déjà google-cloud-bigquery)
      "com.google.cloud.spark" %% "spark-bigquery-with-dependencies" % "0.32.2",
      
      // gRPC pour Pub/Sub (nécessaire pour le client Pub/Sub)
      "io.grpc" % "grpc-netty-shaded" % "1.61.0",

      // dotenv pour tests locaux (utilisé par le Producer uniquement)
      "io.github.cdimascio" % "dotenv-java" % "2.2.2",

      // Scala reflection (version alignée)
      "org.scala-lang" % "scala-reflect" % "2.12.18",

      // Forcer Jackson (doit venir après les libs Google)
      "com.fasterxml.jackson.core" % "jackson-core" % "2.14.2" force(),
      "com.fasterxml.jackson.core" % "jackson-databind" % "2.14.0" force(),
      "com.fasterxml.jackson.module" %% "jackson-module-scala" % "2.14.2" force()
    ),
    dependencyOverrides ++= Seq(
      "com.fasterxml.jackson.core" % "jackson-core" % "2.14.2",
      "com.fasterxml.jackson.core" % "jackson-annotations" % "2.14.2",
      "com.fasterxml.jackson.core" % "jackson-databind" % "2.14.2",
      "com.fasterxml.jackson.module" %% "jackson-module-scala" % "2.14.2"
    ),
    // Exclure UNIQUEMENT Spark et Hadoop (fournis par Dataproc)
    // Garder TOUTES les dépendances Google Cloud et leurs transitives
    assembly / assemblyExcludedJars := {
      val cp = (assembly / fullClasspath).value
      cp.filter { file =>
        val name = file.data.getName
        // Exclure seulement Spark et Hadoop de base (mais garder spark-bigquery)
        (name.contains("spark-sql") && !name.contains("spark-bigquery")) || 
        name.contains("spark-core") || 
        name.contains("spark-streaming") ||
        (name.contains("hadoop") && (name.contains("common") || name.contains("client"))) ||
        name.contains("scala-library")
      }
    },
    assembly / assemblyMergeStrategy := {
      // Exclure les classes v2 du package bigquery.v2
      case PathList("com", "google", "cloud", "spark", "bigquery", "v2", xs @ _*) => MergeStrategy.discard
      // Filtrer les services pour exclure les références v2
      case PathList("META-INF", "services", "com.google.cloud.spark.bigquery.TypeConverter") => 
        MergeStrategy.filterDistinctLines
      case PathList("META-INF", "services", xs @ _*) => MergeStrategy.filterDistinctLines
      case PathList("META-INF", "MANIFEST.MF") => MergeStrategy.discard
      case PathList("META-INF", xs @ _*) => MergeStrategy.first
      case PathList("arrow-git.properties") => MergeStrategy.first
      case "module-info.class" => MergeStrategy.discard
      case _ => MergeStrategy.first
    },
    assembly / mainClass := Some("com.example.streaming.Consumer")
  )
