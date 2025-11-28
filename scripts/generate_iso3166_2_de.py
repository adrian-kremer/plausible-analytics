#!/usr/bin/env python3
"""
Generate German ISO 3166-2 subdivision names from Wikidata.
Creates deps/location/priv/iso_3166-2.de-translations.json
"""
import json
import urllib.request
import urllib.parse

# Wikidata SPARQL query to get ISO 3166-2 codes with German labels
QUERY = """
SELECT ?code ?labelDe WHERE {
  ?item wdt:P300 ?code .
  ?item rdfs:label ?labelDe .
  FILTER(LANG(?labelDe) = "de")
}
ORDER BY ?code
"""

ENDPOINT = "https://query.wikidata.org/sparql"

def fetch_wikidata():
    """Fetch subdivision data from Wikidata SPARQL endpoint."""
    params = {
        "query": QUERY,
        "format": "json"
    }
    
    url = f"{ENDPOINT}?{urllib.parse.urlencode(params)}"
    headers = {"User-Agent": "Plausible-ISO3166-Generator/1.0"}
    
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=30) as response:
        data = json.loads(response.read().decode())
    
    return data

def main():
    print("Fetching German subdivision names from Wikidata...")
    data = fetch_wikidata()
    
    result = {}
    for binding in data["results"]["bindings"]:
        code = binding["code"]["value"]
        label = binding["labelDe"]["value"]
        result[code] = label
    
    output_path = "deps/location/priv/iso_3166-2.de-translations.json"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
    
    print(f"✓ Wrote {len(result)} entries to {output_path}")
    print(f"Sample entries:")
    for i, (k, v) in enumerate(list(result.items())[:5]):
        print(f"  {k}: {v}")

if __name__ == "__main__":
    main()
