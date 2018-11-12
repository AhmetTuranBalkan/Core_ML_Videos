//
//  ViewController.swift
//  CoreMLVideos
//
//  Created by Ahmet Turan Balkan on 22.05.2018.
//  Copyright © 2018 TAV. All rights reserved.
//


import Foundation
import UIKit
import AVFoundation
import Vision
import QuartzCore

class ViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    
    var captureSession : AVCaptureSession!
    var cameraOutput : AVCapturePhotoOutput!
    var previewLayer : AVCaptureVideoPreviewLayer!
    
    @IBOutlet weak var previewView: UIView!
    @IBOutlet var predictionTextView: UITextView!
    var imageToAnalyze: UIImage!
    
    let synth = AVSpeechSynthesizer()
    var myUtterance = AVSpeechUtterance(string: "")
    var previousPrediction = ""
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupCamera()
        
        //Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.launchAI), userInfo: nil, repeats: false);
        
    }
    
    func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
        cameraOutput = AVCapturePhotoOutput()
        
        let device = AVCaptureDevice.default(for: AVMediaType.video)
        
        if let input = try? AVCaptureDeviceInput(device: device!) {
            if(captureSession.canAddInput(input)) {
                captureSession.addInput(input)
                
                if(captureSession.canAddOutput(cameraOutput)) {
                    captureSession.addOutput(cameraOutput)
                }
                
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
                previewLayer.frame = previewView.bounds
                previewView.layer.addSublayer(previewLayer)
                captureSession.startRunning()
                
            } else {
                print("could not add the input")
            }
        } else {
            print("could not find an input")
        }
        
        self.launchAI()
        
        
    }
    
    
    @objc func launchAI() {
        
        // capture an image from the video stream (camera)
        // we feed this image as the input of the ML model
        // we capture the relsult and process it back to the User Interface (label)
        let settings = AVCapturePhotoSettings()
        let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
        let previewFormat = [
            kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
            kCVPixelBufferWidthKey as String: 160,
            kCVPixelBufferHeightKey as String: 160
        ]
        settings.previewPhotoFormat = previewFormat
        cameraOutput.capturePhoto(with: settings, delegate: self)
        
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("error occured: \(error.localizedDescription)")
        }
        
        if let imageData = photo.fileDataRepresentation(), let image = UIImage(data: imageData) {
            self.predict(image: image)
        }
    }
    
    
    func predict(image: UIImage) {
        
        // run the model
        // get all the predictions from the completion Handler method
        if let data = UIImagePNGRepresentation(image) {
            let fileName = getDocumentsDirectory().appendingPathComponent("image.png")
            try? data.write(to: fileName)
            
            // use the image as input to feed the model (use its URL)
            let model = try! VNCoreMLModel(for: VGG16().model)
            let request = VNCoreMLRequest(model: model, completionHandler: predictionCompleted)
            let handler = VNImageRequestHandler(url: fileName)
            try! handler.perform([request])
            
        }
    }
    
    func predictionCompleted(request: VNRequest, error: Error?) {
        
        guard let results = request.results as? [VNClassificationObservation] else {
            fatalError("could not get any prediction output from ML model")
        }
        
        var bestPrediction = ""
        var confidence: VNConfidence = 0
        
        for classification in results {
            if classification.confidence > confidence {
                confidence = classification.confidence
                bestPrediction = classification.identifier
            }
        }
        
        self.predictionTextView.text = bestPrediction
        print(bestPrediction)
        
        // scroll textview down
        let stringLength: Int = self.predictionTextView.text.characters.count
        self.predictionTextView.scrollRangeToVisible(NSMakeRange(stringLength-1, 0))
        
        
        Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.launchAI), userInfo: nil, repeats: false)
        
        
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    //////////////////////////
    //////////////////////////
    // Take picture button
    @IBAction func didPressTakePhoto(_ sender: UIButton) {
        let settings = AVCapturePhotoSettings()
        let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
        let previewFormat = [
            kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
            kCVPixelBufferWidthKey as String: 160,
            kCVPixelBufferHeightKey as String: 160
        ]
        settings.previewPhotoFormat = previewFormat
        cameraOutput.capturePhoto(with: settings, delegate: self)
        
    }
    
    
    // This method you can use somewhere you need to know camera permission   state
    func askPermission() {
        print("here")
        let cameraPermissionStatus =  AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        
        switch cameraPermissionStatus {
        case .authorized:
            print("Already Authorized")
        case .denied:
            print("denied")
            
            let alert = UIAlertController(title: "Sorry :(" , message: "But  could you please grant permission for camera within device settings",  preferredStyle: .alert)
            let action = UIAlertAction(title: "Ok", style: .cancel,  handler: nil)
            alert.addAction(action)
            present(alert, animated: true, completion: nil)
            
        case .restricted:
            print("restricted")
        default:
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: {
                [weak self]
                (granted :Bool) -> Void in
                
                if granted == true {
                    // User granted
                    print("User granted")
                    DispatchQueue.main.async(){
                        //Do smth that you need in main thread
                    }
                }
                else {
                    // User Rejected
                    print("User Rejected")
                    
                    DispatchQueue.main.async(){
                        let alert = UIAlertController(title: "WHY?" , message:  "Camera it is the main feature of our application", preferredStyle: .alert)
                        let action = UIAlertAction(title: "Ok", style: .cancel, handler: nil)
                        alert.addAction(action)
                        self?.present(alert, animated: true, completion: nil)
                    }
                }
            });
        }
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }
    
    func analyze(image: UIImage) {
        if let data = UIImagePNGRepresentation(image) {
            let fileName = getDocumentsDirectory().appendingPathComponent("copy.png")
            try? data.write(to: fileName)
            
            self.FindObjectInImage(imageURL: fileName, completionHandler: myResultsMethod)
        }
        
    }
    
    func myResultsMethod(request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNClassificationObservation]
            else { fatalError("something went wrong") }
        
        
        var best : String = ""
        var confidence : VNConfidence = 0
        
        for classification in results {
            if classification.confidence > confidence {
                confidence = classification.confidence
                best = classification.identifier
            }
        }
        
        if(self.isNewPredictionDifferentThanPrevious(newPrediction: best)) {
            print("found: ", best, confidence)
            say(sentence: "I see \(best)")
            self.predictionTextView.text = self.predictionTextView.text + best + "\n"
        } else {
            self.predictionTextView.text = self.predictionTextView.text + "...\n"
        }
        self.previousPrediction = best
        
        // scroll textview down
        let stringLength: Int = self.predictionTextView.text.characters.count
        self.predictionTextView.scrollRangeToVisible(NSMakeRange(stringLength-1, 0))
        
        //Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.launchAI), userInfo: nil, repeats: false);
        
    }
    
    func say(sentence: String) {
        
        myUtterance = AVSpeechUtterance(string: sentence)
        myUtterance.rate = 0.5
        
        synth.speak(myUtterance)
    }
    
    @objc func launchAIOld () {
        self.didPressTakePhoto(UIButton())
    }
    
    func isNewPredictionDifferentThanPrevious (newPrediction: String) -> Bool {
        return previousPrediction != newPrediction
    }
    
    // pragma: arrange view on rotation
    func updatePreviewUI(newSize: CGSize) {
        guard let previewLayer = self.previewLayer else {
            return
        }
        self.previewView.frame = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        previewLayer.frame = self.previewView.bounds
        previewLayer.removeAllAnimations()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: nil, completion: { [weak self] (context) in
            DispatchQueue.main.async(execute: {
                self?.updatePreviewUI(newSize: size)
            })
        })
    }
    
    override func viewWillLayoutSubviews() {
        
        let orientation: UIDeviceOrientation = UIDevice.current.orientation
        print(orientation)
        
        switch (orientation) {
        case .portrait:
            previewLayer?.connection?.videoOrientation = .portrait
        case .landscapeRight:
            previewLayer?.connection?.videoOrientation = .landscapeLeft
        case .landscapeLeft:
            previewLayer?.connection?.videoOrientation = .landscapeRight
        default:
            previewLayer?.connection?.videoOrientation = .portrait
        }
        //self.view.bringSubview(toFront: predictionTextView)
    }
    
    func configureTextView () {
        predictionTextView.layer.shadowColor = UIColor.black.cgColor
        predictionTextView.layer.shadowOffset = CGSize(width: 1, height: 1)
        predictionTextView.layer.shadowOpacity = 1
        predictionTextView.layer.shadowRadius = 1
        predictionTextView.layoutManager.allowsNonContiguousLayout = false
        self.view.bringSubview(toFront: predictionTextView)
    }
    
    func removeShutterSoundTrick () {
        if let soundURL = Bundle.main.url(forResource: "blank", withExtension: "wav"){
            var mySound: SystemSoundID = 0
            AudioServicesCreateSystemSoundID(soundURL as CFURL, &mySound)
            AudioServicesPlaySystemSound(mySound)
        }
    }
    
    func FindObjectInImage (imageURL: URL, completionHandler: Vision.VNRequestCompletionHandler? = nil) {
        let model = try! VNCoreMLModel(for: VGG16().model)
        let request = VNCoreMLRequest(model: model, completionHandler: completionHandler)
        let handler = VNImageRequestHandler(url: imageURL)
        try! handler.perform([request])
    }
}

