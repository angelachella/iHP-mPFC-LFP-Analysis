function make_LFP_validation_sheet_session_firstBump_ueDirection(ROOT, rat, ss)
% Make trial-wise LFP validation sheet for one session
%
% Window:
%   trial start  -->  first bump outward frame
%
% Per trial, 5 tiles:
%   1) iHP theta + mPFC theta overlay
%   2) iHP wideband + iHP theta
%   3) mPFC wideband + mPFC theta
%   4) ue_direction
%   5) blank spacer
%
% Required ROOT fields:
%   ROOT.behav  = behaviour MAT folder
%   ROOT.rawLFP = raw LFP folder
%   ROOT.bestTT = theta_TT.mat full path
%   ROOT.bump   = T_bump.mat full path
%   ROOT.save   = output folder

%% ------------------------------------------------------------
% Session info
%% ------------------------------------------------------------

ss_num = str2double(ss);
ss1    = sprintf('%d', ss_num);      % for LFP folder: rat774-4
ss2    = sprintf('%02d', ss_num);    % for behaviour file: 774-04.mat
key    = sprintf('r%s_%d', rat, ss_num);

%% ------------------------------------------------------------
% Load behaviour / first bump / best TT
%% ------------------------------------------------------------

B = load(fullfile(ROOT.behav, [rat '-' ss2 '.mat']), ...
    'cheetah', 'ue', 'ue_t');

K = load(ROOT.bump, 'T_bump');
T = load(ROOT.bestTT, 'theta_TT');

cheetah  = B.cheetah;
ue       = B.ue;
ue_t     = B.ue_t;
T_bump   = K.T_bump;
theta_TT = T.theta_TT;

TT = theta_TT.(key);

%% ------------------------------------------------------------
% Explicit behavioural variables
%% ------------------------------------------------------------

cheetah_tick    = cheetah.tick;
trial_start_row = ue_t.trial_start;
valid_trial     = ue_t.performance_available;

%% ------------------------------------------------------------
% Extract ue_direction robustly
%% ------------------------------------------------------------

% Case 1: ue is a table with variable name 'direction'
if istable(ue)

    if ismember('direction', ue.Properties.VariableNames)
        ue_direction = ue.direction;

    elseif ismember('ue_direction', ue.Properties.VariableNames)
        ue_direction = ue.ue_direction;

    elseif ismember('head_direction', ue.Properties.VariableNames)
        ue_direction = ue.head_direction;

    elseif ismember('hd', ue.Properties.VariableNames)
        ue_direction = ue.hd;

    else
        error('Could not find direction variable in ue table. Check ue.Properties.VariableNames.');
    end

else
    % Case 2: ue is a numeric matrix.
    % Based on your previous convention, column 8 is head direction / direction.
    ue_direction = ue(:, 8);
end

ue_direction = ue_direction(:);

%% ------------------------------------------------------------
% LFP files
%% ------------------------------------------------------------

folder_lfp = [ROOT.rawLFP '\LE' rat '\rat' rat '-' ss1];

file_iHP_wb  = [folder_lfp '\AG' num2str(TT.bestTT_iHP)  '_RateReduced_3-300filtered.ncs'];
file_iHP_th  = [folder_lfp '\AG' num2str(TT.bestTT_iHP)  '_RateReduced_3-13filtered.ncs'];
file_mPFC_wb = [folder_lfp '\AG' num2str(TT.bestTT_mPFC) '_RateReduced_3-300filtered.ncs'];
file_mPFC_th = [folder_lfp '\AG' num2str(TT.bestTT_mPFC) '_RateReduced_3-13filtered.ncs'];

HeaderExtractionFlag = 1;
ExtractionMode       = 1;
ExtractionModeVector = [];
FieldSelectionFlags  = [1 1 1 1 1];

%% ------------------------------------------------------------
% Load iHP wideband
%% ------------------------------------------------------------

[CSCdata.Timestamps, CSCdata.ChannelNumbers, CSCdata.SampleFrequencies, ...
 CSCdata.NumberOfValidSamples, CSCdata.eeg, CSCdata.Header] = ...
    Nlx2MatCSC(file_iHP_wb, FieldSelectionFlags, ...
    HeaderExtractionFlag, ExtractionMode, ExtractionModeVector);

CSCdata.ADBitVolts = str2double(CSCdata.Header{15,1}(13:end));
CSCdata.ADMaxValue = str2double(CSCdata.Header{16,1}(13:end)); %#ok<NASGU>
CSCdata.eeg = CSCdata.eeg .* CSCdata.ADBitVolts;

[iHP_wb, ts_iHP_wb] = expandCSC(CSCdata);

%% ------------------------------------------------------------
% Load iHP theta
%% ------------------------------------------------------------

[CSCdata.Timestamps, CSCdata.ChannelNumbers, CSCdata.SampleFrequencies, ...
 CSCdata.NumberOfValidSamples, CSCdata.eeg, CSCdata.Header] = ...
    Nlx2MatCSC(file_iHP_th, FieldSelectionFlags, ...
    HeaderExtractionFlag, ExtractionMode, ExtractionModeVector);

CSCdata.ADBitVolts = str2double(CSCdata.Header{15,1}(13:end));
CSCdata.ADMaxValue = str2double(CSCdata.Header{16,1}(13:end)); %#ok<NASGU>
CSCdata.eeg = CSCdata.eeg .* CSCdata.ADBitVolts;

[iHP_th, ts_iHP_th] = expandCSC(CSCdata);

%% ------------------------------------------------------------
% Load mPFC wideband
%% ------------------------------------------------------------

[CSCdata.Timestamps, CSCdata.ChannelNumbers, CSCdata.SampleFrequencies, ...
 CSCdata.NumberOfValidSamples, CSCdata.eeg, CSCdata.Header] = ...
    Nlx2MatCSC(file_mPFC_wb, FieldSelectionFlags, ...
    HeaderExtractionFlag, ExtractionMode, ExtractionModeVector);

CSCdata.ADBitVolts = str2double(CSCdata.Header{15,1}(13:end));
CSCdata.ADMaxValue = str2double(CSCdata.Header{16,1}(13:end)); %#ok<NASGU>
CSCdata.eeg = CSCdata.eeg .* CSCdata.ADBitVolts;

[mPFC_wb, ts_mPFC_wb] = expandCSC(CSCdata);

%% ------------------------------------------------------------
% Load mPFC theta
%% ------------------------------------------------------------

[CSCdata.Timestamps, CSCdata.ChannelNumbers, CSCdata.SampleFrequencies, ...
 CSCdata.NumberOfValidSamples, CSCdata.eeg, CSCdata.Header] = ...
    Nlx2MatCSC(file_mPFC_th, FieldSelectionFlags, ...
    HeaderExtractionFlag, ExtractionMode, ExtractionModeVector);

CSCdata.ADBitVolts = str2double(CSCdata.Header{15,1}(13:end));
CSCdata.ADMaxValue = str2double(CSCdata.Header{16,1}(13:end)); %#ok<NASGU>
CSCdata.eeg = CSCdata.eeg .* CSCdata.ADBitVolts;

[mPFC_th, ts_mPFC_th] = expandCSC(CSCdata);

%% ------------------------------------------------------------
% Trial selection: only trials with first bump
%% ------------------------------------------------------------

Tb = T_bump(T_bump.rat == string(rat) & T_bump.ss == ss_num, :);

if isempty(Tb)
    fprintf('[SKIP] rat %s ss %s : no T_bump rows\n', rat, ss2);
    return;
end

trial_keep = [];

for i = 1:height(Tb)

    tr = Tb.trial(i);

    if tr >= 1 && ...
       tr <= numel(valid_trial) && ...
       valid_trial(tr) == 1 && ...
       ~isnan(Tb.hit_frame_global(i))

        trial_keep(end+1) = i; %#ok<AGROW>
    end
end

Tb = Tb(trial_keep, :);

if isempty(Tb)
    fprintf('[SKIP] rat %s ss %s : no valid first-bump trials\n', rat, ss2);
    return;
end

Tb = sortrows(Tb, 'trial');

%% ------------------------------------------------------------
% Compute global theta y-limits across trial start → first bump
%% ------------------------------------------------------------

theta_all = [];

for k = 1:height(Tb)

    tr   = Tb.trial(k);
    srow = trial_start_row(tr);
    erow = Tb.hit_frame_global(k);

    if isnan(srow) || isnan(erow) || erow <= srow
        continue;
    end

    if erow > numel(cheetah_tick)
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
    ymax = prctile(abs(theta_all), 99);

    if isempty(ymax) || ~isfinite(ymax) || ymax == 0
        ymax = 1;
    end

    theta_ylim = [-ymax ymax];
end

%% ------------------------------------------------------------
% Save name
%% ------------------------------------------------------------

save_dir = fullfile(ROOT.save, ['rat_' rat]);

if ~exist(save_dir, 'dir')
    mkdir(save_dir);
end

pdf_file = fullfile(save_dir, ...
    sprintf('LFP_validation_firstBump_ueDirection_rat_%s_ss_%s.pdf', rat, ss2));

%% ------------------------------------------------------------
% Page loop
%% ------------------------------------------------------------

nPerPage = 4;
nTrial   = height(Tb);
nPage    = ceil(nTrial / nPerPage);

for iP = 1:nPage

    idx1 = (iP-1)*nPerPage + 1;
    idx2 = min(iP*nPerPage, nTrial);

    Tb_page = Tb(idx1:idx2, :);

    f = figure('Color','w', ...
        'Position',[100 50 850 2100], ...
        'Visible','off');

    tl = tiledlayout(nPerPage*5, 1, ...
        'TileSpacing','none', ...
        'Padding','compact');

    title(tl, ...
        sprintf('rat %s  ss %s page %d/%d', ...
        rat, ss2, iP, nPage), ...
        'FontWeight','bold');

    for k = 1:height(Tb_page)

        tr   = Tb_page.trial(k);
        srow = trial_start_row(tr);
        erow = Tb_page.hit_frame_global(k);

        tileBase = (k-1)*5;

        %% ----------------------------------------------------
        % Validate rows
        %% ----------------------------------------------------

        if isnan(srow) || isnan(erow) || erow <= srow

            nexttile(tileBase+1);
            axis off;
            text(0.1, 0.5, sprintf('trial %d: invalid row', tr), 'Color','r');

            nexttile(tileBase+2); axis off;
            nexttile(tileBase+3); axis off;
            nexttile(tileBase+4); axis off;
            nexttile(tileBase+5); axis off;

            continue;
        end

        if erow > numel(cheetah_tick) || erow > numel(ue_direction)

            nexttile(tileBase+1);
            axis off;
            text(0.1, 0.5, sprintf('trial %d: row out of range', tr), 'Color','r');

            nexttile(tileBase+2); axis off;
            nexttile(tileBase+3); axis off;
            nexttile(tileBase+4); axis off;
            nexttile(tileBase+5); axis off;

            continue;
        end

        %% ----------------------------------------------------
        % Behaviour time window
        %% ----------------------------------------------------

        tick_start = cheetah_tick(srow);
        tick_end   = cheetah_tick(erow);

        %% ----------------------------------------------------
        % Find nearest LFP timestamps
        %% ----------------------------------------------------

        [~, iHP_wb_s]  = min(abs(ts_iHP_wb  - tick_start));
        [~, iHP_wb_e]  = min(abs(ts_iHP_wb  - tick_end));

        [~, iHP_th_s]  = min(abs(ts_iHP_th  - tick_start));
        [~, iHP_th_e]  = min(abs(ts_iHP_th  - tick_end));

        [~, mPFC_wb_s] = min(abs(ts_mPFC_wb - tick_start));
        [~, mPFC_wb_e] = min(abs(ts_mPFC_wb - tick_end));

        [~, mPFC_th_s] = min(abs(ts_mPFC_th - tick_start));
        [~, mPFC_th_e] = min(abs(ts_mPFC_th - tick_end));

        if iHP_wb_e <= iHP_wb_s || iHP_th_e <= iHP_th_s || ...
           mPFC_wb_e <= mPFC_wb_s || mPFC_th_e <= mPFC_th_s

            nexttile(tileBase+1);
            axis off;
            text(0.1, 0.5, sprintf('trial %d: LFP align fail', tr), 'Color','r');

            nexttile(tileBase+2); axis off;
            nexttile(tileBase+3); axis off;
            nexttile(tileBase+4); axis off;
            nexttile(tileBase+5); axis off;

            continue;
        end

        %% ----------------------------------------------------
        % Time axes relative to trial start
        %% ----------------------------------------------------

        t_iHP_wb = ...
            (ts_iHP_wb(iHP_wb_s:iHP_wb_e) - tick_start) / 1e6;

        t_iHP_th = ...
            (ts_iHP_th(iHP_th_s:iHP_th_e) - tick_start) / 1e6;

        t_mPFC_wb = ...
            (ts_mPFC_wb(mPFC_wb_s:mPFC_wb_e) - tick_start) / 1e6;

        t_mPFC_th = ...
            (ts_mPFC_th(mPFC_th_s:mPFC_th_e) - tick_start) / 1e6;

        t_beh = ...
            (cheetah_tick(srow:erow) - cheetah_tick(srow));

        dir_this = ue_direction(srow:erow);

        %% ----------------------------------------------------
        % Optional: unwrap direction for smoother visualisation
        % If you want raw 0-360 values, set plot_unwrapped_direction = false.
        %% ----------------------------------------------------

        plot_unwrapped_direction = false;

        if plot_unwrapped_direction
            dir_plot = rad2deg(unwrap(deg2rad(dir_this)));
            ylab_dir = 'ue direction unwrapped (deg)';
        else
            dir_plot = dir_this;
            ylab_dir = 'ue direction (deg)';
        end

        %% ----------------------------------------------------
        % 1) iHP theta + mPFC theta overlay
        %% ----------------------------------------------------

        nexttile(tileBase+1);

        plot(t_iHP_th, iHP_th(iHP_th_s:iHP_th_e), 'k'); hold on;
        plot(t_mPFC_th, mPFC_th(mPFC_th_s:mPFC_th_e), 'r');

        xlim([0 max([t_iHP_th(:); t_mPFC_th(:)])]);
        ylim(theta_ylim);

        ylabel('theta');
        title(sprintf('Trial %d | start → first bump', tr), ...
            'FontSize', 15, ...
            'FontWeight', 'bold');

        set(gca, 'XTickLabel', []);

        %% ----------------------------------------------------
        % 2) iHP wideband + theta
        %% ----------------------------------------------------

        nexttile(tileBase+2);

        plot(t_iHP_wb, iHP_wb(iHP_wb_s:iHP_wb_e), ...
            'Color', [0.7 0.7 0.7]); hold on;

        plot(t_iHP_th, iHP_th(iHP_th_s:iHP_th_e), 'k');

        xlim([0 max(t_iHP_wb)]);
        ylabel('iHP');
        set(gca, 'XTickLabel', []);

        %% ----------------------------------------------------
        % 3) mPFC wideband + theta
        %% ----------------------------------------------------

        ax3 = nexttile(tileBase+3);

        plot(t_mPFC_wb, mPFC_wb(mPFC_wb_s:mPFC_wb_e), ...
            'Color', [0.7 0.7 0.7]); hold on;

        plot(t_mPFC_th, mPFC_th(mPFC_th_s:mPFC_th_e), 'k');

        xlim([0 max(t_mPFC_wb)]);
        ylabel('mPFC');

        set(ax3, 'XTickLabel', []);
        ax3.YAxisLocation = 'right';

        %% ----------------------------------------------------
        % 4) ue_direction
        %% ----------------------------------------------------

        ax4 = nexttile(tileBase+4);

        plot(t_beh, dir_plot, 'k', 'LineWidth', 1);
        hold on;

        xlim([0 max(t_beh)]);
        xlabel('Time (s)');
        ylabel(ylab_dir);

        % If your direction is 0-360 degrees, this keeps the y-axis interpretable.
        if ~plot_unwrapped_direction
            ylim([0 360]);
            yticks(0:90:360);
        end

        box off;
        ax4.YAxis(1).Color = 'k';

        %% ----------------------------------------------------
        % 5) blank spacer
        %% ----------------------------------------------------

        nexttile(tileBase+5);
        set(gca, 'YTickLabel', []);
        set(gca, 'XTickLabel', []);
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

fprintf('[OK] rat %s ss %s | saved: %s\n', rat, ss2, pdf_file);

end