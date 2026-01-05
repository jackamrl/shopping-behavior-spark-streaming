# 💎 Explication : Calcul de la Valeur Client (CLV)

## 📊 Formule Actuelle

```scala
estimated_clv = previous_purchases * final_amount_usd * 0.3
```

---

## 🔍 Détail de la Formule

### Composants

1. **`previous_purchases`** : Nombre d'achats précédents du client
2. **`final_amount_usd`** : Montant de l'achat actuel (après remise)
3. **`0.3`** : Facteur de projection (30%)

### Explication

La formule estime la **valeur à vie du client** (Customer Lifetime Value) en multipliant :
- Le **nombre d'achats précédents** (historique)
- Le **montant de l'achat actuel** (tendance récente)
- Un **facteur de projection** (0.3 = 30%)

---

## 💡 Logique Métier

### Pourquoi cette formule ?

1. **`previous_purchases`** : 
   - Plus un client a acheté, plus il est fidèle
   - Indique la probabilité de futurs achats
   - Exemple : Un client avec 10 achats précédents est plus précieux qu'un nouveau client

2. **`final_amount_usd`** :
   - Le montant actuel reflète le pouvoir d'achat du client
   - Un client qui achète beaucoup maintenant continuera probablement
   - Exemple : Un client qui achète 200$ est plus précieux qu'un qui achète 20$

3. **`0.3` (30%)** :
   - Facteur de projection pour estimer la valeur future
   - Considère que tous les achats futurs ne seront pas au même montant
   - Réduit l'estimation pour être plus conservateur

---

## 📈 Exemples Concrets

### Exemple 1 : Client Nouveau
```
previous_purchases = 0
final_amount_usd = 50
estimated_clv = 0 * 50 * 0.3 = 0
```
**Interprétation** : Client nouveau, pas encore de valeur établie.

---

### Exemple 2 : Client Occasionnel
```
previous_purchases = 2
final_amount_usd = 80
estimated_clv = 2 * 80 * 0.3 = 48
```
**Interprétation** : Client avec peu d'historique, valeur modérée.

---

### Exemple 3 : Client Régulier
```
previous_purchases = 5
final_amount_usd = 120
estimated_clv = 5 * 120 * 0.3 = 180
```
**Interprétation** : Client fidèle avec bon pouvoir d'achat.

---

### Exemple 4 : Client VIP
```
previous_purchases = 15
final_amount_usd = 250
estimated_clv = 15 * 250 * 0.3 = 1125
```
**Interprétation** : Client très précieux, forte valeur estimée.

---

## 🎯 Cas d'Usage

### 1. Prioriser les Clients VIP
```sql
SELECT 
  customer_id,
  customer_segment,
  estimated_clv,
  final_amount_usd
FROM `spark-streaming-483317.shopping_dev.orders`
WHERE estimated_clv > 500
ORDER BY estimated_clv DESC;
```

### 2. Analyser la Valeur par Segment
```sql
SELECT 
  customer_segment,
  AVG(estimated_clv) as avg_clv,
  MAX(estimated_clv) as max_clv,
  MIN(estimated_clv) as min_clv,
  COUNT(*) as count
FROM `spark-streaming-483317.shopping_dev.orders`
GROUP BY customer_segment
ORDER BY avg_clv DESC;
```

### 3. Identifier les Clients à Fort Potentiel
```sql
-- Clients avec peu d'achats mais montants élevés
SELECT 
  customer_id,
  previous_purchases,
  final_amount_usd,
  estimated_clv
FROM `spark-streaming-483317.shopping_dev.orders`
WHERE previous_purchases < 3 
  AND final_amount_usd > 200
ORDER BY estimated_clv DESC;
```

---

## ⚠️ Limitations de la Formule Actuelle

### Formule Simplifiée

La formule actuelle est **intentionnellement simplifiée** pour le streaming en temps réel. Elle ne prend pas en compte :

1. **Fréquence d'achat** : Un client qui achète souvent vs rarement
2. **Décroissance temporelle** : Les achats anciens devraient compter moins
3. **Taux de rétention** : Probabilité que le client continue d'acheter
4. **Coût d'acquisition** : Coût pour acquérir le client
5. **Durée de vie estimée** : Combien de temps le client restera actif

---

## 🔄 Formule CLV Plus Sophistiquée (Optionnelle)

Si vous voulez une formule plus précise, voici une version améliorée :

```scala
// Formule améliorée (exemple)
estimated_clv = (
  previous_purchases * final_amount_usd * 0.3 +  // Valeur historique
  (if frequency_of_purchases == "Weekly" then 1.5 else 1.0) * final_amount_usd * 0.2 +  // Facteur fréquence
  (if subscription_status == "Yes" then 2.0 else 1.0) * final_amount_usd * 0.1  // Facteur abonnement
)
```

**Avantages** :
- Prend en compte la fréquence d'achat
- Valorise les clients abonnés
- Plus précis mais plus complexe

---

## 📊 Interprétation des Résultats

### Échelle de Valeur

| estimated_clv | Interprétation |
|--------------|----------------|
| 0 - 50 | Client nouveau ou faible valeur |
| 50 - 200 | Client occasionnel |
| 200 - 500 | Client régulier |
| 500 - 1000 | Client VIP |
| > 1000 | Client très précieux |

---

## 💡 Recommandations d'Utilisation

### 1. **Marketing Ciblé**
- Cibler les clients avec `estimated_clv > 500` pour des offres premium
- Offrir des avantages aux clients avec `estimated_clv > 200`

### 2. **Service Client**
- Prioriser le support pour les clients VIP (`estimated_clv > 500`)
- Offrir des remises personnalisées selon la valeur

### 3. **Analyse Business**
- Suivre l'évolution de la CLV moyenne par segment
- Identifier les tendances de valeur client

---

## ✅ Résumé

**Formule actuelle** :
```
estimated_clv = previous_purchases * final_amount_usd * 0.3
```

**Logique** :
- Plus un client achète souvent (`previous_purchases`) → Plus précieux
- Plus un client dépense (`final_amount_usd`) → Plus précieux
- Facteur 0.3 pour une estimation conservatrice

**Utilité** :
- Identifier les clients les plus précieux
- Prioriser les actions marketing
- Analyser la valeur par segment

Cette formule est **simple, rapide et efficace** pour le streaming en temps réel ! 🎯

