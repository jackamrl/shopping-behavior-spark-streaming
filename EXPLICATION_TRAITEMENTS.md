# 📊 Explication : Traitements Ajoutés au Consumer

## ✅ Oui, tous les résultats seront enregistrés dans BigQuery !

---

## 🎯 Vue d'ensemble

J'ai ajouté **10 traitements métier** qui enrichissent les données avant leur écriture dans BigQuery. Chaque traitement ajoute une nouvelle colonne calculée.

---

## 📋 Liste des Traitements

### 1. **💰 Calcul du Montant Final (final_amount_usd)**
```scala
final_amount_usd = purchase_amount_usd * 0.9 si discount_applied = "Yes"
                 = purchase_amount_usd sinon
```
**Utilité** : Calcule le montant réellement payé après application de la remise (10% de réduction).

**Exemple** :
- `purchase_amount_usd = 100`, `discount_applied = "Yes"` → `final_amount_usd = 90`
- `purchase_amount_usd = 100`, `discount_applied = "No"` → `final_amount_usd = 100`

---

### 2. **📊 Catégorisation du Montant (amount_category)**
```scala
amount_category = "Small"   si final_amount_usd < 50
                = "Medium"  si 50 <= final_amount_usd < 150
                = "Large"   si 150 <= final_amount_usd < 300
                = "Premium" si final_amount_usd >= 300
```
**Utilité** : Classe les achats par taille pour faciliter l'analyse des segments de prix.

**Exemple** :
- `final_amount_usd = 30` → `amount_category = "Small"`
- `final_amount_usd = 200` → `amount_category = "Large"`

---

### 3. **👤 Segmentation Client (customer_segment)**
```scala
customer_segment = "VIP"        si previous_purchases >= 10
                 = "Regular"    si 5 <= previous_purchases < 10
                 = "Occasional" si 2 <= previous_purchases < 5
                 = "New"        si previous_purchases < 2
```
**Utilité** : Identifie le type de client pour personnaliser les offres et le service.

**Exemple** :
- `previous_purchases = 12` → `customer_segment = "VIP"`
- `previous_purchases = 1` → `customer_segment = "New"`

---

### 4. **😊 Niveau de Satisfaction (satisfaction_level)**
```scala
satisfaction_level = "Very Satisfied"    si review_rating >= 4.5
                   = "Satisfied"          si 4.0 <= review_rating < 4.5
                   = "Neutral"            si 3.0 <= review_rating < 4.0
                   = "Dissatisfied"       si 2.0 <= review_rating < 3.0
                   = "Very Dissatisfied" si review_rating < 2.0
```
**Utilité** : Convertit les notes numériques en catégories compréhensibles pour l'analyse.

**Exemple** :
- `review_rating = 4.8` → `satisfaction_level = "Very Satisfied"`
- `review_rating = 2.5` → `satisfaction_level = "Dissatisfied"`

---

### 5. **🚨 Détection d'Anomalies (is_anomaly)**
```scala
is_anomaly = true  si final_amount_usd > 500
           = false sinon
```
**Utilité** : Identifie les transactions suspectes ou exceptionnelles pour investigation.

**Exemple** :
- `final_amount_usd = 600` → `is_anomaly = true`
- `final_amount_usd = 100` → `is_anomaly = false`

---

### 6. **💎 Valeur Client Estimée - CLV (estimated_clv)**
```scala
estimated_clv = previous_purchases * final_amount_usd * 0.3
```
**Utilité** : Estime la valeur à vie du client (Customer Lifetime Value) pour prioriser les actions marketing.

**Exemple** :
- `previous_purchases = 5`, `final_amount_usd = 100` → `estimated_clv = 150`
- Plus un client achète souvent et beaucoup, plus sa CLV est élevée

---

### 7. **📅 Catégorisation de la Fréquence (frequency_category)**
```scala
frequency_category = "High Frequency"   si frequency_of_purchases = "Weekly"
                   = "Medium Frequency" si frequency_of_purchases = "Monthly"
                   = "Low Frequency"    si frequency_of_purchases = "Annually"
                   = "Unknown"          sinon
```
**Utilité** : Normalise les fréquences d'achat pour faciliter l'analyse.

**Exemple** :
- `frequency_of_purchases = "Weekly"` → `frequency_category = "High Frequency"`

---

### 8. **💵 Profit Estimé (estimated_profit_usd)**
```scala
estimated_profit_usd = final_amount_usd * 0.4
```
**Utilité** : Estime le profit généré par chaque transaction (marge de 40% estimée).

**Exemple** :
- `final_amount_usd = 100` → `estimated_profit_usd = 40`

---

### 9. **🌍 Type de Saison (season_type)**
```scala
season_type = "High Season" si season = "Spring" ou "Summer"
            = "Low Season"   sinon
```
**Utilité** : Identifie les périodes de forte/petite activité pour la planification.

**Exemple** :
- `season = "Spring"` → `season_type = "High Season"`
- `season = "Winter"` → `season_type = "Low Season"`

---

### 10. **⭐ Score de Fidélité (loyalty_score)**
```scala
loyalty_score = "High"   si subscription_status = "Yes" ET previous_purchases >= 5
              = "Medium" si subscription_status = "Yes" OU previous_purchases >= 3
              = "Low"    sinon
```
**Utilité** : Évalue la fidélité du client pour cibler les campagnes de rétention.

**Exemple** :
- `subscription_status = "Yes"`, `previous_purchases = 8` → `loyalty_score = "High"`
- `subscription_status = "No"`, `previous_purchases = 1` → `loyalty_score = "Low"`

---

## 📊 Structure des Données dans BigQuery

### Avant (19 colonnes)
```
customer_id, age, gender, item_purchased, category, purchase_amount_usd,
location, size, color, season, review_rating, subscription_status,
shipping_type, discount_applied, promo_code_used, previous_purchases,
payment_method, frequency_of_purchases, processed_time
```

### Après (29 colonnes)
**Colonnes originales** (19) + **Colonnes enrichies** (10) :
```
... (colonnes originales) ...
final_amount_usd, amount_category, customer_segment, satisfaction_level,
is_anomaly, estimated_clv, frequency_category, estimated_profit_usd,
season_type, loyalty_score
```

---

## ✅ Confirmation : Oui, tout est enregistré dans BigQuery !

Tous ces traitements sont appliqués **avant** l'écriture dans BigQuery. Chaque ligne dans BigQuery contiendra :
- ✅ Les **19 colonnes originales** du CSV
- ✅ Les **10 colonnes enrichies** calculées par le Consumer

---

## 🎯 Cas d'Usage

### Exemple de Requête BigQuery

```sql
-- Analyser les clients VIP avec des achats Premium
SELECT 
  customer_id,
  customer_segment,
  amount_category,
  final_amount_usd,
  estimated_clv,
  loyalty_score
FROM `spark-streaming-483317.shopping_dev.orders`
WHERE customer_segment = 'VIP'
  AND amount_category = 'Premium'
ORDER BY estimated_clv DESC;
```

### Exemple : Détecter les anomalies

```sql
-- Trouver les transactions suspectes
SELECT *
FROM `spark-streaming-483317.shopping_dev.orders`
WHERE is_anomaly = true
ORDER BY final_amount_usd DESC;
```

### Exemple : Analyse de satisfaction

```sql
-- Taux de satisfaction par segment client
SELECT 
  customer_segment,
  satisfaction_level,
  COUNT(*) as count,
  AVG(review_rating) as avg_rating
FROM `spark-streaming-483317.shopping_dev.orders`
GROUP BY customer_segment, satisfaction_level
ORDER BY customer_segment, avg_rating DESC;
```

---

## 🔄 Flux de Traitement

```
CSV (19 colonnes)
    ↓
Consumer lit les données
    ↓
Traitements métier (10 enrichissements)
    ↓
DataFrame enrichi (29 colonnes)
    ↓
Vérification des doublons
    ↓
Écriture dans BigQuery (29 colonnes)
```

---

## 💡 Avantages

1. **📊 Données enrichies** : Plus d'informations pour l'analyse
2. **🎯 Segmentation** : Clients, montants, satisfaction, etc.
3. **🚨 Détection** : Anomalies identifiées automatiquement
4. **💰 Métriques business** : CLV, profit, fidélité
5. **⚡ Temps réel** : Tous les calculs sont faits en streaming

---

**En résumé** : Le Consumer enrichit maintenant les données avec 10 métriques business calculées, et **tout est enregistré dans BigQuery** pour vos analyses ! 🎉

