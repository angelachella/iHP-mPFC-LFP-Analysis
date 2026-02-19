%%
clc;
clear;
close all;

%% Root setting

ROOT.Mother = 'D:';
ROOT.Raw = [ROOT.Mother '\1. Behavioral data'];
ROOT.Info = [ROOT.Raw '\info'];

ROOT.Data = [ROOT.Raw '\results\behavior\15-May-2024\'];   
ROOT.Save = [ROOT.Raw '\results\figures\trajectory & velocity'];
if ~exist(ROOT.Save); mkdir(ROOT.Save); end

today = char(datetime('today'));

%% Load session info

load([ROOT.Info '\session_info.mat']);

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
% 
% %% Correctness across sessions
% 
% rat_list = {'774', '779', '780', '781', '816', '817'};
% 
% correctness = struct();
% % rat data loop
% for r = 1:length(rat_list)
%     rat_ss = session_list(strcmp(session_list.rat,rat_list{r}),:);
%     correctness.(['LE' rat_list{r}]) = zeros(size(rat_ss,1),3); %N start, S start, performance available==1
% 
%     % session loop 
%     for s = 1:size(rat_ss,1)
%         rat = rat_ss.rat{s};
%         ss = rat_ss.ss{s};
%         formattedSS = sprintf('%02d', str2double(ss));
% 
%         try    % load behavior data
%             load([ROOT.Data rat '-' formattedSS '.mat'], 'ue_t');
% %             ue_t_overall = ue_t(ue_t.performance_available==1,:);
% %             ue_t_north = ue_t_overall(ue_t_overall.start_direction==90,:);
% %             ue_t_south = ue_t_overall(ue_t_overall.start_direction==270,:);
%             ue_t_overall = ue_t;
%             ue_t_north = ue_t(ue_t.start_direction==90,:);
%             ue_t_south = ue_t(ue_t.start_direction==270,:);
%             % north start
%             correctness.(['LE' rat_list{r}])(s,1) = sum(ue_t_north.performance==1) / size(ue_t_north,1) * 100;
%             % south start
%             correctness.(['LE' rat_list{r}])(s,2) = sum(ue_t_south.performance==1) / size(ue_t_south,1) * 100;
%             % overall
%             correctness.(['LE' rat_list{r}])(s,3) = sum(ue_t_overall.performance==1) / size(ue_t_overall,1) * 100;
%         catch   % no behavior data
%             % north start
%             correctness.(['LE' rat_list{r}])(s,1) = nan;
%             % south start
%             correctness.(['LE' rat_list{r}])(s,2) = nan;
%             % overall
%             correctness.(['LE' rat_list{r}])(s,3) = nan;
% 
%             disp([ROOT.Data rat '-' formattedSS '.mat: No such file'])
%         end
%     end
%     correctness.(['LE' rat_list{r}])(all(isnan(correctness.(['LE' rat_list{r}])),2),:) = [];
% end
% 
% % plot
% north_color = [1 0 0]; %red
% south_color = [0 0.4470 0.7410]; %blue
% f1 = figure('Position',[100,100,1500,500]);
% 
% for r = 1:length(rat_list)
%     this_rat = ['LE' rat_list{r}];
%     subplot(2,3,r)
%     plot(1:length(correctness.(this_rat)(:,1)), correctness.(this_rat)(:,1), '-o', 'LineWidth',1, 'Color',north_color, ...
%         'MarkerSize',3, 'MarkerEdgeColor',north_color, 'MarkerFaceColor',north_color); hold on;
%     plot(1:length(correctness.(this_rat)(:,2)), correctness.(this_rat)(:,2), '-o', 'LineWidth',1, 'Color',south_color, ...
%         'MarkerSize',3, 'MarkerEdgeColor',south_color, 'MarkerFaceColor',south_color); hold on;
%     plot(1:length(correctness.(this_rat)(:,3)), correctness.(this_rat)(:,3), '-o', 'LineWidth',2, 'Color',[0 0 0], ...
%         'MarkerSize',4, 'MarkerEdgeColor',[0 0 0], 'MarkerFaceColor',[0 0 0]); hold on;
%     title(this_rat)
%     xticks(1:length(correctness.(this_rat)));
%     xlabel('Session')
%     yticks(0:50:100); ylim([0 100]);
%     ylabel('% Correct');
%     yline(50, ':', 'Chance level');
% 
%     if r==1
%     % legend({'North (red)','South (blue)','Overall'}, ...
%     %        'Location','southoutside','Orientation','horizontal');
% end
% end
% exportgraphics(f1,[ROOT.Save '\abc.pdf'], 'ContentType', 'vector');
% end
% 
% %% Average correctness (aligned to the reversal day)
% 
% rat_list = {'774', '779', '780', '781', '816', '817'};
% 
% correctness = zeros(length(rat_list), 8); %reversal기준 세션포인트 개수지정
% latency = zeros(length(rat_list), 8);
% travel_distance = zeros(length(rat_list), 8);
% 
% for r = 1:length(rat_list)
%     rat = rat_list{r};
% 
%     East_ss = session_list(strcmp(session_list.rat, rat)& ...
%         strcmp(session_list.goal,'East')&strcmp(session_list.stage,'Pre'),2);
% 
%     reversal_ss = min(str2double(East_ss.ss));
%     target_ss = reversal_ss-4:reversal_ss+3;
% 
%     for s = 1:length(target_ss)
%         ss = target_ss(s);
%         formattedSS = sprintf('%02d', ss);
%         try    % load behavior data
%             load([ROOT.Data rat '-' formattedSS '.mat'], 'ue_t');
%             ue_t_overall = ue_t(ue_t.start_direction==270,:);
%             % ue_t_overall = ue_t;
%             correctness(r,s) = sum(ue_t_overall.performance==1) / size(ue_t_overall,1) * 100;
%             latency(r,s) = median(ue_t_overall.latency);
%             travel_distance(r,s) = mean(ue_t_overall.travaled_distance);
%         catch   % no behavior data
%             correctness(r,s) = nan;
%             latency(r,s) = nan;
%             travel_distance(r,s) = nan;
%             disp([ROOT.Data rat '-' formattedSS '.mat: No such file'])
%         end
%     end
% end
% 
% for i = 1:8
%     correctness_sem(i) = sem(correctness(:,i));
%     latency_sem(i) = sem(latency(:,i));
%     distance_sem(i) = sem(travel_distance(:,i));
% end
% 
% f2 = figure('Position',[100,100,600,400]);
% % bar(1:8, mean(mean_correctness,2));
% errorbar(mean(correctness), correctness_sem);
% xticks(1:8);
% xticklabels({'-4', '-3', '-2', '-1', '0', '+1', '+2', '+3'});
% xlim([0 9]);
% xlabel('Day');
% yticks([0 50 100]);
% ylim([0 100]);
% ylabel('Correctness');
% 
% f3 = figure('Position',[100,100,1200,400]);
% subplot(1,2,1);
% errorbar(mean(latency), latency_sem, '-o','MarkerSize',6,'LineWidth',1.2);
% ylabel('Latency (s)');
% xticks(1:8);
% xticklabels({'-4','-3','-2','-1','0','+1','+2','+3'});
% xlim([0 9]);
% xlabel('Day');
% 
% subplot(1,2,2);
% errorbar(mean(travel_distance), distance_sem, '-s','MarkerSize',6,'LineWidth',1.2);
% ylabel('Travel distance (cm)');
% xticks(1:8);
% xticklabels({'-4','-3','-2','-1','0','+1','+2','+3'});
% xlim([0 9]);
% xlabel('Day');
% 
% exportgraphics(f2,[ROOT.Save '\average_corr_lat_dist.pdf'], 'ContentType', 'vector');
% 
% %% Comparing performance between Pre and Post
% 
% rat_list = {'774', '779', '780', '781', '816', '817'};
% 
% West_correctness = zeros(length(rat_list), 3);
% East_correctness = zeros(length(rat_list), 3);
% 
% for r = 1:length(rat_list)
%     rat = rat_list{r};
% 
%     West_post = session_list.ss(strcmp(session_list.rat, rat)& ...
%         strcmp(session_list.goal,'West')&strcmp(session_list.stage,'Post'));
%     West_post_first = str2double(West_post{1});
% 
%     East_post = session_list.ss(strcmp(session_list.rat, rat)& ...
%         strcmp(session_list.goal,'East')&strcmp(session_list.stage,'Post'));
%     East_post_first = str2double(East_post{1});
% 
%     % West
%     West_ss = West_post_first-1:West_post_first+1;
%     for s = 1:3
%         ss = West_ss(s);
%         formattedSS = sprintf('%02d', ss);
%         load([ROOT.Data rat '-' formattedSS '.mat'], 'ue_t');
%         %ue_t_overall = ue_t(ue_t.performance_available==1,:);
%         ue_t_overall = ue_t;
%         West_correctness(r,s) = sum(ue_t_overall.performance==1) / size(ue_t_overall,1) * 100;
%     end
% 
%     % East
%     East_ss = East_post_first-1:East_post_first+1;
%     for s = 1:3
%         ss = East_ss(s);
%         formattedSS = sprintf('%02d', ss);
%         load([ROOT.Data rat '-' formattedSS '.mat'], 'ue_t');
%         %ue_t_overall = ue_t(ue_t.performance_available==1,:);
%         ue_t_overall = ue_t;
%         East_correctness(r,s) = sum(ue_t_overall.performance==1) / size(ue_t_overall,1) * 100;
%     end
% end
% 
% for i = 1:3
%     West_correctness_sem(i) = sem(West_correctness(:,i));
%     East_correctness_sem(i) = sem(East_correctness(:,i));
% end
% 
% f4 = figure('Position',[100,100,1200,400]);
% % West
% subplot(1,2,1);
% bar(1:3, mean(West_correctness)); hold on;
% errorbar(mean(West_correctness), West_correctness_sem, '-o','MarkerSize',6,'LineWidth',1.2);
% ylabel('Correctness');
% xticks(1:3);
% xticklabels({'post-1','post','post+1'});
% xlim([0 4]);
% xlabel('Day');
% title('West');
% % ANOVA
% T = array2table(West_correctness, 'VariableNames', {'Day1','Day2','Day3'});
% Meas = table(categorical([1;2;3]), 'VariableNames', {'Day'});
% rm = fitrm(T, 'Day1-Day3 ~ 1', 'WithinDesign', Meas);
% ranovatbl = ranova(rm, 'WithinModel', 'Day')
% [~, p1, ~, stat1] = ttest(T.Day1, T.Day2);
% [~, p2, ~, stat2] = ttest(T.Day2, T.Day3);
% 
% posthoc = multcompare(rm, 'Day', 'ComparisonType', 'bonferroni')
% 
% % East
% subplot(1,2,2);
% bar(1:3, mean(East_correctness)); hold on;
% errorbar(mean(East_correctness), East_correctness_sem, '-o','MarkerSize',6,'LineWidth',1.2);
% ylabel('Correctness');
% xticks(1:3);
% xticklabels({'post-1','post','post+1'});
% xlim([0 4]);
% xlabel('Day');
% title('East');
% % ANOVA
% T = array2table(East_correctness, 'VariableNames', {'Day1','Day2','Day3'});
% Meas = table(categorical([1;2;3]), 'VariableNames', {'Day'});
% rm = fitrm(T, 'Day1-Day3 ~ 1', 'WithinDesign', Meas);
% ranovatbl = ranova(rm, 'WithinModel', 'Day')
% [~, p1, ~, stat1] = ttest(T.Day1, T.Day2);
% [~, p2, ~, stat2] = ttest(T.Day2, T.Day3);
% 
% exportgraphics(f4,[ROOT.Save '\average_corr.pdf'], 'ContentType', 'vector');
% 

%% Trajectory examples (single_session)
addpath(genpath(fullfile(ROOT.Mother, 'toolbox'))); %toolbox 경로추가

target = '774-12';
temp = split(target, '-');
rat = temp{1};
ss = num2str(str2double(temp{2}));


    goal = session_list.goal(3);
    stage = session_list.stage(4);

        load([ROOT.Data target '.mat']);    

        f = figure('Position',[100,100,450,400]);

        p_Outline=Draw_Circle(Maze.Outline.x,Maze.Outline.y,Maze.Outline.r,4); hold on; p_Outline.LineWidth=0.75;
        % c1 = plot(0, 0,'*'); hold on; c1.MarkerSize=8; c1.Color='b';
        for i = 1:size(ue_t,1)
            if ue_t.performance_available(i)==1 
                X = ue.position_x(ue.trial == i & ue.frame_ITI == 0 & ue.rewardzone_arrival == 0);
                Y = ue.position_y(ue.trial == i & ue.frame_ITI == 0 & ue.rewardzone_arrival == 0);

                p1=plot(X, Y); hold on; if ~isempty(p1); p1.LineWidth=1; p1.LineStyle='-'; p1.Color = [0.7 0.7 0.7]; end
                p_SceneNavigation_end=plot(X(end),Y(end),'r.'); p_SceneNavigation_end.MarkerSize=14; hold on;
            end
        end
        axis off; title([target]);

        p_arch=Draw_AngledCircle(0,0, RewardZone.inner.r,2); p_arch.LineWidth=1; p_arch.LineStyle='-';
        p_arch=Draw_AngledCircle(0,0, RewardZone.outer.r,2); p_arch.LineWidth=1; p_arch.LineStyle='-';
        p_house=Draw_AngledCircle2(0,0,RewardZone.inner.r,1); p_house.LineWidth=1; p_house.LineStyle='-';
        p_house=Draw_AngledCircle2(0,0,RewardZone.outer.r,1); p_arch.LineWidth=1; p_arch.LineStyle='-';


        if ~exist([ROOT.Save 'LE' rat]); mkdir([ROOT.Save 'LE' rat]); end
        exportgraphics(f,[ROOT.Save 'LE' rat '\' target 'North.pdf'], 'ContentType', 'vector');
        exportgraphics(f,[ROOT.Save 'LE' rat '\' target 'North.jpg'], 'Resolution', 300);

        close all;

% 
% 
% 
% % trialPerBlock = 40;
% % nBlockstoPlot = 3;
% acq_sessions = find(session_list.acquisition == 1); 
% for sIdx = 1:numel(acq_sessions)
%     sess_id = acq_sessions(sIdx);
%     target   = session_list{sess_id,1};       % 예: '817-05'
%     temp     = split(target, '-');
%     rat      = temp{1};
%     ss       = num2str(str2double(temp{2}));
% 
% target = '816-02';
% temp = split(target, '-');
% rat = temp{1};
% ss = num2str(str2double(temp{2}));
% 
% matFile = fullfile(ROOT.Data, [target '.mat']);
% load(matFile);
% 
% nTrials = size(ue_t,1);% the number of trials 
% 
% 
% %f2 = figure('Position',[100,100,900,400]);
% f = figure('Position',[50 50 900 400], 'Color','w');   % 가로 폭 줄여서 원 사이 간격 좁힘
% 
% ROWS = 1;
% COLS = nTrials;
% tl = tiledlayout(f, ROWS, COLS, ...     % ← figure 핸들 f에 대해 layout 생성
%     'TileSpacing','none', ...           % 타일 사이 여백 최소
%     'Padding','none');                  % 바깥 패딩도 최소
% 
% sgtitle(sprintf('trajectories: Rat%s-%s (from trial %d)', ...
%         rat, ss), ...
%         'FontSize', 12);
% 
% for b = 1:nTrials
%     nexttile;
%     hold on;
% 
%  p_Outline = Draw_Circle(Maze.Outline.x, Maze.Outline.y, Maze.Outline.r, 4);
%     if isgraphics(p_Outline), p_Outline.LineWidth = 0.75; end
%     c1 = plot(0, 0, '*'); c1.MarkerSize = 8; c1.Color = 'b';  % centre
% 
%     % ---- 이 block 안의 모든 trial trajectory를 한 원 안에 그림 ----
%     for t = nTrials
%         idx = (ue.trial == t) & (ue.frame_ITI == 0) & (ue.rewardzone_arrival == 0);
% 
%         if any(idx)
%             X = ue.position_x(idx);
%             Y = ue.position_y(idx);
% 
%             p1 = plot(X, Y, '-');
%             if isgraphics(p1)
%                 p1.LineWidth = 1;
%                 p1.Color = [0.7 0.7 0.7];   % 원하면 여기서 색 바꿔도 됨
%             end
% 
%             % endpoint 표시 (원하면 지울 수 있음)
%             plot(X(end), Y(end), 'r.', 'MarkerSize', 8);
%         end
%     end
% 
%     % ---- reward zone 표시 (각 block마다 한 번씩) ----
%     p_arch = Draw_AngledCircle(0, 0, RewardZone.inner.r, 2);
%     if isgraphics(p_arch), p_arch.LineWidth = 1; end
%     p_arch = Draw_AngledCircle(0, 0, RewardZone.outer.r, 2);
%     if isgraphics(p_arch), p_arch.LineWidth = 1; end
% 
%     p_house = Draw_AngledCircle2(0, 0, RewardZone.inner.r, 1);
%     if isgraphics(p_house), p_house.LineWidth = 1; end
%     p_house = Draw_AngledCircle2(0, 0, RewardZone.outer.r, 1);
%     if isgraphics(p_house), p_house.LineWidth = 1; end
% 
%     axis equal off;
%     cx = Maze.Outline.x;
% cy = Maze.Outline.y;
% r  = Maze.Outline.r;
% 
% xlim([cx - r, cx + r]);
% ylim([cy - r, cy + r]);  
% axis off;
% 
% % ==== 각 trajectory 블록 위에 rat-ss 라벨 + trial 범위 ====
%         title(sprintf('Rat%s-%s  |  Trials %d–%d', ...
%             rat, ss, startTrial, endTrial), ...
%             'FontSize', 9);
% 
% end
% end
% 
% 
% % tile 제목
% title(sprintf('Trials %d–%d', startTrial, endTrial), 'FontSize', 10);
% 
% 
% end
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% %subplot(1,2,1);
% p_Outline=Draw_Circle(Maze.Outline.x,Maze.Outline.y,Maze.Outline.r,4); hold on; p_Outline.LineWidth=0.75;
% c1 = plot(0, 0,'*'); hold on; c1.MarkerSize=8; c1.Color='b'; % centre
% 
% idx = (ue.trial == t) & (ue.frame_ITI == 0) & (ue.rewardzone_arrival == 0); % data from each trial 
% 
%     if any(idx)
%         % x,y axis에 따른 path 
%         X = ue.position_x(idx);
%         Y = ue.position_y(idx);
% 
%         p1 = plot(X, Y, '-');
%         if isgraphics(p1)
%             p1.LineWidth = 1;
%             p1.Color = [0.7 0.7 0.7]; 
%         end
% 
%         % endpoint 표시
%         plot(X(end), Y(end), 'r.', 'MarkerSize', 10);
% 
%     end
% 
%     % 각각 reward zone 표시 
%     p_arch = Draw_AngledCircle(0,0, RewardZone.inner.r, 2);
%     if isgraphics(p_arch)
%         p_arch.LineWidth = 1; 
%         p_arch.LineStyle = '-';
%     end
%     p_arch = Draw_AngledCircle(0,0, RewardZone.outer.r, 2);
%     if isgraphics(p_arch)
%         p_arch.LineWidth = 1; 
%         p_arch.LineStyle = '-';
%     end
%     p_house = Draw_AngledCircle2(0,0, RewardZone.inner.r, 1);
%     if isgraphics(p_house)
%         p_house.LineWidth = 1; 
%         p_house.LineStyle = '-';
%     end
%     p_house = Draw_AngledCircle2(0,0, RewardZone.outer.r, 1);
%     if isgraphics(p_house)
%         p_house.LineWidth = 1; 
%         p_house.LineStyle = '-';
%     end
% 
% 
%     axis equal off;
% 
%     % 타일 제목: Trial 번호
%     title(sprintf('Trial %d', t), 'FontSize', 9);
% end
% 
% 
% 
% for i = 1:size(ue_t,1) % 1= trial_start
%     X = ue.position_x(ue.trial == i & ue.frame_ITI == 0 & ue.rewardzone_arrival == 0); 
%     Y = ue.position_y(ue.trial == i & ue.frame_ITI == 0 & ue.rewardzone_arrival == 0);
% 
%     p1=plot(X, Y); hold on; if ~isempty(p1); p1.LineWidth=1; p1.LineStyle='-'; p1.Color = [0.7 0.7 0.7]; end
%     p_SceneNavigation_end=plot(X(end),Y(end),'r.'); p_SceneNavigation_end.MarkerSize=14; hold on; 
% end
% axis off; title(['Raw Trajectory (' target ')']);
% 
% p_arch=Draw_AngledCircle(0,0, RewardZone.inner.r,2); p_arch.LineWidth=1; p_arch.LineStyle='-';
% p_arch=Draw_AngledCircle(0,0, RewardZone.outer.r,2); p_arch.LineWidth=1; p_arch.LineStyle='-';
% p_house=Draw_AngledCircle2(0,0,RewardZone.inner.r,1); p_house.LineWidth=1; p_house.LineStyle='-';
% p_house=Draw_AngledCircle2(0,0,RewardZone.outer.r,1); p_arch.LineWidth=1; p_arch.LineStyle='-';
% 
% 
% 
% 
% 
% 
% %% learning curve
% 
% target = '816-10';
% temp = split(target, '-');
% rat = temp{1};
% ss = num2str(str2double(temp{2}));
% 
% subplot(1,2,2);
% % performance = (ue_t.performance_available==1)&(ue_t.performance==1);
% % performance(ue_t.performance_available~=1) = [];
% % [Prob Cback] = LearningCurve_WinBugs(performance);
% load([ROOT.Info '\LE' rat '\MatFile\Performance_LE' rat '_Post-main_' ss '.mat']);
% 
% I=Performance';
% [h1, h2] = plotI(I, ones(1,length(I)));
% 
% learningCurve = Prob(:,3);
% n = length(learningCurve);
% 
% isPeak = false(n,1);
% for i = 2:n-1
%     if learningCurve(i) > learningCurve(i-1) && learningCurve(i) >= learningCurve(i+1)
%         isPeak(i) = true;
%     end
% end
% 
% peakTrials = find(isPeak);
% peakValues = learningCurve(peakTrials);
% 
% hold on;
% plot(peakTrials, peakValues, 'ro', 'MarkerSize', 6, 'LineWidth', 1.5);
% 
% for k = 1:length(peakTrials)
%     text(peakTrials(k), peakValues(k), sprintf(' %d', peakTrials(k)), ...
%         'VerticalAlignment', 'bottom', ...
%         'HorizontalAlignment', 'left', ...
%         'FontSize', 9, ...
%         'FontWeight', 'bold');
% end
% %     xlabel('Trial');
% ylabel('Performance')
% % title('Learning graph')
% plot(Prob(:,2),'k-'); hold on;
% plot(Prob(:,4),'k-');
% for i=1:size(Prob,1)-1
%     f1=fill([i i+1 i+1 i], [Prob(i,4) Prob(i+1,4) Prob(i+1,2) Prob(i,2)],'r'); f1.FaceColor=[0.75 0.75 0.75]; f1.FaceAlpha=1; f1.EdgeAlpha=0;
% end
% p1=plot(Prob(:,3),'r-'); hold on; p1.LineWidth=1;
% l1=line([0 length(Prob)], [0.5 0.5]); l1.Color='k'; l1.LineStyle='--';
% xticks([1 length(I)]);
% xlim([1 length(I)])
% ylim([0 1.1])
% xlabel('Trials');
% g=gca; g.FontSize=11;


%% trajectory sample with velocity for each session
addpath(genpath(fullfile(ROOT.Mother, 'toolbox'))); %toolbox 경로추가

target = '774-13';
temp = split(target, '-');
rat = temp{1};
ss = num2str(str2double(temp{2}));

load([ROOT.Data target '.mat']);

nTrials = size(ue_t, 1);

% session info
% correctness   
ue_t_overall = ue_t;
correctness = sum(ue_t_overall.performance==1) / size(ue_t_overall,1) * 100;
correctness_text = sprintf('correctness = %.1f%%', correctness);  

% rat-session, goal info
rat_text = sprintf('%s-%s', rat, ss);
goal_text = sprintf('goal: %s', string(session_list.goal(strcmp(session_list.rat,rat) & strcmp(session_list.ss,ss))));

saveDir = ROOT.Save;
if ~exist(saveDir,'dir'), mkdir(saveDir); end

Trials_per_fig = 40;
Trials_per_row = 5;
COLS = 2*Trials_per_row;

for figIdx = 1:3
    startTrial = (figIdx-1)*Trials_per_fig + 1;
    endTrial   = min(figIdx*Trials_per_fig, nTrials);
    trialIDs   = startTrial:endTrial;
    T          = numel(trialIDs);
    
    % nTrials가 작아서 이번 figure에 표시할 trial이 없으면, 빈 figure도 저장할지 여부
    % (원치 않으면 아래 if 블록에서 continue로 넘어가게 바꾸면 됨)
    if T == 0
        f2 = figure('Position',[20 20 1600 1000], 'Color','w');
        text(0.5,0.5,sprintf('No trials for Figure %d', figIdx), ...
            'Units','normalized','HorizontalAlignment','center');
        axis off

        outName = fullfile(saveDir, sprintf('%s_fig%d_trials%03d-%03d.pdf', target, figIdx, startTrial, min(figIdx*Trials_per_fig, nTrials)));
        exportgraphics(f2, outName, 'ContentType','image');
        close(f2);
        continue;
    end

    ROWS = ceil(T / Trials_per_row);

    f2 = figure('Position',[20 20 1600 1000], 'Color','w');
    tl = tiledlayout(ROWS, COLS, 'TileSpacing','compact', 'Padding','loose');

    top_title = sprintf('%s / %s / trials: %d / %s / Fig %d: %d-%d', ...
        rat_text, goal_text, nTrials, correctness_text, figIdx, startTrial, endTrial);
    title(tl, top_title, 'FontWeight', 'normal', 'FontSize', 14, 'Interpreter', 'none');

    % ====== trial loop ======
    for i = 1:T
        t = trialIDs(i);  % 실제 trial index
        % ---- trajectory tile ----
        nexttile; hold on;

        p_Outline = Draw_Circle(Maze.Outline.x, Maze.Outline.y, Maze.Outline.r, 4);
        if isgraphics(p_Outline), p_Outline.LineWidth = 0.75; end
        c1 = plot(0, 0, '*'); c1.MarkerSize = 6; c1.Color = 'b';

        idx_traj = (ue.trial == t) & (ue.frame_ITI == 0) & (ue.rewardzone_arrival == 0);

        if any(idx_traj)
            X = ue.position_x(idx_traj);
            Y = ue.position_y(idx_traj);

            p1 = plot(X, Y, '-');
            if isgraphics(p1)
                p1.LineWidth = 1;
                p1.Color = [0 0 0];
            end
            plot(X(end), Y(end), 'r.', 'MarkerSize', 10);
        else
            text(0.5, 0.5, 'No trajectory', 'Units','normalized', ...
                'HorizontalAlignment','center', 'Color',[0.4 0.4 0.4]);
        end

        % rewardzone
        a = Draw_AngledCircle(0,0, RewardZone.inner.r, 2); if isgraphics(a), a.LineWidth = 1; end
        a = Draw_AngledCircle(0,0, RewardZone.outer.r, 2); if isgraphics(a), a.LineWidth = 1; end
        h = Draw_AngledCircle2(0,0, RewardZone.inner.r, 1); if isgraphics(h), h.LineWidth = 1; end
        h = Draw_AngledCircle2(0,0, RewardZone.outer.r, 1); if isgraphics(h), h.LineWidth = 1; end

        axis equal off;

        % performance label
        if ue_t.performance(t) == 1
            perf_label = 'correct';
        elseif ue_t.performance(t) == 2
            perf_label = 'wrong';
        else
            perf_label = 'NA';
        end

        title({sprintf('Trial %d', t), sprintf('%s', perf_label)}, ...
            'FontSize', 9, 'Interpreter','none');

        % ---- velocity tile ----
        nexttile; hold on; box off;

        idx_vel = (ue.trial == t) & (ue.frame_ITI == 0);

        if any(idx_vel)
            sbin = find(idx_vel, 1, 'first');
            ts = ue.time(sbin);

            tt = ue.time(idx_vel) - ts;
            v  = ue.velocity_smoothed(idx_vel);

            plot(tt, v, '-', 'LineWidth', 1);
            xlabel('Time (s)');
            ylabel('Velocity (cm/s)');
            xlim([tt(1) tt(end)]);

            yl = ylim;
            ylim([0 max(yl(2), 5)]);
        else
            text(0.5, 0.5, 'No velocity', 'Units','normalized', ...
                'HorizontalAlignment','center', 'Color',[0.4 0.4 0.4]);
            axis off
        end
    end

    % ====== figure 저장 (각 figure 별 파일명 다르게) ======
    outName = fullfile(saveDir, sprintf('%s_fig%d_trials%03d-%03d.pdf', target, figIdx, startTrial, endTrial));
    exportgraphics(f2, outName, 'ContentType', 'image');

    close(f2);
end


























% 
% %layout
% Trials_per_row = 5;                  % 한 줄에 trial 5개 -> 총 10칸(2*5)
% COLS = 2 * Trials_per_row;
% ROWS = ceil(T / Trials_per_row);
% 
% scr = get(0,'ScreenSize');
% f2 = figure('Position',[20 20 1600 1000], 'Color','w');
% tl = tiledlayout(ROWS, COLS, 'TileSpacing','compact', 'Padding','loose'); %상단공백추가
% 
% 
% 
% % title
% top_title = sprintf('%s / %s / trials: %s / %s', rat_text, goal_text, num2str(nTrials), correctness_text);
% title(tl, top_title, 'FontWeight', 'normal', 'FontSize', 14, 'Interpreter', 'none');
% 
% 
% % trajectory
% 
% for i = 1:T
%     t = trialIDs(i) % trial 40 이후 출력할때만
%     nexttile; hold on;
% 
%     p_Outline = Draw_Circle(Maze.Outline.x, Maze.Outline.y, Maze.Outline.r, 4);
%     if isgraphics(p_Outline), p_Outline.LineWidth = 0.75; end
%     c1 = plot(0, 0, '*'); c1.MarkerSize = 6; c1.Color = 'b';
% 
%     idx_traj = (ue.trial == t) & (ue.frame_ITI == 0) & (ue.rewardzone_arrival == 0);
% 
%     if any(idx_traj)
%         X = ue.position_x(idx_traj);
%         Y = ue.position_y(idx_traj);
% 
%         p1 = plot(X, Y, '-');
%         if isgraphics(p1)
%             p1.LineWidth = 1;
%             p1.Color = [0 0 0];
%         end
%         % endpoint
%         plot(X(end), Y(end), 'r.', 'MarkerSize', 10);
%     else
%         text(0.5, 0.5, 'No trajectory', 'Units','normalized', ...
%              'HorizontalAlignment','center', 'Color',[0.4 0.4 0.4]);
%     end
% 
%     % rewardzone
%     a = Draw_AngledCircle(0,0, RewardZone.inner.r, 2); if isgraphics(a), a.LineWidth = 1; end
%     a = Draw_AngledCircle(0,0, RewardZone.outer.r, 2); if isgraphics(a), a.LineWidth = 1; end
%     h = Draw_AngledCircle2(0,0, RewardZone.inner.r, 1); if isgraphics(h), h.LineWidth = 1; end
%     h = Draw_AngledCircle2(0,0, RewardZone.outer.r, 1); if isgraphics(h), h.LineWidth = 1; end
% 
%     axis equal off;
% 
%     % trial의 performance (correct vs. wrong)
%     if ue_t.performance(t) == 1
%         perf_label = 'correct';
%     elseif ue_t.performance(t) == 2
%         perf_label = 'wrong';
%     else
%         perf_label = 'NA';
%     end
% 
% 
%  title({sprintf('Trial %d', t), sprintf('%s', perf_label)}, ...
%       'FontSize', 9, 'Interpreter','none');
% 
% % velocity
%     nexttile; hold on; box off;
% 
%     % velocity
%     idx_vel = (ue.trial == t) & (ue.frame_ITI == 0);
% 
%     if any(idx_vel)
%         % trial 시작 bin 찾기
%         sbin = find((ue.trial == t) & (ue.frame_ITI == 0), 1, 'first');
%         %sbin = find(idx_vel, 1, 'first'); % trial 40 이후 출력할 때만
%         ts = ue.time(sbin);
% 
%         % time을 trial start 기준으로(0초부터 시작)
%         tt = ue.time(idx_vel) - ts;
%         v = ue.velocity_smoothed(idx_vel);
% 
%         plot(tt, v, '-', 'LineWidth', 1);
%         xlabel('Time (s)');
%         ylabel('Velocity (cm/s)');
%         xlim([tt(1) tt(end)]);
% 
%         yl = ylim;
%         ylim([0 max(yl(2), 5)]);
%     else
%         text(0.5, 0.5, 'No velocity', 'Units','normalized', ...
%              'HorizontalAlignment','center', 'Color',[0.4 0.4 0.4]);
%         axis off
%     end
% 
% end
% 
% exportgraphics(f2,[ROOT.Save,  target '.pdf'], 'ContentType', 'image');
% 
