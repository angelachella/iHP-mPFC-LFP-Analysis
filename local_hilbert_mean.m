
function seg_mean = local_hilbert_mean(ts, eeg, seg_time)

ts  = double(ts(:));
eeg = double(eeg(:));

nSeg = size(seg_time,1);
seg_mean = nan(nSeg,1);

for i = 1:nSeg
    tS = seg_time(i,1);
    tE = seg_time(i,2);

    [~, s] = min(abs(ts - tS));
    [~, e] = min(abs(ts - tE));

    if e <= s, continue; end

    env = abs(hilbert(double(eeg(s:e))));
    seg_mean(i) = mean(env,'omitnan');
end
end