# Data documentation

## File

`fuel_demand_lima_callao.dta` is the analysis dataset used by `code/replication.do`.

## Coverage and unit of observation

- Geography: Metropolitan Lima and Callao, Peru
- Period: March 2020-December 2022
- Products: 90-octane gasohol (G90) and 95-octane gasohol (G95)
- Unit: district-product-month
- Rows: 3,330
- Districts: 50
- Main descriptive sample: 3,272 observations

## Key variables

| Variable | Description |
| --- | --- |
| `distrito_id` | Numeric district identifier |
| `distrito` | District name |
| `fecha_m` | Stata monthly date |
| `year`, `month` | Calendar year and month |
| `producto_id` | Product identifier: 1 = G90; 2 = G95 |
| `producto` | Product label |
| `demanda_galones_dia` | Quantity sold, expressed as average gallons per day in the source dataset |
| `ln_q` | Natural logarithm of quantity |
| `precio_real` | Real gasohol price |
| `ln_p` | Natural logarithm of real price |
| `competencia_promedio_455m` | Average number of nearby stations within 455 meters |
| `competencia_promedio_800m` | Average number of nearby stations within 800 meters |
| `competencia_promedio_1000m` | Average number of nearby stations within 1,000 meters |
| `nivel_ingreso_proxy` | District socioeconomic proxy based on the 2018 poverty ranking |
| `income_group` | Tercile of the district income proxy |
| `pbi_yoy_m` | Monthly GDP, year-on-year change |
| `ln_flow_lima_total` | Natural logarithm of Lima's vehicle-flow index |
| `stringency_m` | COVID-19 policy stringency index |
| `usdpen_m` | PEN/USD exchange rate |
| `prc_g90_ref_usdbl_m` | Osinergmin G90 reference price |
| `prc_g95_ref_usdbl_m` | Osinergmin G95 reference price |
| `z_bartik_dprc_l8_1000` | Lag-8 PRC shift-share instrument interacted with 1,000-meter competition |

The dataset contains many additional generated instruments and diagnostic variables. Their naming convention identifies the price series or shock, lag, and spatial radius. For example, `z_bartik_dprc_l8_1000` combines a shift-share logarithmic PRC change at lag 8 with the 1,000-meter competition measure.

## Sources

The analysis combines:

- Osinergmin fuel quantities, retail prices, service-station locations, spatial competition measures, and fuel reference prices;
- INEI consumer prices, district characteristics, and vehicle-flow information;
- Central Reserve Bank of Peru macroeconomic and exchange-rate series; and
- Oxford COVID-19 Government Response Tracker policy indicators.

Consult Sections 4-5 of the paper for the construction of variables, limitations, and the identification discussion.

## Data-use note

The repository preserves the original variable names for reproducibility, including Spanish-language source names. Users are responsible for complying with the terms of the original data providers. The source dataset contains aggregate district-level observations rather than individual consumer records.
