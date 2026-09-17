# Base de datos AGEB — México

Pipeline en R que construye una tabla con **una fila por AGEB**, urbanas *y*
rurales, para las 32 entidades, de forma reproducible e idempotente. Es la base
para un **índice de vulnerabilidad climática**: reúne población, rezago social,
vivienda, servicios, empleo, acceso a salud, actividad económica, cuerpos de
agua y uso de suelo sobre la geometría oficial del INEGI, junto con la
exposición física (relieve, cauces y costa) que se cruza aparte.

Convención: prosa en español; nombres de archivos, variables y comentarios de
código en inglés. CSV en UTF-8, separador coma.

## Documentación

| Documento | Para qué |
|---|---|
| [docs/DICCIONARIO_DATOS.md](docs/DICCIONARIO_DATOS.md) | Qué es cada columna: descripción, unidad, fórmula, universo, fuente, cobertura y qué significa un vacío |
| [docs/diccionario_datos.csv](docs/diccionario_datos.csv) | Lo mismo en formato tabular, para leer desde R o Python. Es la fuente única del diccionario |
| [docs/DATA_DICTIONARY.md](docs/DATA_DICTIONARY.md), [docs/data_dictionary.csv](docs/data_dictionary.csv) | Versión en inglés del diccionario, fila por fila igual a la española |
| [docs/DECISIONES.md](docs/DECISIONES.md) | Por qué la base es como es: 30 decisiones con evidencia, controles de calidad, problemas conocidos y pendientes |
| [docs/FUENTES.md](docs/FUENTES.md) | Fuentes, URL, años, codificaciones, licencias y cómo citarlas |

Si vas a **usar** los datos, empieza por el diccionario. Si vas a **modificar**
el pipeline, lee antes las decisiones.

## Requisitos

R 4.6 en macOS arm64 todavía no tiene binarios en CRAN, así que el stack
espacial se compila desde fuente y necesita librerías de sistema:

```bash
brew install gdal geos proj udunits gcc cmake abseil
```

```bash
Rscript -e 'install.packages(c("sf","terra","units","classInt","s2","janitor"), type="source")'
```

Paquetes de CRAN adicionales: `dplyr`, `readr`, `stringr`, `tidyr`, `purrr`,
`curl`, `readxl`, `rlang` y, para los mapas, `ggplot2` y `scales`.

`~/.R/Makevars` debe apuntar al `gfortran` de Homebrew, porque R espera
`/opt/gfortran`, que no existe con esta instalación:

```
FC = /opt/homebrew/bin/gfortran
F77 = /opt/homebrew/bin/gfortran
FLIBS = -L/opt/homebrew/opt/gcc/lib/gcc/current -lgfortran -lemutls_w -lquadmath
```

## Ejecución

```bash
Rscript run_all.R 20
```

```bash
Rscript run_all.R
```

Sin argumentos procesa las 32 entidades y consolida el nacional; con
argumentos, solo esas entidades. Las descargas se cachean en `data/raw/` (~30 GB)
y cada bloque intermedio en `data/interim/`. Volver a correr reutiliza lo que ya
existe; para recalcular un bloque, borra su `.rds` en `data/interim/`. Una
corrida nacional desde cero tarda bastante más que antes: el relieve de las 32
entidades toma ~70 min, más la construcción única de la capa nacional de cauces
(1.6 millones de segmentos) y la descarga de ~11 GB de elevación e hidrografía.

Después de cambiar el diccionario, edita **los dos** CSV (`docs/diccionario_datos.csv`
y `docs/data_dictionary.csv`, en inglés) y regenera ambos documentos legibles:

```bash
Rscript docs/build_diccionario.R
```

La exportación **falla** si una columna del CSV no está en alguno de los dos
diccionarios, o si alguno tiene columnas de más o en otro orden.

## Estructura

| Script | Qué hace | Salida intermedia |
|---|---|---|
| `R/00_config.R` | Rutas, catálogo de entidades, CRS, URL, tolerancias | — |
| `R/01_utils.R` | Descargas validadas, llaves, lectores | — |
| `R/02_download.R` | Descarga y extrae todas las fuentes | `data/raw/` |
| `R/03_boundaries.R` | AGEB urbanas y rurales, municipios y puente de localidades del MG | `ageb_attrs`, `ageb_geom`, `municipios`, `locality_bridge` |
| `R/04_census_urban.R` | Censo por AGEB urbana y catálogo de variables censales | `census_urban` |
| `R/05_census_rural.R` | ITER agregado a AGEB rural | `census_rural` |
| `R/06_coneval.R` | GRS e indicadores `RZ_*` de CONEVAL | `coneval` |
| `R/07_denue.R` | Unidades económicas por AGEB | `denue*` |
| `R/08_hydrology.R` | Cuerpos de agua por AGEB | `hydrology` |
| `R/09_landuse.R` | Uso de suelo y vegetación por AGEB | `landuse*` |
| `R/09b_health.R` | Distancia a hospitales y unidades de primer nivel (CLUES) | `health`, `clues_facilities_MX` |
| `R/09c_terrain.R` | Elevación, pendiente, cauces y costa (CEM 4.0, Red Hidrográfica, CONABIO) | `terrain`, `streams_MX`, `coast_MX` |
| `R/10_build.R` | Ensambla todo y calcula los indicadores | `complete` |
| `R/11_qc.R` | 31 controles de calidad por entidad | `quality_control_report_*` |
| `R/12_export.R` | CSV, GeoPackage y consolidado nacional | `data/processed/` |
| `R/13_hazard.R` | Grados municipales de peligro de CENAPRED, vía SEDATU | `hazard`, `hazard_national` |
| `maps/map_municipio.R` | Mapa de control visual de la malla de un municipio | `maps/*.png` |

## Salidas (`data/processed/`)

| Archivo | Contenido |
|---|---|
| `ageb_indicadores_{ENT}.csv` | 184 columnas, una fila por AGEB |
| `ageb_indicadores_MX.csv` | Concatenado nacional |
| `ageb_geom_{ENT}.gpkg` | Geometría AGEB en EPSG:4326 con el bloque de identificación |
| `quality_control_report_{ENT}.csv`, `_MX.csv` | 31 controles por entidad |
| `qc_municipal_coverage_{ENT}.csv` | Detalle de cobertura por municipio |
| `denue_establishments_{ENT}.csv`, `denue_ageb_sector_{ENT}.csv`, `ageb_landuse_detail_{ENT}.csv` | Tablas de detalle |

Lee el CSV **siempre** con las claves como texto, o se pierden los ceros a la
izquierda:

```r
readr::read_csv("data/processed/ageb_indicadores_MX.csv",
                col_types = readr::cols(ID_AGEB = "c", CVE_ENT = "c",
                                        CVE_MUN = "c", CVE_LOC = "c",
                                        CVE_AGEB = "c"))
```

## Contenido del CSV

| Bloque | Columnas | Ámbito |
|---|---|---|
| Identificación y geometría | `ID_AGEB`, claves y nombres, `AREA_KM2`, punto representativo | Ambos |
| Población base | `POB_TOTAL`, sexo, `DENS_POB_KM2`, `POB_POR_VIV`, viviendas | Ambos |
| Confiabilidad | `POB_REPORTADA`, `PCT_POB_REPORTADA`, `N_CELDAS_IMPUTADAS` | Ambos |
| Sensibilidad | `PCT_POB_0A5`, `PCT_POB_65YMAS`, `PCT_POB_DISC`, `PCT_POB_HLI`, `PCT_POB_HLI_NHE`, `PCT_HOG_JEFA` | Ambos |
| Rezago social (equivalentes de CONEVAL) | `PCT_ANALF`, `PCT_NOASIS_6A14`, `PCT_NOASIS_15A24`, `PCT_EDU_BAS_INC`, `PCT_POB_SIN_SALUD`, `GRAPROES`, `PRO_OCUP_C` | Ambos |
| Empleo | `PCT_PEA`, `PCT_PEA_F`, `PCT_DESOCUP` | Ambos |
| Vivienda y servicios | `PCT_VIV_SIN_DRENAJE`, `PCT_VIV_SIN_ELECTRIC`, `PCT_VIV_SIN_AGUA`, `PCT_VIV_SIN_SANITARIO`, `PCT_VIV_PISO_TIERRA`, `PCT_VIV_1CUARTO`, `PCT_DRENAJE`, `PCT_ELECTRIC` | Ambos |
| Agua, bienes y comunicación | `PCT_VIV_TINACO`, `PCT_VIV_CISTERNA`, `PCT_VIV_REFRI`, `PCT_VIV_LAVADORA`, `PCT_VIV_AUTO`, `PCT_VIV_SIN_BIENES`, `PCT_VIV_RADIO`, `PCT_VIV_TELEFONO`, `PCT_VIV_CELULAR`, `PCT_VIV_INTERNET`, `PCT_VIV_COMPU`, `PCT_VIV_SIN_RADIO_TV`, `PCT_VIV_SIN_TEL_CEL`, `PCT_VIV_SIN_TIC` | Ambos |
| Validación CONEVAL | `GRS_GRADO`, `GRS_NUM`, 17 `RZ_*` | Solo urbana |
| Actividad económica | `DENUE_TOT`, `DEN_MANUF`, `DEN_COM`, `DEN_SERV`, `DEN_EDU`, `DEN_GOB`, `SCHOOL_TOT` | Ambos |
| Agua y uso de suelo | `WATER_AREA`, `WATER_PCT`, `HAS_WATER`, `USO_DOM`, `USO_PCT`, `PCT_URB` | Ambos |
| Acceso a salud | `DIST_HOSP_KM`, `DIST_HOSP_PUB_KM`, `DIST_1NIVEL_PUB_KM`, `DIST_ORIGEN` | Ambos |
| Relieve y exposición | `ELEV_M`, `PEND_MEDIA_GRAD`, `PCT_PEND_15`, `PCT_PEND_30`, `DIST_CAUCE_KM`, `DIST_COSTA_KM`, `DESNIVEL_CAUCE_M` | Ambos |
| Amenaza (municipal) | 13 `AMZ_*` de peligro CENAPRED, más `CEN_RESIL` y `CEN_VULN_CC` | Ambos |
| Conteos censales | 51 conteos, para reagregar a otras geografías | Ambos |
| Metadatos | `YEAR_*` | Ambos |

## Validación

Corrida nacional completa (32 entidades, 2026-09-17):

| | |
|---|---|
| AGEB | **81,451** = 63,982 urbanas + 17,469 rurales |
| Municipios | 2,469 |
| `sum(POB_TOTAL)` | **126,014,024**, idéntico al Censo 2020 (diferencia 0) |
| Superficie | 1,956,075 km² |
| Controles de calidad | **992 / 992 PASS** (31 por entidad) |
| DENUE | 6,117,578 unidades, 150,067 escuelas |
| Con GRS | 61,430 de 63,982 urbanas (96 %) |
| Población con indicadores censales | 99.97 % urbana, 99.93 % rural |
| Concordancia con CONEVAL | error medio ponderado de 0.03–0.52 puntos, r ≥ 0.96 en los 16 indicadores comparables |
| Empleo | participación 62.2 %, femenina 49.1 %, desocupación 1.9 % (sumado desde las AGEB) |
| Acceso a salud | mediana a hospital público: 3.3 km urbana, 21.6 km rural; 2.8 % de la población a más de 30 km |
| CLUES | 41,225 unidades en operación; 940 descartadas por geocodificación fuera de su entidad |
| Relieve y exposición | 0 AGEB habitadas sin elevación; 17.6 % de la población a < 1 km de un cauce de orden ≥ 3 y < 5 m sobre el agua; 2.4 % a < 10 km de la costa y < 10 m de altitud |
| Amenaza (CENAPRED) | 2,469 de 2,469 municipios empatados; 0 AGEB sin grado. Población en peligro Alto o Muy alto: inundación 64.1 %, deslizamientos 57.3 %, ondas cálidas 23.3 %, sequía 12.0 %, ciclones 6.9 % |

La población cuadra exacta también por entidad: Oaxaca 4,132,148; CDMX 9,209,944;
Estado de México 16,992,418.

## Decisiones clave

El detalle y la evidencia de cada una están en [docs/DECISIONES.md](docs/DECISIONES.md).

- **El Marco Geoestadístico es la columna vertebral** (D-01): cubre todo el
  territorio, sin huecos municipales. Su URL nacional está muerta; se descarga
  por entidad (D-02).
- **Las AGEB rurales se construyen desde el ITER** (D-04, D-11), sumando
  localidades por grupo de variables para que una ranchería suprimida no borre a
  toda su AGEB (D-13). Esto recuperó el perfil de vivienda del 58 % de la
  población rural de Oaxaca.
- **Una AGEB rural sin localidades es deshabitada**, con población 0 y no `NA`
  (D-12). El ITER nunca suprime `POBTOT`.
- **Las celdas urbanas suprimidas se imputan como 1.5** (D-15): el censo urbano
  nunca publica un 1 ni un 2. `N_CELDAS_IMPUTADAS` lo registra.
- **Los porcentajes de vivienda dividen entre `VIV_CARACT`** y no entre
  `TVIVPARHAB` (D-18). Las carencias usan los conteos directos «sin» (D-19).
- **Los indicadores de CONEVAL se recalculan desde el censo para ambos ámbitos**
  (D-22). El GRS de CONEVAL, solo urbano, queda como validación (D-23, D-24).
- **El empleo divide entre la población con condición de actividad
  especificada** (`PEA + PE_INAC`), no entre `P_12YMAS`, por la misma razón que
  vivienda usa `VIV_CARACT`.
- **El acceso a salud se mide desde donde vive la gente**: en AGEB rurales, desde
  sus localidades habitadas ponderadas por población, no desde el centro del
  polígono. Se descartan las unidades CLUES geocodificadas a más de 5 km de su
  entidad.
- **La amenaza queda fuera del índice de vulnerabilidad** (D-30), siguiendo el
  marco del IPCC AR6. Las columnas de relieve y exposición se publican por tipo
  de amenaza para cruzarse después.
- **El relieve se lee donde vive la gente**: en AGEB rurales, en discos de
  150 m alrededor de cada localidad habitada, no sobre toda la sierra que
  cubre el polígono.
- **Solo cuentan cauces de orden de Strahler ≥ 3**; a escala 1:50 000 casi
  cualquier punto está junto a un arroyo de orden 1. El desnivel se mide contra
  el agua más cercana, cauce o mar.

## Limitaciones y pendientes

Ver [problemas conocidos](docs/DECISIONES.md#problemas-conocidos) y
[pendientes](docs/DECISIONES.md#pendientes). Lo más importante:

- **Universos minúsculos:** en AGEB con pocas viviendas o personas los
  porcentajes son ruido. Filtra o pondera por tamaño y confiabilidad.
- **GRS y `RZ_*` son solo urbanos**; para comparar ámbitos usa los equivalentes
  censales.
- **No hay índice continuo de rezago (IRS) por AGEB**, solo el grado.
- **Entorno urbano** (banqueta, recubrimiento, drenaje pluvial, árboles):
  pendiente. Es otro producto del INEGI, no viene en el CSV del censo.
- **Amenaza climática:** hay exposición por relieve, cauces y costa, y los
  grados municipales de CENAPRED (`13_hazard.R`), cuya resolución es el
  municipio: todas las AGEB de uno comparten valor y las clases son ordinales,
  no magnitudes. Faltan calor (temperatura superficial, días extremos) y lluvia
  extrema con resolución intraurbana.
- **`DESNIVEL_CAUCE_M` aproxima HAND** con el cauce más cercano en planta, no
  con la trayectoria real del agua: puede ser negativo en laderas cuyo cauce más
  cercano corre en el valle vecino, y no considera bordos ni capacidad del
  cauce.
- **El índice de vulnerabilidad todavía no existe**: esta base es su insumo.
- **Acceso a salud en línea recta:** `DIST_*_KM` ordena el acceso pero no es
  tiempo de traslado; lo subestima en la sierra.
- **Desocupación poco informativa:** el censo cuenta el trabajo informal como
  ocupación (tasa de 1.7–2.3 %); la participación femenina discrimina más.
- **Años mixtos** entre fuentes; se registran en las columnas `YEAR_*`.
- **Licencia:** las capas de CONABIO son CC BY-NC 2.5 MX (sin fines de lucro).
