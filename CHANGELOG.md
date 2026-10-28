# Changelog

## 1.1.1+9 (2026-10-28)
- Výpis MZOB: přidána maximální rychlost vlaku podle vozu s nejnižší
  rychlostí v soupisu (u loženého vlaku rychlost ložený, jinak prázdný).
- Výpis MZOB: hmotnost vlaku se zaokrouhluje nahoru a zajišťovací síla dolů
  na celá čísla.
- Výpis MZOB: vozy s příznakem R1 (brzda neupotřebitelná) se do brzdící
  váhy započítávají hodnotou 0; po odebrání příznaku se jejich brzdící váha
  opět započítá.
- Výpis MZOB: zobrazení přepracováno do dvousloupcové tabulky a položky
  seřazeny v novém pořadí (Počet vozů, Hmotnost, Brzdící váha, Zajišťovací
  síla, Vozy s nekovovými špalíky, Vozy v režimu G, Vozy v režimu P, Počet
  ručních brzd, Délka soupravy, Počet náprav, Max. rychlost vlaku).
- Detail vozu i úprava záznamu v databázi vozů: po zapnutí přepínače Ruční
  brzda se kurzor automaticky přesune do pole pro její hodnotu.
- Import databáze vozů:
  - importují se i vozy bez jakýchkoliv údajů,
  - u existujících vozů se technické údaje přepíšou novějším záznamem
    (podle sloupce "Aktualizováno"), vyplněné údaje mají ale přednost před
    časem – prázdný záznam nikdy nepřepíše vyplněný a vyplněný vždy doplní
    prázdný,
  - vyplněné příznaky a poznámka se u existujících vozů nikdy nepřepisují,
    prázdné se z importu doplní,
  - souhrn importu nově ukazuje i počet aktualizovaných vozů.

## 1.1.0+8 (2026-09-19)
- Přidán výpočet MZOB (Mezinárodní zpráva o brzdění vlaku) přímo ze soupisu
  vozů – appka spočítá hmotnost, brzdící váhu, délku, počet náprav a další
  hodnoty potřebné pro sepsání zprávy, včetně dotazu na přestavovače brzdy
  v režimu G nad prahem 1200 t.
- Přidán interaktivní tutoriál appky (spotlight s bublinami nápovědy), který
  krok za krokem provede skenováním vozu, úpravou jeho údajů, soupisem,
  výpočtem MZOB i exportem do e-mailu. Zobrazí se automaticky při prvním
  spuštění a jde ho kdykoliv znovu spustit v Nastavení → O aplikaci.
- Přidána druhá varianta rozložení pro foldovací telefony typu Samsung
  Galaxy Z Fold: na rozevřeném displeji se Soupis vozů, Skenování, Domovská
  obrazovka, Nastavení, Databáze vozů i Adresář zobrazí v širším
  dvoupanelovém (nebo rozšířeném) rozložení místo jednoho úzkého sloupce.
  Na běžném telefonu (i na Foldu ve složeném stavu) zůstává layout beze
  změny.
- Oprava: na obrazovce skenování zůstával pod tlačítkem SKENOVAT tenký
  nevybarvený pruh v prostoru vyhrazeném pro systémovou gesto lištu.
- Po instalaci aktualizace appky se teď při prvním spuštění automaticky
  zobrazí dialog s přehledem novinek dané verze.

## 1.0.6+7 (2026-09-03)
- Nově: pokud je při skenování naskenován vůz, který je v databázi vozů
  veden se závadou (má zapsaný příznak nebo poznámku), zobrazí se dialog
  s citací příznaku a poznámky a třemi možnostmi – "Závada trvá" (jen
  potvrdí a pokračuje ve skenování), "Závada odstraněna" (smaže příznak
  i poznámku ze soupisu i z trvalé databáze vozů) a "Upravit" (rovnou
  otevře editaci příznaku/poznámky, po uložení se uživatel vrátí zpět na
  obrazovku skenování).
- Nově: v seznamu naskenovaných vozů (spodní část obrazovky skenování) se
  u čísel, která mají v databázi vozů vedený příznak nebo poznámku,
  zobrazuje oranžový vykřičník.

## 1.0.5+6 (2026-08-15)
- Oprava: při ručním zadání čísla vozu (nebo opravě nerozpoznaného/neplatného
  čísla) se do porovnání s databází vozů posílal naformátovaný text místo
  čistých číslic, takže se u ručně zadaných čísel neprojevila kontrola
  registru vozů (nenačetly se uložené technické údaje ani hláška o nalezení
  v databázi). Ruční zadání teď prochází stejnou kontrolou jako automaticky
  rozpoznané číslo.
- V Nastavení → O aplikaci přidán přehled changelogu.

## 1.0.4+5 (2026-08-12)
- Oprava: sekce "Poslední soupisy" na hlavní obrazovce se u zařízení
  s klasickou tlačítkovou navigací schovávala pod systémovou navigační
  lištu. Doplněno stejné SafeArea odsazení jako v 1.0.3.

## 1.0.3+4 (2026-08-12)
- Oprava: tlačítka ve spodní části obrazovky (scan i detail vozu) se u zařízení
  s klasickou tlačítkovou navigací schovávala pod systémovou navigační lištu.
  Přidáno SafeArea odsazení, které respektuje skutečnou výšku lišty.

## 1.0.2+3 (2026-08-11)
- Drobné doladění release procesu před prvním zveřejněním na Google Play.
- Ověřeno chování appky bez oprávnění k nahrávání zvuku po jeho odebrání v 1.0.1.

## 1.0.1+2 (2026-08-11)
- Vydání pro Google Play (versionCode navýšen kvůli opakovanému nahrání buildu).
- Odebráno nepoužité oprávnění `RECORD_AUDIO`.
- Zapnuta minifikace (R8) a shrink nepoužitých zdrojů v release buildu.

## 1.0.0+1
- První release verze.
