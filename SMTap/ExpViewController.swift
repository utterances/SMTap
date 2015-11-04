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
	
	private var remainTaps: Int = 0
	private var repeats: Int = 0
	
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
			case 1:	//begin task
				instructLabel.text = instruct[curTask.type]![1]
				engine.startRecording()
				tapButton.enabled = true
				nextButton.enabled = false
				remainTaps = curTask.length
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
	
	override func viewWillAppear(animated: Bool) {
		taskIndex = 0
		repeats = curTask.repeats
		counterLabel.text = "Set \(curTask.repeats - repeats), Task \(taskIndex+1) of \(engine.session.count)"
		step = 0
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
		switch step {
		case 3:
			counterLabel.text = "Set \(curTask.repeats - repeats), Task \(taskIndex+1) of \(engine.session.count)"
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
		if remainTaps == 0 {
			step += 1
		}
	}
}
