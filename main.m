% main.m - Main execution script for Synthetic Bridge Inventory generation
clear; clc; close all;

% Add source folder to path
addpath('src');

% 1. Load raw open-source data
load('data/NIData.mat');

% 2. Execute pipeline using isolated functions
BridgeDemand = get_locations_05(CleanRoads, CleanRivers);
BridgeDemand = calculate_required_spans(BridgeDemand, CleanRoads, CleanRivers);
BridgeDemand = assign_type(BridgeDemand);
BridgeDemand = calculate_environmental_demand(BridgeDemand, Coast_Data);
BridgeDemand = calculating_scour_risk_02(BridgeDemand, CleanRivers);


% 3. Generate output figures
results_visualisation(BridgeDemand, CleanRivers, CleanRoads)