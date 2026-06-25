function raw_behaviour_sheet_batch()
% Batch for trial-wise raw behaviour sheets

clc; clear; close all;

%% Root paths
ROOT.behav   = 'D:\1. Behavioral data\results\behavior\15-May-2024';
ROOT.session = 'D:\2. Neural data\raw data\session_info.mat';
ROOT.bump    = 'D:\2. Neural data\raw data\innerCircle_first_bump_results.mat';
ROOT.save    = 'D:\2. Neural data\Analysis\raw_behaviour';
ROOT.toolbox = 'D:\toolbox';

if exist(ROOT.toolbox, 'dir')
    addpath(genpath(ROOT.toolbox));
end

if ~exist(ROOT.save, 'dir')
    mkdir(ROOT.save);
end

%% Load session list
load(ROOT.session, 'session_list');

%% Rat list
rat_list = {'774'}; 
%rat_list = {'781'};

%% Batch loop
for r = 1:length(rat_list)

    rat_ss = session_list(session_list.rat == rat_list{r}, :);

    for s = 1:size(rat_ss, 1)

        rat = char(rat_ss.rat(s));
        ss  = char(rat_ss.ss(s));

        try
            fprintf('Running %s-%02d ...\n', rat, str2double(ss));

            raw_behaviour_20260612(ROOT, rat, ss);

        catch ME
            fprintf(2, '[FAIL] %s-%02d\n%s\n', rat, str2double(ss), ME.message);
        end
    end
end

fprintf('Done.\n');

end