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
    nan(0,1), nan(0,1), nan(0,1), ...
    'VariableNames', {'rat','ss','trial','goal','start_direction', ...
                      'idPhi','mean_idPhi','nFrame'});

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

        ue_position = Data{:,1:2};        % x,y
        hd          = double(Data{:,7});  %#ok<NASGU>
        ue_trial    = Data{:,4};          % trial index
        ue_rza      = Data{:,5};          % rewardzone arrival flag

        x_all = ue_position(:,1);
        y_all = ue_position(:,2);

        % behaviour info from ue_t
        NumberofTrial = height(ue_t);
        start_dir_all = ue_t{:,'start_direction'};

        %% Trial loop
        T_sess = table();

        for iTrial = 1:NumberofTrial

            % 해당 trial frame들
            idx_trial = find(ue_trial == iTrial);

            if isempty(idx_trial)
                continue;
            end

            % rewardzone arrival 이전까지만 쓰고 싶으면:
            idx_rza = idx_trial(ue_rza(idx_trial) == 1);
            if ~isempty(idx_rza)
                last_idx = idx_rza(1);                 % 첫 rewardzone arrival frame
                idx_trial = idx_trial(idx_trial <= last_idx);
            end

            x = x_all(idx_trial);
            y = y_all(idx_trial);

            % remove NaN
            keep_xy = ~isnan(x) & ~isnan(y);
            x = x(keep_xy);
            y = y(keep_xy);

            if numel(x) < 3
                continue;
            end

            %% movement direction
            dx = diff(x);
            dy = diff(y);

            % zero movement 제거
            keep_move = ~(dx == 0 & dy == 0);
            dx = dx(keep_move);
            dy = dy(keep_move);

            if numel(dx) < 2
                continue;
            end

            phi  = atan2(dy, dx);        % radians
            dphi = wrapToPi(diff(phi));  % radians

            if isempty(dphi)
                continue;
            end

            abs_dphi = abs(dphi);

            idPhi_val      = nansum(abs_dphi);
            mean_idPhi_val = mean(abs_dphi, 'omitnan');
            nFrame_val     = numel(x);

            goal_str  = string(SL.goal(k));
            start_dir = start_dir_all(iTrial);

            T_add = table( ...
                rat, ss_num, iTrial, goal_str, start_dir, ...
                idPhi_val, mean_idPhi_val, nFrame_val, ...
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

%% Histogram: idPhi
x = T_out.idPhi;
x = x(~isnan(x));

f1 = figure('Position',[100 100 500 400]);
histogram(x, 30);
xlabel('idPhi (rad)');
ylabel('Number of trials');
title(sprintf('Trial-wise idPhi distribution (n = %d)', numel(x)));
grid on;
exportgraphics(f1, fullfile(ROOT.Save, 'hist_idPhi.png'), 'Resolution', 300);
close(f1);

%% Histogram: mean_idPhi
x = T_out.mean_idPhi;
x = x(~isnan(x));

f2 = figure('Position',[100 100 500 400]);
histogram(x, 30);
xlabel('Mean |dPhi| per step (rad)');
ylabel('Number of trials');
title(sprintf('Trial-wise mean idPhi distribution (n = %d)', numel(x)));
grid on;
exportgraphics(f2, fullfile(ROOT.Save, 'hist_mean_idPhi.png'), 'Resolution', 300);
close(f2);

disp('DONE');