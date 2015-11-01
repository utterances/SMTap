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
	
	@IBOutlet weak var repeatSlider: UISlider!
	@IBOutlet weak var repeatLabel: UILabel!
	@IBOutlet weak var lengthField: UITextField!
	@IBOutlet weak var typeSegControl: UISegmentedControl!
	@IBOutlet weak var saveButton: UIButton!
	@IBOutlet weak var addTaskButton: UIButton!
	
	@IBOutlet weak var sessionTableview: UITableView!
	@IBOutlet weak var sessionHistoryTableView: UITableView!
	@IBOutlet weak var taskHistoryTableView: UITableView!
	
	var engine = ExpEngine()
	
	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.
	}

	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		sessionTableview.setEditing(true, animated: false)
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

//	MARK: - UI events

	@IBAction func sliderChanged(sender: UISlider) {
		let index = round(sender.value)
		sender.setValue(index, animated: true)
		repeatLabel.text = "\(Int(sender.value))"
		engine.repeats = Int(sender.value)
	}
	
	@IBAction func addTask(sender: UIButton) {
		sessionTableview.beginUpdates()
		engine.addTask(Int(lengthField.text!)!, repeats: Int(repeatSlider.value), type: ExpEngine.TaskType.allValues[typeSegControl.selectedSegmentIndex])
		
		sessionTableview.insertRowsAtIndexPaths([NSIndexPath(forRow: engine.session.count-1, inSection: 0)], withRowAnimation: .Automatic)
		sessionTableview.endUpdates()
		taskHistoryTableView.reloadData()
	}
	
	@IBAction func saveTask(sender: UIButton) {
		if let i = sessionTableview.indexPathForSelectedRow {
			let task = ExpEngine.Task(length: Int(lengthField.text!)!, repeats: Int(repeatSlider.value), type: ExpEngine.TaskType.allValues[typeSegControl.selectedSegmentIndex])
			
			engine.session[i.item] = task
			engine.addToHistory(task)
			sessionTableview.reloadRowsAtIndexPaths([i], withRowAnimation: .Left)
		}
		
		sender.enabled = false
	}
	
	@IBAction func endEditLength(sender: UITextField) {
		if let i = Int(sender.text!) {
			sender.text = "\(i)"
		} else {
			sender.text = "16"
		}
	}
	
	@IBAction func startSession(sender: UIButton) {
		engine.saveSession()
	}
//	MARK: nav
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

extension ViewController: UITextFieldDelegate {
	func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
		let numbers = "0123456789"
		for c in string.characters {
			if !numbers.characters.contains(c) { return false }
		}
		return true
	}
}

extension ViewController: UITableViewDelegate {
	func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		let task: ExpEngine.Task
		switch tableView {
		case sessionTableview:
			if let i = taskHistoryTableView.indexPathForSelectedRow {
				taskHistoryTableView.deselectRowAtIndexPath(i, animated: true)
			}
			saveButton.enabled = true
			task = engine.session[indexPath.item]
		case taskHistoryTableView:
			if let i = sessionTableview.indexPathForSelectedRow {
				sessionTableview.deselectRowAtIndexPath(i, animated: true)
			}
			saveButton.enabled = false
			task = engine.taskHistory[indexPath.item]
		default: return
		}
		
//		load task in "editor"
		
		repeatSlider.value = Float(task.repeats)
//		repeatLabel.text = task.repeats
		lengthField.text = "\(task.length)"
		typeSegControl.selectedSegmentIndex = ExpEngine.TaskType.allValues.indexOf(task.type)!
	}
	
	func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
		if editingStyle == .Delete {
			// Delete the row from the data source
			switch tableView {
			case sessionTableview:
				engine.session.removeAtIndex(indexPath.item)
			case taskHistoryTableView:
				engine.taskHistory.removeAtIndex(indexPath.item)
			case sessionHistoryTableView:
				engine.sessionHistory.removeAtIndex(indexPath.item)
			default: return
			}
			tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Left)
		}
	}
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
			cell.textLabel?.text = engine.summarize(engine.sessionHistory[indexPath.item])
		case taskHistoryTableView:
			cell.textLabel?.text = engine.taskHistory[indexPath.item].description
		default: break
		}
		
		return cell
	}
	
	func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
		return tableView == sessionTableview
	}

	// Override to support rearranging the table view.
	func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {
		assert(tableView == sessionTableview)
		let f = engine.session[fromIndexPath.item]
		let t = engine.session[toIndexPath.item]
		engine.session[toIndexPath.item] = f
		engine.session[fromIndexPath.item] = t
	}
}