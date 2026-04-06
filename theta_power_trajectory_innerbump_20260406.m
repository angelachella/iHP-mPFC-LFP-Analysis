clc; clear; close all;

%% =========================================================
% Root
%% =========================================================
ROOT.Mother = 'D:';
ROOT.Raw    = fullfile(ROOT.Mother,'1. Behavioral data');
ROOT.Info   = fullfile(ROOT.Raw,'info');
ROOT.Data   = fullfile(ROOT.Raw,'results','behavior','15-May-2024');
ROOT.Theta  = fullfile(ROOT.Mother,'2. Neural data','raw data');

ROOT.BestTT = 'D:\2. Neural data\Analysis\2.LFP_filtering_PSD\2.1.bestTT\2025-11-26\theta_TT.mat';
ROOT.Load   = fullfile(ROOT.Raw,'results','innerCircle_first_bump_outward','2026-03-25');

today_is = datetime('today');
today_is.Format = 'yyyy-MM-dd';
today_is = char(today_is);

ROOT.Save = fullfile(ROOT.Load, ['trajectory_thetaHeatmap' today_is]);
if ~exist(ROOT.Save,'dir'), mkdir(ROOT.Save); end

%% =========================================================
% Load
%% =========================================================
load(fullfile(ROOT.Info,'session_info.mat')); %#ok<LOAD>
load(ROOT.BestTT, 'theta_TT');
load(fullfile(ROOT.Load, 'innerCircle_first_bump_results.mat'), 'T_bump', 'T_path');

addpath(genpath(fullfile(ROOT.Mother, 'toolbox')));

%% =========================================================
% User options
%% =========================================================
rat_sel = ["774"];   % 원하는 rat
ss_sel  = [];   % 예: [4 5 6], 비우면 전체

region_list = ["iHP","mPFC"];   % 출력할 region
thetaBand   = [6 12];
Fs          = 2000;

% smoothing
smooth_sec = 0.10;   % seconds
smooth_n   = max(1, round(Fs * smooth_sec));

% transform
use_log_power = true;
use_zscore    = true;

% colour scaling
clim_mode = 'trial';   % 'trial' or 'fixed'
fixed_clim = [-2 2];   % use only when clim_mode='fixed'

% save options
save_png = true;
save_fig = false;

%% =========================================================
% Maze / Reward zone
%% =========================================================
Maze.Outline.x = 0;
Maze.Outline.y = 0;
Maze.Outline.r = 0.9500;

InnerCircle.r = 0.6500;
OuterCircle.r = 0.8000;

RewardZone.inner.r = InnerCircle.r;
RewardZone.outer.r = OuterCircle.r;

%% =========================================================
% T_path cleanup
%% =========================================================
T_path.rat  = string(T_path.rat);
T_path.goal = string(T_path.goal);

idx_keep = ismember(T_path.rat, rat_sel);

if ~isempty(ss_sel)
    idx_keep = idx_keep & ismember(T_path.ss, ss_sel);
end

T_path = T_path(idx_keep, :);

if isempty(T_path)
    error('No rows left in T_path after rat/session filtering.');
end

%% =========================================================
% Unique trial list
%% =========================================================
trial_keys = unique(T_path(:, {'rat','ss','trial','goal','start_direction'}), 'rows');
trial_keys = sortrows(trial_keys, {'rat','ss','trial'});

%% =========================================================
% Session cache
%% =========================================================
current_rat = "";
current_ss  = nan;

cache = struct();
cache.cheetah_tick = [];
cache.iHP_power    = [];
cache.mPFC_power   = [];
cache.theta_ts     = [];

%% =========================================================
% Main loop
%% =========================================================
for iKey = 1:height(trial_keys)

    rat    = string(trial_keys.rat(iKey));
    ss_num = trial_keys.ss(iKey);
    tr_num = trial_keys.trial(iKey);
    goal   = string(trial_keys.goal(iKey));
    sd     = trial_keys.start_direction(iKey);

    fprintf('\n[%d/%d] rat=%s ss=%d trial=%d\n', ...
        iKey, height(trial_keys), rat, ss_num, tr_num);

    %% -----------------------------------------------------
    % Load session only when rat/session changes
    %% -----------------------------------------------------
    if rat ~= current_rat || ss_num ~= current_ss

        current_rat = rat;
        current_ss  = ss_num;

        cache.cheetah_tick = [];
        cache.iHP_power    = [];
        cache.mPFC_power   = [];
        cache.theta_ts     = [];

        ss_beh = sprintf('%02d', ss_num);
        ss_lfp = num2str(ss_num);

        %% behaviour
        behFile = fullfile(ROOT.Data, sprintf('%s-%s.mat', rat, ss_beh));
        if ~exist(behFile, 'file')
            fprintf('[WARN] behaviour file not found: %s\n', behFile);
            continue;
        end

        S = load(behFile, 'cheetah', 'ue', 'ue_t');
        if ~isfield(S,'cheetah')
            fprintf('[WARN] cheetah not found in %s\n', behFile);
            continue;
        end

        cache.cheetah_tick = double(S.cheetah.tick(:));

        %% best TT info
        theta_key = sprintf('r%s_%s', rat, ss_lfp);
        if ~isfield(theta_TT, theta_key)
            fprintf('[WARN] theta_TT key not found: %s\n', theta_key);
            continue;
        end
        theta_info = theta_TT.(theta_key);

        %% iHP file
        iHPfile = fullfile(ROOT.Theta, ['LE' char(rat)], ['rat' char(rat) '-' ss_lfp], ...
            ['AG' num2str(theta_info.bestTT_iHP) '_RateReduced_3-300filtered.ncs']);

        if exist(iHPfile, 'file')
            [cache.iHP_power, cache.theta_ts] = local_getThetaPowerTimeseries( ...
                iHPfile, Fs, thetaBand, smooth_n, use_log_power, use_zscore);
        else
            fprintf('[WARN] iHP file not found: %s\n', iHPfile);
        end

        %% mPFC file
        mPFCfile = fullfile(ROOT.Theta, ['LE' char(rat)], ['rat' char(rat) '-' ss_lfp], ...
            ['AG' num2str(theta_info.bestTT_mPFC) '_RateReduced_3-300filtered.ncs']);

        if exist(mPFCfile, 'file')
            [cache.mPFC_power, ts_check] = local_getThetaPowerTimeseries( ...
                mPFCfile, Fs, thetaBand, smooth_n, use_log_power, use_zscore);

            if isempty(cache.theta_ts)
                cache.theta_ts = ts_check;
            end
        else
            fprintf('[WARN] mPFC file not found: %s\n', mPFCfile);
        end

        if isempty(cache.cheetah_tick) || isempty(cache.theta_ts)
            fprintf('[WARN] session cache incomplete for rat=%s ss=%d\n', rat, ss_num);
            continue;
        end
    end

    %% -----------------------------------------------------
    % This trial from T_path
    %% -----------------------------------------------------
    idx_this = (T_path.rat == rat) & ...
               (T_path.ss == ss_num) & ...
               (T_path.trial == tr_num);

    Tp = T_path(idx_this, :);

    if isempty(Tp) || height(Tp) < 2
        fprintf('[WARN] too few rows in T_path for this trial\n');
        continue;
    end

    % sort by frame
    if ismember('frame_global', Tp.Properties.VariableNames)
        Tp = sortrows(Tp, 'frame_global');
        frame_idx = Tp.frame_global;
    elseif ismember('frame_within_trial', Tp.Properties.VariableNames)
        Tp = sortrows(Tp, 'frame_within_trial');
        frame_idx = Tp.frame_within_trial;
    else
        error('T_path must contain frame_global or frame_within_trial.');
    end

    x = Tp.x;
    y = Tp.y;

    idx_valid_xy = ~isnan(frame_idx) & ~isnan(x) & ~isnan(y);
    frame_idx = frame_idx(idx_valid_xy);
    x = x(idx_valid_xy);
    y = y(idx_valid_xy);

    if numel(x) < 2
        fprintf('[WARN] too few valid x/y points\n');
        continue;
    end

    frame_idx = double(frame_idx(:));
    x = double(x(:));
    y = double(y(:));

    if max(frame_idx) > numel(cache.cheetah_tick) || min(frame_idx) < 1
        fprintf('[WARN] frame index out of bounds for cheetah.tick\n');
        continue;
    end

    frame_tick = cache.cheetah_tick(frame_idx);

    %% -----------------------------------------------------
    % Interpolate theta power to behaviour frames
    %% -----------------------------------------------------
    theta_frame = struct();

    if ~isempty(cache.iHP_power)
        theta_frame.iHP = interp1(cache.theta_ts, cache.iHP_power, frame_tick, 'linear', nan);
    else
        theta_frame.iHP = nan(size(frame_tick));
    end

    if ~isempty(cache.mPFC_power)
        theta_frame.mPFC = interp1(cache.theta_ts, cache.mPFC_power, frame_tick, 'linear', nan);
    else
        theta_frame.mPFC = nan(size(frame_tick));
    end

    %% -----------------------------------------------------
    % Plot each region
    %% -----------------------------------------------------
    for iR = 1:numel(region_list)

        region = region_list(iR);
        c = theta_frame.(region);

        idx_valid_c = ~isnan(c) & ~isnan(x) & ~isnan(y);
        if sum(idx_valid_c) < 2
            fprintf('[WARN] too few valid theta samples for %s\n', region);
            continue;
        end

        xx = x(idx_valid_c);
        yy = y(idx_valid_c);
        cc = c(idx_valid_c);

        if numel(xx) < 2
            continue;
        end

        f = figure('Color','w','Position',[100 100 700 620]);
        hold on;

        %% =================================================
        % Maze outline
        %% =================================================
        p_Outline = Draw_Circle(Maze.Outline.x, Maze.Outline.y, Maze.Outline.r, 4);
        p_Outline.LineWidth = 0.75;
        p_Outline.Color = [0.2 0.2 0.2];

        %% Optional full outer circle
        th = linspace(0, 2*pi, 400);
        plot(InnerCircle.r*cos(th), InnerCircle.r*sin(th), '--', ...
            'Color', [0.35 0.6 0.35], 'LineWidth', 1);

        %% =================================================
        % Exact reward zone sectors
        % West = red
        % East = blue
        %% =================================================
        p_in = Draw_AngledCircle(0, 0, RewardZone.inner.r, 2);
        p_in.LineWidth = 1;
        p_in.LineStyle = '-';
        p_in.Color = [1 0 0];

        p_out = Draw_AngledCircle(0, 0, RewardZone.outer.r, 2);
        p_out.LineWidth = 1;
        p_out.LineStyle = '-';
        p_out.Color = [1 0 0];

        plot([p_in.XData(1)   p_out.XData(1)], ...
             [p_in.YData(1)   p_out.YData(1)], ...
             '-', 'Color', [1 0 0], 'LineWidth', 1);

        plot([p_in.XData(end) p_out.XData(end)], ...
             [p_in.YData(end) p_out.YData(end)], ...
             '-', 'Color', [1 0 0], 'LineWidth', 1);

        p_in2 = Draw_AngledCircle2(0, 0, RewardZone.inner.r, 1);
        p_in2.LineWidth = 1;
        p_in2.LineStyle = '-';
        p_in2.Color = [0 0 1];

        p_out2 = Draw_AngledCircle2(0, 0, RewardZone.outer.r, 1);
        p_out2.LineWidth = 1;
        p_out2.LineStyle = '-';
        p_out2.Color = [0 0 1];

        plot([p_in2.XData(1)   p_out2.XData(1)], ...
             [p_in2.YData(1)   p_out2.YData(1)], ...
             '-', 'Color', [0 0 1], 'LineWidth', 1);

        plot([p_in2.XData(end) p_out2.XData(end)], ...
             [p_in2.YData(end) p_out2.YData(end)], ...
             '-', 'Color', [0 0 1], 'LineWidth', 1);

        %% =================================================
        % Trajectory heatmap
        %% =================================================
        local_plotColourLine(xx, yy, cc, 4);

        %% Start / end
        plot(xx(1), yy(1), 'ko', ...
            'MarkerFaceColor', 'w', ...
            'MarkerSize', 7, ...
            'LineWidth', 1.2);

        %% Axis
        axis equal;
        xlim([-1 1]);
        ylim([-1 1]);

%        % min / max 계산
% cmin = min(cc, [], 'omitnan');
% cmax = max(cc, [], 'omitnan');

cmin = prctile(cc, 5);
cmax = prctile(cc, 95);
caxis([cmin cmax]);


% colorbar
cb = colorbar;

% label
if use_zscore
    cb.Label.String = sprintf('%s theta power (z)', region);
elseif use_log_power
    cb.Label.String = sprintf('%s log_{10}(theta power)', region);
else
    cb.Label.String = sprintf('%s theta power', region);
end

% 👉 핵심: tick을 min/max로 고정
cb.Ticks = linspace(cmin, cmax, 5);
cb.TickLabels = arrayfun(@(x) sprintf('%.2f', x), cb.Ticks, 'UniformOutput', false);

cb.FontSize = 11;
cb.Label.FontSize = 12;

        xlabel('x', 'FontSize', 12);
        ylabel('y', 'FontSize', 12);
        title(sprintf('Rat %s | ss %02d | trial %d | %s | start %d | %s', ...
            rat, ss_num, tr_num, goal, sd, region), ...
            'FontSize', 13, 'FontWeight', 'bold');

        set(gca, 'FontSize', 11, 'LineWidth', 1.2, 'Box', 'off');
        colormap(turbo);
        hold off;

        %% save
        save_name = sprintf('trajTheta_%s_ss%02d_trial%03d_%s', ...
            char(rat), ss_num, tr_num, char(region));
        save_name = regexprep(save_name, '[^\w]', '_');

        if save_png
            saveas(f, fullfile(ROOT.Save, [save_name '.png']));
        end
        if save_fig
            saveas(f, fullfile(ROOT.Save, [save_name '.fig']));
        end

        close(f);
    end
end

disp('Done.');
disp(['Saved to: ' ROOT.Save]);

%% =========================================================
% Local function: theta power time series
%% =========================================================
function [theta_power, ts] = local_getThetaPowerTimeseries(ncsFile, Fs, thetaBand, smooth_n, use_log_power, use_zscore)

    FieldSelectionFlags = [1 1 1 1 1];
    HeaderExtractionFlag = 1;
    ExtractionMode = 1;
    ExtractionModeVector = [];

    [CSC.Timestamps, CSC.ChannelNumbers, CSC.SampleFrequencies, ...
     CSC.NumberOfValidSamples, CSC.eeg, CSC.Header] = ...
        Nlx2MatCSC(ncsFile, FieldSelectionFlags, HeaderExtractionFlag, ExtractionMode, ExtractionModeVector);

    ADBitVolts = str2double(CSC.Header{15,1}(13:end));
    CSC.eeg = CSC.eeg .* ADBitVolts;

    [lfp, ts] = expandCSC(CSC);

    lfp = double(lfp(:));
    ts  = double(ts(:));

    % theta bandpass
    x_theta = bandpass(lfp, thetaBand, Fs);

    % Hilbert amplitude -> power
    theta_amp   = abs(hilbert(x_theta));
    theta_power = theta_amp .^ 2;

    % smoothing
    if smooth_n > 1
        theta_power = movmean(theta_power, smooth_n, 'omitnan');
    end

    % log transform
    if use_log_power
        theta_power = log10(theta_power + eps);
    end

    % z-score within session
    if use_zscore
        mu = mean(theta_power, 'omitnan');
        sd = std(theta_power, 'omitnan');

        if isfinite(sd) && sd > 0
            theta_power = (theta_power - mu) ./ sd;
        end
    end
end

%% =========================================================
% Local function: coloured trajectory line
%% =========================================================
function local_plotColourLine(x, y, c, lineWidth)

    surface([x(:) x(:)], [y(:) y(:)], zeros(numel(x),2), [c(:) c(:)], ...
        'FaceColor', 'none', ...
        'EdgeColor', 'interp', ...
        'LineWidth', lineWidth);
end