# Changelog

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
