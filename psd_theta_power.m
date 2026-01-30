clc; clear; close all;

%% Root setting
ROOT.Mother = 'D:';
ROOT.Raw    = [ROOT.Mother '\1. Behavioral data'];
ROOT.Info   = [ROOT.Raw '\info'];
ROOT.Data   = [ROOT.Raw '\results\behavior\15-May-2024\'];  
ROOT.Theta  = [ROOT.Mother '\2. Neural data\raw data\'];

today_is = datetime('today'); today_is.Format = 'yyyy-MM-dd';
today_is = char(today_is);

ROOT.Save = [ROOT.Raw '\results\theta_power_analysis\' today_is];
if ~exist(ROOT.Save,'dir'), mkdir(ROOT.Save); end

%% Load files
load([ROOT.Info '\session_info.mat']);  % session_list
load(['D:\2. Neural data\Analysis\2.LFP_filtering_PSD\2.1.bestTT\2025-11-26\theta_TT.mat']); % theta_TT
addpath(genpath(fullfile(ROOT.Mother, 'toolbox')));

%% navigation & ITI 

rat_list = {'774','779','780','781','816','817'};

params.Fs = 2000;
thetaBand = [6 12];

% Welch
win   = round(1 * params.Fs);          % 1s
if mod(win,2)==1, win = win+1; end
noverlap = round(0.5*win);
nfft = max(2^nextpow2(win), win);

% output table
T_out = table( ...
    strings(0,1), nan(0,1), ...
    nan(0,1), nan(0,1), ...                  % trial
    nan(0,1), nan(0,1), ...                  % ITI
    strings(0,1), strings(0,1), ...
    'VariableNames', {'rat','ss', ...
                      'theta_power_iHP','theta_power_mPFC', ...
                      'theta_power_iHP_ITI','theta_power_mPFC_ITI', ...
                      'goal','stage'});


        for i = 1:NumberofTrial
            tStart = tick_timestamp(ue_Trialstart(i));
            tEnd   = tick_timestamp(ue_Trialend(i));

            trial_time(i,1) = tStart;
            trial_time(i,2) = tEnd;

            % ITI time: ITI start -> Trial start
            if ~isempty(ue_Trialstart_ITI) && numel(ue_Trialstart_ITI) >= i && ~isnan(ue_Trialstart_ITI(i))
                tITI = tick_timestamp(ue_Trialstart_ITI(i));
                iti_time(i,1) = tITI;
                iti_time(i,2) = tStart;
            end
        end

        % ITI 유효 trial만 남김 (NaN 구간 제거)
        iti_valid = ~isnan(iti_time(:,1)) & ~isnan(iti_time(:,2)) & (iti_time(:,2) > iti_time(:,1));
        iti_time  = iti_time(iti_valid, :);
    end




        % iHP
        iHPfile = [ROOT.Theta 'LE' char(rat) '\rat' char(rat) '-' ss '\AG' ...
                   num2str(theta_info.bestTT_iHP) '_RateReduced_3-300filtered.ncs'];
        if exist(iHPfile,'file')
            tmp = local_sessionThetaPSD(iHPfile, trial_time, params.Fs, thetaBand, win, noverlap, nfft);
            if ~isnan(tmp), theta_iHP = tmp; end

            if ~isempty(iti_time)
                tmpITI = local_sessionThetaPSD(iHPfile, iti_time, params.Fs, thetaBand, win, noverlap, nfft);
                if ~isnan(tmpITI), theta_iHP_ITI = tmpITI; end
            end
        end

        % mPFC
        mPFCfile = [ROOT.Theta 'LE' char(rat) '\rat' char(rat) '-' ss '\AG' ...
                    num2str(theta_info.bestTT_mPFC) '_RateReduced_3-300filtered.ncs'];
        if exist(mPFCfile,'file')
            tmp = local_sessionThetaPSD(mPFCfile, trial_time, params.Fs, thetaBand, win, noverlap, nfft);
            if ~isnan(tmp), theta_mPFC = tmp; end

            if ~isempty(iti_time)
                tmpITI = local_sessionThetaPSD(mPFCfile, iti_time, params.Fs, thetaBand, win, noverlap, nfft);
                if ~isnan(tmpITI), theta_mPFC_ITI = tmpITI; end
            end
        end

        % save
        T_out = [T_out; {rat, ss_num, theta_session_iHP, theta_session_mPFC, theta_iHP_ITI, theta_mPFC_ITI, ...
                         string(SL.goal(k)), string(SL.stage(k))}];

end

save(fullfile(ROOT.Save,'theta_power_session_table_PSD_withITI.mat'), 'T_out');
