# Base de datos AGEB — México

Pipeline en R que construye una tabla **una fila por AGEB** (urbanas *y* rurales)
con todos los indicadores descritos en `PROYECTO_AGEB_instrucciones.md`, para las
32 entidades, de forma reproducible e idempotente.

Convención: prosa en español; nombres de archivos, variables y comentarios de
código en inglés. CSV en UTF-8, separador coma.

## Requisitos

R 4.6 en macOS arm64 todavía no tiene binarios en CRAN, así que el stack
espacial se compila desde fuente y necesita librerías de sistema:

```bash
brew install gdal geos proj udunits gcc cmake abseil
```

```bash
Rscript -e 'install.packages(c("sf","terra","units","classInt","s2","janitor"), type="source")'
```

`~/.R/Makevars` debe apuntar al `gfortran` de Homebrew (R espera `/opt/gfortran`,
que no existe con esta instalación):

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

Sin argumentos procesa las 32 entidades y consolida el nacional. Con argumentos,
solo esas entidades. Todo se cachea en `data/raw/`; volver a correr reutiliza
descargas y bloques ya construidos.

## Salidas (`data/processed/`)

| Archivo | Contenido |
|---|---|
| `ageb_indicadores_{ENT}.csv` | 62 columnas, una fila por AGEB (esquema §7 de la spec) |
| `ageb_indicadores_MX.csv` | concatenado nacional |
| `ageb_geom_{ENT}.gpkg` | geometría AGEB en EPSG:4326 con el bloque de identificación |
| `quality_control_report_{ENT}.csv` | 17 controles (§8) |
| `qc_municipal_coverage_{ENT}.csv` | detalle de cobertura por municipio |
| `denue_establishments_{ENT}.csv`, `denue_ageb_sector_{ENT}.csv`, `ageb_landuse_detail_{ENT}.csv` | tablas de detalle |

Leer el CSV **siempre** con `ID_AGEB` como texto, o se pierden los ceros a la izquierda:

```r
readr::read_csv("ageb_indicadores_20.csv",
                col_types = readr::cols(ID_AGEB = "c", CVE_ENT = "c",
                                        CVE_MUN = "c", CVE_LOC = "c",
                                        CVE_AGEB = "c"))
```

## Hallazgos que corrigen la especificación

1. **El Marco Geoestadístico sí se descarga automáticamente.** La URL de la spec
   (`…/marcogeo/889463807469_s.zip`) está muerta: INEGI responde HTTP **200** con
   una página *"Esta liga ya no existe"*, que es lo que antes se leyó como 503.
   Las descargas vivas son **por entidad**, dentro de una carpeta con el id del
   producto (`…/marcogeo/889463807469/20_oaxaca.zip`). No hace falta bajar nada
   a mano, y por lo tanto **sí hay cobertura territorial completa**.
2. **Las AGEB rurales no tienen `CVE_LOC`** (su `CVEGEO` es de 9 caracteres). Para
   mantener una sola llave de 13 se les asigna `CVE_LOC = "0000"`. El DENUE sí
   reporta la localidad real, así que su llave se resuelve en dos pasos (urbana,
   luego rural); sin eso se pierde ~4 % de los establecimientos.
3. **`{ENT}lpr.shp` es el puente localidad→AGEB rural**: contiene `CVE_AGEB` y
   cubre todas las localidades rurales (las de `{ENT}l.shp` son un subconjunto).
4. **El censo urbano trae AGEB que el marco no reconoce.** En Oaxaca son 8
   localidades de ~2,500–3,700 habitantes que el MG asigna a una AGEB **rural**;
   su población ya llega por el ITER. La geometría es la columna vertebral y el
   ensamble las descarta, evitando un doble conteo de 22,368 personas.
   `NOM_LOC` del censo urbano es inservible (siempre `"Total AGEB urbana"`): los
   nombres reales salen de las capas de localidad del MG.
5. **Encodings mezclados:** el MG es latin-1 (su `.cpg` dice `ISO 88591`, que GDAL
   no entiende); censo, ITER y las capas de CONABIO son UTF-8. Forzar latin-1 en
   CONABIO produce mojibake. Además hay que fijar locale UTF-8 en R o los acentos
   se escriben como `<U+00E1>`.
6. **Los zips del INEGI traen nombres de archivo latin-1** (`léeme.pdf`): el unzip
   interno de R aborta y el `unzip` del sistema se cuelga esperando un prompt
   invisible. Se extrae con `bsdtar`.
7. **AGEB rurales deshabitadas:** 181 en Oaxaca no cruzan con ninguna localidad
   del ITER, no tienen localidad en el marco y tienen 0 establecimientos DENUE.
   Se registran con población **0**, no `NA`: el dato no es desconocido.
8. **Tolerancia de cobertura:** sumada por entidad, el área de las AGEB coincide
   con la municipal (93,959.81 vs 93,959.80 km² en Oaxaca). En municipios muy
   chicos una diferencia de digitización de ~0.05 km² supera el 1 % relativo sin
   ser un hueco, así que el control exige rebasar **ambos** umbrales, relativo y
   absoluto (`COVERAGE_TOL_PCT`, `COVERAGE_TOL_KM2`).

## Validación

Corrida nacional completa (32 entidades, ~29 min, ~19 GB de fuentes en caché):

| | |
|---|---|
| AGEB | **81,451** = 63,982 urbanas + 17,469 rurales |
| Municipios | 2,469 |
| `sum(POB_TOTAL)` | **126,014,024** — idéntico al Censo 2020 (diferencia 0) |
| Superficie | 1,956,075 km² |
| Controles de calidad | **576 / 576 PASS** (18 por entidad) |
| DENUE | 6,117,578 unidades, 150,067 escuelas |
| Con GRS | 61,430 de 63,982 urbanas (96 %) |

La población cuadra exacto también por entidad: Oaxaca 4,132,148; CDMX 9,209,944;
Estado de México 16,992,418.

### Sobre la cobertura municipal

El control distingue dos cosas que suelen confundirse:

- **Hueco real:** territorio que ninguna AGEB cubre. No hay ninguno.
- **Atribución de frontera:** el territorio está completo, pero la capa de AGEB y
  la capa municipal *del mismo marco* no coinciden en qué municipio se lleva una
  franja. Ocurre en el propio dato del INEGI — en Puebla, Coronango aparece con
  −0.6568 km² y Cuautlancingo con +0.6568 km²: la misma franja, contada una sola
  vez. Se reporta, no se marca como falla.

## Limitaciones vigentes

- **GRS/`RZ_*` son urbanos** (producto CONEVAL): las AGEB rurales quedan `NaN`.
  En Oaxaca hay GRS en 2,604 de 2,658 urbanas; el resto lo suprime CONEVAL.
- **IRS continuo no existe a nivel AGEB**, solo el grado.
- **Entorno urbano** (`BANQUETA`, `RECUBRIMIENTO`, `ALUMBRADO`) sigue pendiente:
  es nivel manzana y no se incluye para no inventar ceros.
- **Años mixtos** entre fuentes; se conservan en las columnas `YEAR_*`.
