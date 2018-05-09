% PURPOSE: Calculates intensities for two- or three-colour GUVs (lumenal intensities)
% using cofocal images of single GUVs
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% published in:
% Litschel et al.,  New Journal of Physics, 2018 "Freeze-thaw cycles induce content exchange 
% between cell-sized lipid vesicles"
%
% This code can analyse single data sets or a series of datasets organised in folders.
% For more information on the code and how to run it, please refer to the
% README file.
%
% Please cite our publication if you use or re-purpose our code!
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear all;
close all;
addpath('./source codes');

global n n2;

%% open dialogue for manual input of parameters and add general parameters
[parameters] = parameter_setup;
[parameters] = parameter_setup_auto(parameters);

%% ask whether multiple dataset are to be analysed

[isbatch,path] = run_batch;

%% extract number of folders to be analysed and their individual paths
% (or set number to 1 if single dataset is analysed and prompt for path)
if isbatch == 1
    [folders2analyse,root_directory] = getfolderstoanalyse(path);
    number_of_samples = length(folders2analyse);
    %load(strcat(root_directory,'/inisizethreshold.mat'));
else
    folders2analyse = 1;
    number_of_samples = 1; %both variables are the same because no
    % normalisation is required for single sample
    %stacks_directory = uigetdir('');
    %this variable can also be set to a fixed path so it does not require
    %GUI input; e.g. stacks_directory = 'C:\Users\DataToAnalyse';
end

% inialise variables before iterating over the datasets

glassorcell = 1;
all_bluevector = [];
total_mean=[];
total_stdev = [];
batchsave = [];

%pre-allocation of variables for batch mode:
if isbatch == 1
collect_n = zeros(1,number_of_samples);
collect_frames = zeros(1,number_of_samples);
collect_n_red = zeros(1,number_of_samples);
collect_n_blue = zeros(1,number_of_samples);
label = cell(1,number_of_samples);
ampli_gof = cell(1,number_of_samples);
ampli_fitres = cell(1,number_of_samples);
lnZ_AND_ampli = cell(1,number_of_samples);
all_red_ampli_collected = cell(1,number_of_samples);
all_blue_ampli_collected = cell(1,number_of_samples);
lnZ_hist_counts = cell(1,number_of_samples);
lnZ_hist_freq = cell(1,number_of_samples);
end

%% iterate over all datasets to be anlysed
for n2=1:number_of_samples
    
    
    %% create saving directory for the given dataset and path to current folder
    if iscell(folders2analyse) == 1
        
        %stacks_directory = strcat(root_directory,'\',folders2analyse{n2});
        stacks_directory = strcat(root_directory,'/',folders2analyse{n2});
        %[save_name,fig_name,batchsave]= make_directory(parameters.exp_name,folders2analyse{n2},batchsave,parameters.loc4dir);
        [save_name,fig_name,batchsave]= make_directory_linux(parameters.exp_name,folders2analyse{n2},batchsave,parameters.loc4dir);
      
        parameters.binary_thres = inisizethreshold(n2);
    else
        
        [save_name,fig_name]= make_directory_linux(parameters.exp_name,cell(1,1),batchsave,parameters.loc4dir);
        
    end
    
    if parameters.nocolours == 2
        
        [red_files,blue_files] = get_tiffs(parameters,stacks_directory);
        Lstack = length(red_files);
        
        %% calculate offset if GUI was set accordingly; use the mean value derived from previous measurements if calculation fails
        % (separate step from the subsequent image manipulations (extra for loop over all images)
        
        if parameters.offsetcorr == 1
            [parameters,offset_temp,offset_turn_temp] = calculate_offsets(parameters,stacks_directory,red_files,blue_files,Lstack);
        end
        
        
        
    else
        
        [red_files,blue_files,yellow_files] = get_tiffs_threecolours(parameters,stacks_directory);
        Lstack = length(red_files);
        yellow = cell(Lstack,1);
        all_yellow_ampli_collected = cell(1,number_of_samples);
        
    end
    
    
    
    
    %inialise variables before looping over the individual images of a
    %dataset
    blue = cell(Lstack,1);
    red = cell(Lstack,1);
    Results_blue = cell(Lstack,1);
    Results_red = cell(Lstack,1);
    xyAI_red = cell(Lstack,1);
    xyAI_blue = cell(Lstack,1);
    xyAI_yellow = cell(Lstack,1);
    start_point_cell = zeros(Lstack,1);
    red_spot_index = ones(Lstack,1)*-1;
    blue_spot_index = ones(Lstack,1)*-1;
    yellow_spot_index = ones(Lstack,1)*-1;
    coloc_spots = cell(Lstack,1);
    coloc_pos = cell(Lstack,1);
    coloc_spots_y = cell(Lstack,1);
    coloc_pos_y = cell(Lstack,1);
    all_blueintAND = [];
    all_redintAND = [];
    all_yellowintAND = [];
    all_blueposAND = [];
    sizeV = [];
    sizeVnoThres = [];
    results = cell(Lstack,1);
    number_of_spots = cell(Lstack,1);
    
%% iterate over the individual images of the dataset n2:
    
    for n = 1:Lstack,
        
        %% read in image data (automatic selection) and correct channel offset if required
        
        if  ~isempty(red_files{n})
            
            % display file index for analysed file in the command line
            disp(strcat('Analysing File ',num2str(n), ' of ',num2str(Lstack)))
            
            %read in image data from tiff files (single image data)
            [red{n}] = read_data(stacks_directory,red_files{n});
            [blue{n}] = read_data(stacks_directory,blue_files{n});
            
            if parameters.nocolours == 3
                [yellow{n}] = read_data_threecolours(stacks_directory,yellow_files{n});
                [red{n}] = read_data_threecolours(stacks_directory,red_files{n});
                [blue{n}] = read_data_threecolours(stacks_directory,blue_files{n});
                
            else
                
                nImage = 1;
                
                close all;
                
            end
            if isempty(red{n})
                
                red_files{n} = [];
                blue_files{n} = [];
            end
            
        end
        
        
        
        %% detect cells in both channels (blue, red) and collect information
        
        if  ~isempty(red_files{n})
            
            if parameters.or == 1
                %generate mask / identify cells from both channels and overlay them ("OR" criterion for cell selection)
                [mask] = createBinaryMask(red{n},blue{n},parameters);
                
                
            elseif parameters.or == 2
                %generate mask / identify cells from red channel only (signal from blue channel ignored for cell selection)
                [mask] = createBinaryMaskRedOnly(blue{n},parameters);
                
            end
            
            % in both cases ("OR" and "REDONLY"), the following function
            % extracts information for each cell (mask element)
            % xyAI_(blue/red) is 1xLstack cell containing each a 5xi matrix
            % where i is the number of cells identified in the current
            % image n; in the matrix
            % (:,1-2) is the xy position, (:,3) is the area (pixel),(:,4) intensity and (:,5) intensity corrected
            % for local background
            % cells whose areas are below the size threshold are discarded
            % in this step
            
            if parameters.or == 1 || parameters.or == 2
                
              
               % GUVs whose areas are larger than a second size threshold are also discarded
                    [xyAI_red{n},bacs2keep,sizeVall]  = extract_int_per_cell(red{n},parameters,fig_name,'r',mask);
                    [xyAI_blue{n}]  = extract_int_per_cell(blue{n},parameters,fig_name,'b',mask,xyAI_red{n},bacs2keep);
                    
                    if parameters.nocolours == 3
                        
                        [xyAI_yellow{n}]  = extract_int_per_cell(yellow{n},parameters,fig_name,'b',mask,xyAI_red{n},bacs2keep);
                        
                    end
             
            else
                % generate mask / identify GUVs from each channel individually and collect data -> at later stage, GUVs are only
                % kept if they appear in both channels ("AND" criterion for cell selection)
                % extract cell information as for OR criterion
            
                  [xyAI_red{n},bacs2keep,sizeVall]  = extract_int_per_cell(red{n},parameters,fig_name,'r');
                  [xyAI_blue{n}]  = extract_int_per_cell(blue{n},parameters,fig_name,'b',bacs2keep);
                    
                    
            
            end
            
            
            %% partially obsolete, will be tidied up in a future commit!
            %% COLOCALISATION - find cells that are present in both channels:
            
            % get number of cells detected for each channel, waste is the
            % dimension in which the coordinates etc per spot are listed (always 5)
            
            resred = xyAI_red{n}(:,1:2);
            resblue = xyAI_blue{n}(:,1:2);
            if isempty(resred)
                number_of_spots{n}.red = 0;
            elseif resred(1,1) ~= 0
                number_of_spots_1 = size(resred);
                number_of_spots{n}.red = number_of_spots_1(1);
            else
                number_of_spots{n}.red = 0;
            end
            if  isempty(resblue)
                number_of_spots{n}.blue = 0;
            elseif resblue(1,1) ~= 0
                number_of_spots_1 = size(resblue);
                number_of_spots{n}.blue = number_of_spots_1(1);
            else
                number_of_spots{n}.blue = 0;
            end
            

            
            if parameters.nocolours == 3
                
                resyellow = xyAI_yellow{n}(:,1:2);
                
                if  isempty(resyellow)
                    number_of_spots{n}.yellow = 0;
                elseif resyellow(1,1) ~= 0
                    number_of_spots_1 = size(resyellow);
                    number_of_spots{n}.yellow = number_of_spots_1(1);
                else
                    number_of_spots{n}.yellow = 0;
                end
                
                
                if number_of_spots{n}.red ~= 0 && number_of_spots{n}.yellow ~= 0
                    [coloc_spots_y{n},coloc_pos_y{n}] = get_spot_distances(resred,resyellow,parameters,number_of_spots{n},'y');
                else
                    coloc_spots_y{n} = ones(parameters.maxD,1)*-1;
                    coloc_pos_y{n} = cell(parameters.maxD,1);
                end
                
                yellow_spot_index(n) = number_of_spots{n}.yellow;
                [~, yellowintAND] = int4colocBACS(coloc_pos_y{n}{parameters.coloc_bin},xyAI_red{n},xyAI_yellow{n});
                
                
                
            end
            
      
            % collect counted cells for current images in a matrix format
            red_spot_index(n) = number_of_spots{n}.red;
            blue_spot_index(n) = number_of_spots{n}.blue;
            
            % extract intensities for colocalised spots (separate vectors for red and blue) so that every row of
            % the vector corresponds to a specific GUV; the background
            % corrected intensity is used as a default

            redintAND = xyAI_red{n}(:,5);
            blueintAND = xyAI_blue{n}(:,5);
            blueposAND = xyAI_blue{n}(:,1:2);
            
            
            % concatenate vectors to create one intensity vector for all
            % images analysed in a sample
            
            all_blueintAND = [all_blueintAND;blueintAND];
            all_blueposAND = [all_blueposAND;blueposAND];
            all_redintAND = [all_redintAND;redintAND];
            sizeV = [sizeV; xyAI_red{n}(:,8)];
            sizeVnoThres = [sizeVnoThres; sizeVall];
            if parameters.nocolours == 3
            all_yellowintAND = [all_yellowintAND;yellowintAND];
            end
        end
        close all;
    end
    
    if parameters.nocolours == 2
        
        %% create and plot histgrams of the ratios of the two channels (red/blue)
        % information is saved both in matrices / variables (fit results) and
        % plots (.fig files)
        
        if parameters.or == 0
            [ampli_gof{n2},ampli_fitres{n2},lnZ_AND_ampli{n2}, all_red_ampli_collected{n2},all_blue_ampli_collected{n2},lnZ_hist_counts{n2},lnZ_hist_freq{n2}] = plot_ratio_histgrams(all_blueintAND,all_redintAND,'lnZ',save_name,'AND');
        elseif parameters.or == 1    
            [ampli_gof{n2},ampli_fitres{n2},lnZ_AND_ampli{n2}, all_red_ampli_collected{n2},all_blue_ampli_collected{n2},lnZ_hist_counts{n2},lnZ_hist_freq{n2}] = plot_ratio_histgrams(all_blueintAND,all_redintAND,'lnZ',save_name,'OR');
        else
            [ampli_gof{n2},ampli_fitres{n2},lnZ_AND_ampli{n2}, all_red_ampli_collected{n2},all_blue_ampli_collected{n2},lnZ_hist_counts{n2},lnZ_hist_freq{n2}] = plot_ratio_histgrams(all_blueintAND,all_redintAND,'lnZ',save_name,'dect red channel only');
        
        end
        
        
        
        
        
        %% create histograms of all intensities for the individual channels
        
        
        plot_save_histogram_int(all_blueintAND,'blue',save_name,folders2analyse);
        plot_save_histogram_int(all_red_ampli_collected{n2},'red',save_name,folders2analyse);
        
        %% save some information extracted from the data in the form of text files:
        dlmwrite(strcat(save_name,'_intensities_for_blue.txt'),all_blue_ampli_collected{n2});
        dlmwrite(strcat(save_name,'_intensities_for_red.txt'),all_red_ampli_collected{n2});
        dlmwrite(strcat(save_name,'_numbers_of_bacs_detected_in_red.txt'),red_spot_index);
        dlmwrite(strcat(save_name,'_numbers_of_bacs_detected_in_blue.txt'),blue_spot_index);
        
        % collect information for sample if multiple samples are analysed to be able
        % to access the information easily for all samples in one variable/file
        
        if isbatch == 1
            collect_n(n2) = size(all_blue_ampli_collected{n2},2);
            collect_frames(n2) = Lstack;
            collect_n_red(n2) = sum(red_spot_index);
            collect_n_blue(n2) = sum(blue_spot_index);
            label{n2} = folders2analyse{n2};
            save(strcat(save_name,'workspace.mat'));
            
        end
        
        %% make scatterplots of red versus blue intensities -
        % intensities plotted here that are 0 will be discarded when the ratio is calculated later
        
        figure;scatterhist(all_red_ampli_collected{n2},all_blue_ampli_collected{n2});
        if isbatch == 1
        title(folders2analyse{n2})
        end
        xlabel('red');
        ylabel('green');
        saveas(gcf,strcat(save_name,'_Scatterplot_intensities','.fig'), 'fig');
        
        boxvar = [sizeVnoThres;sizeV];
        boxvar2 =  [ones(length(sizeVnoThres),1); 2*ones(length(sizeV),1)];
        boxvar3 = [boxvar;boxvar2];
        
        figure;boxplot(boxvar,boxvar2,'labels',{'no size threshold','vesicles > 15um^2'});
         if isbatch == 1
        title(folders2analyse{n2})
        end
        %xlabel('red');
        ylabel('size [um]');
        saveas(gcf,strcat(save_name,'_boxplot_sizes','.fig'), 'fig');
            
        
        scattercloud(all_red_ampli_collected{n2}, all_blue_ampli_collected{n2},50,1,'.','jet')
        set(gca,'XLim', [10^2 10^5],'YLim',[10^2 10^5],'DataAspectRatio',[1 1 1]);
       
        colorbar;
        if isbatch == 1
        title(folders2analyse{n2})
        end
        
        saveas(gcf,strcat(save_name,'_heatmap_lin','.fig'), 'fig');
        
        
        set(gca,'XLim', [10^2 10^5],'YLim',[10^2 10^5],'YScale','log','XScale','log','DataAspectRatio',[1 1 1]);
        saveas(gcf,strcat(save_name,'_heatmap_log','.fig'), 'fig');
        
        heatscatter(all_red_ampli_collected{n2},all_blue_ampli_collected{n2},save_name,'_heatscatterplot.fig',100,20,'.', 1, 0, 'red', 'green','');
        set(gca,'XLim', [5*10^2 10^5],'YLim',[5*10^2 10^5],'DataAspectRatio',[1 1 1]);
        colorbar;
        if isbatch == 1
        title(folders2analyse{n2})
        end
        saveas(gcf,strcat(save_name,'_heatscatterplot_lin','.fig'), 'fig');
        
        
        heatscatter(log10(all_red_ampli_collected{n2}),log10(all_blue_ampli_collected{n2}),save_name,'_heatscatterplot.fig',100,20,'.', 1, 0, 'red', 'green','');
      
        set(gca,'XLim', [2.5 5],'YLim',[2.5 5],'DataAspectRatio',[1 1 1]);%'XTickLabel', {'10^3' '10^4' '10^5'},'YTickLabel',{'10^3' '10^4' '10^5'});
        xticks([2.5 3 4 5]);
        xticklabels({'5*10^2' '10^3' '10^4' '10^5'});
        yticks([2.5 3 4 5]);
        yticklabels({'5*10^2' '10^3' '10^4' '10^5'});
        
        colorbar;
        if isbatch == 1
        title(folders2analyse{n2})
        end
        saveas(gcf,strcat(save_name,'_heatscatterplot_log','.fig'), 'fig');
       
        
   %% data can be also displayed as a contour plot instead:     
%         figure;
%          scatter(all_red_ampli_collected{n2},all_blue_ampli_collected{n2},'.y','SizeData',10);
%          hold on 
%         if isbatch == 1
%         title(folders2analyse{n2})
%         end
%         [N,C] = hist3([all_red_ampli_collected{n2} all_blue_ampli_collected{n2}],[20 20]);
%         contour(C{:},N.',20,'LineWidth',0.5);
%         colormap('hot');
%         xlabel('red');
%         ylabel('green');
%         colorbar;%('peer',axes1);
        
        
    else
        dlmwrite(strcat(save_name,'_intensities_for_blue.txt'),all_blueintAND);
        dlmwrite(strcat(save_name,'_intensities_for_red.txt'),all_redintAND);
        dlmwrite(strcat(save_name,'_intensities_for_yellow.txt'),all_yellowintAND);
        dlmwrite(strcat(save_name,'_numbers_of_bacs_detected_in_red.txt'),red_spot_index);
        dlmwrite(strcat(save_name,'_numbers_of_bacs_detected_in_blue.txt'),blue_spot_index);
        dlmwrite(strcat(save_name,'_numbers_of_bacs_detected_in_yellow.txt'),yellow_spot_index);
        save(strcat(save_name,'completeworkspace.mat'));
        
        [ampli_gof{n2},ampli_fitres{n2},lnZ_AND_ampli{n2}, all_red_ampli_collected{n2},all_blue_ampli_collected{n2},all_yellow_ampli_collected{n2},lnZ_hist_counts{n2},lnZ_hist_freq{n2}] = calc_ratio_histograms(all_blueintAND,all_redintAND,all_yellowintAND,'lnZ',' not norm',save_name,'OR');
        
    end
    
end

%% Scatter plot of means and std from Gaussian fits across samples in batch mode
% comparison of the distributions obtained in different experiments and
% statistical assessment whether they can be assumed to be different
%
% export of ratios (log(ratios)) and amplitudes collected in an excel
% sheet, grouped by sample
if parameters.nocolours == 2
    if isbatch == 1
        save_more_parameters(folders2analyse,save_name,collect_n, collect_frames, collect_n_blue, collect_n_red);
        excel_export_bacs2(folders2analyse,lnZ_AND_ampli,all_red_ampli_collected,all_blue_ampli_collected,lnZ_hist_counts,lnZ_hist_freq,save_name);
    end
    
else
    excel_export_bacs3(folders2analyse,all_blue_ampli_collected,all_red_ampli_collected,all_yellow_ampli_collected,lnZ_hist_counts,lnZ_hist_freq,save_name);
end
%save the workspace again after all samples have been analysed and batch
%calculations are done
save(strcat(save_name,'workspace.mat'));

