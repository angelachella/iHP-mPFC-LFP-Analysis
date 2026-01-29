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

load(['D:\1. Behavioral data\results\theta_power_analysis\2026-01-28\\theta_power_session_table_PSD_withITI.mat']);
addpath(genpath(fullfile(ROOT.Mother, 'toolbox')));

%%  bar graph pre vs. post (all rats)
T_out.rat   = string(T_out.rat);
T_out.goal  = string(T_out.goal);
T_out.stage = string(T_out.stage);

rats = unique(T_out.rat);
goals = ["West","East"];

for g = 1:numel(goals)

    goal_g = goals(g);

   % save pre/post
    pre  = nan(numel(rats),1);
    post = nan(numel(rats),1);

    for r = 1:numel(rats)

        Tr = T_out(T_out.rat==rats(r) & T_out.goal==goal_g, :);

        pre_v  = Tr.theta_power_iHP(Tr.stage=="Pre");
        post_v = Tr.theta_power_iHP(Tr.stage=="Post");

        if ~isempty(pre_v) && ~isempty(post_v)
            pre(r)  = mean(pre_v,'omitnan');
            post(r) = mean(post_v,'omitnan');
        end
    end

    %p = signrank(pre, post); % Wilcoxon signed-rank test
    [~, p, ci, stats] = ttest(pre, post); % paired t-test

% plot
    figure('Color','w','Position',[100 100 400 400]); hold on; box off;

    m = [mean(pre) mean(post)];
    sem = [std(pre)/sqrt(numel(pre)), std(post)/sqrt(numel(post))];

    bar([1 2], m, 0.6, 'FaceColor',[0.85 0.85 0.85]);
    errorbar([1 2], m, sem, 'k', 'LineStyle','none','LineWidth',1);

    % paired dots
    for i = 1:numel(pre)
        plot([1 2], [pre(i) post(i)], '-', 'Color',[0.5 0.5 0.5]);
        scatter([1 2], [pre(i) post(i)], 40, 'k', 'filled');
    end

    set(gca,'XTick',[1 2],'XTickLabel',{'Pre','Post'});
    ylabel('iHP theta power');
    title(sprintf('%s | iHP theta (Pre vs Post)\np = %.3g (n = %d)', ...
                  goal_g, p, numel(pre)));
end


%% z-score (baseline: ITI) & paired t-test
T_out.rat   = string(T_out.rat);
T_out.goal  = string(T_out.goal);
T_out.stage = string(T_out.stage);

rats  = unique(T_out.rat);
goals = ["West","East"];

for g = 1:numel(goals)

    goal_g = goals(g);

    pre  = nan(numel(rats),1);
    post = nan(numel(rats),1);

    for r = 1:numel(rats)

        % 해당 rat & goal 세션들
        Tr = T_out(T_out.rat==rats(r) & T_out.goal==goal_g, :);

        all_trial = Tr.theta_power_iHP;
        all_trial = all_trial(~isnan(all_trial));

        if numel(all_trial) < 2
            continue
        end

        muAll = mean(all_trial,'omitnan');
        sdAll = std(all_trial,'omitnan');

        % 세션별 z-score
        z_sess = (Tr.theta_power_iHP - muAll) ./ sdAll;

        % stage별 rat 평균
        pre_v  = z_sess(Tr.stage=="Pre");
        post_v = z_sess(Tr.stage=="Post");

        if ~isempty(pre_v) && ~isempty(post_v)
            pre(r)  = mean(pre_v,'omitnan');
            post(r) = mean(post_v,'omitnan');
        end
    end

    % paired 가능한 rat만
    keep = ~isnan(pre) & ~isnan(post);
    preK  = pre(keep);
    postK = post(keep);

    % paired test
    %p = signrank(preK, postK);
    [~, p, ci, stats] = ttest(pre, post); % paired t-test

    % plot
    figure('Color','w','Position',[100 100 420 420]); hold on; box off;

    m   = [mean(preK,'omitnan')  mean(postK,'omitnan')];
    sem = [std(preK,'omitnan')/sqrt(numel(preK))  std(postK,'omitnan')/sqrt(numel(postK))];

    bar([1 2], m, 0.6, 'FaceColor',[0.85 0.85 0.85], 'EdgeColor','none');
    errorbar([1 2], m, sem, 'k', 'LineStyle','none','LineWidth',1);

    % paired dots + lines
    for i = 1:numel(preK)
        plot([1 2], [preK(i) postK(i)], '-', 'Color',[0.5 0.5 0.5]);
        scatter([1 2], [preK(i) postK(i)], 40, 'k', 'filled');
    end

    yline(0,'-','Color',[0.7 0.7 0.7]);  % z=0 기준선

    set(gca,'XTick',[1 2],'XTickLabel',{'Pre','Post'});
    ylabel('iHP theta');
    title(sprintf('%s | p=%.3g, n=%d', goal_g, p, numel(preK)));

    fprintf('\n[%s] n=%d, p=%.4g, mean(Post-Pre)=%.3f\n', ...
        goal_g, numel(preK), p, mean(postK-preK,'omitnan'));
end



%% === ITI-corrected theta change: (Trial - ITI), Pre vs Post ===

T_out.rat   = string(T_out.rat);
T_out.goal  = string(T_out.goal);
T_out.stage = string(T_out.stage);

rats  = unique(T_out.rat);
goals = ["West","East"];

for g = 1:numel(goals)

    goal_g = goals(g);

    pre  = nan(numel(rats),1);
    post = nan(numel(rats),1);

    for r = 1:numel(rats)

        Tr = T_out(T_out.rat==rats(r) & T_out.goal==goal_g, :);

        % ITI-corrected session values
        dTheta = Tr.theta_power_iHP - Tr.theta_power_iHP_ITI;

        % stage별 rat 평균
        pre_v  = dTheta(Tr.stage=="Pre");
        post_v = dTheta(Tr.stage=="Post");

        if ~isempty(pre_v) && ~isempty(post_v)
            pre(r)  = mean(pre_v,'omitnan');
            post(r) = mean(post_v,'omitnan');
        end
    end

    % paired 가능한 rat만
    keep = ~isnan(pre) & ~isnan(post);
    preK  = pre(keep);
    postK = post(keep);

    % paired t-test
    [~, p, ci, stats] = ttest(preK, postK);
    

    % plot
    figure('Color','w','Position',[100 100 420 420]); hold on; box off;

    m   = [mean(preK,'omitnan')  mean(postK,'omitnan')];
    sem = [std(preK,'omitnan')/sqrt(numel(preK))  std(postK,'omitnan')/sqrt(numel(postK))];

    bar([1 2], m, 0.6, 'FaceColor',[0.85 0.85 0.85], 'EdgeColor','none');
    errorbar([1 2], m, sem, 'k', 'LineStyle','none','LineWidth',1);

    for i = 1:numel(preK)
        plot([1 2], [preK(i) postK(i)], '-', 'Color',[0.5 0.5 0.5]);
        scatter([1 2], [preK(i) postK(i)], 40, 'k', 'filled');
    end

    yline(0,'-','Color',[0.7 0.7 0.7]);

    set(gca,'XTick',[1 2],'XTickLabel',{'Pre','Post'});
    ylabel('\Delta iHP theta (Trial - ITI)');
    title(sprintf('%s | p=%.3g, n=%d', goal_g, p, numel(preK)));
end



%% line graph (all rats in a single figure)
T_out.rat   = string(T_out.rat);
T_out.goal  = string(T_out.goal);
T_out.stage = string(T_out.stage);

rats  = unique(T_out.rat);
goals = ["West","East"];

for g = 1:numel(goals)

    goal_g = goals(g);

    figure('Color','w','Position',[100 100 420 420]); hold on; box off;
    cmap = lines(numel(rats));

    h = gobjects(0);          % line handles (그려진 것만)
    leg = strings(0);         % legend labels (그려진 것만)

    for r = 1:numel(rats)

        Tr = T_out(T_out.rat==rats(r) & T_out.goal==goal_g, :);

        pre  = mean(Tr.theta_power_iHP(Tr.stage=="Pre"),  'omitnan');
        post = mean(Tr.theta_power_iHP(Tr.stage=="Post"), 'omitnan');

        if ~isnan(pre) && ~isnan(post)
            h(end+1,1) = plot([1 2], [pre post], '-o', ...
                'Color', cmap(r,:), ...
                'LineWidth', 2, ...
                'MarkerFaceColor', cmap(r,:));
            leg(end+1,1) = rats(r);
        end
    end

    xlim([0.8 2.2]);
    set(gca,'XTick',[1 2],'XTickLabel',{'Pre','Post'});
    ylabel('iHP theta power');
    title(sprintf('%s | iHP theta', goal_g));

    legend(h, leg, 'Location','bestoutside');   % ✅ 정확히 매칭

end