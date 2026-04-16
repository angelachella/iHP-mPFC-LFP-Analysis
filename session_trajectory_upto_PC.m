function plot_all_trial_trajectories_to_first_bump()

clc; clear; close all;

%% -------------------------------------------------
% Root paths
%% -------------------------------------------------
ROOT.Mother = 'D:';
ROOT.Raw    = fullfile(ROOT.Mother,'1. Behavioral data');
ROOT.Info   = fullfile(ROOT.Raw,'info');
ROOT.Data   = fullfile(ROOT.Raw,'results','behavior','15-May-2024');

ROOT.Neural = 'D:\2. Neural data\raw data';
ROOT.bump   = fullfile(ROOT.Neural, 'innerCircle_first_bump_results.mat');

ROOT.Save   = fullfile(ROOT.Raw, 'results', 'trajectory_to_first_bump');
if ~exist(ROOT.Save, 'dir')
    mkdir(ROOT.Save);
end

%% -------------------------------------------------
% Load data
%% -------------------------------------------------
S = load(ROOT.bump);

T_path = S.T_path;
T_bump = S.T_bump;

target_goal = "East";      % "West", "East", or "all"
target_start = 270;         % 90, 270, or "all"

%% -------------------------------------------------
% Basic checks
%% -------------------------------------------------
req_path_vars = {'rat','ss','trial','x','y','goal','start_direction'};
for i = 1:numel(req_path_vars)
    if ~ismember(req_path_vars{i}, T_path.Properties.VariableNames)
        error('T_path is missing variable: %s', req_path_vars{i});
    end
end

req_bump_vars = {'rat','ss','trial','hit_x','hit_y', 'goal','start_direction'};
for i = 1:numel(req_bump_vars)
    if ~ismember(req_bump_vars{i}, T_bump.Properties.VariableNames)
        error('T_bump is missing variable: %s', req_bump_vars{i});
    end
end

%% -------------------------------------------------
% Convert rat to string for stable comparison
%% -------------------------------------------------
T_path.rat = string(T_path.rat);
T_bump.rat = string(T_bump.rat);

T_path.rat  = string(T_path.rat);
T_bump.rat  = string(T_bump.rat);
T_path.goal = string(T_path.goal);
T_bump.goal = string(T_bump.goal);

%% -------------------------------------------------
% Maze / circle parameters
%% -------------------------------------------------
Maze.Outline.x = 0;
Maze.Outline.y = 0;
Maze.Outline.r = 0.95;

InnerCircle.x = 0;
InnerCircle.y = 0;
InnerCircle.r = 0.65;

OuterCircle.x = 0;
OuterCircle.y = 0;
OuterCircle.r = 0.80;

%% -------------------------------------------------
% Unique rat-session combinations
%% -------------------------------------------------
rat_list = unique(T_path.rat);

for iR = 1:numel(rat_list)

    rat_now = rat_list(iR);
    idx_r   = T_path.rat == rat_now;

    ss_list = unique(T_path.ss(idx_r));
    ss_list = ss_list(~isnan(ss_list));

    rat_save_dir = fullfile(ROOT.Save, ['rat_' char(rat_now)]);
    if ~exist(rat_save_dir, 'dir')
        mkdir(rat_save_dir);
    end

    for iS = 1:numel(ss_list)

        ss_now = ss_list(iS);

        idx_rs_path = (T_path.rat == rat_now) & (T_path.ss == ss_now);
        idx_rs_bump = (T_bump.rat == rat_now) & (T_bump.ss == ss_now);

        T_rs_path = T_path(idx_rs_path, :);
        T_rs_bump = T_bump(idx_rs_bump, :);

        % Apply goal filter
        if ~isequal(target_goal, "all")
            T_rs_path = T_rs_path(T_rs_path.goal == target_goal, :);
            T_rs_bump = T_rs_bump(T_rs_bump.goal == target_goal, :);
        end
        
        % Apply start-direction filter
        if ~(ischar(target_start) || isstring(target_start)) || ~strcmp(string(target_start), "all")
            T_rs_path = T_rs_path(T_rs_path.start_direction == target_start, :);
            T_rs_bump = T_rs_bump(T_rs_bump.start_direction == target_start, :);
        end


        if isempty(T_rs_path)
            fprintf('No path data: rat %s ss %d\n', rat_now, ss_now);
            continue;
        end

        trial_list = unique(T_rs_path.trial);
        trial_list = trial_list(~isnan(trial_list));

        %% -----------------------------------------
        % Figure
        %% -----------------------------------------
        f = figure('Color','w', 'Position', [100 100 900 900]);
        hold on;

  
        % Inner circle
        draw_circle(InnerCircle.x, InnerCircle.y, InnerCircle.r, ...
            'Color', [0.1 0.6 0.1], 'LineWidth', 1.5, 'LineStyle', '--');


        % Plot all trial trajectories
        nTrialPlotted = 0;

        for iT = 1:numel(trial_list)

            tr_now = trial_list(iT);
            idx_t  = (T_rs_path.trial == tr_now);

            T_t = T_rs_path(idx_t, :);

            if isempty(T_t)
                continue;
            end

            x = T_t.x;
            y = T_t.y;

            if all(isnan(x)) || all(isnan(y))
                continue;
            end

            % trajectory
            plot(x, y, '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 1.0);

            % start point
            plot(x(1), y(1), 'o', ...
                'MarkerSize', 4, ...
                'MarkerFaceColor', [0.2 0.2 0.8], ...
                'MarkerEdgeColor', 'none');

            nTrialPlotted = nTrialPlotted + 1;
        end


        % Maze centre
        plot(0, 0, 'k+', 'MarkerSize', 10, 'LineWidth', 1.2);

        axis off;
        xlim([-1 1]);
        ylim([-1 1]);
        box off;


        %% -----------------------------------------
        % Save
        %% -----------------------------------------
        save_name = sprintf('rat_%s_ss_%02d_East_South', char(rat_now), ss_now);
        exportgraphics(f, fullfile(rat_save_dir, [save_name '.png']), 'Resolution', 300);

        close(f);

        fprintf('Saved: rat %s ss %d\n', rat_now, ss_now);
    end
end

fprintf('Done.\n');

end

%% =================================================
% Helper function
%% =================================================
function h = draw_circle(x0, y0, r, varargin)
th = linspace(0, 2*pi, 400);
x = x0 + r*cos(th);
y = y0 + r*sin(th);
h = plot(x, y, varargin{:});
end