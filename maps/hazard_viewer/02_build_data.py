"""02_build_data.py -- per-hazard data files for the national AGEB hazard viewer.

Reads data/hazard/ageb/climate_ssp_gcm_all_ageb.parquet (81,451 AGEB x 240
scenarios = 15 GCM x 4 SSP x 4 periods, 10 indicators) and writes, in OUT_DIR:

    data/<hazard>.js   window.HZ[<hazard>] = {lo, hi, min, max, layers: {...}}
    manifest.js        window.MANIFEST (hazards, GCMs, SSPs, periods, palettes)

Each layer is one scenario as a uint16 vector (0 = no data, 1..65535 spans
[min, max] of the hazard across ALL its layers), base64 encoded. Column j is the
j-th AGEB of geometry.js: both files are sorted by CVEGEO.

Layer key: "<gcm>|<ssp>|<period>", with gcm = "ens" for the median over the 15
GCMs. lo/hi are the 1st/99th percentiles of the hazard, the default color range.

    python3 maps/hazard_viewer/02_build_data.py [out_dir]
"""
import base64, json, os, sys
import numpy as np
import pandas as pd
import pyarrow.parquet as pq

OUT_DIR = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else "~/Downloads/hazard_viewer_ageb_mexico")
SRC = "data/hazard/ageb/climate_ssp_gcm_all_ageb.parquet"
os.makedirs(os.path.join(OUT_DIR, "data"), exist_ok=True)

HAZARDS = [  # parquet column, label, block, unit, palette, reversed-note
    ("heat_bio2", "Mean diurnal range (BIO2)", "Heat", "degC", "YlOrRd", ""),
    ("heat_bio5", "Max temp. of warmest month (BIO5)", "Heat", "degC", "YlOrRd", ""),
    ("heat_bio10", "Mean temp. of warmest quarter (BIO10)", "Heat", "degC", "YlOrRd", ""),
    ("heat_cdd", "Cooling degree-days", "Heat", "degC x day/year (base 18 C)", "YlOrRd", ""),
    ("drought_pet_annual", "Annual potential evapotranspiration", "Drought", "mm/year", "YlOrBr", ""),
    ("drought_aridity_annual", "Aridity index (P/PET)", "Drought", "", "YlOrBr_r", "colors reversed: dark = driest"),
    ("cold_bio6", "Min temp. of coldest month (BIO6)", "Cold", "degC", "PuBu_r", "colors reversed: dark = coldest"),
    ("cold_bio6_delta", "Change in coldest-month min temp. vs baseline", "Cold", "degC", "PuBu", ""),
    ("flood_bio13", "Precip. of wettest month (BIO13)", "Flood", "mm", "GnBu", ""),
    ("flood_bio15", "Precip. seasonality (BIO15)", "Flood", "CV x 100", "GnBu", ""),
]
GCM_LABEL = {
    "access_cm2": "ACCESS-CM2", "bcc_csm2_mr": "BCC-CSM2-MR", "canesm5": "CanESM5",
    "cmcc_esm2": "CMCC-ESM2", "ec_earth3_veg": "EC-Earth3-Veg", "giss_e2_1_g": "GISS-E2-1-G",
    "inm_cm4_8": "INM-CM4-8", "inm_cm5_0": "INM-CM5-0", "ipsl_cm6a_lr": "IPSL-CM6A-LR",
    "miroc6": "MIROC6", "miroc_es2l": "MIROC-ES2L", "mpi_esm1_2_hr": "MPI-ESM1-2-HR",
    "mpi_esm1_2_lr": "MPI-ESM1-2-LR", "mri_esm2_0": "MRI-ESM2-0", "ukesm1_0_ll": "UKESM1-0-LL",
}
SSP_LABEL = {"ssp_126": "SSP1-2.6", "ssp_245": "SSP2-4.5", "ssp_370": "SSP3-7.0", "ssp_585": "SSP5-8.5"}
PALETTES = {  # the matplotlib colormaps the Oaxaca viewer uses
    "YlOrRd": ["#ffffcc", "#ffeda0", "#fed976", "#feb24c", "#fd8c3c", "#fc4d2a", "#e2191c", "#bb0026", "#800026"],
    "YlOrBr": ["#ffffe5", "#fff7bc", "#fee390", "#fec34f", "#fe9829", "#eb6f14", "#cb4b02", "#983404", "#662506"],
    "YlOrBr_r": ["#662506", "#993404", "#cc4c02", "#ec7014", "#fe9a2a", "#fec550", "#fee392", "#fff7bd", "#ffffe5"],
    "PuBu": ["#fff7fb", "#ece7f2", "#d0d1e6", "#a5bddb", "#73a9cf", "#358fc0", "#056faf", "#04598c", "#023858"],
    "PuBu_r": ["#023858", "#045a8d", "#0570b0", "#3790c0", "#75a9cf", "#a7bddb", "#d1d2e6", "#ede7f2", "#fff7fb"],
    "GnBu": ["#f7fcf0", "#e0f3db", "#ccebc5", "#a7ddb5", "#7accc4", "#4db2d3", "#2a8bbe", "#0867ab", "#084081"],
}

pf = pq.ParquetFile(SRC)
keys = pf.read(columns=["CVEGEO", "ssp", "gcm", "time_period"]).to_pandas()
# The hazard parquet writes rural AGEB as ENT+MUN+AGEB (9 characters, no
# locality); the rest of the database -- and geometry.js, whose order this must
# match -- uses the 13-character CVEGEO, with locality "0000" for rural AGEB.
# Both are sorted as 13-character strings, so normalise BEFORE sorting.
raw = pd.Categorical(keys["CVEGEO"].astype(str))
fix = pd.Series(raw.categories.astype(str))
fix = fix.where(fix.str.len() == 13, fix.str[:5] + "0000" + fix.str[5:])
assert (fix.str.len() == 13).all() and fix.is_unique, "unexpected CVEGEO lengths"
cats = np.array(sorted(fix))
assert len(cats) == 81451
order = pd.Series(np.arange(len(cats)), index=cats)
pos = order.reindex(fix.values).to_numpy()[raw.codes].astype(np.int64)
assert pos.min() >= 0 and pos.max() == 81450
cve = raw
ssps = sorted(keys["ssp"].astype(str).unique()); gcms = sorted(keys["gcm"].astype(str).unique())
pers = sorted(keys["time_period"].astype(str).unique())
assert (len(ssps), len(gcms), len(pers)) == (4, 15, 4), (ssps, gcms, pers)
sid = (pd.Categorical(keys["gcm"].astype(str), categories=gcms).codes.astype(np.int64) * 16
       + pd.Categorical(keys["ssp"].astype(str), categories=ssps).codes.astype(np.int64) * 4
       + pd.Categorical(keys["time_period"].astype(str), categories=pers).codes.astype(np.int64))
assert len(np.unique(sid * 81451 + pos)) == len(sid), "duplicate (scenario, AGEB) rows"
del keys, cve

PERIOD_LABEL = {p: p.replace("_", "-") for p in pers}
for col, label, block, unit, pal, note in HAZARDS:
    v = pf.read(columns=[col]).column(0).to_numpy().astype(np.float32)
    M = np.full((15 * 16, 81451), np.nan, np.float32)
    M[sid, pos] = v
    n_nan = int(np.isnan(M).sum())
    cube = M.reshape(15, 16, 81451)
    ens = np.nanmedian(cube, axis=0)                       # (16, 81451)
    allv = np.concatenate([M.reshape(-1), ens.reshape(-1)])
    fin = allv[np.isfinite(allv)]
    vmin, vmax = float(fin.min()), float(fin.max())
    lo, hi = (float(x) for x in np.percentile(fin[:: max(1, len(fin) // 4_000_000)], [1, 99]))

    def enc(a):
        q = np.zeros(a.shape, np.uint16)
        ok = np.isfinite(a)
        q[ok] = np.clip(np.rint((a[ok] - vmin) / (vmax - vmin) * 65534) + 1, 1, 65535).astype(np.uint16)
        return base64.b64encode(q.astype("<u2").tobytes()).decode()

    layers = {}
    for gi, g in enumerate(gcms):
        for si, s in enumerate(ssps):
            for pi, p in enumerate(pers):
                layers[f"{g}|{s}|{p}"] = enc(cube[gi, si * 4 + pi])
    for si, s in enumerate(ssps):
        for pi, p in enumerate(pers):
            layers[f"ens|{s}|{p}"] = enc(ens[si * 4 + pi])
    obj = {"min": vmin, "max": vmax, "lo": lo, "hi": hi, "layers": layers}
    path = os.path.join(OUT_DIR, "data", f"{col}.js")
    with open(path, "w") as f:
        f.write("window.HZ=window.HZ||{};window.HZ[%s]=" % json.dumps(col))
        json.dump(obj, f, separators=(",", ":"))
        f.write(";")
    print(f"{col:24s} min {vmin:10.3f} max {vmax:10.3f} p1 {lo:10.3f} p99 {hi:10.3f} "
          f"nan {n_nan} -> {os.path.getsize(path) / 1e6:.1f} MB", flush=True)
    del M, cube, ens, allv, fin, layers, obj, v

manifest = {
    "hazards": [dict(key=c, label=l, block=b, unit=u, palette=p, note=n) for c, l, b, u, p, n in HAZARDS],
    "gcms": [dict(key="ens", label="Ensemble median (15 GCMs)")] + [dict(key=g, label=GCM_LABEL[g]) for g in gcms],
    "ssps": [dict(key=s, label=SSP_LABEL[s]) for s in ssps],
    "periods": [dict(key=p, label=PERIOD_LABEL[p]) for p in pers],
    "palettes": PALETTES,
}
with open(os.path.join(OUT_DIR, "manifest.js"), "w") as f:
    f.write("window.MANIFEST=" + json.dumps(manifest, separators=(",", ":")) + ";")
print("manifest.js written")
