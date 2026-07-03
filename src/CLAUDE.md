# Kontekst projekta

Ovaj repozitorijum sadrži ABAP objekte za **SAP BTP ABAP Environment** (Steampunk, cloud ABAP stack), povezan preko **abapGit**.

Zadatak: prilagoditi ABAP inbound interfejs klase, originalno napisane za **SAP S/4HANA on-premise**, tako da rade u **ABAP for Cloud Development** jezičkoj verziji. Kostur klasa (imena metoda, potpisi, opšta struktura/logika) treba da ostane isti — menja se samo ono što nije dozvoljeno ili nije released za cloud razvoj.

Namespace: `/X1F/`

---

## Opšta pravila ABAP Cloud jezičke verzije

- Dozvoljene su samo klase i interfejsi (`CLAS`, `INTF`). Nema izvršnih programa (reports), nema dynpro/classic UI logike, nema `WRITE` naredbe.
- Sme se pristupati samo **released** repozitorijum objektima (klase, funkcije, CDS view-ovi, data elementi, domeni). Ako nisi siguran da li je neki standardni objekat released za cloud, **označi to u komentaru i pitaj**, ne pretpostavljaj.
- Nema direktnog `SELECT` nad standardnim SAP tabelama — koristi released CDS view entitete (ako postoje) ili API-je.
- Nema poziva na funkcijske module koji nisu released (`CALL FUNCTION` na klasične BAPI/FM iz on-prem koda treba proveriti pojedinačno).
- Nema dinamičkih poziva koji nisu dozvoljeni u restriktovanom jeziku (npr. `ASSIGN (dinamicko)`, `CALL METHOD (dinamicko)` su ograničeni — proveri svaki slučaj).
- `AUTHORITY-CHECK` i klasična autorizacija se u cloud okruženju drugačije modeluju (PFCG/Business katalozi, RAP access control) — ako original ima `AUTHORITY-CHECK`, označi to mesto komentarom umesto da ga automatski prevodiš.

---

## Zamene za tipične on-prem elemente

| On-prem (staro) | BTP ABAP Cloud (novo) |
|---|---|
| `sy-uname` | `cl_abap_context_info=>get_user_technical_name( )` |
| Data element `XUBNAME` | Data element `SYUNAME` |
| `sy-datum`, `sy-uzeit` | `cl_abap_context_info=>get_system_date( )` / `get_system_time( )` |
| Data element `GUID_16`, `GUID_32` | `SYSUUID_X16`, `SYSUUID_C32` |
| `CALL FUNCTION 'GUID_CREATE'` | `cl_system_uuid=>create_uuid_x16_static( )` (ili `create_uuid_c32_static( )`) |
| `GET TIME STAMP FIELD` (ostaje) | Dozvoljeno u cloud-u, koristi `TIMESTAMPL` tip |
| Klasična autorizacija (`AUTHORITY-CHECK`) | Označi komentarom, ne prevodi automatski |

Ovu tabelu dopunjavaj kako se pojavljuju novi slučajevi tokom migracije.

---

## Struktura fajlova (abapGit / Folder Logic: FULL)

Repozitorijum koristi abapGit **FULL** folder logiku. Fajlovi moraju pratiti tačnu konvenciju:

- Klasa: `#x1f#<ime_klase>.clas.abap` + `#x1f#<ime_klase>.clas.xml`
- Interfejs: `#x1f#<ime_interfejsa>.intf.abap` + `#x1f#<ime_interfejsa>.intf.xml`
- Tabela: `#x1f#<ime_tabele>.tabl.xml` (bez `.abap`, tabele nemaju izvorni kod)
- Paket: `package.devc.xml`
- Namespace `/X1F/` se u imenima fajlova piše kao `#x1f#`

**Ne izmišljaj drugačiju strukturu.** Ako nisi siguran kako izgleda XML deo za novi tip objekta, pogledaj postojeći primer u `src/` folderu (test objekti `cl_test_int`, `if_test_int`, `test_int`) i prati isti obrazac.

---

## Radni tok

1. Kod se izvlači iz `.docx` fajlova u ovom repozitorijumu (originalni S/4 on-prem inbound interfejsi).
2. Kostur (imena klasa/metoda/interfejsa, ulazno-izlazni parametri) treba da ostane prepoznatljiv u odnosu na original, osim ako je preimenovanje eksplicitno traženo.
3. Sve promene vezane za cloud-kompatibilnost jasno komentariši u kodu (npr. `" cloud adaptation: sy-uname replaced with cl_abap_context_info`).
4. Kad nisi siguran da li je neki API/tabela/funkcija released za cloud — nemoj nagađati. Napravi TODO komentar i navedi to eksplicitno u odgovoru.
5. Nakon generisanja, fajlovi se šalju na Git (`git add`, `commit`, `push`), zatim se u SAP ADT-u preko abapGit-a radi **Pull** u BTP sistem, gde se rade sintaksna provera, aktivacija i ATC (cloud varijanta).

---

## Napomena

Ovo je živi dokument — dopunjavaj tabelu zamena i pravila kako se u toku migracije budu otkrivali novi slučajevi nekompatibilnosti.
