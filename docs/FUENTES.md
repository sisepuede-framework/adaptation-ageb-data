# Fuentes de datos

Todas se descargan automáticamente con `Rscript run_all.R` (las URL viven en
`R/00_config.R`) y se guardan en `data/raw/`, que no se versiona. Los
identificadores de la columna `FUENTE` del
[diccionario de datos](DICCIONARIO_DATOS.md) son los de esta tabla.

| ID | Producto | Institución | Año de referencia | Cobertura | Unidad | Escala / formato | Script |
|---|---|---|---|---|---|---|---|
| `MG2020` | Marco Geoestadístico, censo 2020 | INEGI | 2020 | 32 entidades | AGEB urbana y rural, localidad, municipio | Vectorial (shapefile), EPSG:6372 | `03_boundaries.R` |
| `CPV2020_AGEB` | Censo de Población y Vivienda 2020: principales resultados por AGEB y manzana urbana | INEGI | 2020 | AGEB urbanas | AGEB (fila `MZA = 000`) | CSV, UTF-8 | `04_census_urban.R` |
| `CPV2020_ITER` | Censo de Población y Vivienda 2020: principales resultados por localidad (ITER) | INEGI | 2020 | Todas las localidades | Localidad | CSV, UTF-8 | `05_census_rural.R` |
| `CONEVAL_GRS2020` | Grado de Rezago Social por AGEB urbana 2020 | CONEVAL | 2020 | AGEB urbanas | AGEB | XLSX nacional | `06_coneval.R` |
| `DENUE` | Directorio Estadístico Nacional de Unidades Económicas | INEGI | 2026-05 | 32 entidades | Establecimiento | CSV, latin-1 | `07_denue.R` |
| `INEGI_CA50` | Cuerpos de agua. Continuo Nacional Topográfico 1:50 000, serie III | INEGI, distribuido por CONABIO | 2013–2018 | Nacional | Polígono | Shapefile, 1:50,000 | `08_hydrology.R` |
| `INEGI_USV7` | Uso del suelo y vegetación 1:250 000, serie VII | INEGI, distribuido por CONABIO | 2021 (imágenes de año base 2018) | Nacional | Polígono | Shapefile, 1:250,000 | `09_landuse.R` |
| `CLUES` | Catálogo de Clave Única de Establecimientos de Salud | Secretaría de Salud (DGIS) | 2026-07 | Nacional | Establecimiento | XLSX nacional | `09b_health.R` |
| `CEM4` | Continuo de Elevaciones Mexicano 4.0 | INEGI | 2024 (radar ALOS PALSAR 2006–2011) | 32 entidades | Celda de 15 m | GeoTIFF por entidad, EPSG:6365 | `09c_terrain.R` |
| `RED_HIDRO50` | Red Hidrográfica escala 1:50 000, edición 2.0 | INEGI | 2010 | 37 regiones hidrológicas | Línea de flujo | Shapefile por subcuenca | `09c_terrain.R` |
| `CONABIO_COSTA` | Línea de costa de la República Mexicana (2011–2014) | CONABIO | 2018 | Nacional | Línea | Shapefile, 1:25 000 | `09c_terrain.R` |
| `CENAPRED_SITU2023` | Sistema de Indicadores Municipales del Atlas Nacional de Riesgos, republicado por SEDATU en su IDE | CENAPRED; publicación de SEDATU | 2023 (indicadores sociodemográficos del censo 2020) | Nacional | Municipio | WFS, respuesta CSV | `13_hazard.R` |
| `PIPELINE` | Variables derivadas en este repositorio | — | — | — | — | — | ver `SCRIPT` |

## URL de descarga

`{NN}` es la clave de entidad y `{slug}` el nombre de archivo del INEGI (catálogo
`ENTITY_SLUGS` en `00_config.R`).

| ID | URL |
|---|---|
| `MG2020` | `https://www.inegi.org.mx/contenidos/productos/prod_serv/contenidos/espanol/bvinegi/productos/geografia/marcogeo/889463807469/{slug}.zip` |
| `CPV2020_AGEB` | `https://www.inegi.org.mx/contenidos/programas/ccpv/2020/datosabiertos/ageb_manzana/ageb_mza_urbana_{NN}_cpv2020_csv.zip` |
| `CPV2020_ITER` | `https://www.inegi.org.mx/contenidos/programas/ccpv/2020/datosabiertos/iter/iter_{NN}_cpv2020_csv.zip` |
| `CONEVAL_GRS2020` | `https://www.coneval.org.mx/Medicion/Documents/GRS_AGEB_2020/GRS_AGEB_urbana_2020.zip` |
| `DENUE` | `https://www.inegi.org.mx/contenidos/masiva/denue/denue_{NN}_csv.zip` (entidades grandes: `denue_{NN}_{1..6}_csv.zip`) |
| `INEGI_CA50` | `http://www.conabio.gob.mx/informacion/gis/maps/geo/catp50s3gw.zip` |
| `INEGI_USV7` | `http://www.conabio.gob.mx/informacion/gis/maps/geo/usv250s7gw.zip` |
| `CLUES` | `http://gobi.salud.gob.mx/gobi/catalogos/catalogosmaestros/ESTABLECIMIENTO_SALUD_202607.xlsx` |
| `CEM4` | `https://www.inegi.org.mx/app/geo2/elevacionesmex/DownloadFile.do?file=e{NN}_cem_r15_v4_tif.zip&res=15&entidad={NN}` |
| `RED_HIDRO50` | `https://www.inegi.org.mx/contenidos/productos/prod_serv/contenidos/espanol/bvinegi/productos/geografia/hidrogeolo/region_hidrografica/{UPC}_s.zip`, `{UPC}` de 702825006976 a 702825007012 |
| `CONABIO_COSTA` | `http://www.conabio.gob.mx/informacion/gis/maps/geo/lc2018gw.zip` |
| `CENAPRED_SITU2023` | `https://ide.sedatu.gob.mx/geoserver/ows?service=WFS&version=2.0.0&request=GetFeature&typeNames=geonode:{capa}&outputFormat=csv&propertyName=cve_munc,{campo}` — una consulta por capa; el catálogo `capa`/`campo` está en `HAZARD_SOURCES` (`00_config.R`). El portal de descarga es `https://situ.sedatu.gob.mx/descargas/?tema=riesgo` |
| (auxiliar) | `http://www.conabio.gob.mx/informacion/gis/maps/geo/mun22gw.zip`, municipios de CONABIO 2022. No se usa para la cobertura (ver D-08); solo para validar la geocodificación de CLUES |

La URL nacional del MG que aparecía en la especificación original está muerta
(D-02). Las URL se verificaron el 2026-09-15; la de CLUES, el 2026-09-16.

La URL de CLUES lleva la fecha del corte. La DGIS republica el catálogo cada mes
y solo enlaza el más reciente desde
<http://www.dgis.salud.gob.mx/contenidos/intercambio/clues_gobmx.html>. Cuando
el enlace deje de funcionar, toma el vigente de esa página y actualiza
`URL_CLUES`, `CLUES_FILE` y `YEARS$clues` en `00_config.R`.

## Notas por fuente

### Marco Geoestadístico (`MG2020`)
Capas usadas, en `conjunto_de_datos/`:

| Capa | Contenido | Uso |
|---|---|---|
| `{NN}a.shp` | Polígonos de AGEB urbanas (`CVEGEO` de 13 caracteres) | Geometría base |
| `{NN}ar.shp` | Polígonos de AGEB rurales (`CVEGEO` de 9 caracteres, sin localidad) | Geometría base |
| `{NN}mun.shp` | Polígonos municipales | Nombres y control de cobertura |
| `{NN}lpr.shp` | Puntos de localidades rurales, con `CVE_AGEB` | Puente ITER → AGEB rural (D-04) |
| `{NN}l.shp` | Polígonos de localidades urbanas y rurales amanzanadas | Nombres de localidad urbana |
| `{NN}ent.shp` | Polígono de la entidad | Rectángulo envolvente |

Codificación latin-1 (D-09).

### Censo 2020 (`CPV2020_AGEB`, `CPV2020_ITER`)
- **Supresión por confidencialidad** (D-13, D-15, D-16):
  - `*` en conteos de 1 o 2. El producto urbano los suprime siempre; el ITER
    suprime todas las características de localidades de 1–2 viviendas.
  - `N/D`: no disponible.
  - `POBTOT` nunca se suprime.
- Las definiciones oficiales de cada variable están en el diccionario del INEGI
  que acompaña a cada descarga:
  - `diccionario_de_datos/diccionario_datos_ageb_urbana_{NN}_cpv2020.csv`
  - `diccionario_datos/diccionario_datos_iter_{NN}CSV20.csv`

### CONEVAL (`CONEVAL_GRS2020`)
- Libro nacional con un encabezado de tres niveles; los datos empiezan en la
  fila 6.
- Columnas usadas: 8 (clave de AGEB), 11–27 (17 indicadores en porcentaje) y 28
  (grado).
- Existe solo para AGEB urbanas y no incluye un índice continuo (D-23).
- CONEVAL construye estos indicadores con el mismo Censo 2020, lo que permite
  usarlos como validación (D-24).

### DENUE
- Registro administrativo de establecimientos fijos, que no cubre la actividad
  informal ambulante.
- `per_ocu` es un estrato de texto.
- El zip trae también un diccionario en CSV que no debe leerse como datos.

### Capas de CONABIO (`INEGI_CA50`, `INEGI_USV7`)
- Son productos del INEGI redistribuidos por CONABIO en EPSG:4326.
- Se leen recortadas al rectángulo de cada entidad para no cargar el archivo
  nacional completo.

### CLUES
- Libro con tres hojas; se usa la primera (`CLUES_{AAAAMM}`), una fila por
  establecimiento con estatus, tipo, nivel de atención, institución y
  coordenadas.
- Solo se usan unidades `EN OPERACION` (41,225 de 64,133 en el corte 2026-07);
  1,416 no tienen coordenadas.
- **Geocodificación:** 97.4 % cae en su entidad declarada. Las que quedan a más
  de 5 km de ella (940, 2.4 %) se descartan: muchas traen la longitud sin
  signo o coordenadas de otro estado. La prueba usa los municipios de CONABIO.
- Filtros, clases de unidad y método de distancia: fichas de `DIST_HOSP_KM`,
  `DIST_HOSP_PUB_KM` y `DIST_1NIVEL_PUB_KM` en el
  [diccionario](DICCIONARIO_DATOS.md).

### CEM 4.0 (`CEM4`)
- Un GeoTIFF por entidad a ~15 m (0.0001389°), en EPSG:6365 (ITRF2008
  geográficas), con elevaciones sobre el Geoide Gravimétrico Mexicano 2010.
- Derivado de radar ALOS PALSAR (2006–2011); huecos y costas completados con
  MDT LiDAR de 5 m. Cobertura completa en el continente y parcial en islas.
- La URL es la que usa el visor
  <https://www.inegi.org.mx/app/geo2/elevacionesmex/>; su API
  `api/archivo?version=2&opcion=15&clave={NN}` lista el archivo de cada
  entidad. El parámetro `entidad` no afecta la descarga.
- Se descargan las 32 entidades aunque se procese una sola: la pendiente y el
  lecho de los cauces junto a un límite estatal leen celdas del vecino, a
  través de un mosaico virtual (VRT).

### Red Hidrográfica 1:50 000 (`RED_HIDRO50`)
- 37 archivos, uno por región hidrológica, con UPC consecutivos en la
  biblioteca del INEGI. Cada uno trae carpetas por subcuenca; se usa la capa de
  líneas de flujo `{SUBC}_hl.shp`.
- Atributos usados: `ORDER_1` (orden de Strahler). Se conservan los segmentos
  de orden ≥ 3, tanto corrientes (`TIPO` 101) como líneas centrales de cuerpos
  de agua (`TIPO` 103).
- Construida sobre cartas topográficas 1:50 000 de 1995–2002 según la
  subcuenca.

### Línea de costa (`CONABIO_COSTA`)
- Digitalizada sobre imágenes RapidEye de 5 m (2011–2014), escala 1:25 000.
- Se descartan los segmentos con `DESCRIP = "Frontera"` (límites terrestres);
  se conservan costa continental, islas, cayos y bocas de río.

### CENAPRED vía SEDATU (`CENAPRED_SITU2023`)
- El portal publica 32 recursos bajo el tema «Riesgo». 15 de ellos son la
  **misma** tabla municipal (2,469 municipios del Marco Geoestadístico 2020 más
  30 campos sociodemográficos del censo 2020) y se distinguen en **una sola
  columna**, el grado del fenómeno. Por eso el pipeline pide por WFS la clave
  municipal y esa columna (~90 KB por capa) en vez de 15 GeoPackages de ~38 MB
  con los mismos polígonos repetidos.
- Los campos sociodemográficos de la fuente **no se importan**: esta base ya
  calcula esas variables por AGEB y con el tratamiento de supresión del censo.
- Los grados son **clases ordinales**, no magnitudes, y cada fenómeno tiene su
  propia distribución: inundación reparte casi en quintiles (492–496 municipios
  por clase), deslizamientos concentra 1,692 municipios en «Alto», nevadas deja
  2,318 en «Muy bajo» y peligro sísmico nunca usa «Muy bajo». No son
  comparables entre columnas ni promediables entre sí.
- Peligro volcánico y las dos capas de sustancias peligrosas añaden la etiqueta
  «Sin peligro», codificada como 0: es ausencia real de amenaza, no dato
  faltante.
- 12 municipios de creación reciente (02006, 04012, 07120–07125, 17034–17036,
  23011) tienen fila pero campo vacío en sustancias tóxicas, inflamables y
  vulnerabilidad al cambio climático.
- Los otros recursos del tema quedaron fuera: 11 son insumos de altísima
  resolución para tres localidades de Guerrero (ortofotos, MDT, curvas de nivel)
  y los de incidencia delictiva y defunciones por accidentes de transporte están
  fuera del marco climático que sigue esta base.

## Licencias y cita

| Fuente | Condiciones |
|---|---|
| INEGI (MG, censo, DENUE) | Términos de libre uso de la información del INEGI: uso libre citando la fuente. |
| CONEVAL | Información pública; citar a CONEVAL como fuente. |
| INEGI (CEM, Red Hidrográfica) | Términos de libre uso de la información del INEGI: uso libre citando la fuente. |
| Secretaría de Salud (CLUES) | Datos abiertos del Gobierno de México; citar a la Secretaría de Salud / DGIS como fuente. |
| Capas vía CONABIO | **CC BY-NC 2.5 México**: citar al INEGI y a CONABIO, **sin fines de lucro**. |
| CENAPRED / SEDATU | Datos abiertos publicados por SEDATU; citar a CENAPRED como autor de los indicadores y a SEDATU como quien los publica. La ficha de cada capa advierte que «SEDATU no se hace responsable por el uso que se le den a estos datos». |

Si se publica un producto derivado de esta base, conviene citar:

- INEGI (2020). *Marco Geoestadístico, censo de población y vivienda 2020.*
- INEGI (2021). *Censo de Población y Vivienda 2020: principales resultados por
  AGEB y manzana urbana; principales resultados por localidad (ITER).*
- CONEVAL. *Grado de Rezago Social por AGEB urbana 2020.*
- INEGI. *Directorio Estadístico Nacional de Unidades Económicas*, versión
  2026-05.
- Secretaría de Salud, DGIS. *Catálogo de Clave Única de Establecimientos de
  Salud (CLUES)*, corte 2026-07.
- INEGI (2024). *Continuo de Elevaciones Mexicano 4.0*, resolución 15 m.
- INEGI (2010). *Red Hidrográfica escala 1:50 000, edición 2.0.*
- CONABIO (2018). *Línea de costa de la República Mexicana (2011–2014)*, escala
  1:25 000.
- INEGI (2022). *Cuerpos de agua. Continuo Nacional Topográfico, escala
  1:50 000, serie III.* Distribuido por CONABIO.
- INEGI (2021). *Uso de suelo y vegetación, escala 1:250 000, serie VII.*
  Distribuido por CONABIO.
- CENAPRED. *Sistema de Indicadores Municipales del Atlas Nacional de Riesgos*,
  actualización 2023. Publicado por SEDATU en su infraestructura de datos
  espaciales (SITU).
