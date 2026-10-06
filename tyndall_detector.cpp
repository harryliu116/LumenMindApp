#ifdef TYNDALL_WASM
#include <opencv2/core.hpp>
#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>
#else
#include <opencv2/opencv.hpp>
#endif
#include <opencv2/ml.hpp>
#include <iostream>
#include <vector>
#include <string>
#include <fstream>
#include <sstream>
#include <iomanip>
#include <map>

using namespace cv;
using namespace cv::ml;
using namespace std;

static const map<string, float> ORIGINAL_MASS_PERCENTAGE = {
    {"pure_water", 0.0},
    {"whole_milk", 12.5},
    {"skim_milk", 9.0},
    {"starch_suspension", 5.0},
    {"soap_solution", 8.0},
    {"sugar_solution", 50.0},
    {"salt_solution", 26.0},
    {"gelatin", 15.0},
    {"clay_suspension", 10.0},
    {"detergent", 12.0},
    {"coffee", 2.0},
    {"tea", 0.5},
    {"orange_juice", 11.0},
    {"wine", 14.5},
    {"coconut", 3.25},
    {"coconut_water", 3.25},
};

// Experimental data structure
struct ExperimentData {
    string imagePath;
    float originalPercentage;
    float concentrationPercentage;
    float sensorLux;
    float sensorIR;
    float sensorVisible;
    string solutionType;
    float massPercentage;
    float dilutionFactor;
    
    ExperimentData() : originalPercentage(0), concentrationPercentage(100),
                       sensorLux(0), sensorIR(0), sensorVisible(0),
                       massPercentage(0), dilutionFactor(1.0) {}
    
    void calculateDilutionMetrics() {
        massPercentage = originalPercentage * concentrationPercentage / 100.0f;
        
        if (concentrationPercentage > 0) {
            dilutionFactor = 100.0f / concentrationPercentage;
        } else {
            dilutionFactor = 1.0;
        }
    }
};

class TyndallConcentrationPredictor {
private:
    Ptr<SVM> model;
    
    Mat extractFeatures(const Mat& image, float sensorLux, float sensorIR, 
                       float sensorVisible, float massPercentage, 
                       float originalPercentage, float dilutionFactor) {
        vector<float> featureVector;
        
        Mat gray;
        cvtColor(image, gray, COLOR_BGR2GRAY);
        
        Scalar meanVal, stddevVal;
        meanStdDev(gray, meanVal, stddevVal);
        featureVector.push_back(meanVal[0] / 255.0f);
        featureVector.push_back(stddevVal[0] / 255.0f);
        
        Mat brightMask;
        threshold(gray, brightMask, 180, 255, THRESH_BINARY);
        int brightPixels = countNonZero(brightMask);
        float brightRatio = (float)brightPixels / (image.rows * image.cols);
        featureVector.push_back(brightRatio);
        
        Mat veryBrightMask;
        threshold(gray, veryBrightMask, 220, 255, THRESH_BINARY);
        int veryBrightPixels = countNonZero(veryBrightMask);
        float veryBrightRatio = (float)veryBrightPixels / (image.rows * image.cols);
        featureVector.push_back(veryBrightRatio);
        
        double minVal, maxVal;
        minMaxLoc(gray, &minVal, &maxVal);
        float contrast = (maxVal - minVal) / (maxVal + minVal + 1e-6);
        featureVector.push_back(contrast);
        
        Mat edges;
        Canny(gray, edges, 30, 100);
        int edgePixels = countNonZero(edges);
        float edgeDensity = (float)edgePixels / (image.rows * image.cols);
        featureVector.push_back(edgeDensity);
        
        Mat gradX, gradY, magnitude;
        Sobel(gray, gradX, CV_32F, 1, 0);
        Sobel(gray, gradY, CV_32F, 0, 1);
        magnitude = abs(gradX) + abs(gradY);
        Scalar meanGrad = cv::mean(magnitude);
        featureVector.push_back(meanGrad[0] / 255.0f);
        
        Scalar brightGrad = cv::mean(magnitude, brightMask);
        featureVector.push_back(brightGrad[0] / 255.0f);
        
        Mat hist;
        int histSize = 16;
        float range[] = {0, 256};
        const float* histRange = {range};
        calcHist(&gray, 1, 0, Mat(), hist, 1, &histSize, &histRange);
        normalize(hist, hist, 0, 1, NORM_MINMAX);
        for(int i = 0; i < histSize; i++) {
            featureVector.push_back(hist.at<float>(i));
        }
        
        int gridSize = 4;
        int cellHeight = image.rows / gridSize;
        int cellWidth = image.cols / gridSize;
        
        for(int i = 0; i < gridSize; i++) {
            for(int j = 0; j < gridSize; j++) {
                Rect cell(j * cellWidth, i * cellHeight, cellWidth, cellHeight);
                Mat cellRegion = brightMask(cell);
                int cellBright = countNonZero(cellRegion);
                float cellRatio = (float)cellBright / (cellWidth * cellHeight);
                featureVector.push_back(cellRatio);
            }
        }
        
        featureVector.push_back(sensorLux / 1000.0f);
        featureVector.push_back(sensorIR / 10000.0f);
        featureVector.push_back(sensorVisible / 10000.0f);
        
        float irRatio = (sensorLux + sensorVisible) > 0 ? 
            sensorIR / (sensorLux + sensorVisible) : 0;
        featureVector.push_back(irRatio);
        
        float visibleIRRatio = sensorIR > 0 ? sensorVisible / sensorIR : 0;
        featureVector.push_back(visibleIRRatio);
        
        float scatterIndex = sensorVisible > 0 ? sensorLux / sensorVisible : 0;
        featureVector.push_back(scatterIndex);
        
        float fullSpectrum = sensorIR + sensorVisible;
        featureVector.push_back(fullSpectrum / 20000.0f);
        
        float irContribution = fullSpectrum > 0 ? sensorIR / fullSpectrum : 0;
        featureVector.push_back(irContribution);
        
        featureVector.push_back(massPercentage / 70.0f);
        featureVector.push_back(originalPercentage / 70.0f);
        featureVector.push_back(log(dilutionFactor + 1.0) / 5.0);
        
        float concentrationRatio = dilutionFactor > 0 ? 1.0 / dilutionFactor : 0;
        featureVector.push_back(concentrationRatio);
        
        featureVector.push_back((massPercentage / 70.0f) * irRatio);
        featureVector.push_back((massPercentage / 70.0f) * meanVal[0] / 255.0f);
        
        float scatterPerConc = massPercentage > 0 ? 
            (sensorIR / massPercentage) / 1000.0f : 0;
        featureVector.push_back(scatterPerConc);
        
        featureVector.push_back((originalPercentage / 70.0f) * (sensorIR / 10000.0f));
        
        float dilutionCorrectedScatter = sensorIR * concentrationRatio / 10000.0f;
        featureVector.push_back(dilutionCorrectedScatter);
        
        Mat features = Mat(1, featureVector.size(), CV_32F);
        for(size_t i = 0; i < featureVector.size(); i++) {
            features.at<float>(0, i) = featureVector[i];
        }
        
        return features;
    }
    
public:
    TyndallConcentrationPredictor() {
        model = SVM::create();
        model->setType(SVM::EPS_SVR);
        model->setKernel(SVM::RBF);
        model->setGamma(0.1);
        model->setC(10.0);
        model->setP(0.01);
    }
    
    void train(vector<ExperimentData>& experiments) {
        Mat trainData;
        Mat labels;
        
        cout << "\nTYNDALL CONCENTRATION PREDICTOR (Mass Percentage)" << endl;
        cout << "Laser power: 5mW (constant)" << endl;
        cout << "Concentration unit: Mass percentage (%)" << endl;
        cout << "Loading " << experiments.size() << " experimental samples\n" << endl;
        
        for(auto& exp : experiments) {
            exp.calculateDilutionMetrics();
        }
        
        cout << "Known Solution Types and Original Mass Percentages:" << endl;
        for(const auto& pair : ORIGINAL_MASS_PERCENTAGE) {
            cout << "  " << pair.first << ": " << pair.second << "%" << endl;
        }
        cout << endl;
        
        for(const auto& exp : experiments) {
            Mat img = imread(exp.imagePath);
            if(img.empty()) {
                cerr << "Cannot load: " << exp.imagePath << endl;
                continue;
            }
            
            if(img.cols > 800) {
                resize(img, img, Size(), 800.0/img.cols, 800.0/img.cols);
            }
            
            Mat features = extractFeatures(img, exp.sensorLux, exp.sensorIR, 
                                          exp.sensorVisible, exp.massPercentage,
                                          exp.originalPercentage, exp.dilutionFactor);
            trainData.push_back(features);
            labels.push_back(exp.massPercentage);
            
            cout << "Loaded: " << exp.imagePath << endl;
            cout << "  Original Mass %: " << exp.originalPercentage << "%" << endl;
            cout << "  Concentration %: " << exp.concentrationPercentage << "%" << endl;
            cout << "  --> Calculated Current Mass %: " << exp.massPercentage << "%" << endl;
            cout << "  --> Dilution Factor: " << exp.dilutionFactor << "x" << endl;
            if (!exp.solutionType.empty()) {
                cout << "  Solution Type: " << exp.solutionType << endl;
            }
            cout << "  Sensor - Lux: " << exp.sensorLux 
                 << " | IR: " << exp.sensorIR 
                 << " | Visible: " << exp.sensorVisible << endl;
            cout << endl;
        }
        
        if(trainData.rows < 3) {
            cerr << "Need at least 3 samples to train" << endl;
            return;
        }
        
        cout << "Training with " << trainData.rows << " samples, " 
             << trainData.cols << " features" << endl;
        
        Ptr<TrainData> tData = TrainData::create(trainData, ROW_SAMPLE, labels);
        model->train(tData);
        
        cout << "\nTraining Complete" << endl;
    }
    
    float predict(const Mat& image) {
        return predict(image, 0.0f, 0.0f, 0.0f);
    }
    
    float predict(const Mat& image, float sensorLux, float sensorIR, 
                  float sensorVisible) {
        float estimatedPerc = 5.0;
        float originalPerc = 10.0;
        float dilutionFactor = 2.0;
        
        Mat features = extractFeatures(image, sensorLux, sensorIR, sensorVisible, 
                                      estimatedPerc, originalPerc, dilutionFactor);
        return model->predict(features);
    }
    
#ifndef TYNDALL_WASM
    void visualize(const Mat& image, float predictedPercentage, 
                   float actualPercentage = -1) {
        visualize(image, predictedPercentage, 0, 0, 0, actualPercentage);
    }
    
    void visualize(const Mat& image, float predictedPercentage, 
                   float sensorLux, float sensorIR, float sensorVisible,
                   float actualPercentage = -1) {
        Mat display = image.clone();
        
        int y = 40;
        putText(display, "TYNDALL EFFECT ANALYZER", Point(30, y), 
                FONT_HERSHEY_SIMPLEX, 0.9, Scalar(255, 255, 0), 2);
        y += 50;
        
        string predText = "Predicted Mass %: " + 
            to_string(predictedPercentage).substr(0, 5) + "%";
        putText(display, predText, Point(30, y), 
                FONT_HERSHEY_SIMPLEX, 0.9, Scalar(0, 255, 0), 2);
        y += 50;
        
        if (sensorLux > 0.001 || sensorIR > 0.001 || sensorVisible > 0.001) {
            putText(display, "Sensor (5mW laser):", Point(30, y), 
                    FONT_HERSHEY_SIMPLEX, 0.7, Scalar(200, 200, 200), 2);
            y += 35;
            
            string luxText = "  Lux: " + to_string(sensorLux).substr(0, 6);
            putText(display, luxText, Point(30, y), 
                    FONT_HERSHEY_SIMPLEX, 0.6, Scalar(255, 255, 255), 1);
            y += 30;
            
            string irText = "  IR: " + to_string(sensorIR).substr(0, 6);
            putText(display, irText, Point(30, y), 
                    FONT_HERSHEY_SIMPLEX, 0.6, Scalar(255, 255, 255), 1);
            y += 30;
            
            string visText = "  Visible: " + to_string(sensorVisible).substr(0, 6);
            putText(display, visText, Point(30, y), 
                    FONT_HERSHEY_SIMPLEX, 0.6, Scalar(255, 255, 255), 1);
            y += 45;
        }
        
        if(actualPercentage >= 0) {
            string actualText = "Actual Mass %: " + 
                to_string(actualPercentage).substr(0, 5) + "%";
            putText(display, actualText, Point(30, y), 
                    FONT_HERSHEY_SIMPLEX, 0.8, Scalar(100, 100, 255), 2);
            y += 35;
            
            float error = abs(predictedPercentage - actualPercentage);
            string errorText = "Error: " + to_string(error).substr(0, 5) + "%";
            putText(display, errorText, Point(30, y), 
                    FONT_HERSHEY_SIMPLEX, 0.7, Scalar(0, 165, 255), 2);
        }
        
        Mat gray;
        cvtColor(image, gray, COLOR_BGR2GRAY);
        Mat brightMask;
        threshold(gray, brightMask, 180, 255, THRESH_BINARY);
        
        Mat overlay = display.clone();
        overlay.setTo(Scalar(0, 255, 255), brightMask);
        addWeighted(display, 0.85, overlay, 0.15, 0, display);
        
        imshow("Tyndall Effect - Concentration Predictor", display);
        waitKey(0);
    }
#endif
    
    void saveModel(const string& filename) {
        model->save(filename);
        cout << "Model saved: " << filename << endl;
    }
    
    void loadModel(const string& filename) {
        model = SVM::load(filename);
        cout << "Model loaded: " << filename << endl;
    }
    
    static vector<ExperimentData> loadCSV(const string& filename) {
        vector<ExperimentData> data;
        ifstream file(filename);
        
        if(!file.is_open()) {
            cerr << "Cannot open: " << filename << endl;
            return data;
        }
        
        string line;
        getline(file, line);
        
        cout << "Loading data from: " << filename << endl;
        
        while(getline(file, line)) {
            stringstream ss(line);
            ExperimentData exp;
            string temp;
            
            getline(ss, exp.imagePath, ',');
            getline(ss, temp, ','); exp.originalPercentage = stof(temp);
            getline(ss, temp, ','); exp.concentrationPercentage = stof(temp);
            getline(ss, temp, ','); exp.sensorLux = stof(temp);
            getline(ss, temp, ','); exp.sensorIR = stof(temp);
            getline(ss, temp, ','); exp.sensorVisible = stof(temp);
            getline(ss, exp.solutionType, ',');
            
            data.push_back(exp);
        }
        
        file.close();
        cout << "Loaded " << data.size() << " experiments\n" << endl;
        return data;
    }
    
    static void batchPredict(TyndallConcentrationPredictor& predictor,
                            vector<ExperimentData>& testData,
                            const string& outputCSV) {
        ofstream file(outputCSV);
        file << "Image,Original_Percentage,Concentration_Percentage,Calculated_Mass_Percentage,Dilution_Factor,";
        file << "Predicted_Mass_Percentage,Error,";
        file << "Sensor_Lux,Sensor_IR,Sensor_Visible,Solution_Type\n";
        
        cout << "\nBatch Prediction Results" << endl;
        
        for(auto& exp : testData) {
            exp.calculateDilutionMetrics();
        }
        
        float totalError = 0;
        int count = 0;
        
        for(const auto& exp : testData) {
            Mat img = imread(exp.imagePath);
            if(img.empty()) {
                cerr << "Cannot load: " << exp.imagePath << endl;
                continue;
            }
            
            if(img.cols > 800) {
                resize(img, img, Size(), 800.0/img.cols, 800.0/img.cols);
            }
            
            float predicted = predictor.predict(img, exp.sensorLux, 
                                               exp.sensorIR, exp.sensorVisible);
            float error = abs(predicted - exp.massPercentage);
            
            cout << exp.imagePath << endl;
            cout << "   Original %: " << exp.originalPercentage << "%" << endl;
            cout << "   Concentration %: " << exp.concentrationPercentage << "%" << endl;
            cout << "   Calculated Mass %: " << exp.massPercentage << "%" << endl;
            cout << "   Dilution: " << exp.dilutionFactor << "x" << endl;
            cout << "   Predicted: " << predicted << "%" << endl;
            cout << "   Error: " << error << "%\n" << endl;
            
            file << exp.imagePath << ","
                 << exp.originalPercentage << ","
                 << exp.concentrationPercentage << ","
                 << exp.massPercentage << ","
                 << exp.dilutionFactor << ","
                 << predicted << ","
                 << error << ","
                 << exp.sensorLux << ","
                 << exp.sensorIR << ","
                 << exp.sensorVisible << ","
                 << exp.solutionType << "\n";
            
            totalError += error;
            count++;
        }
        
        file.close();
        
        cout << "\nSummary" << endl;
        cout << "Total samples: " << count << endl;
        cout << "Average error: " << (totalError / count) << "%" << endl;
        cout << "Results saved to: " << outputCSV << endl;
    }
};

#ifndef TYNDALL_WASM
int main(int argc, char** argv) {
    if(argc < 2) {
        cout << "\nTYNDALL EFFECT CONCENTRATION PREDICTOR\n" << endl;
        cout << "Concentration Unit: Mass Percentage (%)" << endl;
        cout << "Formula: (mass of solute / total mass) × 100%\n" << endl;
        cout << "Usage:\n" << endl;
        cout << "1. TRAIN MODEL:" << endl;
        cout << "   " << argv[0] << " train <data.csv> <model.xml>\n" << endl;
        cout << "2. PREDICT (image only):" << endl;
        cout << "   " << argv[0] << " predict <image.jpg> <model.xml>\n" << endl;
        cout << "3. PREDICT (image + sensor data):" << endl;
        cout << "   " << argv[0] << " predict <image.jpg> <model.xml> <lux> <ir> <visible>\n" << endl;
        cout << "4. PREDICT (from CSV):" << endl;
        cout << "   " << argv[0] << " predict_csv <test_data.csv> <model.xml> <output.csv>\n" << endl;
        cout << "\nCSV Format:" << endl;
        cout << "   image_path,original_percentage,concentration_percentage,sensor_lux,sensor_ir,sensor_visible,solution_type" << endl;
        cout << "   wine50.jpg,14.5,50,250.5,1200,8500,wine" << endl;
        cout << "   (14.5% original at 50% concentration -> automatically calculates to 7.25% current)\n" << endl;
        cout << "Fields:" << endl;
        cout << "   original_percentage: Original mass % of undiluted solution" << endl;
        cout << "   concentration_percentage: % of original (100=undiluted, 50=half, 25=quarter)" << endl;
        cout << "   solution_type: Optional name for reference" << endl;
        cout << "   -> Program automatically calculates current mass percentage\n" << endl;
        cout << "Available Solution Types:" << endl;
        for(const auto& pair : ORIGINAL_MASS_PERCENTAGE) {
            cout << "   " << pair.first << " (original: " << pair.second << "%)" << endl;
        }
        cout << endl;
        return -1;
    }
    
    string mode = argv[1];
    TyndallConcentrationPredictor predictor;
    
    if(mode == "train") {
        if(argc < 4) {
            cerr << "Usage: train <data.csv> <model.xml>" << endl;
            return -1;
        }
        
        vector<ExperimentData> experiments = 
            TyndallConcentrationPredictor::loadCSV(argv[2]);
        
        if(experiments.size() < 3) {
            cerr << "Need at least 3 experiments" << endl;
            return -1;
        }
        
        predictor.train(experiments);
        predictor.saveModel(argv[3]);
        
    } else if(mode == "predict") {
        if(argc < 4) {
            cerr << "Usage: predict <image.jpg> <model.xml> [lux ir visible]" << endl;
            return -1;
        }
        
        string imagePath = argv[2];
        string modelPath = argv[3];
        
        float lux = 0, ir = 0, visible = 0;
        bool hasSensorData = false;
        
        if(argc >= 7) {
            lux = stof(argv[4]);
            ir = stof(argv[5]);
            visible = stof(argv[6]);
            hasSensorData = true;
        }
        
        predictor.loadModel(modelPath);
        
        Mat image = imread(imagePath);
        if(image.empty()) {
            cerr << "Cannot load image: " << imagePath << endl;
            return -1;
        }
        
        if(image.cols > 800) {
            resize(image, image, Size(), 800.0/image.cols, 800.0/image.cols);
        }
        
        float predicted;
        if (hasSensorData) {
            predicted = predictor.predict(image, lux, ir, visible);
        } else {
            predicted = predictor.predict(image);
        }
        
        cout << "\nPrediction Result" << endl;
        cout << "Predicted Mass Percentage: " << predicted << "%" << endl;
        
        if (hasSensorData) {
            cout << "Sensor readings:" << endl;
            cout << "  Lux: " << lux << endl;
            cout << "  IR: " << ir << endl;
            cout << "  Visible: " << visible << endl;
            predictor.visualize(image, predicted, lux, ir, visible);
        } else {
            cout << "Image-only prediction (no sensor data)" << endl;
            predictor.visualize(image, predicted);
        }
        
    } else if(mode == "predict_csv") {
        if(argc < 5) {
            cerr << "Usage: predict_csv <test_data.csv> <model.xml> <output.csv>" << endl;
            return -1;
        }
        
        predictor.loadModel(argv[3]);
        
        vector<ExperimentData> testData = 
            TyndallConcentrationPredictor::loadCSV(argv[2]);
        
        TyndallConcentrationPredictor::batchPredict(predictor, testData, argv[4]);
    }
    
    return 0;
}
#endif