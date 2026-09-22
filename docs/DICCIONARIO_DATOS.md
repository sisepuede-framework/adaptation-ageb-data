# Diccionario de datos

<!-- Generado por docs/build_diccionario.R a partir de docs/diccionario_datos.csv. No editar a mano. -->

*English version: [DATA_DICTIONARY.md](DATA_DICTIONARY.md).*

Describe cada columna de las tablas que produce el pipeline. La fuente única es
[`diccionario_datos.csv`](diccionario_datos.csv), que se puede leer desde R o Python;
este documento se regenera con `Rscript docs/build_diccionario.R`. El *porqué* de
cada regla está en [DECISIONES.md](DECISIONES.md) (identificadores `D-nn`) y las
fuentes en [FUENTES.md](FUENTES.md).

## Cómo leer este diccionario

| Campo | Significado |
|---|---|
| `TIPO` | `texto`, `entero`, `decimal`, `decimal (conteo)`: conteo que puede traer .5 por la imputación urbana (D-15), `categórica`, `binaria`, `geometría` |
| `UNIDAD` | Unidad física. Los porcentajes van de 0 a 100, no de 0 a 1 |
| `DECIMALES` | Redondeo aplicado al exportar; vacío = sin redondeo |
| `AMBITO` | `Ambos` o `Solo urbana` |
| `FUENTE` | Identificador de [FUENTES.md](FUENTES.md); `PIPELINE` = calculada aquí |
| `VARIABLE_FUENTE` | Nombre de la variable en la fuente original (mnemónico del INEGI, columna de CONEVAL, etc.) |
| `DERIVACION` | Fórmula o regla de construcción |
| `UNIVERSO` | Denominador de un porcentaje o promedio |
| `NA_SIGNIFICA` | Por qué puede venir vacía (códigos abajo) |
| `DIMENSION_IVC` | Papel **sugerido** en un índice de vulnerabilidad climática; no es una decisión tomada (D-30) |
| `SENTIDO_SUGERIDO` | `+`: un valor mayor indica más vulnerabilidad; `−`: menos; `±`: ambiguo o depende de la amenaza; `n/a`: no aplica |

**Códigos de `NA_SIGNIFICA`**

| Código | Significado |
|---|---|
| `S` | **Supresión** del INEGI o CONEVAL: AGEB urbana suprimida entera (1–2 viviendas), o AGEB rural cuyas localidades suprimen todas ese grupo de variables (D-13, D-16) |
| `E` | **Estructural**: el dato no existe para ese ámbito (p. ej. CONEVAL en AGEB rurales) |
| `D0` | **Denominador cero**: el universo del porcentaje es 0 (p. ej. AGEB deshabitada, o sin población de 6–14 años) |
| `C` | **No calculable** por geometría o coordenadas (se explica en la columna) |
| `Nunca` | La columna siempre trae valor; un 0 es un cero real |

**Advertencias generales**

- Lee `ID_AGEB`, `CVE_ENT`, `CVE_MUN`, `CVE_LOC` y `CVE_AGEB` **como texto**.
- Una AGEB rural deshabitada tiene `POB_TOTAL = 0` y sus conteos en 0; sus porcentajes quedan vacíos (`D0`).
- En AGEB con universos minúsculos los porcentajes son ruido (K-01 en DECISIONES.md). Filtra o pondera por `POB_TOTAL`, `VIV_CARACT` o `PCT_POB_REPORTADA`.
- Para reagregar a otra geografía suma **conteos**, nunca promedies porcentajes (D-25).
- `PCT_VIV_SIN_DRENAJE` no es `100 − PCT_DRENAJE`, y está bien que no sumen 100 (D-19).

```r
readr::read_csv("data/processed/ageb_indicadores_MX.csv",
                col_types = readr::cols(ID_AGEB = "c", CVE_ENT = "c", CVE_MUN = "c",
                                        CVE_LOC = "c", CVE_AGEB = "c"))
```

## Tablas

| Tabla | Archivo | Columnas |
|---|---|---|
| [ageb_indicadores](#tabla-ageb-indicadores) | `data/processed/ageb_indicadores_{ENT}.csv` y `ageb_indicadores_MX.csv`. Una fila por AGEB urbana o rural. | 189 |
| [ageb_integrada](#tabla-ageb-integrada) | `data/processed/base_ageb_MX.gpkg`, capa `ageb_integrada` (EPSG:4326), y `ageb_integrada_MX.csv`. Una fila por AGEB con todas las columnas de ageb_indicadores más las que se listan aquí; `ORDEN` es su posición en esa tabla. El GeoPackage también trae, como capas, las demás tablas de este diccionario en versión nacional. | 32 |
| [ageb_geom](#tabla-ageb-geom) | `data/processed/ageb_geom_{ENT}.gpkg`, capa `ageb`, EPSG:4326. Una fila por AGEB. | 10 |
| [denue_establishments](#tabla-denue-establishments) | `data/processed/denue_establishments_{ENT}.csv`. Una fila por establecimiento del DENUE. | 7 |
| [denue_ageb_sector](#tabla-denue-ageb-sector) | `data/processed/denue_ageb_sector_{ENT}.csv`. Una fila por AGEB × sector SCIAN. | 3 |
| [ageb_landuse_detail](#tabla-ageb-landuse-detail) | `data/processed/ageb_landuse_detail_{ENT}.csv`. Una fila por AGEB × clase de uso de suelo. | 5 |
| [quality_control_report](#tabla-quality-control-report) | `data/processed/quality_control_report_{ENT}.csv` y `_MX.csv`. Una fila por control. | 4 |
| [qc_municipal_coverage](#tabla-qc-municipal-coverage) | `data/processed/qc_municipal_coverage_{ENT}.csv`. Una fila por municipio. | 8 |

<a id="tabla-ageb-indicadores"></a>
## Tabla ageb_indicadores

`data/processed/ageb_indicadores_{ENT}.csv` y `ageb_indicadores_MX.csv`. Una fila por AGEB urbana o rural.

Cobertura y mediana medidas sobre `data/processed/ageb_indicadores_MX.csv` (81,451 AGEB, generado el 2026-09-21). La cobertura se mide sobre AGEB **habitadas**, como % de AGEB con valor y como % de su población; la mediana y el rango también se miden sobre AGEB habitadas.

### Identificación

| # | Variable | Descripción | Unidad | Ámbito | Variable fuente | % AGEB con dato (urb / rur) | % población con dato (urb / rur) | Mediana | Sentido |
|---|---|---|---|---|---|---|---|---|---|
| 1 | [`ID_AGEB`](#id_ageb) | Clave única de la AGEB: entidad (2) + municipio (3) + localidad (4) + AGEB (4). | clave | Ambos | `CVEGEO` | 100.0 / 100.0 | 100.0 / 100.0 |  | n/a |
| 2 | [`AMBITO`](#ambito) | Ámbito de la AGEB según la capa del Marco Geoestadístico de la que proviene. |  | Ambos | `capa {ENT}a / {ENT}ar` | 100.0 / 100.0 | 100.0 / 100.0 |  | n/a |
| 3 | [`CVE_ENT`](#cve_ent) | Clave de entidad federativa. | clave | Ambos | `CVE_ENT` | 100.0 / 100.0 | 100.0 / 100.0 |  | n/a |
| 4 | [`NOM_ENT`](#nom_ent) | Nombre de la entidad federativa. |  | Ambos | `ENTITY_NAMES` | 100.0 / 100.0 | 100.0 / 100.0 |  | n/a |
| 5 | [`CVE_MUN`](#cve_mun) | Clave de municipio o demarcación territorial (3 dígitos, única solo dentro de la entidad). | clave | Ambos | `CVE_MUN` | 100.0 / 100.0 | 100.0 / 100.0 |  | n/a |
| 6 | [`NOM_MUN`](#nom_mun) | Nombre del municipio. |  | Ambos | `NOMGEO (capa {ENT}mun)` | 100.0 / 100.0 | 100.0 / 100.0 |  | n/a |
| 7 | [`CVE_LOC`](#cve_loc) | Clave de localidad (4 dígitos). En AGEB rurales es '0000' por convención. | clave | Ambos | `CVE_LOC` | 100.0 / 100.0 | 100.0 / 100.0 |  | n/a |
| 8 | [`NOM_LOC`](#nom_loc) | Nombre de la localidad. |  | Ambos | `NOMGEO (capa {ENT}l) / NOM_LOC (ITER)` | 100.0 / 100.0 | 100.0 / 100.0 |  | n/a |
| 9 | [`CVE_AGEB`](#cve_ageb) | Clave de AGEB (4 caracteres alfanuméricos). | clave | Ambos | `CVE_AGEB` | 100.0 / 100.0 | 100.0 / 100.0 |  | n/a |

### Geometría

| # | Variable | Descripción | Unidad | Ámbito | Variable fuente | % AGEB con dato (urb / rur) | % población con dato (urb / rur) | Mediana | Sentido |
|---|---|---|---|---|---|---|---|---|---|
| 10 | [`AREA_KM2`](#area_km2) | Superficie de la AGEB. | km² | Ambos | `geometría` | 100.0 / 100.0 | 100.0 / 100.0 | 0.3529 | n/a |
| 11 | [`CENTROIDE_LON`](#centroide_lon) | Longitud de un punto representativo dentro de la AGEB. | grados decimales (EPSG:4326) | Ambos | `geometría` | 100.0 / 100.0 | 100.0 / 100.0 | -100.4 | n/a |
| 12 | [`CENTROIDE_LAT`](#centroide_lat) | Latitud de un punto representativo dentro de la AGEB. | grados decimales (EPSG:4326) | Ambos | `geometría` | 100.0 / 100.0 | 100.0 / 100.0 | 20.64 | n/a |

### Población base

| # | Variable | Descripción | Unidad | Ámbito | Variable fuente | % AGEB con dato (urb / rur) | % población con dato (urb / rur) | Mediana | Sentido |
|---|---|---|---|---|---|---|---|---|---|
| 13 | [`POB_TOTAL`](#pob_total) | Población total residente habitual. | personas | Ambos | `POBTOT` | 100.0 / 100.0 | 100.0 / 100.0 | 1,027 | n/a |
| 17 | [`POB_HOMBRES`](#pob_hombres) | Población masculina. | personas | Ambos | `POBMAS` | 95.6 / 86.8 | 100.0 / 99.9 | 565 | n/a |
| 18 | [`POB_MUJERES`](#pob_mujeres) | Población femenina. | personas | Ambos | `POBFEM` | 95.6 / 86.8 | 100.0 / 99.9 | 592 | n/a |
| 19 | [`PCT_HOMBRES`](#pct_hombres) | Porcentaje de hombres. | % | Ambos | `POBMAS` | 95.6 / 86.8 | 100.0 / 99.9 | 48.94 | n/a |
| 20 | [`PCT_MUJERES`](#pct_mujeres) | Porcentaje de mujeres. | % | Ambos | `POBFEM` | 95.6 / 86.8 | 100.0 / 99.9 | 51.06 | n/a |
| 21 | [`DENS_POB_KM2`](#dens_pob_km2) | Densidad de población. | personas/km² | Ambos |  | 100.0 / 100.0 | 100.0 / 100.0 | 2,560 | ± |
| 22 | [`POB_POR_VIV`](#pob_por_viv) | Personas por vivienda particular habitada. | personas/vivienda | Ambos |  | 95.5 / 86.6 | 100.0 / 99.9 | 3.55 | + |

### Confiabilidad

| # | Variable | Descripción | Unidad | Ámbito | Variable fuente | % AGEB con dato (urb / rur) | % población con dato (urb / rur) | Mediana | Sentido |
|---|---|---|---|---|---|---|---|---|---|
| 14 | [`POB_REPORTADA`](#pob_reportada) | Población cuyas características sí publica el censo. | personas | Ambos | `POBTOT` | 100.0 / 100.0 | 100.0 / 100.0 | 1,021 | n/a |
| 15 | [`PCT_POB_REPORTADA`](#pct_pob_reportada) | Porcentaje de la población de la AGEB cuyas características publica el censo. | % | Ambos |  | 100.0 / 100.0 | 100.0 / 100.0 | 100 | n/a |
| 16 | [`N_CELDAS_IMPUTADAS`](#n_celdas_imputadas) | Número de celdas censales de la AGEB imputadas como 1.5 porque venían suprimidas ('*'). | celdas | Ambos |  | 100.0 / 100.0 | 100.0 / 100.0 | 2 | n/a |

### Vivienda

| # | Variable | Descripción | Unidad | Ámbito | Variable fuente | % AGEB con dato (urb / rur) | % población con dato (urb / rur) | Mediana | Sentido |
|---|---|---|---|---|---|---|---|---|---|
| 23 | [`VIV_PART_HAB`](#viv_part_hab) | Total de viviendas particulares habitadas. | viviendas | Ambos | `TVIVPARHAB` | 95.6 / 86.6 | 100.0 / 99.9 | 330 | n/a |
| 24 | [`VIV_CARACT`](#viv_caract) | Viviendas particulares habitadas con características captadas (estimación). Denominador de todos los porcentajes de vivienda. | viviendas | Ambos | `VPH_*` | 95.6 / 86.6 | 100.0 / 99.9 | 328.5 | n/a |
| 25 | [`VIV_DRENAJE`](#viv_drenaje) | Viviendas que disponen de drenaje (red pública, fosa séptica, barranca, río, lago o mar). | viviendas | Ambos | `VPH_DRENAJ` | 95.6 / 86.6 | 100.0 / 99.9 | 307 | n/a |
| 26 | [`VIV_ELECTRICIDAD`](#viv_electricidad) | Viviendas que disponen de energía eléctrica. | viviendas | Ambos | `VPH_C_ELEC` | 95.6 / 86.6 | 100.0 / 99.9 | 325 | n/a |
| 27 | [`PCT_DRENAJE`](#pct_drenaje) | Porcentaje de viviendas con drenaje. | % | Ambos | `VPH_DRENAJ` | 95.5 / 86.6 | 100.0 / 99.9 | 99.59 | − |
| 28 | [`PCT_ELECTRIC`](#pct_electric) | Porcentaje de viviendas con electricidad. | % | Ambos | `VPH_C_ELEC` | 95.5 / 86.6 | 100.0 / 99.9 | 99.89 | − |
| 43 | [`PCT_VIV_SIN_DRENAJE`](#pct_viv_sin_drenaje) | Porcentaje de viviendas que no disponen de drenaje. | % | Ambos | `VPH_NODREN` | 95.5 / 86.6 | 100.0 / 99.9 | 0.34 | + |
| 44 | [`PCT_VIV_SIN_ELECTRIC`](#pct_viv_sin_electric) | Porcentaje de viviendas que no disponen de energía eléctrica. | % | Ambos | `VPH_S_ELEC` | 95.5 / 86.6 | 100.0 / 99.9 | 0.1 | + |
| 45 | [`PCT_VIV_SIN_AGUA`](#pct_viv_sin_agua) | Porcentaje de viviendas sin agua entubada en el ámbito de la vivienda. | % | Ambos | `VPH_AGUAFV` | 95.5 / 86.6 | 100.0 / 99.9 | 0.31 | + |
| 46 | [`PCT_VIV_PISO_TIERRA`](#pct_viv_piso_tierra) | Porcentaje de viviendas con piso de tierra. | % | Ambos | `VPH_PISOTI` | 95.5 / 86.6 | 100.0 / 99.9 | 1.23 | + |
| 47 | [`PCT_VIV_1CUARTO`](#pct_viv_1cuarto) | Porcentaje de viviendas con un solo cuarto. | % | Ambos | `VPH_1CUART` | 95.5 / 86.6 | 100.0 / 99.9 | 4.06 | + |
| 48 | [`PCT_VIV_SIN_SANITARIO`](#pct_viv_sin_sanitario) | Porcentaje de viviendas sin excusado, sanitario ni letrina. | % | Ambos | `VPH_EXCSA + VPH_LETR` | 95.5 / 86.6 | 100.0 / 99.9 | 0.2 | + |

### Sensibilidad

| # | Variable | Descripción | Unidad | Ámbito | Variable fuente | % AGEB con dato (urb / rur) | % población con dato (urb / rur) | Mediana | Sentido |
|---|---|---|---|---|---|---|---|---|---|
| 29 | [`PCT_POB_0A5`](#pct_pob_0a5) | Porcentaje de población de 0 a 5 años. | % | Ambos | `P_0A2 + P_3A5` | 95.6 / 86.6 | 100.0 / 99.9 | 10.01 | + |
| 30 | [`PCT_POB_65YMAS`](#pct_pob_65ymas) | Porcentaje de población de 65 años y más. | % | Ambos | `POB65_MAS` | 95.6 / 86.6 | 100.0 / 99.9 | 7.21 | + |
| 31 | [`PCT_POB_DISC`](#pct_pob_disc) | Porcentaje de población con discapacidad. | % | Ambos | `PCON_DISC` | 95.6 / 86.6 | 100.0 / 99.9 | 4.6 | + |
| 32 | [`PCT_POB_HLI`](#pct_pob_hli) | Porcentaje de población de 3 años y más que habla lengua indígena. | % | Ambos | `P3YM_HLI` | 95.5 / 86.6 | 100.0 / 99.9 | 0.47 | + |
| 33 | [`PCT_POB_HLI_NHE`](#pct_pob_hli_nhe) | Porcentaje de población de 3 años y más que habla lengua indígena y no habla español. | % | Ambos | `P3HLINHE` | 95.5 / 86.6 | 100.0 / 99.9 | 0 | + |
| 34 | [`PCT_HOG_JEFA`](#pct_hog_jefa) | Porcentaje de hogares censales con persona de referencia mujer. | % | Ambos | `HOGJEF_F` | 95.5 / 86.6 | 100.0 / 99.9 | 31.04 | + |

### Rezago social

| # | Variable | Descripción | Unidad | Ámbito | Variable fuente | % AGEB con dato (urb / rur) | % población con dato (urb / rur) | Mediana | Sentido |
|---|---|---|---|---|---|---|---|---|---|
| 35 | [`PCT_POB_SIN_SALUD`](#pct_pob_sin_salud) | Porcentaje de población sin afiliación a servicios de salud. | % | Ambos | `PSINDER` | 95.6 / 86.6 | 100.0 / 99.9 | 23.44 | + |
| 36 | [`PCT_ANALF`](#pct_analf) | Porcentaje de población de 15 años y más analfabeta. | % | Ambos | `P15YM_AN` | 95.5 / 86.6 | 100.0 / 99.9 | 3.23 | + |
| 37 | [`PCT_EDU_BAS_INC`](#pct_edu_bas_inc) | Porcentaje de población de 15 años y más con educación básica incompleta. | % | Ambos | `P15YM_SE + P15PRI_IN + P15PRI_CO + P15SEC_IN` | 95.5 / 86.6 | 100.0 / 99.9 | 31.82 | + |
| 38 | [`PCT_NOASIS_6A14`](#pct_noasis_6a14) | Porcentaje de población de 6 a 14 años que no asiste a la escuela. | % | Ambos | `P6A11_NOA + P12A14NOA` | 94.8 / 84.0 | 100.0 / 99.9 | 4.7 | + |
| 39 | [`PCT_NOASIS_15A24`](#pct_noasis_15a24) | Porcentaje de población de 15 a 24 años que no asiste a la escuela. | % | Ambos | `P_15A17 + P_18A24 − P15A17A − P18A24A` | 94.7 / 84.7 | 100.0 / 99.9 | 55.7 | ± |
| 63 | [`GRAPROES`](#graproes) | Grado promedio de escolaridad de la población de 15 años y más. | años aprobados | Ambos | `GRAPROES` | 95.5 / 86.6 | 100.0 / 99.9 | 9.08 | − |
| 64 | [`PRO_OCUP_C`](#pro_ocup_c) | Promedio de ocupantes por cuarto en viviendas particulares habitadas. | ocupantes/cuarto | Ambos | `PRO_OCUP_C` | 95.5 / 86.6 | 100.0 / 99.9 | 1.02 | + |

### Empleo

| # | Variable | Descripción | Unidad | Ámbito | Variable fuente | % AGEB con dato (urb / rur) | % población con dato (urb / rur) | Mediana | Sentido |
|---|---|---|---|---|---|---|---|---|---|
| 40 | [`PCT_PEA`](#pct_pea) | Tasa de participación económica: porcentaje de la población de 12 años y más con condición de actividad especificada que es económicamente activa. | % | Ambos | `PEA / (PEA + PE_INAC)` | 95.5 / 86.6 | 100.0 / 99.9 | 61.9 | − |
| 41 | [`PCT_PEA_F`](#pct_pea_f) | Tasa de participación económica femenina: porcentaje de mujeres de 12 años y más con condición de actividad especificada que son económicamente activas. | % | Ambos | `PEA_F / (PEA_F + PE_INAC_F)` | 95.5 / 86.4 | 100.0 / 99.9 | 48.72 | − |
| 42 | [`PCT_DESOCUP`](#pct_desocup) | Tasa de desocupación: porcentaje de la población económicamente activa que no tiene trabajo y lo buscó. | % | Ambos | `PDESOCUP / PEA` | 95.5 / 86.5 | 100.0 / 99.9 | 1.38 | + |

### Agua y almacenamiento

| # | Variable | Descripción | Unidad | Ámbito | Variable fuente | % AGEB con dato (urb / rur) | % población con dato (urb / rur) | Mediana | Sentido |
|---|---|---|---|---|---|---|---|---|---|
| 49 | [`PCT_VIV_TINACO`](#pct_viv_tinaco) | Porcentaje de viviendas con tinaco. | % | Ambos | `VPH_TINACO` | 95.5 / 86.6 | 100.0 / 99.9 | 71.75 | − |
| 50 | [`PCT_VIV_CISTERNA`](#pct_viv_cisterna) | Porcentaje de viviendas con cisterna o aljibe. | % | Ambos | `VPH_CISTER` | 95.5 / 86.6 | 100.0 / 99.9 | 13.04 | − |

### Bienes y movilidad

| # | Variable | Descripción | Unidad | Ámbito | Variable fuente | % AGEB con dato (urb / rur) | % población con dato (urb / rur) | Mediana | Sentido |
|---|---|---|---|---|---|---|---|---|---|
| 51 | [`PCT_VIV_REFRI`](#pct_viv_refri) | Porcentaje de viviendas con refrigerador. | % | Ambos | `VPH_REFRI` | 95.5 / 86.6 | 100.0 / 99.9 | 92.38 | − |
| 52 | [`PCT_VIV_LAVADORA`](#pct_viv_lavadora) | Porcentaje de viviendas con lavadora. | % | Ambos | `VPH_LAVAD` | 95.5 / 86.6 | 100.0 / 99.9 | 76.35 | − |
| 53 | [`PCT_VIV_AUTO`](#pct_viv_auto) | Porcentaje de viviendas con automóvil o camioneta. | % | Ambos | `VPH_AUTOM` | 95.5 / 86.6 | 100.0 / 99.9 | 47.03 | − |
| 62 | [`PCT_VIV_SIN_BIENES`](#pct_viv_sin_bienes) | Porcentaje de viviendas sin ningún bien. | % | Ambos | `VPH_SNBIEN` | 95.5 / 86.6 | 100.0 / 99.9 | 0.28 | + |

### Comunicación y alertas

| # | Variable | Descripción | Unidad | Ámbito | Variable fuente | % AGEB con dato (urb / rur) | % población con dato (urb / rur) | Mediana | Sentido |
|---|---|---|---|---|---|---|---|---|---|
| 54 | [`PCT_VIV_RADIO`](#pct_viv_radio) | Porcentaje de viviendas con radio. | % | Ambos | `VPH_RADIO` | 95.5 / 86.6 | 100.0 / 99.9 | 68.03 | − |
| 55 | [`PCT_VIV_TELEFONO`](#pct_viv_telefono) | Porcentaje de viviendas con línea telefónica fija. | % | Ambos | `VPH_TELEF` | 95.5 / 86.6 | 100.0 / 99.9 | 25 | − |
| 56 | [`PCT_VIV_CELULAR`](#pct_viv_celular) | Porcentaje de viviendas con teléfono celular. | % | Ambos | `VPH_CEL` | 95.5 / 86.6 | 100.0 / 99.9 | 90.97 | − |
| 57 | [`PCT_VIV_INTERNET`](#pct_viv_internet) | Porcentaje de viviendas con internet. | % | Ambos | `VPH_INTER` | 95.5 / 86.6 | 100.0 / 99.9 | 44.7 | − |
| 58 | [`PCT_VIV_COMPU`](#pct_viv_compu) | Porcentaje de viviendas con computadora, laptop o tablet. | % | Ambos | `VPH_PC` | 95.5 / 86.6 | 100.0 / 99.9 | 28.57 | − |
| 59 | [`PCT_VIV_SIN_RADIO_TV`](#pct_viv_sin_radio_tv) | Porcentaje de viviendas sin radio ni televisor. | % | Ambos | `VPH_SINRTV` | 95.5 / 86.6 | 100.0 / 99.9 | 3.18 | + |
| 60 | [`PCT_VIV_SIN_TEL_CEL`](#pct_viv_sin_tel_cel) | Porcentaje de viviendas sin teléfono fijo ni celular. | % | Ambos | `VPH_SINLTC` | 95.5 / 86.6 | 100.0 / 99.9 | 5.66 | + |
| 61 | [`PCT_VIV_SIN_TIC`](#pct_viv_sin_tic) | Porcentaje de viviendas sin ninguna tecnología de información y comunicación. | % | Ambos | `VPH_SINTIC` | 95.5 / 86.6 | 100.0 / 99.9 | 0.73 | + |

### Validación CONEVAL

| # | Variable | Descripción | Unidad | Ámbito | Variable fuente | % AGEB con dato (urb / rur) | % población con dato (urb / rur) | Mediana | Sentido |
|---|---|---|---|---|---|---|---|---|---|
| 65 | [`GRS_GRADO`](#grs_grado) | Grado de Rezago Social de la AGEB urbana según CONEVAL. |  | Solo urbana | `Grado de Rezago Social (col. 28)` | 99.8 / 0.0 | 100.0 / 0.0 |  | + |
| 66 | [`GRS_NUM`](#grs_num) | Grado de Rezago Social codificado numéricamente. | ordinal 1–5 | Solo urbana | `GRS_GRADO` | 99.8 / 0.0 | 100.0 / 0.0 | 3 | + |
| 67 | [`RZ_ANALF`](#rz_analf) | CONEVAL: % de población de 15 años o más analfabeta. | % | Solo urbana | `col. 11` | 95.5 / 0.0 | 100.0 / 0.0 | 2.472 | + |
| 68 | [`RZ_INA614`](#rz_ina614) | CONEVAL: % de población de 6 a 14 años que no asiste a la escuela. | % | Solo urbana | `col. 12` | 95.5 / 0.0 | 100.0 / 0.0 | 4.348 | + |
| 69 | [`RZ_INA1524`](#rz_ina1524) | CONEVAL: % de población de 15 a 24 años que no asiste a la escuela. | % | Solo urbana | `col. 13` | 95.5 / 0.0 | 100.0 / 0.0 | 52.61 | + |
| 70 | [`RZ_EBINC`](#rz_ebinc) | CONEVAL: % de población de 15 años o más con educación básica incompleta. | % | Solo urbana | `col. 14` | 95.5 / 0.0 | 100.0 / 0.0 | 28.17 | + |
| 71 | [`RZ_SSALUD`](#rz_ssalud) | CONEVAL: % de población sin derechohabiencia a servicios de salud. | % | Solo urbana | `col. 15` | 95.5 / 0.0 | 100.0 / 0.0 | 23.81 | + |
| 72 | [`RZ_HACIN`](#rz_hacin) | CONEVAL: % de viviendas con hacinamiento. | % | Solo urbana | `col. 16` | 95.5 / 0.0 | 100.0 / 0.0 | 2.814 | + |
| 73 | [`RZ_SAGUA`](#rz_sagua) | CONEVAL: % de viviendas que no disponen de agua entubada de la red pública. | % | Solo urbana | `col. 17` | 95.5 / 0.0 | 100.0 / 0.0 | 0.1379 | + |
| 74 | [`RZ_SEXCUS`](#rz_sexcus) | CONEVAL: % de viviendas que no disponen de excusado o sanitario. | % | Solo urbana | `col. 18` | 95.5 / 0.0 | 100.0 / 0.0 | 0 | + |
| 75 | [`RZ_SDREN`](#rz_sdren) | CONEVAL: % de viviendas que no disponen de drenaje. | % | Solo urbana | `col. 19` | 95.5 / 0.0 | 100.0 / 0.0 | 0.09804 | + |
| 76 | [`RZ_SELEC`](#rz_selec) | CONEVAL: % de viviendas que no disponen de energía eléctrica. | % | Solo urbana | `col. 20` | 95.5 / 0.0 | 100.0 / 0.0 | 0 | + |
| 77 | [`RZ_PISOT`](#rz_pisot) | CONEVAL: % de viviendas con piso de tierra. | % | Solo urbana | `col. 21` | 95.5 / 0.0 | 100.0 / 0.0 | 0.8247 | + |
| 78 | [`RZ_SLAVAD`](#rz_slavad) | CONEVAL: % de viviendas que no disponen de lavadora. | % | Solo urbana | `col. 22` | 95.5 / 0.0 | 100.0 / 0.0 | 21.21 | + |
| 79 | [`RZ_SREFRI`](#rz_srefri) | CONEVAL: % de viviendas que no disponen de refrigerador. | % | Solo urbana | `col. 23` | 95.5 / 0.0 | 100.0 / 0.0 | 6.25 | + |
| 80 | [`RZ_STELF`](#rz_stelf) | CONEVAL: % de viviendas que no disponen de línea telefónica fija. | % | Solo urbana | `col. 24` | 95.5 / 0.0 | 100.0 / 0.0 | 68.81 | + |
| 81 | [`RZ_SCEL`](#rz_scel) | CONEVAL: % de viviendas que no disponen de teléfono celular. | % | Solo urbana | `col. 25` | 95.5 / 0.0 | 100.0 / 0.0 | 7.666 | + |
| 82 | [`RZ_SCOMPU`](#rz_scompu) | CONEVAL: % de viviendas que no disponen de computadora, laptop o tablet. | % | Solo urbana | `col. 26` | 95.5 / 0.0 | 100.0 / 0.0 | 66.67 | + |
| 83 | [`RZ_SINTER`](#rz_sinter) | CONEVAL: % de viviendas que no disponen de internet. | % | Solo urbana | `col. 27` | 95.5 / 0.0 | 100.0 / 0.0 | 47.75 | + |

### Actividad económica

| # | Variable | Descripción | Unidad | Ámbito | Variable fuente | % AGEB con dato (urb / rur) | % población con dato (urb / rur) | Mediana | Sentido |
|---|---|---|---|---|---|---|---|---|---|
| 84 | [`DENUE_TOT`](#denue_tot) | Unidades económicas registradas en el DENUE. | establecimientos | Ambos | `registros` | 100.0 / 100.0 | 100.0 / 100.0 | 22 | ± |
| 85 | [`DEN_MANUF`](#den_manuf) | Unidades económicas de industrias manufactureras. | establecimientos | Ambos | `codigo_act` | 100.0 / 100.0 | 100.0 / 100.0 | 2 | ± |
| 86 | [`DEN_COM`](#den_com) | Unidades económicas de comercio. | establecimientos | Ambos | `codigo_act` | 100.0 / 100.0 | 100.0 / 100.0 | 9 | ± |
| 87 | [`DEN_SERV`](#den_serv) | Unidades económicas de servicios. | establecimientos | Ambos | `codigo_act` | 100.0 / 100.0 | 100.0 / 100.0 | 8 | ± |
| 88 | [`DEN_EDU`](#den_edu) | Unidades económicas de servicios educativos. | establecimientos | Ambos | `codigo_act` | 100.0 / 100.0 | 100.0 / 100.0 | 0 | − |
| 89 | [`DEN_GOB`](#den_gob) | Unidades de actividades legislativas, gubernamentales y de impartición de justicia. | establecimientos | Ambos | `codigo_act` | 100.0 / 100.0 | 100.0 / 100.0 | 0 | − |
| 90 | [`SCHOOL_TOT`](#school_tot) | Escuelas (proxy de posibles refugios temporales). | establecimientos | Ambos | `codigo_act` | 100.0 / 100.0 | 100.0 / 100.0 | 0 | − |

### Hidrografía

| # | Variable | Descripción | Unidad | Ámbito | Variable fuente | % AGEB con dato (urb / rur) | % población con dato (urb / rur) | Mediana | Sentido |
|---|---|---|---|---|---|---|---|---|---|
| 91 | [`WATER_AREA`](#water_area) | Superficie de cuerpos de agua dentro de la AGEB. | km² | Ambos | `geometría` | 100.0 / 100.0 | 100.0 / 100.0 | 0 | ± |
| 92 | [`WATER_PCT`](#water_pct) | Porcentaje de la superficie de la AGEB cubierta por cuerpos de agua. | % | Ambos |  | 100.0 / 100.0 | 100.0 / 100.0 | 0 | ± |
| 93 | [`HAS_WATER`](#has_water) | Indicador de presencia de cuerpos de agua en la AGEB. | 0/1 | Ambos |  | 100.0 / 100.0 | 100.0 / 100.0 | 0 | ± |

### Uso de suelo

| # | Variable | Descripción | Unidad | Ámbito | Variable fuente | % AGEB con dato (urb / rur) | % población con dato (urb / rur) | Mediana | Sentido |
|---|---|---|---|---|---|---|---|---|---|
| 94 | [`USO_DOM`](#uso_dom) | Clase de uso de suelo y vegetación que ocupa más superficie de la AGEB. |  | Ambos | `DESCRIPCIO` | 100.0 / 100.0 | 100.0 / 100.0 |  | ± |
| 95 | [`USO_PCT`](#uso_pct) | Porcentaje de la AGEB cubierto por la clase dominante. | % | Ambos |  | 100.0 / 100.0 | 100.0 / 100.0 | 93.64 | n/a |
| 96 | [`PCT_URB`](#pct_urb) | Porcentaje de la AGEB clasificado como asentamiento humano o zona urbana. | % | Ambos | `DESCRIPCIO` | 100.0 / 100.0 | 100.0 / 100.0 | 74.9 | ± |

### Acceso a salud

| # | Variable | Descripción | Unidad | Ámbito | Variable fuente | % AGEB con dato (urb / rur) | % población con dato (urb / rur) | Mediana | Sentido |
|---|---|---|---|---|---|---|---|---|---|
| 97 | [`DIST_HOSP_KM`](#dist_hosp_km) | Distancia a la unidad hospitalaria en operación más cercana (segundo o tercer nivel), pública o privada. | km | Ambos | `LATITUD, LONGITUD, NOMBRE TIPO ESTABLECIMIENTO` | 100.0 / 100.0 | 100.0 / 100.0 | 2.748 | + |
| 98 | [`DIST_HOSP_PUB_KM`](#dist_hosp_pub_km) | Distancia al hospital público en operación más cercano (segundo o tercer nivel). | km | Ambos | `LATITUD, LONGITUD, NOMBRE DE LA INSTITUCION` | 100.0 / 100.0 | 100.0 / 100.0 | 4.652 | + |
| 99 | [`DIST_1NIVEL_PUB_KM`](#dist_1nivel_pub_km) | Distancia a la unidad pública de primer nivel en operación más cercana (centro de salud, unidad de medicina familiar, unidad médica rural). | km | Ambos | `LATITUD, LONGITUD, NIVEL ATENCION` | 100.0 / 100.0 | 100.0 / 100.0 | 1.061 | + |
| 100 | [`DIST_ORIGEN`](#dist_origen) | Punto desde el que se midieron las distancias a unidades de salud, cauces y costa. |  | Ambos |  | 100.0 / 100.0 | 100.0 / 100.0 |  | n/a |

### Relieve y exposición

| # | Variable | Descripción | Unidad | Ámbito | Variable fuente | % AGEB con dato (urb / rur) | % población con dato (urb / rur) | Mediana | Sentido |
|---|---|---|---|---|---|---|---|---|---|
| 101 | [`ELEV_M`](#elev_m) | Elevación media del terreno habitado sobre el nivel medio del mar. | m | Ambos | `valor del ráster` | 100.0 / 100.0 | 100.0 / 100.0 | 1,268 | ± |
| 102 | [`PEND_MEDIA_GRAD`](#pend_media_grad) | Pendiente media del terreno habitado. | grados | Ambos | `valor del ráster` | 100.0 / 100.0 | 100.0 / 100.0 | 3.5 | + |
| 103 | [`PCT_PEND_15`](#pct_pend_15) | Porcentaje del terreno habitado con pendiente mayor a 15 grados. | % | Ambos | `valor del ráster` | 100.0 / 100.0 | 100.0 / 100.0 | 0 | + |
| 104 | [`PCT_PEND_30`](#pct_pend_30) | Porcentaje del terreno habitado con pendiente mayor a 30 grados. | % | Ambos | `valor del ráster` | 100.0 / 100.0 | 100.0 / 100.0 | 0 | + |
| 105 | [`DIST_CAUCE_KM`](#dist_cauce_km) | Distancia en línea recta al cauce más cercano de orden de Strahler 3 o mayor. | km | Ambos | `ORDER_1` | 100.0 / 100.0 | 100.0 / 100.0 | 0.77 | − |
| 106 | [`DESNIVEL_CAUCE_M`](#desnivel_cauce_m) | Altura del terreno habitado sobre el agua más cercana: el lecho del cauce de orden ≥ 3 o el mar, lo que esté más cerca. | m | Ambos |  | 100.0 / 100.0 | 100.0 / 100.0 | 10.3 | − |
| 107 | [`DIST_COSTA_KM`](#dist_costa_km) | Distancia en línea recta a la línea de costa. | km | Ambos | `DESCRIP` | 100.0 / 100.0 | 100.0 / 100.0 | 181.4 | − |

### Amenaza (CENAPRED)

| # | Variable | Descripción | Unidad | Ámbito | Variable fuente | % AGEB con dato (urb / rur) | % población con dato (urb / rur) | Mediana | Sentido |
|---|---|---|---|---|---|---|---|---|---|
| 108 | [`AMZ_INUND`](#amz_inund) | Grado de peligro por inundación del municipio al que pertenece la AGEB. | grado (1–5) | Ambos | `gp_inundac` | 100.0 / 100.0 | 100.0 / 100.0 | 4 | n/a |
| 109 | [`AMZ_SEQUIA`](#amz_sequia) | Grado de peligro por sequía del municipio al que pertenece la AGEB. | grado (1–5) | Ambos | `gp_sequia2` | 100.0 / 100.0 | 100.0 / 100.0 | 3 | n/a |
| 110 | [`AMZ_ONDA_CAL`](#amz_onda_cal) | Grado de peligro por ondas cálidas (calor extremo) del municipio al que pertenece la AGEB. | grado (1–5) | Ambos | `gp_ondasca` | 100.0 / 100.0 | 100.0 / 100.0 | 3 | n/a |
| 111 | [`AMZ_CICLON`](#amz_ciclon) | Grado de peligro por ciclones tropicales del municipio al que pertenece la AGEB. | grado (1–5) | Ambos | `gp_ciclnes` | 100.0 / 100.0 | 100.0 / 100.0 | 1 | n/a |
| 112 | [`AMZ_DESLIZ`](#amz_desliz) | Grado de susceptibilidad a deslizamientos de laderas del municipio al que pertenece la AGEB. | grado (1–5) | Ambos | `susceplad` | 100.0 / 100.0 | 100.0 / 100.0 | 4 | n/a |
| 113 | [`AMZ_TORM_ELEC`](#amz_torm_elec) | Grado de peligro por tormentas eléctricas del municipio al que pertenece la AGEB. | grado (1–5) | Ambos | `gp_tormele` | 100.0 / 100.0 | 100.0 / 100.0 | 3 | n/a |
| 114 | [`AMZ_GRANIZO`](#amz_granizo) | Grado de peligro por granizo del municipio al que pertenece la AGEB. | grado (1–5) | Ambos | `gp_granizo` | 100.0 / 100.0 | 100.0 / 100.0 | 2 | n/a |
| 115 | [`AMZ_TEMP_BAJA`](#amz_temp_baja) | Grado de peligro por temperaturas bajas del municipio al que pertenece la AGEB. | grado (1–5) | Ambos | `gp_bajaste` | 100.0 / 100.0 | 100.0 / 100.0 | 2 | n/a |
| 116 | [`AMZ_NEVADA`](#amz_nevada) | Grado de peligro por nevadas del municipio al que pertenece la AGEB. | grado (1–5) | Ambos | `gp_nevadas` | 100.0 / 100.0 | 100.0 / 100.0 | 1 | n/a |
| 117 | [`AMZ_SISMO`](#amz_sismo) | Grado de peligro sísmico del municipio al que pertenece la AGEB. | grado (1–5) | Ambos | `gp_sismico` | 100.0 / 100.0 | 100.0 / 100.0 | 3 | n/a |
| 118 | [`AMZ_VOLCAN`](#amz_volcan) | Grado de peligro volcánico del municipio al que pertenece la AGEB. | grado (0–5) | Ambos | `volcanes` | 100.0 / 100.0 | 100.0 / 100.0 | 2 | n/a |
| 119 | [`AMZ_SUS_TOX`](#amz_sus_tox) | Grado de peligro por sustancias tóxicas del municipio al que pertenece la AGEB. | grado (0–5) | Ambos | `gp_sustox` | 99.8 / 99.6 | 99.8 / 99.7 | 0 | n/a |
| 120 | [`AMZ_SUS_INFLA`](#amz_sus_infla) | Grado de peligro por sustancias inflamables del municipio al que pertenece la AGEB. | grado (0–5) | Ambos | `gp_susinfl` | 99.8 / 99.6 | 99.8 / 99.7 | 2 | n/a |
| 121 | [`CEN_RESIL`](#cen_resil) | Grado de resiliencia del municipio según CENAPRED. | grado (1–5) | Ambos | `g_resilien` | 100.0 / 100.0 | 100.0 / 100.0 | 4 | − |
| 122 | [`CEN_VULN_CC`](#cen_vuln_cc) | Municipio clasificado por CENAPRED como vulnerable al cambio climático. |  | Ambos | `v_cc` | 99.8 / 99.6 | 99.8 / 99.7 | 0 | + |

### Ingreso (municipal)

| # | Variable | Descripción | Unidad | Ámbito | Variable fuente | % AGEB con dato (urb / rur) | % población con dato (urb / rur) | Mediana | Sentido |
|---|---|---|---|---|---|---|---|---|---|
| 123 | [`ING_MUN_HOG_TRIM`](#ing_mun_hog_trim) | Ingreso corriente promedio trimestral por hogar del municipio al que pertenece la AGEB. | pesos de 2022 por hogar por trimestre | Ambos | `icpth (est = 1)` | 100.0 / 100.0 | 100.0 / 100.0 | 57,083 | − |
| 124 | [`ING_MUN_LIM_INF`](#ing_mun_lim_inf) | Límite inferior del intervalo de confianza al 90 % de ING_MUN_HOG_TRIM. | pesos de 2022 por hogar por trimestre | Ambos | `icpth (est = 3)` | 100.0 / 100.0 | 100.0 / 100.0 | 50,308 | n/a |
| 125 | [`ING_MUN_LIM_SUP`](#ing_mun_lim_sup) | Límite superior del intervalo de confianza al 90 % de ING_MUN_HOG_TRIM. | pesos de 2022 por hogar por trimestre | Ambos | `icpth (est = 4)` | 100.0 / 100.0 | 100.0 / 100.0 | 64,345 | n/a |
| 126 | [`ING_MUN_CV`](#ing_mun_cv) | Coeficiente de variación de ING_MUN_HOG_TRIM. | % | Ambos | `icpth (est = 5)` | 100.0 / 100.0 | 100.0 / 100.0 | 7.53 | n/a |

### Conteos censales

| # | Variable | Descripción | Unidad | Ámbito | Variable fuente | % AGEB con dato (urb / rur) | % población con dato (urb / rur) | Mediana | Sentido |
|---|---|---|---|---|---|---|---|---|---|
| 127 | [`POB_0A2`](#pob_0a2) | Población de 0 a 2 años. | personas | Ambos | `P_0A2` | 95.6 / 86.6 | 100.0 / 99.9 | 49 | n/a |
| 128 | [`POB_3A5`](#pob_3a5) | Población de 3 a 5 años. | personas | Ambos | `P_3A5` | 95.6 / 86.6 | 100.0 / 99.9 | 56 | n/a |
| 129 | [`POB_65YMAS`](#pob_65ymas) | Población de 65 años y más. | personas | Ambos | `POB65_MAS` | 95.6 / 86.6 | 100.0 / 99.9 | 78 | n/a |
| 130 | [`POB_DISC`](#pob_disc) | Población con discapacidad. | personas | Ambos | `PCON_DISC` | 95.6 / 86.6 | 100.0 / 99.9 | 52 | n/a |
| 131 | [`POB_3YMAS`](#pob_3ymas) | Población de 3 años y más. | personas | Ambos | `P_3YMAS` | 95.6 / 86.6 | 100.0 / 99.9 | 1,100 | n/a |
| 132 | [`POB_HLI`](#pob_hli) | Población de 3 años y más que habla alguna lengua indígena. | personas | Ambos | `P3YM_HLI` | 95.6 / 86.6 | 100.0 / 99.9 | 5 | n/a |
| 133 | [`POB_HLI_NHE`](#pob_hli_nhe) | Población de 3 años y más que habla lengua indígena y no habla español. | personas | Ambos | `P3HLINHE` | 95.6 / 86.6 | 100.0 / 99.9 | 0 | n/a |
| 134 | [`POB_SIN_SALUD`](#pob_sin_salud) | Población sin afiliación a servicios de salud. | personas | Ambos | `PSINDER` | 95.6 / 86.6 | 100.0 / 99.9 | 246 | n/a |
| 135 | [`POB_15YMAS`](#pob_15ymas) | Población de 15 años y más. | personas | Ambos | `P_15YMAS` | 95.6 / 86.6 | 100.0 / 99.9 | 850 | n/a |
| 136 | [`POB_15YMAS_ANALF`](#pob_15ymas_analf) | Población de 15 años y más analfabeta. | personas | Ambos | `P15YM_AN` | 95.6 / 86.6 | 100.0 / 99.9 | 21 | n/a |
| 137 | [`POB_15YMAS_SIN_ESC`](#pob_15ymas_sin_esc) | Población de 15 años y más sin escolaridad (o solo preescolar). | personas | Ambos | `P15YM_SE` | 95.6 / 86.6 | 100.0 / 99.9 | 26 | n/a |
| 138 | [`POB_15YMAS_PRIM_INC`](#pob_15ymas_prim_inc) | Población de 15 años y más con primaria incompleta. | personas | Ambos | `P15PRI_IN` | 95.6 / 86.6 | 100.0 / 99.9 | 55 | n/a |
| 139 | [`POB_15YMAS_PRIM_COM`](#pob_15ymas_prim_com) | Población de 15 años y más con primaria completa (como máxima escolaridad). | personas | Ambos | `P15PRI_CO` | 95.6 / 86.6 | 100.0 / 99.9 | 97 | n/a |
| 140 | [`POB_15YMAS_SEC_INC`](#pob_15ymas_sec_inc) | Población de 15 años y más con secundaria incompleta. | personas | Ambos | `P15SEC_IN` | 95.6 / 86.6 | 100.0 / 99.9 | 23 | n/a |
| 141 | [`POB_6A11`](#pob_6a11) | Población de 6 a 11 años. | personas | Ambos | `P_6A11` | 95.6 / 86.6 | 100.0 / 99.9 | 114 | n/a |
| 142 | [`POB_12A14`](#pob_12a14) | Población de 12 a 14 años. | personas | Ambos | `P_12A14` | 95.6 / 86.6 | 100.0 / 99.9 | 57 | n/a |
| 143 | [`POB_6A11_NOASIS`](#pob_6a11_noasis) | Población de 6 a 11 años que no asiste a la escuela. | personas | Ambos | `P6A11_NOA` | 95.6 / 86.6 | 100.0 / 99.9 | 4 | n/a |
| 144 | [`POB_12A14_NOASIS`](#pob_12a14_noasis) | Población de 12 a 14 años que no asiste a la escuela. | personas | Ambos | `P12A14NOA` | 95.6 / 86.6 | 100.0 / 99.9 | 4 | n/a |
| 145 | [`POB_15A17`](#pob_15a17) | Población de 15 a 17 años. | personas | Ambos | `P_15A17` | 95.6 / 86.6 | 100.0 / 99.9 | 57 | n/a |
| 146 | [`POB_18A24`](#pob_18a24) | Población de 18 a 24 años. | personas | Ambos | `P_18A24` | 95.6 / 86.6 | 100.0 / 99.9 | 126 | n/a |
| 147 | [`POB_15A17_ASIS`](#pob_15a17_asis) | Población de 15 a 17 años que asiste a la escuela. | personas | Ambos | `P15A17A` | 95.6 / 86.6 | 100.0 / 99.9 | 41 | n/a |
| 148 | [`POB_18A24_ASIS`](#pob_18a24_asis) | Población de 18 a 24 años que asiste a la escuela. | personas | Ambos | `P18A24A` | 95.6 / 86.6 | 100.0 / 99.9 | 34 | n/a |
| 149 | [`POB_PEA`](#pob_pea) | Población económicamente activa de 12 años y más. | personas | Ambos | `PEA` | 95.6 / 86.6 | 100.0 / 99.9 | 547 | n/a |
| 150 | [`POB_PEA_F`](#pob_pea_f) | Mujeres de 12 años y más económicamente activas. | personas | Ambos | `PEA_F` | 95.6 / 86.6 | 100.0 / 99.9 | 210 | n/a |
| 151 | [`POB_INAC`](#pob_inac) | Población de 12 años y más no económicamente activa. | personas | Ambos | `PE_INAC` | 95.6 / 86.6 | 100.0 / 99.9 | 349 | n/a |
| 152 | [`POB_INAC_F`](#pob_inac_f) | Mujeres de 12 años y más no económicamente activas. | personas | Ambos | `PE_INAC_F` | 95.6 / 86.6 | 100.0 / 99.9 | 244 | n/a |
| 153 | [`POB_DESOCUP`](#pob_desocup) | Población de 12 años y más desocupada. | personas | Ambos | `PDESOCUP` | 95.6 / 86.6 | 100.0 / 99.9 | 7 | n/a |
| 154 | [`HOGARES`](#hogares) | Total de hogares censales. | hogares | Ambos | `TOTHOG` | 95.6 / 86.6 | 100.0 / 99.9 | 330 | n/a |
| 155 | [`HOGARES_JEFA`](#hogares_jefa) | Hogares censales con persona de referencia mujer. | hogares | Ambos | `HOGJEF_F` | 95.6 / 86.6 | 100.0 / 99.9 | 98 | n/a |
| 156 | [`VIV_OCUPANTES`](#viv_ocupantes) | Ocupantes en viviendas particulares habitadas. | personas | Ambos | `OCUPVIVPAR` | 95.6 / 86.6 | 100.0 / 99.9 | 1,154 | n/a |
| 157 | [`VIV_SIN_DRENAJE`](#viv_sin_drenaje) | Viviendas que no disponen de drenaje. | viviendas | Ambos | `VPH_NODREN` | 95.6 / 86.6 | 100.0 / 99.9 | 1.5 | n/a |
| 158 | [`VIV_SIN_ELECTRICIDAD`](#viv_sin_electricidad) | Viviendas que no disponen de energía eléctrica. | viviendas | Ambos | `VPH_S_ELEC` | 95.6 / 86.6 | 100.0 / 99.9 | 1 | n/a |
| 159 | [`VIV_SIN_AGUA`](#viv_sin_agua) | Viviendas sin agua entubada en el ámbito de la vivienda. | viviendas | Ambos | `VPH_AGUAFV` | 95.6 / 86.6 | 100.0 / 99.9 | 1.5 | n/a |
| 160 | [`VIV_PISO_TIERRA`](#viv_piso_tierra) | Viviendas con piso de tierra. | viviendas | Ambos | `VPH_PISOTI` | 95.6 / 86.6 | 100.0 / 99.9 | 4 | n/a |
| 161 | [`VIV_1CUARTO`](#viv_1cuarto) | Viviendas con un solo cuarto. | viviendas | Ambos | `VPH_1CUART` | 95.6 / 86.6 | 100.0 / 99.9 | 9 | n/a |
| 162 | [`VIV_EXCUSADO`](#viv_excusado) | Viviendas que disponen de excusado o sanitario. | viviendas | Ambos | `VPH_EXCSA` | 95.6 / 86.6 | 100.0 / 99.9 | 301 | n/a |
| 163 | [`VIV_LETRINA`](#viv_letrina) | Viviendas que disponen de letrina (pozo u hoyo). | viviendas | Ambos | `VPH_LETR` | 95.6 / 86.6 | 100.0 / 99.9 | 1 | n/a |
| 164 | [`VIV_TINACO`](#viv_tinaco) | Viviendas que disponen de tinaco. | viviendas | Ambos | `VPH_TINACO` | 95.6 / 86.6 | 100.0 / 99.9 | 147 | n/a |
| 165 | [`VIV_CISTERNA`](#viv_cisterna) | Viviendas que disponen de cisterna o aljibe. | viviendas | Ambos | `VPH_CISTER` | 95.6 / 86.6 | 100.0 / 99.9 | 24 | n/a |
| 166 | [`VIV_REFRI`](#viv_refri) | Viviendas que disponen de refrigerador. | viviendas | Ambos | `VPH_REFRI` | 95.6 / 86.6 | 100.0 / 99.9 | 277 | n/a |
| 167 | [`VIV_LAVADORA`](#viv_lavadora) | Viviendas que disponen de lavadora. | viviendas | Ambos | `VPH_LAVAD` | 95.6 / 86.6 | 100.0 / 99.9 | 220 | n/a |
| 168 | [`VIV_AUTO`](#viv_auto) | Viviendas que disponen de automóvil o camioneta. | viviendas | Ambos | `VPH_AUTOM` | 95.6 / 86.6 | 100.0 / 99.9 | 131 | n/a |
| 169 | [`VIV_RADIO`](#viv_radio) | Viviendas que disponen de radio. | viviendas | Ambos | `VPH_RADIO` | 95.6 / 86.6 | 100.0 / 99.9 | 201 | n/a |
| 170 | [`VIV_TELEFONO`](#viv_telefono) | Viviendas que disponen de línea telefónica fija. | viviendas | Ambos | `VPH_TELEF` | 95.6 / 86.6 | 100.0 / 99.9 | 61 | n/a |
| 171 | [`VIV_CELULAR`](#viv_celular) | Viviendas que disponen de teléfono celular. | viviendas | Ambos | `VPH_CEL` | 95.6 / 86.6 | 100.0 / 99.9 | 278 | n/a |
| 172 | [`VIV_INTERNET`](#viv_internet) | Viviendas que disponen de internet. | viviendas | Ambos | `VPH_INTER` | 95.6 / 86.6 | 100.0 / 99.9 | 112 | n/a |
| 173 | [`VIV_COMPU`](#viv_compu) | Viviendas que disponen de computadora, laptop o tablet. | viviendas | Ambos | `VPH_PC` | 95.6 / 86.6 | 100.0 / 99.9 | 73 | n/a |
| 174 | [`VIV_SIN_RADIO_TV`](#viv_sin_radio_tv) | Viviendas sin radio ni televisor. | viviendas | Ambos | `VPH_SINRTV` | 95.6 / 86.6 | 100.0 / 99.9 | 10 | n/a |
| 175 | [`VIV_SIN_TEL_CEL`](#viv_sin_tel_cel) | Viviendas sin línea telefónica fija ni teléfono celular. | viviendas | Ambos | `VPH_SINLTC` | 95.6 / 86.6 | 100.0 / 99.9 | 16 | n/a |
| 176 | [`VIV_SIN_TIC`](#viv_sin_tic) | Viviendas sin tecnologías de la información y la comunicación. | viviendas | Ambos | `VPH_SINTIC` | 95.6 / 86.6 | 100.0 / 99.9 | 3 | n/a |
| 177 | [`VIV_SIN_BIENES`](#viv_sin_bienes) | Viviendas sin ningún bien. | viviendas | Ambos | `VPH_SNBIEN` | 95.6 / 86.6 | 100.0 / 99.9 | 1.5 | n/a |

### Metadatos

| # | Variable | Descripción | Unidad | Ámbito | Variable fuente | % AGEB con dato (urb / rur) | % población con dato (urb / rur) | Mediana | Sentido |
|---|---|---|---|---|---|---|---|---|---|
| 178 | [`YEAR_GEOMETRY`](#year_geometry) | Año de referencia de la geometría. | año | Ambos | `YEARS$geometry` | 100.0 / 100.0 | 100.0 / 100.0 | 2,020 | n/a |
| 179 | [`YEAR_CENSUS`](#year_census) | Año de referencia del censo. | año | Ambos | `YEARS$census` | 100.0 / 100.0 | 100.0 / 100.0 | 2,020 | n/a |
| 180 | [`YEAR_CONEVAL`](#year_coneval) | Año de referencia del GRS de CONEVAL. | año | Ambos | `YEARS$coneval` | 100.0 / 100.0 | 100.0 / 100.0 | 2,020 | n/a |
| 181 | [`YEAR_DENUE`](#year_denue) | Versión del DENUE. | año-mes | Ambos | `YEARS$denue` | 100.0 / 100.0 | 100.0 / 100.0 |  | n/a |
| 182 | [`YEAR_HIDRO`](#year_hidro) | Año de referencia de la capa de cuerpos de agua. | año | Ambos | `YEARS$hidro` | 100.0 / 100.0 | 100.0 / 100.0 | 2,018 | n/a |
| 183 | [`YEAR_USV`](#year_usv) | Año de referencia de la capa de uso de suelo y vegetación. | año | Ambos | `YEARS$usv` | 100.0 / 100.0 | 100.0 / 100.0 | 2,021 | n/a |
| 184 | [`YEAR_CLUES`](#year_clues) | Corte del catálogo CLUES de establecimientos de salud. | año-mes | Ambos | `YEARS$clues` | 100.0 / 100.0 | 100.0 / 100.0 |  | n/a |
| 185 | [`YEAR_CEM`](#year_cem) | Año de publicación del Continuo de Elevaciones Mexicano 4.0. | año | Ambos | `YEARS$cem` | 100.0 / 100.0 | 100.0 / 100.0 | 2,024 | n/a |
| 186 | [`YEAR_RED_HIDRO`](#year_red_hidro) | Año de la edición 2.0 de la Red Hidrográfica 1:50 000. | año | Ambos | `YEARS$red_hidro` | 100.0 / 100.0 | 100.0 / 100.0 | 2,010 | n/a |
| 187 | [`YEAR_COSTA`](#year_costa) | Año de la capa de línea de costa de CONABIO. | año | Ambos | `YEARS$costa` | 100.0 / 100.0 | 100.0 / 100.0 | 2,018 | n/a |
| 188 | [`YEAR_CENAPRED`](#year_cenapred) | Actualización del Sistema de Indicadores Municipales del Atlas Nacional de Riesgos. | año | Ambos | `YEARS$cenapred` | 100.0 / 100.0 | 100.0 / 100.0 | 2,023 | n/a |
| 189 | [`YEAR_ICMM`](#year_icmm) | Edición del Ingreso Corriente para los Municipios de México. | año | Ambos | `YEARS$icmm` | 100.0 / 100.0 | 100.0 / 100.0 | 2,022 | n/a |

## Fichas de ageb_indicadores

Una ficha por columna, en el orden del CSV.

<a id="id_ageb"></a>
#### 1. `ID_AGEB`

Clave única de la AGEB: entidad (2) + municipio (3) + localidad (4) + AGEB (4).

| Campo | Valor |
|---|---|
| Bloque | Identificación |
| Tipo | texto |
| Unidad | clave |
| Ámbito | Ambos |
| Fuente | MG2020 |
| Variable en la fuente | `CVEGEO` |
| Derivación | Urbana: CVEGEO de 13 caracteres. Rural: CVE_ENT + CVE_MUN + '0000' + CVE_AGEB. |
| Valores vacíos | Nunca |
| Dimensión sugerida | Identificación |
| Sentido sugerido | n/a |
| Script | 03_boundaries.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Notas | Leer siempre como texto: tiene ceros a la izquierda y CVE_AGEB es alfanumérica. Ver D-03. |

<a id="ambito"></a>
#### 2. `AMBITO`

Ámbito de la AGEB según la capa del Marco Geoestadístico de la que proviene.

| Campo | Valor |
|---|---|
| Bloque | Identificación |
| Tipo | categórica |
| Ámbito | Ambos |
| Fuente | MG2020 |
| Variable en la fuente | `capa {ENT}a / {ENT}ar` |
| Derivación | 'Urbana' si viene de {ENT}a.shp; 'Rural' si viene de {ENT}ar.shp. |
| Valores vacíos | Nunca |
| Dimensión sugerida | Identificación |
| Sentido sugerido | n/a |
| Script | 03_boundaries.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Notas | Valores: Urbana, Rural. Las fuentes de población difieren por ámbito (D-11). |

<a id="cve_ent"></a>
#### 3. `CVE_ENT`

Clave de entidad federativa.

| Campo | Valor |
|---|---|
| Bloque | Identificación |
| Tipo | texto |
| Unidad | clave |
| Ámbito | Ambos |
| Fuente | MG2020 |
| Variable en la fuente | `CVE_ENT` |
| Valores vacíos | Nunca |
| Dimensión sugerida | Identificación |
| Sentido sugerido | n/a |
| Script | 03_boundaries.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Notas | 01 a 32. |

<a id="nom_ent"></a>
#### 4. `NOM_ENT`

Nombre de la entidad federativa.

| Campo | Valor |
|---|---|
| Bloque | Identificación |
| Tipo | texto |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `ENTITY_NAMES` |
| Derivación | Catálogo fijo en 00_config.R. |
| Valores vacíos | Nunca |
| Dimensión sugerida | Identificación |
| Sentido sugerido | n/a |
| Script | 00_config.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Notas | Sin acentos (p. ej. 'Ciudad de Mexico', 'Nuevo Leon'). |

<a id="cve_mun"></a>
#### 5. `CVE_MUN`

Clave de municipio o demarcación territorial (3 dígitos, única solo dentro de la entidad).

| Campo | Valor |
|---|---|
| Bloque | Identificación |
| Tipo | texto |
| Unidad | clave |
| Ámbito | Ambos |
| Fuente | MG2020 |
| Variable en la fuente | `CVE_MUN` |
| Valores vacíos | Nunca |
| Dimensión sugerida | Identificación |
| Sentido sugerido | n/a |
| Script | 03_boundaries.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Notas | La clave municipal completa es CVE_ENT + CVE_MUN. |

<a id="nom_mun"></a>
#### 6. `NOM_MUN`

Nombre del municipio.

| Campo | Valor |
|---|---|
| Bloque | Identificación |
| Tipo | texto |
| Ámbito | Ambos |
| Fuente | MG2020 |
| Variable en la fuente | `NOMGEO (capa {ENT}mun)` |
| Valores vacíos | Nunca |
| Dimensión sugerida | Identificación |
| Sentido sugerido | n/a |
| Script | 03_boundaries.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |

<a id="cve_loc"></a>
#### 7. `CVE_LOC`

Clave de localidad (4 dígitos). En AGEB rurales es '0000' por convención.

| Campo | Valor |
|---|---|
| Bloque | Identificación |
| Tipo | texto |
| Unidad | clave |
| Ámbito | Ambos |
| Fuente | MG2020 |
| Variable en la fuente | `CVE_LOC` |
| Derivación | Rural: '0000' (la AGEB rural no pertenece a una sola localidad). |
| Valores vacíos | Nunca |
| Dimensión sugerida | Identificación |
| Sentido sugerido | n/a |
| Script | 03_boundaries.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Notas | Ver D-03. |

<a id="nom_loc"></a>
#### 8. `NOM_LOC`

Nombre de la localidad.

| Campo | Valor |
|---|---|
| Bloque | Identificación |
| Tipo | texto |
| Ámbito | Ambos |
| Fuente | MG2020 / CPV2020_ITER |
| Variable en la fuente | `NOMGEO (capa {ENT}l) / NOM_LOC (ITER)` |
| Derivación | Urbana: nombre de la localidad en el MG. Rural: nombre del ITER si la AGEB tiene una sola localidad; '(varias localidades)' si tiene más. |
| Valores vacíos | E: AGEB rural deshabitada (sin localidades) |
| Dimensión sugerida | Identificación |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Notas | El NOM_LOC del censo urbano no sirve: siempre dice 'Total AGEB urbana' (D-06). |

<a id="cve_ageb"></a>
#### 9. `CVE_AGEB`

Clave de AGEB (4 caracteres alfanuméricos).

| Campo | Valor |
|---|---|
| Bloque | Identificación |
| Tipo | texto |
| Unidad | clave |
| Ámbito | Ambos |
| Fuente | MG2020 |
| Variable en la fuente | `CVE_AGEB` |
| Valores vacíos | Nunca |
| Dimensión sugerida | Identificación |
| Sentido sugerido | n/a |
| Script | 03_boundaries.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |

<a id="area_km2"></a>
#### 10. `AREA_KM2`

Superficie de la AGEB.

| Campo | Valor |
|---|---|
| Bloque | Geometría |
| Tipo | decimal |
| Unidad | km² |
| Decimales | 6 |
| Ámbito | Ambos |
| Fuente | MG2020 |
| Variable en la fuente | `geometría` |
| Derivación | Área del polígono en EPSG:6372 (LCC ITRF2008) tras st_make_valid(). |
| Valores vacíos | Nunca |
| Dimensión sugerida | Contexto |
| Sentido sugerido | n/a |
| Script | 03_boundaries.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 0.3529 |
| Rango | 0.000333 – 6,420 |
| Notas | Mínimo nacional 0.0003 km²; las AGEB rurales pueden superar 6,000 km². |

<a id="centroide_lon"></a>
#### 11. `CENTROIDE_LON`

Longitud de un punto representativo dentro de la AGEB.

| Campo | Valor |
|---|---|
| Bloque | Geometría |
| Tipo | decimal |
| Unidad | grados decimales (EPSG:4326) |
| Decimales | 6 |
| Ámbito | Ambos |
| Fuente | MG2020 |
| Variable en la fuente | `geometría` |
| Derivación | st_point_on_surface() en EPSG:6372, transformado a EPSG:4326. |
| Valores vacíos | Nunca |
| Dimensión sugerida | Identificación |
| Sentido sugerido | n/a |
| Script | 03_boundaries.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | -100.4 |
| Rango | -118.3 – -86.71 |
| Notas | No es el centroide geométrico: se garantiza que cae dentro del polígono (D-07). |

<a id="centroide_lat"></a>
#### 12. `CENTROIDE_LAT`

Latitud de un punto representativo dentro de la AGEB.

| Campo | Valor |
|---|---|
| Bloque | Geometría |
| Tipo | decimal |
| Unidad | grados decimales (EPSG:4326) |
| Decimales | 6 |
| Ámbito | Ambos |
| Fuente | MG2020 |
| Variable en la fuente | `geometría` |
| Derivación | Igual que CENTROIDE_LON. |
| Valores vacíos | Nunca |
| Dimensión sugerida | Identificación |
| Sentido sugerido | n/a |
| Script | 03_boundaries.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 20.64 |
| Rango | 14.59 – 32.72 |

<a id="pob_total"></a>
#### 13. `POB_TOTAL`

Población total residente habitual.

| Campo | Valor |
|---|---|
| Bloque | Población base |
| Tipo | decimal (conteo) |
| Unidad | personas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `POBTOT` |
| Derivación | Urbana: fila total de AGEB. Rural: suma de POBTOT de las localidades del ITER que caen en la AGEB. |
| Valores vacíos | Nunca (0 en AGEB rural deshabitada) |
| Dimensión sugerida | Población base |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R; 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 1,027 |
| Rango | 0 – 44,157 |
| Notas | Nunca suprimido por el INEGI. La suma nacional cuadra exacta con el Censo: 126,014,024 (D-12). |

<a id="pob_reportada"></a>
#### 14. `POB_REPORTADA`

Población cuyas características sí publica el censo.

| Campo | Valor |
|---|---|
| Bloque | Confiabilidad |
| Tipo | decimal (conteo) |
| Unidad | personas |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `POBTOT` |
| Derivación | Urbana: POB_TOTAL, o 0 si la fila de la AGEB está suprimida entera. Rural: suma de POBTOT de las localidades que publican todas las características. |
| Valores vacíos | Nunca |
| Dimensión sugerida | Confiabilidad |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 1,021 |
| Rango | 0 – 44,154 |
| Notas | Ver D-14. |

<a id="pct_pob_reportada"></a>
#### 15. `PCT_POB_REPORTADA`

Porcentaje de la población de la AGEB cuyas características publica el censo.

| Campo | Valor |
|---|---|
| Bloque | Confiabilidad |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Derivación | 100 × POB_REPORTADA / POB_TOTAL. |
| Universo | POB_TOTAL |
| Valores vacíos | D0: POB_TOTAL = 0 |
| Dimensión sugerida | Confiabilidad |
| Sentido sugerido | n/a |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 100 |
| Rango | 0 – 100 |
| Notas | Úsalo como peso o filtro de confiabilidad de los porcentajes, sobre todo en lo rural. |

<a id="n_celdas_imputadas"></a>
#### 16. `N_CELDAS_IMPUTADAS`

Número de celdas censales de la AGEB imputadas como 1.5 porque venían suprimidas ('*').

| Campo | Valor |
|---|---|
| Bloque | Confiabilidad |
| Tipo | entero |
| Unidad | celdas |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Derivación | Cuenta de celdas '*' entre los 52 conteos de CENSUS_VARS, solo en filas urbanas no suprimidas enteras. |
| Valores vacíos | Nunca |
| Dimensión sugerida | Confiabilidad |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 2 |
| Rango | 0 – 32 |
| Notas | Siempre 0 en AGEB rurales (el ITER sí publica 1 y 2). Nacional: 253,460 celdas en 55,573 AGEB urbanas (D-15). |

<a id="pob_hombres"></a>
#### 17. `POB_HOMBRES`

Población masculina.

| Campo | Valor |
|---|---|
| Bloque | Población base |
| Tipo | decimal (conteo) |
| Unidad | personas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `POBMAS` |
| Derivación | Urbana: valor directo. Rural: suma sobre localidades que publican el grupo SEXO. |
| Valores vacíos | S |
| Dimensión sugerida | Población base |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.8 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 565 |
| Rango | 0 – 20,215 |
| Notas | Puede valer 1.5 en AGEB urbanas (imputación). |

<a id="pob_mujeres"></a>
#### 18. `POB_MUJERES`

Población femenina.

| Campo | Valor |
|---|---|
| Bloque | Población base |
| Tipo | decimal (conteo) |
| Unidad | personas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `POBFEM` |
| Derivación | Igual que POB_HOMBRES. |
| Valores vacíos | S |
| Dimensión sugerida | Población base |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.8 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 592 |
| Rango | 0 – 23,939 |

<a id="pct_hombres"></a>
#### 19. `PCT_HOMBRES`

Porcentaje de hombres.

| Campo | Valor |
|---|---|
| Bloque | Población base |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `POBMAS` |
| Derivación | 100 × POB_HOMBRES / POB_DEN_SEXO. |
| Universo | Población de las localidades que publican el grupo SEXO (= POB_TOTAL en urbana) |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Población base |
| Sentido sugerido | n/a |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.8 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 48.94 |
| Rango | 0 – 100 |

<a id="pct_mujeres"></a>
#### 20. `PCT_MUJERES`

Porcentaje de mujeres.

| Campo | Valor |
|---|---|
| Bloque | Población base |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `POBFEM` |
| Derivación | 100 × POB_MUJERES / POB_DEN_SEXO. |
| Universo | Igual que PCT_HOMBRES |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Población base |
| Sentido sugerido | n/a |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.8 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 51.06 |
| Rango | 0 – 100 |

<a id="dens_pob_km2"></a>
#### 21. `DENS_POB_KM2`

Densidad de población.

| Campo | Valor |
|---|---|
| Bloque | Población base |
| Tipo | decimal |
| Unidad | personas/km² |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Derivación | POB_TOTAL / AREA_KM2. |
| Universo | AREA_KM2 |
| Valores vacíos | Nunca |
| Dimensión sugerida | Exposición (contexto) |
| Sentido sugerido | ± |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 2,560 |
| Rango | 0 – 122,692 |
| Notas | En AGEB rurales divide entre todo el territorio, no entre el área habitada. |

<a id="pob_por_viv"></a>
#### 22. `POB_POR_VIV`

Personas por vivienda particular habitada.

| Campo | Valor |
|---|---|
| Bloque | Población base |
| Tipo | decimal |
| Unidad | personas/vivienda |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Derivación | POB_DEN_VIV / VIV_PART_HAB. |
| Universo | VIV_PART_HAB |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Sensibilidad |
| Sentido sugerido | + |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 3.55 |
| Rango | 0 – 679 |
| Notas | Usa población total, no ocupantes. En AGEB diminutas con viviendas imputadas da valores extremos (52 AGEB > 10; máx. 679): filtrar por tamaño. |

<a id="viv_part_hab"></a>
#### 23. `VIV_PART_HAB`

Total de viviendas particulares habitadas.

| Campo | Valor |
|---|---|
| Bloque | Vivienda |
| Tipo | decimal (conteo) |
| Unidad | viviendas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `TVIVPARHAB` |
| Derivación | Urbana: directo. Rural: suma sobre localidades que publican el grupo VIV. |
| Valores vacíos | S |
| Dimensión sugerida | Población base |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 330 |
| Rango | 0 – 10,199 |
| Notas | Incluye viviendas sin información de ocupantes, por eso NO es el denominador de los porcentajes de vivienda (D-18). En 781 AGEB urbanas con población 0 vale 1.5 por imputación; no afecta ningún porcentaje. |

<a id="viv_caract"></a>
#### 24. `VIV_CARACT`

Viviendas particulares habitadas con características captadas (estimación). Denominador de todos los porcentajes de vivienda.

| Campo | Valor |
|---|---|
| Bloque | Vivienda |
| Tipo | decimal |
| Unidad | viviendas |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `VPH_*` |
| Derivación | min(VIV_PART_HAB, max(VPH_C_ELEC+VPH_S_ELEC, VPH_DRENAJ+VPH_NODREN, VPH_EXCSA+VPH_LETR, y cada conteo VPH_* individual)). |
| Valores vacíos | S |
| Dimensión sugerida | Población base |
| Sentido sugerido | n/a |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 328.5 |
| Rango | 0 – 10,165 |
| Notas | El censo no publica este universo (CONEVAL sí lo usa). Es la mayor de sus cotas inferiores, acotada por TVIVPARHAB. Ver D-18. |

<a id="viv_drenaje"></a>
#### 25. `VIV_DRENAJE`

Viviendas que disponen de drenaje (red pública, fosa séptica, barranca, río, lago o mar).

| Campo | Valor |
|---|---|
| Bloque | Vivienda |
| Tipo | decimal (conteo) |
| Unidad | viviendas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `VPH_DRENAJ` |
| Derivación | Directo (urbana) o suma (rural, grupo VIV). |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 307 |
| Rango | 0 – 9,111 |

<a id="viv_electricidad"></a>
#### 26. `VIV_ELECTRICIDAD`

Viviendas que disponen de energía eléctrica.

| Campo | Valor |
|---|---|
| Bloque | Vivienda |
| Tipo | decimal (conteo) |
| Unidad | viviendas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `VPH_C_ELEC` |
| Derivación | Directo (urbana) o suma (rural, grupo VIV). |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 325 |
| Rango | 0 – 10,011 |

<a id="pct_drenaje"></a>
#### 27. `PCT_DRENAJE`

Porcentaje de viviendas con drenaje.

| Campo | Valor |
|---|---|
| Bloque | Vivienda |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `VPH_DRENAJ` |
| Derivación | 100 × VIV_DRENAJE / VIV_CARACT. |
| Universo | VIV_CARACT |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | − |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 99.59 |
| Rango | 0 – 100 |
| Notas | Cambió de denominador (antes TVIVPARHAB). Para la carencia usa PCT_VIV_SIN_DRENAJE, que no es 100 − este valor (D-19). |

<a id="pct_electric"></a>
#### 28. `PCT_ELECTRIC`

Porcentaje de viviendas con electricidad.

| Campo | Valor |
|---|---|
| Bloque | Vivienda |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `VPH_C_ELEC` |
| Derivación | 100 × VIV_ELECTRICIDAD / VIV_CARACT. |
| Universo | VIV_CARACT |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | − |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 99.89 |
| Rango | 0 – 100 |
| Notas | Igual que PCT_DRENAJE; para la carencia usa PCT_VIV_SIN_ELECTRIC. |

<a id="pct_pob_0a5"></a>
#### 29. `PCT_POB_0A5`

Porcentaje de población de 0 a 5 años.

| Campo | Valor |
|---|---|
| Bloque | Sensibilidad |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `P_0A2 + P_3A5` |
| Derivación | 100 × (POB_0A2 + POB_3A5) / POB_DEN_PERS. |
| Universo | Población de las localidades que publican el grupo PERS |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Sensibilidad |
| Sentido sugerido | + |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 10.01 |
| Rango | 0 – 50 |
| Notas | Calor, enfermedades hídricas y dependencia en evacuación. |

<a id="pct_pob_65ymas"></a>
#### 30. `PCT_POB_65YMAS`

Porcentaje de población de 65 años y más.

| Campo | Valor |
|---|---|
| Bloque | Sensibilidad |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `POB65_MAS` |
| Derivación | 100 × POB_65YMAS / POB_DEN_PERS. |
| Universo | Igual que PCT_POB_0A5 |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Sensibilidad |
| Sentido sugerido | + |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 7.21 |
| Rango | 0 – 100 |
| Notas | Mortalidad por calor, movilidad reducida. |

<a id="pct_pob_disc"></a>
#### 31. `PCT_POB_DISC`

Porcentaje de población con discapacidad.

| Campo | Valor |
|---|---|
| Bloque | Sensibilidad |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `PCON_DISC` |
| Derivación | 100 × POB_DISC / POB_DEN_PERS. |
| Universo | Igual que PCT_POB_0A5 |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Sensibilidad |
| Sentido sugerido | + |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 4.6 |
| Rango | 0 – 88.07 |
| Notas | Discapacidad = mucha dificultad o imposibilidad para ver, oír, caminar, recordar, autocuidado o comunicarse. |

<a id="pct_pob_hli"></a>
#### 32. `PCT_POB_HLI`

Porcentaje de población de 3 años y más que habla lengua indígena.

| Campo | Valor |
|---|---|
| Bloque | Sensibilidad |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `P3YM_HLI` |
| Derivación | 100 × POB_HLI / POB_3YMAS. |
| Universo | Población de 3 años y más |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Sensibilidad |
| Sentido sugerido | + |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 0.47 |
| Rango | 0 – 100 |
| Notas | Proxy de marginación estructural. Para barrera de idioma ante alertas es mejor PCT_POB_HLI_NHE. |

<a id="pct_pob_hli_nhe"></a>
#### 33. `PCT_POB_HLI_NHE`

Porcentaje de población de 3 años y más que habla lengua indígena y no habla español.

| Campo | Valor |
|---|---|
| Bloque | Sensibilidad |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `P3HLINHE` |
| Derivación | 100 × POB_HLI_NHE / POB_3YMAS. |
| Universo | Población de 3 años y más |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Sensibilidad |
| Sentido sugerido | + |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 0 |
| Rango | 0 – 82.24 |
| Notas | Barrera directa para recibir alertas y avisos oficiales. Mediana nacional 0 %: muy concentrado. |

<a id="pct_hog_jefa"></a>
#### 34. `PCT_HOG_JEFA`

Porcentaje de hogares censales con persona de referencia mujer.

| Campo | Valor |
|---|---|
| Bloque | Sensibilidad |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `HOGJEF_F` |
| Derivación | 100 × HOGARES_JEFA / HOGARES. |
| Universo | Hogares censales |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Sensibilidad |
| Sentido sugerido | + |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 31.04 |
| Rango | 0 – 100 |
| Notas | Uso común en la literatura de vulnerabilidad social, pero su sentido es debatible; decidir al construir el índice. |

<a id="pct_pob_sin_salud"></a>
#### 35. `PCT_POB_SIN_SALUD`

Porcentaje de población sin afiliación a servicios de salud.

| Campo | Valor |
|---|---|
| Bloque | Rezago social |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `PSINDER` |
| Derivación | 100 × POB_SIN_SALUD / POB_DEN_PERS. |
| Universo | Igual que PCT_POB_0A5 |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | + |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 23.44 |
| Rango | 0 – 100 |
| Notas | Equivalente de RZ_SSALUD. |

<a id="pct_analf"></a>
#### 36. `PCT_ANALF`

Porcentaje de población de 15 años y más analfabeta.

| Campo | Valor |
|---|---|
| Bloque | Rezago social |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `P15YM_AN` |
| Derivación | 100 × POB_15YMAS_ANALF / POB_15YMAS. |
| Universo | Población de 15 años y más |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | + |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 3.23 |
| Rango | 0 – 100 |
| Notas | Equivalente de RZ_ANALF. |

<a id="pct_edu_bas_inc"></a>
#### 37. `PCT_EDU_BAS_INC`

Porcentaje de población de 15 años y más con educación básica incompleta.

| Campo | Valor |
|---|---|
| Bloque | Rezago social |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `P15YM_SE + P15PRI_IN + P15PRI_CO + P15SEC_IN` |
| Derivación | min(100, 100 × (sin escolaridad + primaria incompleta + primaria completa + secundaria incompleta) / POB_15YMAS). |
| Universo | Población de 15 años y más |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | + |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 31.82 |
| Rango | 0 – 100 |
| Notas | Equivalente de RZ_EBINC. Acotado a 100 porque suma cuatro celdas posiblemente imputadas (D-20). |

<a id="pct_noasis_6a14"></a>
#### 38. `PCT_NOASIS_6A14`

Porcentaje de población de 6 a 14 años que no asiste a la escuela.

| Campo | Valor |
|---|---|
| Bloque | Rezago social |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `P6A11_NOA + P12A14NOA` |
| Derivación | 100 × (POB_6A11_NOASIS + POB_12A14_NOASIS) / (POB_6A11 + POB_12A14). |
| Universo | Población de 6 a 14 años |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | + |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 94.8 % / 84.0 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 4.7 |
| Rango | 0 – 100 |
| Notas | Equivalente de RZ_INA614. |

<a id="pct_noasis_15a24"></a>
#### 39. `PCT_NOASIS_15A24`

Porcentaje de población de 15 a 24 años que no asiste a la escuela.

| Campo | Valor |
|---|---|
| Bloque | Rezago social |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `P_15A17 + P_18A24 − P15A17A − P18A24A` |
| Derivación | max(0, 100 × (POB_15A17 + POB_18A24 − POB_15A17_ASIS − POB_18A24_ASIS) / (POB_15A17 + POB_18A24)). |
| Universo | Población de 15 a 24 años |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | ± |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 94.7 % / 84.7 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 55.7 |
| Rango | 0 – 100 |
| Notas | Equivalente de RZ_INA1524. Es una resta: incluye a quienes no especificaron asistencia. Mediana nacional 56 %: poco discriminante para vulnerabilidad. |

<a id="pct_pea"></a>
#### 40. `PCT_PEA`

Tasa de participación económica: porcentaje de la población de 12 años y más con condición de actividad especificada que es económicamente activa.

| Campo | Valor |
|---|---|
| Bloque | Empleo |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `PEA / (PEA + PE_INAC)` |
| Derivación | 100 × POB_PEA / (POB_PEA + POB_INAC). |
| Universo | Población de 12 años y más con condición de actividad especificada (PEA + PE_INAC) |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | − |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 61.9 |
| Rango | 0 – 100 |
| Notas | No divide entre P_12YMAS: el no especificado es 0.2–0.5 % por entidad pero llega a 27 % en algunas AGEB. Sumado desde las AGEB de Oaxaca da 57.03 %, igual que el total estatal del ITER. El censo no capta ingreso; esta es la señal económica más cercana. |

<a id="pct_pea_f"></a>
#### 41. `PCT_PEA_F`

Tasa de participación económica femenina: porcentaje de mujeres de 12 años y más con condición de actividad especificada que son económicamente activas.

| Campo | Valor |
|---|---|
| Bloque | Empleo |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `PEA_F / (PEA_F + PE_INAC_F)` |
| Derivación | 100 × POB_PEA_F / (POB_PEA_F + POB_INAC_F). |
| Universo | Mujeres de 12 años y más con condición de actividad especificada |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | − |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.4 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 48.72 |
| Rango | 0 – 100 |
| Notas | Discrimina más que PCT_PEA entre AGEB (Oaxaca: 34 % rural contra 48 % urbana). Correlaciona con PCT_HOG_JEFA y con rezago educativo; revisar colinealidad al construir el índice. |

<a id="pct_desocup"></a>
#### 42. `PCT_DESOCUP`

Tasa de desocupación: porcentaje de la población económicamente activa que no tiene trabajo y lo buscó.

| Campo | Valor |
|---|---|
| Bloque | Empleo |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `PDESOCUP / PEA` |
| Derivación | 100 × POB_DESOCUP / POB_PEA. |
| Universo | Población económicamente activa (PEA = POCUPADA + PDESOCUP) |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | + |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.5 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 1.38 |
| Rango | 0 – 100 |
| Notas | Poco discriminante: el trabajo informal cuenta como ocupación y la tasa censal es baja (1.7–2.3 % por entidad). En AGEB urbanas el conteo es con frecuencia 1–2 y se imputa como 1.5 (D-15), así que en AGEB chicas es ruido. |

<a id="pct_viv_sin_drenaje"></a>
#### 43. `PCT_VIV_SIN_DRENAJE`

Porcentaje de viviendas que no disponen de drenaje.

| Campo | Valor |
|---|---|
| Bloque | Vivienda |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `VPH_NODREN` |
| Derivación | 100 × VIV_SIN_DRENAJE / VIV_CARACT. |
| Universo | VIV_CARACT |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | + |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 0.34 |
| Rango | 0 – 100 |
| Notas | Equivalente de RZ_SDREN. Conteo directo, no 100 − PCT_DRENAJE (D-19). |

<a id="pct_viv_sin_electric"></a>
#### 44. `PCT_VIV_SIN_ELECTRIC`

Porcentaje de viviendas que no disponen de energía eléctrica.

| Campo | Valor |
|---|---|
| Bloque | Vivienda |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `VPH_S_ELEC` |
| Derivación | 100 × VIV_SIN_ELECTRICIDAD / VIV_CARACT. |
| Universo | VIV_CARACT |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | + |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 0.1 |
| Rango | 0 – 100 |
| Notas | Equivalente de RZ_SELEC. |

<a id="pct_viv_sin_agua"></a>
#### 45. `PCT_VIV_SIN_AGUA`

Porcentaje de viviendas sin agua entubada en el ámbito de la vivienda.

| Campo | Valor |
|---|---|
| Bloque | Vivienda |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `VPH_AGUAFV` |
| Derivación | 100 × VIV_SIN_AGUA / VIV_CARACT. |
| Universo | VIV_CARACT |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | + |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 0.31 |
| Rango | 0 – 100 |
| Notas | Equivalente de RZ_SAGUA. Estrés hídrico y sequía. |

<a id="pct_viv_piso_tierra"></a>
#### 46. `PCT_VIV_PISO_TIERRA`

Porcentaje de viviendas con piso de tierra.

| Campo | Valor |
|---|---|
| Bloque | Vivienda |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `VPH_PISOTI` |
| Derivación | 100 × VIV_PISO_TIERRA / VIV_CARACT. |
| Universo | VIV_CARACT |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | + |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 1.23 |
| Rango | 0 – 100 |
| Notas | Equivalente de RZ_PISOT. Proxy de precariedad de la vivienda ante inundación. |

<a id="pct_viv_1cuarto"></a>
#### 47. `PCT_VIV_1CUARTO`

Porcentaje de viviendas con un solo cuarto.

| Campo | Valor |
|---|---|
| Bloque | Vivienda |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `VPH_1CUART` |
| Derivación | 100 × VIV_1CUARTO / VIV_CARACT. |
| Universo | VIV_CARACT |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | + |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 4.06 |
| Rango | 0 – 100 |
| Notas | Hacinamiento y calor interior. |

<a id="pct_viv_sin_sanitario"></a>
#### 48. `PCT_VIV_SIN_SANITARIO`

Porcentaje de viviendas sin excusado, sanitario ni letrina.

| Campo | Valor |
|---|---|
| Bloque | Vivienda |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `VPH_EXCSA + VPH_LETR` |
| Derivación | max(0, 100 − 100 × (VIV_EXCUSADO + VIV_LETRINA) / VIV_CARACT). |
| Universo | VIV_CARACT |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | + |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 0.2 |
| Rango | 0 – 100 |
| Notas | Equivalente de RZ_SEXCUS. Único complemento: no existe conteo directo. Como CONEVAL, la letrina cuenta como sanitario (D-19). |

<a id="pct_viv_tinaco"></a>
#### 49. `PCT_VIV_TINACO`

Porcentaje de viviendas con tinaco.

| Campo | Valor |
|---|---|
| Bloque | Agua y almacenamiento |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `VPH_TINACO` |
| Derivación | 100 × VIV_TINACO / VIV_CARACT. |
| Universo | VIV_CARACT |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | − |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 71.75 |
| Rango | 0 – 100 |
| Notas | Almacenamiento de agua ante cortes y sequía. |

<a id="pct_viv_cisterna"></a>
#### 50. `PCT_VIV_CISTERNA`

Porcentaje de viviendas con cisterna o aljibe.

| Campo | Valor |
|---|---|
| Bloque | Agua y almacenamiento |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `VPH_CISTER` |
| Derivación | 100 × VIV_CISTERNA / VIV_CARACT. |
| Universo | VIV_CARACT |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | − |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 13.04 |
| Rango | 0 – 100 |

<a id="pct_viv_refri"></a>
#### 51. `PCT_VIV_REFRI`

Porcentaje de viviendas con refrigerador.

| Campo | Valor |
|---|---|
| Bloque | Bienes y movilidad |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `VPH_REFRI` |
| Derivación | 100 × VIV_REFRI / VIV_CARACT. |
| Universo | VIV_CARACT |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | − |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 92.38 |
| Rango | 0 – 100 |
| Notas | RZ_SREFRI = 100 − este valor (CONEVAL publica la carencia). |

<a id="pct_viv_lavadora"></a>
#### 52. `PCT_VIV_LAVADORA`

Porcentaje de viviendas con lavadora.

| Campo | Valor |
|---|---|
| Bloque | Bienes y movilidad |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `VPH_LAVAD` |
| Derivación | 100 × VIV_LAVADORA / VIV_CARACT. |
| Universo | VIV_CARACT |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | − |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 76.35 |
| Rango | 0 – 100 |
| Notas | RZ_SLAVAD = 100 − este valor. |

<a id="pct_viv_auto"></a>
#### 53. `PCT_VIV_AUTO`

Porcentaje de viviendas con automóvil o camioneta.

| Campo | Valor |
|---|---|
| Bloque | Bienes y movilidad |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `VPH_AUTOM` |
| Derivación | 100 × VIV_AUTO / VIV_CARACT. |
| Universo | VIV_CARACT |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | − |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 47.03 |
| Rango | 0 – 100 |
| Notas | Capacidad de evacuación. |

<a id="pct_viv_radio"></a>
#### 54. `PCT_VIV_RADIO`

Porcentaje de viviendas con radio.

| Campo | Valor |
|---|---|
| Bloque | Comunicación y alertas |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `VPH_RADIO` |
| Derivación | 100 × VIV_RADIO / VIV_CARACT. |
| Universo | VIV_CARACT |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | − |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 68.03 |
| Rango | 0 – 100 |
| Notas | Canal de alerta temprana que no depende de la red eléctrica o de datos. |

<a id="pct_viv_telefono"></a>
#### 55. `PCT_VIV_TELEFONO`

Porcentaje de viviendas con línea telefónica fija.

| Campo | Valor |
|---|---|
| Bloque | Comunicación y alertas |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `VPH_TELEF` |
| Derivación | 100 × VIV_TELEFONO / VIV_CARACT. |
| Universo | VIV_CARACT |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | − |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 25 |
| Rango | 0 – 100 |
| Notas | RZ_STELF = 100 − este valor. |

<a id="pct_viv_celular"></a>
#### 56. `PCT_VIV_CELULAR`

Porcentaje de viviendas con teléfono celular.

| Campo | Valor |
|---|---|
| Bloque | Comunicación y alertas |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `VPH_CEL` |
| Derivación | 100 × VIV_CELULAR / VIV_CARACT. |
| Universo | VIV_CARACT |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | − |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 90.97 |
| Rango | 0 – 100 |
| Notas | RZ_SCEL = 100 − este valor. |

<a id="pct_viv_internet"></a>
#### 57. `PCT_VIV_INTERNET`

Porcentaje de viviendas con internet.

| Campo | Valor |
|---|---|
| Bloque | Comunicación y alertas |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `VPH_INTER` |
| Derivación | 100 × VIV_INTERNET / VIV_CARACT. |
| Universo | VIV_CARACT |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | − |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 44.7 |
| Rango | 0 – 100 |
| Notas | RZ_SINTER = 100 − este valor. |

<a id="pct_viv_compu"></a>
#### 58. `PCT_VIV_COMPU`

Porcentaje de viviendas con computadora, laptop o tablet.

| Campo | Valor |
|---|---|
| Bloque | Comunicación y alertas |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `VPH_PC` |
| Derivación | 100 × VIV_COMPU / VIV_CARACT. |
| Universo | VIV_CARACT |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | − |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 28.57 |
| Rango | 0 – 100 |
| Notas | RZ_SCOMPU = 100 − este valor. |

<a id="pct_viv_sin_radio_tv"></a>
#### 59. `PCT_VIV_SIN_RADIO_TV`

Porcentaje de viviendas sin radio ni televisor.

| Campo | Valor |
|---|---|
| Bloque | Comunicación y alertas |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `VPH_SINRTV` |
| Derivación | 100 × VIV_SIN_RADIO_TV / VIV_CARACT. |
| Universo | VIV_CARACT |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | + |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 3.18 |
| Rango | 0 – 100 |

<a id="pct_viv_sin_tel_cel"></a>
#### 60. `PCT_VIV_SIN_TEL_CEL`

Porcentaje de viviendas sin teléfono fijo ni celular.

| Campo | Valor |
|---|---|
| Bloque | Comunicación y alertas |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `VPH_SINLTC` |
| Derivación | 100 × VIV_SIN_TEL_CEL / VIV_CARACT. |
| Universo | VIV_CARACT |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | + |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 5.66 |
| Rango | 0 – 100 |

<a id="pct_viv_sin_tic"></a>
#### 61. `PCT_VIV_SIN_TIC`

Porcentaje de viviendas sin ninguna tecnología de información y comunicación.

| Campo | Valor |
|---|---|
| Bloque | Comunicación y alertas |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `VPH_SINTIC` |
| Derivación | 100 × VIV_SIN_TIC / VIV_CARACT. |
| Universo | VIV_CARACT |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | + |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 0.73 |
| Rango | 0 – 100 |
| Notas | Sin radio, TV, computadora, teléfono fijo, celular, internet, TV de paga, streaming ni consola. Muy correlacionado con PCT_VIV_SIN_BIENES. |

<a id="pct_viv_sin_bienes"></a>
#### 62. `PCT_VIV_SIN_BIENES`

Porcentaje de viviendas sin ningún bien.

| Campo | Valor |
|---|---|
| Bloque | Bienes y movilidad |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `VPH_SNBIEN` |
| Derivación | 100 × VIV_SIN_BIENES / VIV_CARACT. |
| Universo | VIV_CARACT |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | + |
| Script | 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 0.28 |
| Rango | 0 – 100 |
| Notas | Sin refrigerador, lavadora, microondas, vehículo, bicicleta ni ninguna TIC. |

<a id="graproes"></a>
#### 63. `GRAPROES`

Grado promedio de escolaridad de la población de 15 años y más.

| Campo | Valor |
|---|---|
| Bloque | Rezago social |
| Tipo | decimal |
| Unidad | años aprobados |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `GRAPROES` |
| Derivación | ESC_ANIOS_TOT / POB_15YMAS, donde ESC_ANIOS_TOT = Σ GRAPROES × P_15YMAS de cada localidad (rural) o de la AGEB (urbana). |
| Universo | Población de 15 años y más |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | − |
| Script | 04_census_urban.R; 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 9.08 |
| Rango | 0 – 18.83 |
| Notas | Los promedios no se suman: se convierten a totales y se vuelven a dividir (D-17). El INEGI excluye a quien no especificó grados; aquí el denominador los incluye, diferencia menor. |

<a id="pro_ocup_c"></a>
#### 64. `PRO_OCUP_C`

Promedio de ocupantes por cuarto en viviendas particulares habitadas.

| Campo | Valor |
|---|---|
| Bloque | Rezago social |
| Tipo | decimal |
| Unidad | ocupantes/cuarto |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `PRO_OCUP_C` |
| Derivación | OCUP_CON_CUARTOS / CUARTOS_TOT, con CUARTOS_TOT = Σ OCUPVIVPAR / PRO_OCUP_C (solo donde PRO_OCUP_C > 0). |
| Universo | Cuartos de viviendas particulares habitadas |
| Valores vacíos | S; D0 |
| Dimensión sugerida | Sensibilidad |
| Sentido sugerido | + |
| Script | 04_census_urban.R; 10_build.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 1.02 |
| Rango | 0.16 – 6.83 |
| Notas | Sustituto de RZ_HACIN (el censo no publica el conteo de viviendas hacinadas). No se valida contra CONEVAL porque uno es promedio y otro porcentaje. |

<a id="grs_grado"></a>
#### 65. `GRS_GRADO`

Grado de Rezago Social de la AGEB urbana según CONEVAL.

| Campo | Valor |
|---|---|
| Bloque | Validación CONEVAL |
| Tipo | categórica ordinal |
| Ámbito | Solo urbana |
| Fuente | CONEVAL_GRS2020 |
| Variable en la fuente | `Grado de Rezago Social (col. 28)` |
| Derivación | Lectura directa. |
| Valores vacíos | E: rural; S: CONEVAL no lo publica |
| Dimensión sugerida | Validación externa |
| Sentido sugerido | + |
| Script | 06_coneval.R |
| AGEB habitadas con dato (urbana / rural) | 99.8 % / 0.0 % |
| Población con dato (urbana / rural) | 100.0 % / 0.0 % |
| Notas | Valores: Muy bajo, Bajo, Medio, Alto, Muy alto. No hay índice continuo (IRS) por AGEB (D-23). |

<a id="grs_num"></a>
#### 66. `GRS_NUM`

Grado de Rezago Social codificado numéricamente.

| Campo | Valor |
|---|---|
| Bloque | Validación CONEVAL |
| Tipo | entero |
| Unidad | ordinal 1–5 |
| Ámbito | Solo urbana |
| Fuente | PIPELINE |
| Variable en la fuente | `GRS_GRADO` |
| Derivación | 1 = Muy bajo, 2 = Bajo, 3 = Medio, 4 = Alto, 5 = Muy alto. |
| Valores vacíos | E: rural; S: CONEVAL no lo publica |
| Dimensión sugerida | Validación externa |
| Sentido sugerido | + |
| Script | 06_coneval.R |
| AGEB habitadas con dato (urbana / rural) | 99.8 % / 0.0 % |
| Población con dato (urbana / rural) | 100.0 % / 0.0 % |
| Mediana (AGEB habitadas) | 3 |
| Rango | 1 – 5 |
| Notas | Ordinal: no promediar como si fuera continuo. |

<a id="rz_analf"></a>
#### 67. `RZ_ANALF`

CONEVAL: % de población de 15 años o más analfabeta.

| Campo | Valor |
|---|---|
| Bloque | Validación CONEVAL |
| Tipo | decimal |
| Unidad | % |
| Ámbito | Solo urbana |
| Fuente | CONEVAL_GRS2020 |
| Variable en la fuente | `col. 11` |
| Derivación | Lectura directa, sin redondeo. |
| Universo | Según CONEVAL |
| Valores vacíos | E: rural; S: CONEVAL no lo publica |
| Dimensión sugerida | Validación externa |
| Sentido sugerido | + |
| Script | 06_coneval.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 0.0 % |
| Población con dato (urbana / rural) | 100.0 % / 0.0 % |
| Mediana (AGEB habitadas) | 2.472 |
| Rango | 0 – 100 |
| Notas | Equivalente censal: PCT_ANALF. |

<a id="rz_ina614"></a>
#### 68. `RZ_INA614`

CONEVAL: % de población de 6 a 14 años que no asiste a la escuela.

| Campo | Valor |
|---|---|
| Bloque | Validación CONEVAL |
| Tipo | decimal |
| Unidad | % |
| Ámbito | Solo urbana |
| Fuente | CONEVAL_GRS2020 |
| Variable en la fuente | `col. 12` |
| Derivación | Lectura directa. |
| Universo | Según CONEVAL |
| Valores vacíos | E: rural; S: CONEVAL no lo publica |
| Dimensión sugerida | Validación externa |
| Sentido sugerido | + |
| Script | 06_coneval.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 0.0 % |
| Población con dato (urbana / rural) | 100.0 % / 0.0 % |
| Mediana (AGEB habitadas) | 4.348 |
| Rango | 0 – 100 |
| Notas | Equivalente: PCT_NOASIS_6A14. |

<a id="rz_ina1524"></a>
#### 69. `RZ_INA1524`

CONEVAL: % de población de 15 a 24 años que no asiste a la escuela.

| Campo | Valor |
|---|---|
| Bloque | Validación CONEVAL |
| Tipo | decimal |
| Unidad | % |
| Ámbito | Solo urbana |
| Fuente | CONEVAL_GRS2020 |
| Variable en la fuente | `col. 13` |
| Derivación | Lectura directa. |
| Universo | Según CONEVAL |
| Valores vacíos | E: rural; S: CONEVAL no lo publica |
| Dimensión sugerida | Validación externa |
| Sentido sugerido | + |
| Script | 06_coneval.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 0.0 % |
| Población con dato (urbana / rural) | 100.0 % / 0.0 % |
| Mediana (AGEB habitadas) | 52.61 |
| Rango | 0 – 100 |
| Notas | Equivalente: PCT_NOASIS_15A24. |

<a id="rz_ebinc"></a>
#### 70. `RZ_EBINC`

CONEVAL: % de población de 15 años o más con educación básica incompleta.

| Campo | Valor |
|---|---|
| Bloque | Validación CONEVAL |
| Tipo | decimal |
| Unidad | % |
| Ámbito | Solo urbana |
| Fuente | CONEVAL_GRS2020 |
| Variable en la fuente | `col. 14` |
| Derivación | Lectura directa. |
| Universo | Según CONEVAL |
| Valores vacíos | E: rural; S: CONEVAL no lo publica |
| Dimensión sugerida | Validación externa |
| Sentido sugerido | + |
| Script | 06_coneval.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 0.0 % |
| Población con dato (urbana / rural) | 100.0 % / 0.0 % |
| Mediana (AGEB habitadas) | 28.17 |
| Rango | 0 – 100 |
| Notas | Equivalente: PCT_EDU_BAS_INC. |

<a id="rz_ssalud"></a>
#### 71. `RZ_SSALUD`

CONEVAL: % de población sin derechohabiencia a servicios de salud.

| Campo | Valor |
|---|---|
| Bloque | Validación CONEVAL |
| Tipo | decimal |
| Unidad | % |
| Ámbito | Solo urbana |
| Fuente | CONEVAL_GRS2020 |
| Variable en la fuente | `col. 15` |
| Derivación | Lectura directa. |
| Universo | Según CONEVAL |
| Valores vacíos | E: rural; S: CONEVAL no lo publica |
| Dimensión sugerida | Validación externa |
| Sentido sugerido | + |
| Script | 06_coneval.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 0.0 % |
| Población con dato (urbana / rural) | 100.0 % / 0.0 % |
| Mediana (AGEB habitadas) | 23.81 |
| Rango | 0 – 100 |
| Notas | Equivalente: PCT_POB_SIN_SALUD. |

<a id="rz_hacin"></a>
#### 72. `RZ_HACIN`

CONEVAL: % de viviendas con hacinamiento.

| Campo | Valor |
|---|---|
| Bloque | Validación CONEVAL |
| Tipo | decimal |
| Unidad | % |
| Ámbito | Solo urbana |
| Fuente | CONEVAL_GRS2020 |
| Variable en la fuente | `col. 16` |
| Derivación | Lectura directa. |
| Universo | Según CONEVAL |
| Valores vacíos | E: rural; S: CONEVAL no lo publica |
| Dimensión sugerida | Validación externa |
| Sentido sugerido | + |
| Script | 06_coneval.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 0.0 % |
| Población con dato (urbana / rural) | 100.0 % / 0.0 % |
| Mediana (AGEB habitadas) | 2.814 |
| Rango | 0 – 100 |
| Notas | Sin equivalente exacto; PRO_OCUP_C es el sustituto más cercano. |

<a id="rz_sagua"></a>
#### 73. `RZ_SAGUA`

CONEVAL: % de viviendas que no disponen de agua entubada de la red pública.

| Campo | Valor |
|---|---|
| Bloque | Validación CONEVAL |
| Tipo | decimal |
| Unidad | % |
| Ámbito | Solo urbana |
| Fuente | CONEVAL_GRS2020 |
| Variable en la fuente | `col. 17` |
| Derivación | Lectura directa. |
| Universo | Según CONEVAL |
| Valores vacíos | E: rural; S: CONEVAL no lo publica |
| Dimensión sugerida | Validación externa |
| Sentido sugerido | + |
| Script | 06_coneval.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 0.0 % |
| Población con dato (urbana / rural) | 100.0 % / 0.0 % |
| Mediana (AGEB habitadas) | 0.1379 |
| Rango | 0 – 100 |
| Notas | Equivalente: PCT_VIV_SIN_AGUA. |

<a id="rz_sexcus"></a>
#### 74. `RZ_SEXCUS`

CONEVAL: % de viviendas que no disponen de excusado o sanitario.

| Campo | Valor |
|---|---|
| Bloque | Validación CONEVAL |
| Tipo | decimal |
| Unidad | % |
| Ámbito | Solo urbana |
| Fuente | CONEVAL_GRS2020 |
| Variable en la fuente | `col. 18` |
| Derivación | Lectura directa. |
| Universo | Según CONEVAL |
| Valores vacíos | E: rural; S: CONEVAL no lo publica |
| Dimensión sugerida | Validación externa |
| Sentido sugerido | + |
| Script | 06_coneval.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 0.0 % |
| Población con dato (urbana / rural) | 100.0 % / 0.0 % |
| Mediana (AGEB habitadas) | 0 |
| Rango | 0 – 100 |
| Notas | Equivalente: PCT_VIV_SIN_SANITARIO. |

<a id="rz_sdren"></a>
#### 75. `RZ_SDREN`

CONEVAL: % de viviendas que no disponen de drenaje.

| Campo | Valor |
|---|---|
| Bloque | Validación CONEVAL |
| Tipo | decimal |
| Unidad | % |
| Ámbito | Solo urbana |
| Fuente | CONEVAL_GRS2020 |
| Variable en la fuente | `col. 19` |
| Derivación | Lectura directa. |
| Universo | Según CONEVAL |
| Valores vacíos | E: rural; S: CONEVAL no lo publica |
| Dimensión sugerida | Validación externa |
| Sentido sugerido | + |
| Script | 06_coneval.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 0.0 % |
| Población con dato (urbana / rural) | 100.0 % / 0.0 % |
| Mediana (AGEB habitadas) | 0.09804 |
| Rango | 0 – 100 |
| Notas | Equivalente: PCT_VIV_SIN_DRENAJE. |

<a id="rz_selec"></a>
#### 76. `RZ_SELEC`

CONEVAL: % de viviendas que no disponen de energía eléctrica.

| Campo | Valor |
|---|---|
| Bloque | Validación CONEVAL |
| Tipo | decimal |
| Unidad | % |
| Ámbito | Solo urbana |
| Fuente | CONEVAL_GRS2020 |
| Variable en la fuente | `col. 20` |
| Derivación | Lectura directa. |
| Universo | Según CONEVAL |
| Valores vacíos | E: rural; S: CONEVAL no lo publica |
| Dimensión sugerida | Validación externa |
| Sentido sugerido | + |
| Script | 06_coneval.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 0.0 % |
| Población con dato (urbana / rural) | 100.0 % / 0.0 % |
| Mediana (AGEB habitadas) | 0 |
| Rango | 0 – 100 |
| Notas | Equivalente: PCT_VIV_SIN_ELECTRIC. |

<a id="rz_pisot"></a>
#### 77. `RZ_PISOT`

CONEVAL: % de viviendas con piso de tierra.

| Campo | Valor |
|---|---|
| Bloque | Validación CONEVAL |
| Tipo | decimal |
| Unidad | % |
| Ámbito | Solo urbana |
| Fuente | CONEVAL_GRS2020 |
| Variable en la fuente | `col. 21` |
| Derivación | Lectura directa. |
| Universo | Según CONEVAL |
| Valores vacíos | E: rural; S: CONEVAL no lo publica |
| Dimensión sugerida | Validación externa |
| Sentido sugerido | + |
| Script | 06_coneval.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 0.0 % |
| Población con dato (urbana / rural) | 100.0 % / 0.0 % |
| Mediana (AGEB habitadas) | 0.8247 |
| Rango | 0 – 100 |
| Notas | Equivalente: PCT_VIV_PISO_TIERRA. |

<a id="rz_slavad"></a>
#### 78. `RZ_SLAVAD`

CONEVAL: % de viviendas que no disponen de lavadora.

| Campo | Valor |
|---|---|
| Bloque | Validación CONEVAL |
| Tipo | decimal |
| Unidad | % |
| Ámbito | Solo urbana |
| Fuente | CONEVAL_GRS2020 |
| Variable en la fuente | `col. 22` |
| Derivación | Lectura directa. |
| Universo | Según CONEVAL |
| Valores vacíos | E: rural; S: CONEVAL no lo publica |
| Dimensión sugerida | Validación externa |
| Sentido sugerido | + |
| Script | 06_coneval.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 0.0 % |
| Población con dato (urbana / rural) | 100.0 % / 0.0 % |
| Mediana (AGEB habitadas) | 21.21 |
| Rango | 0 – 100 |
| Notas | Equivalente: 100 − PCT_VIV_LAVADORA. |

<a id="rz_srefri"></a>
#### 79. `RZ_SREFRI`

CONEVAL: % de viviendas que no disponen de refrigerador.

| Campo | Valor |
|---|---|
| Bloque | Validación CONEVAL |
| Tipo | decimal |
| Unidad | % |
| Ámbito | Solo urbana |
| Fuente | CONEVAL_GRS2020 |
| Variable en la fuente | `col. 23` |
| Derivación | Lectura directa. |
| Universo | Según CONEVAL |
| Valores vacíos | E: rural; S: CONEVAL no lo publica |
| Dimensión sugerida | Validación externa |
| Sentido sugerido | + |
| Script | 06_coneval.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 0.0 % |
| Población con dato (urbana / rural) | 100.0 % / 0.0 % |
| Mediana (AGEB habitadas) | 6.25 |
| Rango | 0 – 100 |
| Notas | Equivalente: 100 − PCT_VIV_REFRI. |

<a id="rz_stelf"></a>
#### 80. `RZ_STELF`

CONEVAL: % de viviendas que no disponen de línea telefónica fija.

| Campo | Valor |
|---|---|
| Bloque | Validación CONEVAL |
| Tipo | decimal |
| Unidad | % |
| Ámbito | Solo urbana |
| Fuente | CONEVAL_GRS2020 |
| Variable en la fuente | `col. 24` |
| Derivación | Lectura directa. |
| Universo | Según CONEVAL |
| Valores vacíos | E: rural; S: CONEVAL no lo publica |
| Dimensión sugerida | Validación externa |
| Sentido sugerido | + |
| Script | 06_coneval.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 0.0 % |
| Población con dato (urbana / rural) | 100.0 % / 0.0 % |
| Mediana (AGEB habitadas) | 68.81 |
| Rango | 0 – 100 |
| Notas | Equivalente: 100 − PCT_VIV_TELEFONO. |

<a id="rz_scel"></a>
#### 81. `RZ_SCEL`

CONEVAL: % de viviendas que no disponen de teléfono celular.

| Campo | Valor |
|---|---|
| Bloque | Validación CONEVAL |
| Tipo | decimal |
| Unidad | % |
| Ámbito | Solo urbana |
| Fuente | CONEVAL_GRS2020 |
| Variable en la fuente | `col. 25` |
| Derivación | Lectura directa. |
| Universo | Según CONEVAL |
| Valores vacíos | E: rural; S: CONEVAL no lo publica |
| Dimensión sugerida | Validación externa |
| Sentido sugerido | + |
| Script | 06_coneval.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 0.0 % |
| Población con dato (urbana / rural) | 100.0 % / 0.0 % |
| Mediana (AGEB habitadas) | 7.666 |
| Rango | 0 – 100 |
| Notas | Equivalente: 100 − PCT_VIV_CELULAR. |

<a id="rz_scompu"></a>
#### 82. `RZ_SCOMPU`

CONEVAL: % de viviendas que no disponen de computadora, laptop o tablet.

| Campo | Valor |
|---|---|
| Bloque | Validación CONEVAL |
| Tipo | decimal |
| Unidad | % |
| Ámbito | Solo urbana |
| Fuente | CONEVAL_GRS2020 |
| Variable en la fuente | `col. 26` |
| Derivación | Lectura directa. |
| Universo | Según CONEVAL |
| Valores vacíos | E: rural; S: CONEVAL no lo publica |
| Dimensión sugerida | Validación externa |
| Sentido sugerido | + |
| Script | 06_coneval.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 0.0 % |
| Población con dato (urbana / rural) | 100.0 % / 0.0 % |
| Mediana (AGEB habitadas) | 66.67 |
| Rango | 0 – 100 |
| Notas | Equivalente: 100 − PCT_VIV_COMPU. |

<a id="rz_sinter"></a>
#### 83. `RZ_SINTER`

CONEVAL: % de viviendas que no disponen de internet.

| Campo | Valor |
|---|---|
| Bloque | Validación CONEVAL |
| Tipo | decimal |
| Unidad | % |
| Ámbito | Solo urbana |
| Fuente | CONEVAL_GRS2020 |
| Variable en la fuente | `col. 27` |
| Derivación | Lectura directa. |
| Universo | Según CONEVAL |
| Valores vacíos | E: rural; S: CONEVAL no lo publica |
| Dimensión sugerida | Validación externa |
| Sentido sugerido | + |
| Script | 06_coneval.R |
| AGEB habitadas con dato (urbana / rural) | 95.5 % / 0.0 % |
| Población con dato (urbana / rural) | 100.0 % / 0.0 % |
| Mediana (AGEB habitadas) | 47.75 |
| Rango | 0 – 100 |
| Notas | Equivalente: 100 − PCT_VIV_INTERNET. |

<a id="denue_tot"></a>
#### 84. `DENUE_TOT`

Unidades económicas registradas en el DENUE.

| Campo | Valor |
|---|---|
| Bloque | Actividad económica |
| Tipo | entero |
| Unidad | establecimientos |
| Ámbito | Ambos |
| Fuente | DENUE |
| Variable en la fuente | `registros` |
| Derivación | Conteo de registros cuya clave de AGEB resuelve a esta AGEB. |
| Valores vacíos | Nunca (0 = sin establecimientos) |
| Dimensión sugerida | Contexto |
| Sentido sugerido | ± |
| Script | 07_denue.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 22 |
| Rango | 0 – 7,420 |
| Notas | Incluye todos los sectores SCIAN. DENUE es de 2026-05, no de 2020 (D-26). |

<a id="den_manuf"></a>
#### 85. `DEN_MANUF`

Unidades económicas de industrias manufactureras.

| Campo | Valor |
|---|---|
| Bloque | Actividad económica |
| Tipo | entero |
| Unidad | establecimientos |
| Ámbito | Ambos |
| Fuente | DENUE |
| Variable en la fuente | `codigo_act` |
| Derivación | Conteo con sector SCIAN 31, 32 o 33. |
| Valores vacíos | Nunca |
| Dimensión sugerida | Contexto |
| Sentido sugerido | ± |
| Script | 07_denue.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 2 |
| Rango | 0 – 948 |

<a id="den_com"></a>
#### 86. `DEN_COM`

Unidades económicas de comercio.

| Campo | Valor |
|---|---|
| Bloque | Actividad económica |
| Tipo | entero |
| Unidad | establecimientos |
| Ámbito | Ambos |
| Fuente | DENUE |
| Variable en la fuente | `codigo_act` |
| Derivación | Conteo con sector SCIAN 43 (mayoreo) o 46 (menudeo). |
| Valores vacíos | Nunca |
| Dimensión sugerida | Contexto |
| Sentido sugerido | ± |
| Script | 07_denue.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 9 |
| Rango | 0 – 6,655 |
| Notas | Proxy de acceso a abasto. |

<a id="den_serv"></a>
#### 87. `DEN_SERV`

Unidades económicas de servicios.

| Campo | Valor |
|---|---|
| Bloque | Actividad económica |
| Tipo | entero |
| Unidad | establecimientos |
| Ámbito | Ambos |
| Fuente | DENUE |
| Variable en la fuente | `codigo_act` |
| Derivación | Conteo con sector SCIAN entre 48 y 81. |
| Valores vacíos | Nunca |
| Dimensión sugerida | Contexto |
| Sentido sugerido | ± |
| Script | 07_denue.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 8 |
| Rango | 0 – 1,533 |
| Notas | Incluye a DEN_EDU: los conteos no son aditivos. |

<a id="den_edu"></a>
#### 88. `DEN_EDU`

Unidades económicas de servicios educativos.

| Campo | Valor |
|---|---|
| Bloque | Actividad económica |
| Tipo | entero |
| Unidad | establecimientos |
| Ámbito | Ambos |
| Fuente | DENUE |
| Variable en la fuente | `codigo_act` |
| Derivación | Conteo con sector SCIAN 61. |
| Valores vacíos | Nunca |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | − |
| Script | 07_denue.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 0 |
| Rango | 0 – 180 |
| Notas | Subconjunto de DEN_SERV. Idéntico a SCHOOL_TOT en todo el país. |

<a id="den_gob"></a>
#### 89. `DEN_GOB`

Unidades de actividades legislativas, gubernamentales y de impartición de justicia.

| Campo | Valor |
|---|---|
| Bloque | Actividad económica |
| Tipo | entero |
| Unidad | establecimientos |
| Ámbito | Ambos |
| Fuente | DENUE |
| Variable en la fuente | `codigo_act` |
| Derivación | Conteo con sector SCIAN 93. |
| Valores vacíos | Nunca |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | − |
| Script | 07_denue.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 0 |
| Rango | 0 – 331 |
| Notas | Proxy de presencia institucional. |

<a id="school_tot"></a>
#### 90. `SCHOOL_TOT`

Escuelas (proxy de posibles refugios temporales).

| Campo | Valor |
|---|---|
| Bloque | Actividad económica |
| Tipo | entero |
| Unidad | establecimientos |
| Ámbito | Ambos |
| Fuente | DENUE |
| Variable en la fuente | `codigo_act` |
| Derivación | Conteo con subsector SCIAN 611. |
| Valores vacíos | Nunca |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | − |
| Script | 07_denue.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 0 |
| Rango | 0 – 180 |
| Notas | Hoy es idéntico a DEN_EDU (el sector 61 solo tiene el subsector 611). No son refugios oficiales. |

<a id="water_area"></a>
#### 91. `WATER_AREA`

Superficie de cuerpos de agua dentro de la AGEB.

| Campo | Valor |
|---|---|
| Bloque | Hidrografía |
| Tipo | decimal |
| Unidad | km² |
| Decimales | 6 |
| Ámbito | Ambos |
| Fuente | INEGI_CA50 |
| Variable en la fuente | `geometría` |
| Derivación | Área de la intersección AGEB ∩ unión de cuerpos de agua, en EPSG:6372. |
| Valores vacíos | Nunca (0 = sin agua) |
| Dimensión sugerida | Exposición (contexto) |
| Sentido sugerido | ± |
| Script | 08_hydrology.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 0 |
| Rango | 0 – 1,579 |
| Notas | Intersección de áreas, nunca unión espacial (D-27). |

<a id="water_pct"></a>
#### 92. `WATER_PCT`

Porcentaje de la superficie de la AGEB cubierta por cuerpos de agua.

| Campo | Valor |
|---|---|
| Bloque | Hidrografía |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Derivación | min(100, 100 × WATER_AREA / AREA_KM2). |
| Universo | AREA_KM2 |
| Valores vacíos | Nunca |
| Dimensión sugerida | Exposición (contexto) |
| Sentido sugerido | ± |
| Script | 08_hydrology.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 0 |
| Rango | 0 – 100 |
| Notas | No mide amenaza de inundación: solo presencia de agua superficial cartografiada. |

<a id="has_water"></a>
#### 93. `HAS_WATER`

Indicador de presencia de cuerpos de agua en la AGEB.

| Campo | Valor |
|---|---|
| Bloque | Hidrografía |
| Tipo | binaria |
| Unidad | 0/1 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Derivación | 1 si WATER_AREA > 0; 0 en otro caso. |
| Valores vacíos | Nunca |
| Dimensión sugerida | Exposición (contexto) |
| Sentido sugerido | ± |
| Script | 08_hydrology.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 0 |
| Rango | 0 – 1 |

<a id="uso_dom"></a>
#### 94. `USO_DOM`

Clase de uso de suelo y vegetación que ocupa más superficie de la AGEB.

| Campo | Valor |
|---|---|
| Bloque | Uso de suelo |
| Tipo | categórica |
| Ámbito | Ambos |
| Fuente | INEGI_USV7 |
| Variable en la fuente | `DESCRIPCIO` |
| Derivación | Clase con mayor área disuelta dentro de la AGEB. |
| Valores vacíos | C: ningún polígono USV intersecta la AGEB |
| Dimensión sugerida | Exposición (contexto) |
| Sentido sugerido | ± |
| Script | 09_landuse.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Notas | 129 clases a nivel nacional; 'ASENTAMIENTOS HUMANOS' es la más frecuente. Escala 1:250,000: poco detalle en AGEB urbanas chicas. |

<a id="uso_pct"></a>
#### 95. `USO_PCT`

Porcentaje de la AGEB cubierto por la clase dominante.

| Campo | Valor |
|---|---|
| Bloque | Uso de suelo |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Derivación | min(100, 100 × área de USO_DOM / AREA_KM2). |
| Universo | AREA_KM2 |
| Valores vacíos | C: igual que USO_DOM |
| Dimensión sugerida | Exposición (contexto) |
| Sentido sugerido | n/a |
| Script | 09_landuse.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 93.64 |
| Rango | 0.08 – 100 |

<a id="pct_urb"></a>
#### 96. `PCT_URB`

Porcentaje de la AGEB clasificado como asentamiento humano o zona urbana.

| Campo | Valor |
|---|---|
| Bloque | Uso de suelo |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `DESCRIPCIO` |
| Derivación | min(100, Σ CLASS_PCT de clases que contienen ASENTAMIENTO, ZONA URBANA o URBANO). |
| Universo | AREA_KM2 |
| Valores vacíos | Nunca (0 = sin clase urbana) |
| Dimensión sugerida | Exposición (contexto) |
| Sentido sugerido | ± |
| Script | 09_landuse.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 74.9 |
| Rango | 0 – 100 |
| Notas | Proxy grueso de superficie construida (isla de calor), limitado por la escala 1:250,000. |

<a id="dist_hosp_km"></a>
#### 97. `DIST_HOSP_KM`

Distancia a la unidad hospitalaria en operación más cercana (segundo o tercer nivel), pública o privada.

| Campo | Valor |
|---|---|
| Bloque | Acceso a salud |
| Tipo | decimal |
| Unidad | km |
| Decimales | 3 |
| Ámbito | Ambos |
| Fuente | CLUES |
| Variable en la fuente | `LATITUD, LONGITUD, NOMBRE TIPO ESTABLECIMIENTO` |
| Derivación | Distancia euclidiana en EPSG:6372 al hospital más cercano del país. Urbana y rural deshabitada: desde el punto interior de la AGEB. Rural habitada: promedio de sus localidades habitadas ponderado por POBTOT (ver DIST_ORIGEN). |
| Universo | Unidades CLUES en operación de tipo DE HOSPITALIZACIÓN, sin psiquiátricos ni de adicciones, geocodificadas a ≤ 5 km de su entidad |
| Valores vacíos | Nunca |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | + |
| Script | 09b_health.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 2.748 |
| Rango | 0.005 – 703.5 |
| Notas | Distancia en línea recta, no tiempo de traslado: subestima el acceso en zonas serranas. Incluye 3,645 hospitales privados, muchos de ellos clínicas pequeñas; para población sin seguridad social usa DIST_HOSP_PUB_KM. |

<a id="dist_hosp_pub_km"></a>
#### 98. `DIST_HOSP_PUB_KM`

Distancia al hospital público en operación más cercano (segundo o tercer nivel).

| Campo | Valor |
|---|---|
| Bloque | Acceso a salud |
| Tipo | decimal |
| Unidad | km |
| Decimales | 3 |
| Ámbito | Ambos |
| Fuente | CLUES |
| Variable en la fuente | `LATITUD, LONGITUD, NOMBRE DE LA INSTITUCION` |
| Derivación | Igual que DIST_HOSP_KM, restringido a instituciones públicas. |
| Universo | Hospitales de DIST_HOSP_KM excepto servicios médicos privados y Cruz Roja |
| Valores vacíos | Nunca |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | + |
| Script | 09b_health.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 4.652 |
| Rango | 0.01 – 703.5 |
| Notas | Distancia en línea recta, no tiempo de traslado: subestima el acceso en zonas serranas. Siempre ≥ DIST_HOSP_KM (control health_public_hospital_not_nearer). |

<a id="dist_1nivel_pub_km"></a>
#### 99. `DIST_1NIVEL_PUB_KM`

Distancia a la unidad pública de primer nivel en operación más cercana (centro de salud, unidad de medicina familiar, unidad médica rural).

| Campo | Valor |
|---|---|
| Bloque | Acceso a salud |
| Tipo | decimal |
| Unidad | km |
| Decimales | 3 |
| Ámbito | Ambos |
| Fuente | CLUES |
| Variable en la fuente | `LATITUD, LONGITUD, NIVEL ATENCION` |
| Derivación | Igual que DIST_HOSP_KM, con unidades de consulta externa de primer nivel. |
| Universo | Unidades CLUES en operación DE CONSULTA EXTERNA y PRIMER NIVEL, públicas, fijas (sin unidades móviles ni brigadas), sin fiscalías, forenses, CIJ, SCT ni DIF |
| Valores vacíos | Nunca |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | + |
| Script | 09b_health.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 1.061 |
| Rango | 0 – 703.9 |
| Notas | Distancia en línea recta, no tiempo de traslado: subestima el acceso en zonas serranas. Casi siempre corto (mediana < 1 km en AGEB urbanas); discrimina sobre todo en AGEB rurales. |

<a id="dist_origen"></a>
#### 100. `DIST_ORIGEN`

Punto desde el que se midieron las distancias a unidades de salud, cauces y costa.

| Campo | Valor |
|---|---|
| Bloque | Acceso a salud |
| Tipo | categórica |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Derivación | 'Localidades' si la AGEB es rural y tiene localidades habitadas en {ENT}lpr.shp; si no, 'Punto interior'. |
| Valores vacíos | Nunca |
| Dimensión sugerida | Metadato |
| Sentido sugerido | n/a |
| Script | 09b_health.R; 09c_terrain.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Notas | Valores: Localidades, Punto interior. Toda AGEB urbana usa el punto interior; una rural con Punto interior está deshabitada. En relieve (ELEV_M, pendientes) el mismo criterio usa el polígono completo en lugar del punto interior, y discos de 150 m en lugar de las localidades puntuales. |

<a id="elev_m"></a>
#### 101. `ELEV_M`

Elevación media del terreno habitado sobre el nivel medio del mar.

| Campo | Valor |
|---|---|
| Bloque | Relieve y exposición |
| Tipo | decimal |
| Unidad | m |
| Decimales | 1 |
| Ámbito | Ambos |
| Fuente | CEM4 |
| Variable en la fuente | `valor del ráster` |
| Derivación | Media de las celdas del CEM 4.0 (15 m). Urbana y rural deshabitada: sobre todo el polígono. Rural habitada: disco de 150 m (TERRAIN_BUFFER_M) alrededor de cada localidad habitada, promedio ponderado por POBTOT. |
| Universo | Celdas del CEM dentro del polígono o de los discos |
| Valores vacíos | C: islas que el CEM no cubre |
| Dimensión sugerida | Exposición (contexto) |
| Sentido sugerido | ± |
| Script | 09c_terrain.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 1,268 |
| Rango | -4.4 – 3,773 |
| Notas | Referida al Geoide Gravimétrico Mexicano 2010. Puede ser ligeramente negativa en planicies costeras. Junto con DIST_COSTA_KM identifica zonas bajas costeras. |

<a id="pend_media_grad"></a>
#### 102. `PEND_MEDIA_GRAD`

Pendiente media del terreno habitado.

| Campo | Valor |
|---|---|
| Bloque | Relieve y exposición |
| Tipo | decimal |
| Unidad | grados |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | CEM4 |
| Variable en la fuente | `valor del ráster` |
| Derivación | terra::terrain(slope, grados) sobre el CEM 4.0; media por zona. Urbana y rural deshabitada: sobre todo el polígono. Rural habitada: disco de 150 m (TERRAIN_BUFFER_M) alrededor de cada localidad habitada, promedio ponderado por POBTOT. |
| Universo | Igual que ELEV_M |
| Valores vacíos | C: islas que el CEM no cubre |
| Dimensión sugerida | Exposición (deslizamiento) |
| Sentido sugerido | + |
| Script | 09c_terrain.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 3.5 |
| Rango | 0 – 44.89 |
| Notas | El CEM 4.0 viene de radar (ALOS PALSAR): en ciudades densas sigue en parte los techos, así que la pendiente urbana sale algo rugosa. |

<a id="pct_pend_15"></a>
#### 103. `PCT_PEND_15`

Porcentaje del terreno habitado con pendiente mayor a 15 grados.

| Campo | Valor |
|---|---|
| Bloque | Relieve y exposición |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | CEM4 |
| Variable en la fuente | `valor del ráster` |
| Derivación | 100 × proporción de celdas con pendiente > 15°. Urbana y rural deshabitada: sobre todo el polígono. Rural habitada: disco de 150 m (TERRAIN_BUFFER_M) alrededor de cada localidad habitada, promedio ponderado por POBTOT. |
| Universo | Igual que ELEV_M |
| Valores vacíos | C: islas que el CEM no cubre |
| Dimensión sugerida | Exposición (deslizamiento) |
| Sentido sugerido | + |
| Script | 09c_terrain.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 0 |
| Rango | 0 – 100 |
| Notas | 15° es un umbral habitual de susceptibilidad moderada a procesos de remoción en masa. |

<a id="pct_pend_30"></a>
#### 104. `PCT_PEND_30`

Porcentaje del terreno habitado con pendiente mayor a 30 grados.

| Campo | Valor |
|---|---|
| Bloque | Relieve y exposición |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | CEM4 |
| Variable en la fuente | `valor del ráster` |
| Derivación | 100 × proporción de celdas con pendiente > 30°. Urbana y rural deshabitada: sobre todo el polígono. Rural habitada: disco de 150 m (TERRAIN_BUFFER_M) alrededor de cada localidad habitada, promedio ponderado por POBTOT. |
| Universo | Igual que ELEV_M |
| Valores vacíos | C: islas que el CEM no cubre |
| Dimensión sugerida | Exposición (deslizamiento) |
| Sentido sugerido | + |
| Script | 09c_terrain.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 0 |
| Rango | 0 – 100 |
| Notas | Siempre ≤ PCT_PEND_15 (control terrain_slope_consistent). Mediana 0: muy concentrado en la sierra. |

<a id="dist_cauce_km"></a>
#### 105. `DIST_CAUCE_KM`

Distancia en línea recta al cauce más cercano de orden de Strahler 3 o mayor.

| Campo | Valor |
|---|---|
| Bloque | Relieve y exposición |
| Tipo | decimal |
| Unidad | km |
| Decimales | 3 |
| Ámbito | Ambos |
| Fuente | RED_HIDRO50 |
| Variable en la fuente | `ORDER_1` |
| Derivación | Distancia en EPSG:6372 al segmento más cercano de la red hidrográfica con ORDER_1 ≥ 3 (STREAM_MIN_ORDER). Desde el punto interior (urbana y rural deshabitada) o desde cada localidad habitada, ponderado por POBTOT (ver DIST_ORIGEN). |
| Universo | Líneas de flujo (corrientes y líneas centrales) de orden ≥ 3, perennes o intermitentes |
| Valores vacíos | Nunca |
| Dimensión sugerida | Exposición (inundación) |
| Sentido sugerido | − |
| Script | 09c_terrain.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 0.77 |
| Rango | 0 – 971.7 |
| Notas | A escala 1:50 000 casi todo punto está a pocos cientos de metros de un arroyo de orden 1; el filtro de orden deja cauces con cuenca apreciable. Úsala junto con DESNIVEL_CAUCE_M: cerca y poco por encima es lo que indica riesgo. |

<a id="desnivel_cauce_m"></a>
#### 106. `DESNIVEL_CAUCE_M`

Altura del terreno habitado sobre el agua más cercana: el lecho del cauce de orden ≥ 3 o el mar, lo que esté más cerca.

| Campo | Valor |
|---|---|
| Bloque | Relieve y exposición |
| Tipo | decimal |
| Unidad | m |
| Decimales | 1 |
| Ámbito | Ambos |
| Fuente | CEM4; RED_HIDRO50; CONABIO_COSTA |
| Derivación | ELEV_M del origen (disco o polígono) menos la elevación del agua más cercana: la celda más baja del CEM en 45 m (STREAM_BED_RADIUS_M) alrededor del punto más cercano del cauce, o 0 si la costa está más cerca. Ponderado por POBTOT en AGEB rurales. |
| Universo | Igual que DIST_CAUCE_KM |
| Valores vacíos | C: el lecho cae fuera del CEM |
| Dimensión sugerida | Exposición (inundación) |
| Sentido sugerido | − |
| Script | 09c_terrain.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 10.3 |
| Rango | -324.5 – 1,570 |
| Notas | Aproximación de HAND (altura sobre el drenaje más cercano) con el cauce más cercano en planta, no el de la trayectoria real del agua: puede ser negativa si ese cauce corre en el valle vecino. No considera bordos, capacidad del cauce ni lluvia. |

<a id="dist_costa_km"></a>
#### 107. `DIST_COSTA_KM`

Distancia en línea recta a la línea de costa.

| Campo | Valor |
|---|---|
| Bloque | Relieve y exposición |
| Tipo | decimal |
| Unidad | km |
| Decimales | 3 |
| Ámbito | Ambos |
| Fuente | CONABIO_COSTA |
| Variable en la fuente | `DESCRIP` |
| Derivación | Distancia en EPSG:6372 al segmento de costa más cercano, sin los segmentos Frontera. Mismos orígenes que DIST_CAUCE_KM. |
| Universo | Línea de costa continental e insular |
| Valores vacíos | Nunca |
| Dimensión sugerida | Exposición (marea de tormenta) |
| Sentido sugerido | − |
| Script | 09c_terrain.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 181.4 |
| Rango | 0.001 – 677.7 |
| Notas | Las lagunas costeras cuentan solo donde la capa de CONABIO las traza como costa. Para marea de tormenta, combinar con ELEV_M (p. ej. < 10 m). |

<a id="amz_inund"></a>
#### 108. `AMZ_INUND`

Grado de peligro por inundación del municipio al que pertenece la AGEB.

| Campo | Valor |
|---|---|
| Bloque | Amenaza (CENAPRED) |
| Tipo | categórica ordinal |
| Unidad | grado (1–5) |
| Ámbito | Ambos |
| Fuente | CENAPRED_SITU2023 |
| Variable en la fuente | `gp_inundac` |
| Derivación | Etiqueta de CENAPRED recodificada: Muy bajo=1, Bajo=2, Medio=3, Alto=4, Muy alto=5. |
| Valores vacíos | C: solo si el municipio no tiene fila en la tabla de CENAPRED |
| Dimensión sugerida | Amenaza (fuera del índice) |
| Sentido sugerido | n/a |
| Script | 13_hazard.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 4 |
| Rango | 1 – 5 |
| Notas | Resolución municipal: todas las AGEB del municipio comparten el valor. Es una clase ordinal, no una magnitud física, y su escala no es comparable con la de otra amenaza. Queda fuera del índice de vulnerabilidad (D-30). Distribución nacional casi uniforme entre las cinco clases (492–496 municipios cada una). |

<a id="amz_sequia"></a>
#### 109. `AMZ_SEQUIA`

Grado de peligro por sequía del municipio al que pertenece la AGEB.

| Campo | Valor |
|---|---|
| Bloque | Amenaza (CENAPRED) |
| Tipo | categórica ordinal |
| Unidad | grado (1–5) |
| Ámbito | Ambos |
| Fuente | CENAPRED_SITU2023 |
| Variable en la fuente | `gp_sequia2` |
| Derivación | Etiqueta de CENAPRED recodificada: Muy bajo=1, Bajo=2, Medio=3, Alto=4, Muy alto=5. |
| Valores vacíos | C: solo si el municipio no tiene fila en la tabla de CENAPRED |
| Dimensión sugerida | Amenaza (fuera del índice) |
| Sentido sugerido | n/a |
| Script | 13_hazard.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 3 |
| Rango | 1 – 5 |
| Notas | Resolución municipal: todas las AGEB del municipio comparten el valor. Es una clase ordinal, no una magnitud física, y su escala no es comparable con la de otra amenaza. Queda fuera del índice de vulnerabilidad (D-30). Muy sesgada: solo 9 municipios son Muy alto y 1,082 son Bajo. |

<a id="amz_onda_cal"></a>
#### 110. `AMZ_ONDA_CAL`

Grado de peligro por ondas cálidas (calor extremo) del municipio al que pertenece la AGEB.

| Campo | Valor |
|---|---|
| Bloque | Amenaza (CENAPRED) |
| Tipo | categórica ordinal |
| Unidad | grado (1–5) |
| Ámbito | Ambos |
| Fuente | CENAPRED_SITU2023 |
| Variable en la fuente | `gp_ondasca` |
| Derivación | Etiqueta de CENAPRED recodificada: Muy bajo=1, Bajo=2, Medio=3, Alto=4, Muy alto=5. |
| Valores vacíos | C: solo si el municipio no tiene fila en la tabla de CENAPRED |
| Dimensión sugerida | Amenaza (fuera del índice) |
| Sentido sugerido | n/a |
| Script | 13_hazard.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 3 |
| Rango | 1 – 5 |
| Notas | Resolución municipal: todas las AGEB del municipio comparten el valor. Es una clase ordinal, no una magnitud física, y su escala no es comparable con la de otra amenaza. Queda fuera del índice de vulnerabilidad (D-30). Es la amenaza de calor disponible a esta escala; no sustituye un indicador de isla de calor intraurbana. |

<a id="amz_ciclon"></a>
#### 111. `AMZ_CICLON`

Grado de peligro por ciclones tropicales del municipio al que pertenece la AGEB.

| Campo | Valor |
|---|---|
| Bloque | Amenaza (CENAPRED) |
| Tipo | categórica ordinal |
| Unidad | grado (1–5) |
| Ámbito | Ambos |
| Fuente | CENAPRED_SITU2023 |
| Variable en la fuente | `gp_ciclnes` |
| Derivación | Etiqueta de CENAPRED recodificada: Muy bajo=1, Bajo=2, Medio=3, Alto=4, Muy alto=5. |
| Valores vacíos | C: solo si el municipio no tiene fila en la tabla de CENAPRED |
| Dimensión sugerida | Amenaza (fuera del índice) |
| Sentido sugerido | n/a |
| Script | 13_hazard.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 1 |
| Rango | 1 – 5 |
| Notas | Resolución municipal: todas las AGEB del municipio comparten el valor. Es una clase ordinal, no una magnitud física, y su escala no es comparable con la de otra amenaza. Queda fuera del índice de vulnerabilidad (D-30). |

<a id="amz_desliz"></a>
#### 112. `AMZ_DESLIZ`

Grado de susceptibilidad a deslizamientos de laderas del municipio al que pertenece la AGEB.

| Campo | Valor |
|---|---|
| Bloque | Amenaza (CENAPRED) |
| Tipo | categórica ordinal |
| Unidad | grado (1–5) |
| Ámbito | Ambos |
| Fuente | CENAPRED_SITU2023 |
| Variable en la fuente | `susceplad` |
| Derivación | Etiqueta de CENAPRED recodificada: Muy bajo=1, Bajo=2, Medio=3, Alto=4, Muy alto=5. |
| Valores vacíos | C: solo si el municipio no tiene fila en la tabla de CENAPRED |
| Dimensión sugerida | Amenaza (fuera del índice) |
| Sentido sugerido | n/a |
| Script | 13_hazard.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 4 |
| Rango | 1 – 5 |
| Notas | Resolución municipal: todas las AGEB del municipio comparten el valor. Es una clase ordinal, no una magnitud física, y su escala no es comparable con la de otra amenaza. Queda fuera del índice de vulnerabilidad (D-30). Susceptibilidad del terreno, no peligro con periodo de retorno. 1,692 de 2,469 municipios son Alto, así que discrimina poco por sí sola. |

<a id="amz_torm_elec"></a>
#### 113. `AMZ_TORM_ELEC`

Grado de peligro por tormentas eléctricas del municipio al que pertenece la AGEB.

| Campo | Valor |
|---|---|
| Bloque | Amenaza (CENAPRED) |
| Tipo | categórica ordinal |
| Unidad | grado (1–5) |
| Ámbito | Ambos |
| Fuente | CENAPRED_SITU2023 |
| Variable en la fuente | `gp_tormele` |
| Derivación | Etiqueta de CENAPRED recodificada: Muy bajo=1, Bajo=2, Medio=3, Alto=4, Muy alto=5. |
| Valores vacíos | C: solo si el municipio no tiene fila en la tabla de CENAPRED |
| Dimensión sugerida | Amenaza (fuera del índice) |
| Sentido sugerido | n/a |
| Script | 13_hazard.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 3 |
| Rango | 1 – 5 |
| Notas | Resolución municipal: todas las AGEB del municipio comparten el valor. Es una clase ordinal, no una magnitud física, y su escala no es comparable con la de otra amenaza. Queda fuera del índice de vulnerabilidad (D-30). |

<a id="amz_granizo"></a>
#### 114. `AMZ_GRANIZO`

Grado de peligro por granizo del municipio al que pertenece la AGEB.

| Campo | Valor |
|---|---|
| Bloque | Amenaza (CENAPRED) |
| Tipo | categórica ordinal |
| Unidad | grado (1–5) |
| Ámbito | Ambos |
| Fuente | CENAPRED_SITU2023 |
| Variable en la fuente | `gp_granizo` |
| Derivación | Etiqueta de CENAPRED recodificada: Muy bajo=1, Bajo=2, Medio=3, Alto=4, Muy alto=5. |
| Valores vacíos | C: solo si el municipio no tiene fila en la tabla de CENAPRED |
| Dimensión sugerida | Amenaza (fuera del índice) |
| Sentido sugerido | n/a |
| Script | 13_hazard.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 2 |
| Rango | 1 – 5 |
| Notas | Resolución municipal: todas las AGEB del municipio comparten el valor. Es una clase ordinal, no una magnitud física, y su escala no es comparable con la de otra amenaza. Queda fuera del índice de vulnerabilidad (D-30). |

<a id="amz_temp_baja"></a>
#### 115. `AMZ_TEMP_BAJA`

Grado de peligro por temperaturas bajas del municipio al que pertenece la AGEB.

| Campo | Valor |
|---|---|
| Bloque | Amenaza (CENAPRED) |
| Tipo | categórica ordinal |
| Unidad | grado (1–5) |
| Ámbito | Ambos |
| Fuente | CENAPRED_SITU2023 |
| Variable en la fuente | `gp_bajaste` |
| Derivación | Etiqueta de CENAPRED recodificada: Muy bajo=1, Bajo=2, Medio=3, Alto=4, Muy alto=5. |
| Valores vacíos | C: solo si el municipio no tiene fila en la tabla de CENAPRED |
| Dimensión sugerida | Amenaza (fuera del índice) |
| Sentido sugerido | n/a |
| Script | 13_hazard.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 2 |
| Rango | 1 – 5 |
| Notas | Resolución municipal: todas las AGEB del municipio comparten el valor. Es una clase ordinal, no una magnitud física, y su escala no es comparable con la de otra amenaza. Queda fuera del índice de vulnerabilidad (D-30). |

<a id="amz_nevada"></a>
#### 116. `AMZ_NEVADA`

Grado de peligro por nevadas del municipio al que pertenece la AGEB.

| Campo | Valor |
|---|---|
| Bloque | Amenaza (CENAPRED) |
| Tipo | categórica ordinal |
| Unidad | grado (1–5) |
| Ámbito | Ambos |
| Fuente | CENAPRED_SITU2023 |
| Variable en la fuente | `gp_nevadas` |
| Derivación | Etiqueta de CENAPRED recodificada: Muy bajo=1, Bajo=2, Medio=3, Alto=4, Muy alto=5. |
| Valores vacíos | C: solo si el municipio no tiene fila en la tabla de CENAPRED |
| Dimensión sugerida | Amenaza (fuera del índice) |
| Sentido sugerido | n/a |
| Script | 13_hazard.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 1 |
| Rango | 1 – 5 |
| Notas | Resolución municipal: todas las AGEB del municipio comparten el valor. Es una clase ordinal, no una magnitud física, y su escala no es comparable con la de otra amenaza. Queda fuera del índice de vulnerabilidad (D-30). 2,318 de 2,469 municipios son Muy bajo: solo informativa en el norte y en zonas de alta montaña. |

<a id="amz_sismo"></a>
#### 117. `AMZ_SISMO`

Grado de peligro sísmico del municipio al que pertenece la AGEB.

| Campo | Valor |
|---|---|
| Bloque | Amenaza (CENAPRED) |
| Tipo | categórica ordinal |
| Unidad | grado (1–5) |
| Ámbito | Ambos |
| Fuente | CENAPRED_SITU2023 |
| Variable en la fuente | `gp_sismico` |
| Derivación | Etiqueta de CENAPRED recodificada: Muy bajo=1, Bajo=2, Medio=3, Alto=4, Muy alto=5. |
| Valores vacíos | C: solo si el municipio no tiene fila en la tabla de CENAPRED |
| Dimensión sugerida | Amenaza (fuera del índice) |
| Sentido sugerido | n/a |
| Script | 13_hazard.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 3 |
| Rango | 2 – 5 |
| Notas | Resolución municipal: todas las AGEB del municipio comparten el valor. Es una clase ordinal, no una magnitud física, y su escala no es comparable con la de otra amenaza. Queda fuera del índice de vulnerabilidad (D-30). No es amenaza climática; se incluye para análisis multiamenaza. La clase Muy bajo no se usa en ningún municipio. |

<a id="amz_volcan"></a>
#### 118. `AMZ_VOLCAN`

Grado de peligro volcánico del municipio al que pertenece la AGEB.

| Campo | Valor |
|---|---|
| Bloque | Amenaza (CENAPRED) |
| Tipo | categórica ordinal |
| Unidad | grado (0–5) |
| Ámbito | Ambos |
| Fuente | CENAPRED_SITU2023 |
| Variable en la fuente | `volcanes` |
| Derivación | Etiqueta de CENAPRED recodificada: Muy bajo=1, Bajo=2, Medio=3, Alto=4, Muy alto=5. 'Sin peligro' = 0. |
| Valores vacíos | C: solo si el municipio no tiene fila en la tabla de CENAPRED |
| Dimensión sugerida | Amenaza (fuera del índice) |
| Sentido sugerido | n/a |
| Script | 13_hazard.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 2 |
| Rango | 0 – 5 |
| Notas | Resolución municipal: todas las AGEB del municipio comparten el valor. Es una clase ordinal, no una magnitud física, y su escala no es comparable con la de otra amenaza. Queda fuera del índice de vulnerabilidad (D-30). Única columna con 0 = 'Sin Peligro' (1,138 municipios), que es ausencia real de amenaza, no dato faltante. No es amenaza climática. |

<a id="amz_sus_tox"></a>
#### 119. `AMZ_SUS_TOX`

Grado de peligro por sustancias tóxicas del municipio al que pertenece la AGEB.

| Campo | Valor |
|---|---|
| Bloque | Amenaza (CENAPRED) |
| Tipo | categórica ordinal |
| Unidad | grado (0–5) |
| Ámbito | Ambos |
| Fuente | CENAPRED_SITU2023 |
| Variable en la fuente | `gp_sustox` |
| Derivación | Etiqueta de CENAPRED recodificada: Muy bajo=1, Bajo=2, Medio=3, Alto=4, Muy alto=5. 'Sin peligro' = 0. |
| Valores vacíos | C: 12 municipios de creación reciente (02006, 04012, 07120–07125, 17034–17036, 23011) traen el campo en blanco en la fuente |
| Dimensión sugerida | Amenaza (fuera del índice) |
| Sentido sugerido | n/a |
| Script | 13_hazard.R |
| AGEB habitadas con dato (urbana / rural) | 99.8 % / 99.6 % |
| Población con dato (urbana / rural) | 99.8 % / 99.7 % |
| Mediana (AGEB habitadas) | 0 |
| Rango | 0 – 5 |
| Notas | Resolución municipal: todas las AGEB del municipio comparten el valor. Es una clase ordinal, no una magnitud física, y su escala no es comparable con la de otra amenaza. Queda fuera del índice de vulnerabilidad (D-30). Riesgo tecnológico, no climático. 0 = 'Sin peligro': el municipio no registra instalaciones con esas sustancias, no es dato faltante. |

<a id="amz_sus_infla"></a>
#### 120. `AMZ_SUS_INFLA`

Grado de peligro por sustancias inflamables del municipio al que pertenece la AGEB.

| Campo | Valor |
|---|---|
| Bloque | Amenaza (CENAPRED) |
| Tipo | categórica ordinal |
| Unidad | grado (0–5) |
| Ámbito | Ambos |
| Fuente | CENAPRED_SITU2023 |
| Variable en la fuente | `gp_susinfl` |
| Derivación | Etiqueta de CENAPRED recodificada: Muy bajo=1, Bajo=2, Medio=3, Alto=4, Muy alto=5. 'Sin peligro' = 0. |
| Valores vacíos | C: 12 municipios de creación reciente (02006, 04012, 07120–07125, 17034–17036, 23011) traen el campo en blanco en la fuente |
| Dimensión sugerida | Amenaza (fuera del índice) |
| Sentido sugerido | n/a |
| Script | 13_hazard.R |
| AGEB habitadas con dato (urbana / rural) | 99.8 % / 99.6 % |
| Población con dato (urbana / rural) | 99.8 % / 99.7 % |
| Mediana (AGEB habitadas) | 2 |
| Rango | 0 – 5 |
| Notas | Resolución municipal: todas las AGEB del municipio comparten el valor. Es una clase ordinal, no una magnitud física, y su escala no es comparable con la de otra amenaza. Queda fuera del índice de vulnerabilidad (D-30). Riesgo tecnológico, no climático. 0 = 'Sin peligro': el municipio no registra instalaciones con esas sustancias, no es dato faltante. |

<a id="cen_resil"></a>
#### 121. `CEN_RESIL`

Grado de resiliencia del municipio según CENAPRED.

| Campo | Valor |
|---|---|
| Bloque | Amenaza (CENAPRED) |
| Tipo | categórica ordinal |
| Unidad | grado (1–5) |
| Ámbito | Ambos |
| Fuente | CENAPRED_SITU2023 |
| Variable en la fuente | `g_resilien` |
| Derivación | Etiqueta de CENAPRED recodificada: Muy bajo=1, Bajo=2, Medio=3, Alto=4, Muy alto=5. |
| Valores vacíos | C: solo si el municipio no tiene fila en la tabla de CENAPRED |
| Dimensión sugerida | Validación externa |
| Sentido sugerido | − |
| Script | 13_hazard.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 4 |
| Rango | 1 – 5 |
| Notas | Juicio municipal de CENAPRED, no insumo del índice: se publica para contrastarlo con lo que esta base calcula por AGEB, igual que GRS_GRADO (D-23). Un valor mayor indica más resiliencia, es decir menos vulnerabilidad. |

<a id="cen_vuln_cc"></a>
#### 122. `CEN_VULN_CC`

Municipio clasificado por CENAPRED como vulnerable al cambio climático.

| Campo | Valor |
|---|---|
| Bloque | Amenaza (CENAPRED) |
| Tipo | binaria |
| Ámbito | Ambos |
| Fuente | CENAPRED_SITU2023 |
| Variable en la fuente | `v_cc` |
| Derivación | 'Si' = 1, 'No' = 0. |
| Valores vacíos | C: 12 municipios de creación reciente (02006, 04012, 07120–07125, 17034–17036, 23011) traen el campo en blanco en la fuente |
| Dimensión sugerida | Validación externa |
| Sentido sugerido | + |
| Script | 13_hazard.R |
| AGEB habitadas con dato (urbana / rural) | 99.8 % / 99.6 % |
| Población con dato (urbana / rural) | 99.8 % / 99.7 % |
| Mediana (AGEB habitadas) | 0 |
| Rango | 0 – 1 |
| Notas | 319 municipios marcados Sí. CENAPRED no publica con esta capa el criterio de corte; úsese como contraste, no como insumo. |

<a id="ing_mun_hog_trim"></a>
#### 123. `ING_MUN_HOG_TRIM`

Ingreso corriente promedio trimestral por hogar del municipio al que pertenece la AGEB.

| Campo | Valor |
|---|---|
| Bloque | Ingreso (municipal) |
| Tipo | decimal |
| Unidad | pesos de 2022 por hogar por trimestre |
| Decimales | 0 |
| Ámbito | Ambos |
| Fuente | ICMM2022 |
| Variable en la fuente | `icpth (est = 1)` |
| Derivación | Estimación del INEGI en áreas pequeñas a partir de la ENIGH 2022, el censo 2020 y registros administrativos; se toma el valor tal cual. |
| Universo | Hogares del municipio |
| Valores vacíos | C: solo si el municipio no tiene fila en el ICMM |
| Dimensión sugerida | Capacidad adaptativa |
| Sentido sugerido | − |
| Script | 13b_income.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 57,083 |
| Rango | 15,166 – 161,535 |
| Notas | Resolución municipal: todas las AGEB del municipio comparten el valor y no hay variación intramunicipal. Es una media (la jalan los hogares de mayor ingreso), a precios corrientes de agosto–noviembre de 2022; divide entre 3 para el ingreso mensual. El censo no pregunta ingreso, así que es la única medida de ingreso de la base. |

<a id="ing_mun_lim_inf"></a>
#### 124. `ING_MUN_LIM_INF`

Límite inferior del intervalo de confianza al 90 % de ING_MUN_HOG_TRIM.

| Campo | Valor |
|---|---|
| Bloque | Ingreso (municipal) |
| Tipo | decimal |
| Unidad | pesos de 2022 por hogar por trimestre |
| Decimales | 0 |
| Ámbito | Ambos |
| Fuente | ICMM2022 |
| Variable en la fuente | `icpth (est = 3)` |
| Derivación | Directo. |
| Universo | Hogares del municipio |
| Valores vacíos | C: solo si el municipio no tiene fila en el ICMM |
| Dimensión sugerida | Confiabilidad |
| Sentido sugerido | n/a |
| Script | 13b_income.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 50,308 |
| Rango | 14,047 – 140,299 |
| Notas | Equivale a ING_MUN_HOG_TRIM − 1.645 × error estándar. Úsese para decidir si dos municipios difieren de verdad. |

<a id="ing_mun_lim_sup"></a>
#### 125. `ING_MUN_LIM_SUP`

Límite superior del intervalo de confianza al 90 % de ING_MUN_HOG_TRIM.

| Campo | Valor |
|---|---|
| Bloque | Ingreso (municipal) |
| Tipo | decimal |
| Unidad | pesos de 2022 por hogar por trimestre |
| Decimales | 0 |
| Ámbito | Ambos |
| Fuente | ICMM2022 |
| Variable en la fuente | `icpth (est = 4)` |
| Derivación | Directo. |
| Universo | Hogares del municipio |
| Valores vacíos | C: solo si el municipio no tiene fila en el ICMM |
| Dimensión sugerida | Confiabilidad |
| Sentido sugerido | n/a |
| Script | 13b_income.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 64,345 |
| Rango | 16,285 – 182,771 |
| Notas | Equivale a ING_MUN_HOG_TRIM + 1.645 × error estándar. |

<a id="ing_mun_cv"></a>
#### 126. `ING_MUN_CV`

Coeficiente de variación de ING_MUN_HOG_TRIM.

| Campo | Valor |
|---|---|
| Bloque | Ingreso (municipal) |
| Tipo | decimal |
| Unidad | % |
| Decimales | 2 |
| Ámbito | Ambos |
| Fuente | ICMM2022 |
| Variable en la fuente | `icpth (est = 5)` |
| Derivación | Directo (100 × error estándar / estimación). |
| Universo | Hogares del municipio |
| Valores vacíos | C: solo si el municipio no tiene fila en el ICMM |
| Dimensión sugerida | Confiabilidad |
| Sentido sugerido | n/a |
| Script | 13b_income.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 7.53 |
| Rango | 0.01 – 12.36 |
| Notas | El INEGI califica la precisión como alta con CV < 15, moderada con 15–30 y baja con 30 o más. En la edición 2022 todos los municipios quedan por debajo de 12.4 (alta); los más altos son municipios pequeños de Oaxaca. |

<a id="pob_0a2"></a>
#### 127. `POB_0A2`

Población de 0 a 2 años.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | personas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `P_0A2` |
| Derivación | Directo (urbana) o suma (rural, grupo PERS). |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 49 |
| Rango | 0 – 3,484 |
| Notas | Los conteos se publican para reagregar a otras geografías: suma numeradores y denominadores, nunca porcentajes. |

<a id="pob_3a5"></a>
#### 128. `POB_3A5`

Población de 3 a 5 años.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | personas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `P_3A5` |
| Derivación | Igual que POB_0A2. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 56 |
| Rango | 0 – 3,516 |

<a id="pob_65ymas"></a>
#### 129. `POB_65YMAS`

Población de 65 años y más.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | personas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `POB65_MAS` |
| Derivación | Igual que POB_0A2. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 78 |
| Rango | 0 – 2,798 |

<a id="pob_disc"></a>
#### 130. `POB_DISC`

Población con discapacidad.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | personas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `PCON_DISC` |
| Derivación | Igual que POB_0A2. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 52 |
| Rango | 0 – 2,027 |

<a id="pob_3ymas"></a>
#### 131. `POB_3YMAS`

Población de 3 años y más.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | personas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `P_3YMAS` |
| Derivación | Igual que POB_0A2. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 1,100 |
| Rango | 0 – 40,670 |

<a id="pob_hli"></a>
#### 132. `POB_HLI`

Población de 3 años y más que habla alguna lengua indígena.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | personas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `P3YM_HLI` |
| Derivación | Igual que POB_0A2. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 5 |
| Rango | 0 – 40,047 |

<a id="pob_hli_nhe"></a>
#### 133. `POB_HLI_NHE`

Población de 3 años y más que habla lengua indígena y no habla español.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | personas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `P3HLINHE` |
| Derivación | Igual que POB_0A2. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 0 |
| Rango | 0 – 19,724 |

<a id="pob_sin_salud"></a>
#### 134. `POB_SIN_SALUD`

Población sin afiliación a servicios de salud.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | personas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `PSINDER` |
| Derivación | Igual que POB_0A2. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 246 |
| Rango | 0 – 12,520 |

<a id="pob_15ymas"></a>
#### 135. `POB_15YMAS`

Población de 15 años y más.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | personas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `P_15YMAS` |
| Derivación | Igual que POB_0A2. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 850 |
| Rango | 0 – 26,914 |

<a id="pob_15ymas_analf"></a>
#### 136. `POB_15YMAS_ANALF`

Población de 15 años y más analfabeta.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | personas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `P15YM_AN` |
| Derivación | Igual que POB_0A2. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 21 |
| Rango | 0 – 8,748 |

<a id="pob_15ymas_sin_esc"></a>
#### 137. `POB_15YMAS_SIN_ESC`

Población de 15 años y más sin escolaridad (o solo preescolar).

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | personas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `P15YM_SE` |
| Derivación | Igual que POB_0A2. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 26 |
| Rango | 0 – 8,377 |

<a id="pob_15ymas_prim_inc"></a>
#### 138. `POB_15YMAS_PRIM_INC`

Población de 15 años y más con primaria incompleta.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | personas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `P15PRI_IN` |
| Derivación | Igual que POB_0A2. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 55 |
| Rango | 0 – 4,023 |

<a id="pob_15ymas_prim_com"></a>
#### 139. `POB_15YMAS_PRIM_COM`

Población de 15 años y más con primaria completa (como máxima escolaridad).

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | personas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `P15PRI_CO` |
| Derivación | Igual que POB_0A2. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 97 |
| Rango | 0 – 12,855 |

<a id="pob_15ymas_sec_inc"></a>
#### 140. `POB_15YMAS_SEC_INC`

Población de 15 años y más con secundaria incompleta.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | personas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `P15SEC_IN` |
| Derivación | Igual que POB_0A2. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 23 |
| Rango | 0 – 1,477 |

<a id="pob_6a11"></a>
#### 141. `POB_6A11`

Población de 6 a 11 años.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | personas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `P_6A11` |
| Derivación | Igual que POB_0A2. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 114 |
| Rango | 0 – 7,164 |

<a id="pob_12a14"></a>
#### 142. `POB_12A14`

Población de 12 a 14 años.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | personas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `P_12A14` |
| Derivación | Igual que POB_0A2. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 57 |
| Rango | 0 – 3,241 |

<a id="pob_6a11_noasis"></a>
#### 143. `POB_6A11_NOASIS`

Población de 6 a 11 años que no asiste a la escuela.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | personas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `P6A11_NOA` |
| Derivación | Igual que POB_0A2. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 4 |
| Rango | 0 – 591 |

<a id="pob_12a14_noasis"></a>
#### 144. `POB_12A14_NOASIS`

Población de 12 a 14 años que no asiste a la escuela.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | personas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `P12A14NOA` |
| Derivación | Igual que POB_0A2. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 4 |
| Rango | 0 – 1,578 |

<a id="pob_15a17"></a>
#### 145. `POB_15A17`

Población de 15 a 17 años.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | personas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `P_15A17` |
| Derivación | Igual que POB_0A2. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 57 |
| Rango | 0 – 3,030 |

<a id="pob_18a24"></a>
#### 146. `POB_18A24`

Población de 18 a 24 años.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | personas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `P_18A24` |
| Derivación | Igual que POB_0A2. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 126 |
| Rango | 0 – 5,695 |

<a id="pob_15a17_asis"></a>
#### 147. `POB_15A17_ASIS`

Población de 15 a 17 años que asiste a la escuela.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | personas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `P15A17A` |
| Derivación | Igual que POB_0A2. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 41 |
| Rango | 0 – 1,865 |

<a id="pob_18a24_asis"></a>
#### 148. `POB_18A24_ASIS`

Población de 18 a 24 años que asiste a la escuela.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | personas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `P18A24A` |
| Derivación | Igual que POB_0A2. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 34 |
| Rango | 0 – 1,924 |

<a id="pob_pea"></a>
#### 149. `POB_PEA`

Población económicamente activa de 12 años y más.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | personas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `PEA` |
| Derivación | Igual que POB_0A2. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 547 |
| Rango | 0 – 17,516 |

<a id="pob_pea_f"></a>
#### 150. `POB_PEA_F`

Mujeres de 12 años y más económicamente activas.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | personas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `PEA_F` |
| Derivación | Igual que POB_0A2. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 210 |
| Rango | 0 – 7,228 |

<a id="pob_inac"></a>
#### 151. `POB_INAC`

Población de 12 años y más no económicamente activa.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | personas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `PE_INAC` |
| Derivación | Igual que POB_0A2. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 349 |
| Rango | 0 – 16,310 |

<a id="pob_inac_f"></a>
#### 152. `POB_INAC_F`

Mujeres de 12 años y más no económicamente activas.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | personas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `PE_INAC_F` |
| Derivación | Igual que POB_0A2. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 244 |
| Rango | 0 – 12,961 |

<a id="pob_desocup"></a>
#### 153. `POB_DESOCUP`

Población de 12 años y más desocupada.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | personas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `PDESOCUP` |
| Derivación | Igual que POB_0A2. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 7 |
| Rango | 0 – 697 |

<a id="hogares"></a>
#### 154. `HOGARES`

Total de hogares censales.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | hogares |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `TOTHOG` |
| Derivación | Directo (urbana) o suma (rural, grupo VIV). |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 330 |
| Rango | 0 – 10,199 |
| Notas | El censo considera un hogar por vivienda particular. |

<a id="hogares_jefa"></a>
#### 155. `HOGARES_JEFA`

Hogares censales con persona de referencia mujer.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | hogares |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `HOGJEF_F` |
| Derivación | Igual que HOGARES. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 98 |
| Rango | 0 – 3,134 |

<a id="viv_ocupantes"></a>
#### 156. `VIV_OCUPANTES`

Ocupantes en viviendas particulares habitadas.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | personas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `OCUPVIVPAR` |
| Derivación | Igual que HOGARES. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 1,154 |
| Rango | 0 – 44,154 |

<a id="viv_sin_drenaje"></a>
#### 157. `VIV_SIN_DRENAJE`

Viviendas que no disponen de drenaje.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | viviendas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `VPH_NODREN` |
| Derivación | Igual que HOGARES. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 1.5 |
| Rango | 0 – 4,684 |
| Notas | Denominador para reagregar los porcentajes de vivienda: VIV_CARACT. |

<a id="viv_sin_electricidad"></a>
#### 158. `VIV_SIN_ELECTRICIDAD`

Viviendas que no disponen de energía eléctrica.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | viviendas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `VPH_S_ELEC` |
| Derivación | Igual que HOGARES. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 1 |
| Rango | 0 – 1,877 |

<a id="viv_sin_agua"></a>
#### 159. `VIV_SIN_AGUA`

Viviendas sin agua entubada en el ámbito de la vivienda.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | viviendas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `VPH_AGUAFV` |
| Derivación | Igual que HOGARES. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 1.5 |
| Rango | 0 – 3,068 |

<a id="viv_piso_tierra"></a>
#### 160. `VIV_PISO_TIERRA`

Viviendas con piso de tierra.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | viviendas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `VPH_PISOTI` |
| Derivación | Igual que HOGARES. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 4 |
| Rango | 0 – 5,095 |

<a id="viv_1cuarto"></a>
#### 161. `VIV_1CUARTO`

Viviendas con un solo cuarto.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | viviendas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `VPH_1CUART` |
| Derivación | Igual que HOGARES. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 9 |
| Rango | 0 – 2,454 |

<a id="viv_excusado"></a>
#### 162. `VIV_EXCUSADO`

Viviendas que disponen de excusado o sanitario.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | viviendas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `VPH_EXCSA` |
| Derivación | Igual que HOGARES. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 301 |
| Rango | 0 – 9,079 |

<a id="viv_letrina"></a>
#### 163. `VIV_LETRINA`

Viviendas que disponen de letrina (pozo u hoyo).

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | viviendas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `VPH_LETR` |
| Derivación | Igual que HOGARES. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 1 |
| Rango | 0 – 6,397 |

<a id="viv_tinaco"></a>
#### 164. `VIV_TINACO`

Viviendas que disponen de tinaco.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | viviendas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `VPH_TINACO` |
| Derivación | Igual que HOGARES. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 147 |
| Rango | 0 – 6,969 |

<a id="viv_cisterna"></a>
#### 165. `VIV_CISTERNA`

Viviendas que disponen de cisterna o aljibe.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | viviendas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `VPH_CISTER` |
| Derivación | Igual que HOGARES. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 24 |
| Rango | 0 – 7,317 |

<a id="viv_refri"></a>
#### 166. `VIV_REFRI`

Viviendas que disponen de refrigerador.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | viviendas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `VPH_REFRI` |
| Derivación | Igual que HOGARES. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 277 |
| Rango | 0 – 8,813 |

<a id="viv_lavadora"></a>
#### 167. `VIV_LAVADORA`

Viviendas que disponen de lavadora.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | viviendas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `VPH_LAVAD` |
| Derivación | Igual que HOGARES. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 220 |
| Rango | 0 – 8,242 |

<a id="viv_auto"></a>
#### 168. `VIV_AUTO`

Viviendas que disponen de automóvil o camioneta.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | viviendas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `VPH_AUTOM` |
| Derivación | Igual que HOGARES. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 131 |
| Rango | 0 – 6,072 |

<a id="viv_radio"></a>
#### 169. `VIV_RADIO`

Viviendas que disponen de radio.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | viviendas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `VPH_RADIO` |
| Derivación | Igual que HOGARES. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 201 |
| Rango | 0 – 6,684 |

<a id="viv_telefono"></a>
#### 170. `VIV_TELEFONO`

Viviendas que disponen de línea telefónica fija.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | viviendas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `VPH_TELEF` |
| Derivación | Igual que HOGARES. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 61 |
| Rango | 0 – 6,196 |

<a id="viv_celular"></a>
#### 171. `VIV_CELULAR`

Viviendas que disponen de teléfono celular.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | viviendas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `VPH_CEL` |
| Derivación | Igual que HOGARES. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 278 |
| Rango | 0 – 8,715 |

<a id="viv_internet"></a>
#### 172. `VIV_INTERNET`

Viviendas que disponen de internet.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | viviendas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `VPH_INTER` |
| Derivación | Igual que HOGARES. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 112 |
| Rango | 0 – 7,512 |

<a id="viv_compu"></a>
#### 173. `VIV_COMPU`

Viviendas que disponen de computadora, laptop o tablet.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | viviendas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `VPH_PC` |
| Derivación | Igual que HOGARES. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 73 |
| Rango | 0 – 6,919 |

<a id="viv_sin_radio_tv"></a>
#### 174. `VIV_SIN_RADIO_TV`

Viviendas sin radio ni televisor.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | viviendas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `VPH_SINRTV` |
| Derivación | Igual que HOGARES. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 10 |
| Rango | 0 – 5,191 |

<a id="viv_sin_tel_cel"></a>
#### 175. `VIV_SIN_TEL_CEL`

Viviendas sin línea telefónica fija ni teléfono celular.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | viviendas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `VPH_SINLTC` |
| Derivación | Igual que HOGARES. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 16 |
| Rango | 0 – 6,762 |

<a id="viv_sin_tic"></a>
#### 176. `VIV_SIN_TIC`

Viviendas sin tecnologías de la información y la comunicación.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | viviendas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `VPH_SINTIC` |
| Derivación | Igual que HOGARES. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 3 |
| Rango | 0 – 4,695 |

<a id="viv_sin_bienes"></a>
#### 177. `VIV_SIN_BIENES`

Viviendas sin ningún bien.

| Campo | Valor |
|---|---|
| Bloque | Conteos censales |
| Tipo | decimal (conteo) |
| Unidad | viviendas |
| Ámbito | Ambos |
| Fuente | CPV2020_AGEB / CPV2020_ITER |
| Variable en la fuente | `VPH_SNBIEN` |
| Derivación | Igual que HOGARES. |
| Valores vacíos | S |
| Dimensión sugerida | Conteo para reagregar |
| Sentido sugerido | n/a |
| Script | 04_census_urban.R; 05_census_rural.R |
| AGEB habitadas con dato (urbana / rural) | 95.6 % / 86.6 % |
| Población con dato (urbana / rural) | 100.0 % / 99.9 % |
| Mediana (AGEB habitadas) | 1.5 |
| Rango | 0 – 4,215 |

<a id="year_geometry"></a>
#### 178. `YEAR_GEOMETRY`

Año de referencia de la geometría.

| Campo | Valor |
|---|---|
| Bloque | Metadatos |
| Tipo | entero |
| Unidad | año |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `YEARS$geometry` |
| Derivación | Constante (2020). |
| Valores vacíos | Nunca |
| Dimensión sugerida | Metadato |
| Sentido sugerido | n/a |
| Script | 00_config.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 2,020 |
| Rango | 2,020 – 2,020 |

<a id="year_census"></a>
#### 179. `YEAR_CENSUS`

Año de referencia del censo.

| Campo | Valor |
|---|---|
| Bloque | Metadatos |
| Tipo | entero |
| Unidad | año |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `YEARS$census` |
| Derivación | Constante (2020). |
| Valores vacíos | Nunca |
| Dimensión sugerida | Metadato |
| Sentido sugerido | n/a |
| Script | 00_config.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 2,020 |
| Rango | 2,020 – 2,020 |

<a id="year_coneval"></a>
#### 180. `YEAR_CONEVAL`

Año de referencia del GRS de CONEVAL.

| Campo | Valor |
|---|---|
| Bloque | Metadatos |
| Tipo | entero |
| Unidad | año |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `YEARS$coneval` |
| Derivación | Constante (2020). |
| Valores vacíos | Nunca |
| Dimensión sugerida | Metadato |
| Sentido sugerido | n/a |
| Script | 00_config.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 2,020 |
| Rango | 2,020 – 2,020 |

<a id="year_denue"></a>
#### 181. `YEAR_DENUE`

Versión del DENUE.

| Campo | Valor |
|---|---|
| Bloque | Metadatos |
| Tipo | texto |
| Unidad | año-mes |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `YEARS$denue` |
| Derivación | Constante ('2026-05'). |
| Valores vacíos | Nunca |
| Dimensión sugerida | Metadato |
| Sentido sugerido | n/a |
| Script | 00_config.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Notas | Se escribe a mano en 00_config.R: actualizarlo si se vuelve a descargar el DENUE. |

<a id="year_hidro"></a>
#### 182. `YEAR_HIDRO`

Año de referencia de la capa de cuerpos de agua.

| Campo | Valor |
|---|---|
| Bloque | Metadatos |
| Tipo | entero |
| Unidad | año |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `YEARS$hidro` |
| Derivación | Constante (2018). |
| Valores vacíos | Nunca |
| Dimensión sugerida | Metadato |
| Sentido sugerido | n/a |
| Script | 00_config.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 2,018 |
| Rango | 2,018 – 2,018 |
| Notas | Continuo topográfico 1:50,000 serie III, levantamiento 2013–2018. |

<a id="year_usv"></a>
#### 183. `YEAR_USV`

Año de referencia de la capa de uso de suelo y vegetación.

| Campo | Valor |
|---|---|
| Bloque | Metadatos |
| Tipo | entero |
| Unidad | año |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `YEARS$usv` |
| Derivación | Constante (2021). |
| Valores vacíos | Nunca |
| Dimensión sugerida | Metadato |
| Sentido sugerido | n/a |
| Script | 00_config.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 2,021 |
| Rango | 2,021 – 2,021 |
| Notas | Serie VII, publicada en 2021 con imágenes de año base 2018. |

<a id="year_clues"></a>
#### 184. `YEAR_CLUES`

Corte del catálogo CLUES de establecimientos de salud.

| Campo | Valor |
|---|---|
| Bloque | Metadatos |
| Tipo | texto |
| Unidad | año-mes |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `YEARS$clues` |
| Derivación | Constante ('2026-07'). |
| Valores vacíos | Nunca |
| Dimensión sugerida | Metadato |
| Sentido sugerido | n/a |
| Script | 00_config.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Notas | Se escribe a mano en 00_config.R junto con URL_CLUES y CLUES_FILE: actualizar los tres si se descarga otro corte. |

<a id="year_cem"></a>
#### 185. `YEAR_CEM`

Año de publicación del Continuo de Elevaciones Mexicano 4.0.

| Campo | Valor |
|---|---|
| Bloque | Metadatos |
| Tipo | entero |
| Unidad | año |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `YEARS$cem` |
| Derivación | Constante (2024). |
| Valores vacíos | Nunca |
| Dimensión sugerida | Metadato |
| Sentido sugerido | n/a |
| Script | 00_config.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 2,024 |
| Rango | 2,024 – 2,024 |
| Notas | Imágenes de radar ALOS PALSAR de 2006–2011. |

<a id="year_red_hidro"></a>
#### 186. `YEAR_RED_HIDRO`

Año de la edición 2.0 de la Red Hidrográfica 1:50 000.

| Campo | Valor |
|---|---|
| Bloque | Metadatos |
| Tipo | entero |
| Unidad | año |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `YEARS$red_hidro` |
| Derivación | Constante (2010). |
| Valores vacíos | Nunca |
| Dimensión sugerida | Metadato |
| Sentido sugerido | n/a |
| Script | 00_config.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 2,010 |
| Rango | 2,010 – 2,010 |
| Notas | Construida sobre cartas topográficas 1:50 000 de 1995–2002 según la subcuenca. |

<a id="year_costa"></a>
#### 187. `YEAR_COSTA`

Año de la capa de línea de costa de CONABIO.

| Campo | Valor |
|---|---|
| Bloque | Metadatos |
| Tipo | entero |
| Unidad | año |
| Ámbito | Ambos |
| Fuente | PIPELINE |
| Variable en la fuente | `YEARS$costa` |
| Derivación | Constante (2018). |
| Valores vacíos | Nunca |
| Dimensión sugerida | Metadato |
| Sentido sugerido | n/a |
| Script | 00_config.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 2,018 |
| Rango | 2,018 – 2,018 |
| Notas | Imágenes RapidEye de 2011–2014. |

<a id="year_cenapred"></a>
#### 188. `YEAR_CENAPRED`

Actualización del Sistema de Indicadores Municipales del Atlas Nacional de Riesgos.

| Campo | Valor |
|---|---|
| Bloque | Metadatos |
| Tipo | entero |
| Unidad | año |
| Ámbito | Ambos |
| Fuente | CENAPRED_SITU2023 |
| Variable en la fuente | `YEARS$cenapred` |
| Derivación | Constante (2023). |
| Valores vacíos | Nunca |
| Dimensión sugerida | Metadato |
| Sentido sugerido | n/a |
| Script | 13_hazard.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 2,023 |
| Rango | 2,023 – 2,023 |
| Notas | Los indicadores sociodemográficos con los que CENAPRED construyó estos grados vienen del censo 2020; 2023 es el corte de publicación. |

<a id="year_icmm"></a>
#### 189. `YEAR_ICMM`

Edición del Ingreso Corriente para los Municipios de México.

| Campo | Valor |
|---|---|
| Bloque | Metadatos |
| Tipo | entero |
| Unidad | año |
| Ámbito | Ambos |
| Fuente | ICMM2022 |
| Variable en la fuente | `YEARS$icmm` |
| Derivación | Constante (2022). |
| Valores vacíos | Nunca |
| Dimensión sugerida | Metadato |
| Sentido sugerido | n/a |
| Script | 13b_income.R |
| AGEB habitadas con dato (urbana / rural) | 100.0 % / 100.0 % |
| Población con dato (urbana / rural) | 100.0 % / 100.0 % |
| Mediana (AGEB habitadas) | 2,022 |
| Rango | 2,022 – 2,022 |
| Notas | Levantamiento de la ENIGH 2022: 21 de agosto a 28 de noviembre de 2022. Publicado por el INEGI el 2024-11-14. |

<a id="tabla-ageb-integrada"></a>
## Tabla ageb_integrada

`data/processed/base_ageb_MX.gpkg`, capa `ageb_integrada` (EPSG:4326), y `ageb_integrada_MX.csv`. Una fila por AGEB con todas las columnas de ageb_indicadores más las que se listan aquí; `ORDEN` es su posición en esa tabla. El GeoPackage también trae, como capas, las demás tablas de este diccionario en versión nacional.

| # | Variable | Descripción | Tipo | Unidad | Fuente | Derivación | Notas |
|---|---|---|---|---|---|---|---|
| 91 | `DEN_SCIAN_11` | Unidades económicas del sector SCIAN 11: Agricultura, cría y explotación de animales, aprovechamiento forestal, pesca y caza. | entero | establecimientos | DENUE | Conteo de establecimientos de la AGEB cuyo código SCIAN empieza con 11. | Los 20 DEN_SCIAN_* suman exactamente DENUE_TOT. Formato ancho de denue_ageb_sector. |
| 92 | `DEN_SCIAN_21` | Unidades económicas del sector SCIAN 21: Minería. | entero | establecimientos | DENUE | Conteo de establecimientos de la AGEB cuyo código SCIAN empieza con 21. | Los 20 DEN_SCIAN_* suman exactamente DENUE_TOT. Formato ancho de denue_ageb_sector. |
| 93 | `DEN_SCIAN_22` | Unidades económicas del sector SCIAN 22: Generación y distribución de energía eléctrica, suministro de agua y de gas por ductos. | entero | establecimientos | DENUE | Conteo de establecimientos de la AGEB cuyo código SCIAN empieza con 22. | Los 20 DEN_SCIAN_* suman exactamente DENUE_TOT. Formato ancho de denue_ageb_sector. |
| 94 | `DEN_SCIAN_23` | Unidades económicas del sector SCIAN 23: Construcción. | entero | establecimientos | DENUE | Conteo de establecimientos de la AGEB cuyo código SCIAN empieza con 23. | Los 20 DEN_SCIAN_* suman exactamente DENUE_TOT. Formato ancho de denue_ageb_sector. |
| 95 | `DEN_SCIAN_31_33` | Unidades económicas del sector SCIAN 31-33: Industrias manufactureras. | entero | establecimientos | DENUE | Conteo de establecimientos de la AGEB cuyo código SCIAN empieza con 31 o 33. | Los 20 DEN_SCIAN_* suman exactamente DENUE_TOT. Formato ancho de denue_ageb_sector. |
| 96 | `DEN_SCIAN_43` | Unidades económicas del sector SCIAN 43: Comercio al por mayor. | entero | establecimientos | DENUE | Conteo de establecimientos de la AGEB cuyo código SCIAN empieza con 43. | Los 20 DEN_SCIAN_* suman exactamente DENUE_TOT. Formato ancho de denue_ageb_sector. |
| 97 | `DEN_SCIAN_46` | Unidades económicas del sector SCIAN 46: Comercio al por menor. | entero | establecimientos | DENUE | Conteo de establecimientos de la AGEB cuyo código SCIAN empieza con 46. | Los 20 DEN_SCIAN_* suman exactamente DENUE_TOT. Formato ancho de denue_ageb_sector. |
| 98 | `DEN_SCIAN_48_49` | Unidades económicas del sector SCIAN 48-49: Transportes, correos y almacenamiento. | entero | establecimientos | DENUE | Conteo de establecimientos de la AGEB cuyo código SCIAN empieza con 48 o 49. | Los 20 DEN_SCIAN_* suman exactamente DENUE_TOT. Formato ancho de denue_ageb_sector. |
| 99 | `DEN_SCIAN_51` | Unidades económicas del sector SCIAN 51: Información en medios masivos. | entero | establecimientos | DENUE | Conteo de establecimientos de la AGEB cuyo código SCIAN empieza con 51. | Los 20 DEN_SCIAN_* suman exactamente DENUE_TOT. Formato ancho de denue_ageb_sector. |
| 100 | `DEN_SCIAN_52` | Unidades económicas del sector SCIAN 52: Servicios financieros y de seguros. | entero | establecimientos | DENUE | Conteo de establecimientos de la AGEB cuyo código SCIAN empieza con 52. | Los 20 DEN_SCIAN_* suman exactamente DENUE_TOT. Formato ancho de denue_ageb_sector. |
| 101 | `DEN_SCIAN_53` | Unidades económicas del sector SCIAN 53: Servicios inmobiliarios y de alquiler de bienes muebles e intangibles. | entero | establecimientos | DENUE | Conteo de establecimientos de la AGEB cuyo código SCIAN empieza con 53. | Los 20 DEN_SCIAN_* suman exactamente DENUE_TOT. Formato ancho de denue_ageb_sector. |
| 102 | `DEN_SCIAN_54` | Unidades económicas del sector SCIAN 54: Servicios profesionales, científicos y técnicos. | entero | establecimientos | DENUE | Conteo de establecimientos de la AGEB cuyo código SCIAN empieza con 54. | Los 20 DEN_SCIAN_* suman exactamente DENUE_TOT. Formato ancho de denue_ageb_sector. |
| 103 | `DEN_SCIAN_55` | Unidades económicas del sector SCIAN 55: Corporativos. | entero | establecimientos | DENUE | Conteo de establecimientos de la AGEB cuyo código SCIAN empieza con 55. | Los 20 DEN_SCIAN_* suman exactamente DENUE_TOT. Formato ancho de denue_ageb_sector. |
| 104 | `DEN_SCIAN_56` | Unidades económicas del sector SCIAN 56: Servicios de apoyo a los negocios, manejo de residuos y remediación. | entero | establecimientos | DENUE | Conteo de establecimientos de la AGEB cuyo código SCIAN empieza con 56. | Los 20 DEN_SCIAN_* suman exactamente DENUE_TOT. Formato ancho de denue_ageb_sector. |
| 105 | `DEN_SCIAN_61` | Unidades económicas del sector SCIAN 61: Servicios educativos. | entero | establecimientos | DENUE | Conteo de establecimientos de la AGEB cuyo código SCIAN empieza con 61. | Los 20 DEN_SCIAN_* suman exactamente DENUE_TOT. Formato ancho de denue_ageb_sector. |
| 106 | `DEN_SCIAN_62` | Unidades económicas del sector SCIAN 62: Servicios de salud y de asistencia social. | entero | establecimientos | DENUE | Conteo de establecimientos de la AGEB cuyo código SCIAN empieza con 62. | Los 20 DEN_SCIAN_* suman exactamente DENUE_TOT. Formato ancho de denue_ageb_sector. |
| 107 | `DEN_SCIAN_71` | Unidades económicas del sector SCIAN 71: Servicios de esparcimiento culturales y deportivos, y otros servicios recreativos. | entero | establecimientos | DENUE | Conteo de establecimientos de la AGEB cuyo código SCIAN empieza con 71. | Los 20 DEN_SCIAN_* suman exactamente DENUE_TOT. Formato ancho de denue_ageb_sector. |
| 108 | `DEN_SCIAN_72` | Unidades económicas del sector SCIAN 72: Servicios de alojamiento temporal y de preparación de alimentos y bebidas. | entero | establecimientos | DENUE | Conteo de establecimientos de la AGEB cuyo código SCIAN empieza con 72. | Los 20 DEN_SCIAN_* suman exactamente DENUE_TOT. Formato ancho de denue_ageb_sector. |
| 109 | `DEN_SCIAN_81` | Unidades económicas del sector SCIAN 81: Otros servicios excepto actividades gubernamentales. | entero | establecimientos | DENUE | Conteo de establecimientos de la AGEB cuyo código SCIAN empieza con 81. | Los 20 DEN_SCIAN_* suman exactamente DENUE_TOT. Formato ancho de denue_ageb_sector. |
| 110 | `DEN_SCIAN_93` | Unidades económicas del sector SCIAN 93: Actividades legislativas, gubernamentales y de impartición de justicia. | entero | establecimientos | DENUE | Conteo de establecimientos de la AGEB cuyo código SCIAN empieza con 93. | Los 20 DEN_SCIAN_* suman exactamente DENUE_TOT. Formato ancho de denue_ageb_sector. |
| 117 | `USV_PCT_URBANO` | Porcentaje de la AGEB cubierto por asentamientos humanos y zona urbana. | decimal | % | INEGI_USV7 | min(100, Σ CLASS_PCT de las clases USYV del grupo), según la tabla USV_GROUPS de 14_integrate.R. | ASENTAMIENTOS HUMANOS, ZONA URBANA. Igual a PCT_URB salvo redondeo. Los 12 USV_PCT_* suman ≤ 100 (menos si la capa no cubre toda la AGEB). |
| 118 | `USV_PCT_AGUA` | Porcentaje de la AGEB cubierto por cuerpos de agua y acuicultura. | decimal | % | INEGI_USV7 | min(100, Σ CLASS_PCT de las clases USYV del grupo), según la tabla USV_GROUPS de 14_integrate.R. | CUERPO DE AGUA, ACUÍCOLA. Complementa WATER_PCT (INEGI hidrología 1:50,000), que es más fino. Los 12 USV_PCT_* suman ≤ 100 (menos si la capa no cubre toda la AGEB). |
| 119 | `USV_PCT_SECUNDARIA` | Porcentaje de la AGEB cubierto por vegetación secundaria (arbórea, arbustiva o herbácea) de cualquier formación. | decimal | % | INEGI_USV7 | min(100, Σ CLASS_PCT de las clases USYV del grupo), según la tabla USV_GROUPS de 14_integrate.R. | Todas las clases 'VEGETACIÓN SECUNDARIA ...'. Se separa de su formación original porque indica degradación. Los 12 USV_PCT_* suman ≤ 100 (menos si la capa no cubre toda la AGEB). |
| 120 | `USV_PCT_AGRICOLA` | Porcentaje de la AGEB cubierto por agricultura de riego, temporal o humedad. | decimal | % | INEGI_USV7 | min(100, Σ CLASS_PCT de las clases USYV del grupo), según la tabla USV_GROUPS de 14_integrate.R. | Todas las clases 'AGRICULTURA ...'. Los 12 USV_PCT_* suman ≤ 100 (menos si la capa no cubre toda la AGEB). |
| 121 | `USV_PCT_PASTIZAL_INDUCIDO` | Porcentaje de la AGEB cubierto por pastizal cultivado o inducido (uso pecuario). | decimal | % | INEGI_USV7 | min(100, Σ CLASS_PCT de las clases USYV del grupo), según la tabla USV_GROUPS de 14_integrate.R. | PASTIZAL CULTIVADO, PASTIZAL INDUCIDO. Los 12 USV_PCT_* suman ≤ 100 (menos si la capa no cubre toda la AGEB). |
| 122 | `USV_PCT_BOSQUE` | Porcentaje de la AGEB cubierto por bosque primario (coníferas, encino, mesófilo, galería, cultivado). | decimal | % | INEGI_USV7 | min(100, Σ CLASS_PCT de las clases USYV del grupo), según la tabla USV_GROUPS de 14_integrate.R. | Clases 'BOSQUE ...', incluidos bosque cultivado e inducido. Los 12 USV_PCT_* suman ≤ 100 (menos si la capa no cubre toda la AGEB). |
| 123 | `USV_PCT_SELVA` | Porcentaje de la AGEB cubierto por selva primaria. | decimal | % | INEGI_USV7 | min(100, Σ CLASS_PCT de las clases USYV del grupo), según la tabla USV_GROUPS de 14_integrate.R. | Clases 'SELVA ...'. Los 12 USV_PCT_* suman ≤ 100 (menos si la capa no cubre toda la AGEB). |
| 124 | `USV_PCT_MATORRAL` | Porcentaje de la AGEB cubierto por matorral y vegetación xerófila. | decimal | % | INEGI_USV7 | min(100, Σ CLASS_PCT de las clases USYV del grupo), según la tabla USV_GROUPS de 14_integrate.R. | MATORRAL ..., MEZQUITAL ..., CHAPARRAL, desiertos arenosos, vegetación gipsófila y halófila xerófila. Los 12 USV_PCT_* suman ≤ 100 (menos si la capa no cubre toda la AGEB). |
| 125 | `USV_PCT_PASTIZAL` | Porcentaje de la AGEB cubierto por pastizal natural, pradera y sabana. | decimal | % | INEGI_USV7 | min(100, Σ CLASS_PCT de las clases USYV del grupo), según la tabla USV_GROUPS de 14_integrate.R. | PASTIZAL NATURAL, HALÓFILO, GIPSÓFILO; PRADERA DE ALTA MONTAÑA; SABANA, SABANOIDE. Los 12 USV_PCT_* suman ≤ 100 (menos si la capa no cubre toda la AGEB). |
| 126 | `USV_PCT_HIDROFILA` | Porcentaje de la AGEB cubierto por vegetación hidrófila (manglar, tular, popal, galería, petén). | decimal | % | INEGI_USV7 | min(100, Σ CLASS_PCT de las clases USYV del grupo), según la tabla USV_GROUPS de 14_integrate.R. | MANGLAR, TULAR, POPAL, halófila hidrófila, vegetación de galería y de petén. Bosque y selva de galería quedan en BOSQUE y SELVA. Los 12 USV_PCT_* suman ≤ 100 (menos si la capa no cubre toda la AGEB). |
| 127 | `USV_PCT_SIN_VEG` | Porcentaje de la AGEB cubierto por áreas sin vegetación aparente o desprovistas de vegetación. | decimal | % | INEGI_USV7 | min(100, Σ CLASS_PCT de las clases USYV del grupo), según la tabla USV_GROUPS de 14_integrate.R. | SIN VEGETACIÓN APARENTE, DESPROVISTO DE VEGETACIÓN. Los 12 USV_PCT_* suman ≤ 100 (menos si la capa no cubre toda la AGEB). |
| 128 | `USV_PCT_OTRA` | Porcentaje de la AGEB cubierto por otras formaciones (dunas costeras, palmar). | decimal | % | INEGI_USV7 | min(100, Σ CLASS_PCT de las clases USYV del grupo), según la tabla USV_GROUPS de 14_integrate.R. | VEGETACIÓN DE DUNAS COSTERAS, PALMAR NATURAL, PALMAR INDUCIDO. Los 12 USV_PCT_* suman ≤ 100 (menos si la capa no cubre toda la AGEB). |

<a id="tabla-ageb-geom"></a>
## Tabla ageb_geom

`data/processed/ageb_geom_{ENT}.gpkg`, capa `ageb`, EPSG:4326. Una fila por AGEB.

| # | Variable | Descripción | Tipo | Unidad | Fuente | Derivación | Notas |
|---|---|---|---|---|---|---|---|
| 1 | `ID_AGEB` | Clave única de la AGEB (llave hacia ageb_indicadores). | texto | clave | MG2020 | Igual que en ageb_indicadores. | GeoPackage, capa 'ageb', EPSG:4326. |
| 2 | `AMBITO` | Ámbito de la AGEB. | categórica |  | MG2020 | Copia de ageb_indicadores. |  |
| 3 | `CVE_ENT` | Clave de entidad. | texto | clave | MG2020 | Copia de ageb_indicadores. |  |
| 4 | `CVE_MUN` | Clave de municipio. | texto | clave | MG2020 | Copia de ageb_indicadores. |  |
| 5 | `NOM_MUN` | Nombre del municipio. | texto |  | MG2020 | Copia de ageb_indicadores. |  |
| 6 | `NOM_LOC` | Nombre de la localidad. | texto |  | MG2020 / CPV2020_ITER | Copia de ageb_indicadores. |  |
| 7 | `AREA_KM2` | Superficie de la AGEB. | decimal | km² | MG2020 | Copia de ageb_indicadores. |  |
| 8 | `POB_TOTAL` | Población total. | decimal (conteo) | personas | CPV2020_AGEB / CPV2020_ITER | Copia de ageb_indicadores. |  |
| 9 | `GRS_GRADO` | Grado de Rezago Social. | categórica ordinal |  | CONEVAL_GRS2020 | Copia de ageb_indicadores. |  |
| 10 | `geom` | Polígono o multipolígono de la AGEB. | geometría | EPSG:4326 | MG2020 | Geometría del MG tras st_make_valid(), reproyectada a EPSG:4326. | Para calcular áreas o distancias reproyecta a EPSG:6372. |

<a id="tabla-denue-establishments"></a>
## Tabla denue_establishments

`data/processed/denue_establishments_{ENT}.csv`. Una fila por establecimiento del DENUE.

| # | Variable | Descripción | Tipo | Unidad | Fuente | Derivación | Notas |
|---|---|---|---|---|---|---|---|
| 1 | `ID_AGEB` | AGEB a la que se asignó el establecimiento. | texto | clave | DENUE | Primero se prueba la clave urbana; si no existe en el MG, la rural (CVE_LOC = '0000'). | Puede no existir en el MG (se registra en el log). |
| 2 | `NOM_ESTAB` | Nombre del establecimiento. | texto |  | DENUE |  |  |
| 3 | `SCIAN` | Código de actividad SCIAN a 6 dígitos. | texto | clave | DENUE |  |  |
| 4 | `SECTOR` | Sector SCIAN (2 primeros dígitos). | texto | clave | PIPELINE | substr(codigo_act, 1, 2). |  |
| 5 | `PER_OCU_STRATUM` | Estrato de personal ocupado. | categórica |  | DENUE | Texto tal cual (p. ej. '0 a 5 personas'). | Es un rango, no un número: nunca sumarlo. |
| 6 | `LON` | Longitud del establecimiento. | decimal | grados decimales (EPSG:4326) | DENUE | Se anula si cae fuera del rectángulo envolvente de la entidad (+0.05°). | El establecimiento se sigue contando: la asignación usa la clave, no la coordenada. |
| 7 | `LAT` | Latitud del establecimiento. | decimal | grados decimales (EPSG:4326) | DENUE | Igual que LON. |  |

<a id="tabla-denue-ageb-sector"></a>
## Tabla denue_ageb_sector

`data/processed/denue_ageb_sector_{ENT}.csv`. Una fila por AGEB × sector SCIAN.

| # | Variable | Descripción | Tipo | Unidad | Fuente | Derivación | Notas |
|---|---|---|---|---|---|---|---|
| 1 | `ID_AGEB` | Clave de la AGEB. | texto | clave | DENUE |  | Formato largo: una fila por AGEB × sector con al menos un establecimiento. |
| 2 | `SECTOR` | Sector SCIAN (2 dígitos). | texto | clave | DENUE |  |  |
| 3 | `N_UNITS` | Unidades económicas del sector en la AGEB. | entero | establecimientos | PIPELINE | Conteo. |  |

<a id="tabla-ageb-landuse-detail"></a>
## Tabla ageb_landuse_detail

`data/processed/ageb_landuse_detail_{ENT}.csv`. Una fila por AGEB × clase de uso de suelo.

| # | Variable | Descripción | Tipo | Unidad | Fuente | Derivación | Notas |
|---|---|---|---|---|---|---|---|
| 1 | `ID_AGEB` | Clave de la AGEB. | texto | clave | MG2020 |  | Formato largo: una fila por AGEB × clase de uso de suelo presente. |
| 2 | `USO_CLASE` | Clase de uso de suelo y vegetación. | categórica |  | INEGI_USV7 |  |  |
| 3 | `CLASS_AREA_KM2` | Superficie de la clase dentro de la AGEB. | decimal | km² | PIPELINE | Área (EPSG:6372) de la intersección AGEB ∩ USV, disuelta por AGEB y clase. | Disolver antes de medir evita contar dos veces polígonos traslapados (D-28). |
| 4 | `AREA_KM2` | Superficie total de la AGEB. | decimal | km² | MG2020 | Copia de ageb_indicadores. |  |
| 5 | `CLASS_PCT` | Porcentaje de la AGEB cubierto por la clase. | decimal | % | PIPELINE | min(100, 100 × CLASS_AREA_KM2 / AREA_KM2). | Las clases de una AGEB pueden sumar menos de 100 si la capa USV no la cubre completa. |

<a id="tabla-quality-control-report"></a>
## Tabla quality_control_report

`data/processed/quality_control_report_{ENT}.csv` y `_MX.csv`. Una fila por control.

| # | Variable | Descripción | Tipo | Unidad | Fuente | Derivación | Notas |
|---|---|---|---|---|---|---|---|
| 1 | `CVE_ENT` | Clave de entidad. | texto | clave | PIPELINE |  | Una fila por control (29 por entidad). La versión _MX concatena todas. |
| 2 | `CHECK` | Nombre del control. | texto |  | PIPELINE |  | Descritos en docs/DECISIONES.md, sección Controles de calidad. |
| 3 | `STATUS` | Resultado del control. | categórica |  | PIPELINE | PASS o FAIL. |  |
| 4 | `DETAIL` | Evidencia numérica del resultado. | texto |  | PIPELINE |  |  |

<a id="tabla-qc-municipal-coverage"></a>
## Tabla qc_municipal_coverage

`data/processed/qc_municipal_coverage_{ENT}.csv`. Una fila por municipio.

| # | Variable | Descripción | Tipo | Unidad | Fuente | Derivación | Notas |
|---|---|---|---|---|---|---|---|
| 1 | `CVE_MUN_FULL` | Clave municipal completa (entidad + municipio). | texto | clave | MG2020 |  | Una fila por municipio. |
| 2 | `AGEB_AREA` | Suma de la superficie de las AGEB del municipio. | decimal | km² | PIPELINE | Σ AREA_KM2. |  |
| 3 | `N_AGEB` | Número de AGEB del municipio. | entero | AGEB | PIPELINE |  |  |
| 4 | `NOM_MUN` | Nombre del municipio. | texto |  | MG2020 |  |  |
| 5 | `MUN_AREA_KM2` | Superficie del polígono municipal del mismo Marco Geoestadístico. | decimal | km² | MG2020 | Área en EPSG:6372. |  |
| 6 | `DIFF_KM2` | Diferencia de superficie AGEB − municipio. | decimal | km² | PIPELINE | AGEB_AREA − MUN_AREA_KM2. |  |
| 7 | `DIFF_PCT` | Diferencia relativa de superficie. | decimal | % | PIPELINE | 100 × DIFF_KM2 / MUN_AREA_KM2. |  |
| 8 | `KIND` | Tipo de discrepancia, solo si rebasa ambas tolerancias. | categórica |  | PIPELINE | 'gap' (hueco real) o 'attribution' (franja que otro municipio compensa). | Ver D-08. |

