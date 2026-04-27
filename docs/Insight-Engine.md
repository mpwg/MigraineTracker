# Insight Engine

Die Insight Engine berechnet lokale Hinweise aus echten Tagebuchdaten. Sie erzeugt keine Demo-Werte und keine Fallback-Insights. Wenn die Datenlage zu dünn oder ein Muster zu schwach ist, bleibt die Liste leer.

## Eingabedaten

Ausgewertet werden nur aktive Einträge mit dem Typ `Migräne` oder `Kopfschmerz`. Einträge mit `Unklar`, gelöschte Einträge und zukünftige Nicht-Schmerz-Typen zählen nicht als normale Messwerte. Dadurch werden auch keine „Keine Schmerzen“-Datenpunkte in Durchschnitt, Trend oder Muster eingerechnet.

Die Mindestmenge liegt bei `5` qualifizierten Einträgen. Unterhalb dieser Grenze liefert `InsightEngine` nur `totalQualifiedEpisodeCount` und keine Insights.

## Aggregation

`DataAggregator` bereitet die Daten für alle Detektoren vor:

- qualifizierte Einträge, nach Startzeit sortiert
- durchschnittliche Intensität über alle qualifizierten Einträge
- Anzahl und durchschnittliche Intensität pro Wochentag
- Anzahl normalisierter Trigger pro Eintrag
- Fingerprint für den Cache

Trigger werden pro Eintrag dedupliziert, getrimmt und alphabetisch sortiert. Leere Trigger werden ignoriert.

## Detektoren

`PatternDetector` erzeugt maximal einen Kandidaten pro Kategorie:

- `weekdayPattern`: häufigster Wochentag, sobald dieser mindestens zwei qualifizierte Einträge enthält
- `triggerCorrelation`: häufigster dokumentierter Trigger, sobald dieser mindestens zwei qualifizierte Einträge enthält
- `averageIntensity`: Durchschnitt über alle qualifizierten Einträge
- `trend`: Vergleich der älteren und neueren Hälfte; ein Trend entsteht erst ab mindestens `1,0` Punkt Unterschied

Trigger-Kandidaten beschreiben nur eine Häufung in dokumentierten Einträgen. Sie behaupten keine Ursache und keine medizinische Korrelation.

## Scoring

Jeder Kandidat bekommt `confidence` und `importance`.

`confidence`:

```text
sampleCoverage = min(1, supportCount / 8)
confidence = 0.6 * patternStrength + 0.4 * sampleCoverage
```

`patternStrength` hängt von der Kategorie ab:

- Wochentag: Abstand zur gleichmäßigen 1/7-Verteilung
- Trigger: Anteil qualifizierter Einträge mit diesem Trigger
- Durchschnitt: durchschnittliche Intensität / 10
- Trend: absoluter Unterschied der Hälften / 3, begrenzt auf 1

`importance`:

```text
averageIntensity: importance = durchschnittliche Intensität / 10
andere Kategorien: importance = 0.55 * patternStrength + 0.45 * relevante Intensität / 10
```

Ein Insight wird nur angezeigt, wenn `confidence >= 0.50` und `importance >= 0.40`.

## Sortierung und Hero Insight

Alle sichtbaren Insights werden nach kombiniertem Score sortiert:

```text
sortScore = 0.6 * importance + 0.4 * confidence
```

Bei gleichem Score entscheidet zuerst die höhere `confidence`, danach der Titel alphabetisch. `heroInsight` ist immer der erste Insight dieser sortierten Liste.

## Cache

`InsightEngine` cached das letzte Ergebnis im Speicher. Der Cache-Fingerprint enthält:

- Kalenderkennung, Zeitzone und ersten Wochentag
- qualifizierte Eintrags-IDs
- `startedAt`
- `updatedAt`
- Typ
- Intensität
- normalisierte Trigger
- Wetterstatus

Neue oder bearbeitete Einträge ändern `updatedAt` oder die ausgewerteten Felder und erzwingen dadurch eine Neuberechnung. Der Cache ist bewusst nur lokal im laufenden Prozess; er ersetzt keine persistierte Statistik.

## Texte

`InsightFormatter` formuliert alle Hinweise nicht-diagnostisch. Die Texte sprechen von bisherigen Einträgen, Häufungen und Verläufen. Sie enthalten keine Therapieempfehlung, keine Vorhersage und keine Aussage, dass ein Trigger Beschwerden verursacht.
