"""03_build_exposure.py -- population and establishments per AGEB for the viewer.

Writes OUT_DIR/exposure.js: window.EXPO = {pop: [...], den: [...]} with
POB_TOTAL and DENUE_TOT from data/processed/ageb_integrada_{ENT}.csv, ordered by
CVEGEO like geometry.js (index j = j-th AGEB). Used by the "exposed AGEB" view to
size exposure the way RAND colors counties by the infrastructure they hold.

    python3 maps/hazard_viewer/03_build_exposure.py [out_dir]
"""
import glob, json, os, sys
import pandas as pd

OUT_DIR = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else "~/Downloads/hazard_viewer_ageb_mexico")
fs = sorted(glob.glob("data/processed/ageb_integrada_[0-9][0-9].csv"))
assert len(fs) == 32, f"expected 32 entity files, found {len(fs)}"
d = pd.concat(pd.read_csv(f, dtype={"CVEGEO": str}, usecols=["CVEGEO", "POB_TOTAL", "DENUE_TOT"]) for f in fs)
assert len(d) == 81451 and d.CVEGEO.is_unique and (d.CVEGEO.str.len() == 13).all()
d = d.sort_values("CVEGEO")          # same order as geometry.js
assert d.POB_TOTAL.notna().all() and d.DENUE_TOT.notna().all()
with open(os.path.join(OUT_DIR, "exposure.js"), "w") as f:
    f.write("window.EXPO=" + json.dumps({"pop": d.POB_TOTAL.astype(int).tolist(),
                                          "den": d.DENUE_TOT.astype(int).tolist()},
                                         separators=(",", ":")) + ";")
print("exposure.js:", len(d), "AGEB | population", int(d.POB_TOTAL.sum()), "| establishments", int(d.DENUE_TOT.sum()))
