function thetaP_mean = local_sessionThetaPSD(ncsFile, trial_time, Fs, thetaBand, win, noverlap, nfft)

FieldSelectionFlags = [1 1 1 1 1];
HeaderExtractionFlag = 1;
ExtractionMode = 1;
ExtractionModeVector = [];

[CSC.Timestamps, CSC.ChannelNumbers, CSC.SampleFrequencies, CSC.NumberOfValidSamples, CSC.eeg, CSC.Header] = ...
    Nlx2MatCSC(ncsFile, FieldSelectionFlags, HeaderExtractionFlag, ExtractionMode, ExtractionModeVector);

ADBitVolts = str2double(CSC.Header{15,1}(13:end));
CSC.eeg = CSC.eeg .* ADBitVolts;

[lfp, ts] = expandCSC(CSC);

nT = size(trial_time,1);
thetaP_trial = nan(nT,1);

for i = 1:nT
    [~, s] = min(abs(ts - trial_time(i,1))); % trial_start
    [~, e] = min(abs(ts - trial_time(i,2))); % trial_end
    if e <= s, continue; end

    x = double(lfp(s:e));
    x = x - mean(x,'omitnan');

    % get psd
    [Pxx, f] = pwelch(x, win, noverlap, nfft, Fs);
    thetaP_trial(i) = bandpower(Pxx, f, thetaBand, 'psd'); % theta power calculation
end

% session average 
thetaP_mean = mean(thetaP_trial,'omitnan');
end
