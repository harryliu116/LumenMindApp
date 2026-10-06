#include <emscripten.h>

#include <memory>
#include <sstream>
#include <string>

#define TYNDALL_WASM
#include "../../tyndall_detector.cpp"

namespace {
std::unique_ptr<TyndallConcentrationPredictor> predictor;
std::string output;
}

extern "C" {

EMSCRIPTEN_KEEPALIVE const char* tynsai_load_model() {
    try {
        predictor = std::make_unique<TyndallConcentrationPredictor>();
        predictor->loadModel("/my_model.xml");
        output.clear();
        return output.c_str();
    } catch (const std::exception& error) {
        output = error.what();
        return output.c_str();
    }
}

EMSCRIPTEN_KEEPALIVE const char* tynsai_predict_image(
    const unsigned char* imageBytes,
    int imageLength
) {
    try {
        if (!predictor) {
            throw std::runtime_error("The TynsAI model has not been loaded.");
        }
        if (imageBytes == nullptr || imageLength <= 0) {
            throw std::runtime_error("The selected image is empty.");
        }

        Mat encoded(1, imageLength, CV_8UC1, const_cast<unsigned char*>(imageBytes));
        Mat image = imdecode(encoded, IMREAD_COLOR);
        if (image.empty()) {
            throw std::runtime_error("The selected image could not be decoded.");
        }
        if (image.cols > 800) {
            resize(image, image, Size(), 800.0 / image.cols, 800.0 / image.cols);
        }

        const float predicted = predictor->predict(image);
        std::ostringstream result;
        result << "\nPrediction Result\n";
        result << "Predicted Mass Percentage: " << predicted << "%\n";
        result << "Image-only prediction (no sensor data)\n";
        output = result.str();
        return output.c_str();
    } catch (const std::exception& error) {
        output = error.what();
        return output.c_str();
    }
}

}