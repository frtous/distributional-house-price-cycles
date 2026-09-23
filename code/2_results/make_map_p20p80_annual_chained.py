"""
Map of chained P20 - P80 growth by local authority over the boom (2002-2006)
and the bust (2007-2011), side by side on a common scale.
Inputs:  data/intermediate/Map_P20P80_A_data_0211_CH.csv
         data/raw/lad17.geojson
Output:  output/figures/map_boom_bust.pdf/.png
"""
import os
import numpy as np
import pandas as pd
import geopandas as gpd
import matplotlib.pyplot as plt
import matplotlib as mpl
from matplotlib.patches import Rectangle
from shapely.geometry import box
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GEO  = ROOT / "data" / "raw" / "lad17.geojson"
CSV  = ROOT / "data" / "intermediate" / "Map_P20P80_A_data_0211_CH.csv"
OUT  = ROOT / "output" / "figures"
WINDOWS = {"boom": (2002, 2006), "bust": (2007, 2011)}
VLIM_EP = 30                    # colour cap (log points); extremes clipped

# ---------------------------------------------------------------- chained div
vals = pd.read_csv(CSV).set_index("lau117cd")

for k, (y0, y1) in WINDOWS.items():
    v = vals[f"div_{k}"].dropna()
    print(f"{k:5s} {y0}-{y1}: n={len(v):3d}  mean={v.mean():+6.2f}  "
          f"median={v.median():+6.2f}  min={v.min():+6.1f}  max={v.max():+6.1f}  "
          f"%positive={100*(v>0).mean():.1f}  %clipped={100*(v.abs()>VLIM_EP).mean():.1f}")

# ------------------------------------------------------------------- geometry
if not os.path.exists(GEO):
    raise SystemExit(f"{GEO} not found.")
g = gpd.read_file(GEO)
g = g[g.LAD17CD.str[0].isin(["E", "W"])].to_crs(epsg=27700)
g = g.merge(vals, left_on="LAD17CD", right_index=True, how="left")
cmap = plt.get_cmap("RdBu_r").copy()

X0, Y0, X1, Y1 = g.total_bounds
lon = g[g.LAD17CD.str.startswith("E09")]
LX0, LY0, LX1, LY1 = lon.total_bounds
PAD = 2500
LW, LH = (LX1 - LX0) + 2 * PAD, (LY1 - LY0) + 2 * PAD

# London inset in map coordinates (EPSG:27700), in the sea at the top left
MARGIN, SCALE = 4000, 3.27 * 0.95
IW, IH = LW * SCALE, LH * SCALE
INSET_RECT = [X0 + MARGIN, Y1 - MARGIN - IH, IW, IH]
assert not g.intersects(box(INSET_RECT[0], INSET_RECT[1],
                            INSET_RECT[0] + IW, INSET_RECT[1] + IH)).any(), \
    "inset rectangle overlaps a district - move it"


def draw_map(ax, col, norm, locator=True):
    g.plot(column=col, cmap=cmap, norm=norm, ax=ax,
           edgecolor="white", linewidth=0.15,
           missing_kwds={"color": "0.85", "edgecolor": "white", "linewidth": 0.15})
    ax.set_axis_off()
    if locator:
        ax.add_patch(Rectangle((LX0, LY0), LX1 - LX0, LY1 - LY0,
                               fill=False, edgecolor="0.35", linewidth=0.7, zorder=5))


def fill_inset(axin, col, norm):
    axin.set_facecolor("white")
    lon.plot(column=col, cmap=cmap, norm=norm, ax=axin,
             edgecolor="white", linewidth=0.3,
             missing_kwds={"color": "0.85", "edgecolor": "white", "linewidth": 0.3})
    axin.set_xlim(LX0 - PAD, LX1 + PAD); axin.set_ylim(LY0 - PAD, LY1 + PAD)
    axin.set_xticks([]); axin.set_yticks([])
    axin.text(0.03, 0.95, "Greater London", transform=axin.transAxes,
              ha="left", va="top", fontsize=7.5, color="0.25")
    for s_ in axin.spines.values():
        s_.set_visible(True); s_.set_linewidth(0.6); s_.set_color("0.35")


def draw(ax, col, norm):
    draw_map(ax, col, norm)
    axin = ax.inset_axes(INSET_RECT, transform=ax.transData)
    fill_inset(axin, col, norm)


def save(fig, fname):
    for ext in ("png", "pdf"):
        fig.savefig(OUT / f"{fname}.{ext}", dpi=300 if ext == "png" else None,
                    bbox_inches="tight", facecolor="white")
    plt.close(fig)


# Boom and bust side by side, common scale
norm = mpl.colors.Normalize(vmin=-VLIM_EP, vmax=VLIM_EP)
fig, axes = plt.subplots(1, 2, figsize=(10.6, 7.4))
for ax, (col, ttl) in zip(axes, [("div_boom", "Boom, 2002\u20132006"),
                                 ("div_bust", "Bust, 2007\u20132011")]):
    draw(ax, col, norm)
    ax.set_title(ttl, fontsize=10.5, pad=4)
sm = mpl.cm.ScalarMappable(cmap=cmap, norm=norm)
cb = fig.colorbar(sm, ax=axes, orientation="horizontal", fraction=0.030,
                  pad=0.015, extend="both", shrink=0.55)
cb.set_label("Cumulative P20 growth $-$ P80 growth (log points)", fontsize=9)
cb.ax.tick_params(labelsize=8.5); cb.outline.set_linewidth(0.4)
fig.subplots_adjust(left=0.01, right=0.99, top=0.96, wspace=0.02)
save(fig, "map_boom_bust")

print("done | mapped:", int(g.div_boom.notna().sum()), "of", len(g),
      "| inset at x %.0f-%.0f y %.0f-%.0f (EPSG:27700)"
      % (INSET_RECT[0], INSET_RECT[0] + IW, INSET_RECT[1], INSET_RECT[1] + IH))
