//
//  ExpViewController.swift
//  SMTap
//
//  Created by Tim on 10/28/15.
//  Copyright © 2015 Q. All rights reserved.
//

import UIKit

class ExpViewController: UIViewController {

	var engine: ExpEngine!

	@IBOutlet weak var counterLabel: UILabel!
	@IBOutlet weak var instructLabel: UILabel!
	@IBOutlet weak var instructBigLabel: UILabel!
	
	@IBOutlet weak var tapButton: UIButton!
	@IBOutlet weak var nextButton: UIButton!
	@IBOutlet var panButtonGestureRecognizer: UIPanGestureRecognizer!
	@IBOutlet weak var progressView: UIProgressView!
	@IBOutlet weak var practiceLabel: UILabel!
	@IBOutlet weak var instructImg: UIImageView!
	
	private var remainTaps: Int = 0
	private var repeats: Int = 0
	
	private var showIntroSteps: Int = 0
	
	private let initInstruct = ["In this session you will tap in the center of the button with the index finger of your preferred hand while resting the other fingers on the iPad. \n\nThe screen is very sensitive, so you can tap fairly lightly. While the iPad isn’t fragile, please avoid hard taps and do not press down after making contact with the screen. A brief contact is sufficient, and you only need to tap hard enough to clearly feel the impact of your finger on the screen.",
	"Please use a consistent tapping style for all of the tapping tasks, regardless of how fast or slow you tap. While tapping, try avoid drifting from the center of the button.\n\nTake this time to practice and move the button to a comfortable position."]
	//	Please rest your wrist and fingers (other than index finger) on the table while tapping.
	
	private let instruct: [ExpEngine.TaskType: [String]] = [
	ExpEngine.TaskType.Slow : ["In this task you will tap as slow as possible while maintaining a smooth and continuous rhythm. Please tap as evenly as possible. Try practice tapping as slow as possible on the button below. When you are ready to continue, tap Next",
		"You are ready to begin, start tapping as slow as possible below:"],
		
	ExpEngine.TaskType.Comfortable : ["In this task you will tap at your favorite, or preferred, pace.  By preferred pace, we mean a rate that is not too fast or too slow, but feels “just right” for you. Please tap as evenly as possible. Try practice tapping at a comfortable pace on the button below. When you are ready to continue, tap Next",
		"You are ready to begin, start tapping at a comfortable pace:"],
		
	ExpEngine.TaskType.Fast : ["In this task you will tap as fast as possible. Try practice tapping as fast as possible on the button below. When you are ready to continue, tap Next",
		"You are ready to begin, start tapping as fast as you can:"]
	]

	private let instructCommon = ["Keep tapping...",
		"You are done! Press Next to repeat",
		"You are done! Press Next to continue"]
	
	private var curTask: ExpEngine.Task { return engine.curTask }
	
	private var step: Int = 0 {
		didSet{
			switch step {
			case 0:	//begin instruct
				instructBigLabel.hidden = false
				instructBigLabel.text = instruct[curTask.type]![0]
				instructLabel.hidden = true
				tapButton.enabled = true
				nextButton.enabled = true
				practiceLabel.hidden = false
				progressView.hidden = false
				remainTaps = 5
				progressView.setProgress(0, animated: true)
				instructImg.hidden = true
			case 1:	//begin task
				instructBigLabel.hidden = true
				instructLabel.hidden = false
				instructLabel.text = instruct[curTask.type]![1]
				engine.startRecording()
				tapButton.enabled = true
				nextButton.enabled = false
				practiceLabel.hidden = true
				remainTaps = curTask.length
				progressView.setProgress(0, animated: true)
				instructImg.hidden = false
				instructImg.image = UIImage(named: "go")
			case 2:	// continue tapping
				instructLabel.text = instructCommon[0]
			case 3:	// finish tapping
				engine.stopRecording()
				tapButton.enabled = false
				nextButton.enabled = true
				
				instructImg.image = UIImage(named: "done")
				
				repeats -= 1
				if repeats == 0 {
					instructLabel.text = instructCommon[2]

					engine.flushRecordToFile()
					
//					check if we are finished:
					if engine.currentTaskIndex == engine.session.count-1 {
						let alertVC = UIAlertController(title: "Session Complete (\(engine.currentRecord.ID))", message: "Please find the experimenter. Saved \(engine.session.count) tasks", preferredStyle: .Alert)
						let ExVC = self
						let closeAction = UIAlertAction(title: "OK", style: .Default)
							{ finished in
								ExVC.dismissViewControllerAnimated(true, completion: nil)
						}
						alertVC.addAction(closeAction)
						
						presentViewController(alertVC, animated: true, completion: nil)
					}
					
				} else {
					instructLabel.text = instructCommon[1]
				}
			default:
				break
			}
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		let movBack = UIImage(named: "tapButton-mov")
		tapButton.setBackgroundImage(movBack, forState: .Normal)
		tapButton.setBackgroundImage(movBack, forState: .Highlighted)
	}
	
	override func viewWillAppear(animated: Bool) {
		engine.currentTaskIndex = 0
		repeats = curTask.repeats
		counterLabel.text = ""
		instructBigLabel.text = initInstruct[0]
		instructLabel.hidden = true
		instructBigLabel.hidden = false
		instructImg.hidden = true
		if engine.showFeedback {
			tapButton.setTitleColor(UIColor.whiteColor(), forState: .Highlighted)
		} else {
			tapButton.setTitleColor(UIColor.darkGrayColor(), forState: .Highlighted)
		}
	}
	
	@IBAction func tapClose(sender: UIButton) {
		let alertVC = UIAlertController(title: "End This Session? ", message: "Are you sure? Any unfinished task will be discarded, previously completed task are saved automatically.", preferredStyle: .Alert)
		let exitAction = UIAlertAction(title: "Exit", style: .Destructive) { action in
			self.dismissViewControllerAnimated(true, completion: nil)
		}
		let cancelAction = UIAlertAction(title: "Cancel", style: .Default, handler: nil)
		
		alertVC.addAction(exitAction)
		alertVC.addAction(cancelAction)
		presentViewController(alertVC, animated: true, completion: nil)
	}
	
	@IBAction func tapNext(sender: UIButton) {
		guard showIntroSteps > 1 else {
			showIntroSteps += 1
			
			if showIntroSteps > 1 {
				updateCounterLabel()
				step = 0
				panButtonGestureRecognizer.enabled = false
				let movBack = UIImage(named: "tapButton")
				tapButton.setBackgroundImage(movBack, forState: .Normal)
				tapButton.setBackgroundImage(movBack, forState: .Highlighted)
			} else {
				instructBigLabel.text = initInstruct[showIntroSteps]
			}
			return
		}
		
		switch step {
		case 3:
			updateCounterLabel()
			if repeats == 0 { // starting new task
				engine.currentTaskIndex += 1
				repeats = curTask.repeats
				step = 0
			} else {
				step = 1
			}
		default:
			step += 1
		}
	}
	
	@IBAction func tapDown(sender: UIButton) {
		guard step != 0 else { return }
		engine.tapDown()
		
	}
	
	@IBAction func tapUp(sender: UIButton) {
		remainTaps -= 1
		
		guard step != 0 else {
			let animated: Bool
			if remainTaps == -1 {
				remainTaps = 5
				animated = false
			} else {
				animated = true
			}
				//		update progress too:
			progressView.setProgress(1 - Float(remainTaps) / 5, animated: animated)
			return
		}
		//		update progress too:
		progressView.setProgress(1 - Float(remainTaps) / Float(curTask.length), animated: true)

		
		engine.tapUp()
		
		if step == 1 { step = 2 }
		
//		remainTaps -= 1
//		update progress too:
//		progressView.setProgress(1 - Float(remainTaps) / Float(curTask.length), animated: true)
		
		if remainTaps == 0 {
			step += 1
		}
	}
	
	@IBAction func tappedGesture(sender: UITapGestureRecognizer) {
		guard step == 1 || step == 2 else { return }
		var tapPos = sender.locationInView(tapButton)
		tapPos.x = tapPos.x - tapButton.bounds.width/2
		tapPos.y = tapPos.y - tapButton.bounds.height/2
		print(tapPos)
	}
	
	@IBAction func pannedGesture(sender: UIPanGestureRecognizer) {
		let thisView = sender.view!
		let superview = thisView.superview!
		let superviewH = superview.bounds.size.height
		let myHalfHeight = thisView.bounds.size.height/2
		let translation = sender.translationInView(superview)
		
		var center = CGPoint(x:thisView.center.x + translation.x,
			y:thisView.center.y + translation.y);
		
		//		normal mode: bounds
		if (center.y - myHalfHeight < 0) {
			center.y = myHalfHeight
		} else if (center.y + myHalfHeight > superviewH) {
			center.y = superviewH - myHalfHeight
		}
		
		if (center.x - thisView.bounds.width/2 < 0) {
			center.x = thisView.bounds.width/2
		} else if (center.x + thisView.bounds.width/2 > superview.bounds.width) {
			center.x = superview.bounds.width - thisView.bounds.width/2
		}
		
		sender.view!.center = center
		sender.setTranslation(CGPoint(x: 0, y: 0), inView: superview)
	}
	
	private func updateCounterLabel() {
		counterLabel.text = "Task \(engine.currentTaskIndex+1) of \(engine.session.count), Trial \(curTask.repeats - repeats + 1)"
	}
}
