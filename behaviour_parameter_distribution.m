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
if ~exist(ROOT.Save,'dir')
    mkdir(ROOT.Save);
end

%% Load
load(fullfile(ROOT.Info,'session_info.mat'));   % session_list
addpath(genpath(fullfile(ROOT.Mother, 'toolbox')));   % circ_r 포함

%% Params
rat_list = {'774','779','780','781','816','817'};

dt = 0.033;        % frame interval (s)
speed_thr = 5;     % cm/s
min_run_len = 5;   % 5 frame 연속 이하속도 구간 제거

% 중요:
% Data(:,1:2) position 단위를 cm로 바꾸는 scale.
% 이미 cm 단위면 1로 두세요.
% 예: UE unit이면 적절한 변환계수로 수정 필요
pos2cm = 1;

%% Output table
T_out = table( ...
    strings(0,1), nan(0,1), nan(0,1), strings(0,1), nan(0,1), ...
    nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
    'VariableNames', {'rat','ss','trial','goal','start_direction', ...
                      'travel_distance','idPhi','mean_vector_length','nFrame'} );

%% Loop
for rr = 1:numel(rat_list)

    rat = string(rat_list{rr});
    SL  = session_list(string(session_list.rat) == rat, :);

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
        S = load(behFile, 'ue_t');
        if ~isfield(S, 'ue_t')
            fprintf('[SKIP] ue_t not found in: %s\n', behFile);
            continue;
        end
        ue_t = S.ue_t;

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

        % 최소 필요 열 확인
        if width(Data) < 7
            fprintf('[SKIP] csv has fewer columns than expected: %s\n', csvFile);
            continue;
        end

        ue_position = double(Data{:,1:2});   % x, y
        hd          = double(Data{:,7});     % head direction (deg)
        ue_trial    = double(Data{:,4});     % trial index
        ue_rza      = double(Data{:,5});     % rewardzone arrival flag

        if isempty(ue_position) || isempty(hd) || isempty(ue_trial) || isempty(ue_rza)
            fprintf('[SKIP] missing csv data: %s\n', csvFile);
            continue;
        end

        %% ===== frame-wise speed 계산 =====
        dx = diff(ue_position(:,1)) * pos2cm;
        dy = diff(ue_position(:,2)) * pos2cm;
        speed = [nan; sqrt(dx.^2 + dy.^2) ./ dt];   % cm/s

        % low-speed frame
        low_speed = speed <= speed_thr;
        low_speed(isnan(low_speed)) = false;

        % 5 frame 이상 연속인 low-speed run만 제거
        remove_mask = false(size(low_speed));

        dmask = diff([false; low_speed; false]);
        run_st = find(dmask == 1);
        run_en = find(dmask == -1) - 1;

        for ir = 1:numel(run_st)
            run_len = run_en(ir) - run_st(ir) + 1;
            if run_len >= min_run_len
                remove_mask(run_st(ir):run_en(ir)) = true;
            end
        end

        %% session temp
        T_sess = table();

        %% trial loop
        for iTrial = 1:NumberofTrial

            % performance_available filtering
            if ismember('performance_available', ue_t.Properties.VariableNames)
                if ue_t.performance_available(iTrial) ~= 1
                    continue;
                end
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

            if isempty(idx_trial)
                continue;
            end

            % ===== immobile frame 제거 =====
            idx_trial_run = idx_trial(~remove_mask(idx_trial));

            % hd NaN 제거
            idx_trial_run = idx_trial_run(~isnan(hd(idx_trial_run)));

            if numel(idx_trial_run) < 3
                continue;
            end

            hd_trial = hd(idx_trial_run);

            %% ===== idPhi =====
            % 끊어진 segment 사이 jump는 제외
            idPhi_val = 0;
            break_idx = find(diff(idx_trial_run) > 1);

            seg_st = [1; break_idx + 1];
            seg_en = [break_idx; numel(idx_trial_run)];

            for iseg = 1:numel(seg_st)
                seg_idx = idx_trial_run(seg_st(iseg):seg_en(iseg));

                if numel(seg_idx) < 2
                    continue;
                end

                phi_seg  = deg2rad(hd(seg_idx));
                dphi_seg = wrapToPi(diff(phi_seg));

                idPhi_val = idPhi_val + nansum(abs(dphi_seg));
            end

            if isempty(idPhi_val) || isnan(idPhi_val)
                continue;
            end

            %% ===== mean vector length =====
            % head direction 기반 MVL
            th = deg2rad(mod(hd_trial, 360));
            mvl_val = circ_r(th);

            if isempty(mvl_val) || isnan(mvl_val)
                continue;
            end

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
save(fullfile(ROOT.Save,'trial_table_idPhi_MVL_travelDistance_speedFiltered.mat'), 'T_out');
writetable(T_out, fullfile(ROOT.Save,'trial_table_idPhi_MVL_travelDistance_speedFiltered.csv'));

fprintf('\nSaved to:\n%s\n', ROOT.Save);

%% 출력기준 
goal_sel = "East";
sd_sel   = 270;

idx = (string(T_out.goal) == goal_sel) & (T_out.start_direction == sd_sel);
Tf = T_out(idx,:);
n = sum(~isnan(Tf.mean_vector_length));

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

% travel distance vs. mvl
figure('Position',[100 100 450 380])
scatter(Tf.travel_distance, Tf.mean_vector_length, 18, 'filled')
xlabel('Travel distance','FontSize',14)
ylabel('Mean Vector Length','FontSize',14)
xlim([0 4])
set(gca,'FontSize',13)
grid on
title(sprintf('Travel distance vs MVL (n = %d)', sum(~isnan(Tf.travel_distance) & ~isnan(Tf.mean_vector_length))), 'FontSize',15)

%% =========================================
% Select rat and sessions manually
%% =========================================

rat_sel  = "779";   % 원하는 rat
ss_first = 17;       % 비교할 session 1
ss_last  = 26;      % 비교할 session 2

%% rat data
Tr = T_out(string(T_out.rat) == rat_sel, :);

if isempty(Tr)
    error('Selected rat not found in T_out')
end

%% session data
Tf_all = Tr(Tr.ss == ss_first,:);
Tl_all = Tr(Tr.ss == ss_last,:);

if isempty(Tf_all)
    error('First session not found')
end

if isempty(Tl_all)
    error('Last session not found')
end

%% start direction list
sd_list = [90 270];

for ii = 1:numel(sd_list)

    sd_sel = sd_list(ii);

    %% filter by start direction
    Tf = Tf_all(Tf_all.start_direction == sd_sel, :);
    Tl = Tl_all(Tl_all.start_direction == sd_sel, :);

    if isempty(Tf)
        warning('No data for session %d, start_direction %d', ss_first, sd_sel);
        continue;
    end

    if isempty(Tl)
        warning('No data for session %d, start_direction %d', ss_last, sd_sel);
        continue;
    end

    %% remove NaN
    idPhi_first = Tf.idPhi(~isnan(Tf.idPhi));
    idPhi_last  = Tl.idPhi(~isnan(Tl.idPhi));

    mvl_first = Tf.mean_vector_length(~isnan(Tf.mean_vector_length));
    mvl_last  = Tl.mean_vector_length(~isnan(Tl.mean_vector_length));

    %% =========================================
    % Figure 1/2: idPhi distribution
    %% =========================================
    f1 = figure('Color','w','Position',[100 100 550 420]);
    hold on

    max_idphi = max([idPhi_first; idPhi_last]);
    if isempty(max_idphi) || isnan(max_idphi)
        max_idphi = 1;
    end
    edges_idPhi = 0:0.2:(ceil(max_idphi*5)/5 + 0.2);

    h1 = histogram(idPhi_first, ...
        'BinEdges', edges_idPhi, ...
        'Normalization','probability', ...
        'FaceColor',[0.2 0.6 0.9], ...
        'FaceAlpha',0.45, ...
        'EdgeColor','none');

    h2 = histogram(idPhi_last, ...
        'BinEdges', edges_idPhi, ...
        'Normalization','probability', ...
        'FaceColor',[0.9 0.3 0.3], ...
        'FaceAlpha',0.45, ...
        'EdgeColor','none');

    xlabel('idPhi','FontSize',14)
    ylabel('Probability','FontSize',14)
    title(sprintf('Rat %s | idPhi | Start direction = %d\nSession %d (n=%d) vs %d (n=%d)', ...
        rat_sel, sd_sel, ss_first, numel(idPhi_first), ss_last, numel(idPhi_last)), ...
        'FontSize',15)

    legend([h1 h2], ...
        {sprintf('Session %d', ss_first), sprintf('Session %d', ss_last)}, ...
        'Location','best')

    set(gca,'FontSize',13)
    grid on
    box off

    %% =========================================
    % Figure 3/4: MVL distribution
    %% =========================================
    f2 = figure('Color','w','Position',[150 150 550 420]);
    hold on

    edges_mvl = 0:0.05:1;

    h3 = histogram(mvl_first, ...
        'BinEdges', edges_mvl, ...
        'Normalization','probability', ...
        'FaceColor',[0.2 0.6 0.9], ...
        'FaceAlpha',0.45, ...
        'EdgeColor','none');

    h4 = histogram(mvl_last, ...
        'BinEdges', edges_mvl, ...
        'Normalization','probability', ...
        'FaceColor',[0.9 0.3 0.3], ...
        'FaceAlpha',0.45, ...
        'EdgeColor','none');

    xlabel('Mean Vector Length','FontSize',14)
    ylabel('Probability','FontSize',14)
    title(sprintf('Rat %s | MVL | Start direction = %d\nSession %d (n=%d) vs %d (n=%d)', ...
        rat_sel, sd_sel, ss_first, numel(mvl_first), ss_last, numel(mvl_last)), ...
        'FontSize',15)

    legend([h3 h4], ...
        {sprintf('Session %d', ss_first), sprintf('Session %d', ss_last)}, ...
        'Location','best')

    set(gca,'FontSize',13)
    grid on
    box off
    xlim([0 1])
    xticks(0:0.1:1)

end

%% =========================
% Local function
%% =========================
function col = getUETCol(T, varName1, varName2)
% getUETCol: ue_t에서 변수명 후보를 찾아 column을 반환
% 없으면 nan(height(T),1)

    names = string(T.Properties.VariableNames);

    idx1 = find(strcmpi(names, string(varName1)), 1);
    idx2 = find(strcmpi(names, string(varName2)), 1);

    if ~isempty(idx1)
        col = T.(T.Properties.VariableNames{idx1});
    elseif ~isempty(idx2)
        col = T.(T.Properties.VariableNames{idx2});
    else
        col = nan(height(T),1);
    end

    if iscell(col)
        try
            col = cellfun(@double, col);
        catch
            col = nan(height(T),1);
        end
    end

    if isrow(col)
        col = col';
    end
end