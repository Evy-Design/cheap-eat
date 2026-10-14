# Cheap-eat (website)

De Cheap-eat app als website voor je telefoon. Je logt in met een e-mailcode (Supabase) en je gegevens worden per account opgeslagen. Op een computer of tablet zie je een scherm met een QR-code om de app op je telefoon te openen. Voeg `?preview` aan het adres toe om toch op een computer te testen.

- `docs/` is de website (GitHub Pages publiceert deze map).
- `docs/config.js` bevat het Supabase-adres en de publieke (anon) sleutel.
- `supabase/schema.sql` is de database: één keer uitvoeren in Supabase.

De website wordt gebouwd vanuit `../prototype` met `python3 build.py --web`.

## Supabase instellen (eenmalig)

1. **Database**: Supabase → SQL Editor → plak de inhoud van `supabase/schema.sql` → Run.
2. **Code in plaats van link in de e-mail**: Authentication → Emails (Templates).
   Zet in de templates **Magic Link**, **Confirm signup** en **Change Email Address** de code in de tekst, bijvoorbeeld:

   ```html
   <h2>Je Cheap-eat code</h2>
   <p>Vul deze code in de app in:</p>
   <p style="font-size:28px;font-weight:bold;letter-spacing:4px">{{ .Token }}</p>
   <p>De code is 1 uur geldig. Heb je dit niet aangevraagd? Dan kun je deze mail negeren.</p>
   ```
3. **Code van 6 cijfers**: Authentication → Sign In / Providers → Email → *Email OTP Length* op **6** zetten.
4. **E-mailadres wijzigen met één code**: zet *Secure email change* uit (anders moet je ook je oude adres bevestigen).
5. **Adres van de site**: Authentication → URL Configuration → *Site URL* = het GitHub Pages-adres.

Let op: Supabase verstuurt op het gratis plan maar een paar e-mails per uur. Voor meer gebruikers koppel je een eigen e-mailprovider (bijvoorbeeld Resend) via Authentication → SMTP Settings.

## Wat nog niet echt is

- Huishouden koppelen is nog een demo: een uitnodiging wordt niet echt verstuurd.
- Prijzen zijn voorbeeldprijzen.
- Recepten van Picnic staan erin met naam en ingrediënten en een link naar picnic.app, maar zonder foto's.
