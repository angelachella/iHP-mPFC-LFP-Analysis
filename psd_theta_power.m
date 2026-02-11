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
        load(behFile, 'cheetah','ue_t','encoder');
        tick_timestamp = cheetah.tick;

        ue_Trialstart          = ue_t{:,1};
        ue_Trialstart_ITI      = ue_t{:,2};
        ue_Trialend            = ue_t{:,3}; %rewardzone_arrival 
        ue_performance_available = ue_t{:,8};

        NumberofTrial = numel(ue_Trialstart);

        trial_time = nan(NumberofTrial,2);
        iti_time   = nan(NumberofTrial,2);

       
        for i = 1:NumberofTrial
            tStart = tick_timestamp(ue_Trialstart(i));
            tEnd   = tick_timestamp(ue_Trialend(i));

            trial_time(i,1) = tStart;
            trial_time(i,2) = tEnd;

            % % ITI time: ITI start -> Trial start
            % if ~isempty(ue_Trialstart_ITI) && numel(ue_Trialstart_ITI) >= i && ~isnan(ue_Trialstart_ITI(i))
            %     tITI = tick_timestamp(ue_Trialstart_ITI(i));
            %     iti_time(i,1) = tITI;
            %     iti_time(i,2) = tStart;
            end
        end

        % ITI 유효 trial만 남김 (NaN 구간 제거)
        iti_valid = ~isnan(iti_time(:,1)) & ~isnan(iti_time(:,2)) & (iti_time(:,2) > iti_time(:,1));
        iti_time  = iti_time(iti_valid, :);
       
    
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
        T_out = [T_out; {rat, ss_num, theta_iHP, theta_mPFC, theta_iHP_ITI, theta_mPFC_ITI, ...
                         string(SL.goal(k)), string(SL.stage(k))}];
    end
end

save(fullfile(ROOT.Save,'theta_power_session_table_PSD_withITI.mat'), 'T_out');
