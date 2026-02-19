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

target = '816-04';
temp = split(target, '-');
rat = temp{1};
ss = num2str(str2double(temp{2}));
target_ss_id = ['r' rat '_' ss];
theta_info = theta_TT.(target_ss_id);

load([ROOT.Data target '.mat']);

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

%% Parameters

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

%% ===== 1) trial selection (ROW index 기반) =====
% 필요 변수: ue_latency, ue_traveldistance, ue_performance_available,
%          ue_start_direction, ue_Trialstart, ue_RewardzoneArrival, NumberofTrial


%% theta power
theta = [ROOT.Theta 'LE' rat '\rat' rat '-' ss '\AG' num2str(theta_info.bestTT_iHP) '_RateReduced_6-12filtered.ncs'];
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



% outlier threshold (너가 준 그대로)
n = 2;
threshold_l  = median(ue_latency)        + n*mad(ue_latency,1);
threshold_td = median(ue_traveldistance) + n*mad(ue_traveldistance,1);

trial_idx = [];   % [rS rE origTrial]
t = 0;
trial_time = [];
for i = 1:NumberofTrial
    if ue_performance_available(i) ~= 1, continue; end
    if ue_start_direction(i) ~= 90,       continue; end
    if ue_t.performance(i) ~= 1, continue; end 
    if ue_latency(i) > threshold_l,       continue; end
    if ue_traveldistance(i) > threshold_td, continue; end
    rS = ue_Trialstart(i);
    rE = ue_RewardzoneArrival(i);
    if isempty(rS) || isempty(rE) || rE <= rS, continue; end

    trial_idx = [trial_idx; rS rE i];

       t = t+1;
       trial_time(t,1) = tick_timestamp(ue_Trialstart(i)); %navigation start 
       trial_time(t,2) = tick_timestamp(ue_RewardzoneArrival(i)); %navigation end 
       trial_time(t,3) = i;  

end

%% ===== ue columns (변수명으로 안전하게) =====
X  = ue.position_x;
Y  = ue.position_y;
V  = ue.velocity;
AV = abs(ue.angular_velocity);   % <- 절댓값 사용

th = linspace(0,2*pi,400);

%% ===== Figure 1: velocity heatmap =====
figure('Color','w'); hold on; axis equal; box on;
plot(Maze.Outline.x + Maze.Outline.r*cos(th), Maze.Outline.y + Maze.Outline.r*sin(th), 'k','LineWidth',1);

for k = 1:size(trial_idx,1)
    rS = trial_idx(k,1); rE = trial_idx(k,2);

    x = X(rS:rE); y = Y(rS:rE); c = V(rS:rE);
    ok = ~(isnan(x) | isnan(y) | isnan(c));
    x = x(ok); y = y(ok); c = c(ok);
    if numel(x) < 2, continue; end

    surface([x(:)';x(:)'], [y(:)';y(:)'], zeros(2,numel(x)), [c(:)';c(:)'], ...
        'FaceColor','none','EdgeColor','interp','LineWidth',2);
end
colormap(jet); colorbar; title('Velocity'); xlim([-1 1]); ylim([-1 1]);



% --- colour range 계산: 선택된 trial 구간만 모아서 퍼센타일로 자르기 ---
allC = [];
for k = 1:size(trial_idx,1)
    rS = trial_idx(k,1); rE = trial_idx(k,2);
    c  = AV(rS:rE);
    c  = c(~isnan(c));
    allC = [allC; c(:)];
end
cLim = prctile(allC, [5 95]);     % 필요하면 [1 99]로 더 강하게

% --- plot ---
th = linspace(0,2*pi,400);
figure('Color','w'); hold on; axis equal; box on;
plot(Maze.Outline.x + Maze.Outline.r*cos(th), Maze.Outline.y + Maze.Outline.r*sin(th), 'k','LineWidth',1);

for k = 1:size(trial_idx,1)
    rS = trial_idx(k,1); rE = trial_idx(k,2);

    x = X(rS:rE); y = Y(rS:rE); c = AV(rS:rE);
    ok = ~(isnan(x) | isnan(y) | isnan(c));
    x = x(ok); y = y(ok); c = c(ok);
    if numel(x) < 2, continue; end

    surface([x(:)';x(:)'], [y(:)';y(:)'], zeros(2,numel(x)), [c(:)';c(:)'], ...
        'FaceColor','none','EdgeColor','interp','LineWidth',2);
end

colormap(jet); colorbar;
caxis(cLim);                         % <- 핵심!
title('Angular velocity');
xlim([-1 1]); ylim([-1 1]);

%% ===== Theta power per ue-row (trial-wise z-score) =====

% 1) theta envelope (LFP timebase)
theta_env = abs(hilbert(double(thetaband_iHP.eeg)));

% 2) UE timebase로 보간
theta_ue = interp1(double(thetaband_iHP.timestamp), theta_env, ...
                   double(tick_timestamp), 'linear', nan);

% 3) trial-wise z-score
theta_z = nan(size(theta_ue));   % 결과 초기화

for k = 1:size(trial_idx,1)

    idx = trial_idx(k,1):trial_idx(k,2);   % 이 trial의 ue row 범위

    th = theta_ue(idx);

    if sum(~isnan(th)) < 5   % 너무 짧은 trial 방지
        continue;
    end

    mu = mean(th, 'omitnan');
    sd = std(th, 0, 'omitnan');

    if sd == 0 || isnan(sd)
        continue;
    end

    theta_z(idx) = (th - mu) ./ sd;
end

% 4) (선택) smoothing
w = 10;
theta_z_s = movmean(theta_z, w, 'omitnan');


%% ============================================================
%% ===== Figure: Theta power heatmap (trial-wise z-score) =====

th = linspace(0,2*pi,400);

figure('Color','w'); hold on; axis equal; box on;
plot(Maze.Outline.x + Maze.Outline.r*cos(th), ...
     Maze.Outline.y + Maze.Outline.r*sin(th), ...
     'k','LineWidth',1);

for k = 1:size(trial_idx,1)

    rS = trial_idx(k,1); 
    rE = trial_idx(k,2);

    x = X(rS:rE);
    y = Y(rS:rE);
    c = theta_z_s(rS:rE);    % trial-wise z-scored theta

    ok = ~(isnan(x) | isnan(y) | isnan(c));
    x = x(ok); 
    y = y(ok); 
    c = c(ok);

    if numel(x) < 2
        continue;
    end

    surface([x(:)'; x(:)'], ...
            [y(:)'; y(:)'], ...
            zeros(2,numel(x)), ...
            [c(:)'; c(:)'], ...
            'FaceColor','none', ...
            'EdgeColor','interp', ...
            'LineWidth',2);
end

colormap(turbo);     % velocity/AV랑 통일하려면 jet
colorbar;
caxis([-2 2]);       % ★ z-score 고정 범위
title('Theta power (trial-wise z-score)');
xlim([-1 1]); ylim([-1 1]);
