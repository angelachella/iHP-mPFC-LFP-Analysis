clc; clear; close all;

%% Root setting
ROOT.Mother = 'D:';
ROOT.Raw    = [ROOT.Mother '\1. Behavioral data'];
ROOT.Info   = [ROOT.Raw '\info'];
ROOT.Data   = [ROOT.Raw '\results\behavior\15-May-2024\'];
ROOT.Theta  = [ROOT.Mother '\2. Neural data\raw data\'];

today_is = datetime('today'); today_is.Format = 'yyyy-MM-dd';
today_is = char(today_is);

ROOT.Save = [ROOT.Raw '\results\theta_power_analysis\' today_is];
if ~exist(ROOT.Save,'dir'), mkdir(ROOT.Save); end

%% Load files
load([ROOT.Info '\session_info.mat']);  % session_list
load('D:\2. Neural data\Analysis\2.LFP_filtering_PSD\2.1.bestTT\2025-11-26\theta_TT.mat'); % theta_TT
addpath(genpath(fullfile(ROOT.Mother, 'toolbox')));

%% Params
rat_list = {'774','779','780','781','816','817'};

Fs = 2000;
thetaBand = [6 12];

% Welch params (1s window)
win = round(1 * Fs);
if mod(win,2)==1, win = win+1; end
noverlap = round(0.5*win);
nfft = max(2^nextpow2(win), win);

%% Output table (trial-wise): behaviour + theta power
varNames = {'rat','ss','trial','goal','start_direction', ...
            'latency','travel_distance','edge_distance','percent_edge_nav', ...
            'theta_power_iHP','theta_power_mPFC'};

T_out = table( ...
    strings(0,1), nan(0,1), nan(0,1), strings(0,1), nan(0,1), ...
    nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
    nan(0,1), nan(0,1), ...
    'VariableNames', varNames);

%% Loop over rats/sessions
for rr = 1:numel(rat_list)

    rat = string(rat_list{rr});
    SL  = session_list(string(session_list.rat)==rat, :);

    for k = 1:height(SL)

        % session number formatting
        ss_num = SL.ss(k);
        if isstring(ss_num) || ischar(ss_num)
            ss_num = str2double(ss_num);
        end
        ss = num2str(ss_num);

        target  = char(rat + "-" + sprintf('%02d', ss_num));
        behFile = fullfile(ROOT.Data, [target '.mat']);
        if ~exist(behFile,'file')
            fprintf('[SKIP] beh mat not found: %s\n', behFile);
            continue;
        end

        % theta_TT check (expects r###_# format)
        target_ss_id = ['r' char(rat) '_' ss];
        if ~isfield(theta_TT, target_ss_id)
            fprintf('[SKIP] theta_TT missing: %s\n', target_ss_id);
            continue;
        end
        theta_info = theta_TT.(target_ss_id);

        %% ===== load behaviour =====
        load(behFile, 'cheetah','ue_t'); %#ok<NASGU>
        tick_timestamp = cheetah.tick;

        % trial timing & validity
        ue_Trialstart            = ue_t{:,1};
        ue_Trialend              = ue_t{:,3};   % rewardzone_arrival
        ue_performance_available = ue_t{:,8};

        valid = (ue_performance_available == 1) ...
              & ~isnan(ue_Trialstart) & ~isnan(ue_Trialend) ...
              & (ue_Trialend > ue_Trialstart);

        trial_idx = find(valid);
        if isempty(trial_idx)
            fprintf('[SKIP] no valid trials: %s\n', target);
            continue;
        end

        % ===== behaviour columns (as you specified) =====
        % start_direction: keep name-based access (change if your column name differs)
        start_dir_all = ue_t{:,'start_direction'};

        latency_all      = ue_t{:,9};   % latency
        travel_all       = ue_t{:,10};  % travaled_distance
        edge_dist_all    = ue_t{:,11};  % edge_distance
        edge_pct_all     = ue_t{:,12};  % percent_edge_nav

        % valid trials only
        trial_num        = trial_idx;
        start_dir        = start_dir_all(trial_idx);
        latency          = latency_all(trial_idx);
        travel_distance  = travel_all(trial_idx);
        edge_distance    = edge_dist_all(trial_idx);
        percent_edge_nav = edge_pct_all(trial_idx);

        % trial_time for theta computation (cheetah tick in us)
        trial_time = nan(numel(trial_idx),2);
        for ii = 1:numel(trial_idx)
            iTrial = trial_idx(ii);
            trial_time(ii,1) = tick_timestamp(ue_Trialstart(iTrial));
            trial_time(ii,2) = tick_timestamp(ue_Trialend(iTrial));
        end

        % remove any bad time rows (extra safety)
        keep = ~isnan(trial_time(:,1)) & ~isnan(trial_time(:,2)) & (trial_time(:,2) > trial_time(:,1));
        trial_time       = trial_time(keep,:);
        trial_num        = trial_num(keep);
        start_dir        = start_dir(keep);
        latency          = latency(keep);
        travel_distance  = travel_distance(keep);
        edge_distance    = edge_distance(keep);
        percent_edge_nav = percent_edge_nav(keep);

        if isempty(trial_num)
            fprintf('[SKIP] trial_time invalid after keep: %s\n', target);
            continue;
        end

        %% ===== trial-wise theta power =====
        iHPfile = [ROOT.Theta 'LE' char(rat) '\rat' char(rat) '-' ss '\AG' ...
                   num2str(theta_info.bestTT_iHP) '_RateReduced_3-300filtered.ncs'];

        mPFCfile = [ROOT.Theta 'LE' char(rat) '\rat' char(rat) '-' ss '\AG' ...
                    num2str(theta_info.bestTT_mPFC) '_RateReduced_3-300filtered.ncs'];

        theta_iHP_trial  = nan(numel(trial_num),1);
        theta_mPFC_trial = nan(numel(trial_num),1);

        if exist(iHPfile,'file')
            theta_iHP_trial = local_trialThetaPSD(iHPfile, trial_time, Fs, thetaBand, win, noverlap, nfft);
        else
            fprintf('[WARN] iHP ncs not found: %s\n', iHPfile);
        end

        if exist(mPFCfile,'file')
            theta_mPFC_trial = local_trialThetaPSD(mPFCfile, trial_time, Fs, thetaBand, win, noverlap, nfft);
        else
            fprintf('[WARN] mPFC ncs not found: %s\n', mPFCfile);
        end

        %% ===== append to table =====
        goal_str = string(SL.goal(k));
        nAdd = numel(trial_num);

        T_add = table( ...
            repmat(rat, nAdd,1), repmat(ss_num, nAdd,1), trial_num, ...
            repmat(goal_str, nAdd,1), start_dir, ...
            latency, travel_distance, edge_distance, percent_edge_nav, ...
            theta_iHP_trial, theta_mPFC_trial, ...
            'VariableNames', varNames);

        T_out = [T_out; T_add];

        fprintf('[OK] %s trials=%d\n', target, nAdd);
    end
end

%% Save table
save(fullfile(ROOT.Save,'theta_power_behaviour_trial_table.mat'), 'T_out');
writetable(T_out, fullfile(ROOT.Save,'theta_power_behaviour_trial_table.csv'));

%% Scatter + correlation (overall)
makeScatterCorr(T_out.theta_power_iHP,  T_out.edge_distance, 'iHP theta power',  'edge_distance', fullfile(ROOT.Save,'scatter_iHP_edge_distance.png'));
makeScatterCorr(T_out.theta_power_mPFC, T_out.edge_distance, 'mPFC theta power', 'edge_distance', fullfile(ROOT.Save,'scatter_mPFC_edge_distance.png'));

makeScatterCorr(T_out.theta_power_iHP,  T_out.percent_edge_nav, 'iHP theta power',  'percent_edge_nav', fullfile(ROOT.Save,'scatter_iHP_percent_edge_nav.png'));
makeScatterCorr(T_out.theta_power_mPFC, T_out.percent_edge_nav, 'mPFC theta power', 'percent_edge_nav', fullfile(ROOT.Save,'scatter_mPFC_percent_edge_nav.png'));

disp('DONE. Saved table + scatter plots.');

%% ===== local functions =====

function thetaP_trial = local_trialThetaPSD(ncsFile, trial_time, Fs, thetaBand, win, noverlap, nfft)
% trial_time: [nTrial x 2] (start, end) in same units as CSC ts (after expandCSC)

FieldSelectionFlags = [1 1 1 1 1];
HeaderExtractionFlag = 1;
ExtractionMode = 1;
ExtractionModeVector = [];

[CSC.Timestamps, CSC.ChannelNumbers, CSC.SampleFrequencies, CSC.NumberOfValidSamples, CSC.eeg, CSC.Header] = ...
    Nlx2MatCSC(ncsFile, FieldSelectionFlags, HeaderExtractionFlag, ExtractionMode, ExtractionModeVector);

ADBitVolts = str2double(CSC.Header{15,1}(13:end));
CSC.eeg = CSC.eeg .* ADBitVolts;

[lfp, ts] = expandCSC(CSC);

nT = size(trial_time,1);
thetaP_trial = nan(nT,1);

for i = 1:nT
    [~, s] = min(abs(ts - trial_time(i,1)));
    [~, e] = min(abs(ts - trial_time(i,2)));
    if e <= s, continue; end

    x = double(lfp(s:e));
    x = x - mean(x,'omitnan');

    [Pxx, f] = pwelch(x, win, noverlap, nfft, Fs);
    thetaP_trial(i) = bandpower(Pxx, f, thetaBand, 'psd');
end
end

function makeScatterCorr(x, y, xlab, ylab, savePath)
keep = ~isnan(x) & ~isnan(y);
x = x(keep); y = y(keep);

f = figure('Position',[100,100,450,380]);
scatter(x, y, 18, 'filled'); grid on;
xlabel(xlab); ylabel(ylab);

if numel(x) >= 3
    [r,p] = corr(x, y, 'Type','Pearson');
    title(sprintf('Pearson r = %.3f, p = %.3g, n = %d', r, p, numel(x)));
else
    title(sprintf('n too small (n=%d)', numel(x)));
end

exportgraphics(f, savePath, 'Resolution', 300);
close(f);
end