# Proyecto — Base de datos AGEB (CSV con todos los indicadores)

Documento de instrucciones para construir, en **Claude Code**, una base a nivel
**AGEB** (urbanas **y** rurales) en formato **CSV** con todos los indicadores, de
forma reproducible. Recoge las fuentes verificadas, las decisiones metodológicas
y las trampas encontradas al construir el prototipo de Oaxaca.

> Convención: prosa en español; **nombres de archivos, variables y comentarios
> de código en inglés**. CSV en UTF-8, separador coma.

---

## 0. Cómo usar este documento en Claude Code

1. Crea un repo/carpeta `mexico_geodata/` y pega este archivo como `CLAUDE.md`
   (o `SPEC.md`) en la raíz.
2. Reutiliza el pipeline previo si lo tienes (`pipeline/config.py`, `utils.py`,
   `process_denue.py`, `process_hydrology.py`, `process_landuse.py`,
   `build_complete.py`). **Cambio principal de esta versión:** la geometría deja
   de ser solo urbana (KMZ de CONEVAL) y pasa a **AGEB urbanas + rurales del
   Marco Geoestadístico del INEGI**, para cobertura territorial completa.
3. Entorno: Python 3.11+, `pip install geopandas pyogrio shapely pyproj requests
   openpyxl pandas`.

---

## 1. Objetivo

Un **CSV por AGEB** (una fila = una AGEB), con clave única y **todos los
indicadores**, con **cobertura completa**: las AGEB **urbanas y rurales** deben
**teselar por completo cada municipio** (sin huecos). Prototipo y validación en
**Oaxaca (ent. 20)**; diseño escalable a las 32 entidades.

El CSV es una **tabla de atributos** (sin geometría). Para mapear se une por
`ID_AGEB` a la geometría de AGEB (urbanas+rurales), o se usan
`CENTROIDE_LON/LAT`.

**Regla de cobertura (QC obligatorio):** para cada municipio, la unión de sus
AGEB (urbanas+rurales) debe cubrir el 100 % de su superficie; el área sumada de
AGEB por municipio debe coincidir (±tolerancia) con el área del polígono
municipal.

---

## 2. Aprendizajes críticos de acceso a fuentes  ⚠️

Desde entornos automatizados:

- **INEGI `bvinegi/geografia` (Marco Geoestadístico, USYV directo) → HTTP 503.**
  Esto **bloquea la geometría de AGEB rurales**, que es indispensable para la
  cobertura completa. **En Claude Code (red distinta) reintentar**; si sigue
  503, **descargar el Marco Geoestadístico 2020 manualmente** desde el portal
  del INEGI y colocarlo en `raw/`. Ver §5.0.
- **Endpoints que SÍ funcionan** de forma estable:
  - Censo (datos abiertos): `inegi.org.mx/contenidos/programas/ccpv/2020/datosabiertos/...`
  - DENUE (masiva): `inegi.org.mx/contenidos/masiva/denue/...`
  - CONEVAL (documentos): `coneval.org.mx/Medicion/Documents/...`
  - CONABIO (GIS): `conabio.gob.mx/informacion/gis/maps/geo/...`
- **Encoding:** shapefiles de CONABIO/INEGI y CSV de DENUE vienen en **latin-1**.

---

## 3. Fuentes de datos (verificadas)

| Dataset | Institución | Año | URL | Nota |
|---|---|---|---|---|
| **Marco Geoestadístico — AGEB urbanas + rurales (geometría base)** | **INEGI** | **2020** | `…/geografia/marcogeo/889463807469_s.zip` (nacional ~2.65 GB) | **REQUERIDO para cobertura completa.** 503 desde automatizado → reintentar en Code o descargar manual |
| Censo AGEB/manzana urbana (pob/vivienda urbana) | INEGI | 2020 | `…/ccpv/2020/datosabiertos/ageb_manzana/ageb_mza_urbana_{ENT}_cpv2020_csv.zip` | ✔ **solo urbano** |
| ITER (localidades: pob/vivienda + nombres) | INEGI | 2020 | `…/ccpv/2020/datosabiertos/iter/iter_{ENT}_cpv2020_csv.zip` | ✔ base para atributos **rurales** |
| GRS + 17 indicadores por AGEB urbana | CONEVAL | 2020 | `coneval.org.mx/Medicion/Documents/GRS_AGEB_2020/GRS_AGEB_urbana_2020.zip` | ✔ **solo urbano** |
| Geometría AGEB urbana (KMZ) | CONEVAL | 2020 | `…/GRS_AGEB_2020/Visualizacion_GRS_AGEB_urbana_2020.zip` | respaldo **solo urbano** (insuficiente para cobertura completa) |
| DENUE (unidades económicas) | INEGI | 2026-05 | `inegi.org.mx/contenidos/masiva/denue/denue_{ENT}_csv.zip` | ✔ urbano y rural |
| Municipios (geometría, control de cobertura) | CONABIO (MG INEGI) | 2022 | `conabio.gob.mx/informacion/gis/maps/geo/mun22gw.zip` | ✔ nacional |
| Uso de suelo y vegetación Serie VII | CONABIO (INEGI) | 2021 | `conabio.gob.mx/informacion/gis/maps/geo/usv250s7gw.zip` | ✔ nacional (~317 MB) |
| Cuerpos de agua (hidrografía) | CONABIO/INEGI | 2018 | `conabio.gob.mx/informacion/gis/maps/geo/catp50s3gw.zip` | ✔ nacional |
| IRS continuo (solo municipal) | CONEVAL | 2020 | `coneval.org.mx/Medicion/Documents/IRS_2020/IRS_ent_mun_2000_2020.zip` | ✔ **no existe a nivel AGEB** |
| Entorno urbano (banqueta/alumbrado) | INEGI | 2020 | producto a nivel manzana | ✖ sin descarga automatizada confirmada |

---

## 4. Llave espacial, ámbito y CRS

- **Llave `ID_AGEB` = CVE_ENT(2)+CVE_MUN(3)+CVE_LOC(4)+CVE_AGEB(4) = 13 car.**
  CVE_AGEB es **alfanumérica** → `zfill(4)`, nunca a entero.
- **`AMBITO`** (nuevo, obligatorio): `"Urbana"` / `"Rural"`. Tomarlo del atributo
  correspondiente del Marco Geoestadístico (o inspeccionar las capas del MG para
  identificar urbanas vs rurales); NO deducirlo del código.
- **Nota sobre rurales:** en el MG, la porción no urbana de cada municipio se
  cubre con **AGEB rurales**; junto con las urbanas teselan el municipio completo.
- **CRS:** origen `EPSG:4326`; **análisis `EPSG:6372`** (áreas/distancias);
  distribución `EPSG:4326`. Nunca áreas en grados.

---

## 5. Bloques temáticos (variable → fuente → método → decisión)

### 5.0 Geometría base — AGEB urbanas + rurales (NUEVO, crítico)
- **Fuente:** Marco Geoestadístico 2020 del INEGI. Descomprimir y localizar la(s)
  capa(s) de AGEB; conservar **todas** las AGEB (urbanas y rurales) con
  `ID_AGEB`, `AMBITO` y geometría. Reproyectar a `EPSG:6372` para calcular
  `AREA_KM2`.
- **Si el MG está 503:** reintentar en Code; si no, descargar manual del portal
  INEGI (Geografía → Marco Geoestadístico) y colocar el zip en `raw/`. El
  pipeline debe leer del `raw/` si ya existe (idempotente).
- **QC de cobertura:** por `CVE_MUN`, `sum(AREA_KM2 de AGEB) ≈ AREA municipio`
  (usar `mun22gw` como referencia). Reportar municipios con hueco > tolerancia.
- **Respaldo urbano (degradado):** si de plano no hay MG, usar el KMZ de CONEVAL
  como en el prototipo, dejando `AMBITO="Urbana"` y documentando que **no hay
  cobertura completa** (faltan las rurales).

### 5.1 Identificación
`ID_AGEB, CVE_ENT, NOM_ENT, CVE_MUN, NOM_MUN, CVE_LOC, NOM_LOC, CVE_AGEB, AMBITO`.
- `NOM_LOC`: nombre real de localidad del **ITER** (unir por `ID_LOC=ENT+MUN+LOC`,
  filtrar totales `LOC != 0000` y `< 9998`). En AGEB rurales que agrupan varias
  localidades, `NOM_LOC` puede quedar vacío o marcarse `"(varias localidades)"`.

### 5.2 Población y vivienda
Variables finales: `POB_TOTAL, POB_HOMBRES, POB_MUJERES, VIV_PART_HAB,
VIV_DRENAJE, VIV_ELECTRICIDAD` + derivadas (`PCT_*, DENS_POB_KM2, POB_POR_VIV`).
- **AGEB URBANAS →** archivo `ageb_mza_urbana` (Censo). Total de la AGEB = fila
  **`MZA=='000'`** con `AGEB!='0000'`. Denominador de los `VPH_*` = **`TVIVPARHAB`**
  (verificado: `VPH_ ≤ TVIVPARHAB` ~99.5 %; con `VIVPAR_HAB` solo ~14.5 %).
- **AGEB RURALES → agregar el ITER (localidades) a la AGEB rural.** El ITER trae
  población/vivienda por localidad pero **no** la clave de AGEB; la asignación
  localidad→AGEB viene del **MG** (capa de localidades con `CVE_AGEB`). Método:
  join ITER×MG_localidades por `ID_LOC`, luego `groupby(ID_AGEB).sum()` de las
  mismas variables (`POBTOT, POBMAS, POBFEM, TVIVPARHAB, VPH_DRENAJ, VPH_C_ELEC`).
- **Supresión** (`*`/`N/D` → NaN); en QC comparar solo donde ambos existen.

### 5.3 Rezago social (CONEVAL 2020)
`GRS_GRADO` (Muy bajo…Muy alto) + `GRS_NUM` (1–5) + **17 indicadores `RZ_*`**.
- **Solo urbano:** el GRS por AGEB de CONEVAL existe **únicamente para AGEB
  urbanas**. Las AGEB **rurales** quedan `NaN` en GRS/`RZ_*` (documentarlo).
  Opcional: para contexto rural, usar el rezago social a nivel **localidad** de
  CONEVAL (producto aparte) — no mezclarlo en la misma columna sin marcar.
- xlsx: cabecera de 2 filas, datos desde fila 6; clave AGEB col 7, grado col 27,
  indicadores col 10–26.
- **IRS continuo NO existe a nivel AGEB** (solo grado); el IRS solo es municipal
  hacia arriba.

### 5.4 DENUE — actividad económica (2026)
`DENUE_TOT` + por sector SCIAN: `DEN_MANUF(31-33), DEN_COM(43,46),
DEN_SERV(48-81), DEN_EDU(61), DEN_GOB(93)`. Funciona para **urbanas y rurales**.
- Asignar a AGEB con las claves del propio DENUE (`cve_ent/mun/loc/ageb`).
- `per_ocu` por estratos (no headcount). Leer el CSV de `conjunto_de_datos/` (no
  el diccionario). Encoding latin-1. Sanear coordenadas fuera del bbox estatal.

### 5.5 Escuelas
`SCHOOL_TOT` = DENUE **SCIAN 611** (proxy documentado; fuente formal: SEP/CCT).

### 5.6 Hidrología (CONABIO cuerpos de agua)
`WATER_AREA (km²), WATER_PCT (%), HAS_WATER (0/1)` por intersección en
`EPSG:6372`. Aplica a urbanas y rurales; 0 real donde no intersecta.

### 5.7 Uso de suelo (USYV Serie VII vía CONABIO)
`USO_DOM, USO_PCT, PCT_URB` por **intersección** (no spatial join) en `EPSG:6372`;
guardar tabla detallada AGEB×clase. Especialmente informativo en AGEB **rurales**
(agricultura, vegetación, etc.). Leer USYV con `bbox` de la entidad, latin-1.

### 5.8 Entorno urbano (PENDIENTE)
`BANQUETA, RECUBRIMIENTO, ALUMBRADO` — Censo 2020, nivel manzana; aplica solo a
zonas urbanas. Dejar fuera hasta tener el dato real (sin ceros falsos).

---

## 6. Estructura del pipeline

```
pipeline/
  config.py              # ENTITIES, años por fuente, CRS, URLS, rutas
  utils.py               # download(), build_ageb_id(), loaders censo/CONEVAL
  process_boundaries.py  # << AMPLIAR: leer AGEB urbanas+rurales del MG (+AMBITO)
  process_census_rural.py# << NUEVO: ITER->AGEB rural (vía MG localidades)
  process_denue.py       # DENUE detalle + resumen + escuelas
  process_hydrology.py   # cuerpos de agua -> WATER_*
  process_landuse.py     # USYV S.VII -> USO_DOM/USO_PCT/PCT_URB (+ detalle)
  build_complete.py      # ensambla TODO por ID_AGEB (urbanas+rurales)
  export_csv.py          # << NUEVO: CSV final por AGEB (+ CENTROIDE_LON/LAT)
  qc_coverage.py         # << NUEVO: verifica cobertura municipal 100%
```

Ejecución: `python -m pipeline.build_complete 20 && python -m pipeline.export_csv 20`.
Nacional: `ENTITIES = [f"{i:02d}" for i in range(1,33)]`.

---

## 7. Esquema del CSV (`ageb_indicadores_{ENT}.csv`)

Una fila por AGEB (urbana o rural). Columnas:

- **ID/geo:** `ID_AGEB, AMBITO, CVE_ENT, NOM_ENT, CVE_MUN, NOM_MUN, CVE_LOC,
  NOM_LOC, CVE_AGEB, AREA_KM2, CENTROIDE_LON, CENTROIDE_LAT`
- **Población:** `POB_TOTAL, POB_HOMBRES, POB_MUJERES, PCT_HOMBRES, PCT_MUJERES,
  DENS_POB_KM2, POB_POR_VIV`
- **Vivienda:** `VIV_PART_HAB, VIV_DRENAJE, VIV_ELECTRICIDAD, PCT_DRENAJE, PCT_ELECTRIC`
- **CONEVAL (urbanas; NaN en rurales):** `GRS_GRADO, GRS_NUM, RZ_ANALF, RZ_INA614,
  RZ_INA1524, RZ_EBINC, RZ_SSALUD, RZ_HACIN, RZ_SAGUA, RZ_SEXCUS, RZ_SDREN,
  RZ_SELEC, RZ_PISOT, RZ_SLAVAD, RZ_SREFRI, RZ_STELF, RZ_SCEL, RZ_SCOMPU, RZ_SINTER`
- **DENUE/escuelas:** `DENUE_TOT, DEN_MANUF, DEN_COM, DEN_SERV, DEN_EDU, DEN_GOB, SCHOOL_TOT`
- **Hidrología:** `WATER_AREA, WATER_PCT, HAS_WATER`
- **Uso de suelo:** `USO_DOM, USO_PCT, PCT_URB`
- **(Pendiente) Entorno urbano:** `BANQUETA, RECUBRIMIENTO, ALUMBRADO`
- **Años por fuente:** `YEAR_GEOMETRY, YEAR_CENSUS, YEAR_CONEVAL, YEAR_DENUE,
  YEAR_HIDRO, YEAR_USV`

Tablas de detalle aparte: `denue_establishments_{ENT}.csv`,
`denue_ageb_sector_{ENT}.csv`, `ageb_landuse_detail_{ENT}.csv`.

---

## 8. Controles de calidad (→ `quality_control_report_{ENT}.csv`)

- **Cobertura municipal 100 %** (NUEVO): por `CVE_MUN`, `sum(AREA_KM2 AGEB) ≈
  AREA municipio` (ref. `mun22gw`); reportar huecos/solapes.
- `AMBITO` ∈ {Urbana, Rural}; conteo urbanas vs rurales por municipio.
- Geometría válida/no vacía; `ID_AGEB` único y de 13.
- Cobertura de uniones censo/ITER/CONEVAL/DENUE por ámbito.
- `POB_H+POB_M ≈ POB_TOTAL` (donde no hay supresión).
- `VIV_DRENAJE ≤ VIV_PART_HAB`, `VIV_ELECTRICIDAD ≤ VIV_PART_HAB` (solo donde
  ambos existen; tolerar <1 % por redondeo).
- `GRS/RZ_*` presentes en **urbanas**; `NaN` esperado en **rurales**.
- `WATER_PCT`, `USO_PCT` en [0,100].

---

## 9. Limitaciones conocidas

1. **Geometría:** la cobertura completa **depende del Marco Geoestadístico 2020
   del INEGI**. Si no se consigue, solo hay AGEB urbanas (KMZ CONEVAL) y **no**
   hay cobertura territorial completa.
2. **Rezago social rural:** el GRS por AGEB es urbano; las AGEB rurales quedan sin
   GRS (opcionalmente, usar rezago a nivel localidad como contexto, marcado).
3. **IRS continuo:** no existe a nivel AGEB (solo grado + indicadores urbanos).
4. **Entorno urbano:** banqueta/recubrimiento/alumbrado pendientes (nivel manzana).
5. **Años mixtos:** conservar `YEAR_*` por fuente.

---

## 10. Escalamiento y versionado

- Cambiar `YEAR` y `ENTITIES` en `config.py`.
- Cachear descargas en `raw/` (idempotente). El MG y USYV son grandes: leer por
  entidad / con `bbox`. Para nacional, procesar entidad por entidad y concatenar.
