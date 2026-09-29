# Étiquettes & colisage — Clément Design

Une **seule page HTML** (`index.html`), sans serveur, sans compte, sans installation.
Chaque génération d'étiquette est enregistrée dans la base **Supabase** (projet
« Label »). Elle regroupe les deux outils :

- **Étiquettes & impression** : génère le fichier **`.nlbl`** pour Zebra Designer
  Essentials 3, **avec les données déjà intégrées** (on l'ouvre, on imprime) ;
- **Colisage** : colle ou importe les codes-barres scannés et obtient le colisage
  regroupé **OF → modèle → couleur → taille**, avec les quantités.

Le catalogue des **4 623 références** (article, couleur, taille, manche, code EAN-13)
est intégré à la page : elle fonctionne hors ligne, même ouverte par double-clic.

## Utilisation

- **Sur l'ordinateur** : double-cliquer sur `index.html` (Chrome, Edge ou Firefox récents).
- **Sur GitHub Pages** : *Settings → Pages → Build and deployment → Deploy from a
  branch*, choisir la branche et le dossier `/ (root)`. La page est ensuite en ligne
  à l'adresse `https://<utilisateur>.github.io/<dépôt>/`.

### Étiquettes

1. Choisir l'article, la couleur, la manche, la taille, puis saisir l'OF et le type.
2. **Générer le fichier .NLBL** (ou `Ctrl + ⏎`) : une fenêtre demande les quantités
   (par taille quand l'article en a plusieurs — 0 pour ignorer une taille).
3. Ouvrir le fichier téléchargé dans Zebra Designer 3 : les 7 variables (Modele, Type,
   OF, CodeBarre, Couleur, Manche, Taille) sont déjà remplies.

Une étiquette → un fichier `etiquettes_AAAAMMJJ_HHmm.nlbl` ; plusieurs étiquettes →
une archive `.zip` avec un `.nlbl` par étiquette et un `LISEZMOI.txt` (quantités).
Également : file d'impression (lot jusqu'à 100 étiquettes, `Ctrl + M`), mode SPE
(code-barres calculé, préfixe 99), imprimante cible, export `.TXT` historique,
aperçu du contenu du fichier, journal des générations.

### Colisage

Coller les codes (3 000 à 4 000 lignes) ou importer un `.txt` / `.csv`, puis
**Générer le colisage**. `code×N` compte N pièces. Codes inconnus signalés, copie
du tableau pour Excel, export `colisage_AAAAMMJJ_HHmm.csv`. Les codes SPE générés
sur le même poste sont reconnus avec leur OF ; sinon, saisir l'OF du lot.

## Ce qui est enregistré, et où

### Dans Supabase : l'historique de toutes les générations

À chaque génération (`.nlbl`, lot `.zip`, `.txt`), la page ajoute **une ligne par
étiquette** dans la table `label_generations` : date et heure, site / atelier,
fichier, **FAB ou SPE**, modèle, article, couleur (+ code), taille, manche, OF, type,
**code-barres** (celui du catalogue ou le code SPE calculé) et quantité de copies.

- **Sans Internet** : les lignes attendent sur le poste (en-tête « Supabase · N en
  attente ») et partent automatiquement dès le retour du réseau — rien n'est perdu,
  et un renvoi ne crée jamais de doublon.
- **Site / atelier** : à régler une fois par poste (icône réglages de l'en-tête),
  pour savoir qui a généré quoi. Vide = « Site web ».
- **Télécharger le fichier** : carte « Dernières générations » → *Télécharger
  l'historique complet* → code d'accès (+ dates facultatives) → CSV pour Excel
  (`historique_etiquettes_AAAAMMJJ_HHmm.csv`, tous les postes).
- **Dans Supabase** : *Table Editor* → vue `historique_etiquettes` (date et heure de
  Paris séparées) → *Export* → CSV.

Sécurité : la clé écrite dans `index.html` est la clé **publique** (publishable).
Elle ne permet ni de lire, ni de modifier, ni de supprimer la table : seulement
d'ajouter des générations (valeurs contrôlées) et d'exporter avec le code d'accès.
Le code se change dans Supabase (*SQL Editor*) :
`update public.parametres_prives set valeur = 'NOUVEAU-CODE' where cle = 'code_export';`
Le détail est dans `supabase/generations.sql`.

### Dans le navigateur du poste

Le journal de la page, les derniers OF, les préférences (site, imprimante, thème) et
la mémoire des codes SPE (pour le colisage) restent dans le navigateur (`localStorage`).

## Génération du `.nlbl` (inchangée)

Un `.nlbl` est une archive ZIP chiffrée **AES-256 (WinZip AE-1)** contenant le
design `Formats/<nom>` et la solution `<nom>.slnx`. La page reprend le modèle
**cLEMENT2** d'origine (intégré octet pour octet) et ne remplace que les valeurs des
7 variables (et, si demandé, le nom de l'imprimante) : le design n'est jamais modifié.
Le chiffrement (PBKDF2-HMAC-SHA1, AES-CTR, HMAC-SHA1) est fait dans le navigateur ;
le contenu des fichiers (XML du design et des variables) est identique, octet pour
octet, à celui que produisait l'ancienne application serveur.

## Modifier le catalogue

- **Sans Supabase** : dans `index.html`, bloc `<script id="donnees-catalogue">` —
  une ligne par référence : `["ARTICLE", "COULEUR", "TAILLE", "MANCHE", "CODE13"]`.
- **Avec Supabase (facultatif)** :
  1. Supabase → *SQL Editor* → exécuter `supabase/articles.sql` (crée la table
     `articles` en lecture seule pour la clé publique, et y charge les 4 623 références) ;
  2. dans `index.html`, passer `SUPABASE.lireCatalogue` à `true`.

  La page lit alors le catalogue depuis Supabase (« · Supabase » s'affiche dans
  l'en-tête) et revient automatiquement au catalogue intégré si Supabase ne répond pas.

## Contenu du dépôt

| Fichier | Rôle |
| --- | --- |
| `index.html` | L'application complète (page, styles, scripts, catalogue, modèle Zebra) |
| `supabase/generations.sql` | Enregistrement des générations (déjà appliqué sur le projet « Label ») |
| `supabase/articles.sql` | Facultatif : table du catalogue pour Supabase |
| `.nojekyll` | Publie la page telle quelle sur GitHub Pages |

L'ancienne application Next.js (réception, exports, comptes, synchronisation cloud)
reste disponible dans l'historique git (commit `836b790`).
