// Build file pour créer un JAR avec uniquement les dépendances Google Cloud
lazy val deps = (project in file("deps"))
  .settings(
    name := "spark-streaming-deps",
    version := "0.1.0-SNAPSHOT",
    scalaVersion := "2.12.18",
    libraryDependencies ++= Seq(
      "com.google.cloud" % "google-cloud-pubsub" % "1.141.4",
      "com.google.cloud.spark" %% "spark-bigquery-with-dependencies" % "0.32.2",
      "io.grpc" % "grpc-netty-shaded" % "1.61.0"
    ),
    assembly / assemblyJarName := "spark-streaming-deps.jar",
    assemblyMergeStrategy in assembly := {
      case PathList("META-INF", "services", xs @ _*) => MergeStrategy.filterDistinctLines
      case PathList("META-INF", "MANIFEST.MF") => MergeStrategy.discard
      case PathList("META-INF", xs @ _*) => MergeStrategy.first
      case "module-info.class" => MergeStrategy.discard
      case _ => MergeStrategy.first
    }
  )



