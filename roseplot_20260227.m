clc; clear; close all 

%% target
target = '816-05';

%% ROOT
ROOT.Mother = 'D:';
ROOT.Raw  = [ROOT.Mother '\1. Behavioral data'];
ROOT.Info = [ROOT.Raw '\info'];
ROOT.Data = [ROOT.Raw '\results\behavior\15-May-2024\'];

%% parse
tmp   = split(string(target), "-");
rat   = string(tmp(1));
ssNum = str2double(tmp(2));
ssStr = string(ssNum);

%% load ue_t
behFile = fullfile(ROOT.Data, sprintf('%s-%02d.mat', rat, ssNum));
load(behFile, 'ue_t','ue');

ts0 = ue_t.trial_start(:);
te0 = ue_t.rewardzone_arrival(:);
sd = ue_t.start_direction(:);

%% load CSV
csvFile = fullfile(ROOT.Info, ['LE' char(rat)], ['LE' char(rat) '_Post-main_' char(ssStr) '.csv']);
Data = readtable(csvFile);

timestamp = Data{:,3};   % timestamp
hd        = Data{:,7};   % head direction
ue_flag      = Data{:,27};

% timestamp가 datetime이면 숫자로 바꾸기(초 단위)
if isdatetime(timestamp)
    timestamp = posixtime(timestamp);
end
timestamp = double(timestamp(:));
hd        = double(hd(:));

N = height(Data);

%% decide: indices or timestamps?
isIndexLike = all(isfinite(ts0)) && all(isfinite(te0)) && ...
              all(mod(ts0,1)==0) && all(mod(te0,1)==0) && ...
              max([ts0;te0]) <= N;

Tout = table;
keep = 0;

for tr = 1:min(numel(ts0), numel(te0))

    a = ts0(tr); b = te0(tr);
    if ~isfinite(a) || ~isfinite(b), continue; end

    if isIndexLike
        rS = max(1, min(N, a));
        rE = max(1, min(N, b));
    else
        tS = a; tE = b;
        [~, rS] = min(abs(timestamp - tS));
        [~, rE] = min(abs(timestamp - tE));
    end

    if rE < rS, continue; end

    idx = rS:rE;
    idx = idx(~isnan(hd(idx)));
   
    if isempty(idx), continue; end

     % position data
        ue_position = Data{:,1:2};
        
        % 해당 trial의 navigation 구간 position
        x_temp = ue_position(idx,1);
        y_temp = ue_position(idx,2);
        
        if numel(x_temp) < 6
            continue;
        end
        
        % velocity 계산 (cm/s)
        dist_cm = sqrt(diff(x_temp).^2 + diff(y_temp).^2) * (0.6/9500) * 100;
        vel_temp = dist_cm * 30;   % 30Hz
        
        % 길이 맞추기
        vel_frame = [NaN; vel_temp];
        
        % 5 frame 연속 ≥5cm/s
        run_mask = false(size(vel_frame));
        
        for j = 1:numel(vel_frame)-4
            if all(vel_frame(j:j+4) >= 5)
                run_mask(j:j+4) = true;
            end
        end
        
        % running frame만 남기기
        idx = idx(run_mask);
        
        if isempty(idx)
            continue;
        end
    
        n = numel(idx);

    Ttmp = table;
    Ttmp.rat = repmat(rat, n, 1);
    Ttmp.ss  = repmat(ssStr, n, 1);
    Ttmp.trial = repmat(tr, n, 1);
  

    % ✅ 추가: start_direction (trial 단위 -> frame 단위로 복제)
    if tr <= numel(sd) && isfinite(sd(tr))
        Ttmp.start_direction = repmat(sd(tr), n, 1);
    else
        Ttmp.start_direction = repmat(NaN,   n, 1);
    end

    if isIndexLike
        Ttmp.trial_start = repmat(timestamp(rS), n, 1);
        Ttmp.rewardzone_arrival = repmat(timestamp(rE), n, 1);
    else
        Ttmp.trial_start = repmat(a, n, 1);
        Ttmp.rewardzone_arrival = repmat(b, n, 1);
    end

    Ttmp.head_direction = hd(idx);

    Tout = [Tout; Ttmp];
    keep = keep + 1;
end
fprintf("Trials in ue_t: %d | Trials kept: %d | Rows in Tout: %d\n", numel(ts0), keep, height(Tout));
%% ===== Save folder =====
saveDir = fullfile(ROOT.Raw, 'results', 'behavior', '15-May-2024', ...
                   'navigational strategy', ...
                   ['LE' char(rat)], ...
                   sprintf('%s-%02d', rat, ssNum), ...
                   'vector length');

if ~exist(saveDir,'dir'), mkdir(saveDir); end
save(fullfile(saveDir, 'Tout.mat'), 'Tout');

%% ===== Rose parameter =====
edges = deg2rad(-180:10:180);   % 10 degree bin

%% ===== Unique trial list =====
trial_list = unique(Tout.trial);
trial_list = sort(trial_list);

% 결과 저장용
Tvec = table;

for i = 1:numel(trial_list)

    tr = trial_list(i);

    % 해당 trial의 head direction만 추출
    hd_tr = Tout.head_direction(Tout.trial == tr);
    hd_tr = hd_tr(~isnan(hd_tr));
    if isempty(hd_tr), continue; end

    % wrap to [-180,180] for plotting

    hd_plot = mod(hd_tr+180,360)-180;
    alpha_plot = deg2rad(hd_plot);      % radians 전환

   
    alpha = deg2rad(mod(hd_tr,360));    % radians
    R  = circ_r(alpha);                 % vector length (0~1)

    % mean direction (circular mean)
    mu = atan2(mean(sin(alpha)), mean(cos(alpha)));

    % --- plot ---
    f = figure('visible','off','Color','w');
    polarhistogram(alpha_plot, edges, 'Normalization','probability');
    hold on;

    % 평균방향 벡터 (길이 = R)
    polarplot([mu mu], [0 R], 'r', 'LineWidth', 2);

    title(sprintf('%s Trial %d | R=%.2f', target, tr, R));

    % save
    saveName = sprintf('%s_trial_run%03d_R%.2f.png', target, tr, R);
    exportgraphics(f, fullfile(saveDir, saveName), 'Resolution', 300);
    close(f);

    % --- save stats row ---
    sd_tr = Tout.start_direction(find(Tout.trial==tr,1,'first'));  % trial의 start_direction
    Trow = table(string(rat), string(ssStr), tr, sd_tr, R, mod(rad2deg(mu),360), ...
        'VariableNames', {'rat','ss','trial','start_direction','R','mean_direction_deg'});
    Tvec = [Tvec; Trow];
end

% 저장
save(fullfile(saveDir, sprintf('%s_trial_vectorstats.mat', target)), 'Tvec');
writetable(Tvec, fullfile(saveDir, sprintf('%s_trial_vectorstats.csv', target)));

fprintf("Saved vector stats table + rose plots with R in:\n%s\n", saveDir);






% %% ===== Rose parameter =====
% edges = deg2rad(-180:10:180);   % 10 degree bin
% 
% %% ===== Unique trial list =====
% trial_list = unique(Tout.trial);
% 
% for i = 1:length(trial_list)
% 
%     tr = trial_list(i);
% 
%     % 해당 trial의 head direction만 추출
%     hd = Tout.head_direction(Tout.trial == tr);
%     hd = hd(~isnan(hd));
% 
%     if isempty(hd), continue; end
% 
%     % [-180 180] wrap
%     hd = mod(hd+180,360)-180;
%     hd_rad = deg2rad(hd);
% 
%     % plot
%     f = figure('visible','off');
%     polarhistogram(hd_rad, edges, 'Normalization','probability');
%     title(sprintf('%s Trial %d', target, tr));
% 
%     % save
%     saveName = sprintf('%s_trial_run%03d.png', target, tr);
%     exportgraphics(f, fullfile(saveDir, saveName), 'Resolution', 300);
%     close(f);
% end
% 
% fprintf("Rose plots saved in:\n%s\n", saveDir);