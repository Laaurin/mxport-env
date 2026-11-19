# Custom AAS & Submodel Models (Git-Ignored)

In diesem Ordner kannst du eigene AAS-Environment-JSON-Dateien für die einzelnen Akteure ablegen:

- `actor-a.json`
- `actor-b.json`
- `actor-c.json`
- `actor-d.json`
- `actor-e.json`
- `actor-f.json`

## Verhalten & Fallback
1. Alle `*.json`- und `*.aasx`-Dateien in diesem Ordner (`k8s/helm/dataspace-actor/files/custom-models/`) werden von **Git ignoriert** (`.gitignore`).
2. Wenn für einen Akteur hier eine Datei existiert (z. B. `custom-models/actor-e.json`), wird beim Ausrollen (`./k8s/scripts/deploy-all.sh` bzw. `.\k8s\scripts\deploy-all.ps1`) automatisch **deine eigene Datei** in das BaSyx AAS Environment geladen.
3. Wenn für einen Akteur hier **keine** Datei liegt, greift automatisch der **Fallback** auf die bestehenden Demo-Modelle unter `k8s/helm/dataspace-actor/files/models/<actor>.json`.

## Offizielles JSON-Format (IDTA / Eclipse BaSyx V3.0)
Das Format entspricht dem offiziellen IDTA / Eclipse BaSyx AAS V3.0 JSON-Schema (identisch zum JSON-Export aus dem AASX Package Explorer):

```json
{
  "assetAdministrationShells": [
    {
      "modelType": "AssetAdministrationShell",
      "idShort": "MyCustomAAS",
      "id": "urn:dataspace:e:aas:custom-001",
      "assetInformation": {
        "assetKind": "Instance",
        "globalAssetId": "urn:dataspace:e:asset:custom-001"
      },
      "submodels": [
        {
          "type": "ModelReference",
          "keys": [
            {
              "type": "Submodel",
              "value": "urn:dataspace:e:sm:custom-submodel-001"
            }
          ]
        }
      ]
    }
  ],
  "submodels": [
    {
      "modelType": "Submodel",
      "idShort": "CustomSubmodel",
      "id": "urn:dataspace:e:sm:custom-submodel-001",
      "submodelElements": [
        {
          "modelType": "Property",
          "idShort": "ExampleProperty",
          "valueType": "xs:string",
          "value": "Hello Dataspace"
        }
      ]
    }
  ],
  "conceptDescriptions": []
}
```

