# symiapp.com

Statische Landingpage für Symi. Die Seite lädt keine externen Ressourcen nach:

- keine externen Fonts
- keine CDN-Skripte
- keine externen Bilder
- kein Tracking
- kein Backend

## Cloudflare Pages

Für Cloudflare Pages kann dieses Verzeichnis als statischer Projekt-Root verwendet werden:

```text
semiapp.com
```

Build command leer lassen oder auf `None` setzen. Das Output-Verzeichnis ist ebenfalls `semiapp.com`,
wenn aus dem Repository-Root deployed wird.

Vor Veröffentlichung müssen die Platzhalter in `impressum.html` und `support.html` ergänzt werden.
