%% 3-tick binned iHP-mPFC theta coherence aligned to UE direction
% Output:
%   T_bin        : each row = one 3-tick bin
%   cohMat       : trial x direction(0:359), value = theta coherence
%   countMat     : trial x direction(0:359), number of bins contributing
%
% Note:
%   3 UE ticks ~= 0.099 sec if UE frame rate is 0.033 sec.
%   This is very short for estimating 3-13 Hz coherence.

clear; clc; close all;

%% ===================== ROOT =====================
ROOT.behav   = 'D:\1. Behavioral data\results\behavior\15-May-2024';
ROOT.session = 'D:\2. Neural data\raw data\session_info.mat';
ROOT.bump    = 'D:\2. Neural data\raw data\innerCircle_first_bump_results.mat';
ROOT.rawLFP  = 'D:\2. Neural data\raw data';
ROOT.bestTT  = 'D:\2. Neural data\Analysis\2.LFP_filtering_PSD\2.1.bestTT\2025-11-26\theta_TT.mat';
ROOT.save    = 'D:\2. Neural data\Analysis\theta_coherence_3tick_by_direction';
ROOT.toolbox = 'D:\toolbox';

if exist(ROOT.toolbox, 'dir')
    addpath(genpath(ROOT.toolbox));
end

if ~exist(ROOT.save, 'dir')
    mkdir(ROOT.save);
end

%% ===================== User setting =====================
rat = '817';
ss  = '7';

ss_num = str2double(ss);
ss1 = sprintf('%d', ss_num);     % folder uses rat774-7
ss2 = sprintf('%02d', ss_num);   % behaviour file uses 774-07.mat
key = sprintf('r%s_%d', rat, ss_num);

binTick = 3;                     % 3 UE ticks per bin
dirBins = 0:359;                 % x-axis direction bins

%% ===================== Chronux parameters =====================
PARAM.Fs       = 2000;
PARAM.fpass    = [3 13];
PARAM.tapers   = [3 5];
PARAM.err      = [0 0];
PARAM.trialave = 0;

params.Fs       = PARAM.Fs;
params.fpass    = PARAM.fpass;
params.tapers   = PARAM.tapers;
params.err      = PARAM.err;
params.trialave = PARAM.trialave;

%% ===================== Load data =====================
load(ROOT.session, 'session_list');

B = load(fullfile(ROOT.behav, [rat '-' ss2 '.mat']), ...
    'cheetah', 'ue', 'ue_t');

K = load(ROOT.bump, 'T_bump');
T = load(ROOT.bestTT, 'theta_TT');

cheetah  = B.cheetah;
ue       = B.ue;
ue_t     = B.ue_t;
T_bump   = K.T_bump;
theta_TT = T.theta_TT;

TT = theta_TT.(key);

cheetah_tick    = cheetah.tick;
trial_start_row = ue_t.trial_start;
trial_end_row = ue_t.rewardzone_arrival;
valid_trial     = ue_t.performance_available;

%% ===================== Get UE direction =====================
% Try to detect direction column automatically.
% If this fails, manually set direction_col below.

if istable(ue)
    varNames = ue.Properties.VariableNames;

    candidateNames = {'direction', 'ue_direction', 'Direction', ...
                      'head_direction', 'HeadDirection', 'hd', 'HD'};

    direction_col = [];

    for i = 1:length(candidateNames)
        idx = find(strcmp(varNames, candidateNames{i}), 1);
        if ~isempty(idx)
            direction_col = idx;
            break;
        end
    end

    if isempty(direction_col)
        % Fallback based on your previous convention:
        % ue column 8 = head direction / direction
        direction_col = 8;
        fprintf('Direction column name not found. Using ue column %d.\n', direction_col);
    else
        fprintf('Using direction column: %s\n', varNames{direction_col});
    end

    ue_direction_all = ue{:, direction_col};

else
    % Fallback for numeric matrix ue
    direction_col = 8;
    fprintf('ue is numeric. Using ue column %d as direction.\n', direction_col);
    ue_direction_all = ue(:, direction_col);
end

ue_direction_all = double(ue_direction_all);
ue_direction_all = mod(ue_direction_all, 360);

%% ===================== Goal info =====================
idx_ss = session_list.rat == string(rat) & ...
         str2double(string(session_list.ss)) == ss_num;

if any(idx_ss)
    goal_this = string(session_list.goal(find(idx_ss, 1)));
else
    goal_this = missing;
end

%% ===================== LFP files =====================
folder_lfp = fullfile(ROOT.rawLFP, ['LE' rat], ['rat' rat '-' ss1]);

file_iHP = fullfile(folder_lfp, ...
    ['AG' num2str(TT.bestTT_iHP) '_RateReduced_3-300filtered.ncs']);

file_mPFC = fullfile(folder_lfp, ...
    ['AG' num2str(TT.bestTT_mPFC) '_RateReduced_3-300filtered.ncs']);

fprintf('\nLoading iHP:  %s\n', file_iHP);
fprintf('Loading mPFC: %s\n', file_mPFC);

%% ===================== Load iHP NCS =====================
HeaderExtractionFlag = 1;
ExtractionMode       = 1;
ExtractionModeVector = [];
FieldSelectionFlags  = [1 1 1 1 1];

[CSC_iHP.Timestamps, ...
 CSC_iHP.ChannelNumbers, ...
 CSC_iHP.SampleFrequencies, ...
 CSC_iHP.NumberOfValidSamples, ...
 CSC_iHP.eeg, ...
 CSC_iHP.Header] = Nlx2MatCSC( ...
    file_iHP, ...
    FieldSelectionFlags, ...
    HeaderExtractionFlag, ...
    ExtractionMode, ...
    ExtractionModeVector);

CSC_iHP.ADBitVolts = str2double(CSC_iHP.Header{15,1}(13:end));
CSC_iHP.eeg = CSC_iHP.eeg .* CSC_iHP.ADBitVolts;

[iHP_lfp, ts_iHP] = expandCSC(CSC_iHP);

iHP_lfp = iHP_lfp(:);
ts_iHP  = ts_iHP(:);

%% ===================== Load mPFC NCS =====================
[CSC_mPFC.Timestamps, ...
 CSC_mPFC.ChannelNumbers, ...
 CSC_mPFC.SampleFrequencies, ...
 CSC_mPFC.NumberOfValidSamples, ...
 CSC_mPFC.eeg, ...
 CSC_mPFC.Header] = Nlx2MatCSC( ...
    file_mPFC, ...
    FieldSelectionFlags, ...
    HeaderExtractionFlag, ...
    ExtractionMode, ...
    ExtractionModeVector);

CSC_mPFC.ADBitVolts = str2double(CSC_mPFC.Header{15,1}(13:end));
CSC_mPFC.eeg = CSC_mPFC.eeg .* CSC_mPFC.ADBitVolts;

[mPFC_lfp, ts_mPFC] = expandCSC(CSC_mPFC);

mPFC_lfp = mPFC_lfp(:);
ts_mPFC  = ts_mPFC(:);

%% ===================== Select valid first-bump trials =====================
Tb = T_bump(T_bump.rat == string(rat) & T_bump.ss == ss_num, :);

if isempty(Tb)
    error('No T_bump rows for rat %s session %02d', rat, ss_num);
end

keep = false(height(Tb), 1);

for i = 1:height(Tb)
    tr = Tb.trial(i);

    if tr >= 1 && tr <= numel(valid_trial) && valid_trial(tr) == 1
        keep(i) = true;
    end
end

Tb = Tb(keep, :);
Tb = sortrows(Tb, 'trial');

if isempty(Tb)
    error('No valid first-bump trials for rat %s session %02d', rat, ss_num);
end

%% ===================== Output containers =====================
T_bin = table();

trialList = Tb.trial;
nTrial = height(Tb);
nDir   = length(dirBins);

cohMat   = NaN(nTrial, nDir);
countMat = zeros(nTrial, nDir);

%% ===================== Main loop =====================
for k = 1:nTrial

    tr   = Tb.trial(k);
    srow = trial_start_row(tr);
    erow = Tb.hit_frame_global(k);
   
    if isnan(srow) || isnan(erow) || erow <= srow
        continue;
    end

    if erow > numel(cheetah_tick) || erow > numel(ue_direction_all)
        continue;
    end

    fprintf('\nRat %s ss %02d trial %d | rows %d to %d\n', ...
        rat, ss_num, tr, srow, erow);

    rowVec = srow:erow;

    nBin = floor(numel(rowVec) / binTick);

    for b = 1:nBin

        binRows = rowVec((b-1)*binTick + 1 : b*binTick);

        midRow = binRows(2);   % middle tick of 3 ticks

        ue_dir_mid = ue_direction_all(midRow);

        if isnan(ue_dir_mid)
            continue;
        end

        dirDeg = round(mod(ue_dir_mid, 360));

        if dirDeg == 360
            dirDeg = 0;
        end

        dirCol = dirDeg + 1;   % 0 deg -> column 1

        tick_start = cheetah_tick(binRows(1));
        tick_end   = cheetah_tick(binRows(end));

        %% Find LFP indices
        [~, idx_iHP_s]  = min(abs(ts_iHP  - tick_start));
        [~, idx_iHP_e]  = min(abs(ts_iHP  - tick_end));

        [~, idx_mPFC_s] = min(abs(ts_mPFC - tick_start));
        [~, idx_mPFC_e] = min(abs(ts_mPFC - tick_end));

        if idx_iHP_e <= idx_iHP_s || idx_mPFC_e <= idx_mPFC_s
            continue;
        end

        x = iHP_lfp(idx_iHP_s:idx_iHP_e);
        y = mPFC_lfp(idx_mPFC_s:idx_mPFC_e);

        n = min(numel(x), numel(y));

        x = x(1:n);
        y = y(1:n);

        dur_sec = n / PARAM.Fs;

        if n < 10
            continue;
        end

        x = detrend(x);
        y = detrend(y);

        %% Coherence for this 3-tick bin
try
    [C, phi, S12, S1, S2, f] = coherencyc(x, y, params); %#ok<ASGLU>
catch ME
    fprintf(2, 'coherencyc failed: trial %d bin %d | %s\n', tr, b, ME.message);
    continue;
end

% Make sure C and f are column vectors
C = C(:);
f = f(:);

% Remove invalid values
validC = isfinite(C) & isfinite(f);

if ~any(validC)
    fprintf('Skipped: trial %d bin %d | empty or invalid coherence result\n', tr, b);
    continue;
end

C_valid = C(validC);
f_valid = f(validC);

theta_coh_mean = mean(C_valid, 'omitnan');

[theta_coh_peak, idx_peak] = max(C_valid);

if isempty(theta_coh_peak) || isempty(idx_peak) || isnan(theta_coh_peak)
    fprintf('Skipped: trial %d bin %d | no valid coherence peak\n', tr, b);
    continue;
end

theta_peak_freq = f_valid(idx_peak);

        %% Save long-format row
        T_row = table();

        T_row.rat   = string(rat);
        T_row.ss    = ss_num;
        T_row.goal  = goal_this;
        T_row.trial = tr;

        T_row.trial_row_in_matrix = k;
        T_row.bin_in_trial = b;

        T_row.ue_start_row = binRows(1);
        T_row.ue_mid_row   = midRow;
        T_row.ue_end_row   = binRows(end);

        T_row.tick_start = tick_start;
        T_row.tick_end   = tick_end;
        T_row.lfp_duration_sec = dur_sec;

        T_row.ue_direction_mid = ue_dir_mid;
        T_row.direction_bin_deg = dirDeg;

        T_row.theta_coherence_mean = theta_coh_mean;
        T_row.theta_coherence_peak = theta_coh_peak;
        T_row.theta_peak_freq = theta_peak_freq;

        T_bin = [T_bin; T_row]; %#ok<AGROW>

        %% Save into trial x direction matrix
        oldVal = cohMat(k, dirCol);
        oldN   = countMat(k, dirCol);

        if isnan(oldVal)
            cohMat(k, dirCol) = theta_coh_mean;
            countMat(k, dirCol) = 1;
        else
            cohMat(k, dirCol) = (oldVal * oldN + theta_coh_mean) / (oldN + 1);
            countMat(k, dirCol) = oldN + 1;
        end
    end
end

%% ===================== Save results =====================
save_name = sprintf('thetaCoh_3tick_byDirection_r%s_ss%02d.mat', rat, ss_num);
csv_name  = sprintf('thetaCoh_3tick_byDirection_long_r%s_ss%02d.csv', rat, ss_num);

save(fullfile(ROOT.save, save_name), ...
    'T_bin', 'cohMat', 'countMat', 'trialList', 'dirBins', 'PARAM');

writetable(T_bin, fullfile(ROOT.save, csv_name));

fprintf('\nSaved:\n%s\n%s\n', ...
    fullfile(ROOT.save, save_name), ...
    fullfile(ROOT.save, csv_name));

%% ===================== Plot heatmap: trial x direction =====================
fig = figure('Color', 'w', 'Position', [200 200 1200 600]);

imagesc(dirBins, 1:nTrial, cohMat);
set(gca, 'YDir', 'normal');

xlabel('UE direction (deg)');
ylabel('Trial #');
title(sprintf('iHP-mPFC theta coherence | 3-tick bins | Rat %s Session %02d', ...
    rat, ss_num), ...
    'Interpreter', 'none');

cb = colorbar;
ylabel(cb, 'Theta coherence');

xlim([0 359]);
xticks(0:45:360);

yticks(1:nTrial);
yticklabels(string(trialList));

box off;
set(gca, 'FontSize', 12, 'TickDir', 'out');

fig_name = sprintf('thetaCoh_3tick_byDirection_heatmap_r%s_ss%02d.png', rat, ss_num);
exportgraphics(fig, fullfile(ROOT.save, fig_name), 'Resolution', 300);

fprintf('Figure saved:\n%s\n', fullfile(ROOT.save, fig_name));