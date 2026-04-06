% clc; clear; close all;
% 
% %% ===== Root setting =====
% ROOT.Mother = 'D:';
% ROOT.Raw    = fullfile(ROOT.Mother,'1. Behavioral data');
% ROOT.Info   = fullfile(ROOT.Raw,'info');
% ROOT.Data   = fullfile(ROOT.Raw,'results','behavior','15-May-2024');   % behaviour mat
% ROOT.Theta  = fullfile(ROOT.Mother,'2. Neural data','raw data');       % LFP .ncs raw data
% 
% today_is = datetime('today');
% today_is.Format = 'yyyy-MM-dd';
% today_is = char(today_is);
% 
% ROOT.Save = fullfile(ROOT.Raw,'results','theta_power_analysis', today_is);
% if ~exist(ROOT.Save,'dir'), mkdir(ROOT.Save); end
% 
% %% ===== Additional load path =====
% ROOT.BestTT = 'D:\2. Neural data\Analysis\2.LFP_filtering_PSD\2.1.bestTT\2025-11-26\theta_TT.mat';
% 
% % first bump 결과 저장 위치
% ROOT.Bump = fullfile(ROOT.Raw,'results','innerCircle_first_bump_outward','2026-03-25');
% 
% % optional tables
% ROOT.IdPhiMVL = fullfile(ROOT.Bump,'idPhi_MVL_beforeFirstBump','idPhi_MVL_beforeFirstBump.mat');
% ROOT.Latency  = fullfile(ROOT.Bump,'latency_speed_beforeInnerBump','2026-03-28', ...
%                          'latency_speed_beforeInnerBump_table.mat');
% 
% %% ===== Load files =====
% load(fullfile(ROOT.Info,'session_info.mat'));   % session_list
% load(ROOT.BestTT, 'theta_TT');
% load(fullfile(ROOT.Bump,'innerCircle_first_bump_results.mat'), 'T_bump', 'T_path');
% 
% if exist(ROOT.IdPhiMVL,'file')
%     load(ROOT.IdPhiMVL, 'T_idPhiMVL');
% else
%     T_idPhiMVL = table();
% end
% 
% if exist(ROOT.Latency,'file')
%     load(ROOT.Latency, 'T_out');
% else
%     T_out = table();
% end
% 
% addpath(genpath(fullfile(ROOT.Mother, 'toolbox')));   % circ_r 포함
% 
% %% ===== Parameters =====
% params.Fs = 2000;
% thetaBand = [6 12];
% 
% % Welch
% win = round(1 * params.Fs);    % 1 s
% if mod(win,2)==1
%     win = win + 1;
% end
% noverlap = round(0.5 * win);
% nfft = max(2^nextpow2(win), win);
% 
% %% ===== ue / ue_t column settings =====
% col_x = 6;   % ue position_x
% col_y = 7;   % ue position_y
% 
% % start_direction column in ue_t
% % 네 데이터에서 다르면 여기만 수정
% col_start_direction = 6;
% 
% %% ===== Use exact T_bump variable names =====
% Tb = T_bump(:, {'rat','ss','trial','goal','start_direction','hit_x','hit_y'});
% Tb = unique(Tb, 'rows');
% 
% %% ===== Output table =====
% T_theta = table( ...
%     strings(0,1), ...   % rat
%     nan(0,1), ...       % ss
%     nan(0,1), ...       % trial
%     strings(0,1), ...   % goal
%     nan(0,1), ...       % start_direction
%     nan(0,1), ...       % hit_x
%     nan(0,1), ...       % hit_y
%     nan(0,1), ...       % theta_iHP
%     nan(0,1), ...       % theta_mPFC
%     'VariableNames', ...
%     {'rat','ss','trial','goal','start_direction','hit_x','hit_y','theta_iHP','theta_mPFC'});
% 
% %% ===== Main loop =====
% nRow = height(Tb);
% 
% for i = 1:nRow
% 
%     rat    = string(Tb.rat(i));
%     ss_num = Tb.ss(i);
%     iTrial = Tb.trial(i);
%     goal   = string(Tb.goal(i));
%     sd_tb  = Tb.start_direction(i);
%     hit_x  = Tb.hit_x(i);
%     hit_y  = Tb.hit_y(i);
% 
%     fprintf('\n[%d/%d] rat=%s ss=%d trial=%d\n', i, nRow, rat, ss_num, iTrial);
% 
%     %% ----- session string formatting -----
%     ss_beh = sprintf('%02d', ss_num);   % behaviour file: 04
%     ss_lfp = num2str(ss_num);           % LFP folder key: 4
% 
%     %% ----- behaviour file path -----
%     behFile = fullfile(ROOT.Data, sprintf('%s-%s.mat', rat, ss_beh));
%     if ~exist(behFile, 'file')
%         fprintf('[WARN] behaviour file not found: %s\n', behFile);
%         continue;
%     end
% 
%     %% ----- load behaviour -----
%     S = load(behFile, 'cheetah', 'ue', 'ue_t');
%     if ~isfield(S,'cheetah') || ~isfield(S,'ue') || ~isfield(S,'ue_t')
%         fprintf('[WARN] Missing cheetah / ue / ue_t in %s\n', behFile);
%         continue;
%     end
% 
%     cheetah = S.cheetah;
%     ue      = S.ue;
%     ue_t    = S.ue_t;
%     tick_timestamp = cheetah.tick;
% 
%     if iTrial > size(ue_t,1)
%         fprintf('[WARN] trial index exceeds ue_t rows\n');
%         continue;
%     end
% 
%     trial_start_idx = ue_t{iTrial,1};
%     trial_end_idx   = ue_t{iTrial,3};   % rewardzone_arrival
% 
%     if isnan(trial_start_idx) || isnan(trial_end_idx) || trial_end_idx <= trial_start_idx
%         fprintf('[WARN] invalid trial start/end\n');
%         continue;
%     end
% 
%     if trial_start_idx < 1 || trial_end_idx > height(ue) || trial_end_idx > numel(tick_timestamp)
%         fprintf('[WARN] trial indices out of bounds\n');
%         continue;
%     end
% 
%     %% ----- locate bump frame using T_bump hit_x, hit_y -----
%     x_trial = ue{trial_start_idx:trial_end_idx, col_x};
%     y_trial = ue{trial_start_idx:trial_end_idx, col_y};
% 
%     if isempty(x_trial) || isempty(y_trial) || all(isnan(x_trial)) || all(isnan(y_trial))
%         fprintf('[WARN] empty or nan trajectory\n');
%         continue;
%     end
% 
%     dist2hit = hypot(x_trial - hit_x, y_trial - hit_y);
%     [minDist, bump_rel_idx] = min(dist2hit);
% 
%     if isempty(bump_rel_idx) || isnan(minDist)
%         fprintf('[WARN] failed to locate hit frame\n');
%         continue;
%     end
% 
%     bump_abs_idx = trial_start_idx + bump_rel_idx - 1;
% 
%     if bump_abs_idx <= trial_start_idx
%         fprintf('[WARN] bump index <= start index\n');
%         continue;
%     end
% 
%     tStart = tick_timestamp(trial_start_idx);
%     tBump  = tick_timestamp(bump_abs_idx); % T_bump RZ inner circle first bump frame
% 
%     if tBump <= tStart
%         fprintf('[WARN] tBump <= tStart\n');
%         continue;
%     end
% 
%     trial_time = [tStart tBump]; % theta power 계산 범위 [trial start - inner circle first bump]
% 
%     %% load TT
%     theta_key = sprintf('r%s_%s', rat, ss_lfp);
%     if ~isfield(theta_TT, theta_key)
%         fprintf('[WARN] theta_TT key not found: %s\n', theta_key);
%         continue;
%     end
%     theta_info = theta_TT.(theta_key);
% 
%    % load ncs file 
%     iHPfile = fullfile(ROOT.Theta, ['LE' char(rat)], ['rat' char(rat) '-' ss_lfp], ...
%         ['AG' num2str(theta_info.bestTT_iHP) '_RateReduced_3-300filtered.ncs']);
% 
%     mPFCfile = fullfile(ROOT.Theta, ['LE' char(rat)], ['rat' char(rat) '-' ss_lfp], ...
%         ['AG' num2str(theta_info.bestTT_mPFC) '_RateReduced_3-300filtered.ncs']);
% 
%     %% ----- theta power -----
%     theta_iHP  = nan;
%     theta_mPFC = nan;
% 
%     if exist(iHPfile, 'file')
%         theta_iHP = local_trialThetaPSD(iHPfile, trial_time, params.Fs, thetaBand, win, noverlap, nfft);
%     else
%         fprintf('[WARN] iHP file not found: %s\n', iHPfile);
%     end
% 
%     if exist(mPFCfile, 'file')
%         theta_mPFC = local_trialThetaPSD(mPFCfile, trial_time, params.Fs, thetaBand, win, noverlap, nfft);
%     else
%         fprintf('[WARN] mPFC file not found: %s\n', mPFCfile);
%     end
% 
%     %% ----- start direction -----
%     if size(ue_t,2) >= col_start_direction
%         sd_ue = ue_t{iTrial, col_start_direction};
%     else
%         sd_ue = sd_tb;
%     end
% 
%     %% ----- append row -----
%     newRow = { ...
%         rat, ...
%         ss_num, ...
%         iTrial, ...
%         goal, ...
%         sd_ue, ...
%         hit_x, ...
%         hit_y, ...
%         theta_iHP, ...
%         theta_mPFC};
% 
%     T_theta = [T_theta; newRow]; %#ok<AGROW>
% 
% end
% 
% %% ===== Save =====
% save(fullfile(ROOT.Save, 'theta_power_beforeInnerBump_fromTbump.mat'), 'T_theta');
% writetable(T_theta, fullfile(ROOT.Save, 'theta_power_beforeInnerBump_fromTbump.csv'));
% 
% fprintf('\nSaved results to:\n%s\n', ROOT.Save);
% 
% %% ========================================================================
% %% Local function
% %% ========================================================================
% function thetaP_trial = local_trialThetaPSD(ncsFile, trial_time, Fs, thetaBand, win, noverlap, nfft)
% 
%     FieldSelectionFlags = [1 1 1 1 1];
%     HeaderExtractionFlag = 1;
%     ExtractionMode = 1;
%     ExtractionModeVector = [];
% 
%     [CSC.Timestamps, CSC.ChannelNumbers, CSC.SampleFrequencies, ...
%      CSC.NumberOfValidSamples, CSC.eeg, CSC.Header] = ...
%         Nlx2MatCSC(ncsFile, FieldSelectionFlags, HeaderExtractionFlag, ExtractionMode, ExtractionModeVector);
% 
%     ADBitVolts = str2double(CSC.Header{15,1}(13:end));
%     CSC.eeg = CSC.eeg .* ADBitVolts;
% 
%     [lfp, ts] = expandCSC(CSC); %ts = 전체 LFP timestamp 
% 
%     % timestamp 자르기 [tStart - tBump]
%     [~, s] = min(abs(ts - trial_time(1)));
%     [~, e] = min(abs(ts - trial_time(2)));
% 
%     thetaP_trial = nan;
% 
%     if e <= s
%         return;
%     end
% 
%     % LFP 자르기 
%     x = double(lfp(s:e)); 
% 
%     x = x - mean(x, 'omitnan');
% 
%     if all(isnan(x)) || numel(x) < win
%         return;
%     end
% 
%     [Pxx, f] = pwelch(x, win, noverlap, nfft, Fs);
%     thetaP_trial = bandpower(Pxx, f, thetaBand, 'psd');
% end




% %% Visualization
% clc; clear; close all;
% 
% %% =========================================================
% % Paths
% % =========================================================
% ROOT.Save = 'D:\1. Behavioral data\results\theta_power_analysis\2026-04-03';
% 
% if ~exist(ROOT.Save, 'dir')
%     mkdir(ROOT.Save);
% end
% 
% %% =========================================================
% % Load data
% % =========================================================
% S = load(fullfile(ROOT.Save, 'theta_power_beforeInnerBump_fromTbump.mat'));
% 
% if ~isfield(S, 'T_theta')
%     error('T_theta was not found in theta_power_beforeInnerBump_fromTbump.mat');
% end
% 
% T_theta = S.T_theta;
% 
% %% =========================================================
% % Basic cleanup
% % =========================================================
% % Convert to consistent types
% T_theta.rat  = string(T_theta.rat);
% T_theta.goal = string(T_theta.goal);
% 
% % Remove rows with missing essential values
% idx_valid = ~ismissing(T_theta.rat) & ...
%             ~ismissing(T_theta.goal) & ...
%             ~isnan(T_theta.ss) & ...
%             ~isnan(T_theta.start_direction) & ...
%             ~isnan(T_theta.theta_iHP) & ...
%             ~isnan(T_theta.theta_mPFC);
% 
% T_theta = T_theta(idx_valid, :);
% 
% %% =========================================================
% % 1) Classify difficulty
% % difficult = West + North(90), East + South(270)
% % easy      = West + South(270), East + North(90)
% % =========================================================
% is_difficult = (strcmpi(T_theta.goal, "West") & T_theta.start_direction == 90) | ...
%                (strcmpi(T_theta.goal, "East") & T_theta.start_direction == 270);
% 
% is_easy = (strcmpi(T_theta.goal, "West") & T_theta.start_direction == 270) | ...
%           (strcmpi(T_theta.goal, "East") & T_theta.start_direction == 90);
% 
% difficulty = strings(height(T_theta), 1);
% difficulty(is_difficult) = "difficult";
% difficulty(is_easy)      = "easy";
% 
% T_theta.difficulty = difficulty;
% 
% % Keep only rows that fall into either easy or difficult
% T_theta = T_theta(T_theta.difficulty == "easy" | T_theta.difficulty == "difficult", :);
% 
% %% =========================================================
% % 2) Session-level mean theta power by rat x session x condition
% % Also keep session goal (should be unique within session)
% % =========================================================
% [G, rat_g, ss_g, diff_g] = findgroups(T_theta.rat, T_theta.ss, T_theta.difficulty);
% 
% mean_iHP   = splitapply(@mean, T_theta.theta_iHP,   G);
% mean_mPFC  = splitapply(@mean, T_theta.theta_mPFC,  G);
% n_trials   = splitapply(@numel, T_theta.theta_iHP,  G);
% 
% % session goal within each rat x session x difficulty group
% goal_g = splitapply(@(x) string(x(1)), T_theta.goal, G);
% 
% T_session = table(rat_g, ss_g, goal_g, diff_g, mean_iHP, mean_mPFC, n_trials, ...
%     'VariableNames', {'rat','ss','goal','difficulty','theta_iHP_mean','theta_mPFC_mean','n_trials'});
% 
% %% =========================================================
% % 3) Align sessions by first East goal day = Day 0
% % Important:
% % We align by ORDER of sessions, not by raw session number difference.
% % So the first East session is 0, the previous session is -1, next is +1, etc.
% % =========================================================
% T_session.day_from_reversal = nan(height(T_session), 1);
% 
% rat_list = unique(T_session.rat);
% 
% for iR = 1:numel(rat_list)
%     this_rat = rat_list(iR);
% 
%     idx_rat = T_session.rat == this_rat;
%     T_rat   = T_session(idx_rat, :);
% 
%     % session-level unique goal per session
%     [Gss, ss_unique] = findgroups(T_rat.ss);
%     goal_per_ss = splitapply(@(x) string(x(1)), T_rat.goal, Gss);
% 
%     T_ss = table(ss_unique, goal_per_ss, 'VariableNames', {'ss','goal'});
%     T_ss = sortrows(T_ss, 'ss');
% 
%     east_idx = find(strcmpi(T_ss.goal, "East"), 1, 'first');
% 
%     if isempty(east_idx)
%         warning('Rat %s has no East goal session. day_from_reversal left as NaN.', this_rat);
%         continue;
%     end
% 
%     % Ordered day index relative to first East session
%     % e.g. ... -2, -1, 0, +1, +2 ...
%     T_ss.day_from_reversal = (1:height(T_ss))' - east_idx;
% 
%     % assign back
%     for k = 1:height(T_ss)
%         idx_fill = idx_rat & (T_session.ss == T_ss.ss(k));
%         T_session.day_from_reversal(idx_fill) = T_ss.day_from_reversal(k);
%     end
% end
% 
% %% =========================================================
% % Save summary tables
% % =========================================================
% save(fullfile(ROOT.Save, 'theta_power_sessionSummary_easyDifficult.mat'), ...
%     'T_theta', 'T_session');
% 
% writetable(T_session, fullfile(ROOT.Save, 'theta_power_sessionSummary_easyDifficult.csv'));
% 
% %% =========================================================
% % Plot settings
% % =========================================================
% % x-axis range across all aligned sessions
% x_all = T_session.day_from_reversal(~isnan(T_session.day_from_reversal));
% xmin = min(x_all);
% xmax = max(x_all);
% 
% % Colours
% grey_line   = [0.75 0.75 0.75];
% mean_line   = [0 0 0];
% west_patch  = [0.96 0.78 0.74];
% east_patch  = [0.78 0.85 0.98];
% 
% %% =========================================================
% % 4 figures:
% %   1) iHP easy
% %   2) iHP difficult
% %   3) mPFC easy
% %   4) mPFC difficult
% % =========================================================
% % plot_theta_by_condition(T_session, "theta_iHP_mean",  "easy",      ...
% %     "iHP theta power (easy)", ROOT.Save, xmin, xmax, grey_line, mean_line, west_patch, east_patch);
% % 
% % plot_theta_by_condition(T_session, "theta_iHP_mean",  "difficult", ...
% %     "iHP theta power (difficult)", ROOT.Save, xmin, xmax, grey_line, mean_line, west_patch, east_patch);
% % 
% % plot_theta_by_condition(T_session, "theta_mPFC_mean", "easy",      ...
% %     "mPFC theta power (easy)", ROOT.Save, xmin, xmax, grey_line, mean_line, west_patch, east_patch);
% % 
% % plot_theta_by_condition(T_session, "theta_mPFC_mean", "difficult", ...
% %     "mPFC theta power (difficult)", ROOT.Save, xmin, xmax, grey_line, mean_line, west_patch, east_patch);
% 
% %% =========================================================
% % Per-rat figures
% % =========================================================
% rat_list = unique(T_session.rat);
% 
% for iR = 1:numel(rat_list)
%     rat_now = rat_list(iR);
% 
%     plot_theta_by_condition_perRat(T_session, rat_now, "theta_iHP_mean", "easy", ...
%         "iHP theta power (easy)", ROOT.Save, xmin, xmax, west_patch, east_patch);
% 
%     plot_theta_by_condition_perRat(T_session, rat_now, "theta_iHP_mean", "difficult", ...
%         "iHP theta power (difficult)", ROOT.Save, xmin, xmax, west_patch, east_patch);
% 
%     plot_theta_by_condition_perRat(T_session, rat_now, "theta_mPFC_mean", "easy", ...
%         "mPFC theta power (easy)", ROOT.Save, xmin, xmax, west_patch, east_patch);
% 
%     plot_theta_by_condition_perRat(T_session, rat_now, "theta_mPFC_mean", "difficult", ...
%         "mPFC theta power (difficult)", ROOT.Save, xmin, xmax, west_patch, east_patch);
% end
% 
% 
% 
% 
% disp('Done.');
% disp(['Saved to: ' ROOT.Save]);
% 
% % %% =========================================================
% % % Local function (without colour-coding for rats)
% % % =========================================================
% % function plot_theta_by_condition(T_session, value_var, difficulty_name, fig_title_str, ...
% %     save_dir, xmin, xmax, grey_line, mean_line, west_patch, east_patch)
% % 
% %     T_plot = T_session(T_session.difficulty == difficulty_name & ~isnan(T_session.day_from_reversal), :);
% % 
% %     if isempty(T_plot)
% %         warning('No data found for %s - %s', value_var, difficulty_name);
% %         return;
% %     end
% % 
% %     rat_list = unique(T_plot.rat);
% % 
% %     f = figure('Color', 'w', 'Position', [100 100 780 520]);
% %     hold on;
% % 
% %     % y-limits from data
% %     y = T_plot.(value_var);
% %     y_min = min(y);
% %     y_max = max(y);
% % 
% %     if y_min == y_max
% %         y_min = y_min * 0.9;
% %         y_max = y_max * 1.1;
% %     else
% %         pad = 0.08 * (y_max - y_min);
% %         y_min = y_min - pad;
% %         y_max = y_max + pad;
% %     end
% % 
% %     % Background shading
% %     patch([xmin-0.5, -0.5, -0.5, xmin-0.5], [y_min, y_min, y_max, y_max], ...
% %         west_patch, 'EdgeColor', 'none', 'FaceAlpha', 0.5);
% % 
% %     patch([-0.5, xmax+0.5, xmax+0.5, -0.5], [y_min, y_min, y_max, y_max], ...
% %         east_patch, 'EdgeColor', 'none', 'FaceAlpha', 0.5);
% % 
% %     % Individual rats
% %     for iR = 1:numel(rat_list)
% %         this_rat = rat_list(iR);
% %         idx_rat = T_plot.rat == this_rat;
% % 
% %         T_rat = sortrows(T_plot(idx_rat, :), 'day_from_reversal');
% %         x = T_rat.day_from_reversal;
% %         y = T_rat.(value_var);
% % 
% %         plot(x, y, '-o', ...
% %             'Color', grey_line, ...
% %             'LineWidth', 1.5, ...
% %             'MarkerSize', 5, ...
% %             'MarkerFaceColor', grey_line, ...
% %             'MarkerEdgeColor', grey_line);
% %     end
% % 
% %     % Grand mean across rats at each aligned day
% %     [Gday, day_u] = findgroups(T_plot.day_from_reversal);
% %     mean_day = splitapply(@mean, T_plot.(value_var), Gday);
% % 
% %     [day_u, sort_idx] = sort(day_u);
% %     mean_day = mean_day(sort_idx);
% % 
% %     plot(day_u, mean_day, '-o', ...
% %         'Color', mean_line, ...
% %         'LineWidth', 2.5, ...
% %         'MarkerSize', 6, ...
% %         'MarkerFaceColor', mean_line, ...
% %         'MarkerEdgeColor', mean_line);
% % 
% %     xline(0, 'k-', 'LineWidth', 1.2);
% % 
% %     % Labels for West / East
% %     text(mean([xmin -0.5]), y_max - 0.03*(y_max-y_min), 'West', ...
% %         'HorizontalAlignment', 'center', 'FontSize', 12, 'FontWeight', 'bold');
% %     text(mean([-0.5 xmax]), y_max - 0.03*(y_max-y_min), 'East', ...
% %         'HorizontalAlignment', 'center', 'FontSize', 12, 'FontWeight', 'bold');
% % 
% %     xlabel('Day from reversal', 'FontSize', 12);
% %     ylabel(strrep(value_var, '_', '\_'), 'FontSize', 12);
% %     title(fig_title_str, 'FontSize', 14, 'FontWeight', 'bold');
% % 
% %     xlim([xmin-0.5 xmax+0.5]);
% %     ylim([y_min y_max]);
% %     xticks(xmin:xmax);
% % 
% %     set(gca, 'Box', 'off', 'LineWidth', 1.2, 'FontSize', 11);
% %     hold off;
% % 
% %    % =========================
% % % Safe filename 만들기 (중요)
% % % =========================
% % save_name = char(fig_title_str);
% % 
% % % 위험 문자 제거
% % invalidChars = {'\', '/', ':', '*', '?', '"', '<', '>', '|'};
% % for i = 1:numel(invalidChars)
% %     save_name = strrep(save_name, invalidChars{i}, '');
% % end
% % 
% % % 공백 → underscore
% % save_name = strrep(save_name, ' ', '_');
% % 
% % % 추가로 혹시 남아있을 이상한 문자 제거
% % save_name = regexprep(save_name, '[^a-zA-Z0-9_]', '');
% % 
% % % 너무 길면 자르기 (optional)
% % if length(save_name) > 100
% %     save_name = save_name(1:100);
% % end
% % 
% %     saveas(f, fullfile(save_dir, [save_name '.png']));
% % 
% % end
% 
% %% With colour-coding for rats
% function plot_theta_by_condition_perRat(T_session, rat_name, value_var, difficulty_name, ...
%     fig_title_str, save_dir, xmin, xmax, west_patch, east_patch)
% 
%     T_plot = T_session(T_session.rat == rat_name & ...
%                        T_session.difficulty == difficulty_name & ...
%                        ~isnan(T_session.day_from_reversal), :);
% 
%     if isempty(T_plot)
%         warning('No data found for rat %s | %s | %s', rat_name, value_var, difficulty_name);
%         return;
%     end
% 
%     T_plot = sortrows(T_plot, 'day_from_reversal');
% 
%     x = T_plot.day_from_reversal;
%     y = T_plot.(value_var);
% 
%     f = figure('Color', 'w', 'Position', [100 100 780 520]);
%     hold on;
% 
%     % y-limit
%     y_min = min(y);
%     y_max = max(y);
% 
%     if y_min == y_max
%         y_min = y_min * 0.9;
%         y_max = y_max * 1.1;
%     else
%         pad = 0.08 * (y_max - y_min);
%         y_min = y_min - pad;
%         y_max = y_max + pad;
%     end
% 
%     % West / East background
%     patch([xmin-0.5, -0.5, -0.5, xmin-0.5], [y_min, y_min, y_max, y_max], ...
%         west_patch, 'EdgeColor', 'none', 'FaceAlpha', 0.5);
% 
%     patch([-0.5, xmax+0.5, xmax+0.5, -0.5], [y_min, y_min, y_max, y_max], ...
%         east_patch, 'EdgeColor', 'none', 'FaceAlpha', 0.5);
% 
%     % line
%     plot(x, y, '-o', ...
%         'Color', [0 0 0], ...
%         'LineWidth', 2, ...
%         'MarkerSize', 6, ...
%         'MarkerFaceColor', [0 0 0], ...
%         'MarkerEdgeColor', [0 0 0]);
% 
%     xline(0, 'k-', 'LineWidth', 1.2);
% 
%     % West / East label
%     text(mean([xmin -0.5]), y_max - 0.03*(y_max-y_min), 'West', ...
%         'HorizontalAlignment', 'center', 'FontSize', 12, 'FontWeight', 'bold');
%     text(mean([-0.5 xmax]), y_max - 0.03*(y_max-y_min), 'East', ...
%         'HorizontalAlignment', 'center', 'FontSize', 12, 'FontWeight', 'bold');
% 
%     xlabel('Day from reversal', 'FontSize', 12);
%     ylabel(strrep(value_var, '_', '\_'), 'FontSize', 12);
%     title(sprintf('%s | Rat %s', fig_title_str, rat_name), 'FontSize', 14, 'FontWeight', 'bold');
% 
%     xlim([xmin-0.5 xmax+0.5]);
%     ylim([y_min y_max]);
%     xticks(xmin:xmax);
% 
%     set(gca, 'Box', 'off', 'LineWidth', 1.2, 'FontSize', 11);
%     hold off;
% 
%     % safe filename
%     save_name = sprintf('%s_rat_%s_%s', value_var, rat_name, difficulty_name);
%     save_name = char(save_name);
%     save_name = regexprep(save_name, '[^\w]', '_');
% 
%     saveas(f, fullfile(save_dir, [save_name '.png']));
%     saveas(f, fullfile(save_dir, [save_name '.fig']));
% end



clc; clear; close all;

%% =========================================================
% Paths
% =========================================================
ROOT.Save = 'D:\1. Behavioral data\results\theta_power_analysis\2026-04-03';

if ~exist(ROOT.Save, 'dir')
    mkdir(ROOT.Save);
end

%% =========================================================
% Load data
% =========================================================
S = load(fullfile(ROOT.Save, 'theta_power_beforeInnerBump_fromTbump.mat'));

if ~isfield(S, 'T_theta')
    error('T_theta was not found in theta_power_beforeInnerBump_fromTbump.mat');
end

T_theta = S.T_theta;

%% =========================================================
% Basic cleanup
% =========================================================
T_theta.rat  = string(T_theta.rat);
T_theta.goal = string(T_theta.goal);

idx_valid = ~ismissing(T_theta.rat) & ...
            ~ismissing(T_theta.goal) & ...
            ~isnan(T_theta.ss) & ...
            ~isnan(T_theta.start_direction) & ...
            ~isnan(T_theta.theta_iHP) & ...
            ~isnan(T_theta.theta_mPFC);

T_theta = T_theta(idx_valid, :);

%% =========================================================
% 1) Difficulty classification
% difficult = West + 90, East + 270
% easy      = West + 270, East + 90
% =========================================================
is_difficult = (strcmpi(T_theta.goal, "West") & T_theta.start_direction == 90) | ...
               (strcmpi(T_theta.goal, "East") & T_theta.start_direction == 270);

is_easy = (strcmpi(T_theta.goal, "West") & T_theta.start_direction == 270) | ...
          (strcmpi(T_theta.goal, "East") & T_theta.start_direction == 90);

difficulty = strings(height(T_theta),1);
difficulty(is_difficult) = "difficult";
difficulty(is_easy)      = "easy";

T_theta.difficulty = difficulty;
T_theta = T_theta(T_theta.difficulty=="easy" | T_theta.difficulty=="difficult", :);

%% =========================================================
% 2) rat x session x difficulty mean theta power
% =========================================================
[G, rat_g, ss_g, diff_g] = findgroups(T_theta.rat, T_theta.ss, T_theta.difficulty);

mean_iHP  = splitapply(@mean, T_theta.theta_iHP,  G);
mean_mPFC = splitapply(@mean, T_theta.theta_mPFC, G);
n_trials  = splitapply(@numel, T_theta.theta_iHP, G);
goal_g    = splitapply(@(x) string(x(1)), T_theta.goal, G);

T_session = table(rat_g, ss_g, goal_g, diff_g, mean_iHP, mean_mPFC, n_trials, ...
    'VariableNames', {'rat','ss','goal','difficulty','theta_iHP_mean','theta_mPFC_mean','n_trials'});

%% =========================================================
% 3) Align by first East goal session = Day 0
% ordered-session alignment, not raw session-number subtraction
% =========================================================
T_session.day_from_reversal = nan(height(T_session),1);

rat_list = unique(T_session.rat);

for iR = 1:numel(rat_list)
    this_rat = rat_list(iR);

    idx_rat = T_session.rat == this_rat;
    T_rat   = T_session(idx_rat, :);

    [Gss, ss_unique] = findgroups(T_rat.ss);
    goal_per_ss = splitapply(@(x) string(x(1)), T_rat.goal, Gss);

    T_ss = table(ss_unique, goal_per_ss, 'VariableNames', {'ss','goal'});
    T_ss = sortrows(T_ss, 'ss');

    east_idx = find(strcmpi(T_ss.goal, "East"), 1, 'first');

    if isempty(east_idx)
        warning('Rat %s has no East goal session. day_from_reversal left as NaN.', this_rat);
        continue;
    end

    T_ss.day_from_reversal = (1:height(T_ss))' - east_idx;

    for k = 1:height(T_ss)
        idx_fill = idx_rat & (T_session.ss == T_ss.ss(k));
        T_session.day_from_reversal(idx_fill) = T_ss.day_from_reversal(k);
    end
end

%% =========================================================
% Save summary table
% =========================================================
save(fullfile(ROOT.Save, 'theta_power_sessionSummary_easyDifficult.mat'), ...
    'T_theta', 'T_session');

writetable(T_session, fullfile(ROOT.Save, 'theta_power_sessionSummary_easyDifficult.csv'));

%% =========================================================
% Plot ranges / colours
% =========================================================
x_all = T_session.day_from_reversal(~isnan(T_session.day_from_reversal));
xmin = min(x_all);
xmax = max(x_all);

west_patch = [0.96 0.78 0.74];
east_patch = [0.78 0.85 0.98];
mean_line  = [0 0 0];

%% rat colours
rat_list = unique(T_session.rat);
rat_colors = lines(numel(rat_list));

%% =========================================================
% 4 figures only
% each rat = different colour
% grand mean = black
% =========================================================
plot_theta_by_condition_colouredRats(T_session, rat_list, rat_colors, ...
    "theta_iHP_mean", "easy", ...
    "iHP theta power (easy)", ...
    "theta_iHP_easy", ...
    ROOT.Save, xmin, xmax, west_patch, east_patch, mean_line);

plot_theta_by_condition_colouredRats(T_session, rat_list, rat_colors, ...
    "theta_iHP_mean", "difficult", ...
    "iHP theta power (difficult)", ...
    "theta_iHP_difficult", ...
    ROOT.Save, xmin, xmax, west_patch, east_patch, mean_line);

plot_theta_by_condition_colouredRats(T_session, rat_list, rat_colors, ...
    "theta_mPFC_mean", "easy", ...
    "mPFC theta power (easy)", ...
    "theta_mPFC_easy", ...
    ROOT.Save, xmin, xmax, west_patch, east_patch, mean_line);

plot_theta_by_condition_colouredRats(T_session, rat_list, rat_colors, ...
    "theta_mPFC_mean", "difficult", ...
    "mPFC theta power (difficult)", ...
    "theta_mPFC_difficult", ...
    ROOT.Save, xmin, xmax, west_patch, east_patch, mean_line);

disp('Done.');
disp(['Saved to: ' ROOT.Save]);

%% =========================================================
% Local function
% =========================================================
function plot_theta_by_condition_colouredRats(T_session, rat_list, rat_colors, ...
    value_var, difficulty_name, fig_title_str, save_name, save_dir, ...
    xmin, xmax, west_patch, east_patch, mean_line)

    T_plot = T_session(T_session.difficulty == difficulty_name & ...
                       ~isnan(T_session.day_from_reversal), :);

    if isempty(T_plot)
        warning('No data found for %s - %s', value_var, difficulty_name);
        return;
    end

    f = figure('Color','w','Position',[100 100 820 540]);
    hold on;

    % y-limits from all data in this figure
    y_all = T_plot.(value_var);
    y_min = min(y_all);
    y_max = max(y_all);

    if y_min == y_max
        y_min = y_min * 0.9;
        y_max = y_max * 1.1;
    else
        pad = 0.08 * (y_max - y_min);
        y_min = y_min - pad;
        y_max = y_max + pad;
    end

    % background patches
    patch([xmin-0.5, -0.5, -0.5, xmin-0.5], [y_min, y_min, y_max, y_max], ...
        west_patch, 'EdgeColor','none', 'FaceAlpha',0.5);

    patch([-0.5, xmax+0.5, xmax+0.5, -0.5], [y_min, y_min, y_max, y_max], ...
        east_patch, 'EdgeColor','none', 'FaceAlpha',0.5);

    % plot each rat with different colour
    legend_handles = gobjects(numel(rat_list),1);
    legend_labels  = strings(numel(rat_list),1);

    for iR = 1:numel(rat_list)
        this_rat = rat_list(iR);

        idx_rat = T_plot.rat == this_rat;
        T_rat = T_plot(idx_rat, :);

        if isempty(T_rat)
            continue;
        end

        T_rat = sortrows(T_rat, 'day_from_reversal');
        x = T_rat.day_from_reversal;
        y = T_rat.(value_var);

        h = plot(x, y, '-o', ...
            'Color', rat_colors(iR,:), ...
            'LineWidth', 1.8, ...
            'MarkerSize', 6, ...
            'MarkerFaceColor', rat_colors(iR,:), ...
            'MarkerEdgeColor', rat_colors(iR,:));

        legend_handles(iR) = h;
        legend_labels(iR)  = "Rat " + this_rat;
    end

    % grand mean across rats at each aligned day
    [Gday, day_u] = findgroups(T_plot.day_from_reversal);
    mean_day = splitapply(@mean, T_plot.(value_var), Gday);

    [day_u, sort_idx] = sort(day_u);
    mean_day = mean_day(sort_idx);

    h_mean = plot(day_u, mean_day, '-o', ...
        'Color', mean_line, ...
        'LineWidth', 3, ...
        'MarkerSize', 7, ...
        'MarkerFaceColor', mean_line, ...
        'MarkerEdgeColor', mean_line);

    xline(0, 'k-', 'LineWidth', 1.2);

    % labels
    text(mean([xmin -0.5]), y_max - 0.03*(y_max-y_min), 'West', ...
        'HorizontalAlignment','center', 'FontSize',12, 'FontWeight','bold');
    text(mean([-0.5 xmax]), y_max - 0.03*(y_max-y_min), 'East', ...
        'HorizontalAlignment','center', 'FontSize',12, 'FontWeight','bold');

    xlabel('Day from reversal', 'FontSize', 12);
    ylabel(strrep(value_var, '_', '\_'), 'FontSize', 12);
    title(fig_title_str, 'FontSize', 14, 'FontWeight', 'bold');

    xlim([xmin-0.5 xmax+0.5]);
    ylim([y_min y_max]);
    xticks(xmin:xmax);

    set(gca, 'Box','off', 'LineWidth',1.2, 'FontSize',11);

    % legend: only valid handles
    valid_idx = isgraphics(legend_handles);
    legend_handles = legend_handles(valid_idx);
    legend_labels  = legend_labels(valid_idx);

    if ~isempty(legend_handles)
        legend([legend_handles; h_mean], [cellstr(legend_labels); {'Grand mean'}], ...
            'Location', 'best');
    else
        legend(h_mean, {'Grand mean'}, 'Location', 'best');
    end

    hold off;

    % safe filename
    save_name = char(save_name);
    save_name = regexprep(save_name, '[^\w]', '_');

    saveas(f, fullfile(save_dir, [save_name '.png']));
    saveas(f, fullfile(save_dir, [save_name '.fig']));
end