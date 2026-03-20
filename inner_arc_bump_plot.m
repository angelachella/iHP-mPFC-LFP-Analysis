clc; clear; close all;

%% Root
ROOT.Mother = 'D:';
ROOT.Raw    = fullfile(ROOT.Mother,'1. Behavioral data');

today_is = datetime('today');
today_is.Format = 'yyyy-MM-dd';
today_is = char(today_is);

ROOT.Load = fullfile(ROOT.Raw,'results','innerCircle_first_bump_outward', today_is);

addpath(genpath(fullfile(ROOT.Mother, 'toolbox')));

%% Load
load(fullfile(ROOT.Load, 'T_innerCircle_first_bump_outward.mat'), 'T_bump');

%% Maze / circle
Maze.Outline.x = 0;
Maze.Outline.y = 0;
Maze.Outline.r = 0.9500;

InnerCircle.r = 0.6500;

RewardZone.inner.r = 0.6500;
RewardZone.outer.r = 0.8000;

%% ===== 선택할 세션 =====
rat_sel = "817";
ss_sel  = 11;

%% filter: 한 세션만
idx_valid = T_bump.hit_found == true;
idx_sess  = idx_valid & string(T_bump.rat) == rat_sel & T_bump.ss == ss_sel;

Tf = T_bump(idx_sess,:);

%% group 정의
idx_green = (strcmpi(string(Tf.goal),"West") & Tf.start_direction == 90) | ...
            (strcmpi(string(Tf.goal),"East") & Tf.start_direction == 270);

idx_purple = (strcmpi(string(Tf.goal),"West") & Tf.start_direction == 270) | ...
             (strcmpi(string(Tf.goal),"East") & Tf.start_direction == 90);

fprintf('Session %s-%02d\n', rat_sel, ss_sel);
fprintf('Green group : %d trials\n', sum(idx_green));
fprintf('Purple group: %d trials\n', sum(idx_purple));

%% Plot
f = figure('Color','w','Position',[100 100 560 480]);
hold on;

% Maze outline
p_Outline = Draw_Circle(Maze.Outline.x, Maze.Outline.y, Maze.Outline.r, 4);
p_Outline.LineWidth = 0.75;
p_Outline.Color = [0.2 0.2 0.2];

% Inner circle
th = linspace(0, 2*pi, 400);
plot(InnerCircle.r*cos(th), InnerCircle.r*sin(th), '--', ...
    'Color',[0.35 0.6 0.35], 'LineWidth',1);

% Reward zone arcs
p_in = Draw_AngledCircle(0,0, RewardZone.inner.r,2);
p_in.LineWidth=1; p_in.LineStyle='-'; p_in.Color=[1 0 0];

p_out = Draw_AngledCircle(0,0, RewardZone.outer.r,2);
p_out.LineWidth=1; p_out.LineStyle='-'; p_out.Color=[1 0 0];

plot([p_in.XData(1) p_out.XData(1)], [p_in.YData(1) p_out.YData(1)], 'r-', 'LineWidth',1);
plot([p_in.XData(end) p_out.XData(end)], [p_in.YData(end) p_out.YData(end)], 'r-', 'LineWidth',1);

p_in2 = Draw_AngledCircle2(0,0, RewardZone.inner.r,1);
p_in2.LineWidth=1; p_in2.Color=[0 0 1];

p_out2 = Draw_AngledCircle2(0,0, RewardZone.outer.r,1);
p_out2.LineWidth=1; p_out2.Color=[0 0 1];

plot([p_in2.XData(1) p_out2.XData(1)], [p_in2.YData(1) p_out2.YData(1)], 'b-', 'LineWidth',1);
plot([p_in2.XData(end) p_out2.XData(end)], [p_in2.YData(end) p_out2.YData(end)], 'b-', 'LineWidth',1);

% 초록색
if any(idx_green)
    scatter(Tf.hit_x(idx_green), Tf.hit_y(idx_green), 32, ...
        'filled', ...
        'MarkerFaceColor', [0.2 0.7 0.2], ...
        'MarkerFaceAlpha', 0.45, ...
        'MarkerEdgeAlpha', 0.2);
end

% 보라색
if any(idx_purple)
    scatter(Tf.hit_x(idx_purple), Tf.hit_y(idx_purple), 32, ...
        'filled', ...
        'MarkerFaceColor', [0.55 0.3 0.8], ...
        'MarkerFaceAlpha', 0.45, ...
        'MarkerEdgeAlpha', 0.2);
end

axis equal;
axis off;
title(sprintf('%s-%02d | first bump on inner circle | green=%d | purple=%d', ...
    rat_sel, ss_sel, sum(idx_green), sum(idx_purple)));

%% Save
saveas(f, fullfile(ROOT.Load, sprintf('distribution_%s_%02d_green_purple.png', rat_sel, ss_sel)));