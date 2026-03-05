clc; clear; close all;

%% Root setting
ROOT.Mother = 'D:';
ROOT.Raw    = fullfile(ROOT.Mother,'1. Behavioral data');
ROOT.Info   = fullfile(ROOT.Raw,'info');
ROOT.Data   = fullfile(ROOT.Raw,'results','behavior','15-May-2024');
ROOT.Theta  = fullfile(ROOT.Mother,'2. Neural data','raw data');

today_is = datetime('today'); today_is.Format = 'yyyy-MM-dd';
ROOT.Save = fullfile(ROOT.Raw,'results','theta_power_analysis', char(today_is));
if ~exist(ROOT.Save,'dir'), mkdir(ROOT.Save); end

%% Load files
load(fullfile(ROOT.Info,'session_info.mat'));  % session_list
load('D:\2. Neural data\Analysis\2.LFP_filtering_PSD\2.1.bestTT\2025-11-26\theta_TT.mat'); % theta_TT
addpath(genpath(fullfile(ROOT.Mother, 'toolbox'))); % circ_r 포함

%% Params
rat_list = {'774','779','780','781','816','817'};

params.Fs = 2000;
thetaBand = [6 12];

% Welch
win   = round(1 * params.Fs);          % 1s
if mod(win,2)==1, win = win+1; end
noverlap = round(0.5*win);
nfft = max(2^nextpow2(win), win);

%% Output table (trial-wise)
T_out = table( ...
    strings(0,1), nan(0,1), nan(0,1), ...                 % rat, ss, trial
    strings(0,1), nan(0,1), ...                           % goal, start_direction
    nan(0,1), nan(0,1), ...                               % theta_iHP, theta_mPFC
    nan(0,1), nan(0,1), ...                               % travel_distance, latency
    nan(0,1), ...                                         % mean_vector_length (R)
    'VariableNames', {'rat','ss','trial','goal','start_direction', ...
                      'theta_power_iHP','theta_power_mPFC', ...
                      'travel_distance','latency','mean_vector_length'} );

%% Loop
for rr = 1:numel(rat_list)

    rat = string(rat_list{rr});
    SL  = session_list(string(session_list.rat)==rat, :);

    for k = 1:height(SL)

        %% --- session id
        ss_num = SL.ss(k);
        if isstring(ss_num) || ischar(ss_num), ss_num = str2double(ss_num); end
        ss = num2str(ss_num);

        target  = char(rat + "-" + sprintf('%02d', ss_num));
        behFile = fullfile(ROOT.Data, [target '.mat']);
        if ~exist(behFile,'file')
            fprintf('[SKIP] beh mat not found: %s\n', behFile);
            continue;
        end

        %% --- theta_TT check
        target_ss_id = ['r' char(rat) '_' ss];
        if ~isfield(theta_TT, target_ss_id)
            fprintf('[SKIP] theta_TT missing: %s\n', target_ss_id);
            continue;
        end
        theta_info = theta_TT.(target_ss_id);

        %% ===== load behaviour mat =====
        load(behFile, 'cheetah','ue_t','encoder'); %#ok<NASGU>
        tick_timestamp = cheetah.tick;

        ue_Trialstart            = ue_t{:,1};
        ue_Trialend              = ue_t{:,3};   % rewardzone_arrival
        ue_performance_available = ue_t{:,8};

        NumberofTrial = numel(ue_Trialstart);

        % travel distance / start direction (네 데이터 구조가 섞여있을 수 있어서 안전하게)
        travel_dist_all = getUETCol(ue_t, "travaled_distance", "travaled distance");
        start_dir_all   = getUETCol(ue_t, "start_direction",  "start_direction");

        %% ===== CSV에서 trial별 mean vector length(R) 계산 (네 방식 그대로) =====
        % csv: LE###_Post-main_#.csv
        csvFile = fullfile(ROOT.Info, ['LE' char(rat)], ...
            ['LE' char(rat) '_Post-main_' num2str(ss_num) '.csv']);

        R_byTrial = nan(NumberofTrial,1); % trial index 기반으로 저장 (1..NumberofTrial)

        if exist(csvFile,'file')
            R_byTrial = computeR_byTrial_fromCSV(csvFile, NumberofTrial);
        else
            fprintf('[WARN] CSV not found (R will be NaN): %s\n', csvFile);
        end

        %% ---- valid trial selection (성공 trial만) ----
        valid = (ue_performance_available == 1);
        valid = valid & ~isnan(ue_Trialstart) & ~isnan(ue_Trialend);

        trial_idx = find(valid);
        if isempty(trial_idx)
            fprintf('[SKIP] no valid trials: %s\n', target);
            continue;
        end

        %% ---- trial_time 만들기 (valid trial만) ----
        trial_time = nan(numel(trial_idx),2);
        trial_num  = nan(numel(trial_idx),1);
        latency_s  = nan(numel(trial_idx),1);
        start_dir  = nan(numel(trial_idx),1);
        travel_dst = nan(numel(trial_idx),1);

        for ii = 1:numel(trial_idx)
            iTrial = trial_idx(ii);

            tStart = tick_timestamp(ue_Trialstart(iTrial));
            tEnd   = tick_timestamp(ue_Trialend(iTrial));
            if tEnd <= tStart, continue; end

            trial_time(ii,1) = tStart;
            trial_time(ii,2) = tEnd;
            trial_num(ii)    = iTrial;

            % latency (s): tick이 us라 가정
            latency_s(ii) = (tEnd - tStart) / 1e6;

            start_dir(ii)  = start_dir_all(iTrial);
            travel_dst(ii) = travel_dist_all(iTrial);
        end

        keep = ~isnan(trial_time(:,1)) & ~isnan(trial_time(:,2)) & (trial_time(:,2) > trial_time(:,1));
        trial_time = trial_time(keep,:);
        trial_num  = trial_num(keep);
        latency_s  = latency_s(keep);
        start_dir  = start_dir(keep);
        travel_dst = travel_dst(keep);

        if isempty(trial_num)
            fprintf('[SKIP] trial_time invalid after keep: %s\n', target);
            continue;
        end

        %% ===== trial-wise theta power =====
        iHPfile = fullfile(ROOT.Theta, ['LE' char(rat)], ['rat' char(rat) '-' ss], ...
                   ['AG' num2str(theta_info.bestTT_iHP) '_RateReduced_3-300filtered.ncs']);
        mPFCfile = fullfile(ROOT.Theta, ['LE' char(rat)], ['rat' char(rat) '-' ss], ...
                   ['AG' num2str(theta_info.bestTT_mPFC) '_RateReduced_3-300filtered.ncs']);

        theta_iHP_trial  = nan(numel(trial_num),1);
        theta_mPFC_trial = nan(numel(trial_num),1);

        if exist(iHPfile,'file')
            theta_iHP_trial = local_trialThetaPSD(iHPfile, trial_time, params.Fs, thetaBand, win, noverlap, nfft);
        else
            fprintf('[WARN] iHP ncs not found: %s\n', iHPfile);
        end

        if exist(mPFCfile,'file')
            theta_mPFC_trial = local_trialThetaPSD(mPFCfile, trial_time, params.Fs, thetaBand, win, noverlap, nfft);
        else
            fprintf('[WARN] mPFC ncs not found: %s\n', mPFCfile);
        end

        %% ===== trial-wise mean vector length (R) 매칭 =====
        R_trial = nan(numel(trial_num),1);
        for ii = 1:numel(trial_num)
            tr = trial_num(ii);
            if tr >= 1 && tr <= numel(R_byTrial)
                R_trial(ii) = R_byTrial(tr);
            end
        end

        %% ===== append to table =====
        goal_str = string(SL.goal(k));

        % shape 강제(테이블 에러 방지)
        trial_num        = trial_num(:);
        latency_s        = latency_s(:);
        start_dir        = start_dir(:);
        travel_dst       = travel_dst(:);
        theta_iHP_trial  = theta_iHP_trial(:);
        theta_mPFC_trial = theta_mPFC_trial(:);
        R_trial          = R_trial(:);

        nAdd = numel(trial_num);
        rat_col  = repmat(rat,     [nAdd 1]);
        ss_col   = repmat(ss_num,  [nAdd 1]);
        goal_col = repmat(goal_str,[nAdd 1]);

        % 안전장치: 길이 불일치 방지
        minN = min([numel(trial_num), numel(latency_s), numel(start_dir), numel(travel_dst), ...
                    numel(theta_iHP_trial), numel(theta_mPFC_trial), numel(R_trial)]);
        if minN < nAdd
            trial_num        = trial_num(1:minN);
            latency_s        = latency_s(1:minN);
            start_dir        = start_dir(1:minN);
            travel_dst       = travel_dst(1:minN);
            theta_iHP_trial  = theta_iHP_trial(1:minN);
            theta_mPFC_trial = theta_mPFC_trial(1:minN);
            R_trial          = R_trial(1:minN);
            rat_col          = rat_col(1:minN);
            ss_col           = ss_col(1:minN);
            goal_col         = goal_col(1:minN);
            nAdd = minN;
        end

        T_add = table( ...
            rat_col, ss_col, trial_num, ...
            goal_col, start_dir, ...
            theta_iHP_trial, theta_mPFC_trial, ...
            travel_dst, latency_s, ...
            R_trial, ...
            'VariableNames', T_out.Properties.VariableNames);

        T_out = [T_out; T_add];

        fprintf('[OK] %s trials=%d (R from CSV)\n', target, nAdd);
    end
end

%% Save table
save(fullfile(ROOT.Save,'theta_power_trial_table_with_R.mat'), 'T_out');
writetable(T_out, fullfile(ROOT.Save,'theta_power_trial_table_with_R.csv'));

%% Scatter: R vs theta power
% 원하는 조건
goal_sel = "east";
sd_sel   = 270;

idx = (lower(string(T_out.goal)) == goal_sel) & (T_out.start_direction == sd_sel);

Tf = T_out(idx, :);   % 필터된 trial들만

% % 예: iHP theta vs travel_distance
% makeScatterCorr(Tf.travel_distance, Tf.mean_vector_length, ...
%     "travel distance(m)", "Mean Vector Length", ...
%     fullfile(ROOT.Save, "scatter_iHP_mvlvstravel_east_sd270.png"));

makeScatterCorr(Tf.theta_power_mPFC, Tf.mean_vector_length, ...
    "mPFC theta power", "Mean Vector Length", ...
    fullfile(ROOT.Save, "scatter_mPFC_mvl_east_sd270.png"));

hist(Tf.mean_vector_length);
xlabel('MVL');
ylabel('trials');
%% ===================== functions =====================

function col = getUETCol(ue_t, name1, name2)
% ue_t에서 컬럼 안전하게 가져오기:
%  - 먼저 ue_t.(name1) 시도 (underscore 형태)
%  - 실패하면 ue_t{:,'name2'} 시도 (공백 포함 이름)
%  - 둘 다 실패하면 NaN 벡터
n = height(ue_t);
col = nan(n,1);

try
    if istable(ue_t) && any(strcmp(ue_t.Properties.VariableNames, char(name1)))
        col = ue_t.(char(name1));
        col = col(:);
        return;
    end
end

try
    if istable(ue_t) && any(strcmp(ue_t.Properties.VariableNames, char(name2)))
        col = ue_t{:, char(name2)};
        col = col(:);
        return;
    end
end
end

function R_byTrial = computeR_byTrial_fromCSV(csvFile, NumberofTrial)
% 네가 쓰던 로직 그대로:
% - ue_trial == tr & ue_rza==0 (rewardzone arrival 전 navigation)
% - NaN hd 제거
% - velocity(cm/s) 계산 (0.6/9500 스케일, 30Hz)
% - 5 frame 연속 >= 5 cm/s인 running 프레임만 선택
% - th = deg2rad(mod(hd,360)); R = circ_r(th)

Data = readtable(csvFile);

ue_position = Data{:,1:2};        % x,y
hd          = double(Data{:,7});  % head direction (deg)
ue_trial    = Data{:,4};          % trial index
ue_rza      = Data{:,5};          % rewardzone arrival flag (0: before arrival)

R_byTrial = nan(NumberofTrial,1);

trial_list = unique(ue_trial);
trial_list = trial_list(~isnan(trial_list));

for kk = 1:numel(trial_list)
    tr = trial_list(kk);

    if tr < 1 || tr > NumberofTrial, continue; end

    % navigation 구간만 (rewardzone 도착 전)
    idx_nav = find(ue_trial == tr & ue_rza == 0);

    % head direction NaN 제거
    idx_nav = idx_nav(~isnan(hd(idx_nav)));
    if numel(idx_nav) < 6, continue; end

    % position
    x_temp = ue_position(idx_nav,1);
    y_temp = ue_position(idx_nav,2);

    % velocity (cm/s), dt=1/30
    dist_cm  = sqrt(diff(x_temp).^2 + diff(y_temp).^2) * (0.6/9500) * 100;
    vel_temp = dist_cm * 30;
    vel_frame = [NaN; vel_temp];

    % 5 frame 연속 ≥5 cm/s
    run_mask = false(size(vel_frame));
    for j = 1:numel(vel_frame)-4
        if all(vel_frame(j:j+4) >= 5)
            run_mask(j:j+4) = true;
        end
    end

    running_idx = idx_nav(run_mask);
    if isempty(running_idx), continue; end

    th = deg2rad(mod(hd(running_idx),360));
    R_byTrial(tr) = circ_r(th);
end
end

function thetaP_trial = local_trialThetaPSD(ncsFile, trial_time, Fs, thetaBand, win, noverlap, nfft)

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