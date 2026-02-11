% clc; clear; close all;
% 
% %% paths
% ROOT.Mother = 'D:';
% ROOT.Raw  = [ROOT.Mother '\1. Behavioral data'];
% ROOT.Info = [ROOT.Raw '\info'];
% ROOT.Data = [ROOT.Raw '\results\behavior\15-May-2024\'];
% 
% %% load session list
% load([ROOT.Info '\session_info.mat']);   % session_list 필요
% 
% rat = "779";
% SL  = session_list(string(session_list.rat)==rat, :);
% 
% %% 결과 저장
% ss_all = [];
% lat_all = [];
% corr_all = [];
% ss_all   = [];
% for k = 1:height(SL)
% 
%     ss_num = SL.ss(k);
%     if isstring(ss_num) || ischar(ss_num)
%         ss_num = str2double(ss_num);
%     end
% 
%     target  = char(rat + "-" + sprintf('%02d', ss_num));
%     behFile = fullfile(ROOT.Data, [target '.mat']);
%     if ~exist(behFile,'file')
%         continue;
%     end
% 
%     load(behFile);   % ue_t 로드됨
% 
%     % ue_t columns:
%     % 9 = latency
%     % 8 = performance_available
%     latency = ue_t{:,9};
%     avail   = ue_t{:,8};
%     correct = ue_t{:,7};
% 
%     %lat_all(end+1,1) = median(latency(avail==1), 'omitnan');
%     valid = (avail == 1);
% 
%     corr_all(end+1,1) = sum(correct(valid) == 1) / sum(valid) * 100;
%     ss_all(end+1,1)  = ss_num;
% end
% %% sort by session
% [ss_all, ord] = sort(ss_all);
% % lat_all = lat_all(ord);
% 
% %% plot
% figure('Color','w'); hold on; box on;
% plot(ss_all, corr_all, '-o', 'LineWidth', 1.5, 'Color' ,"r");
% 
% xlabel('Session');
% ylabel('correctness');
% %title('LE779 session-wise latency');
% 
% 
clc; clear; close all;

%% paths
ROOT.Mother = 'D:';
ROOT.Raw  = [ROOT.Mother '\1. Behavioral data'];
ROOT.Info = [ROOT.Raw '\info'];
ROOT.Data = [ROOT.Raw '\results\behavior\15-May-2024\'];

%% load session list
load([ROOT.Info '\session_info.mat']);   % session_list 필요

%% rats to run
rat_list = ["774","779","780","781","816","817"];

%% 결과 저장용 (long format)
Tcorr = table(strings(0,1), nan(0,1), nan(0,1), ...
    'VariableNames', {'rat','ss','latency'});

for r = 1:numel(rat_list)

    rat = rat_list(r);
    SL  = session_list(string(session_list.rat)==rat, :);

    for k = 1:height(SL)

        ss_num = SL.ss(k);
        if isstring(ss_num) || ischar(ss_num)
            ss_num = str2double(ss_num);
        end

        target  = char(rat + "-" + sprintf('%02d', ss_num));
        behFile = fullfile(ROOT.Data, [target '.mat']);
        if ~exist(behFile,'file')
            continue;
        end

        load(behFile);   % ue_t 로드됨

        % ue_t columns:
        % 9 = latency
        % 8 = performance_available
        % 7 = correct (1/0)
        avail   = ue_t{:,8};
        correct = ue_t{:,7};
        latency = ue_t{:,9};
        tdistance = ue_t{:,10};

        valid = (avail == 1);
        % if sum(valid) == 0
        %     continue;
        % end
        % 
        % corr_pct = sum(correct(valid) == 1) / sum(valid) * 100;
       latency = median(latency);

        % append row
        Tcorr = [Tcorr; {rat, ss_num, latency}];
    end
end

%% sort
Tcorr.rat = string(Tcorr.rat);
Tcorr = sortrows(Tcorr, {'rat','ss'});

% (optional) save
save(fullfile(ROOT.Info, 'Tcorr_latency_allrats.mat'), 'Tcorr');

disp(Tcorr);

%% ===== pick sessions per rat & plot =====
% Tcorr (rat, ss, correctness) 가 이미 workspace에 있다고 가정

% 1) rat별로 사용할 세션 지정 (여기만 네가 원하는대로 계속 추가/수정)
pick = struct();
pick.LE774 = [9 10 11];
pick.LE779 = [24 25 26];
pick.LE780 = [7 8 9];
pick.LE781 = [10 11 12];
pick.LE816 = [3 4 5];
pick.LE817 = [3 4 5];

rat_list = ["774","779","780","781","816","817"];

% 2) aligned table 만들기 (원래 ss도 같이 저장)
Talign = table(strings(0,1), nan(0,1), nan(0,1), nan(0,1), ...
    'VariableNames', {'rat','ss_orig','x_align','latency'});

for r = 1:numel(rat_list)

    rat = rat_list(r);
    field = "LE" + rat;

    if ~isfield(pick, field), continue; end
    ss3 = pick.(field);
    if numel(ss3) ~= 3, continue; end

    x3 = [-1; 0; 1];

    % 이 rat의 데이터
    Tr = Tcorr(Tcorr.rat==rat, :);
    if isempty(Tr), continue; end

    for j = 1:3
        ssj = ss3(j);

        idx = (Tr.ss == ssj);
        if ~any(idx)
            continue; % 지정한 세션이 Tcorr에 없으면 스킵
        end

        % 같은 세션이 중복으로 있으면 평균으로 1개만 쓰기
        y = mean(Tr.latency(idx), 'omitnan');

        Talign = [Talign; {rat, ssj, x3(j), y}];
    end
end
%% ===== plot with legend (aligned -1/0/+1) =====
figure('Color','w'); hold on; box on;

x_vals = [-1 0 1];
mean_lat = nan(numel(x_vals),1);
sem_lat  = nan(numel(x_vals),1);

for i = 1:numel(x_vals)
    xi = x_vals(i);

    vals = Talign.latency(Talign.x_align == xi);

    mean_lat(i) = median(vals, 'omitnan');
    sem_lat(i)  = std(vals, 'omitnan') / sqrt(sum(~isnan(vals)));
end
% --- individual rats ---
for r = 1:numel(rat_list)
    rat = rat_list(r);
    Trr = Talign(Talign.rat==rat, :);
    if height(Trr) < 2, continue; end

    Trr = sortrows(Trr, 'x_align');
    plot(Trr.x_align, Trr.latency, '-o', ...
        'LineWidth', 1.2, ...
        'DisplayName', "LE" + rat);
end

% --- mean ± SEM ---
errorbar(x_vals, mean_lat, sem_lat, ...
    '-o', 'Color','k', 'LineWidth',3, ...
    'MarkerFaceColor','k', ...
    'DisplayName','Median ± SEM');

xlim([-1.2 1.2]);
xticks([-1 0 1]);
ylabel('latency (s)');
legend('Location','south');
