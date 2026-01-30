%% theta power vs. velocity 
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

%% exclude outliers (latency & travel distance)
% latency 
latency = ue_latency;   
n = 2;                  

med = median(latency);
mad_val = mad(latency, 1);    % (median(|x - median(x)|)

threshold_l = med + n * mad_val;

% travel distance
travel_distance = ue_traveldistance;
n = 2;                 

med = median(travel_distance);
mad_val = mad(travel_distance, 1);    

threshold_td = med + n * mad_val;

%% theta power
theta = [ROOT.Theta 'LE' rat '\rat' rat '-' ss '\AG' num2str(theta_info.bestTT_mPFC) '_RateReduced_6-12filtered.ncs'];
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

% time
t = 0;
trial_time = [];
for i = 1:NumberofTrial
    % if ue_performance_available(i) ~= 1
    %     continue;
    % end
    % 
    % if ue_latency(i) > threshold_l
    %     continue;
    % end
    % 
    % if ue_traveldistance(i) > threshold_td
    %     continue;
    % end
      
    if ue_performance(i) ~= 2
          continue;
      end

       t = t+1;
       trial_time(t,1) = tick_timestamp(ue_Trialstart(i)); %navigation start 
       trial_time(t,2) = tick_timestamp(ue_RewardzoneArrival(i)); %navigation end 
       trial_time(t,3) = i;  
end

%velocity 
enc_vel = encoder_velocity;

all_vel = [];              % 모든 trial 구간 velocity를 이어붙인 1개의 벡터
all_trial_id = [];         % (옵션) 각 샘플이 어떤 trial인지 표시

for k = 1:size(trial_time,1)

    % trial start/end timestamp 값
    tS = trial_time(k,1);
    tE = trial_time(k,2);

    [~, rS] = min(abs(tick_timestamp - tS));
    [~, rE] = min(abs(tick_timestamp - tE));
    if rE <= rS, continue; end

    vseg = enc_vel(rS:rE);        % 같은 row 범위의 velocity

    % 이어붙이기
    all_vel = [all_vel; vseg];
end


%% 1) normalised time grid에 보간해서 trial x timebin 행렬 만들기

nBin  = 300;
tGrid = linspace(0,1,nBin)';

wTheta = 200;
wVel   = 50;

Ztheta = nan(size(trial_time,1), nBin);
Zvel   = nan(size(trial_time,1), nBin);

for i = 1:size(trial_time,1)


    % theta (thetaband_iHP)

    [~, idxStart] = min(abs(thetaband_iHP.timestamp - trial_time(i,1)));
    [~, idxEnd]   = min(abs(thetaband_iHP.timestamp - trial_time(i,2)));
    if idxEnd <= idxStart, continue; end

    x = double(thetaband_iHP.eeg(idxStart:idxEnd));
    theta_power = abs(hilbert(x));
    theta_sm    = smoothdata(theta_power, "gaussian", wTheta);

    tt_theta = linspace(0,1,numel(theta_sm))';
    Ztheta(i,:) = interp1(tt_theta, theta_sm, tGrid, 'linear', NaN);

    % =========================
    % (B) velocity (encoder_velocity)
    % tick_timestamp와 row가 같으므로, 같은 row 구간을 slice
    % =========================
    tS = trial_time(i,1);
    tE = trial_time(i,2);

    [~, rS] = min(abs(tick_timestamp - tS));
    [~, rE] = min(abs(tick_timestamp - tE));
    if rE <= rS, continue; end

    v = double(enc_vel(rS:rE));
    if numel(v) < 2, continue; end
    v = smoothdata(v, "gaussian", wVel);

    tt_vel = linspace(0,1,numel(v))';
    Zvel(i,:) = interp1(tt_vel, v, tGrid, 'linear', NaN);
end

% SEM
okBoth = any(isfinite(Ztheta),2) & any(isfinite(Zvel),2);
Zt = Ztheta(okBoth,:);
Zv = Zvel(okBoth,:);

theta_mean = nanmean(Zt, 1);
vel_mean   = nanmean(Zv, 1);

theta_sem  = nanstd(Zt, 0, 1) ./ sqrt(sum(isfinite(Zt),1));
vel_sem    = nanstd(Zv, 0, 1) ./ sqrt(sum(isfinite(Zv),1));


% mean 
okBoth = any(isfinite(Ztheta),2) & any(isfinite(Zvel),2);
Zt = Ztheta(okBoth,:);
Zv = Zvel(okBoth,:);

theta_mean = nanmean(Zt, 1);
vel_mean   = nanmean(Zv, 1);

% plot
figure('Color','w'); box off;

yyaxis left; hold on;

% SEM band (theta)
fill([tGrid; flipud(tGrid)], ...
     [theta_mean-theta_sem, fliplr(theta_mean+theta_sem)]', ...
     [0.5 0.5 0.5], 'EdgeColor','none', 'FaceAlpha', 0.5);

h1 = plot(tGrid, theta_mean, 'k', 'LineWidth', 2);
ylabel('Theta power ');

yyaxis right; hold on;

% SEM band (velocity)
fill([tGrid; flipud(tGrid)], ...
     [vel_mean-vel_sem, fliplr(vel_mean+vel_sem)]', ...
     [0.95 0.55 0.15], 'EdgeColor','none', 'FaceAlpha', 0.25);

h2 = plot(tGrid, vel_mean, 'LineWidth', 2);
ylabel('Velocity');

xlabel('Normalized time within trial (0=start, 1=end)');
title(['Session ' rat '-' ss ' | theta power & velocity (mean)']);
legend([h1 h2], {'Theta power', 'Velocity'}, 'Location', 'best');
