function [ISIimage,scaledfilename]=IOSGUI_ImageAnalysis(numtrials,totframes,baseframes,iosframes,...
    stimoffset,tempbin,spatialbin,imgbasename,dfw,numfiles)

    numbins=round(iosframes/tempbin);

    f = waitbar(0,'1','Name','Creating IOS Image',...
        'CreateCancelBtn','setappdata(gcbf,''canceling'',1)');

    setappdata(f,'canceling',0);

    for i=1:numtrials
        % Check for clicked Cancel button
        if getappdata(f,'canceling')
            break
        end

        % Update waitbar and message
        waitbar(i/numtrials,f,sprintf('Calculating Trial #%d',i))


        stimstart=totframes*(i-1)+baseframes+1; %stimulation starts 10 seconds after acquisition starts (11th frame)
        stimSum=[];
        basestart=stimstart-baseframes; 
        count=0; bcount=0;
        base=[]; dR=[];

        for b=1:baseframes
            if numfiles>1
                imgB=imread(sprintf('%s%0*d.tif',imgbasename,dfw,basestart+bcount)); %Load a baseline image 
            else
%                 imgB=imread(imgbasename,basestart+bcount);
                imgB=tiffreadVolume(imgbasename,'PixelRegion', {[1 inf], [1 inf], [basestart+bcount basestart+bcount]});
            end
            imgB=imresize(imgB,spatialbin,'bilinear');
            imgB=imgaussfilt(imgB);
            base=cat(3,base,imgB);
            bcount=bcount+1;
        end

        for j=1:numbins
                stim=[]; 
            for k=1:tempbin
                if numfiles>1
                    imgS=imread(sprintf('%s%0*d.tif',imgbasename,dfw,stimstart+stimoffset+count));
                else
%                     imgS=imread(imgbasename,stimstart+stimoffset+count);
                    imgS=tiffreadVolume(imgbasename,'PixelRegion', {[1 inf], [1 inf],...
                        [stimstart+stimoffset+count stimstart+stimoffset+count]});
                end
                imgS=imresize(imgS,spatialbin,'bilinear');
                imgS=imgaussfilt(imgS);
                stim=cat(3,stim,imgS);
                count=count+1;
            end

                stim=sum(stim,3)/tempbin;
                stimSum=cat(3,stimSum,stim);

        end

        baseAvg=sum(base,3)/baseframes;
        for d=1:numbins
                delta=(stimSum(:,:,d)-baseAvg)./baseAvg;
                dR=cat(3,dR,delta);
        end

        if i==1
                dR_all=dR;
        else
                dR_all=dR_all+dR;
        end

        % Calculate the cumulative image for each trial to see how many trials
        % are needed to get a saturated signal
            dR_RunAvg=dR_all/i;
        if i==1
                ISIimage_RunAvg=zeros(size(imgB,1),size(imgB,2),numtrials);
                ISIimage_RunAvg(:,:,i)=sum(dR_RunAvg,3);
        else
                ISIimage_RunAvg(:,:,i)=sum(dR_RunAvg,3);
        end
    end

    dR_Avg=dR_all/numtrials;
    ISIimage=sum(dR_Avg,3);
    scaled=mat2gray(ISIimage);
    delete(f)
    
    %% Save the data 
    
    save(sprintf('IOSAnalysis_%s%s.mat',imgbasename,string(datetime,'MMddyyyy_HHmmss')));
    if exist('scaled.tif','file')
        scaledfilename=sprintf('scaled_%s.tif',string(datetime,'MMddyyyy_HHmmss'));
        imwrite(scaled,scaledfilename);
    else
        scaledfilename='scaled.tif';
        imwrite(scaled,scaledfilename);
    end
end