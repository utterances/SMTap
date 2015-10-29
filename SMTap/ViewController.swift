//
//  ViewController.swift
//  SMTap
//
//  Created by Tim on 10/28/15.
//  Copyright © 2015 Q. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

	@IBOutlet weak var idField: UITextField!
	@IBOutlet weak var tapButton: UIButton!
	@IBOutlet weak var repeatSlider: UISlider!
	@IBOutlet weak var repeatLabel: UILabel!
	@IBOutlet weak var lengthField: UITextField!
	
	@IBOutlet weak var taskTableview: UITableView!
	
	var engine = ExpEngine()
	
	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}


	@IBAction func sliderChanged(sender: UISlider) {
		let index = round(sender.value)
		sender.setValue(index, animated: true)
		repeatLabel.text = "\(Int(sender.value))"
		engine.repeats = Int(sender.value)
	}
	
	
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		// Get the new view controller using segue.destinationViewController.
		// Pass the selected object to the new view controller.
		if segue.destinationViewController is ExpViewController {
			engine.length = Int(lengthField.text!)!
			engine.startNewRecord(idField.text!)
			
			(segue.destinationViewController as! ExpViewController).engine = engine
		}
	}
}

extension ViewController: UITableViewDelegate {
	
}

extension ViewController: UITableViewDataSource {
	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 0
	}
	
	func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier("taskCell", forIndexPath: indexPath)
		
		return cell
	}
}