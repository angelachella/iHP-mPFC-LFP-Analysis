
%%
clc;
clear;
close all;

%% Root setting

ROOT.Mother = 'D:';
ROOT.Raw = [ROOT.Mother '\1. Behavioral data'];
ROOT.Info = [ROOT.Raw '\info'];

ROOT.Data = [ROOT.Raw '\results\behavior\15-May-2024\'];  
ROOT.Theta = [ROOT.Mother '\2. Neural data\raw data\']

today_is = datetime('today');
today_is.Format = 'yyyy-MM-dd';
today_is = char(today_is);

ROOT.Save = [ROOT.Raw '\results\theta_power_analysis\' today_is];
if ~exist(ROOT.Save); mkdir(ROOT.Save); end


%% Load files

load([ROOT.Info '\session_info.mat']);
load(['D:\2. Neural data\Analysis\2.LFP_filtering_PSD\2.1.bestTT\2025-11-26\theta_TT.mat']);
addpath(genpath(fullfile(ROOT.Mother, 'toolbox')));

target = '774-04';
temp = split(target, '-');
rat = temp{1};
ss = num2str(str2double(temp{2}));
target_ss_id = ['r' rat '_' ss];
theta_info = theta_TT.(target_ss_id);

load([ROOT.Data target '.mat']);
%% Load files

load([ROOT.Info '\session_info.mat']);
load(['D:\2. Neural data\Analysis\2.LFP_filtering_PSD\2.1.bestTT\2025-11-26\theta_TT.mat']);
load(['D:\1. Behavioral data\results\theta_power_analysis\2026-01-28\\theta_power_session_table_PSD_withITI.mat']);
addpath(genpath(fullfile(ROOT.Mother, 'toolbox')));

% % parameters for PSD calculation

params.Fs = 2000;
global Fs
Fs = params.Fs;   % 2000
params.fpass = [1 50];    % LFP range
params.tapers = [3 5];
params.trialave = 1;
params.err = [2 0.05];
params.pad = 0;

%% ue variables
tick_timestamp = cheetah.tick;
trial_timestamp = cheetah.trial;
cueonset_timestamp = cheetah.cueonset;
HighValue_timestamp = cheetah.highvalue;
LowValue_timestamp = cheetah.lowvalue;
NStart_timestamp = cheetah.northstart;
SStart_timestamp = cheetah.southstart;

ue_timestamp.main = ue{:,1};
ue_time = ue{:,2};
ue_trial.main = ue{:,3};
ue_trial.ITIstart = ue{:,4};
ue_performance_available_frame = ue{:,5};
ue_position.main = ue{:,6:7};
ue_head_direction = ue{:,8};
ue_cumdistance = ue{:,9};
ue_DistancefromRewardzone = ue{:,10};
ue_velocity = ue{:,11};
ue_velocity_smoothing_500ms = ue{:,12};
ue_ang_velocity = ue{:,13};
ue_ang_velocity_smoothing_500ms = ue{:,14};
ue_edge = ue{:,15};
ue_flag = ue{:,16};
ue_FrameofITI = ue{:,17};
ue_reward_zone_arrival = ue{:,18}; % directly from UE log
ue_highvaluezone = ue{:,19}; % directly from UE log

ue_Trialstart = ue_t{:,1};
ue_Trialstart_ITI = ue_t{:,2};
ue_RewardzoneArrival = ue_t{:,3};
ue_Trialend = ue_t{:,4};
ue_Trialend_ITI = ue_t{:,5};
ue_start_direction = ue_t{:,6};
ue_performance = ue_t{:,7};
ue_performance_available = ue_t{:,8};
ue_latency = ue_t{:,9};
ue_traveldistance = ue_t{:,10};
ue_EdgeDistance = ue_t{:,11};
ue_PercentofEdgeNav = ue_t{:,12};
ue_guide_trial = ue_t{:,13};
ue_outlier = ue_t{:,14};
ue_outlier_distance = ue_t{:,15};
ue_outlier_latency = ue_t{:,16};
ue_outlier_latency_scene = ue_t{:,17};

encoder_position = encoder{:,1:2};
encoder_velocity = encoder{:,3};
encoder_velocity_smoothing_500ms = encoder{:,4};
encoder_distance = encoder{:,5};
encoder_degree = encoder{:,6};
encoder_angspeed = encoder{:,7};

NumberofFrame = size(ue_timestamp.main,1);
NumberofTrial = ue_trial.main(NumberofFrame)-1;


%% theta power
theta = [ROOT.Theta 'LE' rat '\rat' rat '-' ss '\AG' num2str(theta_info.bestTT_iHP) '_RateReduced_3-300filtered.ncs'];
    HeaderExtractionFlag = 1;
    ExtractionMode = 1;
    ExtractionModeVector = [];
    FieldSelectionFlags = [1 1 1 1 1];

    [CSCdata.Timestamps, CSCdata.ChannelNumbers, CSCdata.SampleFrequencies, CSCdata.NumberOfValidSamples, ...
        CSCdata.eeg, CSCdata.Header]= Nlx2MatCSC(theta, FieldSelectionFlags, ...
        HeaderExtractionFlag, ExtractionMode, ExtractionModeVector);   

CSCdata.ADBitVolts = str2double(CSCdata.Header{15,1}(13:end));
CSCdata.ADMaxValue = str2double(CSCdata.Header{16,1}(13:end));
CSCdata.eeg = CSCdata.eeg.*CSCdata.ADBitVolts;

    % expand CSC & calcualte theta phase

   [thetaband_iHP.eeg, thetaband_iHP.timestamp] = expandCSC(CSCdata);

% get psd
[psd, f] = getPSD(thetaband_iHP.eeg, params.fpass);


plot(f,10*log10(psd));
ylabel('dB');
xlabel('frequency (Hz)');





%% ===================== Pre/Post theta power plots (West + East) =====================
% Input required:
%   T must contain variables: rat, goal, stage, theta_power
%     - rat: per-session rat ID (string/char/cellstr ok)
%     - goal: "West" or "East"
%     - stage: "Pre" or "Post"
%     - theta_power: numeric
%
% Output:
%   Figure 1: West condition (Pre vs Post) like your example image
%   Figure 2: East condition (Pre vs Post) like your example image

%% --- string normalisation ---
T_out.rat   = string(T_out.rat);
T_out.goal  = string(T_out.goal);
T_out.stage = string(T_out.stage);

rats = unique(T_out.rat);

%% --- collect per-rat means (Pre/Post) for West and East ---
xW = nan(numel(rats),1);  % West-Pre
yW = nan(numel(rats),1);  % West-Post
xE = nan(numel(rats),1);  % East-Pre
yE = nan(numel(rats),1);  % East-Post

for i = 1:numel(rats)
    r = rats(i);

    preW  = T_out.theta_power_mPFC(T_out.rat==r & T_out.goal=="West" & T_out.stage=="Pre");
    postW = T_out.theta_power_mPFC(T_out.rat==r & T_out.goal=="West" & T_out.stage=="Post");
    if ~isempty(preW) && ~isempty(postW)
        xW(i) = mean(preW,'omitnan');
        yW(i) = mean(postW,'omitnan');
    end

    preE  = T_out.theta_power_mPFC(T_out.rat==r & T_out.goal=="East" & T_out.stage=="Pre");
    postE = T_out.theta_power_mPFC(T_out.rat==r & T_out.goal=="East" & T_out.stage=="Post");
    if ~isempty(preE) && ~isempty(postE)
        xE(i) = mean(preE,'omitnan');
        yE(i) = mean(postE,'omitnan');
    end
end

% keep only paired rats per condition
okW = ~isnan(xW) & ~isnan(yW);
okE = ~isnan(xE) & ~isnan(yE);
xW = xW(okW); yW = yW(okW);
xE = xE(okE); yE = yE(okE);

%% --- Wilcoxon signed-rank tests ---
pW = signrank(xW, yW);
pE = signrank(xE, yE);


%% --- Plot West (Pre vs Post) ---
plot_prepost_barpair(xW, yW, pW, "West");

%% --- Plot East (Pre vs Post) ---
plot_prepost_barpair(xE, yE, pE, "East");

% 
% 
% 
% 
%% average difference - Wilcoxon signed rank test (all rats)

T_out.rat   = string(T_out.rat);
T_out.goal  = string(T_out.goal);
T_out.stage = string(T_out.stage);

rats = unique(T_out.rat);

% west
xW = nan(numel(rats),1);  % Pre
yW = nan(numel(rats),1);  % Post

% east
xE = nan(numel(rats),1);
yE = nan(numel(rats),1);

for i = 1:numel(rats)
    r = rats(i);

    % West
    preW  = T_out.theta_power_iHP(T_out.rat==r & T_out.goal=="West" & T_out.stage=="Pre");
    postW = T_out.theta_power_iHP(T_out.rat==r & T_out.goal=="West" & T_out.stage=="Post");

    if ~isempty(preW) && ~isempty(postW)
        xW(i) = mean(preW,'omitnan');
        yW(i) = mean(postW,'omitnan');
    end

    % East
    preE  = T_out.theta_power_iHP(T_out.rat==r & T_out.goal=="East" & T_out.stage=="Pre");
    postE = T_out.theta_power_iHP(T_out.rat==r & T_out.goal=="East" & T_out.stage=="Post");

    if ~isempty(preE) && ~isempty(postE)
        xE(i) = mean(preE,'omitnan');
        yE(i) = mean(postE,'omitnan');
    end
end

% Wilcoxon signed-rank
[pW,~,~] = signrank(xW, yW);
[pE,~,~] = signrank(xE, yE);

dW = yW - xW;
dE = yE - xE;

mW  = mean(dW,'omitnan');
mE  = mean(dE,'omitnan');

semW = std(dW,'omitnan') / sqrt(numel(dW));
semE = std(dE,'omitnan') / sqrt(numel(dE));

figure; hold on; box off;

% x 위치
xPos = [1 2];

% ---- 막대 ----
bar(xPos(1), mW, 0.6, 'FaceColor',[0.7 0.7 0.7]);
bar(xPos(2), mE, 0.6, 'FaceColor',[0.7 0.7 0.7]);

% ---- SEM ----
errorbar(xPos(1), mW, semW, 'k', 'LineStyle','none', 'LineWidth',1);
errorbar(xPos(2), mE, semE, 'k', 'LineStyle','none', 'LineWidth',1);

j = 0.08;
xWj = xPos(1) + (rand(size(dW))-0.5)*2*j;
xEj = xPos(2) + (rand(size(dE))-0.5)*2*j;

scatter(xWj, dW, 60, 'k', 'filled');
scatter(xEj, dE, 60, 'k', 'filled');

% % rat별 선으로 연결 (jitter 좌표를 그대로 사용해서 자연스럽게 연결)
% for i = 1:numel(dW)
%     plot([xWj(i) xEj(i)], [dW(i) dE(i)], '-', 'Color',[0 0 0], 'LineWidth', 0.8);
% end
% 
% ---- 기준선 ----
yline(0,'--','Color',[0.5 0.5 0.5]);

% ---- 축 ----
xlim([0.5 2.5]);
set(gca,'XTick',xPos,'XTickLabel',{'West','East'});
ylabel('\Delta Theta power (Post − Pre)');

% ---- 제목 ----
title(sprintf('West p = %.3g (n=%d), East p = %.3g (n=%d)', ...
              pW, numel(dW), pE, numel(dE)));





%% average difference - one sample t-test(all rats)

% H0: mean(d) = 0  (no change)

T_out.rat   = string(T_out.rat);
T_out.goal  = string(T_out.goal);
T_out.stage = string(T_out.stage);

rats = unique(T_out.rat);

% west/east per-rat means (Pre/Post)
xW = nan(numel(rats),1);  yW = nan(numel(rats),1);
xE = nan(numel(rats),1);  yE = nan(numel(rats),1);

for i = 1:numel(rats)
    r = rats(i);

    % West
    preW  = T_out.theta_power_iHP(T_out.rat==r & T_out.goal=="West" & T_out.stage=="Pre");
    postW = T_out.theta_power_iHP(T_out.rat==r & T_out.goal=="West" & T_out.stage=="Post");
    if ~isempty(preW) && ~isempty(postW)
        xW(i) = mean(preW,'omitnan');
        yW(i) = mean(postW,'omitnan');
    end

    % East
    preE  = T_out.theta_power_iHP(T_out.rat==r & T_out.goal=="East" & T_out.stage=="Pre");
    postE = T_out.theta_power_iHP(T_out.rat==r & T_out.goal=="East" & T_out.stage=="Post");
    if ~isempty(preE) && ~isempty(postE)
        xE(i) = mean(preE,'omitnan');
        yE(i) = mean(postE,'omitnan');
    end
end

% within-rat change (mean difference)
dW = yW - xW;
dE = yE - xE;

dWv = dW(~isnan(dW));
dEv = dE(~isnan(dE));

% one-sample t-test (mean difference, 0)
[~, pW, ciW, statsW] = ttest(dWv, 0);
[~, pE, ciE, statsE] = ttest(dEv, 0);

mW   = mean(dWv,'omitnan');   mE   = mean(dEv,'omitnan');
semW = std(dWv,'omitnan') / sqrt(numel(dWv));
semE = std(dEv,'omitnan') / sqrt(numel(dEv));

% plot 
figure; hold on; box off;

xPos = [1 2];

bar(xPos(1), mW, 0.6, 'FaceColor',[0.7 0.7 0.7]);
bar(xPos(2), mE, 0.6, 'FaceColor',[0.7 0.7 0.7]);

errorbar(xPos(1), mW, semW, 'k', 'LineStyle','none', 'LineWidth',1);
errorbar(xPos(2), mE, semE, 'k', 'LineStyle','none', 'LineWidth',1);

j = 0.08;
xWj = xPos(1) + (rand(size(dWv))-0.5)*2*j;
xEj = xPos(2) + (rand(size(dEv))-0.5)*2*j;

scatter(xWj, dWv, 60, 'k', 'filled');
scatter(xEj, dEv, 60, 'k', 'filled');

yline(0,'--','Color',[0.5 0.5 0.5]);

xlim([0.5 2.5]);
set(gca,'XTick',xPos,'XTickLabel',{'West','East'});
ylabel('\Delta Theta power (Post − Pre)');

title(sprintf(['West p=%.3g, CI=[%.3g %.3g], n=%d | ' ...
               'East p=%.3g, CI=[%.3g %.3g], n=%d'], ...
      pW, ciW(1), ciW(2), numel(dWv), ...
      pE, ciE(1), ciE(2), numel(dEv)));









rat_list = {'774', '779', '780', '781', '816', '817'};
T_out = table('Size',[0 6], ...
    'VariableTypes', {'double','double','double','double','string','string'}, ...
    'VariableNames', {'ss','theta_power_iHP','theta_power_mPFC','velocity','goal','stage'});

row = 0;

for r = 1:length(rat_list)
    rat_ss = session_list(strcmp(session_list.rat,rat_list{r}),:);
    
    for s = 1:size(rat_ss,1)
        rat = rat_ss.rat{s};
        ss = rat_ss.ss{s};
        formattedSS = sprintf('%02d', str2double(ss));
        ss_num = str2double(string(ss));
        rat_num = str2double(string(rat));
    target  = sprintf('%s-%s', rat, ss);   % '817-4'
    target2 = sprintf('%s-%s', rat, formattedSS);  % '817-04'
    fprintf('Processing %s\n', target2);
   
    %% ---------- theta TT ----------
   target_ss_id = sprintf('r%s_%s', rat, ss);
    if ~isfield(theta_TT, target_ss_id)
    warning('theta_TT missing: %s (skip session)', target_ss_id);
    continue;
    end

    theta_info = theta_TT.(target_ss_id);
    
    %% ---------- load behaviour ----------
    load([ROOT.Data target2 '.mat']);   % loads ue, ue_t, cheetah, encoder

    %% ue variables
tick_timestamp = cheetah.tick;
trial_timestamp = cheetah.trial;
cueonset_timestamp = cheetah.cueonset;
HighValue_timestamp = cheetah.highvalue;
LowValue_timestamp = cheetah.lowvalue;
NStart_timestamp = cheetah.northstart;
SStart_timestamp = cheetah.southstart;

ue_timestamp.main = ue{:,1};
ue_time = ue{:,2};
ue_trial.main = ue{:,3};
ue_trial.ITIstart = ue{:,4};
ue_performance_available_frame = ue{:,5};
ue_position.main = ue{:,6:7};
ue_head_direction = ue{:,8};
ue_cumdistance = ue{:,9};
ue_DistancefromRewardzone = ue{:,10};
ue_velocity = ue{:,11};
ue_velocity_smoothing_500ms = ue{:,12};
ue_ang_velocity = ue{:,13};
ue_ang_velocity_smoothing_500ms = ue{:,14};
ue_edge = ue{:,15};
ue_flag = ue{:,16};
ue_FrameofITI = ue{:,17};
ue_reward_zone_arrival = ue{:,18}; % directly from UE log
ue_highvaluezone = ue{:,19}; % directly from UE log

ue_Trialstart = ue_t{:,1};
ue_Trialstart_ITI = ue_t{:,2};
ue_RewardzoneArrival = ue_t{:,3};
ue_Trialend = ue_t{:,4};
ue_Trialend_ITI = ue_t{:,5};
ue_start_direction = ue_t{:,6};
ue_performance = ue_t{:,7};
ue_performance_available = ue_t{:,8};
ue_latency = ue_t{:,9};
ue_traveldistance = ue_t{:,10};
ue_EdgeDistance = ue_t{:,11};
ue_PercentofEdgeNav = ue_t{:,12};
ue_guide_trial = ue_t{:,13};
ue_outlier = ue_t{:,14};
ue_outlier_distance = ue_t{:,15};
ue_outlier_latency = ue_t{:,16};
ue_outlier_latency_scene = ue_t{:,17};

encoder_position = encoder{:,1:2};
encoder_velocity = encoder{:,3};
encoder_velocity_smoothing_500ms = encoder{:,4};
encoder_distance = encoder{:,5};
encoder_degree = encoder{:,6};
encoder_angspeed = encoder{:,7};

NumberofFrame = size(ue_timestamp.main,1);
NumberofTrial = ue_trial.main(NumberofFrame)-1;


% correctness
ue_t_overall = ue_t(ue_t.performance_available == 1,:);

if isempty(ue_t_overall)
    corr_session = NaN;
else
    corr_session = sum(ue_t_overall.performance==1) / size(ue_t_overall,1) * 100;
end


%% Set parameters
% parameters for coherence calculation
params.Fs = 2000;
params.fpass = [6 12];    % LFP range
% params.fpass = [6 150];
params.tapers = [3 5];
params.trialave = 1;
params.err = [2 0.05];
params.pad = 0;

% Reward zone and start zone parameter setting
Maze.Outline.x = 0;
Maze.Outline.y = 0;
Maze.Outline.r = 0.9500;

%실제 언리얼 상에서 reward zone diameter
RewardZone.inner.r = 0.6500;
RewardZone.outer.r = 0.8000;

%center of reward zone
RewardZone.arch.x = -0.7715; % RewardZone.arch.x=-5186; % west 
RewardZone.arch.y = 0.1552; % RewardZone.arch.y=873; % west 
RewardZone.sea.x = -0.780; % 사용안함
RewardZone.sea.y = -0.5130; % 사용안함
RewardZone.house.x = 0.7715; % RewardZone.house.x=5247; % east  
RewardZone.house.y = -0.1552; % RewardZone.house.y=-698; % east 



    %% ---------- load theta CSC ----------
  %iHP 
  theta_iHP = [ROOT.Theta 'LE' rat '\rat' rat '-' ss '\AG' num2str(theta_info.bestTT_iHP) '_RateReduced_6-12filtered.ncs'];
    HeaderExtractionFlag = 1;
    ExtractionMode = 1;
    ExtractionModeVector = [];
    FieldSelectionFlags = [1 1 1 1 1];

    try
    [CSCdata.Timestamps, CSCdata.ChannelNumbers, CSCdata.SampleFrequencies, CSCdata.NumberOfValidSamples, ...
        CSCdata.eeg, CSCdata.Header]= Nlx2MatCSC(theta_iHP, FieldSelectionFlags, ...
        HeaderExtractionFlag, ExtractionMode, ExtractionModeVector);   

    catch ME
    warning('Nlx2MatCSC failed: %s (skip %s)', ME.message, target_ss_id);
    continue;
    end

    CSCdata.ADBitVolts = str2double(CSCdata.Header{15,1}(13:end));
    CSCdata.ADMaxValue = str2double(CSCdata.Header{16,1}(13:end));
    CSCdata.eeg = CSCdata.eeg.*CSCdata.ADBitVolts;

    % expand CSC 

   [thetaband_iHP.eeg, thetaband_iHP.timestamp] = expandCSC(CSCdata);


  %mPFC 
  theta_mPFC = [ROOT.Theta 'LE' rat '\rat' rat '-' ss '\AG' num2str(theta_info.bestTT_mPFC) '_RateReduced_6-12filtered.ncs'];
    HeaderExtractionFlag = 1;
    ExtractionMode = 1;
    ExtractionModeVector = [];
    FieldSelectionFlags = [1 1 1 1 1];

    try
    [CSCdata.Timestamps, CSCdata.ChannelNumbers, CSCdata.SampleFrequencies, CSCdata.NumberOfValidSamples, ...
        CSCdata.eeg, CSCdata.Header]= Nlx2MatCSC(theta_mPFC, FieldSelectionFlags, ...
        HeaderExtractionFlag, ExtractionMode, ExtractionModeVector);   

    catch ME
    warning('Nlx2MatCSC failed: %s (skip %s)', ME.message, target_ss_id);
    continue;
    end

    CSCdata.ADBitVolts = str2double(CSCdata.Header{15,1}(13:end));
    CSCdata.ADMaxValue = str2double(CSCdata.Header{16,1}(13:end));
    CSCdata.eeg = CSCdata.eeg.*CSCdata.ADBitVolts;

    % expand CSC 

   [thetaband_mPFC.eeg, thetaband_mPFC.timestamp] = expandCSC(CSCdata);


% time
t = 0;
trial_time = [];
for i = 1:NumberofTrial
    if ue_performance_available(i) == 1 %& ue_start_direction(i) == 90 %start direction
       t = t+1;
       trial_time(t,1) = tick_timestamp(ue_Trialstart(i)); %navigation start 
       trial_time(t,2) = tick_timestamp(ue_RewardzoneArrival(i)); %navigation end 
       trial_time(t,3) = i;  
       trial_time(t,4) = tick_timestamp(ue_Trialstart_ITI(i)); % ITI start 
    end
end


    %% ---------- trial loop ----------
    theta_session = nan(NumberofTrial,1);
    vel_session   = nan(NumberofTrial,1);

% iHP theta power     
nT = size(trial_time,1);

    for r = 1:nT
        origTrial = trial_time(r,3);

    if ue_performance_available(origTrial) ~= 1
        continue;
    end

    tS = trial_time(r,1);
    tE = trial_time(r,2);
    
    [~, idxStart] = min(abs(thetaband_iHP.timestamp - tS));
    [~, idxEnd] = min(abs(thetaband_iHP.timestamp -tE));

    theta_seg_i = double(thetaband_iHP.eeg(idxStart:idxEnd));
    tTheta_i    = double(thetaband_iHP.timestamp(idxStart:idxEnd));
    theta_power_iHP = abs(hilbert(theta_seg_i));
    %theta_smoothed = smoothdata(theta_power, "gaussian", w);

    theta_trial_iHP(r) = mean(theta_power_iHP, 'omitnan');
    theta_session_iHP(r) = mean(theta_trial_iHP, 'omitnan');

% mPFC theta power    
    
    [~, idxStart] = min(abs(thetaband_mPFC.timestamp - tS));
    [~, idxEnd] = min(abs(thetaband_mPFC.timestamp -tE));

    theta_seg_m = double(thetaband_mPFC.eeg(idxStart:idxEnd));
    tTheta_m    = double(thetaband_mPFC.timestamp(idxStart:idxEnd));
    theta_power_mPFC = abs(hilbert(theta_seg_m));
    %theta_smoothed = smoothdata(theta_power, "gaussian", w);

    theta_trial_mPFC(r) = mean(theta_power_mPFC, 'omitnan');
    theta_session_mPFC(r) = mean(theta_trial_mPFC, 'omitnan');

% velocity
    [~, rS] = min(abs(tick_timestamp - tS));
    [~, rE] = min(abs(tick_timestamp - tE));

    v = double(encoder_velocity(rS:rE));

    %v_sm = smoothdata(v, "gaussian", wVel);

    vel_session(i) = mean(v, 'omitnan');
    end

        goal  = string(rat_ss.goal(s));
        stage = string(rat_ss.stage(s));

row = row + 1;

    T_out.ss(s)          = ss_num;
    T_out.theta_power_iHP(s) = mean(theta_session_iHP, 'omitnan');
    T_out.theta_power_mPFC(s) = mean(theta_session_mPFC, 'omitnan');
    T_out.velocity(s) = mean(vel_session,'omitnan');
    T_out.goal(s,1)  = string(session_list.goal(row));
    T_out.stage(s,1) = string(session_list.stage(row));

    end
end           
% g = T.goal;
% st = T.stage;
% th = T.theta_power;

% % block means
% idx1 = (T.goal == "West") & (T.stage == "Pre");
% idx2 = (T.goal == "West") & (T.stage == "Post");
% idx3 = (T.goal == "East") & (T.stage == "Pre");
% idx4 = (T.goal == "East") & (T.stage == "Post");

valid = ~isnan(T_out.theta_power_iHP) & ~isnan(T_out.theta_power_mPFC);

ss_plot     = T_out.ss(valid);
theta_plot_i  = T_out.theta_power_iHP(valid);
theta_plot_m = T_out.theta_power_mPFC(valid);
%corr_plot = T.correctness(valid);

[ss_plot, idx] = sort(ss_plot);
theta_plot_i  = theta_plot_i(idx);
theta_plot_m  = theta_plot_m(idx);

% plot
figure('Color','w','Position',[100 100 800 400]); hold on; box off;

yyaxis left
plot(ss_plot, theta_plot_i, '-o', 'LineWidth',2);
ylabel('iHP theta power (session mean)');

yyaxis right
plot(ss_plot, theta_plot_m, '-s', 'LineWidth',2);
ylabel('mPFC theta power (session mean)');

xlabel('Session');
title(['LE ' target2 ' Session-wise theta power (iHP, mPFC)']);
xticks(min(T_out.ss):1:max(T_out.ss));

fname = sprintf('LE_%s_session_theta_power_iHP_mPFC', rat);
pngFile = fullfile(ROOT.Save, [fname '.png']);
saveas(pngFile);   
end

% figure; hold on; box off;
% bar(Y);
% 
% set(gca,'XTick',1:2, ...
%         'XTickLabel',{'East-Pre','East-Post'});
% 
% % Wilcoxon rank-sum test
% x = T.theta_power(idx3);
% y = T.theta_power(idx4);
% 
% p = ranksum(x, y);
% 
% ylabel('Theta power');
% title(sprintf('LE%s  Pre vs Post: p = %.4g', rat_target, p));

%% overall trend across days
% 필요한 컬럼만 사용
T_out.rat = string(T_out.rat);

rats = unique(T_out.rat);

for r = 1:numel(rats)

    Tr = T_out(T_out.rat == rats(r), :);

    % 세션 기준 정렬
    [ss, idx] = sort(Tr.ss);
    iHP  = Tr.theta_power_iHP(idx);
    mPFC = Tr.theta_power_mPFC(idx);

    % plot
    figure('Color','w','Position',[100 100 800 400]); hold on; box off;

    yyaxis left
    plot(ss, iHP, '-o', 'LineWidth',2);
    ylabel('iHP theta power (session mean)');

    yyaxis right
    plot(ss, mPFC, '-s', 'LineWidth',2);
    ylabel('mPFC theta power (session mean)');

    xlabel('Session');
    title(sprintf('LE %s Session-wise theta power (iHP, mPFC)', rats(r)));
    xticks(ss);

%%  bar graph pre vs. post (all rats)
T_out.rat   = string(T_out.rat);
T_out.goal  = string(T_out.goal);
T_out.stage = string(T_out.stage);

rats = unique(T_out.rat);
goals = ["West","East"];

for g = 1:numel(goals)

    goal_g = goals(g);

   % save pre/post
    pre  = nan(numel(rats),1);
    post = nan(numel(rats),1);

    for r = 1:numel(rats)

        Tr = T_out(T_out.rat==rats(r) & T_out.goal==goal_g, :);

        pre_v  = Tr.theta_power_iHP(Tr.stage=="Pre");
        post_v = Tr.theta_power_iHP(Tr.stage=="Post");

        if ~isempty(pre_v) && ~isempty(post_v)
            pre(r)  = mean(pre_v,'omitnan');
            post(r) = mean(post_v,'omitnan');
        end
    end

    %p = signrank(pre, post); 
    [~, p, ci, stats] = ttest(preK, postK);

% plot
    figure('Color','w','Position',[100 100 400 400]); hold on; box off;

    m = [mean(pre) mean(post)];
    sem = [std(pre)/sqrt(numel(pre)), std(post)/sqrt(numel(post))];

    bar([1 2], m, 0.6, 'FaceColor',[0.85 0.85 0.85]);
    errorbar([1 2], m, sem, 'k', 'LineStyle','none','LineWidth',1);

    % paired dots
    for i = 1:numel(pre)
        plot([1 2], [pre(i) post(i)], '-', 'Color',[0.5 0.5 0.5]);
        scatter([1 2], [pre(i) post(i)], 40, 'k', 'filled');
    end

    set(gca,'XTick',[1 2],'XTickLabel',{'Pre','Post'});
    ylabel('iHP theta power');
    title(sprintf('%s | iHP theta (Pre vs Post)\np = %.3g (n = %d)', ...
                  goal_g, p, numel(pre)));
end



%% bar graph (paired t-test)

T_out.rat   = string(T_out.rat);
T_out.goal  = string(T_out.goal);
T_out.stage = string(T_out.stage);

rats  = unique(T_out.rat);
goals = ["West","East"];

for g = 1:numel(goals)

    goal_g = goals(g);

    % save per-rat pre/post (session-averaged within stage)
    pre  = nan(numel(rats),1);
    post = nan(numel(rats),1);

    for r = 1:numel(rats)

        Tr = T_out(T_out.rat==rats(r) & T_out.goal==goal_g, :);

        pre_v  = Tr.theta_power_mPFC(Tr.stage=="Pre");
        post_v = Tr.theta_power_mPFC(Tr.stage=="Post");

        if ~isempty(pre_v) && ~isempty(post_v)
            pre(r)  = mean(pre_v,'omitnan');
            post(r) = mean(post_v,'omitnan');
        end
    end

    % keep only rats with both values
    keep = ~isnan(pre) & ~isnan(post);
    preK  = pre(keep);
    postK = post(keep);

    % paired t-test
    %[~, p, ci, stats] = ttest(preK, postK);  
    p = signrank(pre, post); 

    % plot
    figure('Color','w','Position',[100 100 400 400]); hold on; box off;

    m   = [mean(preK,'omitnan')  mean(postK,'omitnan')];
    sem = [std(preK,'omitnan')/sqrt(numel(preK))  std(postK,'omitnan')/sqrt(numel(postK))];

    bar([1 2], m, 0.6, 'FaceColor',[0.85 0.85 0.85]);
    errorbar([1 2], m, sem, 'k', 'LineStyle','none','LineWidth',1);

    % paired dots + lines
    for i = 1:numel(preK)
        plot([1 2], [preK(i) postK(i)], '-', 'Color',[0.5 0.5 0.5]);
        scatter([1 2], [preK(i) postK(i)], 40, 'k', 'filled');
    end

    set(gca,'XTick',[1 2],'XTickLabel',{'Pre','Post'});
    ylabel('mPFC theta power');

    title(sprintf(['%s | p=%.3g, n = %d'], goal_g, p, numel(preK)));
end


%% z-score (baseline: ITI) & paired t-test

T_out.rat   = string(T_out.rat);
T_out.goal  = string(T_out.goal);
T_out.stage = string(T_out.stage);

% 필요 컬럼 체크(없으면 에러)
req = ["theta_power_mPFC","theta_power_mPFC_ITI"];
for c = 1:numel(req)
    if ~ismember(req(c), string(T_out.Properties.VariableNames))
        error("T_out에 %s 컬럼이 없습니다.", req(c));
    end
end

rats  = unique(T_out.rat);
goals = ["West","East"];

for g = 1:numel(goals)

    goal_g = goals(g);

    % rat별 pre/post (z-scored session 평균) 저장
    pre  = nan(numel(rats),1);
    post = nan(numel(rats),1);

    for r = 1:numel(rats)

        % 해당 rat & goal 세션들
        Tr = T_out(T_out.rat==rats(r) & T_out.goal==goal_g, :);

        % baseline(ITI) 분포: 이 rat&goal에서 가능한 모든 세션의 ITI 값
        iti_all = Tr.theta_power_mPFC_ITI;
        iti_all = iti_all(~isnan(iti_all));

        muITI = mean(iti_all,'omitnan');
        sdITI = std(iti_all,'omitnan');

        % sd=0이면 z-score 불가
        if sdITI <= 0 || isnan(sdITI)
            continue;
        end

        % 세션별 z-score 계산: (Trial - muITI) / sdITI
        z_sess = (Tr.theta_power_mPFC - muITI) ./ sdITI;

        % stage별 rat 평균
        pre_v  = z_sess(Tr.stage=="Pre");
        post_v = z_sess(Tr.stage=="Post");

        if ~isempty(pre_v) && ~isempty(post_v)
            pre(r)  = mean(pre_v,'omitnan');
            post(r) = mean(post_v,'omitnan');
        end
    end

    % paired 가능한 rat만
    keep = ~isnan(pre) & ~isnan(post);
    preK  = pre(keep);
    postK = post(keep);

    % paired t-test
    %[~, p, ci, stats] = ttest(preK, postK);
    p = signrank(pre, post); 

    % plot
    figure('Color','w','Position',[100 100 420 420]); hold on; box off;

    m   = [mean(preK,'omitnan')  mean(postK,'omitnan')];
    sem = [std(preK,'omitnan')/sqrt(numel(preK))  std(postK,'omitnan')/sqrt(numel(postK))];

    bar([1 2], m, 0.6, 'FaceColor',[0.85 0.85 0.85], 'EdgeColor','none');
    errorbar([1 2], m, sem, 'k', 'LineStyle','none','LineWidth',1);

    % paired dots + lines
    for i = 1:numel(preK)
        plot([1 2], [preK(i) postK(i)], '-', 'Color',[0.5 0.5 0.5]);
        scatter([1 2], [preK(i) postK(i)], 40, 'k', 'filled');
    end

    yline(0,'-','Color',[0.7 0.7 0.7]);  % z=0 기준선 (baseline)

    set(gca,'XTick',[1 2],'XTickLabel',{'Pre','Post'});
    ylabel('mPFC theta (z-score vs ITI baseline)');
    title(sprintf('%s | p=%.3g, n=%d', goal_g, p, numel(preK)));

    % 콘솔에 요약 출력
    fprintf('\n[%s] n=%d, p=%.4g, t(%d)=%.3f, mean(d)=%.3f\n', ...
        goal_g, numel(preK), p, stats.df, stats.tstat, mean(postK-preK,'omitnan'));
end



%% === ITI-corrected theta change: (Trial - ITI), Pre vs Post ===

T_out.rat   = string(T_out.rat);
T_out.goal  = string(T_out.goal);
T_out.stage = string(T_out.stage);

rats  = unique(T_out.rat);
goals = ["West","East"];

for g = 1:numel(goals)

    goal_g = goals(g);

    pre  = nan(numel(rats),1);
    post = nan(numel(rats),1);

    for r = 1:numel(rats)

        Tr = T_out(T_out.rat==rats(r) & T_out.goal==goal_g, :);

        % ITI-corrected session values
        dTheta = Tr.theta_power_iHP - Tr.theta_power_iHP_ITI;

        % stage별 rat 평균
        pre_v  = dTheta(Tr.stage=="Pre");
        post_v = dTheta(Tr.stage=="Post");

        if ~isempty(pre_v) && ~isempty(post_v)
            pre(r)  = mean(pre_v,'omitnan');
            post(r) = mean(post_v,'omitnan');
        end
    end

    % paired 가능한 rat만
    keep = ~isnan(pre) & ~isnan(post);
    preK  = pre(keep);
    postK = post(keep);

    % paired t-test
    [~, p, ci, stats] = ttest(preK, postK);
    

    % plot
    figure('Color','w','Position',[100 100 420 420]); hold on; box off;

    m   = [mean(preK,'omitnan')  mean(postK,'omitnan')];
    sem = [std(preK,'omitnan')/sqrt(numel(preK))  std(postK,'omitnan')/sqrt(numel(postK))];

    bar([1 2], m, 0.6, 'FaceColor',[0.85 0.85 0.85], 'EdgeColor','none');
    errorbar([1 2], m, sem, 'k', 'LineStyle','none','LineWidth',1);

    for i = 1:numel(preK)
        plot([1 2], [preK(i) postK(i)], '-', 'Color',[0.5 0.5 0.5]);
        scatter([1 2], [preK(i) postK(i)], 40, 'k', 'filled');
    end

    yline(0,'-','Color',[0.7 0.7 0.7]);

    set(gca,'XTick',[1 2],'XTickLabel',{'Pre','Post'});
    ylabel('\Delta iHP theta (Trial - ITI)');
    title(sprintf('%s | p=%.3g, n=%d', goal_g, p, numel(preK)));
end



%% line graph (all rats in a single figure)
T_out.rat   = string(T_out.rat);
T_out.goal  = string(T_out.goal);
T_out.stage = string(T_out.stage);

rats  = unique(T_out.rat);
goals = ["West","East"];

for g = 1:numel(goals)

    goal_g = goals(g);

    figure('Color','w','Position',[100 100 420 420]); hold on; box off;
    cmap = lines(numel(rats));

    h = gobjects(0);          % line handles (그려진 것만)
    leg = strings(0);         % legend labels (그려진 것만)

    for r = 1:numel(rats)

        Tr = T_out(T_out.rat==rats(r) & T_out.goal==goal_g, :);

        pre  = mean(Tr.theta_power_iHP(Tr.stage=="Pre"),  'omitnan');
        post = mean(Tr.theta_power_iHP(Tr.stage=="Post"), 'omitnan');

        if ~isnan(pre) && ~isnan(post)
            h(end+1,1) = plot([1 2], [pre post], '-o', ...
                'Color', cmap(r,:), ...
                'LineWidth', 2, ...
                'MarkerFaceColor', cmap(r,:));
            leg(end+1,1) = rats(r);
        end
    end

    xlim([0.8 2.2]);
    set(gca,'XTick',[1 2],'XTickLabel',{'Pre','Post'});
    ylabel('iHP theta power');
    title(sprintf('%s | iHP theta', goal_g));

    legend(h, leg, 'Location','bestoutside');   % ✅ 정확히 매칭

end
