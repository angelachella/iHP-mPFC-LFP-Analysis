clc; clear;

%% ROOT
ROOT.Mother = 'D:';
ROOT.Raw  = [ROOT.Mother '\1. Behavioral data'];
ROOT.Info = [ROOT.Raw '\info'];
ROOT.Data = [ROOT.Raw '\results\behavior\15-May-2024\'];

load([ROOT.Info '\session_info.mat']);

%% USER
rat_in = "817";
dist_range = [0.3 0.6];   % 원하는 범위

session_list.rat = string(session_list.rat);
SL = session_list(session_list.rat==rat_in,:);

Tout = table();

for s = 1:height(SL)

    target = sprintf('%s-%02d', char(rat_in), double(SL.ss(s)));
    load([ROOT.Data target '.mat']);   % loads ue_t

    % 조건에 맞는 trial index
    idx = ue_t.travaled_distance >= dist_range(1) & ...
          ue_t.travaled_distance <= dist_range(2);

    if any(idx)

        Tadd = table( ...
            repmat(rat_in,sum(idx),1), ...
            repmat(SL.ss(s),sum(idx),1), ...
            find(idx), ...
            ue_t.travaled_distance(idx), ...
            ue_t.start_direction(idx), ...
            'VariableNames',{'rat','ss','trial','travel_distance','start_direction'});

        Tout = [Tout; Tadd];
    end
end