-- ==========================================================================
-- Enregistrement des générations d'étiquettes (projet Supabase « Label »)
-- DÉJÀ APPLIQUÉ sur le projet. Ce fichier sert de référence / de réinstallation.
--
-- Principe : la page (clé publique) n'a AUCUN droit direct sur la table.
--  - enregistrer_generations(lignes) : ajoute les étiquettes générées
--    (contrôle des valeurs, doublons ignorés lors des renvois) ;
--  - exporter_generations(code, du, au) : historique complet, uniquement avec
--    le code d'accès stocké dans parametres_prives (invisible depuis la page).
--
-- Changer le code d'accès (SQL Editor) :
--   update public.parametres_prives set valeur = 'NOUVEAU-CODE' where cle = 'code_export';
-- Voir l'historique dans Supabase : Table Editor > vue « historique_etiquettes »
-- (bouton Export > CSV).
-- ==========================================================================

-- Table existante (créée par l'ancienne application), conservée avec son historique.
create table if not exists public.label_generations (
  id           bigserial primary key,
  site_id      text not null,
  site_label   text not null default '',
  local_id     text not null,
  code_barre   text not null,
  article      text not null default '',
  modele       text not null default '',
  couleur      text not null default '',
  couleur_code text not null default '',
  taille       text not null default '',
  manche       text not null default '',
  "of"         text not null default '',
  type         text not null default '',
  source       text not null default 'FAB',   -- FAB (catalogue) | SPE (code calculé 99…) | EXT
  quantite     integer not null default 1,     -- copies demandées
  filename     text not null default '',       -- fichier .nlbl / .zip / .txt produit
  genere_at    timestamptz not null default now(),
  unique (site_id, local_id)
);

-- 1. Aucun accès direct pour la clé publique.
alter table public.label_generations enable row level security;
revoke all on table public.label_generations from anon, authenticated;

-- 2. Vue lisible : date et heure de Paris séparées.
create or replace view public.historique_etiquettes
with (security_invoker = true) as
select
  to_char(g.genere_at at time zone 'Europe/Paris', 'YYYY-MM-DD') as date_generation,
  to_char(g.genere_at at time zone 'Europe/Paris', 'HH24:MI:SS') as heure,
  coalesce(nullif(g.site_label, ''), g.site_id) as site,
  g.filename as fichier,
  g.source, g.modele, g.article, g.couleur, g.couleur_code, g.taille, g.manche,
  g."of", g.type, g.code_barre, g.quantite, g.genere_at, g.id
from public.label_generations g;
revoke all on table public.historique_etiquettes from anon, authenticated;

-- 3. Paramètres privés (code d'accès de l'export).
create table if not exists public.parametres_prives (
  cle text primary key,
  valeur text not null
);
alter table public.parametres_prives enable row level security;
revoke all on table public.parametres_prives from anon, authenticated;
insert into public.parametres_prives (cle, valeur) values ('code_export', 'CHANGEZ-MOI')
on conflict (cle) do nothing;

-- 4. Ajout des générations par la page.
create or replace function public.enregistrer_generations(lignes jsonb)
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  if lignes is null or jsonb_typeof(lignes) <> 'array' or jsonb_array_length(lignes) not between 1 and 500 then
    raise exception 'Lot invalide : tableau de 1 à 500 lignes attendu' using errcode = '22023';
  end if;

  insert into public.label_generations
    (site_id, site_label, local_id, code_barre, article, modele, couleur, couleur_code,
     taille, manche, "of", type, source, quantite, filename, genere_at)
  select
    left(l.site_id, 60), left(coalesce(l.site_label, ''), 120), left(l.local_id, 80), l.code_barre,
    left(coalesce(l.article, ''), 60), left(coalesce(l.modele, ''), 60), left(coalesce(l.couleur, ''), 60),
    left(coalesce(l.couleur_code, ''), 20), left(coalesce(l.taille, ''), 20), left(coalesce(l.manche, ''), 60),
    left(coalesce(l."of", ''), 30), left(coalesce(l.type, ''), 80), l.source, l.quantite,
    left(coalesce(l.filename, ''), 120),
    coalesce(l.genere_at, now())
  from jsonb_to_recordset(lignes) as l(
    site_id text, site_label text, local_id text, code_barre text, article text, modele text,
    couleur text, couleur_code text, taille text, manche text, "of" text, type text,
    source text, quantite integer, filename text, genere_at timestamptz)
  where l.code_barre ~ '^[0-9]{13}$'
    and l.source in ('FAB', 'SPE', 'EXT')
    and l.quantite between 1 and 999
    and coalesce(char_length(l.site_id), 0) between 1 and 60
    and coalesce(char_length(l.local_id), 0) between 1 and 80
  on conflict (site_id, local_id) do nothing;

  get diagnostics n = row_count;
  return n;
end;
$$;
revoke all on function public.enregistrer_generations(jsonb) from public;
grant execute on function public.enregistrer_generations(jsonb) to anon, authenticated;

-- 5. Export de l'historique (avec le code d'accès).
create or replace function public.exporter_generations(code_acces text, depuis date default null, jusqua date default null)
returns table (
  date_generation text, heure text, site text, fichier text, source text, modele text, article text,
  couleur text, couleur_code text, taille text, manche text, "of" text, type text, code_barre text, quantite integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if code_acces is null
     or code_acces is distinct from (select p.valeur from public.parametres_prives p where p.cle = 'code_export') then
    raise exception 'Code d''accès invalide' using errcode = '28000';
  end if;
  return query
    select h.date_generation, h.heure, h.site, h.fichier, h.source, h.modele, h.article,
           h.couleur, h.couleur_code, h.taille, h.manche, h."of", h.type, h.code_barre, h.quantite
    from public.historique_etiquettes h
    where (depuis is null or h.date_generation >= to_char(depuis, 'YYYY-MM-DD'))
      and (jusqua is null or h.date_generation <= to_char(jusqua, 'YYYY-MM-DD'))
    order by h.genere_at desc, h.id desc;
end;
$$;
revoke all on function public.exporter_generations(text, date, date) from public;
grant execute on function public.exporter_generations(text, date, date) to anon, authenticated;
