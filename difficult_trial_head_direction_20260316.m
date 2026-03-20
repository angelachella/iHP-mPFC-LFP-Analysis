clc; clear; close all;

%% Root
ROOT.Mother = 'D:';
ROOT.Raw    = fullfile(ROOT.Mother,'1. Behavioral data');
ROOT.Info   = fullfile(ROOT.Raw,'info');
ROOT.Data   = fullfile(ROOT.Raw,'results','behavior','15-May-2024');

addpath(genpath(fullfile(ROOT.Mother, 'toolbox')));

today_is = datetime('today');
today_is.Format = 'yyyy-MM-dd';
today_is = char(today_is);

ROOT.Save = fullfile(ROOT.Raw,'results','first_target_HD_from_ue', today_is);
if ~exist(ROOT.Save,'dir'), mkdir(ROOT.Save); end

%% Load session info
load(fullfile(ROOT.Info,'session_info.mat'));   % session_list

%% Rats
rat_list = {'774','779','780','781','816','817'};

%% Output table
T_out = table( ...
    strings(0,1), ...   % rat
    nan(0,1), ...       % ss
    nan(0,1), ...       % trial
    strings(0,1), ...   % goal
    nan(0,1), ...       % start_direction
    nan(0,1), ...       % target_hd
    nan(0,1), ...       % x_target
    nan(0,1), ...       % y_target
    nan(0,1), ...       % hd_target
    nan(0,1), ...       % idx_ue
    nan(0,1), ...       % abs_ang_diff
    'VariableNames', {'rat','ss','trial','goal','start_direction', ...
                      'target_hd','x_target','y_target','hd_target','idx_ue','abs_ang_diff'} );

%% Loop over rats
for rr = 1:numel(rat_list)

    rat = string(rat_list{rr});
    SL  = session_list(string(session_list.rat) == rat, :);

    for k = 1:height(SL)

        %% session number
        ss_num = SL.ss(k);
        if isstring(ss_num) || ischar(ss_num)
            ss_num = str2double(ss_num);
        end

        target  = char(rat + "-" + sprintf('%02d', ss_num));
        behFile = fullfile(ROOT.Data, [target '.mat']);

        if ~exist(behFile,'file')
            fprintf('[SKIP] behFile not found: %s\n', behFile);
            continue;
        end

        %% load ue, ue_t
        load(behFile, 'ue', 'ue_t');

        %% goal string
        if iscell(SL.goal)
            goal_str = string(SL.goal{k});
        else
            goal_str = string(SL.goal(k));
        end

        %% trial loop
        for iTrial = 1:height(ue_t)

            %% performance filter
            if ismember('performance_available', ue_t.Properties.VariableNames)
                if ue_t.performance_available(iTrial) ~= 1
                    continue;
                end
            end

            %% start direction
            if ~ismember('start_direction', ue_t.Properties.VariableNames)
                continue;
            end
            start_dir = ue_t.start_direction(iTrial);

            %% use only:
            % West goal + start_direction 90  -> target HD = 180
            % East goal + start_direction 270 -> target HD = 
            use_trial = false;
            target_hd = nan;

            if strcmpi(goal_str, 'West') && start_dir == 90
                use_trial = true;
                target_hd = 225;
            elseif strcmpi(goal_str, 'East') && start_dir == 270
                use_trial = true;
                target_hd = 45;   
            end

            if ~use_trial
                continue;
            end

            %% find frames of this trial
            if ismember('trial', ue.Properties.VariableNames)
                idx_trial = find(ue.trial == iTrial);
            else
                idx_trial = find(ue{:,3} == iTrial);   % fallback
            end

            if isempty(idx_trial)
                continue;
            end

            %% remove ITI frames
            if ismember('frame_ITI', ue.Properties.VariableNames)
                idx_trial = idx_trial(ue.frame_ITI(idx_trial) == 0);
            end

            %% before rewardzone arrival only
            if ismember('rewardzone_arrival', ue.Properties.VariableNames)
                idx_trial = idx_trial(ue.rewardzone_arrival(idx_trial) == 0);
            end

            if isempty(idx_trial)
                continue;
            end

            %% head direction
            if ~ismember('direction', ue.Properties.VariableNames)
                continue;
            end

            hd_trial = ue.direction(idx_trial);

            valid = ~isnan(hd_trial);
            hd_trial  = hd_trial(valid);
            idx_trial = idx_trial(valid);

            if isempty(hd_trial)
                continue;
            end

            %% circular angular distance to target HD
            % returns difference in [-180, 180]
            ang_diff = wrapTo180(hd_trial - target_hd);
            abs_ang_diff = abs(ang_diff);

            %% first moment with minimum angular distance
            min_diff = min(abs_ang_diff);
            closest_idx = find(abs_ang_diff == min_diff, 1, 'first');

            if isempty(closest_idx)
                continue;
            end

            %% corresponding ue index
            idx_ue = idx_trial(closest_idx);

            %% x, y, hd at that moment
            if ~ismember('position_x', ue.Properties.VariableNames) || ...
               ~ismember('position_y', ue.Properties.VariableNames)
                continue;
            end

            x_target  = ue.position_x(idx_ue);
            y_target  = ue.position_y(idx_ue);
            hd_target = ue.direction(idx_ue);

            %% save row
            T_add = table( ...
                rat, ss_num, iTrial, goal_str, start_dir, ...
                target_hd, x_target, y_target, hd_target, idx_ue, min_diff, ...
                'VariableNames', T_out.Properties.VariableNames);

            T_out = [T_out; T_add];
        end

        fprintf('[OK] %s\n', target);
    end
end

%% Save table
save(fullfile(ROOT.Save,'T_out_first_target_HD_from_ue.mat'), 'T_out');
writetable(T_out, fullfile(ROOT.Save,'T_out_first_target_HD_from_ue.csv'));

%% =========================
%% Plot
%% =========================
Maze.Outline.x = 0;
Maze.Outline.y = 0;
Maze.Outline.r = 0.9500;

RewardZone.inner.r = 0.6500;
RewardZone.outer.r = 0.8000;

RewardZone.arch.x  = -0.7715;   % west
RewardZone.arch.y  =  0.1552;
RewardZone.sea.x   = -0.7800;
RewardZone.sea.y   = -0.5130;
RewardZone.house.x =  0.7715;   % east
RewardZone.house.y = -0.1552;

f = figure('Color','w','Position',[100,100,450,400]);
hold on;

%% Maze outline
p_Outline = Draw_Circle(Maze.Outline.x, Maze.Outline.y, Maze.Outline.r, 4);
p_Outline.LineWidth = 0.75;

%% Scatter points
%% goal index
idx_west = strcmpi(T_out.goal,'West');
idx_east = strcmpi(T_out.goal,'East');

%% West
scatter(T_out.x_target(idx_west), T_out.y_target(idx_west), 12, 'filled', ...
    'MarkerFaceColor', [0.9 0.2 0.2], ...
    'MarkerEdgeColor', 'none');

%% East
scatter(T_out.x_target(idx_east), T_out.y_target(idx_east), 12, 'filled', ...
    'MarkerFaceColor', [0.2 0.4 0.9], ...
    'MarkerEdgeColor', 'none');

%% Reward zone arcs
p_in = Draw_AngledCircle(0,0, RewardZone.inner.r, 2);
p_in.LineWidth = 1;
p_in.LineStyle = '-';

p_out = Draw_AngledCircle(0,0, RewardZone.outer.r, 2);
p_out.LineWidth = 1;
p_out.LineStyle = '-';

plot([p_in.XData(1)   p_out.XData(1)], ...
     [p_in.YData(1)   p_out.YData(1)], ...
     'r-', 'LineWidth', 1);

plot([p_in.XData(end) p_out.XData(end)], ...
     [p_in.YData(end) p_out.YData(end)], ...
     'r-', 'LineWidth', 1);

p_in2 = Draw_AngledCircle2(0,0, RewardZone.inner.r, 1);
p_in2.LineWidth = 1;
p_in2.LineStyle = '-';

p_out2 = Draw_AngledCircle2(0,0, RewardZone.outer.r, 1);
p_out2.LineWidth = 1;
p_out2.LineStyle = '-';

plot([p_in2.XData(1)   p_out2.XData(1)], ...
     [p_in2.YData(1)   p_out2.YData(1)], ...
     'b-', 'LineWidth', 1);

plot([p_in2.XData(end) p_out2.XData(end)], ...
     [p_in2.YData(end) p_out2.YData(end)], ...
     'b-', 'LineWidth', 1);

angles = [45 225];

for a = angles

    x = Maze.Outline.r * cosd(a);
    y = Maze.Outline.r * sind(a);

    plot([0 x],[0 y],'k--','LineWidth',1)

    text(x*1.1, y*1.1, sprintf('%d°',a), ...
        'HorizontalAlignment','center', ...
        'FontSize',10);

end

%% Figure settings
axis equal;
axis off;
title(sprintf('First closest HD moment | n = %d', height(T_out)));

%% Save figure
saveas(f, fullfile(ROOT.Save, 'first_target_HD_scatter.png'));
