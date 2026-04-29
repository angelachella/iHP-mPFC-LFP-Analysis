% clear; clc; close all;
% tic
% 
% %% ROOT
% ROOT.mother = 'D:\2. Neural data';
% ROOT.data   = [ROOT.mother '\raw data'];
% 
% ROOT.behav  = 'D:\1. Behavioral data\results\behavior\15-May-2024';
% ROOT.bump   = 'D:\1. Behavioral data\results\innerCircle_first_bump_outward\2026-03-25';
% 
% today_is = char(datetime('today','Format','yyyy-MM-dd'));
% ROOT.save = [ROOT.mother '\results\3. LFP analysis\theta coherence coherencyc first bump freqwise\' today_is];
% 
% if ~exist(ROOT.save,'dir')
%     mkdir(ROOT.save);
% end
% 
% addpath(genpath('D:\code\theta_coherence'));
% addpath(genpath('D:\code\toolbox'));
% addpath(genpath('D:\toolbox'));
% 
% %% Load best TT info
% load([ROOT.mother '\Analysis\2.LFP_filtering_PSD\2.1.bestTT\2025-11-26\theta_TT.mat']);
% 
% %% Load T_path
% T_path = readtable(fullfile(ROOT.bump, 'T_path_frames_until_first_bump.csv'));
% 
% %% Parameters
% params.Fs = 2000;
% params.fpass = [3 13];
% params.tapers = [3 5];
% params.trialave = 0;
% params.pad = 0;
% 
% frame_dt = 0.033;
% target_freqs = 3:13;
% 
% failed_ss = {};
% T_all = table();
% 
% %% Session loop
% ss_list = fieldnames(theta_TT);
% 
% for ss_iter = 1:length(ss_list)
% 
%     ss_id = ss_list{ss_iter};
% 
%     fprintf('\n====================================\n');
%     fprintf('Running %s\n', ss_id);
% 
%     try
%         theta_info = theta_TT.(ss_id);
% 
%         T_out = run_cohgram_firstBump_wideband( ...
%             ROOT, ss_id, theta_info, T_path, params, frame_dt, target_freqs);
% 
%         T_all = [T_all; T_out];
% 
%         fprintf('%s completed\n', ss_id);
% 
%     catch ME
%         warning('%s failed: %s', ss_id, ME.message);
%         failed_ss = [failed_ss; {ss_id}];
%     end
% end
% 
% save(fullfile(ROOT.save, 'failed_ss.mat'), 'failed_ss');
% save(fullfile(ROOT.save, 'T_all_freqwise_coherencyc_firstBump.mat'), ...
%     'T_all', 'params', 'target_freqs');
% 
% writetable(T_all, fullfile(ROOT.save, 'T_all_freqwise_coherencyc_firstBump.csv'));
% 
% toc

%% coherence spectrum (3-13Hz)
clear; clc; close all;

%% Load final table
ROOT.save = 'D:\2. Neural data\results\3. LFP analysis\theta coherence coherencyc first bump freqwise\2026-04-28';

load(fullfile(ROOT.save, 'T_all_freqwise_coherencyc_firstBump.mat'), 'T_all');

%% Frequency columns
target_freqs = 3:13;
coh_vars = strcat("coh_", string(target_freqs), "Hz");

%% Session grouping
[G, rat_g, ss_g] = findgroups(T_all.rat, T_all.ss);

nSession = max(G);

T_session = table();

for g = 1:nSession

    idx = G == g;

    coh_mat = T_all{idx, coh_vars};

    mean_coh = mean(coh_mat, 1, 'omitnan');

    [max_coh, max_idx] = max(mean_coh);
    peak_freq = target_freqs(max_idx);

    newRow = table( ...
        rat_g(g), ss_g(g), peak_freq, max_coh, ...
        'VariableNames', {'rat','ss','peak_freq_Hz','peak_coherence'});

    meanRow = array2table(mean_coh, ...
        'VariableNames', cellstr(coh_vars));

    T_session = [T_session; [newRow meanRow]];

end

%% Save session summary
writetable(T_session, fullfile(ROOT.save, 'T_session_mean_freqwise_coherence.csv'));
save(fullfile(ROOT.save, 'T_session_mean_freqwise_coherence.mat'), 'T_session');

%% Rat-wise tiled session spectrum

rats = unique(T_session.rat);

fig_save = fullfile(ROOT.save, 'rat_level_tiled_sessions');
if ~exist(fig_save, 'dir')
    mkdir(fig_save);
end

for r = 1:length(rats)

    rat_id = rats(r);
    T_r = T_session(T_session.rat == rat_id, :);
    T_r = sortrows(T_r, 'ss');

    nSess = height(T_r);

    nCol = 3;
    nRow = ceil(nSess / nCol);

    figure('Color','w', 'Position', [100 100 1200 300*nRow]);

    tl = tiledlayout(nRow, nCol, ...
        'TileSpacing','compact', ...
        'Padding','compact');

    title(tl, sprintf('Rat %d - Session-wise frequency coherence', rat_id), ...
        'FontSize', 18, 'FontWeight','bold');

    for i = 1:nSess

        nexttile;

        ss = T_r.ss(i);
        mean_coh = T_r{i, coh_vars};

        [max_coh, max_idx] = max(mean_coh);
        peak_freq = target_freqs(max_idx);

        plot(target_freqs, mean_coh, '-o', ...
            'LineWidth', 1.8, ...
            'MarkerSize', 6);
        hold on;

        plot(peak_freq, max_coh, 'ro', ...
            'MarkerSize', 9, ...
            'LineWidth', 2);

        title(sprintf('ss%02d | peak = %d Hz', ss, peak_freq), ...
            'FontSize', 12);

        xlim([3 13]);
        ylim([0 1]);
        xticks(3:13);

        xlabel('Frequency (Hz)');
        ylabel('Mean coherence');

        grid on;
    end

    saveas(gcf, fullfile(fig_save, ...
        sprintf('rat%d_tiled_session_freqwise_coherence.png', rat_id)));
end

%% Heatmap: session x frequency

session_labels = strings(height(T_session),1);

for i = 1:height(T_session)
    session_labels(i) = sprintf('r%d-ss%02d', T_session.rat(i), T_session.ss(i));
end

coh_heat = T_session{:, coh_vars};

figure('Color','w');

imagesc(target_freqs, 1:height(T_session), coh_heat);
axis tight;

xlabel('Frequency (Hz)', 'FontSize', 16);
ylabel('Session', 'FontSize', 16);

yticks(1:height(T_session));
yticklabels(session_labels);

xticks(3:13);

cb = colorbar;
ylabel(cb, 'Mean coherence');

title('Session-wise frequency coherence', 'FontSize', 18);

colormap(jet);
caxis([0 1]);