function BridgeDemand = get_locations_05(CleanRoads, CleanRivers)
%get_locations_05 Identifies bridge locations by intersecting infrastructure networks.
%   BridgeDemand = get_locations_05(CleanRoads, CleanRivers) geometrically 
%   intersects multi-modal GIS layers (road, rail, and river networks) to 
%   detect valid structural crossings.
%
%   The function filters out standard at-grade junctions and generates a 
%   demand database containing the geographical coordinates, calculated 
%   skew angles, and required base widths for each bridge location.
%
%   Inputs:
%       CleanRoads  - Struct array containing road/rail network geometry 
%                     (.Class, .Lat, .Lon, .Lanes).
%       CleanRivers - Struct array containing river network geometry 
%                     (.Type, .Strahler).
%
%   Outputs:
%       BridgeDemand - Struct array containing all detected bridges with 
%                      dimensions and crossing types.
%
%   See also calculate_required_spans, assign_type.
%

if ~exist('CleanRoads', 'var') || ~exist('CleanRivers', 'var')
    error('Required variables CleanRoads/CleanRivers missing.');
end

fprintf('------------------------------------------------------------\n');
fprintf('STARTING MASTER BRIDGE DEMAND CALCULATION\n');
fprintf('------------------------------------------------------------\n');

clear BridgeDemand;
bridge_count = 0;

% --- 1. CONFIGURATION & ENGINEERING ASSUMPTIONS ---

% Geometric correction for Northern Ireland Latitude (approx 54.5N)
ASPECT_RATIO = cosd(54.5); 

% Junction Tolerance (Degrees)
% If an intersection happens within ~2m of a node, it is a Junction/Level Crossing.
TOL_MERGE = 2e-5; 

% A. River Base Widths (Meters) by Strahler Order - FINAL TWEAK
WIDTH_STRAHLER = [
    1.8;   % Raised from 1.2m. With wider variance, this will spread across 0-3m.
    3.0;   % Tweaked from 3.5m to smooth the transition to S3.
    8.0;   
    18.0;  
    35.0;  
    80.0   
];

% B. Road Base Widths (Meters) by Lane Count
% Includes carriageway + shoulders/verges
WIDTH_ROAD = [
    5.0;   % 1 Lane (Minor)
    10.0;  % 2 Lanes (Standard Single)
    15.0;  % 3 Lanes (Wide/Climbing)
    26.0   % 4 Lanes (Dual/Motorway)
];


%% --- PHASE 1: CLASSIFY INFRASTRUCTURE NETWORK ---
fprintf('[1/4] Classifying Infrastructure Network...\n');

AllClasses = [CleanRoads.Class];

% 1. EXCLUSIONS (Do not process these segments)
% 'UNSHOWN_RL': Helper lines that duplicate real rail geometry.
% 'RL_TUNNEL': Underground structures.
% '<4M_TARRED': Confirmed as private farm driveways/lanes.
idx_ignore = ismember(AllClasses, ["UNSHOWN_RL", "RL_TUNNEL", "<4M_TARRED"]);

% 2. RAIL NETWORK
% Include standard rail and unshown/secondary rail links
idx_rail = ismember(AllClasses, ["CL_RAIL", "UNSHOWN_RL"]);

% 3. HIGH SPEED (Source of Flyovers)
% Motorways and Dual Carriageways that might cross other roads.
idx_highspeed = contains(AllClasses, "MOTORWAY") | ...
                contains(AllClasses, "DUAL_CARR");

% 4. STANDARD ROAD NETWORK
% Everything that is valid, not rail, and not ignored.
idx_road = ~idx_rail & ~idx_ignore;

% Create Indices for fast iteration
I_Rail = find(idx_rail);
I_Road = find(idx_road); 
I_HighSpeed = find(idx_highspeed & idx_road);

fprintf('  > Standard Roads: %d segments\n', length(I_Road));
fprintf('  > Rail Lines:     %d segments\n', length(I_Rail));
fprintf('  > High Speed:     %d segments\n', length(I_HighSpeed));
fprintf('  > Ignored:        %d segments\n', sum(idx_ignore));


%% --- PHASE 2: RIVER CROSSINGS (ROAD & RAIL) ---
fprintf('[2/4] Detecting River Crossings...\n');

% Combine Road and Rail to check against rivers in one pass
I_All_Infra = [I_Road, I_Rail]; 

for k = 1:length(I_All_Infra)
    r = I_All_Infra(k);
    
    % Geometry
    rd_lat = CleanRoads(r).Lat; 
    rd_lon = CleanRoads(r).Lon;
    rd_box = [CleanRoads(r).LonLim, CleanRoads(r).LatLim];
    
    % Determine Context
    if ismember(r, I_Rail)
        current_use = "Rail_River";
        req_width = 10; % Standard Rail Corridor Width
    else
        current_use = "Road_River";
        % Clamp lanes 1-4 for width lookup
        lanes = min(max(CleanRoads(r).Lanes, 1), 4);
        req_width = WIDTH_ROAD(lanes);
    end
    
    % Iterate Rivers
    for v = 1:length(CleanRivers)
        % STRICT FILTER: Only 'Y' (Real River Segments)
        if CleanRivers(v).Type ~= "Y", continue; end
        
        % Fast Bounding Box Check
        riv_box = [CleanRivers(v).LonLim, CleanRivers(v).LatLim];
        if rd_box(2)<riv_box(1) || rd_box(1)>riv_box(2) || rd_box(4)<riv_box(3) || rd_box(3)>riv_box(4)
            continue;
        end
        
        % Accurate Intersection Check
        [xi, yi] = polyxpoly(rd_lon, rd_lat, CleanRivers(v).Lon, CleanRivers(v).Lat);
        
        if isempty(xi), continue; end
        
        for p = 1:length(xi)
            bridge_count = bridge_count + 1;
            
            % Calculate Skew and Span using Strahler Order
            [skew, span] = calculate_skew_span(rd_lon, rd_lat, CleanRivers(v).Lon, CleanRivers(v).Lat, ...
                                               xi(p), yi(p), ASPECT_RATIO, CleanRivers(v).Strahler, WIDTH_STRAHLER);

            skew = 90 - skew;
            
            % Store Data
            BridgeDemand(bridge_count).ID = bridge_count;
            BridgeDemand(bridge_count).Lat = yi(p);
            BridgeDemand(bridge_count).Lon = xi(p);
            BridgeDemand(bridge_count).Use = current_use;
            BridgeDemand(bridge_count).RoadID = r;
            BridgeDemand(bridge_count).RiverID = v;
            BridgeDemand(bridge_count).ReqSpan = round(span, 1);
            BridgeDemand(bridge_count).ReqWidth = req_width;
            BridgeDemand(bridge_count).Skew = round(skew, 1);
            BridgeDemand(bridge_count).RoadClass = CleanRoads(r).Class;
            
            % Traffic Inheritance (Only for Roads)
            if isfield(CleanRoads, 'AADT') && ~ismember(r, I_Rail)
                BridgeDemand(bridge_count).AADT = CleanRoads(r).AADT;
                BridgeDemand(bridge_count).HGV = CleanRoads(r).HGV;
            else
                BridgeDemand(bridge_count).AADT = 0;
            end
        end
    end
    
    % Progress Update
    if mod(k, 5000) == 0
        fprintf('   Processed %d infrastructure segments...\n', k); 
    end
end


%% --- PHASE 3: ROAD OVER RAIL ---
diagnostic_count = 0;
RejectedCrossings = struct('Lat', {}, 'Lon', {}, 'RoadID', {}, 'RailID', {});
fprintf('[3/4] Detecting Road over Rail...\n');

for i = 1:length(I_Road)
    r_idx = I_Road(i);
    rd_box = [CleanRoads(r_idx).LonLim, CleanRoads(r_idx).LatLim];
    
    for j = 1:length(I_Rail)
        rl_idx = I_Rail(j);
        rl_box = [CleanRoads(rl_idx).LonLim, CleanRoads(rl_idx).LatLim];
        
        % Box Check
        if rd_box(2)<rl_box(1) || rd_box(1)>rl_box(2) || rd_box(4)<rl_box(3) || rd_box(3)>rl_box(4)
            continue;
        end
        
        [xi, yi] = polyxpoly(CleanRoads(r_idx).Lon, CleanRoads(r_idx).Lat, ...
                             CleanRoads(rl_idx).Lon, CleanRoads(rl_idx).Lat);
                         
        if isempty(xi), continue; end
        
        for p = 1:length(xi)
            % TOPOLOGY CHECK: Avoid Level Crossings
            % If intersection is at a node (endpoint), it's a junction, not a bridge.
            is_junc = check_endpoints(CleanRoads(r_idx), xi(p), yi(p), TOL_MERGE) || ...
                      check_endpoints(CleanRoads(rl_idx), xi(p), yi(p), TOL_MERGE);

           if is_junc
                % --- DIAGNOSTIC CAPTURE ---
                % Instead of silently skipping, save the rejected coordinate
                diagnostic_count = diagnostic_count + 1;
                RejectedCrossings(diagnostic_count).Lat = yi(p);
                RejectedCrossings(diagnostic_count).Lon = xi(p);
                RejectedCrossings(diagnostic_count).RoadID = r_idx;
                RejectedCrossings(diagnostic_count).RailID = rl_idx;
                
                continue; % Still skip adding it to BridgeDemand for now
            end
            
            bridge_count = bridge_count + 1;
            
            % Skew Calculation (Strahler=0 uses default width)
            [skew, ~] = calculate_skew_span(CleanRoads(r_idx).Lon, CleanRoads(r_idx).Lat, ...
                                            CleanRoads(rl_idx).Lon, CleanRoads(rl_idx).Lat, ...
                                            xi(p), yi(p), ASPECT_RATIO, 0, []);

            skew = 90 - skew;
            
            % Span Calculation (Based on Rail Width = 10m)
            span = 10 / sind(skew);
            
            % Store Data
            BridgeDemand(bridge_count).ID = bridge_count;
            BridgeDemand(bridge_count).Lat = yi(p);
            BridgeDemand(bridge_count).Lon = xi(p);
            BridgeDemand(bridge_count).Use = "Road_Rail";
            BridgeDemand(bridge_count).RoadID = r_idx;
            BridgeDemand(bridge_count).RiverID = NaN;
            BridgeDemand(bridge_count).ReqSpan = round(span, 1);
            BridgeDemand(bridge_count).ReqWidth = WIDTH_ROAD(min(max(CleanRoads(r_idx).Lanes,1),4));
            BridgeDemand(bridge_count).Skew = round(skew, 1);
            BridgeDemand(bridge_count).RoadClass = CleanRoads(r_idx).Class;
            
            if isfield(CleanRoads, 'AADT')
                BridgeDemand(bridge_count).AADT = CleanRoads(r_idx).AADT;
                BridgeDemand(bridge_count).HGV = CleanRoads(r_idx).HGV;
            else
                BridgeDemand(bridge_count).AADT = 0;
            end
        end
    end
end


%% --- PHASE 4: ROAD OVER ROAD (FLYOVERS) ---
fprintf('[4/4] Detecting Flyovers (Road over Road)...\n');

for i = 1:length(I_HighSpeed)
    m_idx = I_HighSpeed(i); % MAJOR ROAD (Now the Underpass)
    m_box = [CleanRoads(m_idx).LonLim, CleanRoads(m_idx).LatLim];
    
    for j = 1:length(I_Road)
        % Avoid self-check
        if m_idx == I_Road(j), continue; end 
        
        r_target = I_Road(j); % MINOR ROAD (Now the Overpass / Bridge)
        other_box = [CleanRoads(r_target).LonLim, CleanRoads(r_target).LatLim];
        
        if m_box(2)<other_box(1) || m_box(1)>other_box(2) || m_box(4)<other_box(3) || m_box(3)>other_box(4)
            continue;
        end
        
        [xi, yi] = polyxpoly(CleanRoads(m_idx).Lon, CleanRoads(m_idx).Lat, ...
                             CleanRoads(r_target).Lon, CleanRoads(r_target).Lat);
        
        if isempty(xi), continue; end
        
        for p = 1:length(xi)
            % TOPOLOGY CHECK: Avoid On-Ramps/Roundabouts
            is_junc = check_endpoints(CleanRoads(m_idx), xi(p), yi(p), TOL_MERGE) || ...
                      check_endpoints(CleanRoads(r_target), xi(p), yi(p), TOL_MERGE);
            
            if is_junc, continue; end
            
            bridge_count = bridge_count + 1;
            
            [skew, ~] = calculate_skew_span(CleanRoads(m_idx).Lon, CleanRoads(m_idx).Lat, ...
                                            CleanRoads(r_target).Lon, CleanRoads(r_target).Lat, ...
                                            xi(p), yi(p), ASPECT_RATIO, 0, []);
             
            % --- UPDATED LOGIC START ---
            
            % Span Calculation (Must clear the Major Road Underneath -> m_idx)
            width_under = WIDTH_ROAD(min(max(CleanRoads(m_idx).Lanes, 1), 4));
            span = width_under / sind(skew);
            
            % Store Data (The Bridge is the Minor Road -> r_target)
            BridgeDemand(bridge_count).ID = bridge_count;
            BridgeDemand(bridge_count).Lat = yi(p);
            BridgeDemand(bridge_count).Lon = xi(p);
            BridgeDemand(bridge_count).Use = "Road_Road";
            
            BridgeDemand(bridge_count).RoadID = r_target; % Mapped to Minor Road
            BridgeDemand(bridge_count).RoadCrossedId = m_idx;
            BridgeDemand(bridge_count).RiverID = NaN;
            
            BridgeDemand(bridge_count).ReqSpan = round(span, 1);
            
            % The required deck width is based on the Minor Road
            BridgeDemand(bridge_count).ReqWidth = WIDTH_ROAD(min(max(CleanRoads(r_target).Lanes, 1), 4));
            
            BridgeDemand(bridge_count).Skew = round(skew, 1);
            BridgeDemand(bridge_count).RoadClass = CleanRoads(r_target).Class; % Class of the Overpass
            
            if isfield(CleanRoads, 'AADT')
                % Traffic loading on the bridge comes from the Minor Road
                BridgeDemand(bridge_count).AADT = CleanRoads(r_target).AADT;
                BridgeDemand(bridge_count).HGV = CleanRoads(r_target).HGV; % Fixed typo here
            else
                BridgeDemand(bridge_count).AADT = 0;
                BridgeDemand(bridge_count).HGV = 0;
            end
            
            % --- UPDATED LOGIC END ---
            
        end
    end
end

fprintf('------------------------------------------------------------\n');
fprintf('COMPLETE. Identified %d Total Structures.\n', bridge_count);
fprintf('Breakdown by Type:\n');
tabulate([BridgeDemand.Use]);
fprintf('------------------------------------------------------------\n');


%% ========================================================================
%% LOCAL HELPER FUNCTIONS
%% ========================================================================

function [skew, span] = calculate_skew_span(x1, y1, x2, y2, px, py, ar, strahler, widths)
    % Find which segment indices contain the point P
    idx1 = find_segment_idx(x1, y1, px, py);
    idx2 = find_segment_idx(x2, y2, px, py);
    
    if isempty(idx1) || isempty(idx2)
        skew = 90; span = 10; return; % Fallback
    end
    
    % Vector 1 (Road) - Longitude scaled by Aspect Ratio
    v1y = y1(idx1+1)-y1(idx1); 
    v1x = (x1(idx1+1)-x1(idx1))*ar;
    
    % Vector 2 (Obstacle)
    v2y = y2(idx2+1)-y2(idx2); 
    v2x = (x2(idx2+1)-x2(idx2))*ar;
    
    % Dot Product for Angle
    dot_p = v1x*v2x + v1y*v2y;
    mag1 = sqrt(v1x^2 + v1y^2); 
    mag2 = sqrt(v2x^2 + v2y^2);
    
    if mag1==0 || mag2==0
        angle = 90; 
    else
        angle = rad2deg(acos(abs(dot_p)/(mag1*mag2)));
    end
    
    % Clamp Angle (Prevent infinite span)
    skew = max(15, angle);
    
    % Determine Base Width
    if strahler > 0
        % Use River Lookup Table
        base_nominal = widths(min(strahler, 6));
        
       % NEW TWEAK: +/- 50% variance to flatten the distribution curve
        % 0.50 + (1.0 * rand()) scales this to a multiplier between 0.50 and 1.50
        variance_multiplier = 0.50 + (1.0 * rand()); 
        base = base_nominal * variance_multiplier;
    else
        % Default fallback (e.g. for Rail if not handled externally)
        base = 10; 
    end
    
    span = base / sind(skew);
end

function idx = find_segment_idx(x, y, px, py)
    % Finds the segment index where point (px,py) lies.
    % Uses distance check: dist(A,P) + dist(P,B) == dist(A,B)
    d = abs((sqrt((x(1:end-1)-px).^2 + (y(1:end-1)-py).^2) + ...
             sqrt((x(2:end)-px).^2 + (y(2:end)-py).^2)) - ...
             sqrt((x(1:end-1)-x(2:end)).^2 + (y(1:end-1)-y(2:end)).^2));
    [~, idx] = min(d);
end

function is_end = check_endpoints(Road, px, py, tol)
    % Checks if point (px,py) is close to the start or end of the polyline.
    % Used to filter out junctions (where lines meet at a node).
    dist = sqrt(([Road.Lon(1), Road.Lon(end)] - px).^2 + ...
                ([Road.Lat(1), Road.Lat(end)] - py).^2);
    is_end = any(dist < tol);
end

end