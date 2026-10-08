function results_visualisation(BridgeDemand, CleanRivers, CleanRoads)
%results_visualisation Generates spatial network and bridge distribution maps.
%   RESULTS_VISUALISATION(BridgeDemand, CleanRivers, CleanRoads) produces
%   geographical visualizations of the infrastructure networks and the 
%   generated synthetic bridge inventory. 
%
%   The function creates composite figures displaying the road/rail network 
%   grouped by road class and the river network categorized by Strahler stream 
%   order. It also plots a regional macro-scale distribution of all 
%   identified bridge locations alongside a localised detail view that 
%   categorizes bridges by their topological use (e.g., Road over River, 
%   Road over Road).
%
%   Inputs:
%       BridgeDemand - Struct array containing identified bridge locations, 
%                      coordinates, and uses.
%       CleanRivers  - Struct array containing hydrological network geometry 
%                      and Strahler orders.
%       CleanRoads   - Struct array containing road and rail network geometry 
%                      and road classifications.
%
%   Outputs:
%       None (Generates MATLAB figures).
% =========================================================================
% SCRIPT: PLOT FIGURES
% =========================================================================
% Purpose: Generates a side-by-side map of (a) Roads and (b) Rivers.
% =========================================================================

if ~exist('CleanRoads', 'var') || ~exist('CleanRivers', 'var')
    error('Required variables CleanRoads or CleanRivers missing.');
end

%% Figure 1 
fprintf('Generating Figure 1: Network Geometries...\n');

% Create a wide figure suitable for a 2-column paper layout
fig = figure('Name', 'Figure 1: Primary Networks', 'Color', 'w', 'Position', [-800 -50 600 1200]);

% Use tiledlayout for clean side-by-side subplots
t = tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');


% ========================================================================
% SUBPLOT (a): ROAD AND RAIL NETWORK
% ========================================================================
ax1 = nexttile;
hold(ax1, 'on'); axis(ax1, 'equal'); box(ax1, 'on');

% Adjusted Colors for White Background
plot_group(ax1, CleanRoads, ["<4M_TARRED", "<4M_T_OVER", "CL_MINOR", "CL_M_OVER"], ...
    [0.8 0.8 0.8], 0.5, 'Minor / Local', '-');

plot_group(ax1, CleanRoads, ["B_CLASS"], ...
    [0.5 0.5 0.5], 0.8, 'B-Roads', '-');

plot_group(ax1, CleanRoads, ["A_CLASS"], ...
    [0.9 0.5 0.0], 1.2, 'A-Roads', '-');

plot_group(ax1, CleanRoads, ["MOTORWAY", "DUAL_CARR"], ...
    [0.8 0.0 0.0], 2.0, 'Motorway / Dual', '-');

plot_group(ax1, CleanRoads, ["CL_RAIL", "RL_TUNNEL", "UNSHOWN_RL"], ...
    [0.0 0.0 0.0], 1.2, 'Railways', '-.');

% Formatting Subplot A
title(ax1, '(a)', 'FontSize', 12, 'FontWeight', 'bold');
daspect(ax1, [1/cosd(54.5) 1 1]);
set(ax1, 'XTick', [], 'YTick', []); % Remove lat/lon ticks for clean look
legend(ax1, 'show', 'Location', 'northwest', 'FontSize', 9);


% ========================================================================
% SUBPLOT (b): RIVER NETWORK (STRAHLER ORDER)
% ========================================================================
ax2 = nexttile;
hold(ax2, 'on'); axis(ax2, 'equal'); box(ax2, 'on');

% Colormap: Light Blue -> Deep Navy (for white background)
strahler_colors = [
    0.6 0.8 1.0;  % Order 1
    0.4 0.6 1.0;  % Order 2
    0.2 0.4 0.8;  % Order 3
    0.0 0.2 0.6;  % Order 4
    0.0 0.0 0.4   % Order 5+
];

% Extract arrays once for fast logical indexing
all_strahler = [CleanRivers.Strahler];

% CRASH-PROOF FIX: Use strcmp. It safely ignores NaNs and empties.
% We check for both 'Y' (char array) and "Y" (string) just to be perfectly safe.
is_real_river = strcmp([CleanRivers.Type], 'Y') | strcmp([CleanRivers.Type], "Y");

for s = 1:5
    % Filter by both Strahler Order AND our new logical array
    if s < 5
        idx = find(all_strahler == s & is_real_river);
        name = sprintf('Stream Order %d', s);
        lw = 0.5 + (s * 0.3);
    else
        idx = find(all_strahler >= 5 & is_real_river);
        name = 'Major Rivers (5+)';
        lw = 2.0;
    end
    
    if isempty(idx), continue; end
    
    lats = {CleanRivers(idx).Lat}';
    lons = {CleanRivers(idx).Lon}';
    lp = cellfun(@(x) [x; NaN], lats, 'UniformOutput', false);
    lo = cellfun(@(x) [x; NaN], lons, 'UniformOutput', false);
    
    plot(ax2, cell2mat(lo), cell2mat(lp), 'Color', strahler_colors(s,:), ...
        'LineWidth', lw, 'DisplayName', name);
end

% Formatting Subplot B
title(ax2, '(b)', 'FontSize', 12, 'FontWeight', 'bold');
daspect(ax2, [1/cosd(54.5) 1 1]);
set(ax2, 'XTick', [], 'YTick', []); % Remove lat/lon ticks
legend(ax2, 'show', 'Location', 'northwest', 'FontSize', 9);

% Link axes so zooming/panning on one map affects the other
linkaxes([ax1, ax2], 'xy');

%% Figure 2 

% 1. Create Figure (Wide Aspect Ratio, White Background)
fig = figure('Name', 'Network Attributes & Bridge Extraction', 'Color', 'w', 'Position', [50, 100, 1500, 750]);
t = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% Define your requested zoom coordinates
zoom_xlim = [-6.2567, -6.1588];
zoom_ylim = [54.4701, 54.5150];

% =========================================================================
% SUBPLOT (A): REGIONAL MACRO VIEW (Scale of the Network)
% =========================================================================
ax1 = nexttile;
hold(ax1, 'on'); axis(ax1, 'equal'); box(ax1, 'on');
set(ax1, 'Color', 'w', 'XColor', 'k', 'YColor', 'k'); % White background, black axes text
% title(ax1, 'Macro-Scale: Synthetic Digital Twin Network', 'Color', 'k', 'FontSize', 14, 'FontWeight', 'bold');
title(ax1, '(a)', 'Color', 'k', 'FontSize', 14, 'FontWeight', 'bold');
xlabel(ax1, 'Longitude'); ylabel(ax1, 'Latitude');

% Plot Base Networks on ax1
plot_infrastructure(ax1, CleanRoads, CleanRivers);

% Plot ALL bridge locations as tiny slate-grey points (changed from white to dark)
scatter(ax1, [BridgeDemand.Lon], [BridgeDemand.Lat], 4, [0.3 0.3 0.3], 'filled', ...
    'MarkerEdgeAlpha', 0, 'MarkerFaceAlpha', 0.9, 'DisplayName', 'Bridge Location');

% FIX: Create a dummy line handle purely to feed the legend safely
plot(ax1, NaN, NaN, 'Color', [0 1 0], 'LineStyle', '-', 'LineWidth', 2.0, 'DisplayName', 'Zoom Region (b)');

% Draw the actual red dashed bounding box WITHOUT the illegal DisplayName parameter
rectangle(ax1, 'Position', [zoom_xlim(1), zoom_ylim(1), zoom_xlim(2)-zoom_xlim(1), zoom_ylim(2)-zoom_ylim(1)], ...
    'EdgeColor', [0 1 0], 'LineStyle', '-', 'LineWidth', 2.0);

% Polish Subplot A
daspect(ax1, [1/cosd(54.5) 1 1]);
legend(ax1, 'show', 'Location', 'southwest', 'TextColor', 'k', 'Color', 'white', 'EdgeColor', 'black');


% =========================================================================
% SUBPLOT (B): LOCALISED DETAIL VIEW (Level of Detail at Nodes)
% =========================================================================
ax2 = nexttile;
hold(ax2, 'on'); axis(ax2, 'equal'); box(ax2, 'on');
set(ax2, 'Color', 'w', 'XColor', 'k', 'YColor', 'k');
% title(ax2, 'Meso-Scale: Categorised Bridge Use', 'Color', 'k', 'FontSize', 14, 'FontWeight', 'bold');
title(ax2, '(b)', 'Color', 'k', 'FontSize', 14, 'FontWeight', 'bold');
set(ax2, 'XTick', [], 'YTick', []); % Hide ticks on zoom for cleaner presentation look

% Plot Base Networks on ax2 (will be cropped by xlim/ylim)
plot_infrastructure(ax2, CleanRoads, CleanRivers);

% Filter and Plot Bridges in the Zoom Area Grouped by Use
all_lats = [BridgeDemand.Lat];
all_lons = [BridgeDemand.Lon];
in_zoom = all_lons >= zoom_xlim(1) & all_lons <= zoom_xlim(2) & all_lats >= zoom_ylim(1) & all_lats <= zoom_ylim(2);
LocalBridges = BridgeDemand(in_zoom);

if ~isempty(LocalBridges)
    b_uses = string({LocalBridges.Use});
    
    % High-contrast color palette optimized for a white canvas
    c_rr  = [0.0 0.45 0.74]; % Solid Blue for River
    c_rrd = [0.85 0.33 0.1]; % Rust Orange for Road Over Road
    c_rrl = [0.93 0.69 0.13];% Golden Yellow for Road Over Rail
    c_rlr = [0.47 0.67 0.19];% Sage Green for Rail Over River
    
    % Plot categories sequentially (with clean black borders to ensure they pop)
    idx = b_uses == "Road_River";
    if any(idx), scatter(ax2, [LocalBridges(idx).Lon], [LocalBridges(idx).Lat], 90, c_rr, 'filled', 'o', 'MarkerEdgeColor', 'k', 'DisplayName', 'Road over River'); end
    
    idx = b_uses == "Road_Road";
    if any(idx), scatter(ax2, [LocalBridges(idx).Lon], [LocalBridges(idx).Lat], 100, c_rrd, 'filled', 's', 'MarkerEdgeColor', 'k', 'DisplayName', 'Road over Road (Flyover)'); end
    
    idx = b_uses == "Road_Rail";
    if any(idx), scatter(ax2, [LocalBridges(idx).Lon], [LocalBridges(idx).Lat], 100, c_rrl, 'filled', '^', 'MarkerEdgeColor', 'k', 'DisplayName', 'Road over Rail'); end
    
    idx = b_uses == "Rail_River";
    if any(idx), scatter(ax2, [LocalBridges(idx).Lon], [LocalBridges(idx).Lat], 120, c_rlr, 'filled', 'd', 'MarkerEdgeColor', 'k', 'DisplayName', 'Rail over River'); end
end

% Apply Zoom Limits
xlim(ax2, zoom_xlim);
ylim(ax2, zoom_ylim);
daspect(ax2, [1/cosd(54.5) 1 1]);

% Legend on the right side for the categories
legend(ax2, 'show', 'Location', 'eastoutside', 'TextColor', 'k', 'Color', 'none', 'EdgeColor', 'none', 'FontSize', 11);

fprintf('Presentation map complete!\n');


%% Helper functions
% =========================================================================
% HELPER FUNCTION 
% =========================================================================
function plot_infrastructure(target_ax, CleanRoads, CleanRivers)
    % --- RIVERS BY STRAHLER ORDER (Darker gradient for white canvas) ---
    strahler_colors = [
        0.6 0.8 1.0;  % Order 1 (Soft blue)
        0.4 0.7 1.0;  % Order 2
        0.2 0.5 0.9;  % Order 3
        0.0 0.4 0.8;  % Order 4
        0.0 0.2 0.6   % Order 5+ (Deep blue)
    ];

    for s = 1:5
        if s < 5
            idx = find([CleanRivers.Strahler] == s);
            name = sprintf('Stream Order %d', s);
            lw = 0.3 + (s * 0.2);
        else
            idx = find([CleanRivers.Strahler] >= 5);
            name = 'Major Rivers (5+)';
            lw = 1.8;
        end
        if isempty(idx), continue; end
        
        lats = {CleanRivers(idx).Lat}'; lons = {CleanRivers(idx).Lon}';
        lp = cellfun(@(x) [x(:); NaN], lats, 'UniformOutput', false);
        lo = cellfun(@(x) [x(:); NaN], lons, 'UniformOutput', false);
        
        plot(target_ax, cell2mat(lo), cell2mat(lp), 'Color', strahler_colors(s,:), ...
            'LineWidth', lw, 'DisplayName', name);
    end

    % --- ROADS & RAILWAYS (High-contrast presentation colors) ---
    % 1. RAILWAYS (Dark Crimson/Magenta Dashed)
    plot_group(target_ax, CleanRoads, ["CL_RAIL", "RL_TUNNEL", "UNSHOWN_RL"], [0.6 0.0 0.4], 1.2, 'Railways', '--');
    % 2. MINOR / LOCAL (Very Light Grey - behaves as background texture)
    plot_group(target_ax, CleanRoads, ["<4M_TARRED", "<4M_T_OVER", "CL_MINOR", "CL_M_OVER"], [0.88 0.88 0.88], 0.4, 'Minor/Local', '-');
    % 3. B-CLASS (Muted Gold/Dark Yellow)
    plot_group(target_ax, CleanRoads, ["B_CLASS"], [0.75 0.6 0.0], 0.8, 'B-Roads', '-');
    % 4. A-CLASS (Bright Structural Orange)
    plot_group(target_ax, CleanRoads, ["A_CLASS"], [1.0 0.5 0.0], 1.2, 'A-Roads', '-');
    % 5. HIGH SPEED (Deep Crimson Red)
    plot_group(target_ax, CleanRoads, ["MOTORWAY", "DUAL_CARR"], [0.85 0.0 0.0], 2.0, 'Motorway/Dual', '-');
end

% --- SUBPLOT TARGETED HELPERS ---
function plot_group(ax, CleanRoads, target_classes, color, lw, name, style)
    all_classes = [CleanRoads.Class];
    idx = find(ismember(all_classes, target_classes));
    if isempty(idx), return; end
    
    lats = {CleanRoads(idx).Lat}'; lons = {CleanRoads(idx).Lon}';
    lp = cellfun(@(x) [x(:); NaN], lats, 'UniformOutput', false);
    lo = cellfun(@(x) [x(:); NaN], lons, 'UniformOutput', false);
    
    plot(ax, cell2mat(lo), cell2mat(lp), 'Color', color, ...
        'LineWidth', lw, 'LineStyle', style, 'DisplayName', name);
end

end