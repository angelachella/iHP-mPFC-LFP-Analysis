clc; clear; close all;

addpath(genpath(fullfile('D:\toolbox')));

%% Root
ROOT.Mother = 'D:';
ROOT.Raw    = fullfile(ROOT.Mother,'1. Behavioral data');
ROOT.Info   = fullfile(ROOT.Raw,'info');
ROOT.Data   = fullfile(ROOT.Raw,'results','behavior','15-May-2024');

ROOT.Neural = 'D:\2. Neural data\raw data';
ROOT.bump   = [ROOT.Neural '\innerCircle_first_bump_results.mat'];

today_is = char(datetime('today','Format','yyyy-MM-dd'));

ROOT.Load = fullfile(ROOT.Raw,'results','innerCircle_first_bump_outward', '2026-03-25');
ROOT.Save = 'D:\2. Neural data\results\1. theta coherence PC (trial avg)';
if ~exist(ROOT.Save,'dir'), mkdir(ROOT.Save); end

%% Load
load(fullfile(ROOT.bump),'T_bump');
load(fullfile(ROOT.Info,'session_info.mat'),'session_list');
load('D:\2. Neural data\Analysis\2.LFP_filtering_PSD\2.1.bestTT\2025-11-26\theta_TT.mat','theta_TT');

%% Coherence parameters
params.Fs       = 2000;
params.fpass    = [1 20];   % coherence spectrum 계산 범위
params.tapers   = [3 5];
params.trialave = 0;        % single trial 입력이므로 0 권장
params.err      = [2 0.05];
params.pad      = 0;

theta_band = [6 12];

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

        ue  = S.ue;
        ue_t = S.ue_t;
        cheetah_tick = S.cheetah.tick;

        ue_Trialstart = ue_t.trial_start;
        ue_performance_available = ue_t.performance_available;

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

        %% ----------------------------
        % First-bump frame
        %% ----------------------------
        idx_rs = idx_r & (T_bump.ss == ss_now);
        Tb = T_bump(idx_rs, :);

        if isempty(Tb)
            continue;
        end

        %% ----------------------------
        % trial-wise time info
        %% ----------------------------
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

            start_idx = ue_Trialstart(trial_now);
            bump_idx  = Tb.hit_frame_global(it);

            if isempty(start_idx) || isempty(bump_idx) || isnan(start_idx) || isnan(bump_idx)
                continue;
            end
            if bump_idx <= start_idx
                continue;
            end

            if start_idx > numel(cheetah_tick) || bump_idx > numel(cheetah_tick)
                continue;
            end

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

        %% ----------------------------
        % Per-trial coherence using coherencyc
        %% ----------------------------
        for i = 1:size(trial_time,1)

            [~, s1] = min(abs(iHP.ts  - trial_time(i,1)));
            [~, e1] = min(abs(iHP.ts  - trial_time(i,2)));
            [~, s2] = min(abs(mPFC.ts - trial_time(i,1)));
            [~, e2] = min(abs(mPFC.ts - trial_time(i,2)));

            if e1 <= s1 || e2 <= s2
                continue;
            end

            x = iHP.eeg(s1:e1);
            y = mPFC.eeg(s2:e2);

            % 길이 맞추기
            n = min(numel(x), numel(y));
            x = x(1:n);
            y = y(1:n);

            if n < params.Fs
                continue;
            end

            % column vector로 맞추기
            x = x(:);
            y = y(:);

            try
                [C,phi,S12,S1,S2,f,confC,phistd,Cerr] = coherencyc(x, y, params); % x = iHP, y = mPFC 

                theta_idx = f >= theta_band(1) & f <= theta_band(2); %theta_band [6 12]
                if ~any(theta_idx)
                    continue;
                end

                theta_coh = mean(C(theta_idx), 'omitnan');

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
                fprintf('[WARN] coherencyc failed | rat %s ss %d trial %d | %s\n', ...
                    trial_meta.rat{i}, trial_meta.ss(i), trial_meta.trial(i), ME.message);
            end
        end
    end
end

%% Save
save(fullfile(ROOT.Save,'theta_coherence_trial_PC.mat'),'T_out');