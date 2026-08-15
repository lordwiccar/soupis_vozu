# Changelog

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
