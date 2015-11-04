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
	@IBOutlet weak var tapButton: UIButton!
	@IBOutlet weak var nextButton: UIButton!
	@IBOutlet var panButtonGestureRecognizer: UIPanGestureRecognizer!
	@IBOutlet weak var progressView: UIProgressView!
	
	private var remainTaps: Int = 0
	private var repeats: Int = 0
	
	private var showIntro: Bool = true
	
	private let initInstruct = "To start, we would like you to tap at a regular beat with your dominant index finger on the blue button in front of you. Please tap with your dominant index finger while your wrist rests on the blue pad."
	
	private let instruct: [ExpEngine.TaskType: [String]] = [
	ExpEngine.TaskType.Slow : ["In this task you will tap as slow as possible while maintaining a smooth and continuous rhythm. Please tap as evenly as possible. Try practice tapping as slow as possible on the button below. When you are ready to continue, tap Next",
		"You are ready to begin, start tapping as slow as possible below:"],
		
	ExpEngine.TaskType.Normal : ["In this task you will tap at your favorite, or preferred, pace.  By preferred pace, we mean a rate that is not too fast or too slow, but feels “just right” for you. Please tap as evenly as possible. Try practice tapping at a comfortable pace on the button below. When you are ready to continue, tap Next",
		"You are ready to begin, start tapping at a comfortable pace:"],
		
	ExpEngine.TaskType.Fast : ["In this task you will tap as fast as possible. Try practice tapping as fast as possible on the button below. When you are ready to continue, tap Next",
		"You are ready to begin, start tapping as fast as you can:"]
	]

	private let instructCommon = ["Keep tapping...",
		"You are done! Press Next to repeat",
		"You are done! Press Next to continue"]
	
	private var curTask: ExpEngine.Task { return engine.session[taskIndex] }
	
	private var step: Int = 0 {
		didSet{
			switch step {
			case 0:	//begin instruct
				instructLabel.text = instruct[curTask.type]![0]
				tapButton.enabled = true
				nextButton.enabled = true
				progressView.setProgress(0, animated: true)
			case 1:	//begin task
				instructLabel.text = instruct[curTask.type]![1]
				engine.startRecording()
				tapButton.enabled = true
				nextButton.enabled = false
				remainTaps = curTask.length
				progressView.setProgress(0, animated: true)
			case 2:	// continue tapping
				instructLabel.text = instructCommon[0]
			case 3:	// finish tapping
				engine.stopRecording()
				tapButton.enabled = false
				nextButton.enabled = true
				
				repeats -= 1
				if repeats == 0 {
					instructLabel.text = instructCommon[2]

					engine.flushRecordToFile()
					
//					check if we are finished:
					if taskIndex == engine.session.count-1 {
						let alertVC = UIAlertController(title: "Finished Session \(engine.currentRecord.ID)", message: "Please find the experimenter. Saved \(engine.session.count) tasks", preferredStyle: .Alert)
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
	
	private var taskIndex: Int = 0
	
	override func viewDidLoad() {
		super.viewDidLoad()
		let movBack = UIImage(named: "tapButton-mov")
		tapButton.setBackgroundImage(movBack, forState: .Normal)
		tapButton.setBackgroundImage(movBack, forState: .Highlighted)
		
	}
	
	override func viewWillAppear(animated: Bool) {
		taskIndex = 0
		repeats = curTask.repeats
//		step = 0
		counterLabel.text = ""
	}
	
	@IBAction func tapClose(sender: UIButton) {
		let alertVC = UIAlertController(title: "End This Session? ", message: "Are you sure? Any current unfinished task will be discarded, previously completed task are saved automatically.", preferredStyle: .Alert)
		let exitAction = UIAlertAction(title: "Exit", style: .Destructive) { action in
			self.dismissViewControllerAnimated(true, completion: nil)
		}
		let cancelAction = UIAlertAction(title: "Cancel", style: .Default, handler: nil)
		
		alertVC.addAction(exitAction)
		alertVC.addAction(cancelAction)
		presentViewController(alertVC, animated: true, completion: nil)
	}
	
	@IBAction func tapNext(sender: UIButton) {
		guard !showIntro else {
			updateCounterLabel()
			step = 0
			showIntro = false
			panButtonGestureRecognizer.enabled = false
			let movBack = UIImage(named: "tapButton")
			tapButton.setBackgroundImage(movBack, forState: .Normal)
			tapButton.setBackgroundImage(movBack, forState: .Highlighted)
			return
		}
		
		switch step {
		case 3:
			updateCounterLabel()
			if repeats == 0 { // starting new task
				taskIndex += 1
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
		guard step != 0 else { return }
		engine.tapUp()
		
		if step == 1 { step = 2 }
		
		remainTaps -= 1
//		update progress too:
		progressView.setProgress(1 - Float(remainTaps) / Float(curTask.length), animated: true)
		
		if remainTaps == 0 {
			step += 1
		}
	}
	
	@IBAction func pannedGesture(sender: UIPanGestureRecognizer) {
		let superview = sender.view!.superview!
		let superviewH = superview.bounds.size.height
		let myHalfHeight = sender.view!.bounds.size.height/2
		let translation = sender.translationInView(superview)
		
		var center = CGPoint(x:sender.view!.center.x + translation.x,
			y:sender.view!.center.y + translation.y);
		
		//		normal mode: bounds
		if (center.y - myHalfHeight < 0) {
			center.y = myHalfHeight
		} else if (center.y + myHalfHeight > superviewH) {
			center.y = superviewH - myHalfHeight
		}
		sender.view!.center = center
		sender.setTranslation(CGPoint(x: 0, y: 0), inView: superview)
	}
	
	private func updateCounterLabel() {
		counterLabel.text = "Set \(curTask.repeats - repeats + 1), Task \(taskIndex+1) of \(engine.session.count)"

	}
}
