load('data/FeatureMatrix.mat','Matrix');
size(Matrix);

% 109 label
% 110 Timestamp
% 111 group number
% 112 frame start
% 113 frame end
cols2keep=[5 6 11 12 13 14 15 16 17 18 23 24 29 33 35 38 41 45 47 50 53 59 65 71 77 83 89 95 101 107 109 110 111 112 113];
size(cols2keep);
Matrix(:,setdiff(1:size(Matrix,2),cols2keep))=[];
size(Matrix);

G = findgroups(Matrix(:,33)); % grouping by group IDs
groups = splitapply(@(x){x}, Matrix, G);

res = fopen('result.txt', 'w') ;
fprintf(res, "Group_Number," );
fprintf(res, "DT_Accuracy," );
fprintf(res, "SVM_Accuracy," );
fprintf(res, "NN_Performance\n" );

s = struct([]);
for i = 1: size(groups,1)
    s(i).features = groups{i}(:,1:30);
    s(i).label = groups{i}(:,31);
    s(i).timestamp = groups{i}(1,32);
    s(i).group_Number = groups{i}(1,33);
    s(i).frame_start = groups{i}(1,34);
    s(i).frame_end = groups{i}(1,35);
    s(i).PCA = {};
    [s(i).PCA.coeff,s(i).PCA.score,s(i).PCA.latent,s(i).PCA.tsquared, s(i).PCA.explained, s(i).PCA.mu] = pca(groups{i}(:,1:30));
    s(i).reconstructedMatrix = groups{i}(:,1:30) * s(i).PCA.coeff(:,1:3);
    [rows, columns] = size(s(i).reconstructedMatrix);
    lastRow = int32(floor(0.8 * rows)); % 80 percent of data for training and 20 % percent for testing
    
    Train = s(i).reconstructedMatrix(1:lastRow, :);
    Test  = s(i).reconstructedMatrix(lastRow+1:end, :);
    
    Train_Labels = s(i).label(1:lastRow, :);
    Test_Labels  = s(i).label(lastRow+1:end, :);
    
    s(i).DCT = fitctree(Train,Train_Labels);
    s(i).DCT_predicted_label = predict(s(i).DCT,Test);
    s(i).DCT_Perf = classperf(Test_Labels,s(i).DCT_predicted_label);
    
    s(i).SVM = fitcsvm(Train,Train_Labels);
    s(i).SVM_predicted_label = predict(s(i).SVM,Test);
    s(i).SVM_Perf = classperf(Test_Labels,s(i).SVM_predicted_label);
    
    inputs = s(i).reconstructedMatrix;
    target = s(i).label;
    hiddenLayerSize = 3;
    net.divideParam.trainRatio = 70/100;
    net.divideParam.testRatio  = 30/100;
    [net,tr] = train(net,transpose(inputs),transpose(target));
    % calculating performance on test data
    tInd = tr.testInd;
    outputs = net(transpose(inputs(tInd,:)));
    errors = gsubtract(transpose(target(tInd,:)),outputs);
    performance = perform(net,transpose(target(tInd,:)),outputs);
    
    fprintf(res, '%d,', s(i).group_Number ); 
    fprintf(res, '%f,', s(i).DCT_Perf.CorrectRate);
    fprintf(res, '%f,', s(i).SVM_Perf.CorrectRate);
    fprintf(res, '%f', performance);
    fprintf(res,"\n");
    
    %  2 of the below 4 metrics give precision and recall
%  Am little confused which one is it.
%     s(i).DCT_Perf.Sensitivity  ==> Recall
%     s(i).DCT_Perf.Specificity
%     s(i).DCT_Perf.PositivePredictiveValue ==> precision
%     s(i).DCT_Perf.NegativePredictiveValue
% Accuracy is given by s(i).DCT_Perf.CorrectRate   
end

fclose(res);
% saving variables to file
save('Data./PCAMatrix.mat','s');