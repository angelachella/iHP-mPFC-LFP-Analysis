clc; clear; close all;

%% Root setting
ROOT.Mother = 'D:';
ROOT.Raw    = fullfile(ROOT.Mother,'1. Behavioral data');
ROOT.Info   = fullfile(ROOT.Raw,'info');
ROOT.Data   = fullfile(ROOT.Raw,'results','behavior','15-May-2024');

today_is = datetime('today');
today_is.Format = 'yyyy-MM-dd';
today_is = char(today_is);

ROOT.Save = fullfile(ROOT.Raw,'results','innerCircle_first_bump_outward', today_is);
if ~exist(ROOT.Save,'dir'), mkdir(ROOT.Save); end

%% Load
load(fullfile(ROOT.Info,'session_info.mat'));   % session_list
addpath(genpath(fullfile(ROOT.Mother, 'toolbox')));

%% Params
rat_list = {'774','779','780','781','816','817'};

%% Maze / circle
Maze.Outline.x = 0;
Maze.Outline.y = 0;
Maze.Outline.r = 0.9500;

InnerCircle.r = 0.6500; % reward zone inner circle
OuterCircle.r = 0.8000; %#ok<NASGU> % reward zone outer circle

%% Output table
T_bump = table( ...
    strings(0,1), ...   % rat
    nan(0,1), ...       % ss
    nan(0,1), ...       % trial
    strings(0,1), ...   % goal
    nan(0,1), ...       % start_direction
    nan(0,1), ...       % hit_x
    nan(0,1), ...       % hit_y
    nan(0,1), ...       % hit_angle_deg
    'VariableNames', {'rat','ss','trial','goal','start_direction', ...
                      'hit_x','hit_y','hit_angle_deg'} );

%% Main loop
for rr = 1:numel(rat_list)

    rat = string(rat_list{rr});
    SL  = session_list(string(session_list.rat)==rat, :);

    for k = 1:height(SL)

        %% session id
        ss_num = SL.ss(k);
        if isstring(ss_num) || ischar(ss_num)
            ss_num = str2double(ss_num);
        end

        goal_trial = string(SL.goal(k));   % session-level goal

        target  = char(rat + "-" + sprintf('%02d', ss_num));
        behFile = fullfile(ROOT.Data, [target '.mat']);

        if ~exist(behFile,'file')
            fprintf('[SKIP] beh mat not found: %s\n', behFile);
            continue;
        end

        %% load behaviour mat
        S = load(behFile);
        if ~isfield(S,'ue') || ~isfield(S,'ue_t')
            fprintf('[SKIP] ue or ue_t missing: %s\n', behFile);
            continue;
        end

        ue   = S.ue;
        ue_t = S.ue_t;

        NumberofTrial = height(ue_t);

        for iTrial = 1:NumberofTrial

            start_dir = ue_t.start_direction(iTrial);

            %% trial trajectory
            idx_trial = find(ue.trial == iTrial & ue.frame_ITI == 0);

            if isempty(idx_trial)
                T_add = table( ...
                    rat, ss_num, iTrial, goal_trial, start_dir, ...
                    NaN, NaN, NaN, ...
                    'VariableNames', T_bump.Properties.VariableNames);
                T_bump = [T_bump; T_add];
                continue;
            end

            X  = ue.position_x(idx_trial);
            Y  = ue.position_y(idx_trial);
            HD = ue.direction(idx_trial);

            if numel(X) < 2
                T_add = table( ...
                    rat, ss_num, iTrial, goal_trial, start_dir, ...
                    NaN, NaN, NaN, ...
                    'VariableNames', T_bump.Properties.VariableNames);
                T_bump = [T_bump; T_add];
                continue;
            end

            %% 안쪽 -> 바깥쪽 첫 crossing
            [hit_x, hit_y, hit_ang] = ...
                findFirstOutwardCircleCrossing_local(X, Y, HD, InnerCircle.r);

            %% save
            T_add = table( ...
                rat, ss_num, iTrial, goal_trial, start_dir, ...
                hit_x, hit_y, hit_ang, ...
                'VariableNames', T_bump.Properties.VariableNames);

            T_bump = [T_bump; T_add];
        end
    end
end

%% Save
save(fullfile(ROOT.Save, 'T_innerCircle_first_bump_outward.mat'), 'T_bump');

fprintf('\nDone. Table saved.\n');

%% =======================================================================
% Local functions
%% =======================================================================
function [hit_x, hit_y, hit_ang] = ...
    findFirstOutwardCircleCrossing_local(X, Y, HD, r0)

    hit_x   = NaN;
    hit_y   = NaN;
    hit_ang = NaN;

    R = hypot(X, Y);

    % 안쪽 -> 바깥쪽으로 처음 나가는 구간
    idx = find(R(1:end-1) < r0 & R(2:end) >= r0, 1, 'first');

    if isempty(idx)
        % 이미 처음부터 바깥쪽에 있는 경우: 처음 r>=r0 인 실제 점 사용
        idx2 = find(R >= r0, 1, 'first');
        if ~isempty(idx2)
            hit_x   = X(idx2);
            hit_y   = Y(idx2);
            hit_ang = HD(idx2);
        end
        return;
    end

    % crossing 구간의 두 실제 점
    r1 = R(idx);
    r2 = R(idx+1);

    % r0에 더 가까운 실제 샘플점 선택
    if abs(r1 - r0) <= abs(r2 - r0)
        pick = idx;
    else
        pick = idx + 1;
    end

    hit_x   = X(pick);
    hit_y   = Y(pick);
    hit_ang = HD(pick);
end

% Maze.Outline.x = 0;
% Maze.Outline.y = 0;
% Maze.Outline.r = 0.9500;
% 
% RewardZone.inner.r = 0.6500;
% RewardZone.outer.r = 0.8000;
% 
% RewardZone.arch.x  = -0.7715;   % west
% RewardZone.arch.y  =  0.1552;
% RewardZone.sea.x   = -0.780;
% RewardZone.sea.y   = -0.5130;
% RewardZone.house.x =  0.7715;   % east
% RewardZone.house.y = -0.1552;
% 
% 
% f = figure('Color','w','Position',[100,100,500,500]);
% hold on
% 
% %% ===== Maze outline =====
% p_Outline = Draw_Circle(Maze.Outline.x, Maze.Outline.y, Maze.Outline.r, 4);
% p_Outline.LineWidth = 0.75;
% p_Outline.Color = [0.2 0.2 0.2];
% 
% %% ===== Inner circle =====
% th = linspace(0, 2*pi, 500);
% x_in = RewardZone.inner.r * cos(th);
% y_in = RewardZone.inner.r * sin(th);
% plot(x_in, y_in, '--', 'Color', [0.4 0.7 0.4], 'LineWidth', 1.2);
% 
% %% ===== Start point at maze centre =====
% plot(0, 0, 'k+', 'MarkerSize', 12, 'LineWidth', 1.5);
% 
% %% ===== T_bump points (actual x,y) =====
% for ii = 1:height(T_bump)
% 
%     x = T_bump.hit_x(ii);
%     y = T_bump.hit_y(ii);
% 
%     if isnan(x) || isnan(y)
%         continue;
%     end
% 
%     goal_i = string(T_bump.goal(ii));
%     sd_i   = T_bump.start_direction(ii);
% 
%     is_green = (strcmpi(goal_i,'West') && sd_i == 90) || ...
%                (strcmpi(goal_i,'East') && sd_i == 270);
% 
%     is_purple = (strcmpi(goal_i,'West') && sd_i == 270) || ...
%                 (strcmpi(goal_i,'East') && sd_i == 90);
% 
%     if is_green
%         plot(x, y, 'o', ...
%             'MarkerSize', 6, ...
%             'MarkerFaceColor', [0.5 0.8 0.5], ...
%             'MarkerEdgeColor', [0.5 0.8 0.5]);
%     elseif is_purple
%         plot(x, y, 'o', ...
%             'MarkerSize', 6, ...
%             'MarkerFaceColor', [0.65 0.45 0.85], ...
%             'MarkerEdgeColor', [0.65 0.45 0.85]);
%     end
% end