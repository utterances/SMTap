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
	
	@IBOutlet weak var sessionTableview: UITableView!
	@IBOutlet weak var sessionHistoryTableView: UITableView!
	@IBOutlet weak var taskHistoryTableView: UITableView!
	
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
		switch tableView {
		case sessionTableview:			return engine.session.count
		case sessionHistoryTableView:	return engine.sessionHistory.count
		case taskHistoryTableView:		return engine.taskHistory.count
		default: return 0
		}
	}
	
	func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier("taskCell", forIndexPath: indexPath)
		switch tableView {
		case sessionTableview:
			cell.textLabel?.text = engine.session[indexPath.item].description
		case sessionHistoryTableView:
			cell.textLabel?.text = "\(engine.sessionHistory[indexPath.item].count)"
		case taskHistoryTableView:
			cell.textLabel?.text = engine.taskHistory[indexPath.item].description
		default: break
		}
		
		return cell
	}
}