# 🔍 Explication : Pourquoi `spark.read` et non `readStream` à la ligne 280 ?

## 📍 Contexte

À la ligne 280, dans la fonction `foreachBatch`, on utilise :

```scala
val existingDF = try {
  spark.read  // ← Pourquoi pas readStream ?
    .format("com.google.cloud.spark.bigquery.BigQueryRelationProvider")
    .option("table", finalBigQueryTable)
    .load()
    .select(createHashExpr.alias("row_hash"))
}
```

---

## 🎯 Raison Principale : Lecture Ponctuelle dans `foreachBatch`

### 1. **Contexte : `foreachBatch` est déjà dans un Stream**

```scala
transformedDF.writeStream
  .foreachBatch { (batchDF, batchId) =>
    // Ici, on est DÉJÀ dans un contexte de streaming
    // batchDF est le micro-batch actuel du stream
    
    // On a besoin de lire TOUTES les données existantes de BigQuery
    // pour comparer avec le batch actuel
    val existingDF = spark.read  // ← Lecture batch ponctuelle
      .format("...")
      .load()
  }
```

**Point clé** : On est déjà dans un contexte de streaming (`writeStream`). On n'a pas besoin d'un **nouveau stream** pour lire BigQuery.

---

## 🔄 Différence entre `read` et `readStream`

### `spark.read` (Batch)
- ✅ **Lecture ponctuelle** : Lit toutes les données **une fois**
- ✅ **Résultat immédiat** : Retourne un DataFrame avec toutes les données
- ✅ **Utilisation** : Quand on a besoin de **toutes les données** pour une opération (ex: vérification de doublons)

### `spark.readStream` (Streaming)
- ✅ **Lecture continue** : Lit les données **en continu** (micro-batches)
- ✅ **Résultat continu** : Retourne un Streaming DataFrame
- ✅ **Utilisation** : Quand on veut traiter les **nouvelles données** au fur et à mesure

---

## 💡 Pourquoi `read` ici ?

### Objectif : Vérifier les Doublons

```scala
// 1. On reçoit un micro-batch du stream (batchDF)
val batchDFWithHash = createRowHash(batchDF)

// 2. On a besoin de TOUTES les données existantes dans BigQuery
//    pour savoir si les lignes du batch existent déjà
val existingDF = spark.read  // ← Lecture de TOUTES les données
  .format("...")
  .load()
  .select(createHashExpr.alias("row_hash"))

// 3. On compare le batch avec TOUTES les données existantes
val newRowsDF = batchDFWithHash
  .join(existingDF, Seq("row_hash"), "left_anti")  // ← Join avec TOUTES les données
```

**Pourquoi `read` et non `readStream` ?**

1. **On a besoin de TOUTES les données** : Pour détecter les doublons, on doit comparer avec **toutes** les lignes déjà dans BigQuery, pas seulement les nouvelles.

2. **Lecture ponctuelle** : On lit une seule fois, au moment du micro-batch, pour faire la comparaison.

3. **Pas besoin de streaming** : On ne veut pas un stream continu de BigQuery, juste un snapshot à un instant T.

---

## ❌ Pourquoi `readStream` ne fonctionnerait PAS ici ?

### Problème 1 : Conflit de Contextes

```scala
transformedDF.writeStream  // ← Stream 1
  .foreachBatch { (batchDF, batchId) =>
    val existingDF = spark.readStream  // ← Stream 2
      .format("...")
      .load()
    
    // ❌ On ne peut pas joindre un DataFrame batch (batchDF) 
    //    avec un Streaming DataFrame (existingDF)
    val newRowsDF = batchDF.join(existingDF, ...)  // ERREUR !
  }
```

**Erreur** : On ne peut pas joindre un DataFrame batch avec un Streaming DataFrame.

### Problème 2 : Logique Incorrecte

```scala
// Avec readStream, on lirait seulement les NOUVELLES données de BigQuery
// Mais on a besoin de TOUTES les données existantes pour détecter les doublons !

val existingDF = spark.readStream  // ← Lit seulement les nouvelles données
  .load()

// ❌ On manquerait les doublons avec les anciennes données !
```

---

## ✅ Solution Actuelle (Correcte)

```scala
transformedDF.writeStream  // Stream principal
  .foreachBatch { (batchDF, batchId) =>
    // batchDF = micro-batch du stream (DataFrame batch)
    
    // Lecture ponctuelle de TOUTES les données existantes
    val existingDF = spark.read  // ← DataFrame batch
      .format("...")
      .load()
      .select(createHashExpr.alias("row_hash"))
    
    // Join possible : DataFrame batch × DataFrame batch
    val newRowsDF = batchDFWithHash
      .join(existingDF, Seq("row_hash"), "left_anti")
  }
```

**Pourquoi ça fonctionne** :
- ✅ `batchDF` = DataFrame batch (du micro-batch)
- ✅ `existingDF` = DataFrame batch (lecture ponctuelle)
- ✅ Join possible : batch × batch

---

## 📊 Schéma du Flux

```
┌─────────────────────────────────────────┐
│  Stream Principal (readStream)         │
│  ┌───────────────────────────────────┐ │
│  │  Micro-batch #1                   │ │
│  │  ┌─────────────────────────────┐ │ │
│  │  │ foreachBatch {               │ │ │
│  │  │   batchDF = ...              │ │ │
│  │  │                              │ │ │
│  │  │   existingDF = spark.read    │ │ │ ← Lecture batch ponctuelle
│  │  │     .load()                  │ │ │
│  │  │                              │ │ │
│  │  │   join(batchDF, existingDF) │ │ │ ← Join batch × batch
│  │  │ }                            │ │ │
│  │  └─────────────────────────────┘ │ │
│  └───────────────────────────────────┘ │
│  ┌───────────────────────────────────┐ │
│  │  Micro-batch #2                   │ │
│  │  (même processus)                 │ │
│  └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

---

## 🎯 Résumé

| Aspect | `spark.read` (ligne 280) | `spark.readStream` (ne fonctionnerait pas) |
|--------|-------------------------|-------------------------------------------|
| **Type** | DataFrame batch | Streaming DataFrame |
| **Lecture** | Toutes les données (snapshot) | Nouvelles données (continu) |
| **Usage** | Comparaison avec toutes les données existantes | Traitement continu |
| **Join** | ✅ Possible avec batchDF | ❌ Impossible avec batchDF |
| **Logique** | ✅ Correct pour détecter les doublons | ❌ Incorrect (manquerait les anciens doublons) |

---

## ✅ Conclusion

**On utilise `spark.read` à la ligne 280 car** :

1. ✅ On est déjà dans un contexte de streaming (`foreachBatch`)
2. ✅ On a besoin de **toutes** les données existantes (pas seulement les nouvelles)
3. ✅ On fait une lecture **ponctuelle** pour comparer avec le batch actuel
4. ✅ On doit joindre avec un DataFrame batch (pas un Streaming DataFrame)

**C'est la bonne approche pour la détection de doublons !** 🎯

