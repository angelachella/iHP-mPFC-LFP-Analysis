clc; clear; close all;

%% ROOT
ROOT.Mother = 'D:';
ROOT.Raw  = fullfile(ROOT.Mother,'1. Behavioral data');
ROOT.Info = fullfile(ROOT.Raw,'info');
ROOT.Data = fullfile(ROOT.Raw,'results','behavior','15-May-2024');

%% Load session list
load(fullfile(ROOT.Info,'session_info.mat'));
addpath(genpath(fullfile(ROOT.Mother, 'toolbox')));

%% Initialize output
Tall = table;

%% Loop over rats
rats = unique(session_list.rat);

for r = 1:numel(rats)

    rat = char(rats(r));
    SL  = session_list(string(session_list.rat)==rat, :);

   for s = 1:height(SL)

    %% --- session info ---
    ss_num = str2double(string(SL.ss(s)));
    ss_str = sprintf('%02d', ss_num);
    target = [rat '-' ss_str];

    %% --- load behavior file ---
    behFile = fullfile(ROOT.Data, [target '.mat']);
    if ~exist(behFile,'file'), continue; end
    load(behFile,'ue_t');

    goal = string(SL.goal(s));

    %% --- load CSV ---
    csvFile = fullfile(ROOT.Info, ...
        ['LE' rat], ...
        ['LE' rat '_Post-main_' num2str(ss_num) '.csv']);

    if ~exist(csvFile,'file'), continue; end

    Data = readtable(csvFile);

    ue_position = Data{:,1:2};        % x,y
    hd          = double(Data{:,7});  % head direction
    ue_trial    = Data{:,4};          % trial index
    ue_rza      = Data{:,5};          % rewardzone arrival flag

    hd = double(hd);

    %% ===== trial loop =====
    trial_list = unique(ue_trial);
    trial_list = trial_list(~isnan(trial_list));   % 안전
    
    for k = 1:length(trial_list)

    tr = trial_list(k);   % CSV trial 번호

    ...

        % navigation 구간만 (rewardzone 도착 전)
        idx_nav = find(ue_trial == tr & ue_rza == 0);

        % head direction NaN 제거
        idx_nav = idx_nav(~isnan(hd(idx_nav)));

        if numel(idx_nav) < 6
            continue;
        end

        %% --- position ---
        x_temp = ue_position(idx_nav,1);
        y_temp = ue_position(idx_nav,2);

        %% --- velocity 계산 (cm/s) ---
        dist_cm = sqrt(diff(x_temp).^2 + diff(y_temp).^2) * (0.6/9500) * 100;
        vel_temp = dist_cm * 30;  % dt=1/30

        vel_frame = [NaN; vel_temp];  % 길이 맞추기

        %% --- 5 frame 연속 ≥5 cm/s ---
        run_mask = false(size(vel_frame));

        for j = 1:numel(vel_frame)-4
            if all(vel_frame(j:j+4) >= 5)
                run_mask(j:j+4) = true;
            end
        end

        running_idx = idx_nav(run_mask);

        if isempty(running_idx)
            continue;
        end

        %% --- circular mean head direction (running only) ---
        th = deg2rad(mod(hd(running_idx),360));
        C  = mean(cos(th));
        S  = mean(sin(th));
        meanHD = mod(rad2deg(atan2(S,C)),360);
        
        %% ✅ vector length (mean resultant length)
        R = circ_r(th);   % 0~1, 방향 집중도

        %% --- travel distance ---
        if k <= numel(ue_t.travaled_distance)
            dist = ue_t.travaled_distance(k);
        else
            dist = NaN;
        end
        
        %% --- start direction ---
        if k <= numel(ue_t.start_direction)
            sd = ue_t.start_direction(k);
        else
            sd = NaN;
        end

        %% --- append ---
        Trow = table( ...
        string(rat), string(ss_str), goal, tr, meanHD, R, sd, dist, ...
        'VariableNames', {'rat','ss','goal','trial','mean_head_direction','R','start_direction','travel_distance'} );

        Tall = [Tall; Trow];

    end
end
end
save(fullfile(ROOT.Data,'AllRats_HD_running_only.mat'),'Tall');


%% ===== 원하는 조건 =====
goal_want = "West";   % "West" or "East"
sd_want   = 90;       % North=90, South=270 (너 데이터 기준)

%% ===== filter =====
Tf = Tall( Tall.goal == goal_want & Tall.start_direction == sd_want , :);

% NaN 제거
Tf = Tf(~isnan(Tf.mean_head_direction) & ~isnan(Tf.travel_distance), :);

figure;
scatter(Tf.travel_distance, Tf.R, 30, 'filled');
xlabel('Travel Distance');
ylabel('Vector Length (R)');
ylim([0 1]);
grid on;


% %% ===== plot =====
% figure('Color','w');
% scatter(Tf.mean_head_direction, Tf.travel_distance, 30, 'filled');
% 
% xlim([0 360]); xticks(0:60:360);
% xlabel('Head Direction (circular mean)');
% ylabel('Travel Distance');
% title(sprintf('%s goal | startdirection = %d', goal_want, sd_want));
% grid on;

%% individual session
% clc; clear; close all;
% 
% %% ===== target =====
% target = '816-04';
% 
% %% ===== paths =====
% ROOT.Mother = 'D:';
% ROOT.Raw    = fullfile(ROOT.Mother,'1. Behavioral data');
% ROOT.Data   = fullfile(ROOT.Raw,'results','behavior','15-May-2024');
% ROOT.Save   = fullfile(ROOT.Data,'navigational strategy');
% 
% tmp   = split(string(target),"-");
% rat   = tmp(1);
% ssNum = str2double(tmp(2));
% ss2   = sprintf('%02d', ssNum);
% 
% toutDir  = fullfile(ROOT.Save, "LE"+rat, rat+"-"+ss2, "rose_head_direction");
% toutFile = fullfile(toutDir, "Tout.mat");
% behFile  = fullfile(ROOT.Data, sprintf('%s-%s.mat', rat, ss2));
% 
% %% ===== load =====
% load(toutFile, 'Tout');
% load(behFile,  'ue_t');
% 
% %% ===== trial-level mean head direction =====
% trial_list = unique(Tout.trial);
% trial_list = sort(trial_list);
% 
% meanHD = nan(numel(trial_list),1);
% dist   = nan(numel(trial_list),1);
% 
% for k = 1:numel(trial_list)
%     tr = trial_list(k);
% 
%     hd = Tout.head_direction(Tout.trial==tr);
%     hd = hd(~isnan(hd));
% 
%     if ~isempty(hd)
%         th = deg2rad(mod(hd,360));
%         C  = mean(cos(th));
%         S  = mean(sin(th));
%         meanHD(k) = mod(rad2deg(atan2(S,C)), 360);
%     end
% 
%     if tr <= numel(ue_t.travaled_distance)
%         dist(k) = ue_t.travaled_distance(tr);
%     end
% end
% 
% %% ===== Scatter plot =====
% figure('Color','w');
% 
% scatter(meanHD, dist, 35, 'filled');
% xlim([0 360]); xticks(0:60:360);
% xlabel('Mean Head Direction (deg)');
% ylabel('Travel Distance');
% title(sprintf('%s: Mean Head direction vs Travel Distance', target));
% grid on;
% 
% %% optional: correlation
% [r,p] = corr(meanHD, dist, 'rows','complete');
% fprintf('Pearson r = %.3f, p = %.4f\n', r, p);