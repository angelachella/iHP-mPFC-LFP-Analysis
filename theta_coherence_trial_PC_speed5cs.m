clc; clear; close all;

%% Root
ROOT.Mother = 'D:';
ROOT.Raw    = fullfile(ROOT.Mother,'1. Behavioral data');
ROOT.Info   = fullfile(ROOT.Raw,'info');
ROOT.Data   = fullfile(ROOT.Raw,'results','behavior','15-May-2024');

ROOT.Neural = 'D:\2. Neural data\raw data';
ROOT.bump   = fullfile(ROOT.Neural, 'innerCircle_first_bump_results.mat');

today_is = char(datetime('today','Format','yyyy-MM-dd')); %#ok<NASGU>

ROOT.Load = fullfile(ROOT.Raw,'results','innerCircle_first_bump_outward', '2026-03-25'); %#ok<NASGU>
ROOT.Save = 'D:\2. Neural data\results\1. theta coherence PC (trial avg)\speed filtered_segmentwise';
if ~exist(ROOT.Save,'dir'), mkdir(ROOT.Save); end

addpath(genpath(fullfile('D:\toolbox')));

%% Load
load(ROOT.bump,'T_bump');
load(fullfile(ROOT.Info,'session_info.mat'),'session_list'); %#ok<NASGU>
load('D:\2. Neural data\Analysis\2.LFP_filtering_PSD\2.1.bestTT\2025-11-26\theta_TT.mat','theta_TT');

%% Coherence parameters
params.Fs       = 2000;
params.fpass    = [1 20];
params.tapers   = [3 5];
params.trialave = 0;
params.err      = [2 0.05];
params.pad      = 0;

theta_band  = [6 12];
speed_thr   = 5;    % cm/s
min_run_len = 5;    % remove runs of >= 5 consecutive frames with speed <= 5

% minimum usable segment length for coherencyc
min_seg_sec     = 0.5;                         % adjust if needed
min_seg_samples = round(min_seg_sec * params.Fs);

%% Output table
T_out = table();

%% Rat loop
rat_list = unique(string(T_bump.rat));

for ir = 1:numel(rat_list)

    rat_now = rat_list(ir);
    idx_r   = string(T_bump.rat) == rat_now;
    ss_list = unique(T_bump.ss(idx_r));

    for is = 1:numel(ss_list)

        ss_now = ss_list(is);
        fprintf('\nProcessing rat %s | session %d\n', rat_now, ss_now);

        %% ----------------------------
        % Load behaviour file (2-digit ss)
        %% ----------------------------
        ss_beh   = sprintf('%02d', ss_now);
        beh_file = fullfile(ROOT.Data, sprintf('%s-%s.mat', char(rat_now), ss_beh));

        if ~exist(beh_file,'file')
            fprintf('[WARN] Missing behaviour file: %s\n', beh_file);
            continue;
        end

        S = load(beh_file);

        ue            = S.ue;
        ue_t          = S.ue_t;
        cheetah_tick  = S.cheetah.tick;

        ue_Trialstart = ue_t.trial_start;
        ue_perf       = ue_t.performance_available;

        speed_all     = double(ue.velocity(:));
        cheetah_tick  = double(cheetah_tick(:));

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

        FieldSelectionFlags  = [1 1 1 1 1];
        HeaderExtractionFlag = 1;
        ExtractionMode       = 1;
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
        iHP.ts  = double(iHP.ts(:));
        iHP.eeg = double(iHP.eeg(:));

        % mPFC
        CSC = struct();
        [CSC.Timestamps, CSC.ChannelNumbers, CSC.SampleFrequencies, ...
            CSC.NumberOfValidSamples, CSC.eeg, CSC.Header] = ...
            Nlx2MatCSC(CSC_mPFC, FieldSelectionFlags, ...
            HeaderExtractionFlag, ExtractionMode, ExtractionModeVector);

        CSC.ADBitVolts = str2double(CSC.Header{15}(13:end));
        CSC.eeg = CSC.eeg .* CSC.ADBitVolts;
        [mPFC.eeg, mPFC.ts] = expandCSC(CSC);
        mPFC.ts  = double(mPFC.ts(:));
        mPFC.eeg = double(mPFC.eeg(:));

        %% ----------------------------
        % First-bump table for this session
        %% ----------------------------
        idx_rs = idx_r & (T_bump.ss == ss_now);
        Tb = T_bump(idx_rs, :);

        if isempty(Tb)
            continue;
        end

        %% ----------------------------
        % trial-wise metadata
        %% ----------------------------
        t = 0;
        trial_meta = struct();

        for it = 1:height(Tb)

            trial_now = Tb.trial(it);

            if trial_now > numel(ue_perf)
                continue;
            end
            if ue_perf(trial_now) ~= 1
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
            if start_idx > numel(speed_all) || bump_idx > numel(speed_all)
                continue;
            end

            t = t + 1;

            trial_meta.rat{t,1}             = char(rat_now);
            trial_meta.ss(t,1)              = ss_now;
            trial_meta.trial(t,1)           = trial_now;
            trial_meta.start_direction(t,1) = Tb.start_direction(it);
            trial_meta.goal{t,1}            = char(Tb.goal(it));
            trial_meta.start_idx(t,1)       = start_idx;
            trial_meta.bump_idx(t,1)        = bump_idx;
        end

        %% ----------------------------
        % Per-trial coherence:
        % segment-wise continuous LFP after removing low-speed runs
        %% ----------------------------
        for i = 1:numel(trial_meta.trial)

            start_idx = trial_meta.start_idx(i);
            bump_idx  = trial_meta.bump_idx(i);

            if bump_idx <= start_idx
                continue;
            end
            
            % Extract LFP (trial start - first bump)
            frame_idx = (start_idx:bump_idx)';

            if max(frame_idx) > numel(speed_all) || max(frame_idx) > numel(cheetah_tick)
                continue;
            end

            speed_trial = speed_all(frame_idx); % ue_velocity 
            tick_trial  = cheetah_tick(frame_idx);

            if isempty(speed_trial) || isempty(tick_trial)
                continue;
            end

            speed_trial = speed_trial(:);
            tick_trial  = tick_trial(:);

            % Extract stop frames 
            low_mask = speed_trial <= speed_thr;

            d = diff([false; low_mask; false]);
            run_start = find(d == 1);
            run_end   = find(d == -1) - 1;
            run_len   = run_end - run_start + 1; % the length of stop frames

            remove_mask = false(size(low_mask));

            for irun = 1:numel(run_start)
                if run_len(irun) >= min_run_len
                    remove_mask(run_start(irun):run_end(irun)) = true;
                end
            end

            keep_mask = ~remove_mask;

            % Need at least some kept frames
            if sum(keep_mask) < 2
                continue;
            end

            %% -----------------------------------------
            % Find continuous kept behaviour segments
            %% -----------------------------------------
            d_keep = diff([false; keep_mask; false]);
            keep_start = find(d_keep == 1);
            keep_end   = find(d_keep == -1) - 1;

            if isempty(keep_start)
                continue;
            end

            
            % Segment-wise coherence
           
            theta_coh_sum    = 0;
            theta_weight_sum = 0;
            n_seg_used       = 0;

            for iseg = 1:numel(keep_start)

                seg_frame_start = keep_start(iseg);
                seg_frame_end   = keep_end(iseg);

                if seg_frame_end <= seg_frame_start
                    continue;
                end

                tick_start_seg = tick_trial(seg_frame_start);
                tick_end_seg   = tick_trial(seg_frame_end);

                % continuous LFP within this kept segment
                idx_iHP_seg  = iHP.ts  >= tick_start_seg & iHP.ts  <= tick_end_seg;
                idx_mPFC_seg = mPFC.ts >= tick_start_seg & mPFC.ts <= tick_end_seg;

                x_seg = iHP.eeg(idx_iHP_seg);
                y_seg = mPFC.eeg(idx_mPFC_seg);

                if isempty(x_seg) || isempty(y_seg)
                    continue;
                end

                % match length conservatively
                n = min(numel(x_seg), numel(y_seg));
                x_seg = x_seg(1:n);
                y_seg = y_seg(1:n);

                if n < min_seg_samples
                    continue;
                end

                x_seg = x_seg(:);
                y_seg = y_seg(:);

                try
                    [C,phi,S12,S1,S2,f,confC,phistd,Cerr] = coherencyc(x_seg, y_seg, params); %#ok<ASGLU>

                    theta_idx = f >= theta_band(1) & f <= theta_band(2);
                    if ~any(theta_idx)
                        continue;
                    end

                    theta_coh_seg = mean(C(theta_idx), 'omitnan');

                    if isnan(theta_coh_seg)
                        continue;
                    end

                    % length-weighted average across segments
                    theta_coh_sum    = theta_coh_sum + theta_coh_seg * n;
                    theta_weight_sum = theta_weight_sum + n;
                    n_seg_used       = n_seg_used + 1;

                catch ME
                    fprintf('[WARN] coherencyc failed | rat %s ss %d trial %d seg %d | %s\n', ...
                        trial_meta.rat{i}, trial_meta.ss(i), trial_meta.trial(i), iseg, ME.message);
                end
            end

            if theta_weight_sum == 0
                continue;
            end

            theta_coh_trial = theta_coh_sum / theta_weight_sum;

            T_row = table( ...
                string(trial_meta.rat{i}), ...
                trial_meta.ss(i), ...
                trial_meta.trial(i), ...
                trial_meta.start_direction(i), ...
                string(trial_meta.goal{i}), ...
                theta_coh_trial, ...
                n_seg_used, ...
                theta_weight_sum, ...
                'VariableNames', ...
                {'rat','ss','trial','start_direction','goal','theta_coherence','n_segments_used','n_samples_used'});

            T_out = [T_out; T_row];
        end
    end
end

%% Save
T_out_speedFiltered_segmentwise = T_out;
save(fullfile(ROOT.Save,'theta_coherence_trial_PC_speedFiltered_segmentwise.mat'), ...
    'T_out_speedFiltered_segmentwise');
writetable(T_out_speedFiltered_segmentwise, ...
    fullfile(ROOT.Save,'theta_coherence_trial_PC_speedFiltered_segmentwise.csv'));

fprintf('\nDone.\n');
fprintf('Saved: %s\n', fullfile(ROOT.Save,'theta_coherence_trial_PC_speedFiltered_segmentwise.mat'));
fprintf('Total trials kept: %d\n', height(T_out_speedFiltered_segmentwise));