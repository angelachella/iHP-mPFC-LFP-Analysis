%% idPhi/MVL vs theta power (rat x session z-score, per rat/session figures)
clc; clear; close all;

%% Root
ROOT.Mother = 'D:';
ROOT.Raw    = fullfile(ROOT.Mother,'1. Behavioral data');

today_is = datetime('today');
today_is.Format = 'yyyy-MM-dd';
today_is = char(today_is);

ROOT.Load = fullfile(ROOT.Raw,'results','innerCircle_first_bump_outward', '2026-03-25');
ROOT.Save = fullfile(ROOT.Load, ['idPhi_MVL_thetaScatterHeat_byRatSession_zScore_', today_is]);
if ~exist(ROOT.Save,'dir'), mkdir(ROOT.Save); end

%% Load data
load(fullfile(ROOT.Load, 'innerCircle_first_bump_results.mat'), 'T_bump', 'T_path');
load(fullfile(ROOT.Load, 'idPhi_MVL_beforeFirstBump','idPhi_MVL_beforeFirstBump.mat'), 'T_idPhiMVL');

theta_file = fullfile(ROOT.Raw,'results','theta_power_analysis','2026-04-03', ...
    'theta_power_beforeInnerBump_fromTbump.mat');

S = load(theta_file);
vars_in_file = fieldnames(S);

theta_table_name = '';
for i = 1:numel(vars_in_file)
    if istable(S.(vars_in_file{i}))
        theta_table_name = vars_in_file{i};
        break;
    end
end

if isempty(theta_table_name)
    error('No table variable found in theta file: %s', theta_file);
end

T_theta = S.(theta_table_name);
fprintf('[INFO] Loaded theta table: %s\n', theta_table_name);

%% Standardise variable names
T_idPhiMVL = standardise_key_vars(T_idPhiMVL);
T_theta    = standardise_key_vars(T_theta);

%% Find theta columns
ihp_col  = find_theta_col(T_theta, {'theta_iHP_mean','iHP_theta_mean','theta_iHP','iHP_theta','theta_mean_iHP'});
mpfc_col = find_theta_col(T_theta, {'theta_mPFC_mean','mPFC_theta_mean','theta_mPFC','mPFC_theta','theta_mean_mPFC'});

if isempty(ihp_col)
    error('Could not find iHP theta column in T_theta.');
end
if isempty(mpfc_col)
    error('Could not find mPFC theta column in T_theta.');
end

fprintf('[INFO] iHP theta column  : %s\n', ihp_col);
fprintf('[INFO] mPFC theta column : %s\n', mpfc_col);

%% Keep necessary columns
need_idphi = {'rat','ss','trial','goal','start_direction','idPhi','MVL'};
missing_idphi = setdiff(need_idphi, T_idPhiMVL.Properties.VariableNames);
if ~isempty(missing_idphi)
    error('T_idPhiMVL is missing required variables: %s', strjoin(missing_idphi, ', '));
end

need_theta = {'rat','ss','trial','goal','start_direction', ihp_col, mpfc_col};
missing_theta = setdiff(need_theta, T_theta.Properties.VariableNames);
if ~isempty(missing_theta)
    error('T_theta is missing required variables: %s', strjoin(missing_theta, ', '));
end

T_id = T_idPhiMVL(:, need_idphi);
T_th = T_theta(:, need_theta);

%% Type consistency
T_id.rat = string(T_id.rat);
T_th.rat = string(T_th.rat);

T_id.goal = string(T_id.goal);
T_th.goal = string(T_th.goal);

T_id.ss = double(T_id.ss);
T_th.ss = double(T_th.ss);

T_id.trial = double(T_id.trial);
T_th.trial = double(T_th.trial);

T_id.start_direction = double(T_id.start_direction);
T_th.start_direction = double(T_th.start_direction);

%% Merge
key_vars = {'rat','ss','trial','goal','start_direction'};
T = innerjoin(T_id, T_th, 'Keys', key_vars);

fprintf('[INFO] Merged trial count = %d\n', height(T));

%% Valid common rows
T = T(~isnan(T.idPhi) & ~isnan(T.MVL), :);

%% Trial type
goal = string(T.goal);
sd   = T.start_direction;

T.is_difficult = (strcmpi(goal,'West') & sd == 90)  | ...
                 (strcmpi(goal,'East') & sd == 270);

T.is_easy = (strcmpi(goal,'West') & sd == 270) | ...
            (strcmpi(goal,'East') & sd == 90);

%% Save raw theta
T.theta_iHP_raw  = T.(ihp_col);
T.theta_mPFC_raw = T.(mpfc_col);

%% -------------------------------------------------
% rat x session z-score
%% -------------------------------------------------
T.theta_iHP_zRatSession  = nan(height(T),1);
T.theta_mPFC_zRatSession = nan(height(T),1);

rat_list = unique(string(T.rat));

for ir = 1:numel(rat_list)
    rat_now = rat_list(ir);
    idx_r = string(T.rat) == rat_now;

    ss_list = unique(T.ss(idx_r));

    for is = 1:numel(ss_list)
        ss_now = ss_list(is);
        idx_rs = idx_r & (T.ss == ss_now);

        % iHP
        x = T.theta_iHP_raw(idx_rs);
        mu = mean(x, 'omitnan');
        sdv = std(x, 'omitnan');
        if ~isnan(sdv) && sdv > 0
            T.theta_iHP_zRatSession(idx_rs) = (x - mu) ./ sdv;
        end

        % mPFC
        y = T.theta_mPFC_raw(idx_rs);
        mu = mean(y, 'omitnan');
        sdv = std(y, 'omitnan');
        if ~isnan(sdv) && sdv > 0
            T.theta_mPFC_zRatSession(idx_rs) = (y - mu) ./ sdv;
        end
    end
end

%% Global axis edges for consistent comparison
all_idPhi = T.idPhi(~isnan(T.idPhi));
all_MVL   = T.MVL(~isnan(T.MVL));

nBin_x = 25;
nBin_y = 25;

x_edges = linspace(min(all_idPhi), max(all_idPhi), nBin_x+1);
y_edges = linspace(min(all_MVL),   max(all_MVL),   nBin_y+1);

%% Colour range for z-score
c_lim = [-2.5 2.5];

%% -------------------------------------------------
% Plot per rat, per session
%% -------------------------------------------------
for ir = 1:numel(rat_list)
    rat_now = rat_list(ir);
    idx_r = string(T.rat) == rat_now;

    ss_list = unique(T.ss(idx_r));

    rat_save_dir = fullfile(ROOT.Save, ['rat_' char(rat_now)]);
    if ~exist(rat_save_dir, 'dir'), mkdir(rat_save_dir); end

    for is = 1:numel(ss_list)
        ss_now = ss_list(is);
        idx_rs = idx_r & (T.ss == ss_now);

        T_rs = T(idx_rs, :);

        if isempty(T_rs)
            continue;
        end

        T_iHP_easy      = T_rs(T_rs.is_easy      & ~isnan(T_rs.theta_iHP_zRatSession), :);
        T_iHP_difficult = T_rs(T_rs.is_difficult & ~isnan(T_rs.theta_iHP_zRatSession), :);

        T_mPFC_easy      = T_rs(T_rs.is_easy      & ~isnan(T_rs.theta_mPFC_zRatSession), :);
        T_mPFC_difficult = T_rs(T_rs.is_difficult & ~isnan(T_rs.theta_mPFC_zRatSession), :);

        tag_rs = sprintf('%s-%02d', char(rat_now), ss_now);

       plot_scatter_only(T_iHP_easy, ...
            'idPhi', 'MVL', 'theta_iHP_zRatSession', x_edges, y_edges, c_lim, ...
            sprintf('iHP theta z-score (%s) - easy', tag_rs), ...
            rat_save_dir, sprintf('iHP_theta_easy_%s', tag_rs));
        
        plot_scatter_only(T_iHP_difficult, ...
            'idPhi', 'MVL', 'theta_iHP_zRatSession', x_edges, y_edges, c_lim, ...
            sprintf('iHP theta z-score (%s) - difficult', tag_rs), ...
            rat_save_dir, sprintf('iHP_theta_difficult_%s', tag_rs));
        
        plot_scatter_only(T_mPFC_easy, ...
            'idPhi', 'MVL', 'theta_mPFC_zRatSession', x_edges, y_edges, c_lim, ...
            sprintf('mPFC theta z-score (%s) - easy', tag_rs), ...
            rat_save_dir, sprintf('mPFC_theta_easy_%s', tag_rs));
        
        plot_scatter_only(T_mPFC_difficult, ...
            'idPhi', 'MVL', 'theta_mPFC_zRatSession', x_edges, y_edges, c_lim, ...
            sprintf('mPFC theta z-score (%s) - difficult', tag_rs), ...
            rat_save_dir, sprintf('mPFC_theta_difficult_%s', tag_rs));

        fprintf('[DONE] %s completed\n', tag_rs);
    end
end

fprintf('\nAll figures saved in:\n%s\n', ROOT.Save);

%% =========================================================
% Local functions
%% =========================================================

function T = standardise_key_vars(T)
    if ~ismember('rat', T.Properties.VariableNames)
        cand = intersect(T.Properties.VariableNames, {'Rat','RAT'});
        if ~isempty(cand)
            T.Properties.VariableNames{strcmp(T.Properties.VariableNames, cand{1})} = 'rat';
        end
    end

    if ~ismember('ss', T.Properties.VariableNames)
        cand = intersect(T.Properties.VariableNames, {'session','Session','SS'});
        if ~isempty(cand)
            T.Properties.VariableNames{strcmp(T.Properties.VariableNames, cand{1})} = 'ss';
        end
    end

    if ~ismember('trial', T.Properties.VariableNames)
        cand = intersect(T.Properties.VariableNames, {'Trial','trial_num','trialnumber','trial_number'});
        if ~isempty(cand)
            T.Properties.VariableNames{strcmp(T.Properties.VariableNames, cand{1})} = 'trial';
        end
    end

    if ~ismember('goal', T.Properties.VariableNames)
        cand = intersect(T.Properties.VariableNames, {'Goal','goal_location'});
        if ~isempty(cand)
            T.Properties.VariableNames{strcmp(T.Properties.VariableNames, cand{1})} = 'goal';
        end
    end

    if ~ismember('start_direction', T.Properties.VariableNames)
        cand = intersect(T.Properties.VariableNames, {'StartDirection','startDir','start_dir','sd'});
        if ~isempty(cand)
            T.Properties.VariableNames{strcmp(T.Properties.VariableNames, cand{1})} = 'start_direction';
        end
    end

    if ~ismember('MVL', T.Properties.VariableNames)
        cand = intersect(T.Properties.VariableNames, {'mvl','mean_vector_length'});
        if ~isempty(cand)
            T.Properties.VariableNames{strcmp(T.Properties.VariableNames, cand{1})} = 'MVL';
        end
    end

    if ~ismember('idPhi', T.Properties.VariableNames)
        cand = intersect(T.Properties.VariableNames, {'IdPhi','idphi'});
        if ~isempty(cand)
            T.Properties.VariableNames{strcmp(T.Properties.VariableNames, cand{1})} = 'idPhi';
        end
    end
end

function colname = find_theta_col(T, candidates)
    colname = '';
    vars = T.Properties.VariableNames;
    for i = 1:numel(candidates)
        if ismember(candidates{i}, vars)
            colname = candidates{i};
            return;
        end
    end
end

function plot_scatter_heat_oneRS(T, xvar, yvar, cvar, x_edges, y_edges, c_lim, fig_title, save_dir, save_name)

    if isempty(T)
        warning('[WARN] Empty table for %s', fig_title);
        return;
    end

    x = T.(xvar);
    y = T.(yvar);
    c = T.(cvar);

    f = figure('Color','w', 'Position',[100 100 1200 500]);

    % scatter
    subplot(1,2,1);
    scatter(x, y, 22, c, 'filled', ...
        'MarkerFaceAlpha', 0.55, ...
        'MarkerEdgeColor', 'none');

    xlabel('idPhi', 'FontSize', 12);
    ylabel('MVL', 'FontSize', 12);
    title([fig_title ' : scatter'], 'FontSize', 13, 'FontWeight', 'bold');
    set(gca, 'FontSize', 11, 'LineWidth', 1.2);
    xlim([x_edges(1), x_edges(end)]);
    ylim([y_edges(1), y_edges(end)]);
    caxis(c_lim);
    cb1 = colorbar;
    cb1.Label.String = strrep(cvar, '_', '\_');
    cb1.FontSize = 11;
    box off;

    % heat map
    subplot(1,2,2);

    [~,~,xb] = histcounts(x, x_edges);
    [~,~,yb] = histcounts(y, y_edges);

    Z = nan(numel(y_edges)-1, numel(x_edges)-1);

    for ix = 1:(numel(x_edges)-1)
        for iy = 1:(numel(y_edges)-1)
            idx = (xb == ix) & (yb == iy);
            if any(idx)
                Z(iy, ix) = median(c(idx), 'omitnan');
            end
        end
    end

    imagesc(x_edges, y_edges, [Z; nan(1,size(Z,2))]);
    set(gca, 'YDir', 'normal');

    xlabel('idPhi', 'FontSize', 12);
    ylabel('MVL', 'FontSize', 12);
    title([fig_title ' : heat map'], 'FontSize', 13, 'FontWeight', 'bold');
    set(gca, 'FontSize', 11, 'LineWidth', 1.2);
    xlim([x_edges(1), x_edges(end)]);
    ylim([y_edges(1), y_edges(end)]);
    caxis(c_lim);
    cb2 = colorbar;
    cb2.Label.String = ['Median ' strrep(cvar, '_', '\_')];
    cb2.FontSize = 11;
    box off;

    exportgraphics(f, fullfile(save_dir, [save_name '.png']), 'Resolution', 300);
    savefig(f, fullfile(save_dir, [save_name '.fig']));
    close(f);
end


function plot_scatter_only(T, xvar, yvar, cvar, x_edges, y_edges, c_lim, fig_title, save_dir, save_name)

    if isempty(T)
        warning('[WARN] Empty table for %s', fig_title);
        return;
    end

    x = T.(xvar);
    y = T.(yvar);
    c = T.(cvar);

    f = figure('Color','w', 'Position',[100 100 600 500]);

    scatter(x, y, 25, c, 'filled', ...
        'MarkerFaceAlpha', 0.6, ...
        'MarkerEdgeColor', 'none');

    xlabel('idPhi', 'FontSize', 12);
    ylabel('MVL',   'FontSize', 12);
    title(fig_title, 'FontSize', 13, 'FontWeight', 'bold');

    set(gca, 'FontSize', 11, 'LineWidth', 1.2);
    xlim([x_edges(1), x_edges(end)]);
    ylim([y_edges(1), y_edges(end)]);
    box off;

    % -----------------------------
    % Red-blue colormap (diverging)
    % -----------------------------
    colormap(redbluecmap);   % 아래에 정의 있음
    caxis(c_lim);

    cb = colorbar;
    cb.Label.String = strrep(cvar, '_', '\_');
    cb.FontSize = 11;

    % save
    exportgraphics(f, fullfile(save_dir, [save_name '.png']), 'Resolution', 300);
    savefig(f, fullfile(save_dir, [save_name '.fig']));
    close(f);
end

function cmap = redbluecmap()
    n = 256;
    r = [(0:n/2-1)/(n/2) ones(1,n/2)];
    g = [(0:n/2-1)/(n/2) (n/2-1:-1:0)/(n/2)];
    b = [ones(1,n/2) (n/2-1:-1:0)/(n/2)];
    cmap = [r(:) g(:) b(:)];
end