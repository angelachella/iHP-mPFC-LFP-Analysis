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

target = '774-10';
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
n = 2;                  % 몇 MAD 기준인지

med = median(latency);
mad_val = mad(latency, 1);    % (median(|x - median(x)|)

threshold_l = med + n * mad_val;

% travel distance
travel_distance = ue_traveldistance;
n = 2;                  % 몇 MAD 기준인지

med = median(travel_distance);
mad_val = mad(travel_distance, 1);    % (median(|x - median(x)|)

threshold_td = med + n * mad_val;

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

% time
t = 0;
trial_time = [];
for i = 1:NumberofTrial
    if ue_performance_available(i) ~= 1
        continue;
    end

    %  if ue_start_direction(i) ~= 90 
    %      continue;
    %  end
    % 
    % if ue_t.performance(i) ~=1
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

%% parameters

nBin   = 100;

nTrial = size(trial_time,1);

ThetaBin = nan(nTrial, nBin);   % trial x bin
VelBin   = nan(nTrial, nBin);

% trial loop: binning

for i = 1:nTrial

    tS = trial_time(i,1);
    tE = trial_time(i,2);
    if tE <= tS, continue; end

    % (1) theta power (LFP)
    [~, idxS] = min(abs(thetaband_iHP.timestamp - tS));
    [~, idxE] = min(abs(thetaband_iHP.timestamp - tE));
    if idxE <= idxS, continue; end

    x = double(thetaband_iHP.eeg(idxS:idxE));
    theta_env = abs(hilbert(x));
    %theta_env = smoothdata(theta_env, "gaussian", wTheta);

    % normalized time (0-1)
    tt_theta = linspace(0,1,numel(theta_env));

    % bin edges
    edges = linspace(0,1,nBin+1);

    for b = 1:nBin
        inBin = tt_theta >= edges(b) & tt_theta < edges(b+1);
        if any(inBin)
            ThetaBin(i,b) = mean(theta_env(inBin),'omitnan');
        end
    end

    % (2) velocity

    [~, rS] = min(abs(tick_timestamp - tS));
    [~, rE] = min(abs(tick_timestamp - tE));
    if rE <= rS, continue; end

    v = double(encoder_velocity(rS:rE));
    if numel(v) < 2, continue; end

    %v = smoothdata(v, "gaussian", wVel);

   tt_vel = linspace(0,1,numel(v));
edges  = linspace(0,1,nBin+1);

for b = 1:nBin
    inBin = tt_vel >= edges(b) & tt_vel < edges(b+1);
    if any(inBin)
        v_bin_mean = mean(v(inBin), 'omitnan');   % 먼저 bin 평균

        if v_bin_mean <= 5
            VelBin(i,b) = NaN;                   % 5 이하이면 이 bin 제외
        else
            VelBin(i,b) = v_bin_mean;
        end
    end
end
ThetaBin(i, isnan(VelBin(i,:))) = NaN;
end


% mean & SEM across trials

theta_mean = mean(ThetaBin, 1, 'omitnan');
vel_mean   = mean(VelBin,   1, 'omitnan');

theta_sem  = std(ThetaBin, 0, 1, 'omitnan') ./ sqrt(sum(~isnan(ThetaBin),1));
vel_sem    = std(VelBin,   0, 1, 'omitnan') ./ sqrt(sum(~isnan(VelBin),1));

xBin = linspace(0,1,nBin);

[r, p] = corr(theta_mean(:), vel_mean(:), 'Type','Pearson', 'Rows','complete');


% % plotting (dual y-axis)
% 
% fig = figure('Color','w'); box off;
% 
% yyaxis left; hold on;
% fill([xBin fliplr(xBin)], ...
%      [theta_mean-theta_sem fliplr(theta_mean+theta_sem)], ...
%      [0.5 0.5 0.5], 'EdgeColor','none', 'FaceAlpha',0.4);
% h1 = plot(xBin, theta_mean, 'k', 'LineWidth',2);
% ylabel('Theta power');
% 
% yyaxis right; hold on;
% fill([xBin fliplr(xBin)], ...
%      [vel_mean-vel_sem fliplr(vel_mean+vel_sem)], ...
%      [0.95 0.55 0.15], 'EdgeColor','none', 'FaceAlpha',0.25);
% h2 = plot(xBin, vel_mean, 'LineWidth',2);
% ylabel('Velocity');
% 
% xlabel('Normalized time within trial');
% title(['Session ' rat '-' ss ' | theta power & velocity (100-bin average)']);
% legend([h1 h2], {'Theta power','Velocity'}, 'Location','best');
% 
% fig = gcf;
% fname = fullfile(ROOT.Save, ['theta_vs_velocity_North(iHP)' target '.png']);
% saveas(fig, fname);
% 







% %% plot
% w = 2000;
% trialsPerFig = 40;
% 
% DO_Tile_Colourbar = true;
% 
% [~, srt]  = sort(trial_time(:,3), 'ascend');
% trial_time = trial_time(srt, :);
% 
% nT   = size(trial_time,1);          % 세션이면 보통 120
% nFig = ceil(nT / trialsPerFig);     % 120이면 3
% 
% 
% % === 1 tile = 1 trial ===
% nCol = 5;                            % 5열 x 8행(=40) 추천
% nRow = ceil(trialsPerFig / nCol);
% 
% figW = 1200;
% figH = 2000;
% 
% 
% theta_all = [];
% saveDir = fullfile(ROOT.Save,['LE' rat]); 
% if ~exist([ROOT.Save '\LE' rat]); mkdir([ROOT.Save '\LE' rat]); end
% 
% for figIdx = 1:nFig
% 
%    s = (figIdx-1)*trialsPerFig + 1;
%    e = min(figIdx*trialsPerFig, nT);
%     kList = s:e;
% firstTrial = trial_time(s,3);
% lastTrial  = trial_time(e,3);
%     f = figure('Position',[50 50 figW figH]);
%     tl = tiledlayout(nRow, nCol, 'TileSpacing','compact', 'Padding','compact');
% 
%       for ii = 1:numel(kList)
% 
%         k = kList(ii);
%         origTrial = trial_time(k,3);
%         t0 = trial_time(k,1);
%         t1 = trial_time(k,2);
% 
%         ax = nexttile(tl);
%         hold(ax,'on');
% 
%     p_Outline=Draw_Circle(Maze.Outline.x,Maze.Outline.y,Maze.Outline.r,4); p_Outline.LineWidth=0.75;
%     p_arch=Draw_AngledCircle(0,0, RewardZone.inner.r,2); p_arch.LineWidth=1; p_arch.LineStyle='-';
%     p_arch=Draw_AngledCircle(0,0, RewardZone.outer.r,2); p_arch.LineWidth=1; p_arch.LineStyle='-';
%     p_house=Draw_AngledCircle2(0,0,RewardZone.inner.r,1); p_house.LineWidth=1; p_house.LineStyle='-';
%     p_house=Draw_AngledCircle2(0,0,RewardZone.outer.r,1); p_house.LineWidth=1; p_house.LineStyle='-';
% 
%         [~, idxStart] = min(abs(thetaband_iHP.timestamp - t0));
%         [~, idxEnd]   = min(abs(thetaband_iHP.timestamp - t1));
%         if idxEnd <= idxStart
%             continue;
%         end
% 
%         theta_seg = double(thetaband_iHP.eeg(idxStart:idxEnd));
%         tTheta    = double(thetaband_iHP.timestamp(idxStart:idxEnd));
%         theta_power = abs(hilbert(theta_seg));
%         theta_smoothed = smoothdata(theta_power, "gaussian", w);
% 
%         % trajectory indices
%         idx = (ue.trial == origTrial) & (ue.frame_ITI == 0) & (ue.rewardzone_arrival == 0);
%         if ~any(idx), continue; end
% 
%         X = ue.position_x(idx);
%         Y = ue.position_y(idx);
% 
%         tPos_tick = tick_timestamp(idx);
% 
%         [~, lfp_idx] = min(abs(tTheta(:).' - tPos_tick(:)), [], 2);
%         theta_on_traj = theta_smoothed(lfp_idx);
% 
%         scatter(ax, X, Y, 18, theta_on_traj, 'filled');
% 
%         axis(ax,'equal'); axis(ax,'tight');
%         set(ax,'XTick',[],'YTick',[]);
% 
%         % trial 번호 표시
%         title(ax, sprintf('Trial %d', origTrial), 'FontSize', 10, 'FontWeight','bold');
% 
%         colormap(ax, jet);
% 
%         % trial마다 스케일
%         if ~isempty(theta_on_traj)
%             cax = prctile(theta_on_traj, [5 95]);
%             if diff(cax)==0, cax = [cax(1)-eps, cax(2)+eps]; end
%             caxis(ax, cax);
%         end
% 
%         if DO_Tile_Colourbar
%             cb = colorbar(ax, 'Location','eastoutside');
%             cb.FontSize = 7;
%             cb.TickDirection = 'out';
%         end
%     end
% 
%     title(tl, sprintf('%s | Trials %d-%d', target, trial_time(s,3), trial_time(e,3)));
%     outName = sprintf('%s_mPFC%03d-%03d_fig%02d.jpg', target, firstTrial, lastTrial, figIdx);
% exportgraphics(f, fullfile(saveDir, outName), 'Resolution', 300);
% close(f);
% end

