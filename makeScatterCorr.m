function makeScatterCorr(x, y, xlab, ylab, savePath)
keep = ~isnan(x) & ~isnan(y);
x = x(keep); y = y(keep);

f = figure('Position',[100,100,450,380]);
scatter(x, y, 18, 'filled'); grid on;
xlim([0 1e-7])
xlabel(xlab); ylabel(ylab);

if numel(x) >= 3
    [r,p] = corr(x, y, 'Type','Pearson');
    title(sprintf('Pearson r = %.3f, p = %.3g, n = %d', r, p, numel(x)));
else
    title(sprintf('n too small (n=%d)', numel(x)));
end

exportgraphics(f, savePath, 'Resolution', 300);
close(f);
end