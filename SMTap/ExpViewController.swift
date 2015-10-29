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

	@IBOutlet weak var tapButton: UIButton!
	@IBOutlet weak var startButton: UIButton!
	
	private var remainTaps: Int = 0
	private var repeats: Int = 0
	
	override func viewWillAppear(animated: Bool) {
		repeats = engine.repeats
	}
	
	
	@IBAction func tapClose(sender: UIButton) {
		dismissViewControllerAnimated(true, completion: nil)
	}
	
	@IBAction func tapStart(sender: UIButton) {
		sender.enabled = false
		engine.startRecording()
		tapButton.enabled = true
		remainTaps = engine.length
	}
	
	@IBAction func tapDown(sender: UIButton) {
		engine.tapDown()
	}
	
	@IBAction func tapUp(sender: UIButton) {
		engine.tapUp()
		
		remainTaps -= 1
		if remainTaps == 0 {
			engine.stopRecording()
			sender.enabled = false
			startButton.enabled = true
			
			repeats -= 1
			if repeats == 0 {
				engine.flushRecordToFile()
				let alertVC = UIAlertController(title: "Finished Session \(engine.currentRecord.ID)", message: "Saved \(engine.repeats) sequences, each of length \(engine.length) ", preferredStyle: .Alert)
				let ExVC = self
				let closeAction = UIAlertAction(title: "OK", style: .Default)
					{ finished in
					ExVC.dismissViewControllerAnimated(true, completion: nil)
				}
				alertVC.addAction(closeAction)
				
				presentViewController(alertVC, animated: true, completion: nil)
			}
		}
	}
}
