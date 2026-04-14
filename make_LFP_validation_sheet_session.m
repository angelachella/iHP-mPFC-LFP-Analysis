function make_LFP_validation_sheet_session(ROOT, rat, ss)
% Make trial-wise validation sheet for one session
% Each page contains 12 trials

%% Session info
ss_num = str2double(ss);
ss1    = sprintf('%d', ss_num);      % for LFP folder
ss2    = sprintf('%02d', ss_num);    % for behaviour file
key    = sprintf('r%s_%d', rat, ss_num);

%% Load behavior / bump / bestTT
B = load(fullfile(ROOT.behav, [rat '-' ss2 '.mat']), 'cheetah', 'ue', 'ue_t');
K = load(ROOT.bump, 'T_bump');
T = load(ROOT.bestTT, 'theta_TT');

cheetah  = B.cheetah;
ue       = B.ue;
ue_t     = B.ue_t;
T_bump   = K.T_bump;
theta_TT = T.theta_TT;
TT       = theta_TT.(key);

%% Explicit variable names
cheetah_tick    = cheetah.tick;
ue_velocity     = ue.velocity;
trial_start_row = ue_t.trial_start;
valid_trial     = ue_t.performance_available;

%% LFP files
folder_lfp = [ROOT.rawLFP '\LE' rat '\rat' rat '-' ss1];

file_iHP_wb  = [folder_lfp '\AG' num2str(TT.bestTT_iHP)  '_RateReduced_3-300filtered.ncs'];
file_iHP_th  = [folder_lfp '\AG' num2str(TT.bestTT_iHP)  '_RateReduced_6-12filtered.ncs'];
file_mPFC_wb = [folder_lfp '\AG' num2str(TT.bestTT_mPFC) '_RateReduced_3-300filtered.ncs'];
file_mPFC_th = [folder_lfp '\AG' num2str(TT.bestTT_mPFC) '_RateReduced_6-12filtered.ncs'];

HeaderExtractionFlag = 1;
ExtractionMode       = 1;
ExtractionModeVector = [];
FieldSelectionFlags  = [1 1 1 1 1];

%% iHP wideband
[CSCdata.Timestamps, CSCdata.ChannelNumbers, CSCdata.SampleFrequencies, CSCdata.NumberOfValidSamples, ...
    CSCdata.eeg, CSCdata.Header] = Nlx2MatCSC(file_iHP_wb, FieldSelectionFlags, ...
    HeaderExtractionFlag, ExtractionMode, ExtractionModeVector);

CSCdata.ADBitVolts = str2double(CSCdata.Header{15,1}(13:end));
CSCdata.ADMaxValue = str2double(CSCdata.Header{16,1}(13:end));
CSCdata.eeg = CSCdata.eeg .* CSCdata.ADBitVolts;

[iHP_wb, ts_iHP_wb] = expandCSC(CSCdata);

%% iHP theta
[CSCdata.Timestamps, CSCdata.ChannelNumbers, CSCdata.SampleFrequencies, CSCdata.NumberOfValidSamples, ...
    CSCdata.eeg, CSCdata.Header] = Nlx2MatCSC(file_iHP_th, FieldSelectionFlags, ...
    HeaderExtractionFlag, ExtractionMode, ExtractionModeVector);

CSCdata.ADBitVolts = str2double(CSCdata.Header{15,1}(13:end));
CSCdata.ADMaxValue = str2double(CSCdata.Header{16,1}(13:end));
CSCdata.eeg = CSCdata.eeg .* CSCdata.ADBitVolts;

[iHP_th, ts_iHP_th] = expandCSC(CSCdata);

%% mPFC wideband
[CSCdata.Timestamps, CSCdata.ChannelNumbers, CSCdata.SampleFrequencies, CSCdata.NumberOfValidSamples, ...
    CSCdata.eeg, CSCdata.Header] = Nlx2MatCSC(file_mPFC_wb, FieldSelectionFlags, ...
    HeaderExtractionFlag, ExtractionMode, ExtractionModeVector);

CSCdata.ADBitVolts = str2double(CSCdata.Header{15,1}(13:end));
CSCdata.ADMaxValue = str2double(CSCdata.Header{16,1}(13:end));
CSCdata.eeg = CSCdata.eeg .* CSCdata.ADBitVolts;

[mPFC_wb, ts_mPFC_wb] = expandCSC(CSCdata);

%% mPFC theta
[CSCdata.Timestamps, CSCdata.ChannelNumbers, CSCdata.SampleFrequencies, CSCdata.NumberOfValidSamples, ...
    CSCdata.eeg, CSCdata.Header] = Nlx2MatCSC(file_mPFC_th, FieldSelectionFlags, ...
    HeaderExtractionFlag, ExtractionMode, ExtractionModeVector);

CSCdata.ADBitVolts = str2double(CSCdata.Header{15,1}(13:end));
CSCdata.ADMaxValue = str2double(CSCdata.Header{16,1}(13:end));
CSCdata.eeg = CSCdata.eeg .* CSCdata.ADBitVolts;

[mPFC_th, ts_mPFC_th] = expandCSC(CSCdata);

%% Trial selection: use T_bump only
Tb = T_bump(T_bump.rat == string(rat) & T_bump.ss == ss_num, :);
if isempty(Tb)
    fprintf('[SKIP] rat %s ss %s : no T_bump rows\n', rat, ss2);
    return;
end

trial_keep = [];
for i = 1:height(Tb)
    tr = Tb.trial(i);
    if tr >= 1 && tr <= numel(valid_trial) && valid_trial(tr) == 1
        trial_keep(end+1) = i; %#ok<AGROW>
    end
end
Tb = Tb(trial_keep, :);

if isempty(Tb)
    fprintf('[SKIP] rat %s ss %s : no valid trials after filtering\n', rat, ss2);
    return;
end

Tb = sortrows(Tb, 'trial');

%% Save name
save_dir = fullfile(ROOT.save, ['rat_' rat]);
if ~exist(save_dir, 'dir')
    mkdir(save_dir);
end

pdf_file = fullfile(save_dir, sprintf('LFP_validation_rat_%s_ss_%s.pdf', rat, ss2));

%% Page loop
nPerPage = 4;
nTrial   = height(Tb);
nPage    = ceil(nTrial / nPerPage);

for iP = 1:nPage
    idx1 = (iP-1)*nPerPage + 1;
    idx2 = min(iP*nPerPage, nTrial);
    Tb_page = Tb(idx1:idx2, :);

    f = figure('Color','w', 'Position',[100 50 800 1800], 'Visible','off');
    tl = tiledlayout(nPerPage*4,1,'TileSpacing','none','Padding','compact');
    t.TileSpacing = 'none';
    t.Padding = 'none';
    title(tl, sprintf('rat %s  ss %s  page %d/%d', rat, ss2, iP, nPage), 'FontWeight','bold');

    for k = 1:height(Tb_page)
    tr   = Tb_page.trial(k);
    srow = trial_start_row(tr);
    erow = Tb_page.hit_frame_global(k);

    tileBase = (k-1)*4;

    if isnan(srow) || isnan(erow) || erow <= srow
        nexttile(tileBase+1); axis off; text(0.1,0.5,sprintf('trial %d: invalid row', tr),'Color','r');
        nexttile(tileBase+2); axis off;
        nexttile(tileBase+3); axis off;
        nexttile(tileBase+4); axix off;
        continue;
    end

    if erow > numel(cheetah_tick) || erow > numel(ue_velocity)
        nexttile(tileBase+1); axis off; text(0.1,0.5,sprintf('trial %d: row out of range', tr),'Color','r');
        nexttile(tileBase+2); axis off;
        nexttile(tileBase+3); axis off;
        nexttile(tileBase+4); axix off;
        continue;
    end

    % from cheetah
    tick_start = cheetah_tick(srow);
    tick_end   = cheetah_tick(erow);

    % LFP timestamp 중 cheetah_tick과 가장 가까운 값 찾기 
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
        nexttile(tileBase+1); axis off; text(0.1,0.5,sprintf('trial %d: LFP align fail', tr),'Color','r');
        nexttile(tileBase+2); axis off;
        nexttile(tileBase+3); axis off;
        
        continue;
    end

    % 시간축 정렬 (tick start = 0s)
    % LFP 
    t_iHP_wb   = (ts_iHP_wb(iHP_wb_s:iHP_wb_e)    - tick_start) / 1e6; % us --> s
    t_iHP_th   = (ts_iHP_th(iHP_th_s:iHP_th_e)    - tick_start) / 1e6;
    t_mPFC_wb  = (ts_mPFC_wb(mPFC_wb_s:mPFC_wb_e) - tick_start) / 1e6;
    t_mPFC_th  = (ts_mPFC_th(mPFC_th_s:mPFC_th_e) - tick_start) / 1e6;
    t_spd = (cheetah_tick(srow:erow) - cheetah_tick(srow)); %s
    
    spd        = ue_velocity(srow:erow);

    nexttile(tileBase+1);
    plot(t_iHP_wb, iHP_wb(iHP_wb_s:iHP_wb_e), 'Color',[0.7 0.7 0.7]); hold on;
    plot(t_iHP_th, iHP_th(iHP_th_s:iHP_th_e), 'k');
    xlim([0 max(t_iHP_wb)]);
    ylabel('iHP');
    title(sprintf('Trial %d', tr), 'FontSize', 15, 'FontWeight', 'bold');
    set(gca,'XTickLabel',[]);
   
    
    ax2 = nexttile(tileBase+2);

    plot(t_mPFC_wb, mPFC_wb(mPFC_wb_s:mPFC_wb_e), 'Color',[0.7 0.7 0.7]); hold on;
    plot(t_mPFC_th, mPFC_th(mPFC_th_s:mPFC_th_e), 'k');
    
    xlim([0 max(t_mPFC_wb)]);
    ylabel('mPFC');
    
    set(ax2, 'XTickLabel', []);
    ax2.YAxisLocation = 'right';   % 🔥 오른쪽 y축

    % nexttile(tileBase+2);
    % plot(t_mPFC_wb, mPFC_wb(mPFC_wb_s:mPFC_wb_e), 'Color',[0.7 0.7 0.7]); hold on;
    % plot(t_mPFC_th, mPFC_th(mPFC_th_s:mPFC_th_e), 'k');
    % xlim([0 max(t_mPFC_wb)]);
    % ylabel('mPFC');
    % set(gca,'XTickLabel',[]);
    % 
    

    nexttile(tileBase+3);
    plot(t_spd, spd, 'k');
    xlim([0 max(t_spd)]);
    xlabel('Time (s)');
    ylabel('speed');
    
   

    nexttile(tileBase+4);
    set(gca,'YTickLabel',[]);
    set(gca,'XTickLabel',[]);
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

fprintf('[OK] rat %s ss %s', rat, ss2);
end