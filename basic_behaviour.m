clc; clear; close all;

%% paths
ROOT.Mother = 'D:';
ROOT.Raw  = [ROOT.Mother '\1. Behavioral data'];
ROOT.Info = [ROOT.Raw '\info'];
ROOT.Data = [ROOT.Raw '\results\behavior\15-May-2024\'];

%% load session list
load([ROOT.Info '\session_info.mat']);   % session_list 필요

rat = "779";
SL  = session_list(string(session_list.rat)==rat, :);

%% 결과 저장
ss_all = [];
lat_all = [];
corr_all = [];
ss_all   = [];
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
    latency = ue_t{:,9};
    avail   = ue_t{:,8};
    correct = ue_t{:,7};

    %lat_all(end+1,1) = median(latency(avail==1), 'omitnan');
    valid = (avail == 1);

    corr_all(end+1,1) = sum(correct(valid) == 1) / sum(valid) * 100;
    ss_all(end+1,1)  = ss_num;
end
%% sort by session
[ss_all, ord] = sort(ss_all);
% lat_all = lat_all(ord);

%% plot
figure('Color','w'); hold on; box on;
plot(ss_all, corr_all, '-o', 'LineWidth', 1.5, 'Color' ,"r");

xlabel('Session');
ylabel('correctness');
%title('LE779 session-wise latency');
