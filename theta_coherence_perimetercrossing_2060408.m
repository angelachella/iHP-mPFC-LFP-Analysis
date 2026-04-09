clc; clear; close all;

addpath(genpath(fullfile('D:\toolbox')));

%% Root
ROOT.Mother = 'D:';
ROOT.Raw    = fullfile(ROOT.Mother,'1. Behavioral data');
ROOT.Info   = fullfile(ROOT.Raw,'info');
ROOT.Data   = fullfile(ROOT.Raw,'results','behavior','15-May-2024');

ROOT.Neural = ['D:\2. Neural data\raw data'];   

today_is = char(datetime('today','Format','yyyy-MM-dd'));

ROOT.Load = fullfile(ROOT.Raw,'results','innerCircle_first_bump_outward', '2026-03-25');
ROOT.Save = fullfile(ROOT.Load, 'theta_coherence_innerCircleFirstBump');
if ~exist(ROOT.Save,'dir'), mkdir(ROOT.Save); end

%% Load
load(fullfile(ROOT.Load,'innerCircle_first_bump_results.mat'),'T_bump');
load(fullfile(ROOT.Info,'session_info.mat'),'session_list');
load('D:\2. Neural data\Analysis\2.LFP_filtering_PSD\2.1.bestTT\2025-11-26\theta_TT.mat','theta_TT');

%% Coherence parameters
params.Fs       = 2000;
params.fpass    = [6 12];
params.tapers   = [3 5];
params.trialave = 1;
params.err      = [2 0.05];
params.pad      = 0;

movingwin = [1 0.01];   % [1 sec window, 10 ms step]

%% Output table
T_out = table();

%% Rat loop
rat_list = unique(string(T_bump.rat));

for ir = 1:numel(rat_list)

    rat_now = rat_list(ir);
    idx_r = string(T_bump.rat) == rat_now;
    ss_list = unique(T_bump.ss(idx_r));

    for is = 1:numel(ss_list)

        ss_now = ss_list(is);
        fprintf('Processing rat %s | session %d\n', rat_now, ss_now);

        %% ----------------------------
        % Load behaviour file (2-digit ss)
        %% ----------------------------
        ss_beh = sprintf('%02d', ss_now);
        beh_file = fullfile(ROOT.Data, sprintf('%s-%s.mat', char(rat_now), ss_beh));

        if ~exist(beh_file,'file')
            fprintf('[WARN] Missing behaviour file: %s\n', beh_file);
            continue;
        end

        S = load(beh_file);

        % Expected variables
        ue  = S.ue;
        ue_Trialstart = S.ue_t.trial_start;
        ue_performance_available = S.ue_t.performance_available;
        cheetah_tick = S.cheetah.tick;

        %% ----------------------------
        % theta TT info
        %% ----------------------------
        key = sprintf('r%s_%d', char(rat_now), ss_now);
        if ~isfield(theta_TT, key)
            fprintf('[WARN] Missing theta_TT field: %s\n', key);
            continue;
        end

        theta_info = theta_TT.(key);

        if isempty(theta_info.bestTT_iHP) || isempty(theta_info.bestTT_mPFC)
            fprintf('[WARN] Missing iHP or mPFC TT for %s\n', key);
            continue;
        end

        %% ----------------------------
        % Load LFP files (1-digit ss)
        %% ----------------------------
        ss_lfp = sprintf('%d', ss_now);

        CSC_iHP = fullfile(ROOT.Neural, ['LE' char(rat_now)], ...
            ['rat' char(rat_now) '-' ss_lfp], ...
            ['AG' num2str(theta_info.bestTT_iHP) '_RateReduced_3-300filtered.ncs']);

        CSC_mPFC = fullfile(ROOT.Neural, ['LE' char(rat_now)], ...
            ['rat' char(rat_now) '-' ss_lfp], ...
            ['AG' num2str(theta_info.bestTT_mPFC) '_RateReduced_3-300filtered.ncs']);

        if ~exist(CSC_iHP,'file')
            fprintf('[WARN] Missing iHP file: %s\n', CSC_iHP);
            continue;
        end
        if ~exist(CSC_mPFC,'file')
            fprintf('[WARN] Missing mPFC file: %s\n', CSC_mPFC);
            continue;
        end

        FieldSelectionFlags = [1 1 1 1 1];
        HeaderExtractionFlag = 1;
        ExtractionMode = 1;
        ExtractionModeVector = [];

        % iHP
        CSC = struct();
        [CSC.Timestamps, CSC.ChannelNumbers, CSC.SampleFrequencies, ...
            CSC.NumberOfValidSamples, CSC.eeg, CSC.Header] = ...
            Nlx2MatCSC(CSC_iHP, FieldSelectionFlags, ...
            HeaderExtractionFlag, ExtractionMode, ExtractionModeVector);

        CSC.ADBitVolts = str2double(CSC.Header{15}(13:end));
        CSC.eeg = CSC.eeg .* CSC.ADBitVolts;
        [iHP.eeg, iHP.ts] = expandCSC(CSC);

        % mPFC
        CSC = struct();
        [CSC.Timestamps, CSC.ChannelNumbers, CSC.SampleFrequencies, ...
            CSC.NumberOfValidSamples, CSC.eeg, CSC.Header] = ...
            Nlx2MatCSC(CSC_mPFC, FieldSelectionFlags, ...
            HeaderExtractionFlag, ExtractionMode, ExtractionModeVector);

        CSC.ADBitVolts = str2double(CSC.Header{15}(13:end));
        CSC.eeg = CSC.eeg .* CSC.ADBitVolts;
        [mPFC.eeg, mPFC.ts] = expandCSC(CSC);


        % First-bump frame 
        idx_rs = idx_r & (T_bump.ss == ss_now);
        Tb = T_bump(idx_rs, :); %T_bump: record of the first bump frames

        if isempty(Tb)
            continue;
        end

% trial-wise time info (ue/T_bump --> cheetah --> LFP)
t = 0;

trial_time = [];
trial_meta = struct();

for it = 1:height(Tb)

    trial_now = Tb.trial(it);

    if trial_now > numel(ue_performance_available)
        continue;
    end
    if ue_performance_available(trial_now) ~= 1
        continue;
    end

    start_idx = ue_Trialstart(trial_now); % trial start
    bump_idx  = Tb.hit_frame_global(it);  % the first bump 

    if isempty(start_idx) || isempty(bump_idx) || isnan(start_idx) || isnan(bump_idx)
        continue;
    end
    if bump_idx <= start_idx
        continue;
    end

    % ue index → cheetah.tick
    t_start = cheetah_tick(start_idx);
    t_end   = cheetah_tick(bump_idx);

    if isempty(t_start) || isempty(t_end) || isnan(t_start) || isnan(t_end)
        continue;
    end
    if t_end <= t_start
        continue;
    end

    t = t + 1;

    trial_time(t,1) = t_start;
    trial_time(t,2) = t_end;

    
    trial_meta.rat{t,1} = char(rat_now);
    trial_meta.ss(t,1)  = ss_now;
    trial_meta.trial(t,1) = trial_now;
    trial_meta.start_direction(t,1) = Tb.start_direction(it);
    trial_meta.goal{t,1} = char(Tb.goal(it));
end

% Per-trial coherence
for i = 1:size(trial_time,1)

    % cheetah.tick --> LFP timestamp
    [~, s1] = min(abs(iHP.ts  - trial_time(i,1)));
    [~, e1] = min(abs(iHP.ts  - trial_time(i,2)));
    [~, s2] = min(abs(mPFC.ts - trial_time(i,1)));
    [~, e2] = min(abs(mPFC.ts - trial_time(i,2)));

    if e1 <= s1 || e2 <= s2
        continue;
    end

    x = iHP.eeg(s1:e1);
    y = mPFC.eeg(s2:e2);


    if numel(x) < params.Fs || numel(y) < params.Fs
        continue;
    end

    try
        [Cm,~,~,~,~,tm,fm,confCm,~] = cohgramc(x, y, movingwin, params);

        theta_coh = mean(Cm(:), 'omitnan'); % trial mean coherence

        T_row = table( ...
            string(trial_meta.rat{i}), ...
            trial_meta.ss(i), ...
            trial_meta.trial(i), ...
            trial_meta.start_direction(i), ...
            string(trial_meta.goal{i}), ...
            theta_coh, ...
            'VariableNames', {'rat','ss','trial','start_direction','goal','theta_coherence'});

        T_out = [T_out; T_row];

    catch ME
        fprintf('[WARN] cohgramc failed | rat %s ss %d trial %d | %s\n', ...
            trial_meta.rat{i}, trial_meta.ss(i), trial_meta.trial(i), ME.message);
    end
end
    end % session loop
end % rat loop

%% Save
save(fullfile(ROOT.Save,'theta_coherence_innerCircleFirstBump.mat'),'T_out');




%% plot with idPhi/MVL
clc; clear; close all;

%% Root
ROOT.Mother = 'D:';
ROOT.Raw    = fullfile(ROOT.Mother, '1. Behavioral data');

ROOT.Coh = fullfile(ROOT.Raw, 'results', 'innerCircle_first_bump_outward', ...
    '2026-03-25', 'theta_coherence_innerCircleFirstBump');

ROOT.Load = fullfile(ROOT.Raw, 'results', 'innerCircle_first_bump_outward', ...
    '2026-03-25');

ROOT.Save = fullfile(ROOT.Coh, 'idPhi_MVL_thetaCoherence_scatter','resolution');
if ~exist(ROOT.Save, 'dir')
    mkdir(ROOT.Save);
end

%% Load
load(fullfile(ROOT.Coh, 'theta_coherence_innerCircleFirstBump.mat'), 'T_out');
load(fullfile(ROOT.Load, 'idPhi_MVL_beforeFirstBump', 'idPhi_MVL_beforeFirstBump.mat'), 'T_idPhiMVL');

%% Basic variable formatting
T_out.rat = string(T_out.rat);
T_idPhiMVL.rat = string(T_idPhiMVL.rat);

%% Keep only necessary columns from coherence table
T_coh = T_out(:, {'rat','ss','trial','theta_coherence'});

%% Merge coherence into idPhi/MVL table
T = outerjoin(T_idPhiMVL, T_coh, ...
    'Keys', {'rat','ss','trial'}, ...
    'MergeKeys', true, ...
    'Type', 'left');

%% Remove invalid rows
idx_valid = ~isnan(T.idPhi) & ~isnan(T.MVL) & ~isnan(T.theta_coherence);
T = T(idx_valid, :);

%% Trial type definition
idx_difficult = (strcmpi(string(T.goal), 'West') & T.start_direction == 90) | ...
                (strcmpi(string(T.goal), 'East') & T.start_direction == 270);

idx_easy = (strcmpi(string(T.goal), 'West') & T.start_direction == 270) | ...
           (strcmpi(string(T.goal), 'East') & T.start_direction == 90);

%% Global colour range for consistent comparison
coh_all = T.theta_coherence(~isnan(T.theta_coherence));

% Recommended: percentile-based range
cmin = 0.4;
cmax = 0.7;

%% Rat/session list
rat_list = unique(T.rat);

for ir = 1:numel(rat_list)

    rat_now = rat_list(ir);
    idx_r = T.rat == rat_now;

    ss_list = unique(T.ss(idx_r));

    rat_save_dir = fullfile(ROOT.Save, ['rat_' char(rat_now)]);
    if ~exist(rat_save_dir, 'dir')
        mkdir(rat_save_dir);
    end

    for is = 1:numel(ss_list)

        ss_now = ss_list(is);
        idx_rs = idx_r & (T.ss == ss_now);

        T_rs = T(idx_rs, :);

        if isempty(T_rs)
            continue;
        end

        %% -----------------------------
        % Difficult
        %% -----------------------------
        T_diff = T_rs(idx_difficult(idx_rs), :);

        if ~isempty(T_diff)
            f1 = figure('Color', 'w', 'Position', [100 100 700 550]);

            scatter(T_diff.idPhi, T_diff.MVL, 10, T_diff.theta_coherence, 'filled');
            colormap(flipud(hot));
            c = colorbar;
            c.Label.String = 'Theta coherence';
            c.FontSize = 12;

            caxis([cmin cmax]);

            xlabel('idPhi', 'FontSize', 13);
            ylabel('MVL', 'FontSize', 13);
            title(sprintf('Rat %s | Session %d | Difficult', char(rat_now), ss_now), ...
                'FontSize', 14, 'FontWeight', 'bold');

            xlim([0 8]);
            ylim([min(T.MVL,[],'omitnan') max(T.MVL,[],'omitnan')]);
            xticks(0:1:8);

            set(gca, 'FontSize', 12, 'LineWidth', 1);
            box off;

            exportgraphics(f1, fullfile(rat_save_dir, ...
                sprintf('thetaCoherence_idPhi_MVL_difficult_%s-%02d.png', char(rat_now), ss_now)));
            close(f1);
        end

        %% -----------------------------
        % Easy
        %% -----------------------------
        T_easy = T_rs(idx_easy(idx_rs), :);

        if ~isempty(T_easy)
            f2 = figure('Color', 'w', 'Position', [120 120 700 550]);

            scatter(T_easy.idPhi, T_easy.MVL, 10, T_easy.theta_coherence, 'filled');
            colormap(flipud(hot));
            c = colorbar;
            c.Label.String = 'Theta coherence';
            c.FontSize = 12;

            caxis([cmin cmax]);

            xlabel('idPhi', 'FontSize', 13);
            ylabel('MVL', 'FontSize', 13);
            title(sprintf('Rat %s | Session %d | Easy', char(rat_now), ss_now), ...
                'FontSize', 14, 'FontWeight', 'bold');

            xlim([0 8]);
            ylim([min(T.MVL,[],'omitnan') max(T.MVL,[],'omitnan')]);
            xticks(0:1:8);
            set(gca, 'FontSize', 12, 'LineWidth', 1);
            box off;

            exportgraphics(f2, fullfile(rat_save_dir, ...
                sprintf('thetaCoherence_idPhi_MVL_easy_%s-%02d.png', char(rat_now), ss_now)));
            close(f2);
        end

    end
end



%% Theta coherence across sessions 
clc; clear; close all;

%% Root
ROOT.Mother = 'D:';
ROOT.Raw    = fullfile(ROOT.Mother, '1. Behavioral data');

ROOT.Load = fullfile(ROOT.Raw, 'results', 'innerCircle_first_bump_outward', ...
    '2026-03-25', 'theta_coherence_innerCircleFirstBump');

ROOT.Save = fullfile(ROOT.Load, 'reversal_day_theta_coherence');
if ~exist(ROOT.Save, 'dir')
    mkdir(ROOT.Save);
end

%% Load
load(fullfile(ROOT.Load, 'theta_coherence_innerCircleFirstBump.mat'), 'T_out');

%% Basic formatting
T = T_out;
T.rat  = string(T.rat);
T.goal = string(T.goal);
T = T(T.rat ~= "779", :);

%% Remove invalid rows
idx_valid = ~isnan(T.theta_coherence);
T = T(idx_valid, :);

%% --------------------------------
% Mean theta coherence per session
%% --------------------------------
[G, rat_g, ss_g, goal_g] = findgroups(T.rat, T.ss, T.goal);
mean_coh = splitapply(@(x) mean(x, 'omitnan'), T.theta_coherence, G);
n_trial  = splitapply(@numel, T.theta_coherence, G);

T_sess = table(rat_g, ss_g, goal_g, mean_coh, n_trial, ...
    'VariableNames', {'rat','ss','goal','theta_coherence_mean','n_trial'});

%% --------------------------------
% Define Day from reversal
% First East session = Day 0
%% --------------------------------
T_sess.day_from_reversal = nan(height(T_sess),1);

rat_list = unique(T_sess.rat);

for ir = 1:numel(rat_list)

    rat_now = rat_list(ir);
    idx_r = T_sess.rat == rat_now;

    T_r = T_sess(idx_r, :);
    T_r = sortrows(T_r, 'ss');

    east_idx = find(strcmpi(T_r.goal, 'East'), 1, 'first');

    if isempty(east_idx)
        fprintf('[WARN] Rat %s has no East session. Skipped.\n', char(rat_now));
        continue;
    end

    reversal_ss = T_r.ss(east_idx);

    % Day from reversal: session number relative to first East session
    T_r.day_from_reversal = T_r.ss - reversal_ss;

    T_sess.day_from_reversal(idx_r) = T_r.day_from_reversal;
end

%% Remove rows where reversal could not be defined
T_plot = T_sess(~isnan(T_sess.day_from_reversal), :);

%% --------------------------------
% Plot 1: each rat separately
%% --------------------------------
f1 = figure('Color', 'w', 'Position', [100 100 850 600]);
hold on;

for ir = 1:numel(rat_list)
    rat_now = rat_list(ir);
    idx_r = T_plot.rat == rat_now;

    if sum(idx_r) == 0
        continue;
    end

    T_r = sortrows(T_plot(idx_r,:), 'day_from_reversal');
    plot(T_r.day_from_reversal, T_r.theta_coherence_mean, '-o', ...
        'LineWidth', 1.5, 'MarkerSize', 6);
end

xline(0, '--k', 'LineWidth', 1.2);

xlabel('Day from reversal', 'FontSize', 13);
ylabel('Mean theta coherence', 'FontSize', 13);
title('Session mean theta coherence aligned to reversal', ...
    'FontSize', 14, 'FontWeight', 'bold');

set(gca, 'FontSize', 12, 'LineWidth', 1);
box off;
legend(cellstr(rat_list), 'Location', 'best');
hold off;

saveas(f1, fullfile(ROOT.Save, 'theta_coherence_reversal_eachRat.png'));

histogram(T_out.theta_coherence)
xlabel('theta coherence')
ylabel('trial counts')