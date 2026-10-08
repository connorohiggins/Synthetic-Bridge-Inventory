function BridgeDemand = calculate_environmental_demand(BridgeDemand, Coast_Data)
%calculate_environmental_demand Maps structural exposure to airborne chlorides.
%   BridgeDemand = CALCULATE_ENVIRONMENTAL_DEMAND(BridgeDemand, Coast_Data)
%   calculates the Euclidean distance from each theoretical bridge location
%   to the nearest coastal geometry point. It categorises structures into
%   Marine (<1km), Coastal (1-5km), and Inland (>5km) exposure zones to
%   simulate corrosion susceptibility.
%
%   Inputs:
%       BridgeDemand - Struct array containing identified bridge locations.
%       Coast_Data   - N-by-2 matrix of coastal boundary coordinates [Lon, Lat].
%
%   Outputs:
%       BridgeDemand - Updated struct array appending .DistCoast_km and .EnvZone fields.
%
%   See also calculating_scour_risk_02.
% =========================================================================
% SCRIPT: CALCULATE ENVIRONMENTAL DEMAND (DISTANCE TO COAST)
% =========================================================================
% Inputs: 'BridgeDemand', 'Coast_Data'
% Outputs: Updated 'BridgeDemand' with .DistCoast_km and .EnvZone
% =========================================================================

if ~exist('BridgeDemand', 'var') || ~exist('Coast_Data', 'var')
    error('Required variables BridgeDemand/Coast_Data missing.');
end

fprintf('Calculating Environmental Exposure (Distance to Coast)...\n');

% --- CONFIGURATION ---
% Approximation for NI (Lat 54.5)
deg_to_km_lat = 111.0; 
deg_to_km_lon = 111.0 * cosd(54.5); 

% Prepare Coast Vectors (Col 1 = Lon, Col 2 = Lat based on your screenshot)
C_Lon = Coast_Data(:, 1);
C_Lat = Coast_Data(:, 2);

% Pre-allocate for speed
num_bridges = length(BridgeDemand);
fprintf('  - Processing %d bridges against %d coastal points...\n', ...
    num_bridges, length(C_Lat));

% --- CALCULATION LOOP ---
% (Using a Batched Approach to avoid memory overload)

% Progress bar settings
batch_size = 1000;
num_batches = ceil(num_bridges / batch_size);

for b = 1:num_batches
    % Define Batch Range
    start_idx = (b-1)*batch_size + 1;
    end_idx = min(b*batch_size, num_bridges);
    
    % Extract Bridge Coordinates for this batch
    B_Lat = [BridgeDemand(start_idx:end_idx).Lat]';
    B_Lon = [BridgeDemand(start_idx:end_idx).Lon]';
    
    % We process one by one within the batch (vectorized against coast)
    for i = 1:length(B_Lat)
        b_ptr = start_idx + i - 1;
        
        % Calculate Euclidean Distance to ALL coast points (Degrees)
        % D = sqrt( dx^2 + dy^2 )
        d_lat_km = (C_Lat - B_Lat(i)) * deg_to_km_lat;
        d_lon_km = (C_Lon - B_Lon(i)) * deg_to_km_lon;
        
        dist_km_sq = d_lat_km.^2 + d_lon_km.^2;
        min_dist_km = sqrt(min(dist_km_sq));
        
        % Store Result
        BridgeDemand(b_ptr).DistCoast_km = round(min_dist_km, 2);
        
        % Assign Zone
        if min_dist_km <= 1.0
            BridgeDemand(b_ptr).EnvZone = "Marine (<1km)";
        elseif min_dist_km <= 5.0
            BridgeDemand(b_ptr).EnvZone = "Coastal (1-5km)";
        else
            BridgeDemand(b_ptr).EnvZone = "Inland (>5km)";
        end
    end
    
    if mod(b, 5) == 0
        fprintf('    Batch %d / %d complete.\n', b, num_batches);
    end
end

fprintf('Environmental Classification Complete.\n');
fprintf('Zone Distribution:\n');
tabulate([BridgeDemand.EnvZone]);

end