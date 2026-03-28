% clc; clear; close all;
% 
% %% Root setting
% ROOT.Mother = 'D:';
% ROOT.Raw    = fullfile(ROOT.Mother,'1. Behavioral data');
% ROOT.Info   = fullfile(ROOT.Raw,'info');
% ROOT.Data   = fullfile(ROOT.Raw,'results','behavior','15-May-2024');
% 
% today_is = datetime('today');
% today_is.Format = 'yyyy-MM-dd';
% today_is = char(today_is);
% 
% ROOT.Save = fullfile(ROOT.Raw,'results','innerCircle_first_bump_outward', today_is);
% if ~exist(ROOT.Save,'dir'), mkdir(ROOT.Save); end
% 
% ROOT.SaveFig = fullfile(ROOT.Save, 'trajectory_fig');
% if ~exist(ROOT.SaveFig,'dir'), mkdir(ROOT.SaveFig); end
% 
% %% Load
% load(fullfile(ROOT.Info,'session_info.mat'));   % session_list
% addpath(genpath(fullfile(ROOT.Mother, 'toolbox')));
% 
% %% Params
% rat_list = {'774','779','780','781','816','817'};
% 
% %% Maze / circle
% Maze.Outline.x = 0;
% Maze.Outline.y = 0;
% Maze.Outline.r = 0.9500;
% 
% InnerCircle.r = 0.6500; % reward zone inner circle
% OuterCircle.r = 0.8000; %#ok<NASGU>
% 
% %% Output table: trial summary
% T_bump = table( ...
%     strings(0,1), ...   % rat
%     nan(0,1), ...       % ss
%     nan(0,1), ...       % trial
%     strings(0,1), ...   % goal
%     nan(0,1), ...       % start_direction
%     nan(0,1), ...       % hit_frame_global
%     nan(0,1), ...       % hit_frame_within_trial
%     nan(0,1), ...       % hit_x
%     nan(0,1), ...       % hit_y
%     nan(0,1), ...       % hit_angle_deg
%     nan(0,1), ...       % nFrame_to_hit
%     'VariableNames', {'rat','ss','trial','goal','start_direction', ...
%                       'hit_frame_global','hit_frame_within_trial', ...
%                       'hit_x','hit_y','hit_angle_deg','nFrame_to_hit'});
% 
% %% Output table: frame-by-frame data from trial start to first bump
% T_path = table( ...
%     strings(0,1), ...   % rat
%     nan(0,1), ...       % ss
%     nan(0,1), ...       % trial
%     strings(0,1), ...   % goal
%     nan(0,1), ...       % start_direction
%     nan(0,1), ...       % frame_global
%     nan(0,1), ...       % frame_within_trial
%     nan(0,1), ...       % x
%     nan(0,1), ...       % y
%     nan(0,1), ...       % speed
%     nan(0,1), ...       % head_direction
%     'VariableNames', {'rat','ss','trial','goal','start_direction', ...
%                       'frame_global','frame_within_trial', ...
%                       'x','y','speed','head_direction'});
% 
% %% Main loop
% for rr = 1:numel(rat_list)
% 
%     rat = string(rat_list{rr});
%     SL  = session_list(string(session_list.rat)==rat, :);
% 
%     for k = 1:height(SL)
% 
%         %% session id
%         ss_num = SL.ss(k);
%         if isstring(ss_num) || ischar(ss_num)
%             ss_num = str2double(ss_num);
%         end
% 
%         goal_trial = string(SL.goal(k));   % session-level goal
% 
%         target  = char(rat + "-" + sprintf('%02d', ss_num));
%         behFile = fullfile(ROOT.Data, [target '.mat']);
% 
%         if ~exist(behFile,'file')
%             fprintf('[SKIP] beh mat not found: %s\n', behFile);
%             continue;
%         end
% 
%         %% load behaviour mat
%         S = load(behFile);
%         if ~isfield(S,'ue') || ~isfield(S,'ue_t')
%             fprintf('[SKIP] ue or ue_t missing: %s\n', behFile);
%             continue;
%         end
% 
%         ue   = S.ue;
%         ue_t = S.ue_t;
% 
%         NumberofTrial = height(ue_t);
% 
%         for iTrial = 1:NumberofTrial
% 
%             if ue_t.performance_available(iTrial) ~= 1
%                 continue;
%             end
% 
%             start_dir = ue_t.start_direction(iTrial);
% 
%             %% trial trajectory indices
%             idx_trial = find(ue.trial == iTrial & ue.frame_ITI == 0);
% 
%             if isempty(idx_trial)
%                 T_add = table( ...
%                     rat, ss_num, iTrial, goal_trial, start_dir, ...
%                     NaN, NaN, NaN, NaN, NaN, NaN, ...
%                     'VariableNames', T_bump.Properties.VariableNames);
%                 T_bump = [T_bump; T_add];
%                 continue;
%             end
% 
%             X   = ue.position_x(idx_trial);
%             Y   = ue.position_y(idx_trial);
%             HD  = ue.direction(idx_trial);
%             VEL = ue.velocity(idx_trial);
% 
%             if numel(X) < 2
%                 T_add = table( ...
%                     rat, ss_num, iTrial, goal_trial, start_dir, ...
%                     NaN, NaN, NaN, NaN, NaN, NaN, ...
%                     'VariableNames', T_bump.Properties.VariableNames);
%                 T_bump = [T_bump; T_add];
%                 continue;
%             end
% 
%             %% first outward crossing of InnerCircle
%             [hit_idx_local, hit_x, hit_y, hit_ang] = ...
%                 findFirstOutwardCircleCrossing_local(X, Y, HD, InnerCircle.r);
% 
%             if isnan(hit_idx_local)
%                 T_add = table( ...
%                     rat, ss_num, iTrial, goal_trial, start_dir, ...
%                     NaN, NaN, NaN, NaN, NaN, NaN, ...
%                     'VariableNames', T_bump.Properties.VariableNames);
%                 T_bump = [T_bump; T_add];
%                 continue;
%             end
% 
%             %% from trial start to first bump
%             idx_to_hit_local  = 1:hit_idx_local;
%             idx_to_hit_global = idx_trial(idx_to_hit_local);
% 
%             X_hit   = X(idx_to_hit_local);
%             Y_hit   = Y(idx_to_hit_local);
%             VEL_hit = VEL(idx_to_hit_local);
%             HD_hit  = HD(idx_to_hit_local);
% 
%             %% save frame-by-frame path
%             nF = numel(idx_to_hit_local);
% 
%             T_add_path = table( ...
%                 repmat(rat, nF, 1), ...
%                 repmat(ss_num, nF, 1), ...
%                 repmat(iTrial, nF, 1), ...
%                 repmat(goal_trial, nF, 1), ...
%                 repmat(start_dir, nF, 1), ...
%                 idx_to_hit_global(:), ...
%                 idx_to_hit_local(:), ...
%                 X_hit(:), ...
%                 Y_hit(:), ...
%                 VEL_hit(:), ...
%                 HD_hit(:), ...
%                 'VariableNames', T_path.Properties.VariableNames);
% 
%             T_path = [T_path; T_add_path];
% 
%             %% save trial summary
%             T_add = table( ...
%                 rat, ss_num, iTrial, goal_trial, start_dir, ...
%                 idx_trial(hit_idx_local), ...
%                 hit_idx_local, ...
%                 hit_x, hit_y, hit_ang, nF, ...
%                 'VariableNames', T_bump.Properties.VariableNames);
% 
%             T_bump = [T_bump; T_add];
% 
%             %% plot trajectory from trial start to first bump
%             f = figure('Color','w','Position',[100 100 550 550]);
%             hold on;
% 
%             % maze outline
%             th = linspace(0, 2*pi, 400);
%             plot(Maze.Outline.r*cos(th), Maze.Outline.r*sin(th), 'k-', 'LineWidth', 1.2);
% 
%             % inner circle
%             plot(InnerCircle.r*cos(th), InnerCircle.r*sin(th), '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.2);
% 
%             % trajectory
%             plot(X_hit, Y_hit, 'b-', 'LineWidth', 2);
% 
%             % start point
%             plot(X_hit(1), Y_hit(1), 'go', 'MarkerFaceColor','g', 'MarkerSize', 8);
% 
%             % hit point
%             plot(hit_x, hit_y, 'ro', 'MarkerFaceColor','r', 'MarkerSize', 8);
% 
%             %% ===== Reward zone arcs =====
%             p_in = Draw_AngledCircle(0,0, InnerCircle.r,2);
%             p_in.LineWidth = 1;
%             p_in.LineStyle = '-';
% 
%             p_out = Draw_AngledCircle(0,0, OuterCircle.r,2);
%             p_out.LineWidth = 1;
%             p_out.LineStyle = '-';
% 
%             plot([p_in.XData(1)   p_out.XData(1)],   [p_in.YData(1)   p_out.YData(1)],   'r-', 'LineWidth',1);
%             plot([p_in.XData(end) p_out.XData(end)], [p_in.YData(end) p_out.YData(end)], 'r-', 'LineWidth',1);
% 
%             p_in2 = Draw_AngledCircle2(0,0, InnerCircle.r,1);
%             p_in2.LineWidth = 1;
% 
%             p_out2 = Draw_AngledCircle2(0,0, OuterCircle.r,1);
%             p_out2.LineWidth = 1;
% 
%             plot([p_in2.XData(1)   p_out2.XData(1)],   [p_in2.YData(1)   p_out2.YData(1)],   'b-', 'LineWidth',1);
%             plot([p_in2.XData(end) p_out2.XData(end)], [p_in2.YData(end) p_out2.YData(end)], 'b-', 'LineWidth',1);
% 
%             axis equal;
%             xlim([-1 1]);
%             ylim([-1 1]);
%             box on;
% 
%             title(sprintf('Rat %s | Session %02d | Trial %d | Goal %s | SD %d', ...
%                 char(rat), ss_num, iTrial, char(goal_trial), start_dir), ...
%                 'Interpreter','none');
% 
%             xlabel('X');
%             ylabel('Y');
% 
%             saveas(f, fullfile(ROOT.SaveFig, ...
%                 sprintf('traj_until_firstInnerBump_rat%s_ss%02d_trial%03d.png', ...
%                 char(rat), ss_num, iTrial)));
% 
%             close(f);
% 
%         end
%     end
% end
% 
% %% Save tables
% save(fullfile(ROOT.Save, 'innerCircle_first_bump_results.mat'), 'T_bump', 'T_path');
% writetable(T_bump, fullfile(ROOT.Save, 'T_bump_summary.csv'));
% writetable(T_path, fullfile(ROOT.Save, 'T_path_frames_until_first_bump.csv'));
% 
% disp('Done.');
% 
% %% Local function
% function [hit_idx, hit_x, hit_y, hit_ang] = findFirstOutwardCircleCrossing_local(X, Y, HD, r0)
% 
%     hit_idx = NaN;
%     hit_x   = NaN;
%     hit_y   = NaN;
%     hit_ang = NaN;
% 
%     D = sqrt(X.^2 + Y.^2);
% 
%     for ii = 2:numel(D)
%         % 안쪽 -> 바깥쪽 crossing
%         if D(ii-1) < r0 && D(ii) >= r0
%             hit_idx = ii;
%             hit_x   = X(ii);
%             hit_y   = Y(ii);
% 
%             % crossing point의 angle (position angle)
%             hit_ang = atan2d(hit_y, hit_x);
%             if hit_ang < 0
%                 hit_ang = hit_ang + 360;
%             end
%             return;
%         end
%     end
% end



%% idPhi vs MVL (before the first bump to the inner circle only)
clc; clear; close all;

%% Root
ROOT.Mother = 'D:';
ROOT.Raw    = fullfile(ROOT.Mother,'1. Behavioral data');

today_is = datetime('today');
today_is.Format = 'yyyy-MM-dd';
today_is = char(today_is);

ROOT.Load = fullfile(ROOT.Raw,'results','innerCircle_first_bump_outward', '2026-03-25');
ROOT.Save = fullfile(ROOT.Load, 'idPhi_MVL_beforeFirstBump');
if ~exist(ROOT.Save,'dir'), mkdir(ROOT.Save); end

%% Load data
load(fullfile(ROOT.Load, 'innerCircle_first_bump_results.mat'), 'T_bump', 'T_path');

%% Parameters
speed_thr   = 5;   % cm/s
min_run_len = 5;   % at least 5 consecutive frames

%% Output table
T_idPhiMVL = table( ...
    strings(0,1), ...   % rat
    nan(0,1), ...       % ss
    nan(0,1), ...       % trial
    strings(0,1), ...   % goal
    nan(0,1), ...       % start_direction
    nan(0,1), ...       % nFrame_total_before_bump
    nan(0,1), ...       % nFrame_used
    nan(0,1), ...       % idPhi
    nan(0,1), ...       % MVL
    strings(0,1), ...   % difficulty
    'VariableNames', {'rat','ss','trial','goal','start_direction', ...
                      'nFrame_total_before_bump','nFrame_used', ...
                      'idPhi','MVL','difficulty'});

%% Unique trial list
trial_keys = unique(T_path(:,{'rat','ss','trial','goal','start_direction'}), 'rows');

for i = 1:height(trial_keys)

    rat_k   = trial_keys.rat(i);
    ss_k    = trial_keys.ss(i);
    trial_k = trial_keys.trial(i);
    goal_k  = string(trial_keys.goal(i));
    sd_k    = trial_keys.start_direction(i);

    %% frames for this trial (already from trial start to first bump)
    idx = (T_path.rat == rat_k) & ...
          (T_path.ss == ss_k) & ...
          (T_path.trial == trial_k);

    Ts = T_path(idx,:);

    if isempty(Ts)
        continue;
    end

    %% sort by frame order within trial
    [~, ord] = sort(Ts.frame_within_trial);
    Ts = Ts(ord,:);

    nFrame_total = height(Ts);

    speed = Ts.speed;
    hd    = Ts.head_direction;

    %% 1) speed >= threshold
    is_fast = speed >= speed_thr;

    %% 2) keep only runs with consecutive length >= min_run_len
    keep_mask = false(size(is_fast));

    d = diff([0; is_fast; 0]);
    run_starts = find(d == 1);
    run_ends   = find(d == -1) - 1;

    for r = 1:numel(run_starts)
        run_len = run_ends(r) - run_starts(r) + 1;
        if run_len >= min_run_len
            keep_mask(run_starts(r):run_ends(r)) = true;
        end
    end

    %% filtered frames
    hd_use = hd(keep_mask);

    if numel(hd_use) < 2
        idphi_val = NaN;
        mvl_val   = NaN;
        n_used    = sum(keep_mask);
    else
        %% convert degree -> rad
        phi = deg2rad(hd_use);

        %% idPhi
        dphi = wrapToPi(diff(phi));
        idphi_val = sum(abs(dphi));

        %% MVL
        mvl_val = abs(mean(exp(1i*phi)));

        n_used = numel(hd_use);
    end

    %% classify difficulty
    if (strcmpi(goal_k,'West') && sd_k == 90) || (strcmpi(goal_k,'East') && sd_k == 270)
        diff_label = "difficult";
    elseif (strcmpi(goal_k,'West') && sd_k == 270) || (strcmpi(goal_k,'East') && sd_k == 90)
        diff_label = "easy";
    else
        diff_label = "other";
    end

    %% save
    T_add = table( ...
        rat_k, ss_k, trial_k, goal_k, sd_k, ...
        nFrame_total, n_used, idphi_val, mvl_val, diff_label, ...
        'VariableNames', T_idPhiMVL.Properties.VariableNames);

    T_idPhiMVL = [T_idPhiMVL; T_add];
end

%% Save result table
save(fullfile(ROOT.Save, 'idPhi_MVL_beforeFirstBump.mat'), 'T_idPhiMVL');
writetable(T_idPhiMVL, fullfile(ROOT.Save, 'idPhi_MVL_beforeFirstBump.csv'));

%% Scatter plot
Tf = T_idPhiMVL(~isnan(T_idPhiMVL.idPhi) & ~isnan(T_idPhiMVL.MVL), :);

idx_diff = Tf.difficulty == "difficult";
idx_easy = Tf.difficulty == "easy";

f = figure('Color','w','Position',[200 200 700 550]);
hold on;

%scatter(Tf.idPhi(idx_diff), Tf.MVL(idx_diff), 18, 'filled', 'MarkerFaceColor', [0.2 0.7 0.2]);
scatter(Tf.idPhi(idx_easy), Tf.MVL(idx_easy), 18, 'filled', 'MarkerFaceColor', [0.6 0.3 0.8]);

xlabel('idPhi');
ylabel('Mean Vector Length (MVL)');
title('Before first bump: idPhi vs. MVL');
legend({'Difficult','Easy'}, 'Location','best');
box on;

saveas(f, fullfile(ROOT.Save, 'scatter_idPhi_vs_MVL_beforeFirstBump.png'));
savefig(f, fullfile(ROOT.Save, 'scatter_idPhi_vs_MVL_beforeFirstBump.fig'));

disp('Done.');


% goal

Tf = T_idPhiMVL(~isnan(T_idPhiMVL.idPhi) & ~isnan(T_idPhiMVL.MVL), :);

goal_list = ["West","East"];

for g = 1:numel(goal_list)

    goal_sel = goal_list(g);
    Tg = Tf(strcmpi(string(Tf.goal), goal_sel), :);

    if isempty(Tg)
        continue;
    end

    idx_diff = Tg.difficulty == "difficult";
    idx_easy = Tg.difficulty == "easy";

    f = figure('Color','w','Position',[200 200 700 550]);
    hold on;

    scatter(Tg.idPhi(idx_diff), Tg.MVL(idx_diff), 18, ...
        'filled', 'MarkerFaceColor', [0.2 0.7 0.2]);

    % scatter(Tg.idPhi(idx_easy), Tg.MVL(idx_easy), 18, ...
    %     'filled', 'MarkerFaceColor', [0.6 0.3 0.8]);

    xlabel('idPhi');
    ylabel('Mean Vector Length (MVL)');
    title(['Before first bump: idPhi vs. MVL (' char(goal_sel) ' goal)']);
    % legend({'Difficult','Easy'}, 'Location','best');
    box on;

    saveas(f, fullfile(ROOT.Save, ...
        ['scatter_idPhi_vs_MVL_beforeFirstBump_' char(goal_sel) '.png']));
    savefig(f, fullfile(ROOT.Save, ...
        ['scatter_idPhi_vs_MVL_beforeFirstBump_' char(goal_sel) '.fig']));
end



% %% selected session only 
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
% ROOT.Load = fullfile(ROOT.Raw,'results','innerCircle_first_bump_outward', '2026-03-25');
% ROOT.Save = fullfile(ROOT.Load, 'idPhi_MVL_beforeFirstBump_selectedSessions');
% if ~exist(ROOT.Save,'dir'), mkdir(ROOT.Save); end
% 
% %% Load data
% load(fullfile(ROOT.Load, 'innerCircle_first_bump_results.mat'), 'T_path');
% 
% %% =========================
% % User selection
% % =========================
% rat_sel = "774";          % 선택할 rat
% ss_sel  = [13 14 15 16];      % 선택할 session들
% 
% %% Parameters
% speed_thr   = 5;   % cm/s
% min_run_len = 5;   % 최소 연속 frame 수
% 
% %% Select rat/session
% idx_sel = (string(T_path.rat) == rat_sel) & ismember(T_path.ss, ss_sel);
% T_path_sel = T_path(idx_sel, :);
% 
% if isempty(T_path_sel)
%     error('선택한 rat/session에 해당하는 T_path 데이터가 없습니다.');
% end
% 
% %% Output table
% T_idPhiMVL = table( ...
%     strings(0,1), ...   % rat
%     nan(0,1), ...       % ss
%     nan(0,1), ...       % trial
%     strings(0,1), ...   % goal
%     nan(0,1), ...       % start_direction
%     nan(0,1), ...       % nFrame_total_before_bump
%     nan(0,1), ...       % nFrame_used
%     nan(0,1), ...       % idPhi
%     nan(0,1), ...       % MVL
%     strings(0,1), ...   % difficulty
%     'VariableNames', {'rat','ss','trial','goal','start_direction', ...
%                       'nFrame_total_before_bump','nFrame_used', ...
%                       'idPhi','MVL','difficulty'});
% 
% %% Unique trial list
% trial_keys = unique(T_path_sel(:,{'rat','ss','trial','goal','start_direction'}), 'rows');
% 
% for i = 1:height(trial_keys)
% 
%     rat_k   = trial_keys.rat(i);
%     ss_k    = trial_keys.ss(i);
%     trial_k = trial_keys.trial(i);
%     goal_k  = string(trial_keys.goal(i));
%     sd_k    = trial_keys.start_direction(i);
% 
%     %% frames for this trial
%     idx = (string(T_path_sel.rat) == string(rat_k)) & ...
%           (T_path_sel.ss == ss_k) & ...
%           (T_path_sel.trial == trial_k);
% 
%     Ts = T_path_sel(idx,:);
% 
%     if isempty(Ts)
%         continue;
%     end
% 
%     %% sort by frame order within trial
%     [~, ord] = sort(Ts.frame_within_trial);
%     Ts = Ts(ord,:);
% 
%     nFrame_total = height(Ts);
% 
%     speed = Ts.speed;
%     hd    = Ts.head_direction;
% 
%     %% 1) speed >= threshold
%     is_fast = speed >= speed_thr;
% 
%     %% 2) keep only runs with consecutive length >= min_run_len
%     keep_mask = false(size(is_fast));
% 
%     d = diff([0; is_fast; 0]);
%     run_starts = find(d == 1);
%     run_ends   = find(d == -1) - 1;
% 
%     for r = 1:numel(run_starts)
%         run_len = run_ends(r) - run_starts(r) + 1;
%         if run_len >= min_run_len
%             keep_mask(run_starts(r):run_ends(r)) = true;
%         end
%     end
% 
%     %% filtered frames
%     hd_use = hd(keep_mask);
%     n_used = sum(keep_mask);
% 
%     if numel(hd_use) < 2
%         idphi_val = NaN;
%         mvl_val   = NaN;
%     else
%         %% degree -> rad
%         phi = deg2rad(hd_use);
% 
%         %% idPhi
%         dphi = wrapToPi(diff(phi));
%         idphi_val = sum(abs(dphi));
% 
%         %% MVL
%         mvl_val = abs(mean(exp(1i*phi)));
%     end
% 
%     %% classify difficulty
%     if (strcmpi(goal_k,'West') && sd_k == 90) || (strcmpi(goal_k,'East') && sd_k == 270)
%         diff_label = "difficult";
%     elseif (strcmpi(goal_k,'West') && sd_k == 270) || (strcmpi(goal_k,'East') && sd_k == 90)
%         diff_label = "easy";
%     else
%         diff_label = "other";
%     end
% 
%     %% save
%     T_add = table( ...
%         rat_k, ss_k, trial_k, goal_k, sd_k, ...
%         nFrame_total, n_used, idphi_val, mvl_val, diff_label, ...
%         'VariableNames', T_idPhiMVL.Properties.VariableNames);
% 
%     T_idPhiMVL = [T_idPhiMVL; T_add];
% end
% 
% %% Save result table
% save(fullfile(ROOT.Save, sprintf('idPhi_MVL_beforeFirstBump_rat%s.mat', char(rat_sel))), 'T_idPhiMVL');
% writetable(T_idPhiMVL, fullfile(ROOT.Save, sprintf('idPhi_MVL_beforeFirstBump_rat%s.csv', char(rat_sel))));
% 
% %% ===============================
% % Session-wise scatter plot
% % ===============================
% 
% for ss_k = ss_sel
% 
%     %% 해당 session만 선택
%     idx_sess = (T_idPhiMVL.ss == ss_k);
%     Tf = T_idPhiMVL(idx_sess, :);
% 
%     Tf = Tf(~isnan(Tf.idPhi) & ~isnan(Tf.MVL), :);
% 
%     if isempty(Tf)
%         fprintf('No valid data for session %d\n', ss_k);
%         continue;
%     end
% 
%     %% condition split
%     idx_diff = Tf.difficulty == "difficult";
%     idx_easy = Tf.difficulty == "easy";
% 
%     %% figure
%     f = figure('Color','w','Position',[200 200 700 550]);
%     hold on;
% 
%     scatter(Tf.idPhi(idx_diff), Tf.MVL(idx_diff), 18, 'filled', ...
%         'MarkerFaceColor', [0.2 0.7 0.2]);
% 
%     scatter(Tf.idPhi(idx_easy), Tf.MVL(idx_easy), 18, 'filled', ...
%         'MarkerFaceColor', [0.6 0.3 0.8]);
% 
%     xlabel('idPhi');
%     ylabel('MVL');
%     title(sprintf('Before first bump: idPhi vs MVL | Rat %s | Session %d', ...
%         char(rat_sel), ss_k));
% 
%     legend({'Difficult','Easy'}, 'Location','best');
%     box on;
% 
%     %% save (세션별 파일명)
%     saveas(f, fullfile(ROOT.Save, ...
%         sprintf('scatter_idPhi_vs_MVL_rat%s_ss%02d.png', char(rat_sel), ss_k)));
% 
%     close(f);   % 중요: figure 쌓이는거 방지
% end
