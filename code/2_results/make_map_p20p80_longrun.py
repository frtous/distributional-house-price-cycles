"""
Map of long-run P20 - P80 growth by local authority, on the basket of units
matched across 1995-97 and 2017-19. The Isles of Scilly and the City of London
are left out.
Inputs:  data/intermediate/Map_P20P80_LongRun_Matched.csv
         data/raw/lad17.geojson
Output:  output/figures/map_long_run.pdf/.png
"""
import numpy as np
import pandas as pd
import geopandas as gpd
import matplotlib.pyplot as plt
import matplotlib as mpl
from matplotlib.patches import Rectangle
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CSV  = ROOT / "data" / "intermediate" / "Map_P20P80_LongRun_Matched.csv"
GEO  = ROOT / "data" / "raw" / "lad17.geojson"
OUT  = ROOT / "output" / "figures"
COL  = "div_matched"
DROP = ["E06000053", "E09000001"]
VLIM = 25            # colour cap (log points)

x = pd.read_csv(CSV)
x = x[~x.lau117cd.isin(DROP)].set_index("lau117cd")
print(f"markets: {len(x)}   mean {x[COL].mean():+.2f}   "
      f"range {x[COL].min():+.1f} / {x[COL].max():+.1f}   "
      f"%positive {100*(x[COL] > 0).mean():.1f}")

g = gpd.read_file(GEO)
g = g[g.LAD17CD.str[0].isin(["E", "W"])].to_crs(epsg=27700)
g = g.merge(x[[COL]], left_on="LAD17CD", right_index=True, how="left")
cmap = plt.get_cmap("RdBu_r").copy()
norm = mpl.colors.Normalize(vmin=-VLIM, vmax=VLIM)


def draw_map(ax, col):
    g.plot(column=col, cmap=cmap, norm=norm, ax=ax,
           edgecolor="white", linewidth=0.15,
           missing_kwds={"color": "0.85", "edgecolor": "white", "linewidth": 0.15})
    ax.set_axis_off()
    lon = g[g.LAD17CD.str.startswith("E09")]
    x0, y0, x1, y1 = lon.total_bounds
    ax.add_patch(Rectangle((x0, y0), x1 - x0, y1 - y0,
                           fill=False, edgecolor="0.35", linewidth=0.7, zorder=5))


def fill_inset(axin, col):
    lon = g[g.LAD17CD.str.startswith("E09")]
    x0, y0, x1, y1 = lon.total_bounds
    axin.set_facecolor("white")
    lon.plot(column=col, cmap=cmap, norm=norm, ax=axin,
             edgecolor="white", linewidth=0.3,
             missing_kwds={"color": "0.85", "edgecolor": "white", "linewidth": 0.3})
    pad = 2500
    axin.set_xlim(x0 - pad, x1 + pad); axin.set_ylim(y0 - pad, y1 + pad)
    axin.set_xticks([]); axin.set_yticks([])
    axin.text(0.03, 0.95, "Greater London", transform=axin.transAxes,
              ha="left", va="top", fontsize=7.5, color="0.25")
    for s in axin.spines.values():
        s.set_visible(True); s.set_linewidth(0.6); s.set_color("0.35")


# London inset outside the map, to the right
fig = plt.figure(figsize=(8.8, 7.6))
ax = fig.add_axes([0.00, 0.075, 0.68, 0.915])
draw_map(ax, COL)
axin = fig.add_axes([0.685, 0.44, 0.30, 0.26])
fill_inset(axin, COL)

cb = fig.colorbar(mpl.cm.ScalarMappable(cmap=cmap, norm=norm), ax=ax,
                  orientation="horizontal", fraction=0.035, pad=0.01,
                  extend="both", shrink=0.75)
cb.set_label("Cumulative P20 growth $-$ P80 growth, 1995–97 to 2017–19 (log points)",
             fontsize=8.5)
cb.ax.tick_params(labelsize=8); cb.outline.set_linewidth(0.4)

for ext in ("png", "pdf"):
    fig.savefig(OUT / f"map_long_run.{ext}",
                dpi=300 if ext == "png" else None,
                bbox_inches="tight", facecolor="white")
print("done | mapped:", int(g[COL].notna().sum()), "of", len(g))
