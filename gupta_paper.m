close all;
clear all;
addpath('adds','datasets','auxiliar');

%Initialize the net
architecture;

%Initialize monitors for plotting
combinedMonitors = CombinedMonitors();
combinedMonitors.enabled = true;

results = true;
logging = false;
if (logging)
   %Clear output and open for writing
   fid = fopen('logOfResults.tsv','w'); 
   fclose(fid);
   fid = fopen('logOfResults.tsv','a');
end

time = 0;
for epochIndex = 1:epochs
    
    %Used to print useful information 
    uniqueSpikePercentageTotal = 0;
    topVsClosestNtmpTotal = 0;
    topVsAllNtmpTotal = 0;
    numberOfSpikesPerChar = zeros(1,4);
    
    for dictionaryIndex = 1:length(Dictionary)
        %Each character is presented one at a time sequentially during
        %the training process
        charCounter= mod(dictionaryIndex,length(Dictionary))+1;
        charMatrix = Dictionary{charCounter,2};
        input = reshape(charMatrix,[],1);
        
        %Used to print useful information 
        voltagesMembraneTotal = 0;
        addsDiracForChar=zeros(1,4);   
        
        %Used to plot current character
        combinedMonitors.record_DictionaryLoop(time,charMatrix,input);
                
        %Main code
        for stepIndex = 1:presentationTime*timeStep          
            time = time + timeStep;
            
            %Integrate and fire layer
            likI = input * stimulusIntensity;
            likFired=find(likV > firingThreshold);    % indices of spikes
            likV = likV + timeStep  .* 1/capacitance * (likI - likV./ resistance);
            likV(likFired) = restPotential; %Set to resting potential
            
            likDirac = zeros(15,1);
            likDirac(likFired) = 1;
            likFirings(:,stepIndex) = likDirac; %Something isn't working here, almost all zeros check Monitor.plotFirings
            likLastTimeFired = [likLastTimeFired likLastTimeFired(:,end)];
            likLastTimeFired(likFired,end) = time;
            
            %Second layer
            addsFired=find(voltagesMembrane > firingThreshold);
            addsDirac = zeros(1,4);
            addsDirac(addsFired) = 1;
            addsDiracForChar(addsFired) = 1;            
            addsFirings(:,stepIndex) = addsDirac;
            addsLastTimeFired = [addsLastTimeFired addsLastTimeFired(:,end)];
            addsLastTimeFired(addsFired,end) = time;
            
            tauDendritic = timeConstant(tauMax, tauMin , weightsDendritic);
            resistenceDendritic = resistanceComputation(tauDendritic, firingThreshold , resistenceMembrane, tauMembrane);        
            
            currentDendritic = currentDendritic + timeStep * ((-currentDendritic + resistenceDendritic .* weightsDendritic .* [likDirac likDirac likDirac likDirac] .* 1.8)./tauDendritic);
            currentSomatic = currentSomatic + timeStep * ((-currentSomatic + sum(weightsSomatic .* [addsDirac; addsDirac; addsDirac; addsDirac],1))./tauSomatic);
            
            voltagesMembrane =  voltagesMembrane + timeStep * ((-voltagesMembrane + resistenceMembrane .* ( sum(currentDendritic,1) + currentSomatic))/tauMembrane);
            voltagesMembrane(addsFired) = restPotential;
                                   
            %updateWeights
            for addsNeuron = 1:length(Dictionary)
                deltaSynapticSpike = addsLastTimeFired(addsNeuron,end)*ones(size(likLastTimeFired(end))) -  likLastTimeFired(:,end);
                deltaSynapticWeight = deltaWeight(deltaSynapticSpike);
                weightsDendritic(:,addsNeuron) = newWeight(deltaSynapticWeight,weightsDendritic(:,addsNeuron), weightMinExcitatory, weightMaxExcitatory,learningRate);
                
                somaticSynapseWeigthIndexes = setdiff(1:length(Dictionary),addsNeuron);
                deltaSomaticSpike = addsLastTimeFired(addsNeuron,end)*ones(length(Dictionary)-1,1) -  addsLastTimeFired(somaticSynapseWeigthIndexes,end);
                deltaSomaticWeight = deltaWeight(deltaSomaticSpike);
                weightsSomatic(somaticSynapseWeigthIndexes,addsNeuron) = newWeight(deltaSomaticWeight, weightsSomatic(somaticSynapseWeigthIndexes,addsNeuron), weightMinInhibitory, weightMaxInhibitory,learningRate);
            end
            
            %Used to plot membrane potentials
            combinedMonitors.record_StepLoop(time,likV,voltagesMembrane);
            
            %Used to print useful information 
            voltagesMembraneTotal = voltagesMembraneTotal + voltagesMembrane;             
        end
        
        if (logging)
            logResults(Dictionary{dictionaryIndex}, epochIndex, voltagesMembraneTotal, addsDiracForChar, fid);        
        end
        
        %Used to print useful information 
        if (results)
            [ percentageOfUniqueSpikes, topVsClosestNtmp, topVsAllNtmp ] = scoreResults( Dictionary{dictionaryIndex}, epochIndex, voltagesMembraneTotal, addsDiracForChar );
            uniqueSpikePercentageTotal = uniqueSpikePercentageTotal + percentageOfUniqueSpikes;
            topVsClosestNtmpTotal = topVsClosestNtmpTotal + topVsClosestNtmp;
            topVsAllNtmpTotal = topVsAllNtmpTotal + topVsAllNtmp;
            
            % Record spikes for each Char
            numberOfSpikesForChar = size(find(addsDiracForChar == 1), 2);
            numberOfSpikesPerChar(1, dictionaryIndex) = numberOfSpikesForChar;
        end
    end
    %Print epoch number
    fprintf('Epoch %d of %d \n',epochIndex,epochs);
    
    %Print selected results
    if (results)
        if (epochIndex == 1 || epochIndex == 2 || epochIndex == 3 || epochIndex == 25 || epochIndex == 50 || epochIndex == 75 || epochIndex == 100)
            presentResults(uniqueSpikePercentageTotal, numberOfSpikesPerChar, Dictionary(1:length(Dictionary),1), topVsClosestNtmpTotal, topVsAllNtmpTotal, length(Dictionary));
        end
    end
end

if (logging)
    %Close output file
    fclose(fid);
end
