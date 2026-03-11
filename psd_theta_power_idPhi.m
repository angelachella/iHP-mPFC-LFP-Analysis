clc; clear; close all;

%% Root setting
ROOT.Mother = 'D:';
ROOT.Raw    = fullfile(ROOT.Mother,'1. Behavioral data');
ROOT.Info   = fullfile(ROOT.Raw,'info');
ROOT.Data   = fullfile(ROOT.Raw,'results','behavior','15-May-2024');

today_is = datetime('today');
today_is.Format = 'yyyy-MM-dd';
today_is = char(today_is);

ROOT.Save = fullfile(ROOT.Raw,'results','idPhi_MVL_analysis', today_is);
if ~exist(ROOT.Save,'dir'), mkdir(ROOT.Save); end

%% Load
load(fullfile(ROOT.Info,'session_info.mat'));   % session_list
addpath(genpath(fullfile(ROOT.Mother, 'toolbox')));   % circ_r 포함

%% Params
rat_list = {'774','779','780','781','816','817'};

%% Output table
T_out = table( ...
    strings(0,1), nan(0,1), nan(0,1), strings(0,1), nan(0,1), ...
    nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
    'VariableNames', {'rat','ss','trial','goal','start_direction', ...
                      'travel_distance','idPhi','mean_vector_length','nFrame'} );

%% Loop
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
        load(behFile, 'ue_t');

        NumberofTrial = height(ue_t);

        start_dir_all   = getUETCol(ue_t, "start_direction", "start_direction");
        travel_dist_all = getUETCol(ue_t, "travaled_distance", "travaled distance");
        

        %% load CSV
        csvFile = fullfile(ROOT.Info, ['LE' char(rat)], ...
            ['LE' char(rat) '_Post-main_' num2str(ss_num) '.csv']);

        if ~exist(csvFile,'file')
            fprintf('[SKIP] csv not found: %s\n', csvFile);
            continue;
        end

        Data = readtable(csvFile);

        ue_position = Data{:,1:2};        % x, y
        hd          = double(Data{:,7});  % head direction (deg)
        ue_trial    = Data{:,4};          % trial index
        ue_rza      = Data{:,5};          % rewardzone arrival flag

        %% session temp
        T_sess = table();

        %% trial loop
        for iTrial = 1:NumberofTrial
            % performance_available filtering
                if ue_t.performance_available(iTrial) ~= 1
                    continue;
                end

            % CSV에서 해당 trial frame
            idx_trial = find(ue_trial == iTrial);
            if isempty(idx_trial)
                continue;
            end

            % reward zone arrival 이전까지만 사용
            idx_rza = idx_trial(ue_rza(idx_trial) == 1);
            if ~isempty(idx_rza)
                last_idx = idx_rza(1);
                idx_trial = idx_trial(idx_trial <= last_idx);
            end

            % head direction
            hd_trial = hd(idx_trial);
            hd_trial = hd_trial(~isnan(hd_trial));

            if numel(hd_trial) < 3
                continue;
            end

            %% ===== idPhi =====
            phi  = deg2rad(hd_trial);
            dphi = wrapToPi(diff(phi));

            if isempty(dphi)
                continue;
            end

            idPhi_val = nansum(abs(dphi));

            %% ===== mean vector length =====
            % head direction 기반 MVL
            th = deg2rad(mod(hd_trial, 360));
            mvl_val = circ_r(th);

            %% ===== nFrame =====
            nFrame_val = numel(hd_trial);

            %% ===== behaviour info from ue_t =====
            if iTrial <= numel(start_dir_all)
                start_dir = start_dir_all(iTrial);
            else
                start_dir = nan;
            end

            if iTrial <= numel(travel_dist_all)
                travel_dst = travel_dist_all(iTrial);
            else
                travel_dst = nan;
            end

            goal_str = string(SL.goal(k));

            T_add = table( ...
                rat, ss_num, iTrial, goal_str, start_dir, ...
                travel_dst, idPhi_val, mvl_val, nFrame_val, ...
                'VariableNames', T_out.Properties.VariableNames);

            T_sess = [T_sess; T_add];
        end

        T_out = [T_out; T_sess];
        fprintf('[OK] %s trials=%d\n', target, height(T_sess));
    end
end

%% Save
save(fullfile(ROOT.Save,'trial_table_idPhi_MVL_travelDistance.mat'), 'T_out');
writetable(T_out, fullfile(ROOT.Save,'trial_table_idPhi_MVL_travelDistance.csv'));


%% 출력조건입력
goal_sel = "East";
sd_sel   = 270;

idx = (string(T_out.goal) == goal_sel) & (T_out.start_direction == sd_sel);
Tf = T_out(idx,:);
n  = sum(~isnan(Tf.mean_vector_length));

%% Example 1: Histogram of idPhi
figure('Position',[100 100 500 400])
histogram(Tf.travel_distance, 0:0.2:4)
xlabel('travel distance(m)','FontSize',14)
xticks(0:0.2:4)
ylabel('Trials','FontSize',14)
title(sprintf('Goal = %s, Start = %d (n = %d)', goal_sel, sd_sel, n),'FontSize',18)

set(gca,'FontSize',14)
grid on

%% Example 2: Histogram of MVL
n = sum(~isnan(Tf.mean_vector_length));

figure('Position',[100 100 500 400])
histogram(Tf.mean_vector_length, 0:0.1:1)
xlabel('MVL','FontSize',14)
ylabel('Trials','FontSize',14)
title(sprintf('Goal = %s, Start = %d (n = %d)', goal_sel, sd_sel, n),'FontSize',18)
xlim([0 1])
xticks(0:0.1:1)
set(gca,'FontSize',14)
grid on

%% Example 3: Scatter plots
% idPhi vs mvl
figure('Position',[100 100 450 380])
scatter(Tf.idPhi, Tf.mean_vector_length, 18, 'filled')
xlabel('idPhi','FontSize',14)
ylabel('Mean Vector Length','FontSize',14)
set(gca,'FontSize',13)
grid on
title(sprintf('idPhi vs MVL (n = %d)', sum(~isnan(Tf.idPhi) & ~isnan(Tf.mean_vector_length))), 'FontSize',15)

% travel distance vs idPhi
figure('Position',[100 100 450 380])
scatter(Tf.travel_distance, Tf.idPhi, 18, 'filled')
xlabel('Travel distance','FontSize',14)
%xlim([0 4])
ylabel('idPhi','FontSize',14)
set(gca,'FontSize',13)
grid on
title(sprintf('Travel distance vs idPhi (n = %d)', sum(~isnan(Tf.travel_distance) & ~isnan(Tf.idPhi))), 'FontSize',15)

% travel distance vs mvl
figure('Position',[100 100 450 380])
scatter(Tf.travel_distance, Tf.mean_vector_length, 18, 'filled')
xlabel('Travel distance','FontSize',14)
ylabel('Mean Vector Length','FontSize',14)
xlim([0 4])
set(gca,'FontSize',13)
grid on
title(sprintf('Travel distance vs MVL (n = %d)', sum(~isnan(Tf.travel_distance) & ~isnan(Tf.mean_vector_length))), 'FontSize',15)

% idPhi vs mvl
figure('Position',[100 100 450 380])
scatter(Tf.idPhi, Tf.mean_vector_length, 18, 'filled')
xlim([0 15])
xticks(0:1:15)
xlabel('idPhi','FontSize',14)
ylabel('Mean Vector Length','FontSize',14)
set(gca,'FontSize',13)
grid on
title(sprintf('idPhi vs MVL (n = %d)', ...
    sum(~isnan(Tf.idPhi) & ~isnan(Tf.mean_vector_length))), 'FontSize',15)

%% 3. session별 분포
T = T_out;

%% type 정리
T.rat = string(T.rat);

if ~isnumeric(T.ss)
    T.ss = double(string(T.ss));
end

%% NaN 제거
idx_valid = ~isnan(T.idPhi) & ~isnan(T.mean_vector_length);
T = T(idx_valid,:);

%% rat-session 목록
sess_keys = unique(T(:,{'rat','ss'}),'rows');

for k = 1:height(sess_keys)

    rat_k = sess_keys.rat(k);
    ss_k  = sess_keys.ss(k);

    %% 해당 session 데이터
    idx = (T.rat == rat_k) & (T.ss == ss_k);
    Ts  = T(idx,:);

    if isempty(Ts)
        continue
    end

    %% start direction 분리
    idx_90  = Ts.start_direction == 90;
    idx_270 = Ts.start_direction == 270;

    %% figure
    f = figure('Color','w','Position',[200 200 650 500]);
    hold on

    scatter(Ts.idPhi(idx_90),  Ts.mean_vector_length(idx_90), 40, 'r', 'filled')
    scatter(Ts.idPhi(idx_270), Ts.mean_vector_length(idx_270), 40, 'b', 'filled')

    xlabel('idPhi')
    ylabel('Mean Vector Length')
    title(sprintf('Rat %s  |  Session %d', rat_k, ss_k))

    legend({'Start dir 90','Start dir 270'},'Location','best')
    grid on
    box off

    %% save
    save_name = sprintf('rat%s_ss%d_mvl_idPhi.png',rat_k,ss_k);
    exportgraphics(f, fullfile(ROOT.Save, save_name),'Resolution',300)

    close(f)

end

%% 4.rotation = 90 vs. 270
%===== All rats / all sessions / all trials =====
idx_valid = ~isnan(T.idPhi) & ~isnan(T.mean_vector_length);
T2 = T(idx_valid,:);

% 그룹 정의
idx_green = (strcmpi(string(T2.goal),"West") & T2.start_direction == 90) | ...
            (strcmpi(string(T2.goal),"East") & T2.start_direction == 270);

idx_purple = (strcmpi(string(T2.goal),"West") & T2.start_direction == 270) | ...
             (strcmpi(string(T2.goal),"East") & T2.start_direction == 90);

f = figure('Color','w','Position',[200 200 700 550]);
hold on

scatter(T2.idPhi(idx_green),  T2.mean_vector_length(idx_green),  26, ...
    [0.2 0.65 0.2], 'filled')   % green

scatter(T2.idPhi(idx_purple), T2.mean_vector_length(idx_purple), 26, ...
    [0.5 0.2 0.7], 'filled')    % purple

xlabel('idPhi','FontSize',14)
xlim([0 20])
ylabel('Mean Vector Length','FontSize',14)
title('All rats | All sessions','FontSize',16)

legend({ ...
    'West+90 / East+270', ...
    'West+270 / East+90'}, ...
    'Location','best')

set(gca,'FontSize',13)
grid on
box off

%% 4.rotation = 90 vs. 270
%===== All rats / all sessions / all trials =====
%% 4.rotation = 90 vs. 270
%===== All rats / all sessions / all trials =====

idx_valid = ~isnan(T.idPhi) & ~isnan(T.mean_vector_length);
T2 = T(idx_valid,:);

goal_list = ["West","East"];

for g = 1:length(goal_list)

    goal_sel = goal_list(g);

    % goal filtering
    Tg = T2(strcmpi(string(T2.goal), goal_sel), :);

    % rotation grouping
    if goal_sel == "West"
        idx_green  = Tg.start_direction == 90;
        idx_purple = Tg.start_direction == 270;
    else % East
        idx_green  = Tg.start_direction == 270;
        idx_purple = Tg.start_direction == 90;
    end

    f = figure('Color','w','Position',[200 200 700 550]);
    hold on

    scatter(Tg.idPhi(idx_green), Tg.mean_vector_length(idx_green), 26, ...
        [0.2 0.65 0.2], 'filled')   % green

    scatter(Tg.idPhi(idx_purple), Tg.mean_vector_length(idx_purple), 26, ...
        [0.5 0.2 0.7], 'filled')    % purple

    xlabel('idPhi','FontSize',14)
    xlim([0 20])
    ylabel('Mean Vector Length','FontSize',14)

    title(sprintf('All rats | All sessions | Goal = %s', goal_sel),'FontSize',16)

    legend({ ...
        'Rotation A', ...
        'Rotation B'}, ...
        'Location','best')

    set(gca,'FontSize',13)
    grid on

end



%%===== Session-wise plot =====
idx_valid = ~isnan(T.idPhi) & ~isnan(T.mean_vector_length);
T2 = T(idx_valid,:);

%% rat-session 목록
sess_keys = unique(T2(:,{'rat','ss'}),'rows');

for k = 1:height(sess_keys)

    rat_k = sess_keys.rat(k);
    ss_k  = sess_keys.ss(k);

    %% 해당 session 데이터
    idx = (T2.rat == rat_k) & (T2.ss == ss_k);
    Ts  = T2(idx,:);

    if isempty(Ts)
        continue
    end

    %% 그룹 정의
    idx_green = (strcmpi(string(Ts.goal),"West") & Ts.start_direction == 90) | ...
                (strcmpi(string(Ts.goal),"East") & Ts.start_direction == 270);

    idx_purple = (strcmpi(string(Ts.goal),"West") & Ts.start_direction == 270) | ...
                 (strcmpi(string(Ts.goal),"East") & Ts.start_direction == 90);

    %% figure
    f = figure('Color','w','Position',[200 200 650 500]);
    hold on

    scatter(Ts.idPhi(idx_green),  Ts.mean_vector_length(idx_green), 40, ...
        [0.2 0.65 0.2], 'filled')

    scatter(Ts.idPhi(idx_purple), Ts.mean_vector_length(idx_purple), 40, ...
        [0.5 0.2 0.7], 'filled')

    xlabel('idPhi','FontSize',14)
    ylabel('Mean Vector Length','FontSize',14)
    title(sprintf('Rat %s | Session %d', string(rat_k), ss_k), 'FontSize',16)

    legend({ ...
        'Far-goal(270)', ...
        'Near-goal(90)'}, ...
        'Location','best')

    set(gca,'FontSize',13)
    grid on
    box off

    save
    save_name = sprintf('rat%s_ss%d_mvl_idPhi_grouped.png', string(rat_k), ss_k);
    exportgraphics(f, fullfile(ROOT.Save, save_name), 'Resolution', 300)
close(f);
end
% save_name = 'allrats_allsessions_mvl_idPhi_grouped.png';
% exportgraphics(f, fullfile(ROOT.Save, save_name), 'Resolution', 300)


%% ===================== functions =====================

function col = getUETCol(ue_t, name1, name2)
n = height(ue_t);
col = nan(n,1);

try
    if istable(ue_t) && any(strcmp(ue_t.Properties.VariableNames, char(name1)))
        col = ue_t.(char(name1));
        col = col(:);
        return;
    end
end

try
    if istable(ue_t) && any(strcmp(ue_t.Properties.VariableNames, char(name2)))
        col = ue_t{:, char(name2)};
        col = col(:);
        return;
    end
end
end