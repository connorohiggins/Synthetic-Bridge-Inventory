function BridgeDemand = calculate_required_spans(BridgeDemand, CleanRoads, CleanRivers)
%calculate_required_spans Determines the necessary span arrangement for a bridge network.
%   BridgeDemand = CALCULATE_REQUIRED_SPANS(BridgeDemand, CleanRoads, CleanRivers) 
%   evaluates the obstacle width and functional use case for each theoretical 
%   bridge location to calculate the required number of spans.
%
%   The function applies a probabilistic model to river crossings to reflect 
%   historical masonry arch construction limits versus modern clear-span 
%   design trends.
%
%   Inputs:
%       BridgeDemand - Struct array containing identified bridge locations and dimensions.
%       CleanRoads   - Struct array containing the continuous road network geometry.
%       CleanRivers  - Struct array containing hydrological network data and Strahler orders.
%
%   Outputs:
%       BridgeDemand - Updated struct array appending the .ReqSpans field.
%
%   See also get_locations_05, assign_type.

% =========================================================================
% SCRIPT: CALCULATE REQUIRED NUMBER OF SPANS
% =========================================================================
fprintf('Calculating required number of spans for %d nodes...\n', length(BridgeDemand));

for i = 1:length(BridgeDemand)
    use_type = string(BridgeDemand(i).Use);
    req_s = BridgeDemand(i).ReqSpan;  % The length of the bridge
    req_w = BridgeDemand(i).ReqWidth; % The width of the obstacle underneath
    
    % Initialize default
    spans = 1; 
    
    switch use_type
        case "Road_Road"
            lane_obstacle_under = CleanRoads(BridgeDemand(i).RoadCrossedId).Lanes;
            if lane_obstacle_under < 4
                spans = 1; % Rule A: 2-lane road
            else % Rule B: Dual carriageway (needs central pier)
                spans = 2;            
            end
            
         case {"Road_River", "Rail_River"}
            strahler = CleanRivers(BridgeDemand(i).RiverID).Strahler;
            % Apply probabilistic historical vs modern logic
            is_historical = rand() < 0.8; % Set to your probability based on target population
            
            if is_historical
                if strahler > 5
                    historical_limit = 30; % Set based on target population
                    spans = ceil(req_s / historical_limit);
                else
                    % Historical Arch Logic (Shorter spans, more piers)
                    historical_limit = 6.0; % Set based on target population
                    spans = ceil(req_s / historical_limit);
                end
            else
                if strahler > 5
                    historical_limit = 100; % Set based on target population
                    spans = ceil(req_s / historical_limit);
                else
                    % Modern Bridge Logic (Longer clear spans)
                    modern_limit = 30.0; % Set to your optimized modern limit
                    spans = ceil(req_s / modern_limit);
                end
            end
            
        case "Road_Rail"
            % Attempt to clear-span the tracks up to 25m
            if req_s <= 25.0
                spans = 1; % Rule F: Clear span over tracks
            else
                spans = ceil(req_s / 25.0); % Rule G: Spanning a rail yard
            end
    end
    
    % Save back to the database
    BridgeDemand(i).ReqSpans = spans;
end

fprintf('Span calculation complete.\n\n');

end