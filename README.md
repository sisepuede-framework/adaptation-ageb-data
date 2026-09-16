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
| `ageb_indicadores_{ENT}.csv` | 145 columnas, una fila por AGEB (esquema §7 de la spec + indicadores censales de vulnerabilidad, ver abajo) |
| `ageb_indicadores_MX.csv` | concatenado nacional |
| `ageb_geom_{ENT}.gpkg` | geometría AGEB en EPSG:4326 con el bloque de identificación |
| `quality_control_report_{ENT}.csv` | 23 controles (§8) |
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
   Se registran con población **0**, no `NA`: el dato no es desconocido. La
   bandera sale del cruce (ninguna localidad del ITER), no de un `NA` en
   `POBTOT`; `05_census_rural.R` aborta si el INEGI llegara a suprimir `POBTOT`,
   porque entonces un `NA` ya no significaría territorio vacío.
8. **Tolerancia de cobertura:** sumada por entidad, el área de las AGEB coincide
   con la municipal (93,959.81 vs 93,959.80 km² en Oaxaca). En municipios muy
   chicos una diferencia de digitización de ~0.05 km² supera el 1 % relativo sin
   ser un hueco, así que el control exige rebasar **ambos** umbrales, relativo y
   absoluto (`COVERAGE_TOL_PCT`, `COVERAGE_TOL_KM2`).
9. **Supresión en el ITER y AGEB rurales.** El ITER nunca suprime `POBTOT`, pero
   en localidades de 1–2 viviendas pone `*` en todo lo demás, y algunas
   localidades publican sexo con vivienda `N/D`. Sumar sin `na.rm` hacía que una
   sola ranchería dejara en `NA` a toda su AGEB: en Oaxaca, 57 % de las AGEB
   rurales habitadas (58 % de la población rural) perdían `PCT_DRENAJE` para
   ocultar al 0.6 % de esa población. Ahora cada grupo de variables
   (`CENSUS_GROUPS`: sexo, personas, vivienda) se suma sobre las localidades que lo
   reportan completo, y los porcentajes dividen entre la población de esas mismas
   localidades (`POB_DEN_*`, solo en tablas intermedias). En Oaxaca las AGEB
   rurales sin `PCT_DRENAJE` bajan de 884 a 235 (181 deshabitadas + 54 cuyas
   localidades están todas suprimidas), sin cambiar ningún valor que ya existía.

   Columnas nuevas: `POB_REPORTADA` es la población de las localidades que
   publican todas sus características, y `PCT_POB_REPORTADA` su proporción sobre
   `POB_TOTAL`. Úsala como indicador de confiabilidad de los porcentajes rurales.
   En AGEB urbanas la supresión es por celda y no hay agregación, así que
   `POB_REPORTADA = POB_TOTAL` salvo que el INEGI suprima la fila entera.

   Nacionalmente 98.45 % de la población rural vive en localidades que publican
   sus características: de 88.7 % en Baja California Sur (ranchos dispersos) a
   99.8 % en Tabasco, cifras verificadas contra un conteo directo del ITER.
10. **El censo urbano nunca publica un 1 ni un 2.** En las 64,313 filas de AGEB
    urbana no hay una sola celda con esos valores, mientras que 0 y 3 son
    comunes: el INEGI los reemplaza por `*`. El ITER sí los publica. Dejarlos en
    `NA` borraba justo los conteos de carencias raras en las AGEB menos
    carenciadas (sin electricidad: 34 % de la población urbana), un faltante no
    aleatorio que sesgaría cualquier índice. Cada `*` en una fila urbana publicada
    se imputa como **1.5** (error máximo ±0.5) y `N_CELDAS_IMPUTADAS` cuenta
    cuántas celdas se imputaron por AGEB (253,460 en 55,573 AGEB). Las filas
    suprimidas completas (AGEB de 1–2 viviendas, marcadas por `GRAPROES = *`) no
    se imputan y quedan `NA`, con `POB_REPORTADA = 0`.
11. **El universo de las características de vivienda no es `TVIVPARHAB`.** Los
    `VPH_*` describen solo las viviendas cuyas características se captaron;
    `TVIVPARHAB` incluye además viviendas sin información de ocupantes. Donde la
    no respuesta es alta, dividir entre `TVIVPARHAB` infla las carencias: una AGEB
    de CDMX con 446 viviendas y 187 celulares daba 58 % sin celular contra 2.6 %
    de CONEVAL. Los porcentajes de vivienda dividen ahora entre `VIV_CARACT`, la
    mayor de las cotas inferiores de ese universo (pares con + sin, y cada
    conteo), acotada por `TVIVPARHAB`. **Esto cambia `PCT_DRENAJE` y
    `PCT_ELECTRIC`**: su error contra CONEVAL baja de 0.455 a 0.056 puntos; en 99 %
    de las AGEB el cambio es menor a 5.2 puntos.

## Indicadores censales de vulnerabilidad

Todos vienen del Censo 2020 y existen para AGEB urbanas **y** rurales, con las
mismas definiciones. El catálogo vive en `04_census_urban.R` (`CENSUS_VARS`,
`CENSUS_GROUPS`) y las fórmulas en `10_build.R`. Se publican los porcentajes y,
al final del CSV, los conteos, para reagregar a otras geografías.

| Dimensión | Columnas |
|---|---|
| Sensibilidad | `PCT_POB_0A5`, `PCT_POB_65YMAS`, `PCT_POB_DISC`, `PCT_POB_HLI`, `PCT_POB_HLI_NHE` (lengua indígena sin español), `PCT_HOG_JEFA` |
| Rezago (equivalentes de CONEVAL) | `PCT_ANALF`, `PCT_NOASIS_6A14`, `PCT_NOASIS_15A24`, `PCT_EDU_BAS_INC`, `PCT_POB_SIN_SALUD`, `GRAPROES`, `PRO_OCUP_C` |
| Servicios de la vivienda | `PCT_VIV_SIN_DRENAJE`, `PCT_VIV_SIN_ELECTRIC`, `PCT_VIV_SIN_AGUA`, `PCT_VIV_SIN_SANITARIO`, `PCT_VIV_PISO_TIERRA`, `PCT_VIV_1CUARTO` |
| Agua y almacenamiento | `PCT_VIV_TINACO`, `PCT_VIV_CISTERNA` |
| Bienes y movilidad | `PCT_VIV_REFRI`, `PCT_VIV_LAVADORA`, `PCT_VIV_AUTO`, `PCT_VIV_SIN_BIENES` |
| Comunicación y alertas | `PCT_VIV_RADIO`, `PCT_VIV_TELEFONO`, `PCT_VIV_CELULAR`, `PCT_VIV_INTERNET`, `PCT_VIV_COMPU`, `PCT_VIV_SIN_RADIO_TV`, `PCT_VIV_SIN_TEL_CEL`, `PCT_VIV_SIN_TIC` |

Las carencias salen de los conteos "sin" del propio censo, nunca de `100 − con`:
para carencias raras, las viviendas con el dato no especificado dominan la
señal (sin electricidad contra CONEVAL: r = 0.98 directo, 0.82 por complemento).
La única excepción es `PCT_VIV_SIN_SANITARIO`, que no tiene conteo directo; como
CONEVAL, cuenta la letrina como sanitario.

**Validación externa.** CONEVAL calculó sus `RZ_*` urbanos con el mismo censo,
así que en las 63,982 AGEB urbanas cada equivalente se compara contra ellos. La
diferencia absoluta media ponderada por población es de 0.02–0.04 puntos en los
indicadores de un solo conteo, y de 0.10–0.52 en los compuestos (educación básica
incompleta suma cuatro conteos); r ≥ 0.96 en los 16. El control
`census_shares_agree_with_coneval_rz` falla por entidad si algún indicador rebasa
su techo (`CONEVAL_MAX_WMAE`), calibrado con fórmulas deliberadamente rotas: un
universo o denominador equivocado da 0.24–15 puntos. El hacinamiento no se
compara: `RZ_HACIN` es un porcentaje de viviendas y el censo solo publica el
promedio de ocupantes por cuarto (`PRO_OCUP_C`).

**Para el índice:** en AGEB con universos minúsculos (unas cuantas personas de
15–24 años, o pocas viviendas) los porcentajes son ruido: 1.5 de 1.5 da 0 % o
100 % donde el dato exacto podría ser 50 %. Conviene filtrar o suavizar por
tamaño (p. ej. `VIV_CARACT`, `POB_TOTAL`) y usar `PCT_POB_REPORTADA` y
`N_CELDAS_IMPUTADAS` como indicadores de confiabilidad.

## Validación

Corrida nacional completa (32 entidades, ~29 min desde cero, ~19 GB de fuentes en caché):

| | |
|---|---|
| AGEB | **81,451** = 63,982 urbanas + 17,469 rurales |
| Municipios | 2,469 |
| `sum(POB_TOTAL)` | **126,014,024** — idéntico al Censo 2020 (diferencia 0) |
| Superficie | 1,956,075 km² |
| Controles de calidad | **736 / 736 PASS** (23 por entidad) |
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
  En Oaxaca hay GRS en 2,604 de 2,658 urbanas; el resto lo suprime CONEVAL. Para
  comparar ámbitos usa los equivalentes censales, que cubren ambos.
- **IRS continuo no existe a nivel AGEB**, solo el grado.
- **Entorno urbano** (`BANQUETA`, `RECUBRIMIENTO`, `ALUMBRADO`, drenaje pluvial)
  sigue pendiente: no viene en el CSV `ageb_mza_urbana` del censo sino en un
  producto aparte del INEGI (características del entorno urbano por frente de
  manzana), que habría que descargar y agregar ponderando por viviendas.
- **Años mixtos** entre fuentes; se conservan en las columnas `YEAR_*`.
