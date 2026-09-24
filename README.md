# PharmaLink 🏥💊

> **Your Health, Our Priority** — Full-stack healthcare delivery platform for Yaoundé, Cameroon.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | Node.js + Express |
| Database | PostgreSQL + Prisma ORM |
| Mobile | Flutter (Dart) |
| Real-time | Socket.io |
| AI Chatbot | Gemini AI API |
| Maps | Google Maps API |
| SMS/OTP | Africa's Talking |
| Push | Firebase Cloud Messaging |
| Payments | MTN Momo / Orange Money |

---

## Quick Start

### Backend
```bash
cd backend
npm install
cp .env.example .env   # fill in your values
createdb pharmalink
npx prisma migrate dev --name init
npx prisma generate
npm run db:seed
npm run dev            # runs on http://localhost:3000
```

### Flutter
```bash
cd flutter_app
flutter pub get
# Set baseUrl in lib/utils/constants.dart
flutter run
```

---

## 👥 All Test Accounts & Credentials

> **Standard Password for all accounts:** `password123`

### 👑 System Administrators (1)

| # | Name | Email | Phone | Status |
|---|------|-------|-------|--------|
| 1 | **PharmaLink Admin** | `admin@pharmalink.cm` | `+237600000001` | Active |

### 🩺 Doctors (51)

| # | Doctor Name | Email | Phone | Hospital / Affiliation | Specialty |
|---|-------------|-------|-------|------------------------|-----------|
| 1 | **Dr. Amadou** | `amadou@pharmalink.cm` | `+237600000002` | Yaoundé Central Hospital | General Practitioner |
| 2 | **Dr. Jean-Pierre Mbarga** | `doctor1@pharmalink.cm` | `+237620001000` | Yaoundé General Hospital | Cardiologist |
| 3 | **Dr. Sophie Ngo Bilong** | `doctor2@pharmalink.cm` | `+237620001001` | CHUY (Teaching Hospital Yaoundé) | Dermatologist |
| 4 | **Dr. Alain Fotso** | `doctor3@pharmalink.cm` | `+237620001002` | Douala General Hospital | Pediatrician |
| 5 | **Dr. Grace Ngum** | `doctor4@pharmalink.cm` | `+237620001003` | Laquintinie Hospital Douala | Neurologist |
| 6 | **Dr. Eric Tagne** | `doctor5@pharmalink.cm` | `+237620001004` | Bastos Medical Center | Orthopedist |
| 7 | **Dr. Clara Abena** | `doctor6@pharmalink.cm` | `+237620001005` | Military Hospital Yaoundé | Gynecologist |
| 8 | **Dr. David Nji** | `doctor7@pharmalink.cm` | `+237620001006` | Jamot Hospital Yaoundé | Ophthalmologist |
| 9 | **Dr. Fatima Oumarou** | `doctor8@pharmalink.cm` | `+237620001007` | Biyem-Assi District Hospital | Psychiatrist |
| 10 | **Dr. Christian Mewoli** | `doctor9@pharmalink.cm` | `+237620001008` | Cité Verte District Hospital | Endocrinologist |
| 11 | **Dr. Angeline Biyong** | `doctor10@pharmalink.cm` | `+237620001009` | Regional Hospital Bafoussam | Pulmonologist |
| 12 | **Dr. Paul Nkemdirim** | `doctor11@pharmalink.cm` | `+237620001010` | Regional Hospital Bamenda | Gastroenterologist |
| 13 | **Dr. Rose Akono** | `doctor12@pharmalink.cm` | `+237620001011` | Buea Regional Hospital | Urologist |
| 14 | **Dr. Samuel Beyala** | `doctor13@pharmalink.cm` | `+237620001012` | Limbe Regional Hospital | Rheumatologist |
| 15 | **Dr. Laure Ndoumbe** | `doctor14@pharmalink.cm` | `+237620001013` | Garoua General Hospital | Oncologist |
| 16 | **Dr. Henri Tita** | `doctor15@pharmalink.cm` | `+237620001014` | Yaoundé Central Hospital | General Practitioner |
| 17 | **Dr. Madeleine Effa** | `doctor16@pharmalink.cm` | `+237620001015` | Yaoundé General Hospital | ENT Specialist |
| 18 | **Dr. Joseph Ngala** | `doctor17@pharmalink.cm` | `+237620001016` | CHUY (Teaching Hospital Yaoundé) | Nephrologist |
| 19 | **Dr. Yvonne Kouam** | `doctor18@pharmalink.cm` | `+237620001017` | Douala General Hospital | Infectious Disease |
| 20 | **Dr. François Djoufack** | `doctor19@pharmalink.cm` | `+237620001018` | Laquintinie Hospital Douala | Hematologist |
| 21 | **Dr. Isabelle Meyo** | `doctor20@pharmalink.cm` | `+237620001019` | Bastos Medical Center | Radiologist |
| 22 | **Dr. Thomas Ebede** | `doctor21@pharmalink.cm` | `+237620001020` | Military Hospital Yaoundé | Cardiologist |
| 23 | **Dr. Brigitte Nsom** | `doctor22@pharmalink.cm` | `+237620001021` | Jamot Hospital Yaoundé | Dermatologist |
| 24 | **Dr. Achille Foba** | `doctor23@pharmalink.cm` | `+237620001022` | Biyem-Assi District Hospital | Pediatrician |
| 26 | **Dr. Maurice Tene** | `doctor25@pharmalink.cm` | `+237620001024` | Regional Hospital Bafoussam | Orthopedist |
| 27 | **Dr. Christine Mounjouopou** | `doctor26@pharmalink.cm` | `+237620001025` | Regional Hospital Bamenda | Gynecologist |
| 28 | **Dr. Patrick Njock** | `doctor27@pharmalink.cm` | `+237620001026` | Buea Regional Hospital | Ophthalmologist |
| 29 | **Dr. Solange Zambo** | `doctor28@pharmalink.cm` | `+237620001027` | Limbe Regional Hospital | Psychiatrist |
| 30 | **Dr. Victor Atangana** | `doctor29@pharmalink.cm` | `+237620001028` | Garoua General Hospital | Endocrinologist |
| 31 | **Dr. Chantal Mvondo** | `doctor30@pharmalink.cm` | `+237620001029` | Yaoundé Central Hospital | Pulmonologist |
| 32 | **Dr. Rodrigue Kenmogne** | `doctor31@pharmalink.cm` | `+237620001030` | Yaoundé General Hospital | Gastroenterologist |
| 33 | **Dr. Anne-Marie Bikié** | `doctor32@pharmalink.cm` | `+237620001031` | CHUY (Teaching Hospital Yaoundé) | Urologist |
| 34 | **Dr. Blaise Kana** | `doctor33@pharmalink.cm` | `+237620001032` | Douala General Hospital | Rheumatologist |
| 35 | **Dr. Josephine Wamba** | `doctor34@pharmalink.cm` | `+237620001033` | Laquintinie Hospital Douala | Oncologist |
| 36 | **Dr. Georges Tsafack** | `doctor35@pharmalink.cm` | `+237620001034` | Bastos Medical Center | General Practitioner |
| 37 | **Dr. Paulette Nnomo** | `doctor36@pharmalink.cm` | `+237620001035` | Military Hospital Yaoundé | ENT Specialist |
| 38 | **Dr. Thierry Fonkou** | `doctor37@pharmalink.cm` | `+237620001036` | Jamot Hospital Yaoundé | Nephrologist |
| 39 | **Dr. Veronique Mbassi** | `doctor38@pharmalink.cm` | `+237620001037` | Biyem-Assi District Hospital | Infectious Disease |
| 40 | **Dr. Fernand Etoundi** | `doctor39@pharmalink.cm` | `+237620001038` | Cité Verte District Hospital | Hematologist |
| 41 | **Dr. Nathalie Mbah** | `doctor40@pharmalink.cm` | `+237620001039` | Regional Hospital Bafoussam | Radiologist |
| 42 | **Dr. Lambert Owona** | `doctor41@pharmalink.cm` | `+237620001040` | Regional Hospital Bamenda | Cardiologist |
| 43 | **Dr. Genevieve Suh** | `doctor42@pharmalink.cm` | `+237620001041` | Buea Regional Hospital | Dermatologist |
| 44 | **Dr. Cyrille Abouem** | `doctor43@pharmalink.cm` | `+237620001042` | Limbe Regional Hospital | Pediatrician |
| 45 | **Dr. Therese Ndongo** | `doctor44@pharmalink.cm` | `+237620001043` | Garoua General Hospital | Neurologist |
| 46 | **Dr. Sylvain Kamdem** | `doctor45@pharmalink.cm` | `+237620001044` | Yaoundé Central Hospital | Orthopedist |
| 47 | **Dr. Marceline Nkoa** | `doctor46@pharmalink.cm` | `+237620001045` | Yaoundé General Hospital | Gynecologist |
| 48 | **Dr. Edouard Bekolo** | `doctor47@pharmalink.cm` | `+237620001046` | CHUY (Teaching Hospital Yaoundé) | Ophthalmologist |
| 49 | **Dr. Albertine Fouda** | `doctor48@pharmalink.cm` | `+237620001047` | Douala General Hospital | Psychiatrist |
| 50 | **Dr. Germain Tiako** | `doctor49@pharmalink.cm` | `+237620001048` | Laquintinie Hospital Douala | Endocrinologist |
| 51 | **Dr. Beatrice Onana** | `doctor50@pharmalink.cm` | `+237620001049` | Bastos Medical Center | Pulmonologist |

### 💊 Pharmacies & Pharmacists (51)

| # | Pharmacist Name | Email | Phone | Pharmacy Name | Location / Address |
|---|-----------------|-------|-------|---------------|--------------------|
| 1 | **Marie Centrale** | `pharmacie@centrale.cm` | `+237600000003` | **Pharmacie Centrale** | Avenue Kennedy, Bastos, Yaoundé |
| 2 | **Marie Centrale** | `pharmacist1@pharmalink.cm` | `+237620002000` | **Pharmacie Centrale** | Carrefour Warda, Yaoundé |
| 3 | **Jean Nations** | `pharmacist2@pharmalink.cm` | `+237620002001` | **Pharmacie des Nations** | Avenue Kennedy, Yaoundé |
| 4 | **Alice Lac** | `pharmacist3@pharmalink.cm` | `+237620002002` | **Pharmacie du Lac** | Quartier Lac, Yaoundé |
| 5 | **Robert Biyem** | `pharmacist4@pharmalink.cm` | `+237620002003` | **Pharmacie Biyem-Assi** | Biyem-Assi, Yaoundé |
| 6 | **Esther Paix** | `pharmacist5@pharmalink.cm` | `+237620002004` | **Pharmacie de la Paix** | Marché Central, Yaoundé |
| 7 | **Michel Melen** | `pharmacist6@pharmalink.cm` | `+237620002005` | **Pharmacie Melen** | Quartier Melen, Yaoundé |
| 8 | **Celine Bastos** | `pharmacist7@pharmalink.cm` | `+237620002006` | **Pharmacie de Bastos** | Bastos, Yaoundé |
| 9 | **Pierre Barbara** | `pharmacist8@pharmalink.cm` | `+237620002007` | **Pharmacie Santa Barbara** | Santa Barbara, Douala |
| 10 | **Josephine Stade** | `pharmacist9@pharmalink.cm` | `+237620002008` | **Pharmacie du Stade** | Stade Omnisports, Yaoundé |
| 11 | **Andre Nouvelle** | `pharmacist10@pharmalink.cm` | `+237620002009` | **Pharmacie Nouvelle Génération** | Ngousso, Yaoundé |
| 12 | **Pauline Essos** | `pharmacist11@pharmalink.cm` | `+237620002010` | **Pharmacie d'Essos** | Essos, Yaoundé |
| 13 | **Samuel Mokolo** | `pharmacist12@pharmalink.cm` | `+237620002011` | **Pharmacie du Marché Mokolo** | Marché Mokolo, Yaoundé |
| 14 | **Delphine Emana** | `pharmacist13@pharmalink.cm` | `+237620002012` | **Pharmacie d'Emana** | Emana, Yaoundé |
| 15 | **Lucas Nlongkak** | `pharmacist14@pharmalink.cm` | `+237620002013` | **Pharmacie de Nlongkak** | Nlongkak, Yaoundé |
| 16 | **Blandine Kondengui** | `pharmacist15@pharmalink.cm` | `+237620002014` | **Pharmacie de Kondengui** | Kondengui, Yaoundé |
| 17 | **Guy Simbock** | `pharmacist16@pharmalink.cm` | `+237620002015` | **Pharmacie de Simbock** | Simbock, Yaoundé |
| 18 | **Nadine Ahala** | `pharmacist17@pharmalink.cm` | `+237620002016` | **Pharmacie de l'Aéroport Ahala** | Ahala, Yaoundé |
| 19 | **Boris Mvan** | `pharmacist18@pharmalink.cm` | `+237620002017` | **Pharmacie de Mvan** | Mvan, Yaoundé |
| 20 | **Solange Obobogo** | `pharmacist19@pharmalink.cm` | `+237620002018` | **Pharmacie d'Obobogo** | Obobogo, Yaoundé |
| 21 | **Fabrice Tsinga** | `pharmacist20@pharmalink.cm` | `+237620002019` | **Pharmacie de Tsinga** | Tsinga, Yaoundé |
| 22 | **Aline Madagscar** | `pharmacist21@pharmalink.cm` | `+237620002020` | **Pharmacie de Madagascar** | Madagascar, Yaoundé |
| 23 | **Gaston Messa** | `pharmacist22@pharmalink.cm` | `+237620002021` | **Pharmacie de la Messa** | Camp SIC Messa, Yaoundé |
| 24 | **Clarisse Nsam** | `pharmacist23@pharmalink.cm` | `+237620002022` | **Pharmacie de Nsam** | Nsam, Yaoundé |
| 25 | **Hervé Odza** | `pharmacist24@pharmalink.cm` | `+237620002023` | **Pharmacie d'Odza** | Odza, Yaoundé |
| 26 | **Leontine Biteng** | `pharmacist25@pharmalink.cm` | `+237620002024` | **Pharmacie de Biteng** | Biteng, Yaoundé |
| 27 | **Albert Bonanjo** | `pharmacist26@pharmalink.cm` | `+237620002025` | **Pharmacie de Bonanjo** | Bonanjo, Douala |
| 28 | **Carine Akwa** | `pharmacist27@pharmalink.cm` | `+237620002026` | **Pharmacie de l'Étoile Akwa** | Boulevard de la Liberté Akwa, Douala |
| 29 | **Serge Deido** | `pharmacist28@pharmalink.cm` | `+237620002027` | **Pharmacie de Deido** | Rue Deido, Douala |
| 30 | **Monique Bali** | `pharmacist29@pharmalink.cm` | `+237620002028` | **Pharmacie de Bali** | Bali, Douala |
| 31 | **Yves Bonapriso** | `pharmacist30@pharmalink.cm` | `+237620002029` | **Pharmacie de Bonapriso** | Bonapriso, Douala |
| 32 | **Tatiana Makepe** | `pharmacist31@pharmalink.cm` | `+237620002030` | **Pharmacie des Palmiers Makepe** | Makepe, Douala |
| 33 | **Arnaud Logpom** | `pharmacist32@pharmalink.cm` | `+237620002031` | **Pharmacie de Logpom** | Logpom, Douala |
| 34 | **Chantal Kotto** | `pharmacist33@pharmalink.cm` | `+237620002032` | **Pharmacie de Kotto** | Kotto, Douala |
| 35 | **Emile Ndogpassi** | `pharmacist34@pharmalink.cm` | `+237620002033` | **Pharmacie de Ndogpassi** | Ndogpassi, Douala |
| 36 | **Florence PK14** | `pharmacist35@pharmalink.cm` | `+237620002034` | **Pharmacie de l'Espoir PK14** | PK14, Douala |
| 37 | **Olivier Nylon** | `pharmacist36@pharmalink.cm` | `+237620002035` | **Pharmacie Populaire Nylon** | Nylon, Douala |
| 38 | **Gisèle Bépanda** | `pharmacist37@pharmalink.cm` | `+237620002036` | **Pharmacie de Bépanda** | Bépanda, Douala |
| 39 | **Daniel New-Bell** | `pharmacist38@pharmalink.cm` | `+237620002037` | **Pharmacie du Soleil New-Bell** | New-Bell, Douala |
| 40 | **Julienne Bonabéri** | `pharmacist39@pharmalink.cm` | `+237620002038` | **Pharmacie du Pont Bonabéri** | Ancien Pont Bonabéri, Douala |
| 41 | **Marc Cité-Sic** | `pharmacist40@pharmalink.cm` | `+237620002039` | **Pharmacie de la Cité-Sic** | Cité-Sic, Douala |
| 42 | **Brigitte Bafoussam** | `pharmacist41@pharmalink.cm` | `+237620002040` | **Pharmacie de l'Ouest Bafoussam** | Centre-ville, Bafoussam |
| 43 | **Rodrigue Dschang** | `pharmacist42@pharmalink.cm` | `+237620002041` | **Pharmacie Menoua Dschang** | Avenue Principale, Dschang |
| 44 | **Vanessa Bamenda** | `pharmacist43@pharmalink.cm` | `+237620002042` | **Pharmacie Highland Bamenda** | Commercial Avenue, Bamenda |
| 45 | **Patrick Kumba** | `pharmacist44@pharmalink.cm` | `+237620002043` | **Pharmacie Meme Kumba** | Main Market, Kumba |
| 46 | **Sandrine Limbe** | `pharmacist45@pharmalink.cm` | `+237620002044` | **Pharmacie Océane Limbe** | Down Beach, Limbe |
| 47 | **Alain Buea** | `pharmacist46@pharmalink.cm` | `+237620002045` | **Pharmacie du Mont Fako Buea** | Molyko, Buea |
| 48 | **Colette Garoua** | `pharmacist47@pharmalink.cm` | `+237620002046` | **Pharmacie de la Bénoué Garoua** | Boulevard Lamido, Garoua |
| 49 | **Hamidou Maroua** | `pharmacist48@pharmalink.cm` | `+237620002047` | **Pharmacie du Sahel Maroua** | Carrefour Para, Maroua |
| 50 | **Fadimatou Ngaoundere** | `pharmacist49@pharmalink.cm` | `+237620002048` | **Pharmacie du Château Ngaoundéré** | Grand Marché, Ngaoundéré |
| 51 | **Ibrahim Bertoua** | `pharmacist50@pharmalink.cm` | `+237620002049` | **Pharmacie du Soleil Levant Bertoua** | Avenue Royale, Bertoua |

### 🧑‍⚕️ Patients (53)

| # | Patient Name | Email | Phone | Blood Group | Address |
|---|--------------|-------|-------|-------------|---------|
| 1 | **Marie Nguema** | `marie@patient.cm` | `+237600000004` | `A+` | Quartier Bastos, Yaoundé |
| 2 | **New Patient** | `new_patient_1789567686867@patient.cm` | `+237699871890` | `O+` | Yaoundé |
| 3 | **Walker Jr** | `walkerjr@gmail.com` | `687042748` | `O+` | Yaoundé |
| 4 | **Marie Nguema** | `patient1@pharmalink.cm` | `+237620003000` | `B+` | Biyem-Assi, Yaoundé |
| 5 | **Jean Tagne** | `patient2@pharmalink.cm` | `+237620003001` | `B+` | Mokolo, Yaoundé |
| 6 | **Alice Bello** | `patient3@pharmalink.cm` | `+237620003002` | `B+` | Bonamoussadi, Douala |
| 7 | **Robert Kamga** | `patient4@pharmalink.cm` | `+237620003003` | `AB+` | Mokolo, Yaoundé |
| 8 | **Esther Fonkou** | `patient5@pharmalink.cm` | `+237620003004` | `B+` | Akwa, Douala |
| 9 | **Michel Nkoa** | `patient6@pharmalink.cm` | `+237620003005` | `AB-` | Bastos, Yaoundé |
| 10 | **Celine Mbarga** | `patient7@pharmalink.cm` | `+237620003006` | `O-` | Melen, Yaoundé |
| 11 | **Pierre Abena** | `patient8@pharmalink.cm` | `+237620003007` | `B+` | Akwa, Douala |
| 12 | **Josephine Bilong** | `patient9@pharmalink.cm` | `+237620003008` | `A+` | Deido, Douala |
| 13 | **Andre Meyo** | `patient10@pharmalink.cm` | `+237620003009` | `B+` | Melen, Yaoundé |
| 14 | **Cecile Mewoli** | `patient11@pharmalink.cm` | `+237620003010` | `O-` | Omnisports, Yaoundé |
| 15 | **Francois Fouda** | `patient12@pharmalink.cm` | `+237620003011` | `O+` | Omnisports, Yaoundé |
| 16 | **Therese Ngum** | `patient13@pharmalink.cm` | `+237620003012` | `A+` | Deido, Douala |
| 17 | **Emile Tita** | `patient14@pharmalink.cm` | `+237620003013` | `A+` | Ngousso, Yaoundé |
| 18 | **Veronique Beyala** | `patient15@pharmalink.cm` | `+237620003014` | `B-` | Omnisports, Yaoundé |
| 19 | **Gustave Ndoumbe** | `patient16@pharmalink.cm` | `+237620003015` | `O+` | Deido, Douala |
| 20 | **Yvette Effa** | `patient17@pharmalink.cm` | `+237620003016` | `AB-` | Ngousso, Yaoundé |
| 21 | **Leonard Mvondo** | `patient18@pharmalink.cm` | `+237620003017` | `B+` | Essos, Yaoundé |
| 22 | **Suzanne Atangana** | `patient19@pharmalink.cm` | `+237620003018` | `A-` | Emana, Yaoundé |
| 23 | **Claude Mbah** | `patient20@pharmalink.cm` | `+237620003019` | `AB+` | Omnisports, Yaoundé |
| 24 | **Delphine Ngono** | `patient21@pharmalink.cm` | `+237620003020` | `A-` | Essos, Yaoundé |
| 25 | **Ernest Nji** | `patient22@pharmalink.cm` | `+237620003021` | `O-` | Biyem-Assi, Yaoundé |
| 26 | **Mathilde Kouam** | `patient23@pharmalink.cm` | `+237620003022` | `O-` | Bonamoussadi, Douala |
| 27 | **Innocent Oumarou** | `patient24@pharmalink.cm` | `+237620003023` | `B+` | Bonamoussadi, Douala |
| 28 | **Pascaline Biyong** | `patient25@pharmalink.cm` | `+237620003024` | `B+` | Bastos, Yaoundé |
| 29 | **Aurelien Zambo** | `patient26@pharmalink.cm` | `+237620003025` | `B+` | Omnisports, Yaoundé |
| 30 | **Dorothee Ebede** | `patient27@pharmalink.cm` | `+237620003026` | `A+` | Bonamoussadi, Douala |
| 31 | **Simon Nsom** | `patient28@pharmalink.cm` | `+237620003027` | `A+` | Akwa, Douala |
| 32 | **Felicite Ngala** | `patient29@pharmalink.cm` | `+237620003028` | `AB+` | Melen, Yaoundé |
| 33 | **Armand Foba** | `patient30@pharmalink.cm` | `+237620003029` | `O+` | Biyem-Assi, Yaoundé |
| 34 | **Nathalie Tene** | `patient31@pharmalink.cm` | `+237620003030` | `B+` | Akwa, Douala |
| 35 | **Bertrand Djoufack** | `patient32@pharmalink.cm` | `+237620003031` | `B-` | Akwa, Douala |
| 36 | **Monique Akono** | `patient33@pharmalink.cm` | `+237620003032` | `O+` | Deido, Douala |
| 37 | **Hilaire Bekolo** | `patient34@pharmalink.cm` | `+237620003033` | `B-` | Omnisports, Yaoundé |
| 38 | **Constance Kenmogne** | `patient35@pharmalink.cm` | `+237620003034` | `AB+` | Omnisports, Yaoundé |
| 39 | **Patrice Wamba** | `patient36@pharmalink.cm` | `+237620003035` | `AB-` | Mokolo, Yaoundé |
| 40 | **Georgette Tsafack** | `patient37@pharmalink.cm` | `+237620003036` | `O-` | Bastos, Yaoundé |
| 41 | **Rene Njock** | `patient38@pharmalink.cm` | `+237620003037` | `B-` | Omnisports, Yaoundé |
| 42 | **Adrienne Onana** | `patient39@pharmalink.cm` | `+237620003038` | `B-` | Bastos, Yaoundé |
| 43 | **Herve Etoundi** | `patient40@pharmalink.cm` | `+237620003039` | `B-` | Akwa, Douala |
| 44 | **Brigitte Owona** | `patient41@pharmalink.cm` | `+237620003040` | `A-` | Bastos, Yaoundé |
| 45 | **Victor Suh** | `patient42@pharmalink.cm` | `+237620003041` | `A-` | Mokolo, Yaoundé |
| 46 | **Martine Mbassi** | `patient43@pharmalink.cm` | `+237620003042` | `B-` | Biyem-Assi, Yaoundé |
| 47 | **Ange Abouem** | `patient44@pharmalink.cm` | `+237620003043` | `AB-` | Akwa, Douala |
| 48 | **Serge Ndongo** | `patient45@pharmalink.cm` | `+237620003044` | `B+` | Biyem-Assi, Yaoundé |
| 49 | **Colette Kamdem** | `patient46@pharmalink.cm` | `+237620003045` | `AB+` | Akwa, Douala |
| 50 | **Denis Tiako** | `patient47@pharmalink.cm` | `+237620003046` | `O+` | Melen, Yaoundé |
| 51 | **Christine Fouda** | `patient48@pharmalink.cm` | `+237620003047` | `B+` | Bastos, Yaoundé |
| 52 | **Felix Kana** | `patient49@pharmalink.cm` | `+237620003048` | `AB-` | Emana, Yaoundé |
| 53 | **Honorine Bikié** | `patient50@pharmalink.cm` | `+237620003049` | `B+` | Emana, Yaoundé |

### 🛵 Delivery Drivers (51)

| # | Driver Name | Email | Phone | Vehicle | Status |
|---|-------------|-------|-------|---------|--------|
| 1 | **Pierre Mbarga** | `pierre@driver.cm` | `+237600000005` | Motorbike CG 125 - CE 7843 A | ⚪ Standby |
| 2 | **Pierre Mbarga** | `driver1@pharmalink.cm` | `+237620004000` | Car Kia Picanto - Grey | ⚪ Standby |
| 3 | **Joseph Tagne** | `driver2@pharmalink.cm` | `+237620004001` | Car Toyota Vitz - White | ⚪ Standby |
| 4 | **Emmanuel Fonkou** | `driver3@pharmalink.cm` | `+237620004002` | Motorcycle Suzuki - Black | ⚪ Standby |
| 5 | **Pascal Kamga** | `driver4@pharmalink.cm` | `+237620004003` | Car Hyundai i10 - Silver | ⚪ Standby |
| 6 | **Sylvain Ngum** | `driver5@pharmalink.cm` | `+237620004004` | Motorcycle Suzuki - Black | ⚪ Standby |
| 7 | **Bruno Abena** | `driver6@pharmalink.cm` | `+237620004005` | Motorcycle Hero - Red | ⚪ Standby |
| 8 | **Gilles Bilong** | `driver7@pharmalink.cm` | `+237620004006` | Motorcycle Bajaj - Green | ⚪ Standby |
| 9 | **Remi Meyo** | `driver8@pharmalink.cm` | `+237620004007` | Car Kia Picanto - Grey | ⚪ Standby |
| 10 | **Didier Mewoli** | `driver9@pharmalink.cm` | `+237620004008` | Motorcycle Suzuki - Black | ⚪ Standby |
| 11 | **Arnaud Fouda** | `driver10@pharmalink.cm` | `+237620004009` | Car Hyundai i10 - Silver | ⚪ Standby |
| 12 | **Cedric Ndoumbe** | `driver11@pharmalink.cm` | `+237620004010` | Motorcycle Bajaj - Green | ⚪ Standby |
| 13 | **Tony Effa** | `driver12@pharmalink.cm` | `+237620004011` | Motorcycle Bajaj - Green | ⚪ Standby |
| 14 | **Lionel Mvondo** | `driver13@pharmalink.cm` | `+237620004012` | Motorcycle TVS - Orange | ⚪ Standby |
| 15 | **Stephane Atangana** | `driver14@pharmalink.cm` | `+237620004013` | Motorcycle Honda CB500 - Red | ⚪ Standby |
| 16 | **Kevin Mbah** | `driver15@pharmalink.cm` | `+237620004014` | Car Kia Picanto - Grey | ⚪ Standby |
| 17 | **Roland Ngono** | `driver16@pharmalink.cm` | `+237620004015` | Motorcycle Hero - Red | ⚪ Standby |
| 18 | **Faustin Nji** | `driver17@pharmalink.cm` | `+237620004016` | Car Kia Picanto - Grey | ⚪ Standby |
| 19 | **Gerard Kouam** | `driver18@pharmalink.cm` | `+237620004017` | Bicycle - Yellow | ⚪ Standby |
| 20 | **Constant Oumarou** | `driver19@pharmalink.cm` | `+237620004018` | Motorcycle TVS - Orange | ⚪ Standby |
| 21 | **Albert Biyong** | `driver20@pharmalink.cm` | `+237620004019` | Motorcycle Honda CB500 - Red | ⚪ Standby |
| 22 | **Florent Zambo** | `driver21@pharmalink.cm` | `+237620004020` | Motorcycle Bajaj - Green | ⚪ Standby |
| 23 | **Desire Ebede** | `driver22@pharmalink.cm` | `+237620004021` | Car Kia Picanto - Grey | ⚪ Standby |
| 24 | **Landry Nsom** | `driver23@pharmalink.cm` | `+237620004022` | Car Toyota Vitz - White | ⚪ Standby |
| 25 | **Serge Ngala** | `driver24@pharmalink.cm` | `+237620004023` | Motorcycle Suzuki - Black | ⚪ Standby |
| 26 | **Aubin Foba** | `driver25@pharmalink.cm` | `+237620004024` | Motorcycle Hero - Red | ⚪ Standby |
| 27 | **Blaise Tene** | `driver26@pharmalink.cm` | `+237620004025` | Motorcycle Honda CB500 - Red | ⚪ Standby |
| 28 | **Calvin Djoufack** | `driver27@pharmalink.cm` | `+237620004026` | Bicycle - Yellow | ⚪ Standby |
| 29 | **Daniel Akono** | `driver28@pharmalink.cm` | `+237620004027` | Car Hyundai i10 - Silver | ⚪ Standby |
| 30 | **Edgard Bekolo** | `driver29@pharmalink.cm` | `+237620004028` | Motorcycle Honda CB500 - Red | ⚪ Standby |
| 31 | **Firmin Kenmogne** | `driver30@pharmalink.cm` | `+237620004029` | Motorcycle Yamaha FZ - Blue | ⚪ Standby |
| 32 | **Gatien Wamba** | `driver31@pharmalink.cm` | `+237620004030` | Motorcycle Yamaha FZ - Blue | ⚪ Standby |
| 33 | **Hermine Tsafack** | `driver32@pharmalink.cm` | `+237620004031` | Motorcycle Honda CB500 - Red | ⚪ Standby |
| 34 | **Igor Njock** | `driver33@pharmalink.cm` | `+237620004032` | Car Hyundai i10 - Silver | ⚪ Standby |
| 35 | **Junior Onana** | `driver34@pharmalink.cm` | `+237620004033` | Motorcycle TVS - Orange | ⚪ Standby |
| 36 | **Klaus Etoundi** | `driver35@pharmalink.cm` | `+237620004034` | Motorcycle TVS - Orange | ⚪ Standby |
| 37 | **Leopold Owona** | `driver36@pharmalink.cm` | `+237620004035` | Motorcycle Bajaj - Green | ⚪ Standby |
| 38 | **Marcel Suh** | `driver37@pharmalink.cm` | `+237620004036` | Car Toyota Vitz - White | ⚪ Standby |
| 39 | **Nicolas Mbassi** | `driver38@pharmalink.cm` | `+237620004037` | Motorcycle Bajaj - Green | ⚪ Standby |
| 40 | **Oscar Abouem** | `driver39@pharmalink.cm` | `+237620004038` | Bicycle - Yellow | ⚪ Standby |
| 41 | **Philippe Ndongo** | `driver40@pharmalink.cm` | `+237620004039` | Motorcycle TVS - Orange | ⚪ Standby |
| 42 | **Quentin Kamdem** | `driver41@pharmalink.cm` | `+237620004040` | Motorcycle Suzuki - Black | ⚪ Standby |
| 43 | **Raymond Tiako** | `driver42@pharmalink.cm` | `+237620004041` | Motorcycle Bajaj - Green | ⚪ Standby |
| 44 | **Stephane Fouda** | `driver43@pharmalink.cm` | `+237620004042` | Motorcycle Bajaj - Green | ⚪ Standby |
| 45 | **Thierry Kana** | `driver44@pharmalink.cm` | `+237620004043` | Car Hyundai i10 - Silver | ⚪ Standby |
| 46 | **Ulrich Bikié** | `driver45@pharmalink.cm` | `+237620004044` | Motorcycle Honda CB500 - Red | ⚪ Standby |
| 47 | **Valentin Bikam** | `driver46@pharmalink.cm` | `+237620004045` | Car Toyota Vitz - White | ⚪ Standby |
| 48 | **William Ndoumou** | `driver47@pharmalink.cm` | `+237620004046` | Motorcycle Suzuki - Black | ⚪ Standby |
| 49 | **Xavier Ondobo** | `driver48@pharmalink.cm` | `+237620004047` | Car Kia Picanto - Grey | ⚪ Standby |
| 50 | **Yannick Bwele** | `driver49@pharmalink.cm` | `+237620004048` | Motorcycle Bajaj - Green | ⚪ Standby |
| 51 | **Zacharie Ebanga** | `driver50@pharmalink.cm` | `+237620004049` | Motorcycle Suzuki - Black | ⚪ Standby |

---

## 🏛️ Predefined Cameroon Regulatory Registries (ONMC & ONPC)

PharmaLink includes official preloaded national registry datasets for Yaoundé to enable **instant automatic cross-checking**, **1-click auto-verification**, and **auto-learning** during doctor and pharmacist onboarding.

### 🩺 Official ONMC Doctor Registry (*Ordre National des Médecins du Cameroun*)

| License Number | Doctor Full Name | Specialty | Hospital / Practice | Region | Status |
|---|---|---|---|---|---|
| `ONMC/2023/8492` | **Dr. Marie Nguema** | Cardiology | Hôpital Central de Yaoundé | Centre (Yaoundé) | Active |
| `ONMC/2021/5120` | **Dr. Paul Biya Essomba** | General Practitioner | Centre Hospitalier Universitaire (CHU) Yaoundé | Centre (Yaoundé) | Active |
| `ONMC/2020/3891` | **Dr. Jeanne Manga** | Pediatrics | Fondation Chantal Biya, Yaoundé | Centre (Yaoundé) | Active |
| `ONMC/2019/1204` | **Dr. Alain Fofana** | Dermatology | Hôpital Général de Yaoundé | Centre (Yaoundé) | Active |
| `ONMC/2022/6740` | **Dr. Samuel Eto'o Mbida** | Internal Medicine | Clinique Bastos, Yaoundé | Centre (Yaoundé) | Active |
| `ONMC/2024/9021` | **Dr. Walker Jr** | General Medicine & Surgery | Hôpital Central de Yaoundé | Centre (Yaoundé) | Active |

### 💊 Official ONPC Pharmacy Registry (*Ordre National des Pharmaciens du Cameroun*)

| License Number | Pharmacy Name | Titular Pharmacist | Physical Address | Category | Region | Status |
|---|---|---|---|---|---|---|
| `ONPC/PHARM/2022/104` | **Pharmacie du Centre** | Dr. Pharm. Estelle Ndom | Rue Joseph Essono Balla, Bastos, Yaoundé | Officine | Centre (Yaoundé) | Active |
| `ONPC/PHARM/2020/088` | **Pharmacie du Soleil** | Dr. Pharm. Christian Mballa | Carrefour Mvan, Yaoundé | Officine | Centre (Yaoundé) | Active |
| `ONPC/PHARM/2018/045` | **Pharmacie de l'Avenue** | Dr. Pharm. Patrick Ndongo | Avenue Kennedy, Centre-Ville, Yaoundé | Officine | Centre (Yaoundé) | Active |
| `ONPC/PHARM/2023/162` | **Pharmacie Bastos Santé** | Dr. Pharm. Sandrine Abena | Boulevard de l'URSS, Bastos, Yaoundé | Officine | Centre (Yaoundé) | Active |
| `ONPC/PHARM/2021/095` | **Pharmacie de Melen** | Dr. Pharm. Yves Kamga | Carrefour Emia, Melen, Yaoundé | Officine | Centre (Yaoundé) | Active |

> 💡 **How Automatic Verification & Registry Learning Work**:
> 1. **Instant Match**: Registering with any of the numbers above displays a 🟢 `✓ Auto-Match Found in Official Registry` banner in the Admin Dashboard.
> 2. **Auto-Learning for New Doctors/Pharmacies**: If a newly graduated doctor or new pharmacy registers with a valid document before the table is updated, the Admin can approve them with **1-click Auto-Save**, which automatically inserts them into the internal registry table for all future verifications.
> 3. **Admin Registry Manager**: Admins can search, view, and add new ONMC/ONPC entries anytime via **Admin Dashboard > ONMC / ONPC Registry**.

---

## Screens — COMPLETE ✅

### Auth
- Splash Screen (auto-navigate by role)
- Login
- Register (role tabs)
- OTP Verification
- Forgot Password + Reset Password

### Patient
- Home Dashboard
- Search Medication (list + popular chips)
- Pharmacy Detail
- Order Options (delivery vs pickup modal)
- Payment (Momo, Orange Money, Card, Cash)
- My Orders (tabs: active / completed / cancelled)
- Delivery Tracking (Google Maps + Socket.io live)
- OTP Confirm
- Signature Capture
- Delivery Success
- Pickup Success (with pickup code display)
- Book Appointment
- My Prescriptions
- Medical History
- Reminders (add/toggle/delete)
- AI Chatbot (Gemini)
- Telemedicine (chat + simulated video call)
- Complaints (submit + view)

### Doctor
- Home Dashboard
- My Patients
- Patient Detail (overview, prescriptions, history tabs)
- Doctor Appointments (confirm/cancel)
- Write Prescription (multi-medication)
- Set Availability (weekly schedule)
- Upload Medical License

### Pharmacist
- Home Dashboard
- Inventory (add/edit/delete, low stock alerts)
- Manage Orders (confirm/ready)
- Prescription Management (pending/fulfilled tabs)
- Sales Analytics (total + top products)
- Upload Pharmacy License

### Driver
- Home Dashboard (online/offline toggle)
- Delivery List (pending/ongoing/completed)
- Route Map (Google Maps + step-by-step: pickup → deliver)
- Delivery Photo Proof
- Earnings Screen
- Upload Documents (license + national ID)

### Admin
- Home Dashboard (stats: users, orders, deliveries, revenue)
- Manage Users (activate/deactivate)
- Verify Licenses (approve/reject doctors, pharmacists, drivers)
- Manage Complaints (respond + resolve)
- All Transactions

### Shared
- Notifications
- Profile (view/edit + logout)
- Payment Screen
- Transaction History
- In-App Chat (patient ↔ driver/doctor)

---

## API Endpoints

### Auth
```
POST /api/auth/register
POST /api/auth/login
POST /api/auth/refresh-token
POST /api/auth/send-otp
POST /api/auth/verify-otp
POST /api/auth/forgot-password
POST /api/auth/reset-password
POST /api/auth/change-password     (authenticated)
```

### Push
```
POST /api/push/fcm-token           (register FCM token)
```

### Patient
```
GET  /api/medications/search?q=paracetamol&lat=3.84&lng=11.50
GET  /api/pharmacies/nearest?lat=&lng=
GET  /api/pharmacies/:id
POST /api/orders
GET  /api/orders
GET  /api/orders/:id
POST /api/orders/:id/otp/generate
POST /api/orders/:id/otp/verify
POST /api/orders/:id/signature
POST /api/appointments
GET  /api/appointments
GET  /api/prescriptions
POST /api/reminders
GET  /api/reminders
POST /api/chat/gemini
GET  /api/chat/messages/:userId
POST /api/chat/messages
POST /api/complaints
GET  /api/transactions/mine
GET  /api/notifications
```

### Doctor
```
GET  /api/doctor/patients
GET  /api/doctor/patients/:id
POST /api/prescriptions
PATCH /api/appointments/:id/status
PUT  /api/doctor/availability
POST /api/doctor/license
```

### Pharmacist
```
GET  /api/pharmacist/inventory
POST /api/pharmacist/inventory
PUT  /api/pharmacist/inventory/:id
DELETE /api/pharmacist/inventory/:id
GET  /api/pharmacist/orders
PATCH /api/pharmacist/orders/:id/confirm
PATCH /api/pharmacist/orders/:id/ready
PATCH /api/prescriptions/:id/fulfill
GET  /api/pharmacist/analytics
POST /api/pharmacist/license
```

### Driver
```
GET  /api/driver/deliveries
PATCH /api/driver/deliveries/:id/accept
PATCH /api/driver/deliveries/:id/pickup
PATCH /api/driver/deliveries/:id/deliver
PUT  /api/driver/location
PATCH /api/driver/status
GET  /api/driver/earnings
POST /api/driver/documents
```

### Admin
```
GET  /api/admin/users
PATCH /api/admin/users/:id/activate
PATCH /api/admin/users/:id/deactivate
GET  /api/admin/licenses/pending
PATCH /api/admin/licenses/:id/review
GET  /api/admin/complaints
PATCH /api/admin/complaints/:id/respond
GET  /api/admin/stats
GET  /api/admin/transactions
```

---

## Socket.io Events

| Event | Direction | Payload |
|-------|-----------|---------|
| `join_room` | Client→Server | `userId` |
| `join_order` | Client→Server | `orderId` |
| `driver:location_update` | Driver→Server | `{ orderId, lat, lng }` |
| `driver:location` | Server→Patient | `{ lat, lng, orderId }` |
| `order:status_change` | Server→Patient | `{ orderId, status }` |
| `notification:new` | Server→User | `{ title, body, type }` |
| `chat:message` | Client↔Server | `{ senderId, receiverId, content }` |

---

## Environment Variables

```env
DATABASE_URL=postgresql://...
JWT_SECRET=
JWT_REFRESH_SECRET=
GOOGLE_MAPS_API_KEY=
GEMINI_API_KEY=
SMS_PROVIDER=africas_talking
SMS_API_KEY=
SMS_USERNAME=
FIREBASE_PROJECT_ID=
FIREBASE_SERVER_KEY=
PAYMENT_MOMO_API_KEY=
PAYMENT_ORANGE_API_KEY=
PORT=3000
NODE_ENV=development
```

---

## What Remains (optional enhancements)

- [ ] Real MTN Momo / Orange Money SDK integration (currently simulated)
- [ ] Real WebRTC video call in telemedicine (currently UI only)
- [ ] Google Maps directions polyline from API (currently straight line)
- [ ] Email notifications (Nodemailer)
- [ ] Rate limiting per endpoint
- [ ] Unit + integration tests (Jest)
- [ ] Docker + docker-compose setup
- [ ] CI/CD pipeline
