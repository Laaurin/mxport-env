import * as fs from 'fs';
import * as path from 'path';
import { types, jsonization, verification } from '@aas-core-works/aas-core3.0-typescript';

// Standard IDTA Semantic ID Constants
const IDTA_NAMEPLATE_SEMANTIC_ID = 'https://admin-shell.io/zvei/nameplate/1/0/Nameplate';
const IDTA_TECHNICAL_DATA_SEMANTIC_ID = 'https://admin-shell.io/idta/TechnicalData/TechnicalData/1/1';
const IDTA_SIMULATION_SEMANTIC_ID = 'https://admin-shell.io/idta/SimulationModel/0/1';
const IDTA_TIMESERIES_SEMANTIC_ID = 'https://admin-shell.io/idta/TimeSeries/TimeSeriesData/1/0';

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
// 1. Akteur A: Servo Motor Supplier (Public AAS Repo)
// -----------------------------------------------------------------------------
export function buildActorAEnvironment(): types.Environment {
  const aasId = 'urn:dataspace:a:aas:servo-motor-001';
  const assetId = 'urn:dataspace:a:asset:servo-motor-001';
  const smNameplateId = 'urn:dataspace:a:sm:nameplate';
  const smTechId = 'urn:dataspace:a:sm:technical-data';

  const assetInfo = new types.AssetInformation(types.AssetKind.Instance, assetId);
  const shell = new types.AssetAdministrationShell(aasId, assetInfo);
  shell.idShort = 'ServoMotorAAS';
  shell.submodels = [
    createModelReference(types.KeyTypes.Submodel, smNameplateId),
    createModelReference(types.KeyTypes.Submodel, smTechId)
  ];

  // Nameplate Submodel
  const smNameplate = new types.Submodel(smNameplateId);
  smNameplate.idShort = 'Nameplate';
  smNameplate.semanticId = createSemanticReference(IDTA_NAMEPLATE_SEMANTIC_ID);
  smNameplate.submodelElements = [
    createProperty('ManufacturerName', types.DataTypeDefXsd.String, 'MotorTech Antriebssysteme GmbH'),
    createProperty('ManufacturerProductDesignation', types.DataTypeDefXsd.String, 'HighTorque ServoDrive S7'),
    createProperty('SerialNumber', types.DataTypeDefXsd.String, 'MT-S7-99214'),
    createProperty('YearOfConstruction', types.DataTypeDefXsd.String, '2026')
  ];

  // Technical Data Submodel
  const smTech = new types.Submodel(smTechId);
  smTech.idShort = 'TechnicalData';
  smTech.semanticId = createSemanticReference(IDTA_TECHNICAL_DATA_SEMANTIC_ID);
  smTech.submodelElements = [
    createProperty('NominalPowerKW', types.DataTypeDefXsd.Double, '15.0'),
    createProperty('MaxTorqueNm', types.DataTypeDefXsd.Double, '75.0'),
    createProperty('RatedSpeedRPM', types.DataTypeDefXsd.Integer, '3000'),
    createProperty('EfficiencyClass', types.DataTypeDefXsd.String, 'IE4')
  ];

  const env = new types.Environment();
  env.assetAdministrationShells = [shell];
  env.submodels = [smNameplate, smTech];
  return env;
}

// -----------------------------------------------------------------------------
// 2. Akteur B: Industrial Gearbox Supplier (Public AAS Repo)
// -----------------------------------------------------------------------------
export function buildActorBEnvironment(): types.Environment {
  const aasId = 'urn:dataspace:b:aas:gearbox-001';
  const assetId = 'urn:dataspace:b:asset:gearbox-001';
  const smNameplateId = 'urn:dataspace:b:sm:nameplate';
  const smTechId = 'urn:dataspace:b:sm:technical-data';

  const assetInfo = new types.AssetInformation(types.AssetKind.Instance, assetId);
  const shell = new types.AssetAdministrationShell(aasId, assetInfo);
  shell.idShort = 'IndustrialGearboxAAS';
  shell.submodels = [
    createModelReference(types.KeyTypes.Submodel, smNameplateId),
    createModelReference(types.KeyTypes.Submodel, smTechId)
  ];

  // Nameplate Submodel
  const smNameplate = new types.Submodel(smNameplateId);
  smNameplate.idShort = 'Nameplate';
  smNameplate.semanticId = createSemanticReference(IDTA_NAMEPLATE_SEMANTIC_ID);
  smNameplate.submodelElements = [
    createProperty('ManufacturerName', types.DataTypeDefXsd.String, 'PrecisionGear AG'),
    createProperty('ManufacturerProductDesignation', types.DataTypeDefXsd.String, 'Planetary Precision Gear PG-50'),
    createProperty('SerialNumber', types.DataTypeDefXsd.String, 'PG-50-4821'),
    createProperty('YearOfConstruction', types.DataTypeDefXsd.String, '2026')
  ];

  // Technical Data Submodel
  const smTech = new types.Submodel(smTechId);
  smTech.idShort = 'TechnicalData';
  smTech.semanticId = createSemanticReference(IDTA_TECHNICAL_DATA_SEMANTIC_ID);
  smTech.submodelElements = [
    createProperty('GearRatio', types.DataTypeDefXsd.String, '10:1'),
    createProperty('MaxOutputTorqueNm', types.DataTypeDefXsd.Double, '450.0'),
    createProperty('TorsionalBacklashArcmin', types.DataTypeDefXsd.Double, '1.2'),
    createProperty('EfficiencyPercent', types.DataTypeDefXsd.Double, '97.5')
  ];

  const env = new types.Environment();
  env.assetAdministrationShells = [shell];
  env.submodels = [smNameplate, smTech];
  return env;
}

// -----------------------------------------------------------------------------
// 3. Akteur C: Vibration Sensor Supplier (Public AAS Repo)
// -----------------------------------------------------------------------------
export function buildActorCEnvironment(): types.Environment {
  const aasId = 'urn:dataspace:c:aas:sensor-001';
  const assetId = 'urn:dataspace:c:asset:sensor-001';
  const smNameplateId = 'urn:dataspace:c:sm:nameplate';
  const smTechId = 'urn:dataspace:c:sm:technical-data';

  const assetInfo = new types.AssetInformation(types.AssetKind.Instance, assetId);
  const shell = new types.AssetAdministrationShell(aasId, assetInfo);
  shell.idShort = 'VibrationSensorAAS';
  shell.submodels = [
    createModelReference(types.KeyTypes.Submodel, smNameplateId),
    createModelReference(types.KeyTypes.Submodel, smTechId)
  ];

  // Nameplate Submodel
  const smNameplate = new types.Submodel(smNameplateId);
  smNameplate.idShort = 'Nameplate';
  smNameplate.semanticId = createSemanticReference(IDTA_NAMEPLATE_SEMANTIC_ID);
  smNameplate.submodelElements = [
    createProperty('ManufacturerName', types.DataTypeDefXsd.String, 'SensX Automation Solutions'),
    createProperty('ManufacturerProductDesignation', types.DataTypeDefXsd.String, 'Triaxial Vibration Sensor VIB-3X'),
    createProperty('SerialNumber', types.DataTypeDefXsd.String, 'SX-VIB-3012'),
    createProperty('YearOfConstruction', types.DataTypeDefXsd.String, '2026')
  ];

  // Technical Data Submodel
  const smTech = new types.Submodel(smTechId);
  smTech.idShort = 'TechnicalData';
  smTech.semanticId = createSemanticReference(IDTA_TECHNICAL_DATA_SEMANTIC_ID);
  smTech.submodelElements = [
    createProperty('SamplingRateKHz', types.DataTypeDefXsd.Double, '25.6'),
    createProperty('MeasuringRangeG', types.DataTypeDefXsd.Double, '50.0'),
    createProperty('Interface', types.DataTypeDefXsd.String, 'IO-Link')
  ];

  const env = new types.Environment();
  env.assetAdministrationShells = [shell];
  env.submodels = [smNameplate, smTech];
  return env;
}

// -----------------------------------------------------------------------------
// 4. Akteur D: Machine Manufacturer (Maschinenbauer mit Simulation Submodel)
// -----------------------------------------------------------------------------
export function buildActorDEnvironment(): types.Environment {
  const aasId = 'urn:dataspace:d:aas:machine-type-001';
  const assetId = 'urn:dataspace:d:asset:machine-type-001';
  const smNameplateId = 'urn:dataspace:d:sm:nameplate';
  const smTechId = 'urn:dataspace:d:sm:technical-data';
  const smSimId = 'urn:dataspace:d:sm:machine-simulation';

  const assetInfo = new types.AssetInformation(types.AssetKind.Type, assetId);
  const shell = new types.AssetAdministrationShell(aasId, assetInfo);
  shell.idShort = 'MillingMachineTypeAAS';
  shell.submodels = [
    createModelReference(types.KeyTypes.Submodel, smNameplateId),
    createModelReference(types.KeyTypes.Submodel, smTechId),
    createModelReference(types.KeyTypes.Submodel, smSimId)
  ];

  // Nameplate Submodel
  const smNameplate = new types.Submodel(smNameplateId);
  smNameplate.idShort = 'Nameplate';
  smNameplate.semanticId = createSemanticReference(IDTA_NAMEPLATE_SEMANTIC_ID);
  smNameplate.submodelElements = [
    createProperty('ManufacturerName', types.DataTypeDefXsd.String, 'Apex Machining Systems GmbH'),
    createProperty('ManufacturerProductDesignation', types.DataTypeDefXsd.String, '5-Axis CNC Precision Milling Center V5'),
    createProperty('MachineType', types.DataTypeDefXsd.String, 'Industrial Milling Machine Type AAS')
  ];

  // Technical Data Submodel (referencing components from A, B, C)
  const smTech = new types.Submodel(smTechId);
  smTech.idShort = 'TechnicalData';
  smTech.semanticId = createSemanticReference(IDTA_TECHNICAL_DATA_SEMANTIC_ID);
  smTech.submodelElements = [
    createProperty('SpindlePowerKW', types.DataTypeDefXsd.Double, '22.0'),
    createProperty('MaxSpindleSpeedRPM', types.DataTypeDefXsd.Integer, '18000'),
    createProperty('AxisCount', types.DataTypeDefXsd.Integer, '5'),
    createProperty('IntegratedMotorRef', types.DataTypeDefXsd.String, 'urn:dataspace:a:aas:servo-motor-001'),
    createProperty('IntegratedGearboxRef', types.DataTypeDefXsd.String, 'urn:dataspace:b:aas:gearbox-001'),
    createProperty('IntegratedSensorRef', types.DataTypeDefXsd.String, 'urn:dataspace:c:aas:sensor-001')
  ];

  // Simulation Submodel (Restricted to paying customers like Akteur E)
  const smSim = new types.Submodel(smSimId);
  smSim.idShort = 'SimulationModel';
  smSim.semanticId = createSemanticReference(IDTA_SIMULATION_SEMANTIC_ID);
  smSim.submodelElements = [
    createProperty('SimulationType', types.DataTypeDefXsd.String, 'KinematicAndThermalFEA'),
    createProperty('ModelVersion', types.DataTypeDefXsd.String, 'v3.2.1'),
    createProperty('ToolCenterPointPrecisionMicron', types.DataTypeDefXsd.Double, '2.5'),
    createProperty('ThermalDriftCoefficient', types.DataTypeDefXsd.Double, '0.0014'),
    createProperty('SimulationPackageUrl', types.DataTypeDefXsd.String, 's3://apex-simulation-vault/packages/v5-thermal-fea.fmu'),
    createProperty('SimulationMeshElements', types.DataTypeDefXsd.Integer, '1450000')
  ];

  const env = new types.Environment();
  env.assetAdministrationShells = [shell];
  env.submodels = [smNameplate, smTech, smSim];
  return env;
}

// -----------------------------------------------------------------------------
// 5. Akteur E: Production Plant (Hersteller mit TimeSeries Submodel)
// -----------------------------------------------------------------------------
export function buildActorEEnvironment(): types.Environment {
  const aasId = 'urn:dataspace:e:aas:produced-part-001';
  const assetId = 'urn:dataspace:e:asset:produced-part-001';
  const smNameplateId = 'urn:dataspace:e:sm:nameplate';
  const smTimeSeriesId = 'urn:dataspace:e:sm:timeseries';

  const assetInfo = new types.AssetInformation(types.AssetKind.Instance, assetId);
  const shell = new types.AssetAdministrationShell(aasId, assetInfo);
  shell.idShort = 'TurbineBladeProductAAS';
  shell.submodels = [
    createModelReference(types.KeyTypes.Submodel, smNameplateId),
    createModelReference(types.KeyTypes.Submodel, smTimeSeriesId)
  ];

  // Nameplate Submodel (Publicly visible to dataspace participants)
  const smNameplate = new types.Submodel(smNameplateId);
  smNameplate.idShort = 'Nameplate';
  smNameplate.semanticId = createSemanticReference(IDTA_NAMEPLATE_SEMANTIC_ID);
  smNameplate.submodelElements = [
    createProperty('ManufacturerName', types.DataTypeDefXsd.String, 'PrecisionAero Components GmbH'),
    createProperty('ManufacturerProductDesignation', types.DataTypeDefXsd.String, 'HighPressure Turbine Blade Ti-6Al-4V'),
    createProperty('PartSerialNumber', types.DataTypeDefXsd.String, 'HPTB-2026-0042'),
    createProperty('ManufacturingDate', types.DataTypeDefXsd.String, '2026-10-12'),
    createProperty('ProducingMachineRef', types.DataTypeDefXsd.String, 'urn:dataspace:d:aas:machine-type-001')
  ];

  // TimeSeries Submodel (Restricted to verified customers like Akteur F)
  const smTimeSeries = new types.Submodel(smTimeSeriesId);
  smTimeSeries.idShort = 'TimeSeries';
  smTimeSeries.semanticId = createSemanticReference(IDTA_TIMESERIES_SEMANTIC_ID);
  smTimeSeries.submodelElements = [
    createProperty('ProcessRecordCount', types.DataTypeDefXsd.Integer, '3600'),
    createProperty('AverageMillingTemperatureCelsius', types.DataTypeDefXsd.Double, '142.8'),
    createProperty('PeakVibrationRMS', types.DataTypeDefXsd.Double, '0.45'),
    createProperty('SurfaceRoughnessRaMicron', types.DataTypeDefXsd.Double, '0.38'),
    createProperty('SpindleLoadPercent', types.DataTypeDefXsd.Double, '68.4'),
    createProperty('TimeSeriesStorageUrl', types.DataTypeDefXsd.String, 'https://influxdb.internal.e/query?part=HPTB-2026-0042')
  ];

  const env = new types.Environment();
  env.assetAdministrationShells = [shell];
  env.submodels = [smNameplate, smTimeSeries];
  return env;
}

// -----------------------------------------------------------------------------
// 6. Akteur F: Customer of E (Endkunde)
// -----------------------------------------------------------------------------
export function buildActorFEnvironment(): types.Environment {
  const aasId = 'urn:dataspace:f:aas:customer-profile-001';
  const assetId = 'urn:dataspace:f:asset:customer-profile-001';
  const smNameplateId = 'urn:dataspace:f:sm:nameplate';

  const assetInfo = new types.AssetInformation(types.AssetKind.Instance, assetId);
  const shell = new types.AssetAdministrationShell(aasId, assetInfo);
  shell.idShort = 'CustomerAeroEngineOEM';
  shell.submodels = [
    createModelReference(types.KeyTypes.Submodel, smNameplateId)
  ];

  const smNameplate = new types.Submodel(smNameplateId);
  smNameplate.idShort = 'Nameplate';
  smNameplate.semanticId = createSemanticReference(IDTA_NAMEPLATE_SEMANTIC_ID);
  smNameplate.submodelElements = [
    createProperty('CustomerName', types.DataTypeDefXsd.String, 'AeroEngine Global Corp'),
    createProperty('ProcurementProject', types.DataTypeDefXsd.String, 'NextGen Turbofan Engine X200'),
    createProperty('AuthorizedCustomerFor', types.DataTypeDefXsd.String, 'urn:dataspace:e:aas:produced-part-001')
  ];

  const env = new types.Environment();
  env.assetAdministrationShells = [shell];
  env.submodels = [smNameplate];
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
    { name: 'actor-a', env: buildActorAEnvironment() },
    { name: 'actor-b', env: buildActorBEnvironment() },
    { name: 'actor-c', env: buildActorCEnvironment() },
    { name: 'actor-d', env: buildActorDEnvironment() },
    { name: 'actor-e', env: buildActorEEnvironment() },
    { name: 'actor-f', env: buildActorFEnvironment() }
  ];

  for (const actor of actors) {
    verifyAndExport(actor.name, actor.env, targets);
  }

  console.log('\n================================================================');
  console.log(' All 6 AAS Environments successfully generated and verified!');
  console.log('================================================================\n');
}

main();
