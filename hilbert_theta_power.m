
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


rat_list = {'774','779','780','781','816','817'};

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

% Nlx flags
HeaderExtractionFlag = 1;
ExtractionMode = 1;
ExtractionModeVector = [];
FieldSelectionFlags = [1 1 1 1 1];

for rr = 1:numel(rat_list)

    rat = string(rat_list{rr});
    SL  = session_list(string(session_list.rat)==rat, :);

    for k = 1:height(SL)

        ss_num = SL.ss(k);
        if isstring(ss_num) || ischar(ss_num)
            ss_num = str2double(ss_num);
        end
        ss = num2str(ss_num);

        target  = char(rat + "-" + sprintf('%02d', ss_num));
        behFile = fullfile(ROOT.Data, [target '.mat']);
        if ~exist(behFile,'file')
            continue;
        end

        % default outputs
        theta_iHP      = nan;
        theta_mPFC     = nan;
        theta_iHP_ITI  = nan;
        theta_mPFC_ITI = nan;

        % theta_TT check
        target_ss_id = ['r' char(rat) '_' ss];
        if ~isfield(theta_TT, target_ss_id)
            T_out = [T_out; {rat, ss_num, theta_iHP, theta_mPFC, theta_iHP_ITI, theta_mPFC_ITI, ...
                             string(SL.goal(k)), string(SL.stage(k))}];
            continue;
        end
        theta_info = theta_TT.(target_ss_id);

        %% ===== load behaviour =====
        load(behFile, 'cheetah','ue_t');
        tick_timestamp = cheetah.tick;

        ue_Trialstart          = ue_t{:,1};
        ue_Trialstart_ITI      = ue_t{:,2};
        ue_Trialend            = ue_t{:,3}; %rewardzone_arrival 
        ue_performance_available = ue_t{:,8};

        NumberofTrial = numel(ue_Trialstart);

        trial_time = nan(NumberofTrial,2);
        iti_time   = nan(NumberofTrial,2);

        for i = 1:NumberofTrial
            if ue_performance_available(i) ~= 1
                continue;
            end

            if isnan(ue_Trialstart(i)) || isnan(ue_Trialend(i))
                continue;
            end

            tS = tick_timestamp(ue_Trialstart(i));
            tE = tick_timestamp(ue_Trialend(i));
            if tE <= tS, continue; end

            trial_time(i,:) = [tS tE];

            if ~isnan(ue_Trialstart_ITI(i))
                tITI = tick_timestamp(ue_Trialstart_ITI(i));
                if tS > tITI
                    iti_time(i,:) = [tITI tS];
                end
            end
        end

        trial_time = trial_time(~isnan(trial_time(:,1)),:);
        iti_time   = iti_time(~isnan(iti_time(:,1)),:);

        %% ===== load iHP (once per session) =====
        clear thetaband_iHP
        try
            iHPfile = [ROOT.Theta 'LE' char(rat) '\rat' char(rat) '-' ss '\AG' ...
                       num2str(theta_info.bestTT_iHP) '_RateReduced_6-12filtered.ncs'];

            [CSC.Timestamps, CSC.ChannelNumbers, CSC.SampleFrequencies, CSC.NumberOfValidSamples, CSC.eeg, CSC.Header] = ...
                Nlx2MatCSC(iHPfile, FieldSelectionFlags, HeaderExtractionFlag, ExtractionMode, ExtractionModeVector);

            ADBitVolts = str2double(CSC.Header{15,1}(13:end));
            CSC.eeg = CSC.eeg .* ADBitVolts;

            [thetaband_iHP.eeg, thetaband_iHP.timestamp] = expandCSC(CSC);
        catch
          
        end

        %% ===== load mPFC (once per session) =====
        clear thetaband_mPFC
        try
            mPFCfile = [ROOT.Theta 'LE' char(rat) '\rat' char(rat) '-' ss '\AG' ...
                        num2str(theta_info.bestTT_mPFC) '_RateReduced_6-12filtered.ncs'];

            [CSC.Timestamps, CSC.ChannelNumbers, CSC.SampleFrequencies, CSC.NumberOfValidSamples, CSC.eeg, CSC.Header] = ...
                Nlx2MatCSC(mPFCfile, FieldSelectionFlags, HeaderExtractionFlag, ExtractionMode, ExtractionModeVector);

            ADBitVolts = str2double(CSC.Header{15,1}(13:end));
            CSC.eeg = CSC.eeg .* ADBitVolts;

            [thetaband_mPFC.eeg, thetaband_mPFC.timestamp] = expandCSC(CSC);
        catch
           
        end

        %% ===== trial Hilbert =====
        if exist('thetaband_iHP','var')
            theta_trial = local_hilbert_mean(thetaband_iHP.timestamp, thetaband_iHP.eeg, trial_time);
            theta_iHP = mean(theta_trial,'omitnan');
        end

        if exist('thetaband_mPFC','var')
            theta_trial = local_hilbert_mean(thetaband_mPFC.timestamp, thetaband_mPFC.eeg, trial_time);
            theta_mPFC = mean(theta_trial,'omitnan');
        end

        %% ===== ITI Hilbert =====
        if ~isempty(iti_time)
            if exist('thetaband_iHP','var')
                theta_iti = local_hilbert_mean(thetaband_iHP.timestamp, thetaband_iHP.eeg, iti_time);
                theta_iHP_ITI = mean(theta_iti,'omitnan');
            end
            if exist('thetaband_mPFC','var')
                theta_iti = local_hilbert_mean(thetaband_mPFC.timestamp, thetaband_mPFC.eeg, iti_time);
                theta_mPFC_ITI = mean(theta_iti,'omitnan');
            end
        end

        %% ===== save =====
        T_out = [T_out; {rat, ss_num, theta_iHP, theta_mPFC, theta_iHP_ITI, theta_mPFC_ITI, ...
                         string(SL.goal(k)), string(SL.stage(k))}];

    end
end

save(fullfile(ROOT.Save,'theta_power_session_table_Hilbert_withITI.mat'),'T_out');



