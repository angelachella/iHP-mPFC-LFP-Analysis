function make_LFP_validation_sheet_session_withAngularVelocity(ROOT, rat, ss)
% Trial-wise LFP validation sheet with absolute angular velocity
%
% Per trial, 5 tiles:
%   1) iHP theta + mPFC theta overlay
%   2) iHP wideband + theta
%   3) mPFC wideband + theta
%   4) abs angular velocity: raw + 500 ms smoothed
%   5) blank spacer

%% ===================== Session info =====================
ss_num = str2double(ss);
ss1    = sprintf('%d', ss_num);      % LFP folder
ss2    = sprintf('%02d', ss_num);    % behaviour file
key    = sprintf('r%s_%d', rat, ss_num);

%% ===================== Load behavior / bump / bestTT =====================
B = load(fullfile(ROOT.behav, [rat '-' ss2 '.mat']), ...
    'cheetah', 'ue', 'ue_t');

K = load(ROOT.bump, 'T_bump');
T = load(ROOT.bestTT, 'theta_TT');

cheetah  = B.cheetah;
ue       = B.ue;
ue_t     = B.ue_t;
T_bump   = K.T_bump;
theta_TT = T.theta_TT;
TT       = theta_TT.(key);

cheetah_tick    = double(cheetah.tick(:));
trial_start_row = ue_t.trial_start;
valid_trial     = ue_t.performance_available;

%% ===================== Load recomputed angular velocity =====================
angvel_file_mat = fullfile(ROOT.angvel, ...
    sprintf('%s-%s_300ms_angular_velocity.mat', rat, ss2));

angvel_file_csv = fullfile(ROOT.angvel, ...
    sprintf('%s-%s_300ms_angular_velocity.csv', rat, ss2));

if exist(angvel_file_mat, 'file')
    A = load(angvel_file_mat, 'T_angvel');
    T_angvel = A.T_angvel;
elseif exist(angvel_file_csv, 'file')
    T_angvel = readtable(angvel_file_csv);
else
    error('Angular velocity file not found for rat %s ss %s.', rat, ss2);
end

if ~ismember('angular_velocity', T_angvel.Properties.VariableNames)
    error('Column angular_velocity not found in T_angvel.');
end

if ~ismember('angular_velocity_smoothed_500ms', T_angvel.Properties.VariableNames)
    error('Column angular_velocity_smoothed_500ms not found in T_angvel.');
end

angvel_raw = abs(double(T_angvel.angular_velocity(:)));
angvel_smooth = abs(double(T_angvel.angular_velocity_smoothed_500ms(:)));

%% ===================== LFP files =====================
folder_lfp = fullfile(ROOT.rawLFP, ['LE' rat], ['rat' rat '-' ss1]);

file_iHP_wb  = fullfile(folder_lfp, ...
    ['AG' num2str(TT.bestTT_iHP)  '_RateReduced_3-300filtered.ncs']);

file_iHP_th  = fullfile(folder_lfp, ...
    ['AG' num2str(TT.bestTT_iHP)  '_RateReduced_3-13filtered.ncs']);

file_mPFC_wb = fullfile(folder_lfp, ...
    ['AG' num2str(TT.bestTT_mPFC) '_RateReduced_3-300filtered.ncs']);

file_mPFC_th = fullfile(folder_lfp, ...
    ['AG' num2str(TT.bestTT_mPFC) '_RateReduced_3-13filtered.ncs']);

%% ===================== Load LFP =====================
[iHP_wb,  ts_iHP_wb]  = load_csc_lfp(file_iHP_wb);
[iHP_th,  ts_iHP_th]  = load_csc_lfp(file_iHP_th);
[mPFC_wb, ts_mPFC_wb] = load_csc_lfp(file_mPFC_wb);
[mPFC_th, ts_mPFC_th] = load_csc_lfp(file_mPFC_th);

%% ===================== Trial selection using T_bump =====================
T_bump.rat = string(T_bump.rat);

Tb = T_bump(T_bump.rat == string(rat) & T_bump.ss == ss_num, :);

if isempty(Tb)
    fprintf('[SKIP] rat %s ss %s : no T_bump rows\n', rat, ss2);
    return;
end

keep = false(height(Tb), 1);

for i = 1:height(Tb)
    tr = Tb.trial(i);

    if tr >= 1 && tr <= numel(valid_trial) && valid_trial(tr) == 1
        keep(i) = true;
    end
end

Tb = sortrows(Tb(keep, :), 'trial');

if isempty(Tb)
    fprintf('[SKIP] rat %s ss %s : no valid trials\n', rat, ss2);
    return;
end

%% ===================== Compute global theta y-limits =====================
theta_all = [];

for k = 1:height(Tb)

    tr = Tb.trial(k);
    srow = trial_start_row(tr);
    erow = Tb.hit_frame_global(k);

    if isnan(srow) || isnan(erow) || erow <= srow || erow > numel(cheetah_tick)
        continue;
    end

    tick_start = cheetah_tick(srow);
    tick_end   = cheetah_tick(erow);

    [~, iHP_th_s]  = min(abs(ts_iHP_th  - tick_start));
    [~, iHP_th_e]  = min(abs(ts_iHP_th  - tick_end));
    [~, mPFC_th_s] = min(abs(ts_mPFC_th - tick_start));
    [~, mPFC_th_e] = min(abs(ts_mPFC_th - tick_end));

    if iHP_th_e <= iHP_th_s || mPFC_th_e <= mPFC_th_s
        continue;
    end

    theta_all = [theta_all; ...
        iHP_th(iHP_th_s:iHP_th_e); ...
        mPFC_th(mPFC_th_s:mPFC_th_e)]; %#ok<AGROW>
end

if isempty(theta_all)
    theta_ylim = [-1 1];
else
    ymax = max(abs(theta_all), [], 'omitnan');
    if isempty(ymax) || ~isfinite(ymax) || ymax == 0
        ymax = 1;
    end
    theta_ylim = [-ymax ymax];
end

%% ===================== Save path =====================
save_dir = fullfile(ROOT.save, ['rat_' rat]);

if ~exist(save_dir, 'dir')
    mkdir(save_dir);
end

pdf_file = fullfile(save_dir, ...
    sprintf('LFP_validation_angvel_rat_%s_ss_%s.pdf', rat, ss2));

%% ===================== Page loop =====================
nPerPage = 4;
nTrial   = height(Tb);
nPage    = ceil(nTrial / nPerPage);

for iP = 1:nPage

    idx1 = (iP-1)*nPerPage + 1;
    idx2 = min(iP*nPerPage, nTrial);
    Tb_page = Tb(idx1:idx2, :);

    f = figure('Color', 'w', ...
        'Position', [100 50 850 2100], ...
        'Visible', 'off');

    tl = tiledlayout(nPerPage*5, 1, ...
        'TileSpacing', 'none', ...
        'Padding', 'compact');

    title(tl, sprintf('rat %s  ss %s  page %d/%d', ...
        rat, ss2, iP, nPage), ...
        'FontWeight', 'bold');

    for k = 1:height(Tb_page)

        tr   = Tb_page.trial(k);
        srow = trial_start_row(tr);
        erow = Tb_page.hit_frame_global(k);

        tileBase = (k-1)*5;

        if isnan(srow) || isnan(erow) || erow <= srow || ...
           erow > numel(cheetah_tick) || erow > numel(angvel_raw)

            nexttile(tileBase+1); axis off;
            text(0.1, 0.5, sprintf('trial %d: invalid row', tr), 'Color', 'r');
            nexttile(tileBase+2); axis off;
            nexttile(tileBase+3); axis off;
            nexttile(tileBase+4); axis off;
            nexttile(tileBase+5); axis off;
            continue;
        end

        %% --------------------- Time window ---------------------
        tick_start = cheetah_tick(srow);
        tick_end   = cheetah_tick(erow);

        [~, iHP_wb_s]  = min(abs(ts_iHP_wb   - tick_start));
        [~, iHP_wb_e]  = min(abs(ts_iHP_wb   - tick_end));
        [~, iHP_th_s]  = min(abs(ts_iHP_th   - tick_start));
        [~, iHP_th_e]  = min(abs(ts_iHP_th   - tick_end));

        [~, mPFC_wb_s] = min(abs(ts_mPFC_wb  - tick_start));
        [~, mPFC_wb_e] = min(abs(ts_mPFC_wb  - tick_end));
        [~, mPFC_th_s] = min(abs(ts_mPFC_th  - tick_start));
        [~, mPFC_th_e] = min(abs(ts_mPFC_th  - tick_end));

        if iHP_wb_e <= iHP_wb_s || iHP_th_e <= iHP_th_s || ...
           mPFC_wb_e <= mPFC_wb_s || mPFC_th_e <= mPFC_th_s

            nexttile(tileBase+1); axis off;
            text(0.1, 0.5, sprintf('trial %d: LFP align fail', tr), 'Color', 'r');
            nexttile(tileBase+2); axis off;
            nexttile(tileBase+3); axis off;
            nexttile(tileBase+4); axis off;
            nexttile(tileBase+5); axis off;
            continue;
        end

        %% --------------------- Relative time axes ---------------------
        t_iHP_wb  = (ts_iHP_wb(iHP_wb_s:iHP_wb_e)     - tick_start) / 1e6;
        t_iHP_th  = (ts_iHP_th(iHP_th_s:iHP_th_e)     - tick_start) / 1e6;
        t_mPFC_wb = (ts_mPFC_wb(mPFC_wb_s:mPFC_wb_e)  - tick_start) / 1e6;
        t_mPFC_th = (ts_mPFC_th(mPFC_th_s:mPFC_th_e)  - tick_start) / 1e6;

        t_behav = cheetah_tick(srow:erow) - cheetah_tick(srow);

        av_raw = angvel_raw(srow:erow);
        av_smooth = angvel_smooth(srow:erow);

        xmax = max(t_behav);

        %% ===================== 1) theta overlay =====================
        nexttile(tileBase+1);
        plot(t_iHP_th, iHP_th(iHP_th_s:iHP_th_e), 'k'); hold on;
        plot(t_mPFC_th, mPFC_th(mPFC_th_s:mPFC_th_e), 'r');
        xlim([0 max([t_iHP_th(:); t_mPFC_th(:)])]);
        ylim(theta_ylim);
        ylabel('theta');
        title(sprintf('Trial %d', tr), ...
            'FontSize', 15, ...
            'FontWeight', 'bold');
        set(gca, 'XTickLabel', []);

        %% ===================== 2) iHP wideband + theta =====================
        nexttile(tileBase+2);
        plot(t_iHP_wb, iHP_wb(iHP_wb_s:iHP_wb_e), ...
            'Color', [0.7 0.7 0.7]); hold on;
        plot(t_iHP_th, iHP_th(iHP_th_s:iHP_th_e), 'k');
        xlim([0 max(t_iHP_wb)]);
        ylabel('iHP');
        set(gca, 'XTickLabel', []);

        %% ===================== 3) mPFC wideband + theta =====================
        ax3 = nexttile(tileBase+3);
        plot(t_mPFC_wb, mPFC_wb(mPFC_wb_s:mPFC_wb_e), ...
            'Color', [0.7 0.7 0.7]); hold on;
        plot(t_mPFC_th, mPFC_th(mPFC_th_s:mPFC_th_e), 'k');
        xlim([0 max(t_mPFC_wb)]);
        ylabel('mPFC');
        set(ax3, 'XTickLabel', []);
        ax3.YAxisLocation = 'right';

        %% ===================== 4) absolute angular velocity =====================
        ax4 = nexttile(tileBase+4);

        yyaxis left
        plot(t_behav, av_raw, ...
            'Color', [0.65 0.65 0.65], ...
            'LineWidth', 0.75);
        ylabel('|raw ang vel|');

        yyaxis right
        plot(t_behav, av_smooth, ...
            'k', ...
            'LineWidth', 1.2);
        ylabel('|500 ms smooth|');

        xlim([0 xmax]);
        xlabel('Time (s)');
        title('|Angular velocity|');

        ax4.YAxis(1).Color = 'k';
        ax4.YAxis(2).Color = 'k';
        box off;

        %% ===================== 5) blank spacer =====================
        nexttile(tileBase+5);
        axis off;
    end

    drawnow;

    if iP == 1
        exportgraphics(f, pdf_file, 'ContentType', 'image');
    else
        exportgraphics(f, pdf_file, 'Append', true, 'ContentType', 'image');
    end

    close(f);
end

fprintf('[OK] rat %s ss %s\nSaved:\n%s\n', rat, ss2, pdf_file);

end

%% ========================================================================
% Local function
%% ========================================================================
function [lfp, ts] = load_csc_lfp(file_csc)

HeaderExtractionFlag = 1;
ExtractionMode       = 1;
ExtractionModeVector = [];
FieldSelectionFlags  = [1 1 1 1 1];

[CSC.Timestamps, ...
 CSC.ChannelNumbers, ...
 CSC.SampleFrequencies, ...
 CSC.NumberOfValidSamples, ...
 CSC.eeg, ...
 CSC.Header] = Nlx2MatCSC( ...
    file_csc, ...
    FieldSelectionFlags, ...
    HeaderExtractionFlag, ...
    ExtractionMode, ...
    ExtractionModeVector);

CSC.ADBitVolts = str2double(CSC.Header{15,1}(13:end));
CSC.eeg = CSC.eeg .* CSC.ADBitVolts;

[lfp, ts] = expandCSC(CSC);

lfp = double(lfp(:));
ts  = double(ts(:));

end