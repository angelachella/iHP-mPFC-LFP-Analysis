
function T_out = run_cohgram_firstBump_wideband(ROOT, ss_id, theta_info, T_path, params, frame_dt, target_freqs)

%% Parse session ID
temp = split(ss_id, '_');
rat_str = erase(temp{1}, 'r');
ss_str  = temp{2};

rat = str2double(rat_str);
ss  = str2double(ss_str);
ss_str2 = sprintf('%02d', ss);

%% Load wideband LFP from best TT
[wideband_iHP, wideband_mPFC] = theta_coherence_best_TT(ROOT, rat_str, ss_str, theta_info);

if isempty(wideband_iHP.eeg) || isempty(wideband_mPFC.eeg)
    error('Missing iHP or mPFC wideband LFP.');
end

%% Load behaviour
behav_file = fullfile(ROOT.behav, sprintf('%s-%s.mat', rat_str, ss_str2));
S = load(behav_file, 'ue_t', 'cheetah');

ue_t = S.ue_t;
cheetah = S.cheetah;

tick_timestamp = cheetah.tick;

ue_Trialstart = ue_t{:,1};
ue_performance_available = ue_t{:,8};

%% Filter T_path for this session
T_sub = T_path(T_path.rat == rat & T_path.ss == ss, :);

if isempty(T_sub)
    error('No T_path found for %s.', ss_id);
end

%% Get first bump frame and latency for every trial
[G, rat_g, ss_g, trial_g, goal_g, start_direction_g] = findgroups( ...
    T_sub.rat, ...
    T_sub.ss, ...
    T_sub.trial, ...
    T_sub.goal, ...
    T_sub.start_direction);

nFrames = splitapply(@numel, T_sub.frame_global, G);
first_bump_frame = splitapply(@max, T_sub.frame_global, G);

latency = nFrames * frame_dt;

T_use = table(rat_g, ss_g, trial_g, goal_g, start_direction_g, ...
    nFrames, first_bump_frame, latency, ...
    'VariableNames', {'rat','ss','trial','goal','start_direction', ...
    'nFrames','first_bump_frame','latency'});

T_use = sortrows(T_use, {'rat','ss','trial'});

fprintf('%s: total trials to analyse = %d\n', ss_id, height(T_use));

%% Prepare output
T_out = table();

coh_varnames = strings(1, numel(target_freqs));
for k = 1:numel(target_freqs)
    coh_varnames(k) = sprintf('coh_%dHz', target_freqs(k));
end

%% Trial-wise coherencyc
for i = 1:height(T_use)

    tr = T_use.trial(i);

    if tr > numel(ue_Trialstart)
        continue;
    end

    if ue_performance_available(tr) ~= 1
        continue;
    end

    start_frame = ue_Trialstart(tr);
    bump_frame  = T_use.first_bump_frame(i);

    if isnan(start_frame) || isnan(bump_frame) || bump_frame <= start_frame
        continue;
    end

    tStart = tick_timestamp(start_frame);
    tEnd   = tick_timestamp(bump_frame);

    [~, idxStart_iHP] = min(abs(wideband_iHP.timestamp - tStart));
    [~, idxEnd_iHP]   = min(abs(wideband_iHP.timestamp - tEnd));

    [~, idxStart_mPFC] = min(abs(wideband_mPFC.timestamp - tStart));
    [~, idxEnd_mPFC]   = min(abs(wideband_mPFC.timestamp - tEnd));

    x = wideband_iHP.eeg(idxStart_iHP:idxEnd_iHP);
    y = wideband_mPFC.eeg(idxStart_mPFC:idxEnd_mPFC);

    L = min(length(x), length(y));
    x = x(1:L);
    y = y(1:L);

    lfp_duration = L / params.Fs;

    if lfp_duration < 1
        continue;
    end

    x = detrend(x);
    y = detrend(y);

    try
        [C, phi, S12, S1, S2, f] = coherencyc(x, y, params);

        coh_by_freq = nan(1, numel(target_freqs));

        for k = 1:numel(target_freqs)
            [~, f_idx] = min(abs(f - target_freqs(k))); %각 target f하고 가장 가까운값
            coh_by_freq(k) = C(f_idx);
        end

        theta_phase = angle(mean(exp(1i * phi), 'omitnan'));

        baseRow = table( ...
            rat, ss, tr, ...
            T_use.goal(i), ...
            T_use.start_direction(i), ...
            T_use.latency(i), ...
            lfp_duration, ...
            theta_phase, ...
            theta_info.bestTT_iHP, ...
            theta_info.bestTT_mPFC, ...
            'VariableNames', {'rat','ss','trial','goal','start_direction', ...
            'latency','lfp_duration','theta_phase', ...
            'bestTT_iHP','bestTT_mPFC'});

        cohRow = array2table(coh_by_freq, ...
            'VariableNames', cellstr(coh_varnames));

        newRow = [baseRow cohRow];

        T_out = [T_out; newRow];

    catch ME
        warning('%s trial %d failed: %s', ss_id, tr, ME.message);
        continue;
    end
end

%% Save session output
save(fullfile(ROOT.save, [ss_id '_freqwise_coherencyc_firstBump.mat']), ...
    'T_out', 'T_use', 'params', 'theta_info', 'target_freqs');

writetable(T_out, fullfile(ROOT.save, [ss_id '_freqwise_coherencyc_firstBump.csv']));

fprintf('%s valid trials saved: %d\n', ss_id, height(T_out));

end