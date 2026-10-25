# PREFIRE_AUX_SAT bundle

The PREFIRE AUX-SAT product collects other satellites' daily Level-3 snow, cloud and sea ice fields (VIIRS on Suomi-NPP and NOAA-20, AMSR2, NISE) inside each PREFIRE footprint and combines them with AUX-MET into a final surface type. The code is split across four repositories from the PREFIRE mission team (UW-PREFIRE). This repository holds them side by side as git submodules, each pinned to its `R01` release, so the whole algorithm can be cloned in one step:

```sh
git clone --recurse-submodules https://github.com/gchang/prefire-aux-sat-bundle.git
```

| Submodule | Upstream | R01 commit | Role |
|---|---|---|---|
| `PREFIRE_AUX_SAT` | https://github.com/UW-PREFIRE/PREFIRE_AUX_SAT | 49e09d4d36f66aca809b167b569ad205215f3c1d | the AUX-SAT product code (`test/run.sh`, `dist/produce_AUX.py`) |
| `PREFIRE_AUX_MET` | https://github.com/UW-PREFIRE/PREFIRE_AUX_MET | 19cdc59ade9c96c2742a475b77fefcaa1629dcab | preliminary surface type helpers (`utils/classify_sfc_type_prelim.py`) |
| `PREFIRE_PRD_GEN` | https://github.com/UW-PREFIRE/PREFIRE_PRD_GEN | e3933a389894d1af081b3d0bbac4aa0eb27019bc | NetCDF read and write helpers, and the finalization step |
| `PREFIRE_tools` | https://github.com/UW-PREFIRE/PREFIRE_tools | 3b590a6eba09ce596e193ad1e04f636a8b7c3d58 | footprint geometry and file utilities |

Nothing inside the submodules is changed. All four are MIT-licensed by the PREFIRE Mission Team; see each submodule's LICENSE. The official ASDC R01 AUX-SAT products report `PREFIRE_AUX_SAT 1.0.3`, the version in `PREFIRE_AUX_SAT/VERSION.txt` at this commit.

## Finding the sibling packages

`PREFIRE_AUX_SAT`'s README offers two ways to find its siblings: symbolic links in `PREFIRE_AUX_SAT/source/`, or adding each sibling's Python source directory to `PYTHONPATH`. This bundle uses `PYTHONPATH`, so the submodules stay untouched:

```sh
source bundle_env.sh    # from the bundle root; sets PYTHONPATH to the three sibling source directories
```

`bundle_env.sh` also sets `PYTHONDONTWRITEBYTECODE=1`: `PREFIRE_tools` tracks three `.pyc` files, and if Python rewrites them the product's `provenance` attribute says `(modified)`.

## Software

Python 3.10 from conda-forge with the packages in `PREFIRE_AUX_SAT/README.md`, plus git (to record the code versions in the product). Two things matter when you build the environment:

- **numpy must be below 2.** The code was written against numpy 1.26 (see `PREFIRE_AUX_SAT/conda_env.list`). With numpy 2 the final surface type step stops at `classify_sfc_type_final.py:297` (`OverflowError: Python integer -9999 out of bounds for int8`).
- **Use the no-MPI build of ESMF and leave out mpi4py.** One orbit runs on one core and nothing on the run path imports mpi4py. The unpinned list with mpi4py kept the conda solver busy for about 3 hours without an answer.

On Linux x86-64, install the exact environment the check used from the lock file at the bundle root. It lists every package (116, all from conda-forge, each with its checksum), so conda downloads them without solving; it took 14 seconds with an empty package cache on 2026-10-25:

```sh
conda create -n prefire_aux_sat --file conda-linux-64.lock
conda activate prefire_aux_sat
```

The lock gives python 3.10.22, numpy 1.26.4, esmf and esmpy 8.9.1 (nompi), netcdf4 1.7.4 (nompi), h5py 3.16.0, pyhdf 0.11.7, scipy 1.15.2 and cartopy 0.25.0.

The slow alternative, for another platform or to pick up newer builds, is `environment.yml`, the readable list the lock was made from (conda-forge only, with the two pins above). Solving it took 22 to 41 minutes on a 16-core Linux machine; the `timeout` stops a stuck solve after an hour:

```sh
timeout 3600 conda env create -f environment.yml
conda activate prefire_aux_sat
```

To refresh the lock after such a solve: `conda list --explicit --md5 -n prefire_aux_sat > conda-linux-64.lock`.

Memory: **at least 12 GB.** Each VIIRS step builds a search tree of the whole global 0.05-degree grid and peaks at about 8.5 GB. If the process is killed for lack of memory there is no error message and `run.sh` still exits 0 (see "Checking that it worked").

## Inputs (one orbit)

Five files per orbit, all from NASA Earthdata Cloud and all needing an Earthdata login (for example `curl -n -L -c cookies -b cookies -O <url>` with a `~/.netrc` entry for `urs.earthdata.nasa.gov`):

| Product | Collection and archive | File for the test orbit (SAT1 01877, 2024-10-07) |
|---|---|---|
| PREFIRE AUX-MET, R01 | `PREFIRE_SAT1_AUX-MET` or `PREFIRE_SAT2_AUX-MET`, NASA LaRC ASDC | `PREFIRE_SAT1_AUX-MET_R01_P00_20241007075724_01877.nc` (58 MB) |
| SNPP VIIRS daily snow cover CMG, v2 | `VNP10C1`, NSIDC DAAC | `VNP10C1.A2024281.002.2024282222953.h5` (6 MB) |
| NOAA-20 VIIRS daily snow cover CMG, v2 | `VJ110C1`, NSIDC DAAC | `VJ110C1.A2024281.002.2024284032244.h5` (6 MB) |
| AMSR2 daily 12.5 km sea ice, v1 | `AU_SI12`, NSIDC DAAC | `AMSR_U2_L3_SeaIce12km_B04_20241007.he5` (132 MB) |
| Near-real-time Ice and Snow Extent (NISE), v5 | `NISE`, NSIDC DAAC | `NISE_SSMISF18_20241007.HDFEOS` (2 MB) |

The four NSIDC products are daily files for the UTC day of the orbit; an orbit that crosses midnight needs both days of each. Download URLs for the test orbit:

```
https://data.asdc.earthdata.nasa.gov/asdc-prod-protected/PREFIRE/PREFIRE_SAT1_AUX-MET_R01/2024.10.07/PREFIRE_SAT1_AUX-MET_R01_P00_20241007075724_01877.nc
https://data.nsidc.earthdatacloud.nasa.gov/nsidc-cumulus-prod-protected/VIIRS/VNP10C1/2/2024/10/07/VNP10C1.A2024281.002.2024282222953.h5
https://data.nsidc.earthdatacloud.nasa.gov/nsidc-cumulus-prod-protected/VIIRS/VJ110C1/2/2024/10/07/VJ110C1.A2024281.002.2024284032244.h5
https://data.nsidc.earthdatacloud.nasa.gov/nsidc-cumulus-prod-protected/AMSA/AU_SI12/1/2024/10/07/AMSR_U2_L3_SeaIce12km_B04_20241007.he5
https://data.nsidc.earthdatacloud.nasa.gov/nsidc-cumulus-prod-protected/PM/NISE/5/2024/10/07/NISE_SSMISF18_20241007.HDFEOS
```

Put the NSIDC files in **one subfolder per product**, named exactly as below, under one input folder (`IN_PRODS_DIR`). The AUX-MET file can go anywhere; `run.sh` expects it in the same input folder.

```
inputs/
  PREFIRE_SAT1_AUX-MET_R01_P00_20241007075724_01877.nc
  VNP10C1/VNP10C1.A2024281.002.2024282222953.h5
  VJ110C1/VJ110C1.A2024281.002.2024284032244.h5
  AMSR_U2_L3_SeaIce12km_B04/AMSR_U2_L3_SeaIce12km_B04_20241007.he5
  NISE_SSMISF18/NISE_SSMISF18_20241007.HDFEOS
```

The input folder must be writable: if a subfolder is missing, `dist/produce_AUX.py` creates a symbolic link with that name pointing back at the input folder itself. Do not rely on that with a flat folder: the VIIRS lookup (`calculate_VIIRS_L3_aux.py:66-67`) matches any file with the right date, so both satellite slots can end up reading the same VIIRS file (see "Known issue").

## Running one orbit: the mission's test script

The package's own route is `PREFIRE_AUX_SAT/test/run.sh`, which the README says to copy to `my-run.sh` and edit. It must be run from `PREFIRE_AUX_SAT/test/`. It sets these environment variables and then calls `dist/determine_prdgit.py` (records the code versions; skipped if `dist/for_SDPS_delivery.txt` exists) and `dist/produce_AUX.py`, which takes no arguments:

| Variable | Set by `run.sh` to | Meaning |
|---|---|---|
| `PACKAGE_TOP_DIR` | `PREFIRE_AUX_SAT` | top of the package |
| `ANCILLARY_DATA_DIR` | `PREFIRE_AUX_SAT/dist/ancillary` | holds `Aux-Sat_product_filespecs.json`; nothing to download |
| `IN_PRODS_DIR` | `input_dir`, default `test/inputs` | the input folder laid out as above |
| `AUX_MET_FILE` | from `cfg_str1`, default `test/inputs/PREFIRE_SAT1_AUX-MET_R01_P00_20241007075724_01877.nc` | the AUX-MET granule of the orbit |
| `ATRACK_IDX_RANGE_0BI` | from `cfg_str1`, `ATRACK_IDXRANGE_0BASED_INCLUSIVE:0:END` | frames to process (all) |
| `OUTPUT_DIR` | `test/outputs` | where the product is written; must exist |
| `TMP_DIR` | `test/outputs` | temporary files (deleted at the end); must exist |
| `PRODUCT_FULLVER` | `R01_P00` | product version in the file name |
| `MKL_NUM_THREADS`, `NUMEXPR_NUM_THREADS`, `OMP_NUM_THREADS`, `VECLIB_MAXIMUM_THREADS`, `OPENBLAS_NUM_THREADS` | `1` | one thread |

For the test orbit, from the bundle root, with the inputs laid out as above in `/path/to/inputs`:

```sh
source bundle_env.sh
cd PREFIRE_AUX_SAT/test
ln -s /path/to/inputs inputs
mkdir -p outputs
cp run.sh my-run.sh
./my-run.sh
```

The product is `PREFIRE_AUX_SAT/test/outputs/raw-PREFIRE_SAT1_AUX-SAT_R01_P00_20241007075724_01877.nc` (about 2.3 MB). `inputs` and `outputs` are ignored by the submodule's `.gitignore` and `my-run.sh` is untracked, so the code versions recorded in the product stay clean (`git status` in the bundle still lists `PREFIRE_AUX_SAT` as having untracked content).

For another orbit or other folders, change four lines of `my-run.sh`: `input_dir`, `cfg_str1` (the frame range, a comma, then the AUX-MET path), `OUTPUT_DIR` and `TMP_DIR`. For example, instead of `cp run.sh my-run.sh`:

```sh
sed -e 's|^input_dir=.*|input_dir="/path/to/inputs";|' \
    -e 's|^cfg_str1=.*|cfg_str1="ATRACK_IDXRANGE_0BASED_INCLUSIVE:0:END,/path/to/inputs/PREFIRE_SAT1_AUX-MET_R01_P00_20241007075724_01877.nc";|' \
    -e 's|^OUTPUT_DIR=.*|OUTPUT_DIR=/path/to/raw;|' \
    -e 's|^TMP_DIR=.*|TMP_DIR=/path/to/tmp;|' \
    run.sh > my-run.sh
chmod +x my-run.sh
mkdir -p /path/to/raw /path/to/tmp
./my-run.sh
```

`run.sh` processes only `cfg_str1`; the SAT2 orbit on its `cfg_str2` line is commented out of the loop.

### The same run without the script

`run.sh` only sets the variables above, so they can also be set by hand, from the bundle root:

```sh
source bundle_env.sh
python PREFIRE_AUX_SAT/dist/determine_prdgit.py     # writes PREFIRE_AUX_SAT/dist/prdgit_version.txt; the product step needs it
export MKL_NUM_THREADS=1 NUMEXPR_NUM_THREADS=1 OMP_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 OPENBLAS_NUM_THREADS=1
export PACKAGE_TOP_DIR=$PWD/PREFIRE_AUX_SAT ANCILLARY_DATA_DIR=$PWD/PREFIRE_AUX_SAT/dist/ancillary \
       IN_PRODS_DIR=/path/to/inputs OUTPUT_DIR=/path/to/raw TMP_DIR=/path/to/tmp PRODUCT_FULLVER=R01_P00 \
       ATRACK_IDX_RANGE_0BI=ATRACK_IDXRANGE_0BASED_INCLUSIVE:0:END \
       AUX_MET_FILE=/path/to/inputs/PREFIRE_SAT1_AUX-MET_R01_P00_20241007075724_01877.nc
mkdir -p $OUTPUT_DIR $TMP_DIR
python PREFIRE_AUX_SAT/dist/produce_AUX.py
```

### Finalization into the archived product

The mission archives AUX-SAT after a second step in `PREFIRE_PRD_GEN`, which rounds the floating-point fields to their `least_significant_digit` and adds the archive's metadata (AUX-SAT keeps all frames). From the bundle root, after `source bundle_env.sh`:

```sh
python PREFIRE_PRD_GEN/dist/determine_prdgit.py    # once; the finalization step needs it
mkdir -p /path/to/final                            # must exist
export MKL_NUM_THREADS=1 NUMEXPR_NUM_THREADS=1 OMP_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 OPENBLAS_NUM_THREADS=1
export PACKAGE_TOP_DIR=$PWD/PREFIRE_PRD_GEN ANCILLARY_DATA_DIR=$PWD/PREFIRE_PRD_GEN/dist/ancillary \
       OUTPUT_PRODUCT_DIR=/path/to/final OUTPUT_OPTIONS="" PRD_GEN_BASIC_ONLY=1 \
       INPUT_FPATH_OR_FPREFIX=/path/to/raw/raw-PREFIRE_SAT1_AUX-SAT_R01_P00_20241007075724_01877.nc
python PREFIRE_PRD_GEN/dist/produce_PRD.py
```

`PRD_GEN_BASIC_ONLY=1` writes the product and its metrics file and skips the browse image and the CMR metadata file. Those need matplotlib, cartopy, shapely, geopandas and pandas, and network access for cartopy's Natural Earth coastlines.

## Checking that it worked

`produce_AUX.py` runs five steps one after another (AMSR and NISE regridding, VIIRS for SNPP, VIIRS for NOAA-20, final surface type, combining) and does not stop when one fails. A failed step still leaves `run.sh` with exit code 0 and a broken output file of a few hundred bytes. Check that the log has no `Traceback` and that the product is about 2 MB.

## Known issue: VIIRS satellite slots

`calculate_VIIRS_L3_aux.py:66-67` finds the VIIRS file with the pattern `<IN_PRODS_DIR>/<product>/*.A<YYYYDDD>.*` and takes the first match, without checking the product name in the file name. With one subfolder per product, as above, each satellite reads its own file. With a flat folder, both slots can get the same satellite's file. The official R01 granules show the same mix-up: in the test orbit's official file both VIIRS slots hold NOAA-20 data and both carry the NOAA-20 DOI (`10.5067/DNC2SNXE6HJB`). A run with the layout above therefore differs from the official file in the SNPP slot, and through it in the snow data source and the final surface type for about 2% of footprints (snowy land). Putting the NOAA-20 file in `VNP10C1/` as well reproduces the official file exactly. The fix belongs in `calculate_VIIRS_L3_aux.py` (match `<product>.A<YYYYDDD>.*`); this bundle leaves the R01 code as released.

## Run time

About 3 to 5 minutes per orbit on one core (more cores do not help), peak memory 8.4 GB, almost all of it in the two VIIRS steps. Finalization takes about a second and 75 MB. About 205 MB of input per orbit; the raw product is about 2.3 MB and the final product about 2.2 MB.

Checked on 2026-10-25 from a fresh `git clone --recurse-submodules`, with the environment above (numpy 1.26.4, esmf 8.9.1 nompi) and SAT1 orbit 01877, run with no network and a 14 GB memory limit. Both `run.sh` routes above (the test folders, and the `sed` edit with folders outside the clone) gave the same raw product in 4 to 5 minutes at 8.4 GB peak. After finalization, compared with the official ASDC R01 AUX-SAT granule: geometry, the AMSR2 and NISE fields, the sea ice data source, `VIIRS_L3_num_pts_total` and every NOAA-20 VIIRS field are identical, and `merged_surface_type_final` agrees for 51,927 of 52,880 footprints (98.2%). The rest, and the SNPP slot, differ only because of the satellite slot issue above: with the NOAA-20 file also in `VNP10C1/`, every variable in the final file is identical to the official granule, and the file differs only in its creation time, netCDF library version and code version hashes.
