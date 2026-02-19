clc; clear; close all;

%% ===== Paths =====
ROOT.Info = 'D:\1. Behavioral data\info';
ROOT.Data = 'D:\1. Behavioral data\results\behavior\15-May-2024';
ROOT.Raw    = 'D:\1. Behavioral data';
today_is = datetime('today'); today_is.Format = 'yyyy-MM-dd';
today_is = char(today_is);

ROOT.Save = [ROOT.Raw '\results\theta_power_analysis\' today_is];
if ~exist(ROOT.Save,'dir'), mkdir(ROOT.Save); end

load(fullfile(ROOT.Info,'session_info.mat'));  % session_list

%% ===== Params =====
rat_id = "817";     % <- rat 지정
thr = 1.0;          % (m) threshold

%% ===== Get sessions =====
SL = session_list(string(session_list.rat) == rat_id, :);
ss_list = sort(double(SL.ss));

%% ===== Per-session compute =====
T = table('Size',[0 5], ...
    'VariableTypes',["string","double","double","double","double"], ...
    'VariableNames',["rat","ss","n_total","n_over1m","prop_over1m"]);

for k = 1:numel(ss_list)

    ss = ss_list(k);

    fname = sprintf('%s-%02d.mat', rat_id, ss);
    fpath = fullfile(ROOT.Data, fname);

    if ~exist(fpath,'file')
        warning('Missing file: %s', fname);
        continue;
    end

    S = load(fpath);
    if ~isfield(S,'ue_t')
        warning('No ue_t in: %s', fname);
        continue;
    end

    ue_t = S.ue_t;

    d = double(ue_t.travaled_distance);
    d = d(~isnan(d) & isfinite(d));

    n_total = numel(d);
    if n_total == 0
        warning('Empty distance data: %s', fname);
        continue;
    end

    n_over = sum(d > thr);
    prop   = n_over / n_total;

    T = [T; {rat_id, ss, n_total, n_over, prop}]; %#ok<AGROW>
end

T = sortrows(T, "ss");
disp(T);

%% ===== Plot =====
figure('Color','w','Position',[200 200 650 350]); hold on; box off;
plot(T.ss, T.prop_over1m, '-o', 'LineWidth', 1.5);

yline(0.5, '--', 'LineWidth', 1.2);
xlabel('Session (ss)');
ylabel('Proportion of trials w/ td > 1.0 m');
title(sprintf('LE %s', rat_id));
ylim([0 1]);

%% ===== Save =====
outdir = fullfile(ROOT.Data, "over1m_prop_analysis");
if ~exist(outdir,'dir'), mkdir(outdir); end

writetable(T, fullfile(outdir, sprintf('over1m_prop_rat_%s.csv', rat_id)));
save(fullfile(outdir, sprintf('over1m_prop_rat_%s.mat', rat_id)), 'T', 'thr');

disp("Saved to: " + outdir);
