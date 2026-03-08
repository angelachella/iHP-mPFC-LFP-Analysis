clc; clear; close all;

%% Root
ROOT.Mother = 'D:';
ROOT.Raw    = [ROOT.Mother '\1. Behavioral data'];
ROOT.Info   = [ROOT.Raw '\info'];
ROOT.Data   = [ROOT.Raw '\results\behavior\15-May-2024\'];

today_is = datetime('today');
today_is.Format = 'yyyy-MM-dd';
today_is = char(today_is);

ROOT.Save = fullfile(ROOT.Raw, 'results', 'idPhi_analysis', today_is);
if ~exist(ROOT.Save,'dir'), mkdir(ROOT.Save); end

%% Load
load(fullfile(ROOT.Info, 'session_info.mat'));   % session_list

rat_list = {'774','779','780','781','816','817'};

%% Output table
T_out = table( ...
    strings(0,1), nan(0,1), nan(0,1), strings(0,1), nan(0,1), ...
    nan(0,1), nan(0,1), ...
    'VariableNames', {'rat','ss','trial','goal','start_direction', ...
                      'idPhi','nFrame'});

%% Loop all rats / sessions
for rr = 1:numel(rat_list)

    rat = string(rat_list{rr});
    SL  = session_list(string(session_list.rat)==rat, :);

    for k = 1:height(SL)

        ss_num = SL.ss(k);
        if isstring(ss_num) || ischar(ss_num)
            ss_num = str2double(ss_num);
        end

        %% --- load MAT ---
        target  = char(rat + "-" + sprintf('%02d', ss_num));
        behFile = fullfile(ROOT.Data, [target '.mat']);

        if ~exist(behFile, 'file')
            fprintf('[SKIP] mat not found: %s\n', behFile);
            continue;
        end

        load(behFile, 'ue_t');

        %% --- load CSV ---
        csvFile = fullfile(ROOT.Info, ...
            ['LE' char(rat)], ...
            ['LE' char(rat) '_Post-main_' num2str(ss_num) '.csv']);

        if ~exist(csvFile,'file')
            fprintf('[SKIP] csv not found: %s\n', csvFile);
            continue;
        end

        Data = readtable(csvFile);

        hd       = double(Data{:,7});   % head direction (deg)
        ue_trial = Data{:,4};           % trial index
        ue_rza   = Data{:,5};           % rewardzone arrival flag

        % behaviour info
        NumberofTrial = height(ue_t);
        start_dir_all = ue_t{:,'start_direction'};

        %% Trial loop
        T_sess = table();

        for iTrial = 1:NumberofTrial

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

            hd_trial = hd(idx_trial);
            hd_trial = hd_trial(~isnan(hd_trial));

            %% idPhi calculation
            phi  = deg2rad(hd_trial); % radian으로 변환
            dphi = wrapToPi(diff(phi)); % 무조건 짧은쪽 회전량으로 계산 

            if isempty(dphi)
                continue;
            end

            idPhi_val = nansum(abs(dphi)); %절댓값-->전체합(한 trial당 회전값 누적) 
            nFrame_val = numel(hd_trial);

            goal_str  = string(SL.goal(k));
            start_dir = start_dir_all(iTrial);

            T_add = table( ...
                rat, ss_num, iTrial, goal_str, start_dir, ...
                idPhi_val, nFrame_val, ...
                'VariableNames', T_out.Properties.VariableNames);

            T_sess = [T_sess; T_add];
        end

        T_out = [T_out; T_sess];
        fprintf('[OK] %s : %d trials\n', target, height(T_sess));
    end
end

%% Save
save(fullfile(ROOT.Save, 'idPhi_trial_table.mat'), 'T_out');
writetable(T_out, fullfile(ROOT.Save, 'idPhi_trial_table.csv'));

%% Histogram
goal_sel = "West";
sd_sel   = 90;

idx = (string(T_out.goal) == goal_sel) & ...
      (T_out.start_direction == sd_sel);

Tf = T_out(idx,:);
n = height(Tf);   % trial 수

figure

% histogram bin width
histogram(Tf.idPhi,'BinWidth',0.5)

xlabel('idPhi','FontSize',14)
ylabel('Trials','FontSize',14)
title(sprintf('Goal = %s, Start = %d (n = %d)', goal_sel, sd_sel, n),'FontSize',18)

% x축 범위
xlim([0 20])

% x축 tick 간격
xticks(0:1:20)

% 폰트 전체 키우기
set(gca,'FontSize',14)

grid on