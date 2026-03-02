clc; clear;

%% target
target = '816-04';

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

%% load CSV
csvFile = fullfile(ROOT.Info, ['LE' char(rat)], ['LE' char(rat) '_Post-main_' char(ssStr) '.csv']);
Data = readtable(csvFile);

timestamp = Data{:,3};   % timestamp
hd        = Data{:,7};   % head direction

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

    n = numel(idx);

    Ttmp = table;
    Ttmp.rat = repmat(rat, n, 1);
    Ttmp.ss  = repmat(ssStr, n, 1);
    Ttmp.trial = repmat(tr, n, 1);

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
                   'rose_head_direction');

if ~exist(saveDir,'dir'), mkdir(saveDir); end

%% ===== Rose parameter =====
edges = deg2rad(-180:10:180);   % 10 degree bin

%% ===== Unique trial list =====
trial_list = unique(Tout.trial);

for i = 1:length(trial_list)

    tr = trial_list(i);

    % 해당 trial의 head direction만 추출
    hd = Tout.head_direction(Tout.trial == tr);
    hd = hd(~isnan(hd));

    if isempty(hd), continue; end

    % [-180 180] wrap
    hd = mod(hd+180,360)-180;
    hd_rad = deg2rad(hd);

    % plot
    f = figure('visible','off');
    polarhistogram(hd_rad, edges, 'Normalization','probability');
    title(sprintf('%s Trial %d', target, tr));

    % save
    saveName = sprintf('%s_trial%03d.png', target, tr);
    exportgraphics(f, fullfile(saveDir, saveName), 'Resolution', 300);
    close(f);
end

fprintf("Rose plots saved in:\n%s\n", saveDir);