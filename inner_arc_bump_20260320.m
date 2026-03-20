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

InnerCircle.r = 0.6500;

%% Output table
T_bump = table( ...
    strings(0,1), ...   % rat
    nan(0,1), ...       % ss
    nan(0,1), ...       % trial
    strings(0,1), ...   % goal
    nan(0,1), ...       % start_direction
    false(0,1), ...     % hit_found
    nan(0,1), ...       % hit_x
    nan(0,1), ...       % hit_y
    nan(0,1), ...       % hit_r
    nan(0,1), ...       % hit_angle_deg
    nan(0,1), ...       % crossing_seg_idx
    'VariableNames', {'rat','ss','trial','goal','start_direction', ...
                      'hit_found','hit_x','hit_y','hit_r','hit_angle_deg', ...
                      'crossing_seg_idx'} );

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

        %% metadata
        start_dir_all = getUETCol_local(ue_t, ["start_direction","start direction"]);

        if ismember('goal', SL.Properties.VariableNames)
            goal_sess = string(SL.goal(k));
        else
            goal_sess = "Unknown";
        end

        fprintf('Processing %s ...\n', target);

        for iTrial = 1:NumberofTrial

            %% metadata
            if ~isempty(start_dir_all) && numel(start_dir_all) >= iTrial
                start_dir = start_dir_all(iTrial);
            else
                start_dir = NaN;
            end

            goal_trial = string(goal_sess);

            %% trial trajectory
            idx_trial = find(ue.trial == iTrial & ue.frame_ITI == 0);

            if isempty(idx_trial)
                T_add = table( ...
                    rat, ss_num, iTrial, goal_trial, start_dir, ...
                    false, NaN, NaN, NaN, NaN, NaN, ...
                    'VariableNames', T_bump.Properties.VariableNames);
                T_bump = [T_bump; T_add];
                continue;
            end

            X = ue.position_x(idx_trial);
            Y = ue.position_y(idx_trial);

            if numel(X) < 2
                T_add = table( ...
                    rat, ss_num, iTrial, goal_trial, start_dir, ...
                    false, NaN, NaN, NaN, NaN, NaN, ...
                    'VariableNames', T_bump.Properties.VariableNames);
                T_bump = [T_bump; T_add];
                continue;
            end

            %% 안쪽 -> 바깥쪽 첫 crossing
            [hit_found, hit_x, hit_y, hit_r, hit_ang, seg_idx] = ...
                findFirstOutwardCircleCrossing_local(X, Y, InnerCircle.r);

            %% save
            T_add = table( ...
                rat, ss_num, iTrial, goal_trial, start_dir, ...
                hit_found, hit_x, hit_y, hit_r, hit_ang, seg_idx, ...
                'VariableNames', T_bump.Properties.VariableNames);

            T_bump = [T_bump; T_add];
        end
    end
end

%% Save
save(fullfile(ROOT.Save, 'T_innerCircle_first_bump_outward.mat'), 'T_bump');
writetable(T_bump, fullfile(ROOT.Save, 'T_innerCircle_first_bump_outward.csv'));

fprintf('\nDone. Table saved.\n');

%% =======================================================================
% Local functions
%% =======================================================================

function col = getUETCol_local(T, candNames)
    col = [];
    if ischar(candNames) || isstring(candNames)
        candNames = cellstr(candNames);
    end

    vn = string(T.Properties.VariableNames);
    vn2 = lower(strrep(vn, "_", " "));

    for i = 1:numel(candNames)
        key = lower(strrep(string(candNames{i}), "_", " "));
        idx = find(vn2 == key, 1);
        if ~isempty(idx)
            col = T.(T.Properties.VariableNames{idx});
            return;
        end
    end
end

function [hit_found, hit_x, hit_y, hit_r, hit_ang, seg_idx] = ...
    findFirstOutwardCircleCrossing_local(X, Y, r0)

    hit_found = false;
    hit_x     = NaN;
    hit_y     = NaN;
    hit_r     = NaN;
    hit_ang   = NaN;
    seg_idx   = NaN;

    R = hypot(X, Y);

    % 안쪽 -> 바깥쪽으로 처음 나가는 구간
    idx = find(R(1:end-1) < r0 & R(2:end) >= r0, 1, 'first');

    if isempty(idx)
        % 혹시 첫 점이 이미 원 위/바깥이면 첫 점 기록
        idx2 = find(R >= r0, 1, 'first');
        if ~isempty(idx2)
            hit_found = true;
            hit_x = X(idx2);
            hit_y = Y(idx2);
            hit_r = hypot(hit_x, hit_y);
            hit_ang = mod(atan2d(hit_y, hit_x), 360);
            seg_idx = idx2;
        end
        return;
    end

    % 선형보간
    x1 = X(idx);   y1 = Y(idx);
    x2 = X(idx+1); y2 = Y(idx+1);

    r1 = R(idx);
    r2 = R(idx+1);

    if r1 == r2
        t = 0;
    else
        t = (r0 - r1) / (r2 - r1);
        t = max(0, min(1, t));
    end

    hit_x = x1 + t*(x2 - x1);
    hit_y = y1 + t*(y2 - y1);
    hit_r = hypot(hit_x, hit_y);
    hit_ang = mod(atan2d(hit_y, hit_x), 360);
    seg_idx = idx;

    hit_found = true;
end



%% Distribution plot
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
% ROOT.Load = fullfile(ROOT.Raw,'results','innerCircle_first_bump_outward', today_is);
% 
% addpath(genpath(fullfile(ROOT.Mother, 'toolbox')));
% 
% %% Load
% load(fullfile(ROOT.Load, 'T_innerCircle_first_bump_outward.mat'), 'T_bump');

%% Maze / circle
Maze.Outline.x = 0;
Maze.Outline.y = 0;
Maze.Outline.r = 0.9500;

InnerCircle.r = 0.6500;

%% 원하는 조건
rat_sel  = ;      % 예: "774"
ss_sel   = [];      % 예: 5
goal_sel = [];      % 예: "West"
sd_sel   = [];      % 예: 90

%% filtering
idx = T_bump.hit_found == true;

if ~isempty(rat_sel)
    idx = idx & (string(T_bump.rat) == string(rat_sel));
end

if ~isempty(ss_sel)
    idx = idx & (T_bump.ss == ss_sel);
end

if ~isempty(goal_sel)
    idx = idx & strcmpi(string(T_bump.goal), string(goal_sel));
end

if ~isempty(sd_sel)
    idx = idx & (T_bump.start_direction == sd_sel);
end

Tf = T_bump(idx,:);

%% Plot
f = figure('Color','w','Position',[100 100 520 450]);
hold on;

p_Outline = Draw_Circle(Maze.Outline.x, Maze.Outline.y, Maze.Outline.r, 4);
p_Outline.LineWidth = 0.75;
p_Outline.Color = [0.2 0.2 0.2];

th = linspace(0, 2*pi, 400);
plot(InnerCircle.r*cos(th), InnerCircle.r*sin(th), '--', 'LineWidth', 1);

scatter(Tf.hit_x, Tf.hit_y, 28, ...
    'filled', ...
    'MarkerFaceAlpha', 0.35, ...
    'MarkerEdgeAlpha', 0.2);

axis equal;
axis off;
title(sprintf('First outward bump on r = %.2f circle | n = %d', InnerCircle.r, height(Tf)));