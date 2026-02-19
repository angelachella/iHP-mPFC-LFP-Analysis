clc; clear; close all;

%% ===== Paths =====
ROOT.Info = 'D:\1. Behavioral data\info';
ROOT.Data = 'D:\1. Behavioral data\results\behavior\15-May-2024';
ROOT.Save = 'D:\1. Behavioral data\results\theta_power_analysis';

load(fullfile(ROOT.Info,'session_info.mat'));  % session_list

%% ===== Parameters (your plotting params) =====
Maze.Outline.x = 0;  Maze.Outline.y = 0;  Maze.Outline.r = 0.9500;

RewardZone.inner.r = 0.6500;
RewardZone.outer.r = 0.8000;

RewardZone.arch.x  = -0.7715; RewardZone.arch.y  =  0.1552;
RewardZone.house.x =  0.7715; RewardZone.house.y = -0.1552;

%% ===== Params =====
rat_id = "817";
Nbin  = 24;

% bin grid in -1..1 coordinates (matches ue.position_x/y)
edges = linspace(-1, 1, Nbin+1);
pos2bin = @(v) min(max(floor((v + 1) / (2/Nbin)) + 1, 1), Nbin);

%% ===== sessions =====
SL = session_list(string(session_list.rat) == rat_id, :);
ss_list = sort(double(SL.ss));

%% ===== output table =====
T = table('Size',[0 4], ...
    'VariableTypes', ["string","double","double","double"], ...
    'VariableNames', ["rat","ss","trial","n_spatial_bins"]);

%% ===== output folders =====
outdir_table = fullfile(ROOT.Data, "spatial_coverage_saved");
if ~exist(outdir_table,'dir'), mkdir(outdir_table); end

outdir_fig = fullfile(ROOT.Save, "bins_check_figs", "LE"+rat_id);
if ~exist(outdir_fig,'dir'), mkdir(outdir_fig); end

%% ===== loop sessions =====
for k = 1:numel(ss_list)

    ss = ss_list(k);
    target = sprintf('%s-%02d', rat_id, ss);
    behFile = fullfile(ROOT.Data, target + ".mat");

    if ~exist(behFile,'file')
        warning('Missing file: %s', behFile);
        continue;
    end

    S = load(behFile);   % expects ue, ue_t
    if ~isfield(S,'ue') || ~isfield(S,'ue_t')
        warning('Need ue & ue_t in: %s (skip)', behFile);
        continue;
    end

    ue   = S.ue;
    ue_t = S.ue_t;

    % perf
    if ismember("performance_available", string(ue_t.Properties.VariableNames))
        perf = double(ue_t.performance_available);
    else
        perf = double(ue_t{:,8});
    end

    trials = find(perf == 1);

    % session-specific figure folder
    outdir_fig_ss = fullfile(outdir_fig, target);
    if ~exist(outdir_fig_ss,'dir'), mkdir(outdir_fig_ss); end

    %% ===== loop trials =====
    for tt = 1:numel(trials)

        trial_to_check = trials(tt);

        % --- selected trial trajectory (used for BOTH bin calc and plotting) ---
        Xsel = ue.position_x(ue.trial == trial_to_check & ue.frame_ITI == 0 & ue.rewardzone_arrival == 0);
        Ysel = ue.position_y(ue.trial == trial_to_check & ue.frame_ITI == 0 & ue.rewardzone_arrival == 0);

        ok = isfinite(Xsel) & isfinite(Ysel);
        Xsel = double(Xsel(ok));
        Ysel = double(Ysel(ok));
        if isempty(Xsel)
            continue;
        end

        % --- bin count ---
        xb = pos2bin(Xsel);
        yb = pos2bin(Ysel);
        bin_id = (yb-1)*Nbin + xb;
        u = unique(bin_id);
        n_cov = numel(u);

        % save to table
        T = [T; {rat_id, ss, trial_to_check, n_cov}]; %#ok<AGROW>

        %% ===== make figure (same as your check figure) =====
        f = figure('Color','w','Position',[100,100,520,480]); hold on;

        % outline
        p_Outline = Draw_Circle(Maze.Outline.x, Maze.Outline.y, Maze.Outline.r, 4);
        p_Outline.LineWidth = 0.75;

        % grid
        for i = 1:numel(edges)
            plot([edges(i) edges(i)], [-1 1], 'k:', 'LineWidth', 0.5);
            plot([-1 1], [edges(i) edges(i)], 'k:', 'LineWidth', 0.5);
        end

        % reward rings
        p_arch = Draw_AngledCircle(0,0, RewardZone.inner.r,2); p_arch.LineWidth=1;
        p_arch = Draw_AngledCircle(0,0, RewardZone.outer.r,2); p_arch.LineWidth=1;
        p_house = Draw_AngledCircle2(0,0, RewardZone.inner.r,1); p_house.LineWidth=1;
        p_house = Draw_AngledCircle2(0,0, RewardZone.outer.r,1); p_house.LineWidth=1;

        % plot ALL trials (grey) first
        for i = 1:size(ue_t,1)
            if perf(i) ~= 1, continue; end
            X = ue.position_x(ue.trial == i & ue.frame_ITI == 0 & ue.rewardzone_arrival == 0);
            Y = ue.position_y(ue.trial == i & ue.frame_ITI == 0 & ue.rewardzone_arrival == 0);
            if isempty(X), continue; end
            plot(X, Y, 'Color', [0.85 0.85 0.85], 'LineWidth', 1);
        end

        % draw visited bins (red transparent)
        for b = u(:)'
            yy = floor((b-1)/Nbin) + 1;
            xx = mod((b-1), Nbin) + 1;
            x0 = edges(xx);   x1 = edges(xx+1);
            y0 = edges(yy);   y1 = edges(yy+1);
            patch([x0 x1 x1 x0], [y0 y0 y1 y1], 'r', 'FaceAlpha', 0.10, 'EdgeColor', 'none');
        end

        % selected trial ON TOP (thick black)
        plot(Xsel, Ysel, 'k', 'LineWidth', 2.5);
        plot(Xsel(end), Ysel(end), 'ro', 'MarkerSize', 8, 'LineWidth', 1.5);

        axis equal; axis off;
        title(sprintf('%s | trial %d (n=%d)', target, trial_to_check, n_cov), 'Interpreter','none');

        % save
        fname_base = sprintf('%s_trial%03d_binscheck', target, trial_to_check);
        exportgraphics(f, fullfile(outdir_fig_ss, fname_base + ".png"), 'Resolution', 300);
        close(f);

    end
end

%% ===== save table =====
T = sortrows(T, ["ss","trial"]);
writetable(T, fullfile(outdir_table, sprintf("T_spatialCoverage_%s.csv", rat_id)));
save(fullfile(outdir_table, sprintf("T_spatialCoverage_%s.mat", rat_id)), "T", "Nbin");

disp("Saved table to:");
disp(outdir_table);
disp("Saved figures to:");
disp(outdir_fig);

ss_to_plot = 11;

idx = T.ss == ss_to_plot;
data = T.n_spatial_bins(idx);

figure('Color','w');
histogram(data);
xlabel('Number of spatial bins visited');
ylabel('Trial count');
title(sprintf('Rat %s | Session %02d', rat_id, ss_to_plot));

%% stats 
T.rat = string(T.rat);
T = sortrows(T, {'rat','ss','trial'});

%% ===== per-session summary =====
rats = unique(T.rat);

S = table('Size',[0 13], ...
    'VariableTypes', ["string","double","double","double","double","double","double","double","double","double","double","double","double"], ...
    'VariableNames', ["rat","ss","nTrials","meanBins","medianBins","varBins","stdBins", ...
                      "p75Bins","p90Bins","p95Bins","iqrBins","tailRatio90_50","exploreIndex"]);

for r = 1:numel(rats)

    Tr = T(T.rat==rats(r), :);
    ss_list = unique(Tr.ss);

    for k = 1:numel(ss_list)

        ss = ss_list(k);
        x = double(Tr.n_spatial_bins(Tr.ss==ss));
        x = x(isfinite(x));

        if isempty(x), continue; end

        nTrials = numel(x);

        m  = mean(x);
        md = median(x);
        v  = var(x, 1);        % population variance (원하면 var(x,0) sample variance로)
        sd = std(x, 1);

        p75 = prctile(x, 75);
        
        p95 = prctile(x, 95);

        iqrVal = iqr(x);

        % tail ratio: 상위 10% (p90) / typical (median)  -> tail이 두꺼울수록 커짐
        p90 = prctile(x, 90);
        tailRatio = p90 / md;

        % ===== Composite exploration index =====
        % 구성 의도:
        %  - p90 (rare big-coverage trials) ↑
        %  - variance / iqr (전략 불안정성/다양성) ↑
        %  - median은 "보통 수행"이라 tail 대비 분리용
        %
        % 여기서는 각 항목을 rat 내에서 z-score로 표준화한 뒤 합산할 예정
        % (아래에서 rat별로 z를 다시 계산)

        % 일단 원자료로 저장해두고, exploreIndex는 나중에 채움
        S = [S; {rats(r), ss, nTrials, m, md, v, sd, p75, p90, p95, iqrVal, tailRatio, nan}]; %#ok<AGROW>
    end
end

%% ===== rat 내 z-score로 composite 만들기 =====
S = sortrows(S, {'rat','ss'});
S.exploreIndex = nan(height(S),1);

for r = 1:numel(rats)
    idx = S.rat == rats(r);

    % 각 rat 안에서 표준화 
    z_p90  = zscore(S.p90Bins(idx)); %90prctile
    z_var  = zscore(S.varBins(idx)); %variance
    z_tail = zscore(S.tailRatio90_50(idx)); %tail ratio

    % 가중치 (원하면 조절)
    w1 = 0.5;  % p90 강조
    w2 = 0.3;  % variance
    w3 = 0.2;  % tail ratio

    S.exploreIndex(idx) = w1*z_p90 + w2*z_var + w3*z_tail;
end

%% ===== output 확인 =====
disp(S);

%% ===== (optional) plot: session vs exploreIndex =====
figure('Color','w','Position',[200 200 650 300]); hold on; box off;
for r = 1:numel(rats)
    idx = S.rat==rats(r);
    plot(S.ss(idx), S.exploreIndex(idx), '-o', 'LineWidth', 1.5);
end
xlabel('Session (ss)');
ylabel('Exploration Index (z within rat)');
title('Exploration index across sessions');


