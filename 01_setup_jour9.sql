-- ============================================================
--  JOUR 9 / 10 DAYS OF SQL — Setup : Index & Performance
--  Tables : products (10 000 lignes) + orders (50 000 lignes)
-- ============================================================

DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;

CREATE TABLE products (
    id          INTEGER PRIMARY KEY,
    nom         TEXT NOT NULL,
    categorie   TEXT NOT NULL,
    prix        REAL NOT NULL,
    stock       INTEGER NOT NULL
);

CREATE TABLE orders (
    id              INTEGER PRIMARY KEY,
    product_id      INTEGER NOT NULL,
    date_commande   DATE NOT NULL,
    quantite        INTEGER NOT NULL,
    montant         REAL NOT NULL,
    statut          TEXT NOT NULL,
    client_id       INTEGER NOT NULL,
    FOREIGN KEY (product_id) REFERENCES products(id)
);
