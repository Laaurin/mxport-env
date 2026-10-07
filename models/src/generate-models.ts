import * as fs from 'fs';
import * as path from 'path';
import { types, jsonization, verification } from '@aas-core-works/aas-core3.0-typescript';

// Standard IDTA Semantic ID Constants
const IDTA_TECHNICAL_DATA_SEMANTIC_ID = 'https://admin-shell.io/idta/TechnicalData/TechnicalData/1/1';
const IDTA_PCF_SEMANTIC_ID = 'https://admin-shell.io/idta/CarbonFootprint/ProductCarbonFootprint/0/9';

function createSemanticReference(id: string): types.Reference {
  const key = new types.Key(types.KeyTypes.GlobalReference, id);
  return new types.Reference(types.ReferenceTypes.ExternalReference, [key]);
}

function createModelReference(type: types.KeyTypes, id: string): types.Reference {
  const key = new types.Key(type, id);
  return new types.Reference(types.ReferenceTypes.ModelReference, [key]);
}

function createProperty(
  idShort: string,
  valueType: types.DataTypeDefXsd,
  value: string
): types.Property {
  const prop = new types.Property(valueType);
  prop.idShort = idShort;
  prop.value = value;
  return prop;
}

// -----------------------------------------------------------------------------
// 1. Tier 3: Battery Cell Supplier
// -----------------------------------------------------------------------------
export function buildTier3Environment(): types.Environment {
  const aasId = 'urn:dataspace:tier3:aas:battery-cell-001';
  const assetId = 'urn:dataspace:tier3:asset:battery-cell-001';
  const smTechId = 'urn:dataspace:tier3:sm:cell-tech-data';
  const smPcfId = 'urn:dataspace:tier3:sm:cell-pcf';

  const assetInfo = new types.AssetInformation(types.AssetKind.Instance, assetId);
  const shell = new types.AssetAdministrationShell(aasId, assetInfo);
  shell.idShort = 'BatteryCellAAS';
  shell.submodels = [
    createModelReference(types.KeyTypes.Submodel, smTechId),
    createModelReference(types.KeyTypes.Submodel, smPcfId)
  ];

  // Technical Data Submodel
  const smTech = new types.Submodel(smTechId);
  smTech.idShort = 'TechnicalData';
  smTech.semanticId = createSemanticReference(IDTA_TECHNICAL_DATA_SEMANTIC_ID);
  smTech.submodelElements = [
    createProperty('Chemistry', types.DataTypeDefXsd.String, 'NMC 811'),
    createProperty('NominalVoltageV', types.DataTypeDefXsd.Double, '3.7'),
    createProperty('CapacityAh', types.DataTypeDefXsd.Double, '50.0')
  ];

  // PCF Submodel
  const smPcf = new types.Submodel(smPcfId);
  smPcf.idShort = 'CarbonFootprint';
  smPcf.semanticId = createSemanticReference(IDTA_PCF_SEMANTIC_ID);
  smPcf.submodelElements = [
    createProperty('ProductCarbonFootprintKgCO2e', types.DataTypeDefXsd.Double, '18.5'),
    createProperty('PrimaryDataSharePercent', types.DataTypeDefXsd.Double, '85.0')
  ];

  const env = new types.Environment();
  env.assetAdministrationShells = [shell];
  env.submodels = [smTech, smPcf];
  return env;
}

// -----------------------------------------------------------------------------
// 2. Tier 2: Battery Module Supplier
// -----------------------------------------------------------------------------
export function buildTier2Environment(): types.Environment {
  const aasId = 'urn:dataspace:tier2:aas:battery-module-001';
  const assetId = 'urn:dataspace:tier2:asset:battery-module-001';
  const smTechId = 'urn:dataspace:tier2:sm:module-tech-data';
  const smPcfId = 'urn:dataspace:tier2:sm:module-pcf';

  const assetInfo = new types.AssetInformation(types.AssetKind.Instance, assetId);
  const shell = new types.AssetAdministrationShell(aasId, assetInfo);
  shell.idShort = 'BatteryModuleAAS';
  shell.submodels = [
    createModelReference(types.KeyTypes.Submodel, smTechId),
    createModelReference(types.KeyTypes.Submodel, smPcfId)
  ];

  // Technical Data Submodel
  const smTech = new types.Submodel(smTechId);
  smTech.idShort = 'TechnicalData';
  smTech.semanticId = createSemanticReference(IDTA_TECHNICAL_DATA_SEMANTIC_ID);
  smTech.submodelElements = [
    createProperty('CellConfiguration', types.DataTypeDefXsd.String, '12S1P'),
    createProperty('TotalVoltageV', types.DataTypeDefXsd.Double, '44.4'),
    createProperty('WeightKg', types.DataTypeDefXsd.Double, '15.2')
  ];

  // PCF Submodel
  const smPcf = new types.Submodel(smPcfId);
  smPcf.idShort = 'CarbonFootprint';
  smPcf.semanticId = createSemanticReference(IDTA_PCF_SEMANTIC_ID);
  smPcf.submodelElements = [
    createProperty('ProductCarbonFootprintKgCO2e', types.DataTypeDefXsd.Double, '245.0'),
    createProperty('UpstreamCellRef', types.DataTypeDefXsd.String, 'urn:dataspace:tier3:aas:battery-cell-001')
  ];

  const env = new types.Environment();
  env.assetAdministrationShells = [shell];
  env.submodels = [smTech, smPcf];
  return env;
}

// -----------------------------------------------------------------------------
// 3. Tier 1: Battery Pack Supplier
// -----------------------------------------------------------------------------
export function buildTier1Environment(): types.Environment {
  const aasId = 'urn:dataspace:tier1:aas:battery-pack-001';
  const assetId = 'urn:dataspace:tier1:asset:battery-pack-001';
  const smTechId = 'urn:dataspace:tier1:sm:pack-tech-data';
  const smPcfId = 'urn:dataspace:tier1:sm:pack-pcf';

  const assetInfo = new types.AssetInformation(types.AssetKind.Instance, assetId);
  const shell = new types.AssetAdministrationShell(aasId, assetInfo);
  shell.idShort = 'BatteryPackAAS';
  shell.submodels = [
    createModelReference(types.KeyTypes.Submodel, smTechId),
    createModelReference(types.KeyTypes.Submodel, smPcfId)
  ];

  // Technical Data Submodel
  const smTech = new types.Submodel(smTechId);
  smTech.idShort = 'TechnicalData';
  smTech.semanticId = createSemanticReference(IDTA_TECHNICAL_DATA_SEMANTIC_ID);
  smTech.submodelElements = [
    createProperty('PackCapacityKWh', types.DataTypeDefXsd.Double, '80.0'),
    createProperty('NominalVoltageV', types.DataTypeDefXsd.Double, '400.0'),
    createProperty('ModuleCount', types.DataTypeDefXsd.Integer, '8')
  ];

  // PCF Submodel
  const smPcf = new types.Submodel(smPcfId);
  smPcf.idShort = 'CarbonFootprint';
  smPcf.semanticId = createSemanticReference(IDTA_PCF_SEMANTIC_ID);
  smPcf.submodelElements = [
    createProperty('ProductCarbonFootprintKgCO2e', types.DataTypeDefXsd.Double, '2150.0'),
    createProperty('UpstreamModuleRef', types.DataTypeDefXsd.String, 'urn:dataspace:tier2:aas:battery-module-001')
  ];

  const env = new types.Environment();
  env.assetAdministrationShells = [shell];
  env.submodels = [smTech, smPcf];
  return env;
}

// -----------------------------------------------------------------------------
// 4. OEM: Vehicle Manufacturer
// -----------------------------------------------------------------------------
export function buildOemEnvironment(): types.Environment {
  const aasId = 'urn:dataspace:oem:aas:vehicle-001';
  const assetId = 'urn:dataspace:oem:asset:vehicle-001';
  const smTechId = 'urn:dataspace:oem:sm:vehicle-tech-data';
  const smPcfId = 'urn:dataspace:oem:sm:vehicle-pcf';

  const assetInfo = new types.AssetInformation(types.AssetKind.Instance, assetId);
  const shell = new types.AssetAdministrationShell(aasId, assetInfo);
  shell.idShort = 'ElectricVehicleAAS';
  shell.submodels = [
    createModelReference(types.KeyTypes.Submodel, smTechId),
    createModelReference(types.KeyTypes.Submodel, smPcfId)
  ];

  // Technical Data Submodel
  const smTech = new types.Submodel(smTechId);
  smTech.idShort = 'TechnicalData';
  smTech.semanticId = createSemanticReference(IDTA_TECHNICAL_DATA_SEMANTIC_ID);
  smTech.submodelElements = [
    createProperty('ModelName', types.DataTypeDefXsd.String, 'VisionGT EV'),
    createProperty('BatteryPackCapacityKWh', types.DataTypeDefXsd.Double, '80.0'),
    createProperty('DriveType', types.DataTypeDefXsd.String, 'AWD Dual Motor')
  ];

  // PCF Submodel
  const smPcf = new types.Submodel(smPcfId);
  smPcf.idShort = 'CarbonFootprint';
  smPcf.semanticId = createSemanticReference(IDTA_PCF_SEMANTIC_ID);
  smPcf.submodelElements = [
    createProperty('VehicleTotalCarbonFootprintKgCO2e', types.DataTypeDefXsd.Double, '8500.0'),
    createProperty('UpstreamPackRef', types.DataTypeDefXsd.String, 'urn:dataspace:tier1:aas:battery-pack-001')
  ];

  const env = new types.Environment();
  env.assetAdministrationShells = [shell];
  env.submodels = [smTech, smPcf];
  return env;
}

// -----------------------------------------------------------------------------
// Verification and Export Runner
// -----------------------------------------------------------------------------
function verifyAndExport(name: string, env: types.Environment, targetDirs: string[]) {
  console.log(`\n>>> Processing AAS Environment: ${name}`);

  // 1. Formal Metamodel Schema Verification
  const errors: string[] = [];
  for (const error of verification.verify(env)) {
    errors.push(`${error.path}: ${error.message}`);
  }

  if (errors.length > 0) {
    console.error(`  ✗ Metamodel Verification Failed with ${errors.length} error(s):`);
    for (const err of errors) {
      console.error(`    - ${err}`);
    }
    throw new Error(`Verification failed for ${name}`);
  }

  console.log(`  ✓ Schema Verification Passed (100% IDTA Metamodel V3 Compliant)`);

  // 2. Serialize to standard-compliant JSON
  const jsonable = jsonization.toJsonable(env);
  const jsonContent = JSON.stringify(jsonable, null, 2);

  // 3. Write to targets
  for (const dir of targetDirs) {
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    const filePath = path.join(dir, `${name}.json`);
    fs.writeFileSync(filePath, jsonContent, 'utf-8');
    console.log(`  ✓ Wrote: ${filePath} (${jsonContent.length} bytes)`);
  }
}

function main() {
  const rootDir = path.resolve(__dirname, '..', '..');
  const distDir = path.join(__dirname, '..', 'dist');
  const helmFilesDir = path.join(rootDir, 'k8s', 'helm', 'dataspace-actor', 'files', 'models');

  const targets = [distDir, helmFilesDir];

  const actors = [
    { name: 'oem', env: buildOemEnvironment() },
    { name: 'tier1', env: buildTier1Environment() },
    { name: 'tier2', env: buildTier2Environment() },
    { name: 'tier3', env: buildTier3Environment() }
  ];

  for (const actor of actors) {
    verifyAndExport(actor.name, actor.env, targets);
  }

  console.log('\n================================================================');
  console.log(' All 4 AAS Environments successfully generated and verified!');
  console.log('================================================================\n');
}

main();
