function BridgeDemand = assign_type(BridgeDemand)
%assign_type Classifies structural forms for a synthetic bridge inventory.
%   BridgeDemand = ASSIGNTYPE(BridgeDemand) applies deterministic engineering
%   rulesets to assign overarching bridge construction types (e.g., Culvert,
%   Masonry Arch, RC Slab, Viaduct) based on span arrangement and obstacle type.
%
%   Classification is based on empirical thresholds derived from regional
%   infrastructure data, evaluating the individual clear span length between piers.
%
%   Inputs:
%       BridgeDemand - Struct array containing bridge geometries and span requirements.
%
%   Outputs:
%       BridgeDemand - Updated struct array appending the .AssignedType and
%                      .MatchStatus fields.
%
%   See also CALCULATE_REQUIRED_SPANS.

% -------------------------------------------------------------------------
% 2. INITIALIZE MISSING VARIABLES (Safety Check)
% -------------------------------------------------------------------------
% Ensure MatchStatus exists so the loop below doesn't crash
if ~isfield(BridgeDemand, 'MatchStatus')
    for i = 1:length(BridgeDemand)
        BridgeDemand(i).MatchStatus = "Unassigned";
    end
end

% -------------------------------------------------------------------------
% 3. PHASE 2: EMPIRICAL FALLBACK CLASSIFICATION
% -------------------------------------------------------------------------
fprintf('  - Phase 2: Classifying residual demand based on empirical distributions...\n');

count_culvert = 0;
count_arch    = 0;
count_rcslab  = 0;
count_rail    = 0;
count_viaduct = 0;

for i = 1:length(BridgeDemand)
    % Only classify nodes that haven't already been assigned a PEAR asset
    if BridgeDemand(i).MatchStatus ~= "Unassigned"
        continue;
    end

    req_s = BridgeDemand(i).ReqSpan;         % Total length of the crossing
    req_spans = BridgeDemand(i).ReqSpans;    % Number of spans (piers)
    c_use = string(BridgeDemand(i).Use);

    % Calculate the individual clear span length between piers
    % E.g. A 20m total length with 4 spans = 5.0m individual span
    single_span_length = req_s / req_spans;

    % EMPIRICAL RULES
    if c_use == "Road_Rail" || c_use == "Rail_River"
        BridgeDemand(i).AssignedType = "Rail_Bridge";
        count_rail = count_rail + 1;

    elseif c_use == "Road_River"

        % --- 1. MACROSCOPIC OVERRIDE FOR MASSIVE STRUCTURES ---
        if req_s >= 20.0 
            BridgeDemand(i).AssignedType = "Bespoke_Viaduct";
            count_viaduct = count_viaduct + 1;

            % --- 2. EVALUATING BASED ON INDIVIDUAL SPAN LENGTH ---
        elseif single_span_length <= 1.8 && req_spans == 1
            BridgeDemand(i).AssignedType = "Culvert";
            count_culvert = count_culvert + 1;

        elseif single_span_length > 1.8 && single_span_length <= 4.5
            BridgeDemand(i).AssignedType = "Masonry_Arch";
            count_arch = count_arch + 1;

        elseif single_span_length > 4.5 && single_span_length <= 10.0
            BridgeDemand(i).AssignedType = "RC_Slab";
            count_rcslab = count_rcslab + 1;

        else
            BridgeDemand(i).AssignedType = "Bespoke_Viaduct";
            count_viaduct = count_viaduct + 1;
        end

    elseif c_use == "Road_Road"
        % Apply the same macroscopic override to massive highway interchanges
        if req_s >= 20.0
            BridgeDemand(i).AssignedType = "Bespoke_Viaduct";
            count_viaduct = count_viaduct + 1;
        else
            BridgeDemand(i).AssignedType = "RC_Slab";
            count_rcslab = count_rcslab + 1;
        end
    end

    BridgeDemand(i).MatchStatus = "Empirical_Fallback";
end

% -------------------------------------------------------------------------
% 4. RESULTS & VALIDATION OUTPUT
% -------------------------------------------------------------------------
total_bridges = length(BridgeDemand);
total_resid   = count_culvert + count_arch + count_rcslab + count_rail + count_viaduct;

fprintf('\n=== ASSET ALLOCATION & NETWORK COMPOSITION ===\n');
fprintf('Total Demand Nodes Processed: %d\n\n', total_bridges);


fprintf('--- PHASE 2: EMPIRICAL CLASSIFICATION ---\n');
fprintf('Masonry Arches:  %d (%.1f%%) [Empirical Target: ~53%%]\n', count_arch, (count_arch/total_bridges)*100);
fprintf('Culverts:        %d (%.1f%%) [Empirical Target: ~22%%]\n', count_culvert, (count_culvert/total_bridges)*100);
fprintf('R.C. Slab:       %d (%.1f%%) [Empirical Target: ~11%%]\n', count_rcslab, (count_rcslab/total_bridges)*100);
fprintf('Other:           %d (%.1f%%) [Empirical Target: ~14%%]\n', count_rail+count_viaduct, ((count_rail+count_viaduct)/total_bridges)*100);
% fprintf('Bespoke/Viaduct: %d (%.1f%%)\n', count_viaduct, (count_viaduct/total_bridges)*100);
fprintf('==============================================\n');

% -------------------------------------------------------------------------
% USAGE STATISTICS: TOPOLOGICAL CROSSING TYPES
% -------------------------------------------------------------------------
fprintf('\n=== NETWORK USAGE STATISTICS ===\n');

% 1. Extract all 'Use' tags from the database
all_uses = string({BridgeDemand.Use});
total_current_nodes = length(all_uses);

% 2. Find the unique categories dynamically
unique_uses = unique(all_uses);

% 3. Tally and print the results with aligned formatting
for k = 1:length(unique_uses)
    current_use = unique_uses(k);

    % Count how many times this specific use appears
    count_use = sum(all_uses == current_use);

    % Calculate percentage
    pct = (count_use / total_current_nodes) * 100;

    % Print with neat alignment (e.g., "Road_River:     12500  ( 82.5%)")
    fprintf('%-15s %5d  (%5.1f%%)\n', current_use + ":", count_use, pct);
end
fprintf('================================\n');

end