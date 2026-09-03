# Fuel Demand, Spatial Competition, and Local Market Structure

Replication materials for:

> Gonzales Peña, David Ricardo. *Fuel Demand, Spatial Competition, and Local Market Structure: Evidence from Gasohol Retailing in Lima and Callao*.

The study estimates the price elasticity of demand for 90- and 95-octane gasohol in Metropolitan Lima and Callao from March 2020 through December 2022. The repository contains the analysis dataset, an English-language Stata replication script, the paper, and documentation.

## Repository structure

```text
fuel-demand-lima-callao/
|-- README.md
|-- CITATION.cff
|-- code/
|   `-- replication.do
|-- data/
|   |-- fuel_demand_lima_callao.dta
|   `-- README.md
`-- paper/
    `-- fuel_demand_spatial_competition_lima_callao.pdf
```

## Requirements

- Stata 17 or later is recommended.
- Internet access is required the first time the script runs so that missing community-contributed packages can be installed from SSC.
- Required Stata packages: `ftools`, `reghdfe`, `estout`, `ivreg2`, `ranktest`, and `ivreghdfe`.
- Git LFS is required to version the `.dta` file. The dataset is approximately 71 MB.

## Reproduce the analysis

1. Download or clone the repository.
2. Open Stata.
3. Set Stata's working directory to the repository root, not to the `code` folder.
4. Run:

```stata
do "code/replication.do"
```

The script also detects when it is launched while the working directory is `code/` and moves one level up automatically. It never overwrites the source dataset. Generated tables, logs, and derived data are written under `output/`.

## Main outputs

The script produces source tables for the results reported in the paper:

- Table 1: descriptive statistics;
- Table 2: main fixed-effects elasticity estimates;
- Table 3: complementary models with aggregate controls;
- Table 4: income-by-time robustness checks;
- Table 5: instrumental-variable diagnostic;
- Appendix Tables 7-8: systematic PRC-instrument diagnostics;
- Appendix Table 9: temporal robustness;
- Appendix Table 10: alternative functional forms.

Each results table is exported as both CSV and RTF when appropriate. The complete execution log is saved as `output/logs/replication.log`.

## Data

The unit of observation is district-product-month. The dataset contains 3,330 observations covering 50 districts and two products (G90 and G95). It contains 3,272 observations in the main descriptive sample before regression-specific singleton handling.

The data combine information from Osinergmin, INEI, the Central Reserve Bank of Peru, and the Oxford COVID-19 Government Response Tracker. See [`data/README.md`](data/README.md) and the paper for variable definitions and source details.

The original variable names are retained to avoid breaking the analysis. Some source variables therefore have Spanish names, but the replication code and all repository documentation are in English.


## Citation

Please use the metadata in [`CITATION.cff`](CITATION.cff). On GitHub, this file activates the repository's **Cite this repository** function.

Instructions for publishing the folder, including the required Git LFS step, are in [`docs/GITHUB_UPLOAD.md`](docs/GITHUB_UPLOAD.md).

## Contact

David Ricardo Gonzales Peña  
IESE Business School  
Email: drgnzales@iese.edu
