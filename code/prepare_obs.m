function [Model_real, sObsPerFreq, t_obs, props_obs, g_obs] = prepare_obs(output_path, varargin)

input_parameters;
[~, ~, dx, dz] = define_computational_domain(Lx, Lz, nx, nz);
if ~exist('butterworth_npoles', 'var');
    butterworth_npoles = 5;
end

if filter_stf_with_freqlist 
    nfr = length(f_maxlist);
else
    nfr = 1;
end


%% Model
[Model_real, onlyseiss] = checkargs(varargin(:));
if strcmp(onlyseiss,'yesonlyseis')
    onlyseis = true;
else
    onlyseis = false;
end

% Model_real = update_model(modelnr);

% % plotting the real model
% fig_mod_real = plot_model(Model_real, 'rhovsvp');
% mtit(fig_mod_real, 'real model -- rho-vs-vp parametrisation');
% figname = [output_path,'/obs.model.rhovsvp.png'];
% print(fig_mod_real, '-dpng', '-r400', figname);
% close(fig_mod_real);

% real - background model
if ~onlyseis
    fig_mod_diff = plot_model_diff(Model_real, bg_model_type, 'rhovsvp');
    mtit(fig_mod_diff, 'real - bg model -- rho-vs-vp parametrisation');
    figname = [output_path,'/obs.model-real-diff-bg.rhovsvp.png'];
    print(fig_mod_diff, '-dpng', '-r400', figname);
    close(fig_mod_diff);
end

% h.c. model properties for real model
props_obs = calculate_model_properties(Model_real.rho, 'x');


%% gravity

% gravity field of real model
disp 'creating obs gravity recordings';
[g_obs, fig_grav_obs] = calculate_gravity_field(Model_real.rho, rec_g);
if ~onlyseis
    figname = [output_path,'/obs.gravityrecordings.png'];
    mtit(fig_grav_obs, 'gravity field of real model');
    print(fig_grav_obs, '-dpng', '-r400', figname);
end
close(fig_grav_obs);

%% seismic

if strcmp(use_seis, 'yesseis');
    sEventInfoUnfilt = prepare_stf();
    nsrc = length(sEventInfoUnfilt);
    
    % make sources frequency dependent
    for ifr = 1:nfr
        
        
        % get frequencies
        if filter_stf_with_freqlist
            disp(['FREQUENCY NR. ',num2str(ifr),'/',num2str(nfr), ...
            '. fmin=',num2str(f_minlist(ifr)),', fmax=',num2str(f_maxlist(ifr))]);
            sObsPerFreq(ifr).f_max = f_maxlist(ifr);
            sObsPerFreq(ifr).f_min = f_minlist(ifr);
            
            % filter stf per src & per component
            sEventInfo = sEventInfoUnfilt;
            
            for isrc = 1:nsrc
                comps = fieldnames(sEventInfoUnfilt(isrc).stf);
                for icomp = 1:length(comps)
                    stf = sEventInfoUnfilt(isrc).stf.(comps{icomp});
                    t = sEventInfoUnfilt(isrc).t;
                    stf = butterworth_lp(stf,t,butterworth_npoles, sObsPerFreq(ifr).f_max,'silent');
                    stf = butterworth_hp(stf,t,butterworth_npoles, sObsPerFreq(ifr).f_min,'silent');
                    sEventInfo(isrc).stf.(comps{icomp}) = stf; clearvars stf;
                end
            end
        else
            disp 'NOT filtering stf'
            sObsPerFreq(ifr).f_max = 'not_filtering_stf';
            sObsPerFreq(ifr).f_min = 'not_filtering_stf';
            sEventInfo = sEventInfoUnfilt;
        end
        
        % run forward per source
        [sEventObs, ~] = run_forward_persource(Model_real, sEventInfo, 'noplot');
        
        % plot & save each figure fig_seis
        for isrc = 1:nsrc
            vobs = sEventObs(isrc).vel;
            v0 = make_seismogram_zeros(sEventObs(isrc).vel);
            t   = sEventObs(isrc).t;
            recs = 1:length(vobs);
            % determine how many seismograms are actually plotted
            while length(recs) > 8; recs = [2:2:length(recs)]; end
            % actual plotting
            fig_seis = plot_seismogram_difference(vobs, v0, t, recs, 'nodiff');
            titel = ['src ', num2str(isrc),' - observed seismograms freq range: ', ...
                num2str(sObsPerFreq(ifr).f_min), '-',num2str(sObsPerFreq(ifr).f_max), ' Hz'];
            mtit(fig_seis, titel, 'xoff', 0.001, 'yoff', -0.05);
            figname = [output_path,'/obs.seis.fmax-',num2str(sObsPerFreq(ifr).f_max,'%.2e'),...
                '.src-',num2str(isrc,'%02d'),'.png'];
            print(fig_seis,'-dpng','-r400',figname);
            close(fig_seis);
        end
        
        sObsPerFreq(ifr).sEventInfo = sEventInfo;
        sObsPerFreq(ifr).sEventObs = sEventObs;
    end
    
    t_obs = sObsPerFreq(ifr).sEventObs(1).t;
    
else
    sObsPerFreq = NaN;
    t_obs = NaN;
    
end

%% saving to file

% saving the obs variables
disp 'saving obs variables to matfile...'
savename = [output_path,'/obs.all-vars.mat'];
if strcmp(use_seis, 'yesseis')
    save(savename, 'sObsPerFreq', 't_obs', 'Model_real', 'props_obs', 'g_obs', '-v6');
else
    save(savename, 'Model_real', 'props_obs', 'g_obs', '-v6');
end


% close all;

end

function [Model_real, onlyseis] = checkargs(args)

nargs = length(args);

onlyseis = 'noonlyseis';

% if nargs ~= 1
%     error('wrong input to prepare_obs !')
% else
for ii = 1:nargs
    if isnumeric(args{ii})
        modelnr = args{ii};
        Model_real = update_model(modelnr);
    elseif isstruct(args{ii})
        Model_real = args{ii};
    elseif ischar(args{ii})
        onlyseis = args{ii};
    else
        error('wrong input to prepare_obs !')
    end
end
% end


end