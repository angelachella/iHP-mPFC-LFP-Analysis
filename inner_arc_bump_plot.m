% clc; clear; close all;
% 
% %% Root
% ROOT.Mother = 'D:';
% ROOT.Raw    = fullfile(ROOT.Mother,'1. Behavioral data');
% 
% today_is = datetime('today');
% today_is.Format = 'yyyy-MM-dd';
% today_is = char(today_is);
% 
% ROOT.Load = fullfile(ROOT.Raw,'results','outerCircle_first_bump_outward', today_is);
% 
% addpath(genpath(fullfile(ROOT.Mother, 'toolbox')));
% 
% %% Load
% load(fullfile(ROOT.Load, 'T_outerCircle_first_bump_outward.mat'), 'T_bump');
% 
% %% Maze / circle
% Maze.Outline.x = 0;
% Maze.Outline.y = 0;
% Maze.Outline.r = 0.9500;
% 
% InnerCircle.r = 0.6500;
% OuterCircle.r = 0.8000;
% 
% RewardZone.inner.r = 0.6500;
% RewardZone.outer.r = 0.8000;
% 
% %% ===== 선택할 세션 =====
% rat_sel = "817";
% ss_sel  = 11;
% 
% %% filter: 한 세션만
% idx_valid = T_bump.hit_found == true;
% idx_sess  = idx_valid & string(T_bump.rat) == rat_sel & T_bump.ss == ss_sel;
% 
% Tf = T_bump(idx_sess,:);
% 
% %% group 정의
% idx_green = (strcmpi(string(Tf.goal),"West") & Tf.start_direction == 90) | ...
%             (strcmpi(string(Tf.goal),"East") & Tf.start_direction == 270);
% 
% idx_purple = (strcmpi(string(Tf.goal),"West") & Tf.start_direction == 270) | ...
%              (strcmpi(string(Tf.goal),"East") & Tf.start_direction == 90);
% 
% fprintf('Session %s-%02d\n', rat_sel, ss_sel);
% fprintf('Green group : %d trials\n', sum(idx_green));
% fprintf('Purple group: %d trials\n', sum(idx_purple));
% 
% %% Plot
% f = figure('Color','w','Position',[100 100 560 480]);
% hold on;
% 
% % Maze outline
% p_Outline = Draw_Circle(Maze.Outline.x, Maze.Outline.y, Maze.Outline.r, 4);
% p_Outline.LineWidth = 0.75;
% p_Outline.Color = [0.2 0.2 0.2];
% 
% % % Inner circle
% % th = linspace(0, 2*pi, 400);
% % plot(InnerCircle.r*cos(th), InnerCircle.r*sin(th), '--', ...
% %     'Color',[0.35 0.6 0.35], 'LineWidth',1);
% 
% % Outer circle
% th = linspace(0, 2*pi, 400);
% plot(OuterCircle.r*cos(th), OuterCircle.r*sin(th), '--', ...
%     'Color',[0.35 0.6 0.35], 'LineWidth',1);
% 
% % Reward zone arcs
% p_in = Draw_AngledCircle(0,0, RewardZone.inner.r,2);
% p_in.LineWidth=1; p_in.LineStyle='-'; p_in.Color=[1 0 0];
% 
% p_out = Draw_AngledCircle(0,0, RewardZone.outer.r,2);
% p_out.LineWidth=1; p_out.LineStyle='-'; p_out.Color=[1 0 0];
% 
% plot([p_in.XData(1) p_out.XData(1)], [p_in.YData(1) p_out.YData(1)], 'r-', 'LineWidth',1);
% plot([p_in.XData(end) p_out.XData(end)], [p_in.YData(end) p_out.YData(end)], 'r-', 'LineWidth',1);
% 
% p_in2 = Draw_AngledCircle2(0,0, RewardZone.inner.r,1);
% p_in2.LineWidth=1; p_in2.Color=[0 0 1];
% 
% p_out2 = Draw_AngledCircle2(0,0, RewardZone.outer.r,1);
% p_out2.LineWidth=1; p_out2.Color=[0 0 1];
% 
% plot([p_in2.XData(1) p_out2.XData(1)], [p_in2.YData(1) p_out2.YData(1)], 'b-', 'LineWidth',1);
% plot([p_in2.XData(end) p_out2.XData(end)], [p_in2.YData(end) p_out2.YData(end)], 'b-', 'LineWidth',1);
% 
% % 초록색
% if any(idx_green)
%     scatter(Tf.hit_x(idx_green), Tf.hit_y(idx_green), 32, ...
%         'filled', ...
%         'MarkerFaceColor', [0.2 0.7 0.2], ...
%         'MarkerFaceAlpha', 0.45, ...
%         'MarkerEdgeAlpha', 0.2);
% end
% 
% % 보라색
% if any(idx_purple)
%     scatter(Tf.hit_x(idx_purple), Tf.hit_y(idx_purple), 32, ...
%         'filled', ...
%         'MarkerFaceColor', [0.55 0.3 0.8], ...
%         'MarkerFaceAlpha', 0.45, ...
%         'MarkerEdgeAlpha', 0.2);
% end
% 
% axis equal;
% axis off;
% title(sprintf('%s-%02d | first bump on inner circle | green=%d | purple=%d', ...
%     rat_sel, ss_sel, sum(idx_green), sum(idx_purple)));
% 
% %% Save
% saveas(f, fullfile(ROOT.Load, sprintf('distribution_%s_%02d_outer.png', rat_sel, ss_sel)));


% 
clc; clear; close all;

%% ===== Root =====
ROOT.Mother = 'D:';
ROOT.Raw    = fullfile(ROOT.Mother,'1. Behavioral data');

today_is = datetime('today');
today_is.Format = 'yyyy-MM-dd';
today_is = char(today_is);

% T_bump 불러올 폴더
ROOT.Load = fullfile(ROOT.Raw,'results','innerCircle_first_bump_outward', today_is);

% figure 저장 폴더
ROOT.Save = fullfile(ROOT.Raw,'results','innerCircle_first_bump_outward_png', today_is);
if ~exist(ROOT.Save,'dir')
    mkdir(ROOT.Save);
end

%% ===== Load T_bump =====
load(fullfile(ROOT.Load, 'T_innerCircle_first_bump_outward.mat'), 'T_bump');

% %% ===== Maze / reward zone parameters =====
% Maze.Outline.x = 0;
% Maze.Outline.y = 0;
% Maze.Outline.r = 0.9500;
% 
% RewardZone.inner.r = 0.6500;
% RewardZone.outer.r = 0.8000;
% 
% %% ===== Unique rat-session list =====
% sess_keys = unique(T_bump(:,{'rat','ss'}), 'rows');
% 
% %% ===== Loop over rat-session =====
% for k = 1:height(sess_keys)
% 
%     rat_k = string(sess_keys.rat(k));
%     ss_k  = sess_keys.ss(k);
% 
%     idx_sess = (string(T_bump.rat) == rat_k) & (T_bump.ss == ss_k);
%     Ts = T_bump(idx_sess, :);
% 
%     if isempty(Ts)
%         continue;
%     end
% 
%     %% ===== Figure =====
%     f = figure('Color','w','Position',[100 100 500 500]);
%     hold on
% 
%     % Maze outline
%     p_Outline = Draw_Circle(Maze.Outline.x, Maze.Outline.y, Maze.Outline.r, 4);
%     p_Outline.LineWidth = 0.75;
%     p_Outline.Color     = [0.2 0.2 0.2];
% 
%     % Inner circle
%     th = linspace(0, 2*pi, 500);
%     x_in = RewardZone.inner.r * cos(th);
%     y_in = RewardZone.inner.r * sin(th);
%     plot(x_in, y_in, '--', 'Color', [0.4 0.7 0.4], 'LineWidth', 1.2);
% 
%     % % Outer circle 
%     % th = linspace(0, 2*pi, 500);
%     % x_in = RewardZone.outer.r * cos(th);
%     % y_in = RewardZone.outer.r * sin(th);
%     % plot(x_in, y_in, '--', 'Color', [0.4 0.7 0.4], 'LineWidth', 1.2);
% 
%     % Start point at maze centre
%     plot(0, 0, 'k+', 'MarkerSize', 12, 'LineWidth', 1.5);
% 
%     %% ===== Reward zone arcs =====
%     p_in = Draw_AngledCircle(0,0, RewardZone.inner.r,2);
%     p_in.LineWidth = 1;
%     p_in.LineStyle = '-';
% 
%     p_out = Draw_AngledCircle(0,0, RewardZone.outer.r,2);
%     p_out.LineWidth = 1;
%     p_out.LineStyle = '-';
% 
%     plot([p_in.XData(1)   p_out.XData(1)],   [p_in.YData(1)   p_out.YData(1)],   'r-', 'LineWidth',1);
%     plot([p_in.XData(end) p_out.XData(end)], [p_in.YData(end) p_out.YData(end)], 'r-', 'LineWidth',1);
% 
%     p_in2 = Draw_AngledCircle2(0,0, RewardZone.inner.r,1);
%     p_in2.LineWidth = 1;
% 
%     p_out2 = Draw_AngledCircle2(0,0, RewardZone.outer.r,1);
%     p_out2.LineWidth = 1;
% 
%     plot([p_in2.XData(1)   p_out2.XData(1)],   [p_in2.YData(1)   p_out2.YData(1)],   'b-', 'LineWidth',1);
%     plot([p_in2.XData(end) p_out2.XData(end)], [p_in2.YData(end) p_out2.YData(end)], 'b-', 'LineWidth',1);
% 
%     %% ===== Plot actual T_bump points =====
%     for ii = 1:height(Ts)
% 
%         x = Ts.hit_x(ii);
%         y = Ts.hit_y(ii);
% 
%         if isnan(x) || isnan(y)
%             continue;
%         end
% 
%         goal_i = string(Ts.goal(ii));
%         sd_i   = Ts.start_direction(ii);
% 
%         is_green = (strcmpi(goal_i,'West') && sd_i == 90) || ...
%                    (strcmpi(goal_i,'East') && sd_i == 270);
% 
%         is_purple = (strcmpi(goal_i,'West') && sd_i == 270) || ...
%                     (strcmpi(goal_i,'East') && sd_i == 90);
% 
%         if is_green
%             plot(x, y, 'o', ...
%                 'MarkerSize', 6, ...
%                 'MarkerFaceColor', [0.5 0.8 0.5], ...
%                 'MarkerEdgeColor', [0.5 0.8 0.5]);
%         elseif is_purple
%             plot(x, y, 'o', ...
%                 'MarkerSize', 6, ...
%                 'MarkerFaceColor', [0.65 0.45 0.85], ...
%                 'MarkerEdgeColor', [0.65 0.45 0.85]);
%         end
%     end
% 
%      title(sprintf('Rat %s  |  Session %02d', rat_k, ss_k), ...
%         'FontWeight','normal', 'FontSize', 11);
% 
% 
%     %% ===== Save =====
%     save_name = sprintf('rat%s_ss%02d.png', char(rat_k), ss_k);
%     exportgraphics(f, fullfile(ROOT.Save, save_name), 'Resolution', 300);
% 
%     close(f);
% end
% 
% fprintf('Done. All session PNG files saved to:\n%s\n', ROOT.Save);
% 
% 
% 
% 
% %% Valid rows
% idx_valid = ~isnan(T_bump.hit_angle_deg) & ~isnan(T_bump.start_direction);
% Tb = T_bump(idx_valid,:);
% 
% goal_str = string(Tb.goal);
% sd       = Tb.start_direction;
% ang      = Tb.hit_angle_deg;
% 
% %% Group definition
% idx_green = (strcmpi(goal_str,'East') & sd == 270);
% idx_purple = (strcmpi(goal_str,'East') & sd == 90);
% 
% ang_green  = ang(idx_green);
% ang_purple = ang(idx_purple);
% 
% %% Histogram
% binEdges = 0:10:360;
% 
% f = figure('Color','w','Position',[100 100 700 500]);
% hold on
% 
% histogram(ang_green, binEdges, ...
%     'FaceColor',[0.5 0.8 0.5], ...
%     'EdgeColor','none', ...
%     'FaceAlpha',0.6);
% 
% histogram(ang_purple, binEdges, ...
%     'FaceColor',[0.65 0.45 0.85], ...
%     'EdgeColor','none', ...
%     'FaceAlpha',0.6);
% 
% % histogram(ang_green,  binEdges, ...
% %     'Normalization','probability', ...
% %     'FaceColor',[0.5 0.8 0.5], ...
% %     'EdgeColor','none', ...
% %     'FaceAlpha',0.5);
% % 
% % histogram(ang_purple, binEdges, ...
% %     'Normalization','probability', ...
% %     'FaceColor',[0.65 0.45 0.85], ...
% %     'EdgeColor','none', ...
% %     'FaceAlpha',0.5);
% 
% xlim([0 360])
% xticks(0:45:360)
% xlabel('Head direction at first bump (outer)')
% ylabel('Count')
% legend({'difficult,' 'easy'}, 'Location','best')
% box off
% set(gca,'TickDir','out')
% title('All rats / Goal East')



%% Rose plot + MVL 
%% ===== User-defined rats =====
rat_sel = ["817"];   % <- 여기서 원하는 rat 지정

%% ===== User-defined sessions =====
pre_sessions      = [2 3];
learning_sessions = [4 5];
post_sessions     = [6 7];

%% ===== Valid rows =====
idx_valid = ~isnan(T_bump.hit_angle_deg) & ~isnan(T_bump.start_direction);

% rat filter
idx_rat = ismember(string(T_bump.rat), rat_sel);

Tb = T_bump(idx_valid & idx_rat, :);

%% ===== Variables =====
goal = string(Tb.goal);
sd   = Tb.start_direction;
ang  = Tb.hit_angle_deg;
ss   = Tb.ss;

%% ===== Trial type definition =====
idx_difficult = (strcmpi(goal,'West') & sd == 90) | ...
                (strcmpi(goal,'East') & sd == 270);

idx_easy = (strcmpi(goal,'West') & sd == 270) | ...
           (strcmpi(goal,'East') & sd == 90);

%% ===== Stage definition =====
idx_pre      = ismember(ss, pre_sessions);
idx_learning = ismember(ss, learning_sessions);
idx_post     = ismember(ss, post_sessions);

%% ===== Extract angles =====
% difficult
ang_pre_diff      = deg2rad(ang(idx_pre      & idx_difficult));
ang_learning_diff = deg2rad(ang(idx_learning & idx_difficult));
ang_post_diff     = deg2rad(ang(idx_post     & idx_difficult));

% easy
ang_pre_easy      = deg2rad(ang(idx_pre      & idx_easy));
ang_learning_easy = deg2rad(ang(idx_learning & idx_easy));
ang_post_easy     = deg2rad(ang(idx_post     & idx_easy));

%% ===== Helper functions =====
calc_mvl = @(a) local_mvl(a);
calc_mu  = @(a) local_mean_angle(a);

%% ===== Compute MVL =====
mvl_pre_diff      = calc_mvl(ang_pre_diff);
mvl_learning_diff = calc_mvl(ang_learning_diff);
mvl_post_diff     = calc_mvl(ang_post_diff);

mvl_pre_easy      = calc_mvl(ang_pre_easy);
mvl_learning_easy = calc_mvl(ang_learning_easy);
mvl_post_easy     = calc_mvl(ang_post_easy);

%% ===== Compute mean angle =====
mu_pre_diff      = calc_mu(ang_pre_diff);
mu_learning_diff = calc_mu(ang_learning_diff);
mu_post_diff     = calc_mu(ang_post_diff);

mu_pre_easy      = calc_mu(ang_pre_easy);
mu_learning_easy = calc_mu(ang_learning_easy);
mu_post_easy     = calc_mu(ang_post_easy);

%% ===== Plot =====
binEdges = deg2rad(0:20:360);

f = figure('Color','w','Position',[100 100 1200 700]);

titles_stage = {'Pre','Learning','Post'};

% ================= Difficult =================
data_diff = {ang_pre_diff, ang_learning_diff, ang_post_diff};
mu_diff   = [mu_pre_diff, mu_learning_diff, mu_post_diff];
mvl_diff  = [mvl_pre_diff, mvl_learning_diff, mvl_post_diff];

for i = 1:3
    subplot(2,3,i)
    polarhistogram(data_diff{i}, binEdges, ...
        'FaceColor',[0.5 0.8 0.5], ...
        'EdgeColor','k', ...
        'FaceAlpha',0.7);
    hold on

    if ~isempty(data_diff{i})
        rl = rlim;
        rmax = rl(2);
        polarplot([mu_diff(i) mu_diff(i)], [0 mvl_diff(i)*rmax], ...
            'r-', 'LineWidth', 2);
    end

    title(sprintf('Difficult - %s\nn=%d, MVL=%.3f', ...
        titles_stage{i}, numel(data_diff{i}), mvl_diff(i)));
end

% ================= Easy =================
data_easy = {ang_pre_easy, ang_learning_easy, ang_post_easy};
mu_easy   = [mu_pre_easy, mu_learning_easy, mu_post_easy];
mvl_easy  = [mvl_pre_easy, mvl_learning_easy, mvl_post_easy];

for i = 1:3
    subplot(2,3,i+3)
    polarhistogram(data_easy{i}, binEdges, ...
        'FaceColor',[0.65 0.45 0.85], ...
        'EdgeColor','k', ...
        'FaceAlpha',0.7);
    hold on

    if ~isempty(data_easy{i})
        rl = rlim;
        rmax = rl(2);
        polarplot([mu_easy(i) mu_easy(i)], [0 mvl_easy(i)*rmax], ...
            'r-', 'LineWidth', 2);
    end

    title(sprintf('Easy - %s\nn=%d, MVL=%.3f', ...
        titles_stage{i}, numel(data_easy{i}), mvl_easy(i)));
end

sgtitle(sprintf('Inner circle hit angle distribution | Rats: %s', strjoin(cellstr(rat_sel), ', ')))

%% ===== Local functions =====
function r = local_mvl(alpha)
    if isempty(alpha)
        r = NaN;
        return;
    end
    r = abs(mean(exp(1i*alpha)));
end

function mu = local_mean_angle(alpha)
    if isempty(alpha)
        mu = NaN;
        return;
    end
    mu = angle(mean(exp(1i*alpha)));
    if mu < 0
        mu = mu + 2*pi;
    end
end