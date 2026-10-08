# Generation of Synthetic Regional Bridge Inventories Using Open-Source Data

This repository contains the MATLAB code and processed datasets required to generate a realistic, synthetic regional bridge inventory. By combining open-source geospatial and operational datasets, this framework provides a practical, restriction-free method to build bespoke synthetic networks tailored to a region's specific construction methods and policies.

The methodology successfully produces a validated regional bridge stock inventory which accurately replicates the real-world spatial distributions, span geometries, and specific structural forms of the region's infrastructure, utilizing Northern Ireland as the primary case study.

## Repository Structure

```text
Synthetic-Bridge-Inventory/
├── data/
│   └── NIData.mat
│       ├── CleanRivers                 # Processed river network data
│       ├── CleanRoads                  # Processed road and rail network data
│       └── Coast_Data                  # Coastal boundary coordinates
├── src/
│   ├── assign_type.m                   # Classifies overarching structural type
│   ├── calculate_environmental_demand.m # Maps exposure to chlorides
│   ├── calculate_required_spans.m      # Determines necessary span arrangements
│   ├── calculating_scour_risk.m        # Generates scour risk index
│   ├── get_locations_05.m              # Identifies bridges via GIS intersections
│   └── results_visualisation           # produces figures of GIS netwroks and bridge inventory
├── main.m                              # Main execution script
├── LICENSE                             # CC BY-NC 4.0 License
└── README.md                           # This file
```

## Prerequisites
* **MATLAB**
* **Mapping Toolbox** (Required for spatial functions such as `polyxpoly` and `geoscatter` used in the scripts)
* **Statistics and Machine Learning Toolbox**

## Usage
1. Clone this repository to your local machine.
2. Open MATLAB and navigate to the `Synthetic-Bridge-Inventory` root folder.
3. Open `main.m` and click **Run**.
4. The script will execute the complete pipeline and output a structured `BridgeDemand` database containing the generated inventory.

## Data Attribution
The synthetic bridge inventory generated in this project utilises geospatial and operational datasets adapted from OpenDataNI (https://admin.opendatani.gov.uk/dataset/). This data is used under the Open Government Licence v3.0 (OGL).
<br> River Data 
https://admin.opendatani.gov.uk/dataset/https-www-daera-ni-gov-uk-sites-default-files-publications-doe-riversegmentgml-zip
<br> Road and Rail Data 
https://admin.opendatani.gov.uk/dataset/osni-open-data-50k-transport-transport-lines
<br> Coast Data 
https://admin.opendatani.gov.uk/dataset/2021-ni-coastal-survey2


## Contact
**Connor O'Higgins**

School of Natural and Built Environment, Queen's University Belfast

Email: c.ohiggins@qub.ac.uk