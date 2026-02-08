%%
clc;
clear;
close all;

%% Root setting

ROOT.Mother = 'D:';
ROOT.Raw = [ROOT.Mother '\1. Behavioral data'];
ROOT.Info = [ROOT.Raw '\info'];

ROOT.Data = [ROOT.Raw '\results\behavior\15-May-2024\'];  
ROOT.Theta = [ROOT.Mother '\2. Neural data\raw data\']

today_is = datetime('today');
today_is.Format = 'yyyy-MM-dd';
today_is = char(today_is);

ROOT.Save = [ROOT.Raw '\results\theta_power_analysis\' today_is];
if ~exist(ROOT.Save); mkdir(ROOT.Save); end


%% Load files

load(['D:\1. Behavioral data\results\theta_power_analysis\2026-01-31\\theta_power_session_table_PSD_withITI.mat']);
addpath(genpath(fullfile(ROOT.Mother, 'toolbox')));

%% z-score 
% --- make sure types are consistent
T_out.rat  = string(T_out.rat);
T_out.goal = string(T_out.goal);

rats = unique(T_out.rat);

% containers (ragged -> we will later bin by integer day)
All_iHP  = [];  % columns: [ratIdx, dayFromRev, z_iHP]
All_mPFC = [];  % columns: [ratIdx, dayFromRev, z_mPFC]

for r = 1:numel(rats)

    Tr = T_out(T_out.rat==rats(r), :);

    % sort by session number
    [~, ord] = sort(Tr.ss);
    Tr = Tr(ord,:);

    idxEast = find(Tr.goal=="East", 1, "first"); % define reversal point (Day 0)
    if isempty(idxEast)
        warning('Rat %s has no East sessions', rats(r)); 
        continue;
    end

    % reversal point 기준으로 세션 번호 저장
    ss0 = Tr.ss(idxEast);  
    day = Tr.ss - ss0;    

    % z-score within rat 
    % iHP
    x_i = Tr.theta_power_iHP;
    mu_i = mean(x_i, 'omitnan');
    sd_i = std(x_i,  'omitnan');
    z_i  = (x_i - mu_i) ./ sd_i;

    % mPFC
    x_m = Tr.theta_power_mPFC;
    mu_m = mean(x_m, 'omitnan');
    sd_m = std(x_m,  'omitnan');
    z_m  = (x_m - mu_m) ./ sd_m;

    All_iHP  = [All_iHP;  [repmat(r,size(day)), double(day), double(z_i)]];
    All_mPFC = [All_mPFC; [repmat(r,size(day)), double(day), double(z_m)]];
end

[days_i, mean_i, sem_i] = local_mean_sem_by_day(All_iHP);
[days_m, mean_m, sem_m] = local_mean_sem_by_day(All_mPFC);

%% plot
% 모든 day tick
xt_i = unique(All_iHP(:,2));  xt_i = sort(xt_i);
xt_m = unique(All_mPFC(:,2)); xt_m = sort(xt_m);

figure('Color','w','Position',[100 100 900 380]);

% iHP
subplot(1,2,1); hold on; box off;
%title('iHP theta (z-score)');
xlabel('Day from reversal');
ylabel('iHP theta power (z-score)');

for r = 1:numel(rats)
    Ai = All_iHP(All_iHP(:,1)==r & ~isnan(All_iHP(:,3)), :);
    if isempty(Ai), continue; end
    [~, ord] = sort(Ai(:,2));
    plot(Ai(ord,2), Ai(ord,3), 'k-', 'LineWidth', 1);
end

% --- 평균 ± SEM
fill([days_i; flipud(days_i)], ...
     [mean_i-sem_i; flipud(mean_i+sem_i)], ...
     [0.6 0.6 0.6], 'FaceAlpha',0.25, 'EdgeColor','none');

plot(days_i, mean_i, 'k-', 'LineWidth', 3);

xline(0,'k-','LineWidth',1);
set(gca,'XTick',xt_i);

% mPFC
subplot(1,2,2); hold on; box off;
%title();
xlabel('Day from reversal');
ylabel('mPFC theta power (z-score)');

for r = 1:numel(rats)
    Am = All_mPFC(All_mPFC(:,1)==r & ~isnan(All_mPFC(:,3)), :);
    if isempty(Am), continue; end
    [~, ord] = sort(Am(:,2));
    plot(Am(ord,2), Am(ord,3), 'k-', 'LineWidth', 1);
end

fill([days_m; flipud(days_m)], ...
     [mean_m-sem_m; flipud(mean_m+sem_m)], ...
     [0.6 0.6 0.6], 'FaceAlpha',0.25, 'EdgeColor','none');

plot(days_m, mean_m, 'k-', 'LineWidth', 3);

xline(0,'k-','LineWidth',1);
set(gca,'XTick',xt_m);
