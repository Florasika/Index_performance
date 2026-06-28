-- ============================================================
--  JOUR 9 / 10 DAYS OF SQL — Index & Performance
--  Concepts : EXPLAIN QUERY PLAN · CREATE INDEX · Index composé
--             Index partiel · Quand indexer (et quand pas)
-- ============================================================

-- ── AVANT LES INDEX — comprendre le problème ─────────────────

-- ── 1. EXPLAIN QUERY PLAN : voir ce que SQL fait en coulisses ─
-- Sans index : SQLite scanne TOUTES les lignes (SCAN TABLE)
EXPLAIN QUERY PLAN
SELECT * FROM orders WHERE statut = 'livree';

-- Résultat attendu : SCAN orders
-- → SQL lit les 50 000 lignes une par une pour trouver les correspondances
-- → Équivalent de chercher un mot dans un livre sans index = lire page par page


-- ── 2. Requête de base SANS index (point de référence) ───────
SELECT
    statut,
    COUNT(*) AS nb_commandes,
    ROUND(SUM(montant), 2) AS ca_total
FROM orders
GROUP BY statut;


-- ════════════════════════════════════════════════════════════
--  CRÉER LES INDEX
-- ════════════════════════════════════════════════════════════

-- ── 3. CREATE INDEX simple sur une colonne ───────────────────
CREATE INDEX IF NOT EXISTS idx_orders_statut
ON orders (statut);

-- Syntaxe : CREATE INDEX nom_index ON table (colonne)
-- Convention de nommage : idx_table_colonne (lisible et uniforme)


-- ── 4. EXPLAIN QUERY PLAN APRÈS l'index ──────────────────────
-- La même requête qu'au #1 — maintenant avec index
EXPLAIN QUERY PLAN
SELECT * FROM orders WHERE statut = 'livree';

-- Résultat attendu : SEARCH orders USING INDEX idx_orders_statut
-- → SQL utilise l'index pour aller directement aux bonnes lignes
-- → Comme chercher un mot dans un index de livre = direct à la bonne page


-- ── 5. Index sur date (colonne de filtre et tri fréquents) ───
CREATE INDEX IF NOT EXISTS idx_orders_date
ON orders (date_commande);

-- Utile pour :
-- WHERE date_commande BETWEEN '2024-01-01' AND '2024-12-31'
-- ORDER BY date_commande
-- GROUP BY strftime('%Y-%m', date_commande)


-- ── 6. Index composé : plusieurs colonnes ensemble ───────────
CREATE INDEX IF NOT EXISTS idx_orders_statut_date
ON orders (statut, date_commande);

-- Utile quand on filtre souvent sur LES DEUX colonnes ensemble :
-- WHERE statut = 'livree' AND date_commande >= '2024-01-01'
--
-- RÈGLE IMPORTANTE : l'ordre des colonnes compte
-- idx(statut, date) est efficace pour : WHERE statut = ...
-- idx(statut, date) est AUSSI efficace pour : WHERE statut = ... AND date = ...
-- idx(statut, date) est PEU utile pour : WHERE date = ... (sans statut)


-- ── 7. EXPLAIN pour valider que l'index composé est utilisé ──
EXPLAIN QUERY PLAN
SELECT * FROM orders
WHERE statut = 'livree'
  AND date_commande >= '2024-01-01';


-- ── 8. Index sur clé étrangère (JOIN plus rapide) ────────────
CREATE INDEX IF NOT EXISTS idx_orders_product_id
ON orders (product_id);

-- Sans cet index, un JOIN sur product_id scanne toute la table orders
-- Toutes les clés étrangères fréquemment utilisées en JOIN = à indexer


-- ── 9. Vérifier les index existants sur une table ────────────
PRAGMA index_list('orders');
PRAGMA index_list('products');


-- ── 10. Voir les colonnes d'un index spécifique ──────────────
PRAGMA index_info('idx_orders_statut_date');


-- ════════════════════════════════════════════════════════════
--  CAS D'USAGE RÉELS
-- ════════════════════════════════════════════════════════════

-- ── 11. Requête bénéficiant du double index ──────────────────
-- CA mensuel pour les commandes livrées (FILTRE + GROUPE PAR DATE)
SELECT
    strftime('%Y-%m', date_commande) AS mois,
    COUNT(*) AS nb_commandes,
    ROUND(SUM(montant), 2) AS ca_mensuel
FROM orders
WHERE statut = 'livree'
GROUP BY mois
ORDER BY mois;


-- ── 12. JOIN rapide grâce à l'index sur clé étrangère ────────
SELECT
    p.categorie,
    COUNT(o.id) AS nb_commandes,
    ROUND(SUM(o.montant), 2) AS ca_total
FROM orders o
INNER JOIN products p ON o.product_id = p.id
WHERE o.statut = 'livree'
GROUP BY p.categorie
ORDER BY ca_total DESC;


-- ── 13. EXPLAIN sur le JOIN pour vérifier les index utilisés ─
EXPLAIN QUERY PLAN
SELECT p.categorie, COUNT(o.id)
FROM orders o
INNER JOIN products p ON o.product_id = p.id
WHERE o.statut = 'livree'
GROUP BY p.categorie;


-- ── 14. Index partiel : indexer seulement les lignes utiles ──
-- Créer un index uniquement sur les commandes en cours
-- (plus petit = plus rapide que d'indexer toute la table)
CREATE INDEX IF NOT EXISTS idx_orders_en_cours
ON orders (date_commande, client_id)
WHERE statut = 'en_cours';

-- SQLite, PostgreSQL supportent les index partiels
-- MySQL ne les supporte pas nativement


-- ── 15. Supprimer un index inutile ───────────────────────────
-- DROP INDEX IF EXISTS idx_inutile;
-- (Commenté pour ne pas supprimer un index créé dans ce fichier)
-- Un index coûte de l'espace disque et RALENTIT les INSERT/UPDATE/DELETE
-- → N'indexer que les colonnes réellement utilisées en WHERE, JOIN, ORDER BY


-- ════════════════════════════════════════════════════════════
--  RÈGLES DE DÉCISION
-- ════════════════════════════════════════════════════════════

-- ── 16. QUAND indexer ? ──────────────────────────────────────
-- Colonnes dans WHERE, JOIN ON, ORDER BY fréquents
-- Clés étrangères (product_id, client_id...)
-- Colonnes avec haute cardinalité (beaucoup de valeurs uniques)
-- Tables avec > 10 000 lignes

-- QUAND ne PAS indexer ?
-- Tables < 1 000 lignes (le SCAN complet est souvent plus rapide)
-- Colonnes rarement utilisées en filtre
-- Colonnes avec très peu de valeurs distinctes (booléen, statut binaire)
-- Tables souvent modifiées (INSERT/UPDATE/DELETE fréquents)

-- ── 17. REQUÊTE FINALE — Tableau de bord performance ─────────
WITH stats_par_mois AS (
    SELECT
        strftime('%Y-%m', o.date_commande) AS mois,
        p.categorie,
        COUNT(*) AS nb_commandes,
        ROUND(SUM(o.montant), 2) AS ca,
        ROUND(AVG(o.montant), 2) AS panier_moyen
    FROM orders o
    INNER JOIN products p ON o.product_id = p.id
    WHERE o.statut = 'livree'
      AND o.date_commande >= '2024-01-01'
    GROUP BY mois, p.categorie
)
SELECT *
FROM stats_par_mois
ORDER BY mois, ca DESC
LIMIT 20;
