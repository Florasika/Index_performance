# ⚡ Jour 9 / 10 — SQL : Index & Performance

> **Série : 10 Days of SQL** · Jour 9/10  
> Concepts : EXPLAIN QUERY PLAN · CREATE INDEX · Index composé · Index partiel · Trade-offs

---

## 📁 Structure du projet

```
day-09-indexes/
│
├── 01_setup.sql      ← Schéma + script Python pour générer les données
├── 02_indexes.sql    ← 17 requêtes commentées
├── perf.db            ← Base SQLite (10 000 produits + 50 000 commandes)
└── README.md
```

---

## 🚀 Installation & Lancement

```bash
# Cloner le repo
git clone https://github.com/ton-pseudo/10-days-sql.git
cd 10-days-sql/day-09-indexes

# Recréer la base depuis zéro (génère 60 000 lignes via Python)
python3 -c "
import sqlite3, random, datetime
random.seed(42)
conn = sqlite3.connect('perf.db')
c = conn.cursor()
c.executescript(open('01_setup.sql').read())
categories = ['Informatique','Mobile','Audio','Wearable','Accessoire']
statuts    = ['livree','en_cours','annulee']
produits_base = ['Laptop','Smartphone','Tablette','Ecouteurs','Montre','Clavier','Souris','Webcam','SSD','Hub']
products = [(i, random.choice(produits_base)+f' Pro {i}', random.choice(categories),
             round(random.uniform(20,2000),2), random.randint(0,500)) for i in range(1,10001)]
c.executemany('INSERT INTO products VALUES (?,?,?,?,?)', products)
start = datetime.date(2023,1,1)
orders = [(i, random.randint(1,10000), (start+datetime.timedelta(days=random.randint(0,730))).isoformat(),
           random.randint(1,20), 0, random.choice(statuts), random.randint(1,1000)) for i in range(1,50001)]
c.executemany('INSERT INTO orders VALUES (?,?,?,?,?,?,?)', orders)
conn.commit(); conn.close()
print('Base créée')
"

# Exécuter toutes les requêtes
sqlite3 perf.db < 02_indexes.sql
```

---

## 📊 Le schéma — 2 tables

```
products (10 000 lignes)
├── id (INTEGER PRIMARY KEY — auto-indexé)
├── nom, categorie, prix, stock

orders (50 000 lignes)
├── id (INTEGER PRIMARY KEY — auto-indexé)
├── product_id (FK → products.id)
├── date_commande, quantite, montant, statut, client_id
```

La taille est choisie pour que la différence avant/après index soit **visible** dans le plan d'exécution.

---

## 🔑 1. EXPLAIN QUERY PLAN — voir ce que SQL fait vraiment

```sql
EXPLAIN QUERY PLAN
SELECT * FROM orders WHERE statut = 'livree';
```

**Avant index :**
```
SCAN orders
```
SQL lit les 50 000 lignes une par une — équivalent de chercher un mot en lisant un livre page par page.

**Après `CREATE INDEX idx_orders_statut ON orders (statut)` :**
```
SEARCH orders USING INDEX idx_orders_statut (statut=?)
```
SQL saute directement aux bonnes lignes — équivalent de chercher dans l'index du livre.

---

## 🔑 2. CREATE INDEX — syntaxe

```sql
-- Index simple
CREATE INDEX idx_orders_statut ON orders (statut);

-- Vérifier les index d'une table
PRAGMA index_list('orders');

-- Voir les colonnes d'un index
PRAGMA index_info('idx_orders_statut_date');

-- Supprimer un index
DROP INDEX IF EXISTS idx_inutile;
```
Convention de nommage recommandée : `idx_table_colonne` — uniforme et lisible.

---

## 🔑 3. Index composé — l'ordre des colonnes compte

```sql
CREATE INDEX idx_orders_statut_date ON orders (statut, date_commande);
```

| Requête | Index utilisé ? |
|---|---|
| `WHERE statut = 'livree'` | ✓ Oui (1ère colonne) |
| `WHERE statut = 'livree' AND date_commande >= '2024-01-01'` | ✓ Oui (les 2 colonnes) |
| `WHERE date_commande >= '2024-01-01'` (sans statut) | ✗ Non |

**Règle du préfixe** : pour qu'un index composé soit utilisé, la première colonne doit obligatoirement apparaître dans le `WHERE`.

---

## 🔑 4. Index sur clé étrangère — JOIN plus rapide

```sql
CREATE INDEX idx_orders_product_id ON orders (product_id);
```
Sans cet index, un JOIN `orders ↔ products` scanne les 50 000 lignes de `orders` pour chaque ligne de `products`. Avec l'index, SQL accède directement aux lignes correspondantes.

**Règle** : toutes les colonnes régulièrement utilisées dans `JOIN ON` méritent un index.

---

## 🔑 5. Index partiel — indexer seulement ce qui est utile

```sql
CREATE INDEX idx_orders_en_cours
ON orders (date_commande, client_id)
WHERE statut = 'en_cours';
```
N'indexe que les commandes en cours (~33% des lignes). Plus petit = plus rapide à lire, moins d'espace disque. Disponible sur SQLite et PostgreSQL, mais **pas sur MySQL**.

---

## 🧠 Quand créer un index ?

### ✓ Indexer
- Table avec **> 10 000 lignes**
- Colonne fréquemment dans `WHERE`, `JOIN ON`, `ORDER BY`
- Clés étrangères (`product_id`, `client_id`...)
- Colonnes avec **haute cardinalité** (beaucoup de valeurs uniques)

### ✗ Ne pas indexer
- Tables avec **< 1 000 lignes** (SCAN souvent plus rapide avec le cache)
- Colonnes rarement filtrées
- **Faible cardinalité** : booléen, statut avec 2-3 valeurs
- Tables avec **INSERT/UPDATE/DELETE très fréquents** (chaque écriture met à jour l'index)

---

## 🔄 Le workflow complet

```
1. Requête lente identifiée
2. EXPLAIN QUERY PLAN → on voit SCAN
3. CREATE INDEX sur la colonne du WHERE
4. EXPLAIN QUERY PLAN → on voit SEARCH USING INDEX
5. Valider que la requête fonctionnelle produit le même résultat
```


---

⭐ **Si ce projet t'aide, mets une étoile !**
