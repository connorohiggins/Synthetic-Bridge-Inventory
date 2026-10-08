function BridgeDemand = calculating_scour_risk_02(BridgeDemand, CleanRivers)
%calculating_scour_risk_02 Generates a synthetic hydraulic scour risk index.
%   BridgeDemand = CALCULATING_SCOUR_RISK(BridgeDemand, CleanRivers) 
%   classifies river crossings into High, Medium, or Low scour risk 
%   categories. The classification is derived from three interacting 
%   variables: the presence of intermediate piers (span arrangement), the 
%   hydraulic energy (Strahler stream order), and the river flow angle 
%   (intersection skew).
%
%   Inputs:
%       BridgeDemand - Struct array containing bridge geometries and span requirements.
%       CleanRivers  - Struct array containing hydrological network data and Strahler orders.
%
%   Outputs:
%       BridgeDemand - Updated struct array appending the .ScourRisk field.
%
%   See also CALCULATE_ENVIRONMENTAL_DEMAND, ASSIGNTYPE.

% =========================================================================
% SCRIPT: CALCULATE SCOUR RISK INDEX (Updated Logic)
% =========================================================================
fprintf('Calculating Scour Risk Index for water crossings...\n');

count_high = 0;
count_med  = 0;
count_low  = 0;

for i = 1:length(BridgeDemand)
    % 1. Default for non-water crossings (Road_Road, Road_Rail)
    BridgeDemand(i).ScourRisk = "N/A";
    
    use_type = string(BridgeDemand(i).Use);
    
    if use_type == "Road_River" || use_type == "Rail_River"
        
        req_spans = BridgeDemand(i).ReqSpans;
        skew_angle = BridgeDemand(i).Skew;
             
        % 2. Extract Strahler Order Safely
        r_id = BridgeDemand(i).RiverID;
        strahler = 0;
        if r_id > 0 && r_id <= length(CleanRivers)
            s_val = CleanRivers(r_id).Strahler;
            if ~isempty(s_val) && ~isnan(s_val(1))
                strahler = s_val(1);
            end
        end
        
        % 3. THE SCOUR RISK LOGIC TREE
        % High Risk: Multi-span in major rivers OR severe skew in medium/large rivers
        is_high = (req_spans > 1 && strahler >= 4) || (skew_angle >= 60 && strahler >= 3);
        
        % Medium Risk: Single-span in major rivers OR moderate skew in standard rivers
        is_med  = (req_spans == 1 && strahler >= 4) || ...
                  (skew_angle >= 20 && skew_angle <= 50 && strahler >= 2 && strahler <= 3);
        
        % 4. Assign the tags
        if is_high
            BridgeDemand(i).ScourRisk = "High";
            count_high = count_high + 1;
        elseif is_med
            BridgeDemand(i).ScourRisk = "Medium";
            count_med = count_med + 1;
        else
            BridgeDemand(i).ScourRisk = "Low"; % Standard minor crossings
            count_low = count_low + 1;
        end
    end
end

% 5. Print the Summary Distribution
total_water = count_high + count_med + count_low;

fprintf('\n=== SCOUR RISK INDEX SUMMARY ===\n');
fprintf('Total Water Crossings Evaluated: %d\n', total_water);
fprintf('High Risk:   %5d  (%5.1f%%)\n', count_high, (count_high/total_water)*100);
fprintf('Medium Risk: %5d  (%5.1f%%)\n', count_med, (count_med/total_water)*100);
fprintf('Low Risk:    %5d  (%5.1f%%)\n', count_low, (count_low/total_water)*100);
fprintf('================================\n\n');

end