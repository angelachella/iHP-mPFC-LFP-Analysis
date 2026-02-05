
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

target = '774-16';
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


edges = 0:1:7;

figure;
h = histogram(ue_traveldistance, 'BinEdges', edges);
h.FaceColor = [0.6 0.3 0.8];   % 보라색
h.EdgeColor = 'none';
h.FaceAlpha = 0.6;  
xlim([0 7]);


xlabel('traveled distance (cm)');
ylabel('Count');

